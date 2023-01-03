// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { IJumpRate } from "./interfaces/IJumpRate.sol";

abstract contract JumpRate is IJumpRate {
  uint256 public constant override kink = 0.8 ether;

  uint256 public constant override multiplier = 1.375 ether;

  uint256 public constant override jumpMultiplier = 44.5 ether;

  function getBorrowRate(uint256 borrowedLiquidity, uint256 totalLiquidity) public pure override returns (uint256 rate) {
    uint256 util = utilizationRate(borrowedLiquidity, totalLiquidity);

    if (util <= kink) {
      return (util * multiplier) / 1e18;
    } else {
      uint256 normalRate = (kink * multiplier) / 1e18;
      uint256 excessUtil = util - kink;
      return ((excessUtil * jumpMultiplier) / 1e18) + normalRate;
    }
  }

  function getSupplyRate(
    uint256 borrowedLiquidity,
    uint256 totalLiquidity
  )
    external
    pure
    override
    returns (uint256 rate)
  {
    uint256 util = utilizationRate(borrowedLiquidity, totalLiquidity);
    uint256 borrowRate = getBorrowRate(borrowedLiquidity, totalLiquidity);

    return (borrowRate * util) / 1e18;
  }

  function utilizationRate(uint256 borrowedLiquidity, uint256 totalLiquidity) private pure returns (uint256 rate) {
    if (totalLiquidity == 0) return 0;
    return (borrowedLiquidity * 1e18) / totalLiquidity;
  }
}
