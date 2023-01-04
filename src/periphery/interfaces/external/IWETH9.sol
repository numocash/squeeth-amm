// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Interface for WETH
interface IWETH9 {
  /// @notice Wraps ETH into WETH
  function deposit() external payable;

  /// @notice Unwraps WETH into ETH
  function withdraw(uint256) external;
}
