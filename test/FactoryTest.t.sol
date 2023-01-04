// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "../src/core/Factory.sol";
import { Lendgine } from "../src/core/Lendgine.sol";
import { Test } from "forge-std/Test.sol";

import { LendgineAddress } from "../src/periphery/libraries/LendgineAddress.sol";

contract FactoryTest is Test {
  event LendgineCreated(
    address indexed token0,
    address indexed token1,
    uint256 token0Scale,
    uint256 token1Scale,
    uint256 indexed upperBound,
    address lendgine
  );

  Factory public factory;

  function setUp() external {
    factory = new Factory();
  }

  function testGetLendgine() external {
    address lendgine = factory.createLendgine(address(1), address(2), 18, 18, 1e18);

    assertEq(lendgine, factory.getLendgine(address(1), address(2), 18, 18, 1e18));
  }

  function testDeployAddress() external {
    address lendgineEstimate = LendgineAddress.computeAddress(address(factory), address(1), address(2), 18, 18, 1e18);

    address lendgine = factory.createLendgine(address(1), address(2), 18, 18, 1e18);

    assertEq(lendgine, lendgineEstimate);
  }

  function testSameTokenError() external {
    vm.expectRevert(Factory.SameTokenError.selector);
    factory.createLendgine(address(1), address(1), 18, 18, 1e18);
  }

  function testZeroAddressError() external {
    vm.expectRevert(Factory.ZeroAddressError.selector);
    factory.createLendgine(address(0), address(1), 18, 18, 1e18);

    vm.expectRevert(Factory.ZeroAddressError.selector);
    factory.createLendgine(address(1), address(0), 18, 18, 1e18);
  }

  function testDeployedError() external {
    factory.createLendgine(address(1), address(2), 18, 18, 1e18);

    vm.expectRevert(Factory.DeployedError.selector);
    factory.createLendgine(address(1), address(2), 18, 18, 1e18);
  }

  function helpParametersZero() private {
    (address token0, address token1, uint256 token0Scale, uint256 token1Scale, uint256 upperBound) =
      factory.parameters();

    assertEq(address(0), token0);
    assertEq(address(0), token1);
    assertEq(0, token0Scale);
    assertEq(0, token1Scale);
    assertEq(0, upperBound);
  }

  function testParameters() external {
    helpParametersZero();

    factory.createLendgine(address(1), address(2), 18, 18, 1e18);

    helpParametersZero();
  }

  function testEmit() external {
    address lendgineEstimate = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              address(factory),
              keccak256(abi.encode(address(1), address(2), 18, 18, 1e18)),
              keccak256(type(Lendgine).creationCode)
            )
          )
        )
      )
    );
    vm.expectEmit(true, true, true, true, address(factory));
    emit LendgineCreated(address(1), address(2), 18, 18, 1e18, lendgineEstimate);
    factory.createLendgine(address(1), address(2), 18, 18, 1e18);
  }
}
