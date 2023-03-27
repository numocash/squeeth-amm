// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { CREATE3Factory } from "create3-factory/CREATE3Factory.sol";

import { Factory } from "src/core/Factory.sol";
import { LiquidityManager } from "src/periphery/LiquidityManager.sol";
import { LendgineRouter } from "src/periphery/LendgineRouter.sol";

contract Deploy is Script {
  address constant create3Factory = 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1;

  address constant uniV2Factory = 0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32;
  address constant uniV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

  address constant weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

  function run() external returns (address factory, address liquidityManager, address lendgineRouter) {
    CREATE3Factory create3 = CREATE3Factory(create3Factory);

    uint256 pk = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(pk);

    factory = create3.deploy(keccak256("NumoenFactory"), type(Factory).creationCode);

    liquidityManager = create3.deploy(
      keccak256("NumoenLiquidityManager"), bytes.concat(type(LiquidityManager).creationCode, abi.encode(factory, weth))
    );

    lendgineRouter = create3.deploy(
      keccak256("NumoenLendgineRouter"),
      bytes.concat(type(LendgineRouter).creationCode, abi.encode(factory, uniV2Factory, uniV3Factory, weth))
    );
  }
}
