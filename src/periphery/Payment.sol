// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import { IWETH9 } from "./interfaces/external/IWETH9.sol";

import { Balance } from "./../libraries/Balance.sol";
import { SafeTransferLib } from "./../libraries/SafeTransferLib.sol";

/// @title   Payment contract
/// @author  https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/PeripheryPayments.sol
/// @notice  Functions to ease deposits and withdrawals of ETH
abstract contract Payment {
  address public immutable weth;

  error InsufficientOutputError();

  constructor(address _weth) {
    weth = _weth;
  }

  receive() external payable {
    require(msg.sender == weth, "Not WETH9");
  }

  function unwrapWETH(uint256 amountMinimum, address recipient) public payable {
    uint256 balanceWETH = Balance.balance(weth);
    if (balanceWETH < amountMinimum) revert InsufficientOutputError();

    if (balanceWETH > 0) {
      IWETH9(weth).withdraw(balanceWETH);
      SafeTransferLib.safeTransferETH(recipient, balanceWETH);
    }
  }

  function sweepToken(address token, uint256 amountMinimum, address recipient) public payable {
    uint256 balanceToken = Balance.balance(token);
    if (balanceToken < amountMinimum) revert InsufficientOutputError();

    if (balanceToken > 0) {
      SafeTransferLib.safeTransfer(token, recipient, balanceToken);
    }
  }

  function refundETH() external payable {
    if (address(this).balance > 0) SafeTransferLib.safeTransferETH(msg.sender, address(this).balance);
  }

  /// @param token The token to pay
  /// @param payer The entity that must pay
  /// @param recipient The entity that will receive payment
  /// @param value The amount to pay
  function pay(address token, address payer, address recipient, uint256 value) internal {
    if (token == weth && address(this).balance >= value) {
      // pay with WETH
      IWETH9(weth).deposit{value: value}(); // wrap only what is needed to pay
      SafeTransferLib.safeTransfer(weth, recipient, value);
    } else if (payer == address(this)) {
      // pay with tokens already in the contract (for the exact input multihop case)
      SafeTransferLib.safeTransfer(token, recipient, value);
    } else {
      // pull payment
      SafeTransferLib.safeTransferFrom(token, payer, recipient, value);
    }
  }
}
