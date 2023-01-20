// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "../src/core/Lendgine.sol";
import { LendgineRouter } from "../src/periphery/LendgineRouter.sol";
import { SwapHelper } from "../src/periphery/SwapHelper.sol";
import { TestHelper } from "./utils/TestHelper.sol";
import { MockERC20 } from "./utils/mocks/MockERC20.sol";

import { IUniswapV2Factory } from "../src/periphery/UniswapV2/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../src/periphery/UniswapV2/interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Factory } from "../src/periphery/UniswapV3/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "../src/periphery/UniswapV3/interfaces/IUniswapV3Pool.sol";

contract LendgineRouterTest is TestHelper {
  event Mint(address indexed from, address indexed lendgine, uint256 collateral, uint256 shares, address indexed to);

  event Burn(address indexed from, address indexed lendgine, uint256 collateral, uint256 shares, address indexed to);

  LendgineRouter public lendgineRouter;

  IUniswapV2Factory public uniswapV2Factory = IUniswapV2Factory(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
  IUniswapV2Pair public uniswapV2Pair;
  IUniswapV3Factory public uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
  IUniswapV3Pool public uniswapV3Pool = IUniswapV3Pool(0x07A4f63f643fE39261140DF5E613b9469eccEC86); // uni / eth 5 bps

  // pool

  function setUp() external {
    // use goerli from a block where we know we can get tokens
    vm.createSelectFork("goerli");
    vm.rollFork(8_345_575);

    _setUp();
    lendgineRouter = new LendgineRouter(
      address(factory),
      address(uniswapV2Factory),
      address(uniswapV3Factory),
      address(0)
    );

    // set up the uniswap v2 pair
    uniswapV2Pair = IUniswapV2Pair(uniswapV2Factory.createPair(address(token0), address(token1)));
    token0.mint(address(uniswapV2Pair), 100 ether);
    token1.mint(address(uniswapV2Pair), 100 ether);
    uniswapV2Pair.mint(address(this));

    _deposit(address(this), address(this), 100 ether, 800 ether, 100 ether);
  }

  function setUpUniswapV3() internal {
    // change tokens
    token0 = MockERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984); // UNI
    token1 = MockERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6); // WETH

    // get tokens
    vm.prank(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    token0.transfer(cuh, 100 ether);

    vm.prank(0xb3A16C2B68BBB0111EbD27871a5934b949837D95);
    token1.transfer(cuh, 100 ether);

    // deploy lendgine
    lendgine = Lendgine(factory.createLendgine(address(token0), address(token1), 18, 18, 3 ether));

    // deposit tokens
    vm.startPrank(cuh);
    token0.approve(address(this), 5.40225 ether);
    token1.approve(address(this), 45.3 ether);
    vm.stopPrank();

    // price is .735 weth / uni
    lendgine.deposit(
      address(this),
      10 ether,
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: 5.40225 ether,
          amount1: 45.3 ether,
          payer: cuh
        })
      )
    );
  }

  function testMintNoBorrow() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 0,
        sharesMin: 0.1 ether,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    // check option amounts
    assertEq(0.1 ether, lendgine.totalSupply());
    assertEq(0.1 ether, lendgine.balanceOf(cuh));

    // check uniswap
    // swap 0.1 ether of token 0 to token 1
    assertEq(100.1 ether, token0.balanceOf(address(uniswapV2Pair)));
    assertApproxEqRel(99.9 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check lendgine storage
    assertEq(0.1 ether, lendgine.totalLiquidityBorrowed());

    // check user balances
    assertApproxEqRel(0.9 ether, token1.balanceOf(cuh), 1 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testMintBorrow() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 8.8 ether,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    // check option amounts
    assertEq(0.98 ether, lendgine.totalSupply());
    assertEq(0.98 ether, lendgine.balanceOf(cuh));

    // check uniswap
    // swap 0.98 ether of token 0 to token 1
    assertEq(100.98 ether, token0.balanceOf(address(uniswapV2Pair)));
    assertApproxEqRel(99.02 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check lendgine storage
    assertEq(0.98 ether, lendgine.totalLiquidityBorrowed());

    // check user balances
    assertApproxEqRel(0, token1.balanceOf(cuh), 1 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testMintV3() external {
    setUpUniswapV3();

    uint256 balance0Before = token0.balanceOf(address(uniswapV3Pool));
    uint256 balance1Before = token1.balanceOf(address(uniswapV3Pool));

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: 18,
        token1Exp: 18,
        upperBound: 3 ether,
        amountIn: 1.2 ether,
        amountBorrow: 0,
        sharesMin: 0.2 ether,
        swapType: SwapHelper.SwapType.UniswapV3,
        swapExtraData: abi.encode(uint24(500)),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    // check option amounts
    assertEq(0.2 ether, lendgine.totalSupply());
    assertEq(0.2 ether, lendgine.balanceOf(cuh));

    // check uniswap
    // swap (1.2 / 6) * .540 ether of token 0 to token 1
    assertApproxEqRel(balance0Before + 0.108 ether, token0.balanceOf(address(uniswapV3Pool)), 0.001 ether);
    assertApproxEqRel(balance1Before - 0.072 ether, token1.balanceOf(address(uniswapV3Pool)), 0.001 ether);

    // check lendgine storage
    assertEq(0.2 ether, lendgine.totalLiquidityBorrowed());

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testAmountError() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    vm.expectRevert(LendgineRouter.AmountError.selector);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 0,
        sharesMin: 0.2 ether,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );
  }

  function testUserAmountError() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    vm.expectRevert(LendgineRouter.AmountError.selector);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 10 ether,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );
  }

  function testMintEmit() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    vm.expectEmit(true, true, true, true, address(lendgineRouter));
    emit Mint(cuh, address(lendgine), 1 ether, 0.1 ether, cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 0,
        sharesMin: 0.1 ether,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );
  }

  function testBurn() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 8.8 ether,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    vm.prank(cuh);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(cuh);
    lendgineRouter.burn(
      LendgineRouter.BurnParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        shares: 0.98 ether,
        collateralMin: 0.96 ether,
        amount0Min: 0.98 ether,
        amount1Min: 8 * 0.98 ether,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    // check lendgine token
    assertEq(0, lendgine.balanceOf(cuh));
    assertEq(0, lendgine.totalSupply());

    // check lendgine storage slots
    assertEq(0, lendgine.totalLiquidityBorrowed());

    // check uniswap
    assertApproxEqRel(100 ether, token0.balanceOf(address(uniswapV2Pair)), 0.001 ether);
    assertApproxEqRel(100 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check user balances
    assertApproxEqRel(0.1 ether, token1.balanceOf(cuh), 1 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testBurnNoLiquidity() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 0,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    _withdraw(address(this), address(this), 99.9 ether);

    vm.prank(cuh);
    lendgine.approve(address(lendgineRouter), 0.1 ether);

    vm.prank(cuh);
    lendgineRouter.burn(
      LendgineRouter.BurnParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        shares: 0.1 ether,
        collateralMin: 0,
        amount0Min: 0.1 ether,
        amount1Min: 0.8 ether,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    // check lendgine token
    assertEq(0, lendgine.balanceOf(cuh));
    assertEq(0, lendgine.totalSupply());

    // check lendgine storage slots
    assertEq(0, lendgine.totalLiquidityBorrowed());

    // check uniswap
    assertApproxEqRel(100 ether, token0.balanceOf(address(uniswapV2Pair)), 0.001 ether);
    assertApproxEqRel(100 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check user balances
    assertApproxEqRel(0.1 ether, token1.balanceOf(cuh), 1 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testBurnV3() external {
    setUpUniswapV3();

    uint256 balance0Before = token0.balanceOf(address(uniswapV3Pool));
    uint256 balance1Before = token1.balanceOf(address(uniswapV3Pool));

    uint256 userBalanceBefore = token1.balanceOf(cuh);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: 18,
        token1Exp: 18,
        upperBound: 3 ether,
        amountIn: 1.2 ether,
        amountBorrow: 0,
        sharesMin: 0.2 ether,
        swapType: SwapHelper.SwapType.UniswapV3,
        swapExtraData: abi.encode(uint24(500)),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    vm.prank(cuh);
    lendgine.approve(address(lendgineRouter), 0.2 ether);

    vm.prank(cuh);
    lendgineRouter.burn(
      LendgineRouter.BurnParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: 18,
        token1Exp: 18,
        upperBound: 3 ether,
        shares: 0.2 ether,
        collateralMin: 0,
        amount0Min: 0,
        amount1Min: 0,
        swapType: SwapHelper.SwapType.UniswapV3,
        swapExtraData: abi.encode(uint24(500)),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    // check lendgine token
    assertEq(0, lendgine.balanceOf(cuh));
    assertEq(0, lendgine.totalSupply());

    // check lendgine storage slots
    assertEq(0, lendgine.totalLiquidityBorrowed());

    // check uniswap
    assertApproxEqRel(balance0Before, token0.balanceOf(address(uniswapV3Pool)), 0.001 ether);
    assertApproxEqRel(balance1Before, token1.balanceOf(address(uniswapV3Pool)), 0.001 ether);

    // check user balance
    assertApproxEqRel(userBalanceBefore, token1.balanceOf(cuh), 0.001 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testBurnEmit() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 8.8 ether,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    vm.prank(cuh);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(cuh);
    vm.expectEmit(true, true, true, true, address(lendgineRouter));
    emit Burn(cuh, address(lendgine), 9.8 ether, 0.98 ether, cuh);
    lendgineRouter.burn(
      LendgineRouter.BurnParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        shares: 0.98 ether,
        collateralMin: 0.96 ether,
        amount0Min: 0.98 ether,
        amount1Min: 8 * 0.98 ether,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );
  }

  function testBurnAmountError() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 8.8 ether,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    vm.prank(cuh);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(cuh);
    vm.expectRevert(LendgineRouter.AmountError.selector);
    lendgineRouter.burn(
      LendgineRouter.BurnParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        shares: 0.98 ether,
        collateralMin: 0,
        amount0Min: 0.98 ether,
        amount1Min: 8 * 0.98 ether + 1,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );
  }

  function testBurnUserAmountError() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 8.8 ether,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    vm.prank(cuh);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(cuh);
    vm.expectRevert(LendgineRouter.AmountError.selector);
    lendgineRouter.burn(
      LendgineRouter.BurnParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        shares: 0.98 ether,
        collateralMin: 1 ether,
        amount0Min: 0.98 ether,
        amount1Min: 8 * 0.98 ether,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );
  }

  function testBurnNoRecipient() external {
    token1.mint(cuh, 1 ether);

    vm.prank(cuh);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(cuh);
    lendgineRouter.mint(
      LendgineRouter.MintParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        amountIn: 1 ether,
        amountBorrow: 8.8 ether,
        sharesMin: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: cuh,
        deadline: block.timestamp
      })
    );

    uint256 balanceBefore = token1.balanceOf(address(cuh));

    vm.prank(cuh);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(cuh);
    lendgineRouter.burn(
      LendgineRouter.BurnParams({
        token0: address(token0),
        token1: address(token1),
        token0Exp: token0Scale,
        token1Exp: token1Scale,
        upperBound: upperBound,
        shares: 0.98 ether,
        collateralMin: 0,
        amount0Min: 0,
        amount1Min: 0,
        swapType: SwapHelper.SwapType.UniswapV2,
        swapExtraData: bytes(""),
        recipient: address(0),
        deadline: block.timestamp
      })
    );

    // check lendgine token
    assertEq(0, lendgine.balanceOf(cuh));
    assertEq(0, lendgine.totalSupply());

    // check lendgine storage slots
    assertEq(0, lendgine.totalLiquidityBorrowed());

    // check uniswap
    assertApproxEqRel(100 ether, token0.balanceOf(address(uniswapV2Pair)), 0.001 ether);
    assertApproxEqRel(100 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check user balances
    assertEq(balanceBefore, token1.balanceOf(address(cuh)));

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertApproxEqRel(0.1 ether, token1.balanceOf(address(lendgineRouter)), 1 ether);
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }
}
