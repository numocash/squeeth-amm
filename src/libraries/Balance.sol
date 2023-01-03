// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

/// @notice Library for safely and cheaply reading balances
/// @author Kyle Scott (kyle@numoen.com)
/// @author Modified from UniswapV3Pool
/// (https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L140-L145)
library Balance {
  error BalanceReturnError();

  /// @notice Determine the callers balance of the specified token
  function balance(address token) internal view returns (uint256) {
    (bool success, bytes memory data) =
      token.staticcall(abi.encodeWithSelector(bytes4(keccak256(bytes("balanceOf(address)"))), address(this)));
    if (!success || data.length < 32) revert BalanceReturnError();
    return abi.decode(data, (uint256));
  }
}
