// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { IPairMintCallback } from "../../src/core/interfaces/callback/IPairMintCallback.sol";
import { IMintCallback } from "../../src/core/interfaces/callback/IMintCallback.sol";
import { ISwapCallback } from "../../src/core/interfaces/callback/ISwapCallback.sol";

import { SafeTransferLib } from "../../src/libraries/SafeTransferLib.sol";

contract CallbackHelper is IPairMintCallback, IMintCallback, ISwapCallback {
  struct PairMintCallbackData {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
    address payer;
  }

  function pairMintCallback(uint256, bytes calldata data) external override {
    PairMintCallbackData memory decoded = abi.decode(data, (PairMintCallbackData));

    if (decoded.payer == address(this)) {
      if (decoded.amount0 > 0) SafeTransferLib.safeTransfer(decoded.token0, msg.sender, decoded.amount0);
      if (decoded.amount1 > 0) SafeTransferLib.safeTransfer(decoded.token1, msg.sender, decoded.amount1);
    } else {
      if (decoded.amount0 > 0) {
        SafeTransferLib.safeTransferFrom(decoded.token0, decoded.payer, msg.sender, decoded.amount0);
      }
      if (decoded.amount1 > 0) {
        SafeTransferLib.safeTransferFrom(decoded.token1, decoded.payer, msg.sender, decoded.amount1);
      }
    }
  }

  struct MintCallbackData {
    address token;
    address payer;
  }

  function mintCallback(uint256 collateral, uint256, uint256, uint256, bytes calldata data) external override {
    MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

    if (decoded.payer == address(this)) {
      SafeTransferLib.safeTransfer(decoded.token, msg.sender, collateral);
    } else {
      SafeTransferLib.safeTransferFrom(decoded.token, decoded.payer, msg.sender, collateral);
    }
  }

  struct SwapCallbackData {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
    address payer;
  }

  function swapCallback(uint256, uint256, bytes calldata data) external override {
    SwapCallbackData memory decoded = abi.decode(data, (SwapCallbackData));

    if (decoded.payer == address(this)) {
      if (decoded.amount0 > 0) SafeTransferLib.safeTransfer(decoded.token0, msg.sender, decoded.amount0);
      if (decoded.amount1 > 0) SafeTransferLib.safeTransfer(decoded.token1, msg.sender, decoded.amount1);
    } else {
      if (decoded.amount0 > 0) {
        SafeTransferLib.safeTransferFrom(decoded.token0, decoded.payer, msg.sender, decoded.amount0);
      }
      if (decoded.amount1 > 0) {
        SafeTransferLib.safeTransferFrom(decoded.token1, decoded.payer, msg.sender, decoded.amount1);
      }
    }
  }
}
