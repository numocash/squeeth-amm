// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

/// @notice Immutable state interface
/// @author Kyle Scott (kyle@numoen.com)
interface IImmutableState {
  /// @notice The contract that deployed the lendgine
  function factory() external view returns (address);

  /// @notice The "numeraire" or "base" token in the pair
  function token0() external view returns (address);

  /// @notice The "risky" or "speculative" token in the pair
  function token1() external view returns (address);

  /// @notice Scale required to make token 0 18 decimals
  function token0Scale() external view returns (uint256);

  /// @notice Scale required to make token 1 18 decimals
  function token1Scale() external view returns (uint256);

  /// @notice Maximum exchange rate (token0/token1)
  function upperBound() external view returns (uint256);
}
