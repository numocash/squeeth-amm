// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

/// @notice Math library for positions
/// @author Kyle Scott (kyle@numoen.com)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/LiquidityMath.sol)
library PositionMath {
  /// @notice Add a signed size delta to size and revert if it overflows or underflows
  /// @param x The size before change
  /// @param y The delta by which size should be changed
  /// @return z The sizes delta
  function addDelta(uint256 x, int256 y) internal pure returns (uint256 z) {
    if (y < 0) {
      require((z = x - uint256(-y)) < x, "LS");
    } else {
      require((z = x + uint256(y)) >= x, "LA");
    }
  }
}
