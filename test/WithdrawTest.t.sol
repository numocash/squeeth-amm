// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "../src/core/Lendgine.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";

contract WithdrawTest is TestHelper {
    event Withdraw(address indexed sender, uint256 size, uint256 liquidity, address indexed to);

    event Burn(uint256 amount0Out, uint256 amount1Out, uint256 liquidity, address indexed to);

    function setUp() external {
        _setUp();

        _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    }

    function testWithdrawPartial() external {
        uint256 liquidity = _withdraw(cuh, cuh, 0.5 ether);

        assertEq(liquidity, 0.5 ether);

        assertEq(0.5 ether, lendgine.totalLiquidity());
        assertEq(0.5 ether, lendgine.totalPositionSize());

        assertEq(0.5 ether, uint256(lendgine.reserve0()));
        assertEq(4 ether, uint256(lendgine.reserve1()));
        assertEq(0.5 ether, token0.balanceOf(address(lendgine)));
        assertEq(4 ether, token1.balanceOf(address(lendgine)));

        assertEq(0.5 ether, token0.balanceOf(address(cuh)));
        assertEq(4 ether, token1.balanceOf(address(cuh)));

        (uint256 positionSize, , ) = lendgine.positions(cuh);
        assertEq(0.5 ether, positionSize);
    }

    function testWithdrawFull() external {
        uint256 liquidity = _withdraw(cuh, cuh, 1 ether);

        assertEq(liquidity, 1 ether);

        assertEq(0, lendgine.totalLiquidity());
        assertEq(0, lendgine.totalPositionSize());

        assertEq(0, uint256(lendgine.reserve0()));
        assertEq(0, uint256(lendgine.reserve1()));
        assertEq(0, token0.balanceOf(address(lendgine)));
        assertEq(0, token1.balanceOf(address(lendgine)));

        assertEq(1 ether, token0.balanceOf(address(cuh)));
        assertEq(8 ether, token1.balanceOf(address(cuh)));

        (uint256 positionSize, , ) = lendgine.positions(cuh);
        assertEq(0, positionSize);
    }

    function testEmitLendgine() external {
        vm.expectEmit(true, true, false, true, address(lendgine));
        emit Withdraw(cuh, 1 ether, 1 ether, cuh);
        _withdraw(cuh, cuh, 1 ether);
    }

    function testEmitPair() external {
        vm.expectEmit(true, false, false, true, address(lendgine));
        emit Burn(1 ether, 8 ether, 1 ether, cuh);
        _withdraw(cuh, cuh, 1 ether);
    }

    function testZeroWithdraw() external {
        vm.expectRevert(Lendgine.InputError.selector);
        _withdraw(cuh, cuh, 0);
    }

    function testOverWithdraw() external {
        vm.expectRevert(Lendgine.InsufficientPositionError.selector);
        _withdraw(cuh, cuh, 2 ether);
    }

    function testCompleteUtilization() external {
        _mint(address(this), address(this), 5 ether);

        vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
        _withdraw(cuh, cuh, 0.6 ether);
    }

    // function testAccrueOnWithdraw

    // function testPositionSize
}
