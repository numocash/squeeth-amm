// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { IUniswapV2Pair } from "./UniswapV2/interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "./UniswapV3/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3SwapCallback } from "./UniswapV3/interfaces/callback/IUniswapV3SwapCallback.sol";

import { PoolAddress } from "./UniswapV3/libraries/PoolAddress.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { TickMath } from "./UniswapV3/libraries/TickMath.sol";
import { UniswapV2Library } from "./UniswapV2/libraries/UniswapV2Library.sol";

/// @notice Allows for swapping on Uniswap V2 or V3
/// @author Kyle Scott (kyle@numoen.com)
abstract contract SwapHelper is IUniswapV3SwapCallback {
  /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

  /// @dev should match the init code hash in the UniswapV2Library
  address public immutable uniswapV2Factory;

  address public immutable uniswapV3Factory;

  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor(address _uniswapV2Factory, address _uniswapV3Factory) {
    uniswapV2Factory = _uniswapV2Factory;
    uniswapV3Factory = _uniswapV3Factory;
  }

  /*//////////////////////////////////////////////////////////////
                        UNISWAPV3 SWAP CALLBACK
    //////////////////////////////////////////////////////////////*/

  function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
    address tokenIn = abi.decode(data, (address));
    // no validation because this contract should hold no tokens between transactions

    SafeTransferLib.safeTransfer(tokenIn, msg.sender, amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta));
  }

  /*//////////////////////////////////////////////////////////////
                               SWAP LOGIC
    //////////////////////////////////////////////////////////////*/

  enum SwapType {
    UniswapV2,
    UniswapV3
  }

  struct SwapParams {
    address tokenIn;
    address tokenOut;
    int256 amount; // negative corresponds to exact out
    address recipient;
  }

  struct UniV3Data {
    uint24 fee;
  }

  /// @notice Handles swaps on Uniswap V2 or V3
  /// @param swapType A selector for UniswapV2 or V3
  /// @param data Extra data that is not used by all types of swaps
  /// @return amount The amount in or amount out depending on whether the call was exact in or exact out
  function swap(SwapType swapType, SwapParams memory params, bytes memory data) internal returns (uint256 amount) {
    if (swapType == SwapType.UniswapV2) {
      address pair = UniswapV2Library.pairFor(uniswapV2Factory, params.tokenIn, params.tokenOut);

      (uint256 reserveIn, uint256 reserveOut) =
        UniswapV2Library.getReserves(uniswapV2Factory, params.tokenIn, params.tokenOut);

      amount = params.amount > 0
        ? UniswapV2Library.getAmountOut(uint256(params.amount), reserveIn, reserveOut)
        : UniswapV2Library.getAmountIn(uint256(-params.amount), reserveIn, reserveOut);

      (uint256 amountIn, uint256 amountOut) =
        params.amount > 0 ? (uint256(params.amount), amount) : (amount, uint256(-params.amount));

      (address token0,) = UniswapV2Library.sortTokens(params.tokenIn, params.tokenOut);
      (uint256 amount0Out, uint256 amount1Out) =
        params.tokenIn == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));

      SafeTransferLib.safeTransfer(params.tokenIn, pair, amountIn);
      IUniswapV2Pair(pair).swap(amount0Out, amount1Out, params.recipient, bytes(""));
    } else {
      UniV3Data memory uniV3Data = abi.decode(data, (UniV3Data));

      // Borrowed logic from https://github.com/Uniswap/v3-periphery/blob/main/contracts/SwapRouter.sol
      // exactInputInternal and exactOutputInternal

      bool zeroForOne = params.tokenIn < params.tokenOut;

      IUniswapV3Pool pool = IUniswapV3Pool(
        PoolAddress.computeAddress(
          uniswapV3Factory, PoolAddress.getPoolKey(params.tokenIn, params.tokenOut, uniV3Data.fee)
        )
      );

      (int256 amount0, int256 amount1) = pool.swap(
        params.recipient,
        zeroForOne,
        params.amount,
        zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
        abi.encode(params.tokenIn)
      );

      if (params.amount > 0) {
        amount = uint256(-(zeroForOne ? amount1 : amount0));
      } else {
        int256 amountOutReceived;
        (amount, amountOutReceived) = zeroForOne ? (uint256(amount0), amount1) : (uint256(amount1), amount0);
        require(amountOutReceived == params.amount);
      }
    }
  }
}
