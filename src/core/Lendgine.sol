// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { ERC20 } from "./ERC20.sol";
import { JumpRate } from "./JumpRate.sol";
import { Pair } from "./Pair.sol";

import { IMintCallback } from "./interfaces/callbacks/IMintCallback.sol";

import { Balance } from "./libraries/Balance.sol";
import { FullMath } from "./libraries/FullMath.sol";
import { Position } from "./libraries/Position.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";

contract Lendgine is ERC20, JumpRate, Pair {
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

    mapping(address => Position.Info) public positions;

    uint256 public totalPositionSize; // TODO: can we remove this slot

    uint256 public totalLiquidityBorrowed;

    uint256 public rewardPerPositionStored;

    /// @dev don't downsize because it takes up the last slot
    uint256 public lastUpdate;

    function mint(
        address to,
        uint256 collateral,
        bytes calldata data
    ) external nonReentrant returns (uint256 shares) {
        _accrueInterest();

        uint256 liquidity = convertCollateralToLiquidity(collateral);
        shares = convertLiquidityToShare(liquidity);

        if (collateral == 0 || liquidity == 0 || shares == 0) revert InputError();
        if (liquidity + totalLiquidityBorrowed > totalLiquidity) revert CompleteUtilizationError();
        if (totalSupply > 0 && totalLiquidityBorrowed == 0) revert CompleteUtilizationError();

        // update state
        totalLiquidityBorrowed += liquidity;
        burn(to, liquidity);
        _mint(to, shares);

        uint256 balanceBefore = Balance.balance(token1);
        IMintCallback(msg.sender).mintCallback(collateral, data);
        uint256 balanceAfter = Balance.balance(token1);

        if (balanceAfter < balanceBefore + collateral) revert InsufficientInputError();

        emit Mint(msg.sender, collateral, shares, liquidity, to);
    }

    function burn(address to, bytes calldata data) external nonReentrant returns (uint256 collateral) {
        _accrueInterest();

        // calc shares and liquidity
        uint256 shares = balanceOf[address(this)];
        uint256 liquidity = convertShareToLiquidity(shares);
        collateral = convertLiquidityToCollateral(liquidity);

        if (collateral == 0 || liquidity == 0 || shares == 0) revert InputError();

        // update state
        totalLiquidityBorrowed -= liquidity;
        _burn(address(this), shares);
        SafeTransferLib.safeTransfer(token1, to, collateral); // optimistically transfer
        mint(liquidity, data);

        emit Burn(msg.sender, collateral, shares, liquidity, to);
    }

    function deposit(
        address to,
        uint256 liquidity,
        bytes calldata data
    ) external nonReentrant returns (uint256 size) {
        _accrueInterest();

        uint256 _totalPositionSize = totalPositionSize; // SLOAD
        uint256 totalLiquiditySupplied = totalLiquidity + totalLiquidityBorrowed;

        // calculate position
        size = Position.convertLiquidityToPosition(liquidity, totalLiquiditySupplied, _totalPositionSize);

        // validate inputs
        if (liquidity == 0 || size == 0) revert InputError();

        // update state
        positions.update(to, int256(size), rewardPerPositionStored); // TODO: are we safe to cast this
        totalPositionSize = _totalPositionSize + size;
        mint(liquidity, data);

        emit Deposit(msg.sender, size, liquidity, to);
    }

    function withdraw(address to, uint256 size) external nonReentrant returns (uint256 liquidity) {
        _accrueInterest();

        uint256 _totalPositionSize = totalPositionSize; // SLOAD
        uint256 _totalLiquidity = totalLiquidity; // SLOAD
        uint256 totalLiquiditySupplied = _totalLiquidity + totalLiquidityBorrowed;

        // read position
        Position.Info memory positionInfo = positions.get(msg.sender);
        liquidity = Position.convertPositionToLiquidity(size, totalLiquiditySupplied, _totalPositionSize); // TODO: can liquidity ever be 0

        // validate inputs
        if (liquidity == 0 || size == 0) revert InputError();

        // check position
        if (size > positionInfo.size) revert InsufficientPositionError();
        if (totalLiquidityBorrowed + liquidity > _totalLiquidity) revert CompleteUtilizationError(); // prevents underflows

        // update state
        positions.update(msg.sender, -int256(size), rewardPerPositionStored); // TODO: are we safe to cast this
        totalPositionSize -= size;
        burn(to, liquidity);

        emit Withdraw(msg.sender, size, liquidity, to);
    }

    function accrueInterest() external nonReentrant {
        _accrueInterest();
    }

    function accruePositionInterest() external nonReentrant {
        _accrueInterest();
        _accruePositionInterest(msg.sender);
    }

    function collect(address to, uint256 collateralRequested) external nonReentrant returns (uint256 collateral) {
        Position.Info storage position = positions.get(msg.sender);
        uint256 tokensOwed = position.tokensOwed; // SLOAD

        collateral = collateralRequested > tokensOwed ? tokensOwed : collateralRequested;

        if (collateral > 0) {
            position.tokensOwed = tokensOwed - collateral;
            SafeTransferLib.safeTransfer(token1, to, collateral);
        }

        emit Collect(msg.sender, to, collateral);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function convertLiquidityToShare(uint256 liquidity) public view returns (uint256) {
        uint256 _totalLiquidityBorrowed = totalLiquidityBorrowed; // SLOAD
        return
            _totalLiquidityBorrowed == 0 ? liquidity : FullMath.mulDiv(liquidity, totalSupply, _totalLiquidityBorrowed);
    }

    function convertShareToLiquidity(uint256 shares) public view returns (uint256) {
        return FullMath.mulDiv(totalLiquidityBorrowed, shares, totalSupply);
    }

    function convertCollateralToLiquidity(uint256 collateral) public view returns (uint256) {
        return FullMath.mulDiv(collateral, 1 ether, 2 * upperBound);
    }

    function convertLiquidityToCollateral(uint256 liquidity) public view returns (uint256) {
        return FullMath.mulDiv(liquidity, 2 * upperBound, 1 ether);
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

        uint256 dilutionLPRequested = (FullMath.mulDiv(borrowRate, _totalLiquidityBorrowed, 1 ether) * timeElapsed) /
            365 days;
        uint256 dilutionLP = dilutionLPRequested > _totalLiquidityBorrowed
            ? _totalLiquidityBorrowed
            : dilutionLPRequested;
        uint256 dilutionSpeculative = convertLiquidityToCollateral(dilutionLP);

        totalLiquidityBorrowed = _totalLiquidityBorrowed - dilutionLP;
        rewardPerPositionStored += FullMath.mulDiv(dilutionSpeculative, 1 ether, totalPositionSize);
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
