// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { ERC20 } from "./ERC20.sol";
import { JumpRate } from "./JumpRate.sol";
import { Pair } from "./Pair.sol";

import { ILendgine } from "./interfaces/ILendgine.sol";
import { IMintCallback } from "./interfaces/callback/IMintCallback.sol";

import { Balance } from "../libraries/Balance.sol";
import { FullMath } from "../libraries/FullMath.sol";
import { Position } from "./libraries/Position.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { SafeCast } from "../libraries/SafeCast.sol";

contract Lendgine is ERC20, JumpRate, Pair, ILendgine {
  using Position for mapping(address => Position.Info);
  using Position for Position.Info;

  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

  event Mint(address indexed sender, uint256 collateral, uint256 shares, uint256 liquidity, address indexed to);

  event Burn(address indexed sender, uint256 collateral, uint256 shares, uint256 liquidity, address indexed to);

  event Deposit(address indexed sender, uint256 size, uint256 liquidity, address indexed to);

  event Withdraw(address indexed sender, uint256 size, uint256 liquidity, address indexed to);

  event AccrueInterest(uint256 timeElapsed, uint256 collateral, uint256 liquidity);

  event AccruePositionInterest(address indexed owner, uint256 rewardPerPosition);

  event Collect(address indexed owner, address indexed to, uint256 amount);

  /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

  error InputError();

  error CompleteUtilizationError();

  error InsufficientInputError();

  error InsufficientPositionError();

  /*//////////////////////////////////////////////////////////////
                          LENDGINE STORAGE
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ILendgine
  mapping(address => Position.Info) public override positions;

  /// @inheritdoc ILendgine
  uint256 public override totalPositionSize;

  /// @inheritdoc ILendgine
  uint256 public override totalLiquidityBorrowed;

  /// @inheritdoc ILendgine
  uint256 public override rewardPerPositionStored;

  /// @inheritdoc ILendgine
  uint256 public override lastUpdate;

  /// @inheritdoc ILendgine
  function mint(
    address to,
    uint256 collateral,
    bytes calldata data
  )
    external
    override
    nonReentrant
    returns (uint256 shares)
  {
    _accrueInterest();

    uint256 liquidity = convertCollateralToLiquidity(collateral);
    shares = convertLiquidityToShare(liquidity);

    if (collateral == 0 || liquidity == 0 || shares == 0) revert InputError();
    if (liquidity > totalLiquidity) revert CompleteUtilizationError();
    // next check is for the case when liquidity is borrowed but then was completely accrued
    if (totalSupply > 0 && totalLiquidityBorrowed == 0) revert CompleteUtilizationError();

    totalLiquidityBorrowed += liquidity;
    (uint256 amount0, uint256 amount1) = burn(to, liquidity);
    _mint(to, shares);

    uint256 balanceBefore = Balance.balance(token1);
    IMintCallback(msg.sender).mintCallback(collateral, amount0, amount1, liquidity, data);
    uint256 balanceAfter = Balance.balance(token1);

    if (balanceAfter < balanceBefore + collateral) revert InsufficientInputError();

    emit Mint(msg.sender, collateral, shares, liquidity, to);
  }

  /// @inheritdoc ILendgine
  function burn(address to, bytes calldata data) external override nonReentrant returns (uint256 collateral) {
    _accrueInterest();

    uint256 shares = balanceOf[address(this)];
    uint256 liquidity = convertShareToLiquidity(shares);
    collateral = convertLiquidityToCollateral(liquidity);

    if (collateral == 0 || liquidity == 0 || shares == 0) revert InputError();

    totalLiquidityBorrowed -= liquidity;
    _burn(address(this), shares);
    SafeTransferLib.safeTransfer(token1, to, collateral); // optimistically transfer
    mint(liquidity, data);

    emit Burn(msg.sender, collateral, shares, liquidity, to);
  }

  /// @inheritdoc ILendgine
  function deposit(
    address to,
    uint256 liquidity,
    bytes calldata data
  )
    external
    override
    nonReentrant
    returns (uint256 size)
  {
    _accrueInterest();

    uint256 _totalPositionSize = totalPositionSize; // SLOAD
    uint256 totalLiquiditySupplied = totalLiquidity + totalLiquidityBorrowed;

    size = Position.convertLiquidityToPosition(liquidity, totalLiquiditySupplied, _totalPositionSize);

    if (liquidity == 0 || size == 0) revert InputError();
    // next check is for the case when liquidity is borrowed but then was completely accrued
    if (totalLiquiditySupplied == 0 && totalPositionSize > 0) revert CompleteUtilizationError();

    positions.update(to, SafeCast.toInt256(size), rewardPerPositionStored);
    totalPositionSize = _totalPositionSize + size;
    mint(liquidity, data);

    emit Deposit(msg.sender, size, liquidity, to);
  }

  /// @inheritdoc ILendgine
  function withdraw(
    address to,
    uint256 size
  )
    external
    override
    nonReentrant
    returns (uint256 amount0, uint256 amount1, uint256 liquidity)
  {
    _accrueInterest();

    uint256 _totalPositionSize = totalPositionSize; // SLOAD
    uint256 _totalLiquidity = totalLiquidity; // SLOAD
    uint256 totalLiquiditySupplied = _totalLiquidity + totalLiquidityBorrowed;

    Position.Info memory positionInfo = positions[msg.sender]; // SLOAD
    liquidity = Position.convertPositionToLiquidity(size, totalLiquiditySupplied, _totalPositionSize);

    if (liquidity == 0 || size == 0) revert InputError();

    if (size > positionInfo.size) revert InsufficientPositionError();
    if (liquidity > _totalLiquidity) revert CompleteUtilizationError();

    positions.update(msg.sender, -SafeCast.toInt256(size), rewardPerPositionStored);
    totalPositionSize -= size;
    (amount0, amount1) = burn(to, liquidity);

    emit Withdraw(msg.sender, size, liquidity, to);
  }

  /// @inheritdoc ILendgine
  function accrueInterest() external override nonReentrant {
    _accrueInterest();
  }

  /// @inheritdoc ILendgine
  function accruePositionInterest() external override nonReentrant {
    _accrueInterest();
    _accruePositionInterest(msg.sender);
  }

  /// @inheritdoc ILendgine
  function collect(address to, uint256 collateralRequested) external override nonReentrant returns (uint256 collateral) {
    Position.Info storage position = positions[msg.sender]; // SLOAD
    uint256 tokensOwed = position.tokensOwed;

    collateral = collateralRequested > tokensOwed ? tokensOwed : collateralRequested;

    if (collateral > 0) {
      position.tokensOwed = tokensOwed - collateral; // SSTORE
      SafeTransferLib.safeTransfer(token1, to, collateral);
    }

    emit Collect(msg.sender, to, collateral);
  }

  /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ILendgine
  function convertLiquidityToShare(uint256 liquidity) public view override returns (uint256) {
    uint256 _totalLiquidityBorrowed = totalLiquidityBorrowed; // SLOAD
    return _totalLiquidityBorrowed == 0 ? liquidity : FullMath.mulDiv(liquidity, totalSupply, _totalLiquidityBorrowed);
  }

  /// @inheritdoc ILendgine
  function convertShareToLiquidity(uint256 shares) public view override returns (uint256) {
    return FullMath.mulDiv(totalLiquidityBorrowed, shares, totalSupply);
  }

  /// @inheritdoc ILendgine
  function convertCollateralToLiquidity(uint256 collateral) public view override returns (uint256) {
    return FullMath.mulDiv(collateral * token1Scale, 1e18, 2 * upperBound);
  }

  /// @inheritdoc ILendgine
  function convertLiquidityToCollateral(uint256 liquidity) public view override returns (uint256) {
    return FullMath.mulDiv(liquidity, 2 * upperBound, 1e18) / token1Scale;
  }

  /*//////////////////////////////////////////////////////////////
                         INTERNAL INTEREST LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @notice Helper function for accruing lendgine interest
  function _accrueInterest() private {
    if (totalSupply == 0 || totalLiquidityBorrowed == 0) {
      lastUpdate = block.timestamp;
      return;
    }

    uint256 timeElapsed = block.timestamp - lastUpdate;
    if (timeElapsed == 0) return;

    uint256 _totalLiquidityBorrowed = totalLiquidityBorrowed; // SLOAD
    uint256 totalLiquiditySupplied = totalLiquidity + _totalLiquidityBorrowed; // SLOAD

    uint256 borrowRate = getBorrowRate(_totalLiquidityBorrowed, totalLiquiditySupplied);

    uint256 dilutionLPRequested = (FullMath.mulDiv(borrowRate, _totalLiquidityBorrowed, 1e18) * timeElapsed) / 365 days;
    uint256 dilutionLP = dilutionLPRequested > _totalLiquidityBorrowed ? _totalLiquidityBorrowed : dilutionLPRequested;
    uint256 dilutionSpeculative = convertLiquidityToCollateral(dilutionLP);

    totalLiquidityBorrowed = _totalLiquidityBorrowed - dilutionLP;
    rewardPerPositionStored += FullMath.mulDiv(dilutionSpeculative, 1e18, totalPositionSize);
    lastUpdate = block.timestamp;

    emit AccrueInterest(timeElapsed, dilutionSpeculative, dilutionLP);
  }

  /// @notice Helper function for accruing interest to a position
  /// @dev Assume the global interest is up to date
  /// @param owner The address that this position belongs to
  function _accruePositionInterest(address owner) private {
    uint256 _rewardPerPositionStored = rewardPerPositionStored; // SLOAD

    positions.update(owner, 0, _rewardPerPositionStored);

    emit AccruePositionInterest(owner, _rewardPerPositionStored);
  }
}
