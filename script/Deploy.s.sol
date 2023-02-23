// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { Factory } from "src/core/Factory.sol";
import { LiquidityManager } from "src/periphery/LiquidityManager.sol";
import { LendgineRouter } from "src/periphery/LendgineRouter.sol";
import { Lendgine } from "src/core/Lendgine.sol";

contract Deploy is Script {
  address constant uniV2Factory = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
  address constant uniV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

  address constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

  function run() external returns (Factory, LiquidityManager, LendgineRouter) {
    uint256 pk = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(pk);
    Factory factory = new Factory{salt: keccak256("NumoenFactoryTest1")}();
    LiquidityManager liquidityManager =
      new LiquidityManager{salt: keccak256("NumoenLiquidityManagerTest1")}(address(factory), weth);
    LendgineRouter lendgineRouter =
    new LendgineRouter{salt: keccak256("NumoenLendgineRouterTest1")}(address(factory), uniV2Factory, uniV3Factory,
    weth);

    return (factory, liquidityManager, lendgineRouter);
  }
}
