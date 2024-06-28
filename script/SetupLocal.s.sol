// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { console2 } from "forge-std/console2.sol";

import { Factory } from "../src/core/Factory.sol";
import { LiquidityManager } from "../src/periphery/LiquidityManager.sol";
import { LendgineRouter } from "../src/periphery/LendgineRouter.sol";
import { SwapHelper } from "../src/periphery/SwapHelper.sol";
import { ERC20 } from "../src/core/ERC20.sol";
import { IWETH9 } from "../src/periphery/interfaces/external/IWETH9.sol";
import { UniswapV2Library } from "../src/periphery/UniswapV2/libraries/UniswapV2Library.sol";
import { IUniswapV2Pair } from "../src/periphery/UniswapV2/interfaces/IUniswapV2Pair.sol";

// returns the reserves for one unit of liquidity
/// @dev has precision errors for large and small price values
function priceToReserves(uint256 price, uint256 bound) pure returns (uint256 reserve0, uint256 reserve1) {
  reserve0 = (price * price) / 1e18;
  reserve1 = 2 * (bound - price);
}

contract SetupLocalScript is Script {
  address constant uniV2Factory = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
  address constant uniV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

  address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // has 6 decimals
  address constant uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

  uint256 immutable usdcWethPrice = uniV2Price(usdc, weth) * 10 ** 12;
  uint256 immutable wethUniPrice = uniV2Price(weth, uni);
  uint256 immutable uniWethPrice = uniV2Price(uni, weth);

  uint256 constant usdcWethBound = 3000 * 10 ** 18; // TODO: adjust for decimals
  uint256 constant wethUniBound = 15 * 10 ** 16;
  uint256 constant uniWethBound = 60 * 10 ** 18;

  function uniV2Price(address base, address quote) internal view returns (uint256 price) {
    address pair = UniswapV2Library.pairFor(uniV2Factory, base, quote);

    (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();

    bool inverse = base > quote;

    price = inverse ? (reserve1 * 1e18) / reserve0 : (reserve0 * 1e18) / reserve1;
  }

  function run() public {
    string memory mnemonic = "test test test test test test test test test test test junk";
    uint256 pk = vm.deriveKey(mnemonic, 0);
    address addr = vm.addr(pk);

    // deploy core contracts
    vm.startBroadcast(pk);
    Factory factory = new Factory{salt: keccak256("NumoFactoryTest1")}();
    LiquidityManager liquidityManager =
      new LiquidityManager{salt: keccak256("NumoLiquidityManagerTest1")}(address(factory), weth);
    LendgineRouter lendgineRouter = new LendgineRouter{salt: keccak256("NumoLendgineRouterTest1")}(
      address(factory),
      uniV2Factory,
      uniV3Factory,
      weth
    );

    // deploy new lendgines
    console2.log("usdc/weth lendgine: ", factory.createLendgine(usdc, weth, 6, 18, usdcWethBound));
    console2.log("weth/uni lendgine: ", factory.createLendgine(weth, uni, 18, 18, wethUniBound));
    console2.log("uni/weth lendgine: ", factory.createLendgine(uni, weth, 18, 18, uniWethBound));

    // mint tokens to addr
    IWETH9(weth).deposit{ value: 100 ether }();

    // add liquidity to each market
    ERC20(weth).approve(address(liquidityManager), 50 * 1e18);
    ERC20(usdc).approve(address(liquidityManager), 50 * 1e6);
    ERC20(uni).approve(address(liquidityManager), 50 * 1e18);

    uint256 reserveWeth;
    uint256 reserveUsdc;
    uint256 reserveUni;
    (reserveUsdc, reserveWeth) = priceToReserves(usdcWethPrice, usdcWethBound);
    liquidityManager.addLiquidity(
      LiquidityManager.AddLiquidityParams({
        token0: usdc,
        token1: weth,
        token0Exp: 6,
        token1Exp: 18,
        strike: usdcWethBound,
        liquidity: 1 ether / 1e5,
        amount0Min: (reserveUsdc / 1e17) + 1,
        amount1Min: (reserveWeth / 1e5) + 1,
        sizeMin: 1 ether / 1e5,
        recipient: addr,
        deadline: block.timestamp + 120
      })
    );
    (reserveWeth, reserveUni) = priceToReserves(wethUniPrice, wethUniBound);
    liquidityManager.addLiquidity(
      LiquidityManager.AddLiquidityParams({
        token0: weth,
        token1: uni,
        token0Exp: 18,
        token1Exp: 18,
        strike: wethUniBound,
        liquidity: 1 ether * 1e2,
        amount0Min: (reserveWeth * 1e2) + 100,
        amount1Min: (reserveUni * 1e2) + 100,
        sizeMin: 1 ether * 1e2,
        recipient: addr,
        deadline: block.timestamp + 120
      })
    );
    (reserveWeth, reserveUni) = priceToReserves(uniWethPrice, uniWethBound);
    liquidityManager.addLiquidity(
      LiquidityManager.AddLiquidityParams({
        token0: uni,
        token1: weth,
        token0Exp: 18,
        token1Exp: 18,
        strike: uniWethBound,
        liquidity: 1 ether / 20,
        amount0Min: (reserveWeth / 20) + 20,
        amount1Min: (reserveUni / 20) + 20,
        sizeMin: 1 ether / 20,
        recipient: addr,
        deadline: block.timestamp + 120
      })
    );

    // borrow from market
    ERC20(uni).approve(address(lendgineRouter), 50 * 1e18);

    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: weth,
        token1: uni,
        token0Exp: 18,
        token1Exp: 18,
        strike: wethUniBound,
        amountIn: 1e18,
        amountBorrow: 4 * 1e18,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: addr,
        deadline: block.timestamp + 120
      })
    );

    vm.stopBroadcast();
  }
}
