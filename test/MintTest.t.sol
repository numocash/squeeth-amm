// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "../src/core/Lendgine.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";

contract MintTest is TestHelper {
    event Mint(address indexed sender, uint256 collateral, uint256 shares, uint256 liquidity, address indexed to);

    event Burn(uint256 amount0Out, uint256 amount1Out, uint256 liquidity, address indexed to);

    function setUp() external {
        _setUp();
        _deposit(address(this), address(this), 1 ether, 8 ether, 1 ether);
    }

    function testMintPartial() external {
        uint256 shares = _mint(cuh, cuh, 5 ether);

        // check lendgine token
        assertEq(0.5 ether, shares);
        assertEq(0.5 ether, lendgine.totalSupply());
        assertEq(0.5 ether, lendgine.balanceOf(cuh));

        // check lendgine storage slots
        assertEq(0.5 ether, lendgine.totalLiquidityBorrowed());
        assertEq(0.5 ether, lendgine.totalLiquidity());
        assertEq(0.5 ether, uint256(lendgine.reserve0()));
        assertEq(4 ether, uint256(lendgine.reserve1()));

        // check lendgine balances
        assertEq(0.5 ether, token0.balanceOf(address(lendgine)));
        assertEq(4 ether + 5 ether, token1.balanceOf(address(lendgine)));

        // check user balances
        assertEq(0.5 ether, token0.balanceOf(cuh));
        assertEq(4 ether, token1.balanceOf(cuh));
    }

    function testMintFull() external {
        uint256 shares = _mint(cuh, cuh, 10 ether);

        // check lendgine token
        assertEq(1 ether, shares);
        assertEq(1 ether, lendgine.totalSupply());
        assertEq(1 ether, lendgine.balanceOf(cuh));

        // check lendgine storage slots
        assertEq(1 ether, lendgine.totalLiquidityBorrowed());
        assertEq(0, lendgine.totalLiquidity());
        assertEq(0, uint256(lendgine.reserve0()));
        assertEq(0, uint256(lendgine.reserve1()));

        // check lendgine balances
        assertEq(0, token0.balanceOf(address(lendgine)));
        assertEq(10 ether, token1.balanceOf(address(lendgine)));

        // check user balances
        assertEq(1 ether, token0.balanceOf(cuh));
        assertEq(8 ether, token1.balanceOf(cuh));
    }

    function testZeroMint() external {
        vm.expectRevert(Lendgine.InputError.selector);
        lendgine.mint(cuh, 0, bytes(""));
    }

    function testOverMint() external {
        vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
        lendgine.mint(cuh, 11 ether, bytes(""));
    }

    // TODO: function test under payment

    function testEmitLendgine() external {
        token1.mint(cuh, 5 ether);

        vm.prank(cuh);
        token1.approve(address(this), 5 ether);

        vm.expectEmit(true, true, false, true, address(lendgine));
        emit Mint(address(this), 5 ether, 0.5 ether, 0.5 ether, cuh);
        lendgine.mint(cuh, 5 ether, abi.encode(MintCallbackData({ token: address(token1), payer: cuh })));
    }

    function testEmitPair() external {
        token1.mint(cuh, 5 ether);

        vm.prank(cuh);
        token1.approve(address(this), 5 ether);

        vm.expectEmit(true, false, false, true, address(lendgine));
        emit Burn(0.5 ether, 4 ether, 0.5 ether, cuh);
        lendgine.mint(cuh, 5 ether, abi.encode(MintCallbackData({ token: address(token1), payer: cuh })));
    }

    // function testProportionalMint
    // function testAccrueOnMint
}
