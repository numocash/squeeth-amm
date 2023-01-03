// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

import { IImmutableState } from "./IImmutableState.sol";

/// @notice AMM implementing the capped power invariant
/// @author Kyle Scott (kyle@numoen.com)
interface IPair is IImmutableState {
  /// @notice The amount of token0 in the pair
  function reserve0() external view returns (uint120);

  /// @notice The amount of token1 in the pair
  function reserve1() external view returns (uint120);

  /// @notice The total amount of liquidity shares in the pair
  function totalLiquidity() external view returns (uint256);

  /// @notice The implementation of the capped power invariant
  /// @return valid True if the invariant is satisfied
  function invariant(uint256 amount0, uint256 amount1, uint256 liquidity) external view returns (bool);

  /// @notice Exchange between token0 and token1, either accepts or rejects the proposed trade
  /// @param data The data to be passed through to the callback
  /// @dev A callback is invoked on the caller
  function swap(address to, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external;
}
