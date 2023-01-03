// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ISwapCallback {
  /// @notice Called to `msg.sender` after executing a swap via Pair
  /// @dev In the implementation you must pay the pool tokens owed for the swap.
  /// The caller of this method must be checked to be a Pair deployed by the canonical Factory.
  /// @param data Any data passed through by the caller via the Swap call
  function swapCallback(uint256 amount0Out, uint256 amount1Out, bytes calldata data) external;
}
