// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "../src/core/Lendgine.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";
import { FullMath } from "../src/libraries/FullMath.sol";

contract SwapTest is TestHelper {
  event Swap(uint256 amount0Out, uint256 amount1Out, uint256 amount0In, uint256 amount1In, address indexed to);

  uint256 constant SWAP_FEE_VALUE = 3;
  uint256 constant FEE_DENOMINATOR = 1000;

  function setUp() external {
    _setUp();
    _deposit(alice, alice, 1 ether, 8 ether, 1 ether);
  }

  function testSwapFull() external {
    token0.mint(alice, 24 ether);

    vm.prank(alice);
    token0.approve(address(this), 24 ether);

    lendgine.swap(
      alice,
      0,
      8 ether,
      abi.encode(
        SwapCallbackData({ token0: address(token0), token1: address(token1), amount0: 24 ether, amount1: 0, payer: alice })
      )
    );

    // Calculate the swap fee amounts
    uint256 fee0 = FullMath.mulDiv(24 ether, SWAP_FEE_VALUE, FEE_DENOMINATOR);
    uint256 fee1 = 0;

    // Adjust the input amounts by subtracting the swap fees
    uint256 amount0In = 24 ether - fee0;
    uint256 amount1In = 0;

    // check user balances
    assertEq(0, token0.balanceOf(alice));
    assertEq(8 ether, token1.balanceOf(alice));

    // check lendgine storage slots
    assertEq(25 ether, lendgine.reserve0());
    assertEq(0, lendgine.reserve1());
  }

  function testUnderPay() external {
    token0.mint(alice, 23 ether);

    vm.prank(alice);
    token0.approve(address(this), 23 ether);

    vm.expectRevert(Pair.InvariantError.selector);
    lendgine.swap(
      alice,
      0,
      8 ether,
      abi.encode(
        SwapCallbackData({ token0: address(token0), token1: address(token1), amount0: 23 ether, amount1: 0, payer: alice })
      )
    );
  }

  function testEmit() external {
    token0.mint(alice, 24 ether);

    vm.prank(alice);
    token0.approve(address(this), 24 ether);

    // Calculate the swap fee amounts
    uint256 fee0 = FullMath.mulDiv(24 ether, SWAP_FEE_VALUE, FEE_DENOMINATOR);
    uint256 fee1 = 0;

    // Adjust the input amounts by subtracting the swap fees
    uint256 amount0In = 24 ether - fee0;
    uint256 amount1In = 0;


    vm.expectEmit(true, false, false, true, address(lendgine));
    emit Swap(0, 8 ether, 24 ether, 0, alice);
    lendgine.swap(
      alice,
      0,
      8 ether,
      abi.encode(
        SwapCallbackData({ token0: address(token0), token1: address(token1), amount0: 24 ether, amount1: 0, payer: alice })
      )
    );
  }
}
