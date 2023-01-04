// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

/// @notice An implementation of the Jump Rate model for interest rates
/// @author Kyle Scott (kyle@numoen.com)
/// @author Modified from Compound
/// (https://github.com/compound-finance/compound-protocol/blob/master/contracts/JumpRateModel.sol)
interface IJumpRate {
  function kink() external view returns (uint256 kink);

  function multiplier() external view returns (uint256 multiplier);

  function jumpMultiplier() external view returns (uint256 jumpMultiplier);

  function getBorrowRate(uint256 borrowedLiquidity, uint256 totalLiquidity) external view returns (uint256 rate);

  function getSupplyRate(uint256 borrowedLiquidity, uint256 totalLiquidity) external view returns (uint256 rate);
}
