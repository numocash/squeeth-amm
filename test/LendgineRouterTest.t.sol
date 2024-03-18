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

  IUniswapV2Factory public uniswapV2Factory = IUniswapV2Factory(0xB7f907f7A9eBC822a80BD25E224be42Ce0A698A0);
  IUniswapV2Pair public uniswapV2Pair;
  IUniswapV3Factory public uniswapV3Factory = IUniswapV3Factory(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);
  IUniswapV3Pool public uniswapV3Pool = IUniswapV3Pool(0x51aDC79e7760aC5317a0d05e7a64c4f9cB2d4369); // uni / eth / 100 bps

  // pool

  function setUp() external {
    // use sepolia from a block where we know we can get tokens
    vm.createSelectFork("sepolia");
    vm.rollFork(2_244_070); //latest block

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
    token0 = MockERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984); // Sepolia UNI
    token1 = MockERC20(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14); // Sepolia WETH

    // get tokens
    vm.prank(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    token0.transfer(alice, 100 ether);

    vm.prank(0xb3A16C2B68BBB0111EbD27871a5934b949837D95);
    token1.transfer(alice, 100 ether);

    // deploy lendgine
    lendgine = Lendgine(factory.createLendgine(address(token0), address(token1), 18, 18, 3 ether));

    // deposit tokens
    vm.startPrank(alice);
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
          payer: alice
        })
      )
    );
  }

  function testMintNoBorrow() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    // check option amounts
    assertEq(0.1 ether, lendgine.totalSupply());
    assertEq(0.1 ether, lendgine.balanceOf(alice));

    // check uniswap
    // swap 0.1 ether of token 0 to token 1
    assertEq(100.1 ether, token0.balanceOf(address(uniswapV2Pair)));
    assertApproxEqRel(99.9 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check lendgine storage
    assertEq(0.1 ether, lendgine.totalLiquidityBorrowed());

    // check user balances
    assertApproxEqRel(0.9 ether, token1.balanceOf(alice), 1 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testMintBorrow() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    // check option amounts
    assertEq(0.98 ether, lendgine.totalSupply());
    assertEq(0.98 ether, lendgine.balanceOf(alice));

    // check uniswap
    // swap 0.98 ether of token 0 to token 1
    assertEq(100.98 ether, token0.balanceOf(address(uniswapV2Pair)));
    assertApproxEqRel(99.02 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check lendgine storage
    assertEq(0.98 ether, lendgine.totalLiquidityBorrowed());

    // check user balances
    assertApproxEqRel(0, token1.balanceOf(alice), 1 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testMintV3() external {
    setUpUniswapV3();

    uint256 balance0Before = token0.balanceOf(address(uniswapV3Pool));
    uint256 balance1Before = token1.balanceOf(address(uniswapV3Pool));

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    // check option amounts
    assertEq(0.2 ether, lendgine.totalSupply());
    assertEq(0.2 ether, lendgine.balanceOf(alice));

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
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );
  }

  function testUserAmountError() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );
  }

  function testMintEmit() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
    vm.expectEmit(true, true, true, true, address(lendgineRouter));
    emit Mint(alice, address(lendgine), 1 ether, 0.1 ether, alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );
  }

  function testBurn() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    vm.prank(alice);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    // check lendgine token
    assertEq(0, lendgine.balanceOf(alice));
    assertEq(0, lendgine.totalSupply());

    // check lendgine storage slots
    assertEq(0, lendgine.totalLiquidityBorrowed());

    // check uniswap
    assertApproxEqRel(100 ether, token0.balanceOf(address(uniswapV2Pair)), 0.001 ether);
    assertApproxEqRel(100 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check user balances
    assertApproxEqRel(0.1 ether, token1.balanceOf(alice), 1 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testBurnNoLiquidity() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    _withdraw(address(this), address(this), 99.9 ether);

    vm.prank(alice);
    lendgine.approve(address(lendgineRouter), 0.1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    // check lendgine token
    assertEq(0, lendgine.balanceOf(alice));
    assertEq(0, lendgine.totalSupply());

    // check lendgine storage slots
    assertEq(0, lendgine.totalLiquidityBorrowed());

    // check uniswap
    assertApproxEqRel(100 ether, token0.balanceOf(address(uniswapV2Pair)), 0.001 ether);
    assertApproxEqRel(100 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check user balances
    assertApproxEqRel(0.1 ether, token1.balanceOf(alice), 1 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testBurnV3() external {
    setUpUniswapV3();

    uint256 balance0Before = token0.balanceOf(address(uniswapV3Pool));
    uint256 balance1Before = token1.balanceOf(address(uniswapV3Pool));

    uint256 userBalanceBefore = token1.balanceOf(alice);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    vm.prank(alice);
    lendgine.approve(address(lendgineRouter), 0.2 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    // check lendgine token
    assertEq(0, lendgine.balanceOf(alice));
    assertEq(0, lendgine.totalSupply());

    // check lendgine storage slots
    assertEq(0, lendgine.totalLiquidityBorrowed());

    // check uniswap
    assertApproxEqRel(balance0Before, token0.balanceOf(address(uniswapV3Pool)), 0.001 ether);
    assertApproxEqRel(balance1Before, token1.balanceOf(address(uniswapV3Pool)), 0.001 ether);

    // check user balance
    assertApproxEqRel(userBalanceBefore, token1.balanceOf(alice), 0.001 ether);

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertEq(0, token1.balanceOf(address(lendgineRouter)));
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }

  function testBurnEmit() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    vm.prank(alice);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(alice);
    vm.expectEmit(true, true, true, true, address(lendgineRouter));
    emit Burn(alice, address(lendgine), 9.8 ether, 0.98 ether, alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );
  }

  function testBurnAmountError() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    vm.prank(alice);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );
  }

  function testBurnUserAmountError() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    vm.prank(alice);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );
  }

  function testBurnNoRecipient() external {
    token1.mint(alice, 1 ether);

    vm.prank(alice);
    token1.approve(address(lendgineRouter), 1 ether);

    vm.prank(alice);
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
        recipient: alice,
        deadline: block.timestamp
      })
    );

    uint256 balanceBefore = token1.balanceOf(address(alice));

    vm.prank(alice);
    lendgine.approve(address(lendgineRouter), 0.98 ether);

    vm.prank(alice);
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
    assertEq(0, lendgine.balanceOf(alice));
    assertEq(0, lendgine.totalSupply());

    // check lendgine storage slots
    assertEq(0, lendgine.totalLiquidityBorrowed());

    // check uniswap
    assertApproxEqRel(100 ether, token0.balanceOf(address(uniswapV2Pair)), 0.001 ether);
    assertApproxEqRel(100 ether, token1.balanceOf(address(uniswapV2Pair)), 0.001 ether);

    // check user balances
    assertEq(balanceBefore, token1.balanceOf(address(alice)));

    // check router token balances
    assertEq(0, token0.balanceOf(address(lendgineRouter)));
    assertApproxEqRel(0.1 ether, token1.balanceOf(address(lendgineRouter)), 1 ether);
    assertEq(0, lendgine.balanceOf(address(lendgineRouter)));
  }
}
