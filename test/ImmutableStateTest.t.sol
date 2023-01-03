// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "../src/core/Factory.sol";
import { Lendgine } from "../src/core/Lendgine.sol";
import { Test } from "forge-std/Test.sol";

contract ImmutableStateTest is Test {
  Factory public factory;
  Lendgine public lendgine;

  function setUp() external {
    factory = new Factory();
    lendgine = Lendgine(factory.createLendgine(address(1), address(2), 18, 18, 1e18));
  }

  function testImmutableState() external {
    assertEq(address(1), lendgine.token0());
    assertEq(address(2), lendgine.token1());
    assertEq(1, lendgine.token0Scale());
    assertEq(1, lendgine.token1Scale());
    assertEq(1e18, lendgine.upperBound());
  }
}
