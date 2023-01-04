// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

/// @notice Library for safely and cheaply casting solidity types
/// @author Kyle Scott (kyle@numoen.com)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/SafeCast.sol)
library SafeCast {
  function toUint120(uint256 y) internal pure returns (uint120 z) {
    require((z = uint120(y)) == y);
  }

  /// @notice Cast a uint256 to a int256, revert on overflow
  /// @param y The uint256 to be casted
  /// @return z The casted integer, now type int256
  function toInt256(uint256 y) internal pure returns (int256 z) {
    require(y < 2 ** 255);
    z = int256(y);
  }
}
