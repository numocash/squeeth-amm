// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

import { IPair } from "./IPair.sol";

/// @notice Lending engine for borrowing and lending liquidity provider shares
/// @author Kyle Scott (kyle@numoen.com)
interface ILendgine is IPair {
  /// @notice Returns information about a position given the controllers address
  function positions(address) external view returns (uint256, uint256, uint256);

  /// @notice The total amount of positions issued
  function totalPositionSize() external view returns (uint256);

  /// @notice The total amount of liquidity shares borrowed
  function totalLiquidityBorrowed() external view returns (uint256);

  /// @notice The amount of token1 rewarded to each unit of position
  function rewardPerPositionStored() external view returns (uint256);

  /// @notice The timestamp at which the interest was last accrued
  /// @dev don't downsize because it takes up the last slot
  function lastUpdate() external view returns (uint256);

  /// @notice Mint an option position by providing token1 as collateral and borrowing the max amount of liquidity
  /// @param to The address that receives the underlying tokens of the liquidity that is withdrawn
  /// @param collateral The amount of collateral in the position
  /// @param data The data to be passed through to the callback
  /// @return shares The amount of shares that were minted
  /// @dev A callback is invoked on the caller
  function mint(address to, uint256 collateral, bytes calldata data) external returns (uint256 shares);

  /// @notice Burn an option position by minting the required liquidity and unlocking the collateral
  /// @param to The address to send the unlocked collateral to
  /// @param data The data to be passed through to the callback
  /// @dev Send the amount to burn before calling this function
  /// @dev A callback is invoked on the caller
  function burn(address to, bytes calldata data) external returns (uint256 collateral);

  /// @notice Provide liquidity to the underlying AMM
  /// @param to The address that will control the position
  /// @param liquidity The amount of liquidity shares that will be minted
  /// @param data The data to be passed through to the callback
  /// @return size The size of the position that was minted
  /// @dev A callback is invoked on the caller
  function deposit(address to, uint256 liquidity, bytes calldata data) external returns (uint256 size);

  /// @notice Withdraw liquidity from the underlying AMM
  /// @param to The address to receive the underlying tokens of the AMM
  /// @param size The size of the position to be withdrawn
  /// @return amount0 The amount of token0 that was withdrawn
  /// @return amount1 The amount of token1 that was withdrawn
  /// @return liquidity The amount of liquidity shares that were withdrawn
  function withdraw(address to, uint256 size) external returns (uint256 amount0, uint256 amount1, uint256 liquidity);

  /// @notice Accrues the global interest by decreasing the total amount of liquidity owed by borrowers and rewarding
  /// lenders with the borrowers collateral
  function accrueInterest() external;

  /// @notice Accrues interest for the caller's liquidity position
  /// @dev Reverts if the sender doesn't have a position
  function accruePositionInterest() external;

  /// @notice Collects the interest that has been gathered to a liquidity position
  /// @param to The address that recieves the collected interest
  /// @param collateralRequested The amount of interest to collect
  /// @return collateral The amount of interest that was actually collected
  function collect(address to, uint256 collateralRequested) external returns (uint256 collateral);

  /// @notice Accounting logic for converting liquidity to share amount
  function convertLiquidityToShare(uint256 liquidity) external view returns (uint256);

  /// @notice Accounting logic for converting share amount to liqudity
  function convertShareToLiquidity(uint256 shares) external view returns (uint256);

  /// @notice Accounting logic for converting collateral amount to liquidity
  function convertCollateralToLiquidity(uint256 collateral) external view returns (uint256);

  /// @notice Accounting logic for converting liquidity to collateral amount
  function convertLiquidityToCollateral(uint256 liquidity) external view returns (uint256);
}
