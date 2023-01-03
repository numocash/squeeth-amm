// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "../src/core/Lendgine.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";

contract AccrueInterestTest is TestHelper {
  event AccrueInterest(uint256 timeElapsed, uint256 collateral, uint256 liquidity);

  function setUp() external {
    _setUp();
  }

  function testAccrueNoLiquidity() external {
    lendgine.accrueInterest();

    assertEq(1, lendgine.lastUpdate());
    assertEq(0, lendgine.rewardPerPositionStored());
    assertEq(0, lendgine.totalLiquidityBorrowed());
  }

  function testAccrueNoTime() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    lendgine.accrueInterest();

    assertEq(1, lendgine.lastUpdate());
    assertEq(0, lendgine.rewardPerPositionStored());
    assertEq(0.5 ether, lendgine.totalLiquidityBorrowed());
  }

  function testAccrueInterest() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.warp(365 days + 1);

    lendgine.accrueInterest();

    uint256 borrowRate = lendgine.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year
    uint256 token1Dilution = 10 * lpDilution; // same as rewardPerPosition because position size is 1

    assertEq(365 days + 1, lendgine.lastUpdate());
    assertEq(0.5 ether - lpDilution, lendgine.totalLiquidityBorrowed());
    assertEq(token1Dilution, lendgine.rewardPerPositionStored());
  }

  function testMaxDilution() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.warp(730 days + 1);

    lendgine.accrueInterest();

    assertEq(730 days + 1, lendgine.lastUpdate());
    assertEq(0, lendgine.totalLiquidityBorrowed());
    assertEq(5 ether, lendgine.rewardPerPositionStored());
  }

  function testLendgineEmit() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.warp(365 days + 1);

    uint256 borrowRate = lendgine.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year
    uint256 token1Dilution = 10 * lpDilution; // same as rewardPerPosition because position size is 1

    vm.expectEmit(false, false, false, true, address(lendgine));
    emit AccrueInterest(365 days, token1Dilution, lpDilution);
    lendgine.accrueInterest();
  }

  function testNonStandardDecimals() external {
    token1Scale = 9;

    lendgine = Lendgine(factory.createLendgine(address(token0), address(token1), token0Scale, token1Scale, upperBound));

    token0.mint(address(this), 1e18);
    token1.mint(address(this), 8 * 1e9);

    lendgine.deposit(
      address(this),
      1 ether,
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: 1e18,
          amount1: 8 * 1e9,
          payer: address(this)
        })
      )
    );

    token1.mint(cuh, 5 * 1e9);

    vm.prank(cuh);
    token1.approve(address(this), 5 * 1e9);
    lendgine.mint(cuh, 5 * 1e9, abi.encode(MintCallbackData({token: address(token1), payer: cuh})));

    vm.warp(365 days + 1);

    lendgine.accrueInterest();

    uint256 borrowRate = lendgine.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year
    uint256 token1Dilution = lendgine.convertLiquidityToCollateral(lpDilution); // same as rewardPerPosition because
    // position size is 1

    assertEq(0.5 ether - lpDilution, lendgine.totalLiquidityBorrowed());
    assertEq(token1Dilution, lendgine.rewardPerPositionStored());
  }
}
