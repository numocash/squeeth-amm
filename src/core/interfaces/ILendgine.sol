// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

import { IPair } from "./IPair.sol";

interface ILendgine is IPair {
  /// @notice
  function positions(address) external view returns (uint256, uint256, uint256);

  function totalPositionSize() external view returns (uint256);

  function totalLiquidityBorrowed() external view returns (uint256);

  function rewardPerPositionStored() external view returns (uint256);

  function lastUpdate() external view returns (uint256);

  function mint(address to, uint256 collateral, bytes calldata data) external returns (uint256 shares);

  function burn(address to, bytes calldata data) external returns (uint256 collateral);

  function deposit(address to, uint256 liquidity, bytes calldata data) external returns (uint256 size);

  function withdraw(address to, uint256 size) external returns (uint256 amount0, uint256 amount1, uint256 liquidity);

  function accrueInterest() external;

  function accruePositionInterest() external;

  function collect(address to, uint256 collateralRequested) external returns (uint256 collateral);

  //         function convertLiquidityToShare(uint256 liquidity) public view returns (uint256) {
  //     uint256 _totalLiquidityBorrowed = totalLiquidityBorrowed; // SLOAD
  //     return
  //         _totalLiquidityBorrowed == 0 ? liquidity : FullMath.mulDiv(liquidity, totalSupply,
  // _totalLiquidityBorrowed);
  // }

  // function convertShareToLiquidity(uint256 shares) public view returns (uint256) {
  //     return FullMath.mulDiv(totalLiquidityBorrowed, shares, totalSupply);
  // }

  // function convertCollateralToLiquidity(uint256 collateral) public view returns (uint256) {
  //     return FullMath.mulDiv(collateral * token1Scale, 1e18, 2 * upperBound);
  // }

  // function convertLiquidityToCollateral(uint256 liquidity) public view returns (uint256) {
  //     return FullMath.mulDiv(liquidity, 2 * upperBound, 1e18) / token1Scale;
  // }
}
