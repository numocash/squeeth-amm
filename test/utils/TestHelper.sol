// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "../../src/core/Factory.sol";
import { Lendgine } from "../../src/core/Lendgine.sol";
import { Test } from "forge-std/Test.sol";

import { CallbackHelper } from "./CallbackHelper.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

abstract contract TestHelper is Test, CallbackHelper {
  MockERC20 public token0;
  MockERC20 public token1;

  uint8 public token0Scale;
  uint8 public token1Scale;

  uint256 public upperBound;

  Factory public factory;
  Lendgine public lendgine;

  address public cuh;
  address public dennis;

  function mkaddr(string memory name) public returns (address) {
    address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
    vm.label(addr, name);
    return addr;
  }

  constructor() {
    cuh = mkaddr("cuh");
    dennis = mkaddr("dennis");

    token0Scale = 18;
    token1Scale = 18;

    upperBound = 5 * 1e18;
  }

  function _setUp() internal {
    token0 = new MockERC20();
    token1 = new MockERC20();

    factory = new Factory();
    lendgine = Lendgine(factory.createLendgine(address(token0), address(token1), token0Scale, token1Scale, upperBound));
  }

  function _mint(address from, address to, uint256 collateral) internal returns (uint256 shares) {
    token1.mint(from, collateral);

    if (from != address(this)) {
      vm.prank(from);
      token1.approve(address(this), collateral);
    }

    shares = lendgine.mint(to, collateral, abi.encode(MintCallbackData({token: address(token1), payer: from})));
  }

  function _burn(
    address to,
    address from,
    uint256 shares,
    uint256 amount0,
    uint256 amount1
  )
    internal
    returns (uint256 collateral)
  {
    if (from != address(this)) {
      vm.startPrank(from);
      lendgine.transfer(address(lendgine), shares);
      token0.approve(address(this), amount0);
      token1.approve(address(this), amount1);
      vm.stopPrank();
    } else {
      lendgine.transfer(address(lendgine), shares);
    }

    collateral = lendgine.burn(
      to,
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: amount0,
          amount1: amount1,
          payer: from
        })
      )
    );
  }

  function _deposit(
    address to,
    address from,
    uint256 amount0,
    uint256 amount1,
    uint256 liquidity
  )
    internal
    returns (uint256 size)
  {
    token0.mint(from, amount0);
    token1.mint(from, amount1);

    if (from != address(this)) {
      vm.startPrank(from);
      token0.approve(address(this), amount0);
      token1.approve(address(this), amount1);
      vm.stopPrank();
    }

    size = lendgine.deposit(
      to,
      liquidity,
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: amount0,
          amount1: amount1,
          payer: from
        })
      )
    );
  }

  function _withdraw(
    address from,
    address to,
    uint256 size
  )
    internal
    returns (uint256 amount0, uint256 amount1, uint256 liquidity)
  {
    vm.prank(from);
    (amount0, amount1, liquidity) = lendgine.withdraw(to, size);
  }
}
