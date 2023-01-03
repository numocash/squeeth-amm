// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "../src/core/Lendgine.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";
import { FullMath } from "../src/libraries/FullMath.sol";

contract BurnTest is TestHelper {
  event Burn(address indexed sender, uint256 collateral, uint256 shares, uint256 liquidity, address indexed to);

  event Mint(uint256 amount0In, uint256 amount1In, uint256 liquidity);

  function setUp() external {
    _setUp();
    _deposit(address(this), address(this), 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);
  }

  function testBurnPartial() external {
    uint256 collateral = _burn(cuh, cuh, 0.25 ether, 0.25 ether, 2 ether);

    // check returned tokens
    assertEq(2.5 ether, collateral);
    assertEq(0.25 ether, token0.balanceOf(cuh));
    assertEq(2 ether + 2.5 ether, token1.balanceOf(cuh));

    // check lendgine token
    assertEq(0.25 ether, lendgine.totalSupply());
    assertEq(0.25 ether, lendgine.balanceOf(cuh));

    // check storage slots
    assertEq(0.25 ether, lendgine.totalLiquidityBorrowed());
    assertEq(0.75 ether, lendgine.totalLiquidity());
    assertEq(0.75 ether, uint256(lendgine.reserve0()));
    assertEq(6 ether, uint256(lendgine.reserve1()));

    // check lendgine balances
    assertEq(0.75 ether, token0.balanceOf(address(lendgine)));
    assertEq(2.5 ether + 6 ether, token1.balanceOf(address(lendgine)));
  }

  function testBurnFull() external {
    uint256 collateral = _burn(cuh, cuh, 0.5 ether, 0.5 ether, 4 ether);

    // check returned tokens
    assertEq(5 ether, collateral);
    assertEq(0 ether, token0.balanceOf(cuh));
    assertEq(5 ether, token1.balanceOf(cuh));

    // check lendgine token
    assertEq(0 ether, lendgine.totalSupply());
    assertEq(0 ether, lendgine.balanceOf(cuh));

    // check storage slots
    assertEq(0 ether, lendgine.totalLiquidityBorrowed());
    assertEq(1 ether, lendgine.totalLiquidity());
    assertEq(1 ether, uint256(lendgine.reserve0()));
    assertEq(8 ether, uint256(lendgine.reserve1()));

    // check lendgine balances
    assertEq(1 ether, token0.balanceOf(address(lendgine)));
    assertEq(8 ether, token1.balanceOf(address(lendgine)));
  }

  function testZeroBurn() external {
    vm.expectRevert(Lendgine.InputError.selector);
    lendgine.burn(cuh, bytes(""));
  }

  function testUnderPay() external {
    vm.prank(cuh);
    lendgine.transfer(address(lendgine), 0.5 ether);

    vm.startPrank(cuh);
    token0.approve(address(this), 0.5 ether);
    token1.approve(address(this), 3 ether);
    vm.stopPrank();

    vm.expectRevert(Pair.InvariantError.selector);
    lendgine.burn(
      cuh,
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: 0.5 ether,
          amount1: 3 ether,
          payer: cuh
        })
      )
    );
  }

  function testEmitLendgine() external {
    vm.prank(cuh);
    lendgine.transfer(address(lendgine), 0.5 ether);

    vm.startPrank(cuh);
    token0.approve(address(this), 0.5 ether);
    token1.approve(address(this), 4 ether);
    vm.stopPrank();

    vm.expectEmit(true, true, false, true, address(lendgine));
    emit Burn(address(this), 5 ether, 0.5 ether, 0.5 ether, cuh);
    lendgine.burn(
      cuh,
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: 0.5 ether,
          amount1: 4 ether,
          payer: cuh
        })
      )
    );
  }

  function testEmitPair() external {
    vm.prank(cuh);
    lendgine.transfer(address(lendgine), 0.5 ether);

    vm.startPrank(cuh);
    token0.approve(address(this), 0.5 ether);
    token1.approve(address(this), 4 ether);
    vm.stopPrank();

    vm.expectEmit(false, false, false, true, address(lendgine));
    emit Mint(0.5 ether, 4 ether, 0.5 ether);
    lendgine.burn(
      cuh,
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: 0.5 ether,
          amount1: 4 ether,
          payer: cuh
        })
      )
    );
  }

  function testAccrueOnBurn() external {
    vm.warp(365 days + 1);
    lendgine.accrueInterest();

    uint256 reserve0 = lendgine.reserve0();
    uint256 reserve1 = lendgine.reserve1();

    uint256 amount0 =
      FullMath.mulDivRoundingUp(reserve0, lendgine.convertShareToLiquidity(0.5 ether), lendgine.totalLiquidity());
    uint256 amount1 =
      FullMath.mulDivRoundingUp(reserve1, lendgine.convertShareToLiquidity(0.5 ether), lendgine.totalLiquidity());

    _burn(cuh, cuh, 0.5 ether, amount0, amount1);

    assertEq(365 days + 1, lendgine.lastUpdate());
    assert(lendgine.rewardPerPositionStored() != 0);
  }

  function testProportionalBurn() external {
    vm.warp(365 days + 1);
    lendgine.accrueInterest();

    uint256 borrowRate = lendgine.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year

    uint256 reserve0 = lendgine.reserve0();
    uint256 reserve1 = lendgine.reserve1();
    uint256 shares = 0.25 ether;

    uint256 amount0 =
      FullMath.mulDivRoundingUp(reserve0, lendgine.convertShareToLiquidity(shares), lendgine.totalLiquidity());
    uint256 amount1 =
      FullMath.mulDivRoundingUp(reserve1, lendgine.convertShareToLiquidity(shares), lendgine.totalLiquidity());

    uint256 collateral = _burn(cuh, cuh, shares, amount0, amount1);

    // check collateral returned
    assertEq(5 * (0.5 ether - lpDilution), collateral); // withdrew half the collateral

    // check lendgine storage slots
    assertEq((0.5 ether - lpDilution) / 2, lendgine.totalLiquidityBorrowed()); // withdrew half the liquidity
    assertEq(0.5 ether + (0.5 ether - lpDilution) / 2, lendgine.totalLiquidity());
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

    token1.mint(address(this), 5 * 1e9);

    lendgine.mint(address(this), 5 * 1e9, abi.encode(MintCallbackData({token: address(token1), payer: address(this)})));

    lendgine.transfer(address(lendgine), 0.25 ether);

    uint256 collateral = lendgine.burn(
      address(this),
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: 0.25 ether,
          amount1: 2 * 1e9,
          payer: address(this)
        })
      )
    );

    // check returned tokens
    assertEq(2.5 * 1e9, collateral);
    assertEq(0.25 ether, token0.balanceOf(address(this)));
    assertEq(4.5 * 1e9, token1.balanceOf(address(this)));

    // check lendgine token
    assertEq(0.25 ether, lendgine.totalSupply());
    assertEq(0.25 ether, lendgine.balanceOf(address(this)));

    // check storage slots
    assertEq(0.25 ether, lendgine.totalLiquidityBorrowed());
    assertEq(0.75 ether, lendgine.totalLiquidity());
    assertEq(0.75 ether, uint256(lendgine.reserve0()));
    assertEq(6 * 1e9, uint256(lendgine.reserve1()));

    // check lendgine balances
    assertEq(0.75 ether, token0.balanceOf(address(lendgine)));
    assertEq(8.5 * 1e9, token1.balanceOf(address(lendgine)));
  }
}
