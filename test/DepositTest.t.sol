// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "../src/core/Lendgine.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";

contract DepositTest is TestHelper {
    event Deposit(address indexed sender, uint256 size, uint256 liquidity, address indexed to);

    event Mint(uint256 amount0In, uint256 amount1In, uint256 liquidity);

    function setUp() external {
        _setUp();
    }

    function testBasicDeposit() external {
        uint256 size = _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);

        assertEq(1 ether, size);

        assertEq(1 ether, lendgine.totalLiquidity());
        assertEq(1 ether, lendgine.totalPositionSize());
        assertEq(1 ether, uint256(lendgine.reserve0()));
        assertEq(8 ether, uint256(lendgine.reserve1()));
        assertEq(1 ether, token0.balanceOf(address(lendgine)));
        assertEq(8 ether, token1.balanceOf(address(lendgine)));

        (uint256 positionSize, , ) = lendgine.positions(cuh);
        assertEq(1 ether, positionSize);
    }

    function testZeroMint() external {
        vm.expectRevert(Lendgine.InputError.selector);
        lendgine.deposit(cuh, 0, bytes(""));
    }

    function testUnderPayment() external {
        token0.mint(cuh, 1 ether);
        token1.mint(cuh, 7 ether);

        vm.startPrank(cuh);
        token0.approve(address(this), 1 ether);
        token1.approve(address(this), 7 ether);
        vm.stopPrank();

        vm.expectRevert(Pair.InvariantError.selector);
        lendgine.deposit(
            cuh,
            1 ether,
            abi.encode(
                PairMintCallbackData({
                    token0: address(token0),
                    token1: address(token1),
                    amount0: 1 ether,
                    amount1: 7 ether,
                    payer: cuh
                })
            )
        );
    }

    function testEmitLendgine() external {
        token0.mint(cuh, 1 ether);
        token1.mint(cuh, 8 ether);

        vm.startPrank(cuh);
        token0.approve(address(this), 1 ether);
        token1.approve(address(this), 8 ether);
        vm.stopPrank();

        vm.expectEmit(true, true, false, true, address(lendgine));
        emit Deposit(address(this), 1 ether, 1 ether, cuh);
        lendgine.deposit(
            cuh,
            1 ether,
            abi.encode(
                PairMintCallbackData({
                    token0: address(token0),
                    token1: address(token1),
                    amount0: 1 ether,
                    amount1: 8 ether,
                    payer: cuh
                })
            )
        );
    }

    function testEmitPair() external {
        token0.mint(cuh, 1 ether);
        token1.mint(cuh, 8 ether);

        vm.startPrank(cuh);
        token0.approve(address(this), 1 ether);
        token1.approve(address(this), 8 ether);
        vm.stopPrank();

        vm.expectEmit(false, false, false, true, address(lendgine));
        emit Mint(1 ether, 8 ether, 1 ether);
        lendgine.deposit(
            cuh,
            1 ether,
            abi.encode(
                PairMintCallbackData({
                    token0: address(token0),
                    token1: address(token1),
                    amount0: 1 ether,
                    amount1: 8 ether,
                    payer: cuh
                })
            )
        );
    }

    function testAccrueOnDepositEmpty() external {
        _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);

        assertEq(1, lendgine.lastUpdate());
    }

    // function testAccrueOnDeposit();
    // function testProportionPositionSize();
}
