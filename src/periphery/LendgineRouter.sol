// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Multicall } from "./Multicall.sol";
import { Payment } from "./Payment.sol";
import { SelfPermit } from "./SelfPermit.sol";
import { SwapHelper } from "./SwapHelper.sol";

import { ILendgine } from "../core/interfaces/ILendgine.sol";
import { IMintCallback } from "../core/interfaces/callback/IMintCallback.sol";
import { IPairMintCallback } from "../core/interfaces/callback/IPairMintCallback.sol";

import { FullMath } from "../libraries/FullMath.sol";
import { LendgineAddress } from "./libraries/LendgineAddress.sol";
import { SafeCast } from "../libraries/SafeCast.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";

/// @notice Contract for automatically entering and exiting option positions
/// @author Kyle Scott (kyle@numoen.com)
contract LendgineRouter is Multicall, Payment, SelfPermit, SwapHelper, IMintCallback, IPairMintCallback {
  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

  event Mint(address indexed from, address indexed lendgine, uint256 collateral, uint256 shares, address indexed to);

  event Burn(address indexed from, address indexed lendgine, uint256 collateral, uint256 shares, address indexed to);

  /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

  error LivelinessError();

  error ValidationError();

  error AmountError();

  /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

  address public immutable factory;

  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor(
    address _factory,
    address _uniswapV2Factory,
    address _uniswapV3Factory,
    address _weth
  )
    SwapHelper(_uniswapV2Factory, _uniswapV3Factory)
    Payment(_weth)
  {
    factory = _factory;
  }

  /*//////////////////////////////////////////////////////////////
                           LIVELINESS MODIFIER
    //////////////////////////////////////////////////////////////*/

  modifier checkDeadline(uint256 deadline) {
    if (deadline < block.timestamp) revert LivelinessError();
    _;
  }

  /*//////////////////////////////////////////////////////////////
                               MINT LOGIC
    //////////////////////////////////////////////////////////////*/

  struct MintCallbackData {
    address token0;
    address token1;
    uint256 token0Exp;
    uint256 token1Exp;
    uint256 upperBound;
    uint256 collateralMax;
    SwapType swapType;
    bytes swapExtraData;
    address payer;
  }

  /// @notice Transfer the necessary amount of token1 to mint an option position
  function mintCallback(
    uint256 collateralTotal,
    uint256 amount0,
    uint256 amount1,
    uint256,
    bytes calldata data
  )
    external
    override
  {
    MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

    address lendgine = LendgineAddress.computeAddress(
      factory, decoded.token0, decoded.token1, decoded.token0Exp, decoded.token1Exp, decoded.upperBound
    );
    if (lendgine != msg.sender) revert ValidationError();

    // swap all token0 to token1
    uint256 collateralSwap = swap(
      decoded.swapType,
      SwapParams({
        tokenIn: decoded.token0,
        tokenOut: decoded.token1,
        amount: SafeCast.toInt256(amount0),
        recipient: msg.sender
      }),
      decoded.swapExtraData
    );

    // send token1 back
    SafeTransferLib.safeTransfer(decoded.token1, msg.sender, amount1);

    // pull the rest of tokens from the user
    uint256 collateralIn = collateralTotal - amount1 - collateralSwap;
    if (collateralIn > decoded.collateralMax) revert AmountError();

    pay(decoded.token1, decoded.payer, msg.sender, collateralIn);
  }

  struct MintParams {
    address token0;
    address token1;
    uint256 token0Exp;
    uint256 token1Exp;
    uint256 upperBound;
    uint256 amountIn;
    uint256 amountBorrow;
    uint256 sharesMin;
    SwapType swapType;
    bytes swapExtraData;
    address recipient;
    uint256 deadline;
  }

  /// @notice Use token1 to completely mint an option position
  function mint(MintParams calldata params) external payable checkDeadline(params.deadline) returns (uint256 shares) {
    address lendgine = LendgineAddress.computeAddress(
      factory, params.token0, params.token1, params.token0Exp, params.token1Exp, params.upperBound
    );

    shares = ILendgine(lendgine).mint(
      address(this),
      params.amountIn + params.amountBorrow,
      abi.encode(
        MintCallbackData({
          token0: params.token0,
          token1: params.token1,
          token0Exp: params.token0Exp,
          token1Exp: params.token1Exp,
          upperBound: params.upperBound,
          collateralMax: params.amountIn,
          swapType: params.swapType,
          swapExtraData: params.swapExtraData,
          payer: msg.sender
        })
      )
    );
    if (shares < params.sharesMin) revert AmountError();

    SafeTransferLib.safeTransfer(lendgine, params.recipient, shares);

    emit Mint(msg.sender, lendgine, params.amountIn, shares, params.recipient);
  }

  /*//////////////////////////////////////////////////////////////
                               BURN LOGIC
    //////////////////////////////////////////////////////////////*/

  struct PairMintCallbackData {
    address token0;
    address token1;
    uint256 token0Exp;
    uint256 token1Exp;
    uint256 upperBound;
    uint256 collateralMin;
    uint256 amount0Min;
    uint256 amount1Min;
    SwapType swapType;
    bytes swapExtraData;
    address recipient;
  }

  /// @notice Provide the tokens for the liquidity that is owed
  function pairMintCallback(uint256 liquidity, bytes calldata data) external override {
    PairMintCallbackData memory decoded = abi.decode(data, (PairMintCallbackData));

    address lendgine = LendgineAddress.computeAddress(
      factory, decoded.token0, decoded.token1, decoded.token0Exp, decoded.token1Exp, decoded.upperBound
    );
    if (lendgine != msg.sender) revert ValidationError();

    uint256 r0 = ILendgine(msg.sender).reserve0();
    uint256 r1 = ILendgine(msg.sender).reserve1();
    uint256 totalLiquidity = ILendgine(msg.sender).totalLiquidity();

    uint256 amount0;
    uint256 amount1;

    if (totalLiquidity == 0) {
      amount0 = decoded.amount0Min;
      amount1 = decoded.amount1Min;
    } else {
      amount0 = FullMath.mulDivRoundingUp(liquidity, r0, totalLiquidity);
      amount1 = FullMath.mulDivRoundingUp(liquidity, r1, totalLiquidity);
    }

    if (amount0 < decoded.amount0Min || amount1 < decoded.amount1Min) revert AmountError();

    // swap for required token0
    uint256 collateralSwapped = swap(
      decoded.swapType,
      SwapParams({
        tokenIn: decoded.token1,
        tokenOut: decoded.token0,
        amount: -SafeCast.toInt256(amount0),
        recipient: msg.sender
      }),
      decoded.swapExtraData
    );

    // pay token1
    SafeTransferLib.safeTransfer(decoded.token1, msg.sender, amount1);

    // determine remaining and send to recipient
    uint256 collateralTotal = ILendgine(msg.sender).convertLiquidityToCollateral(liquidity);
    uint256 collateralOut = collateralTotal - amount1 - collateralSwapped;
    if (collateralOut < decoded.collateralMin) revert AmountError();

    if (decoded.recipient != address(this)) {
      SafeTransferLib.safeTransfer(decoded.token1, decoded.recipient, collateralOut);
    }
  }

  struct BurnParams {
    address token0;
    address token1;
    uint256 token0Exp;
    uint256 token1Exp;
    uint256 upperBound;
    uint256 shares;
    uint256 collateralMin;
    uint256 amount0Min;
    uint256 amount1Min;
    SwapType swapType;
    bytes swapExtraData;
    address recipient;
    uint256 deadline;
  }

  /// @notice Take an option position and withdraw it fully into token1
  function burn(BurnParams calldata params) external payable checkDeadline(params.deadline) returns (uint256 amount) {
    address lendgine = LendgineAddress.computeAddress(
      factory, params.token0, params.token1, params.token0Exp, params.token1Exp, params.upperBound
    );

    address recipient = params.recipient == address(0) ? address(this) : params.recipient;

    SafeTransferLib.safeTransferFrom(lendgine, msg.sender, lendgine, params.shares);

    amount = ILendgine(lendgine).burn(
      address(this),
      abi.encode(
        PairMintCallbackData({
          token0: params.token0,
          token1: params.token1,
          token0Exp: params.token0Exp,
          token1Exp: params.token1Exp,
          upperBound: params.upperBound,
          collateralMin: params.collateralMin,
          amount0Min: params.amount0Min,
          amount1Min: params.amount1Min,
          swapType: params.swapType,
          swapExtraData: params.swapExtraData,
          recipient: recipient
        })
      )
    );

    emit Burn(msg.sender, lendgine, amount, params.shares, recipient);
  }
}
