// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { ImmutableState } from "./ImmutableState.sol";
import { ReentrancyGuard } from "./ReentrancyGuard.sol";

import { IPairMintCallback } from "./interfaces/callback/IPairMintCallback.sol";
import { ISwapCallback } from "./interfaces/callback/ISwapCallback.sol";

import { Balance } from "../libraries/Balance.sol";
import { FullMath } from "../libraries/FullMath.sol";
import { SafeCast } from "../libraries/SafeCast.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";

abstract contract Pair is ImmutableState, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(uint256 amount0In, uint256 amount1In, uint256 liquidity);

    event Burn(uint256 amount0Out, uint256 amount1Out, uint256 liquidity, address indexed to);

    event Swap(uint256 amount0Out, uint256 amount1Out, uint256 amount0In, uint256 amount1In, address indexed to);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvariantError();

    error InsufficientOutputError();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint120 public reserve0;

    uint120 public reserve1;

    uint256 public totalLiquidity;

    /*//////////////////////////////////////////////////////////////
                              PAIR LOGIC
    //////////////////////////////////////////////////////////////*/

    function invariant(
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    ) public view returns (bool) {
        if (liquidity == 0) return (amount0 == 0 && amount1 == 0);

        uint256 scale0 = FullMath.mulDiv(amount0, 1e18, liquidity) * token0Scale;
        uint256 scale1 = FullMath.mulDiv(amount1, 1e18, liquidity) * token1Scale;

        if (scale1 > 2 * upperBound) revert InvariantError();

        uint256 a = scale0 * 1e18;
        uint256 b = scale1 * upperBound;
        uint256 c = (scale1 * scale1) / 4;
        uint256 d = upperBound * upperBound;

        return a + b >= c + d;
    }

    /// @dev assumes liquidity is non-zero
    function mint(uint256 liquidity, bytes calldata data) internal {
        uint120 _reserve0 = reserve0; // SLOAD
        uint120 _reserve1 = reserve1; // SLOAD
        uint256 _totalLiquidity = totalLiquidity; // SLOAD

        uint256 balance0Before = Balance.balance(token0);
        uint256 balance1Before = Balance.balance(token1);
        IPairMintCallback(msg.sender).pairMintCallback(liquidity, data);
        uint256 amount0In = Balance.balance(token0) - balance0Before;
        uint256 amount1In = Balance.balance(token1) - balance1Before;

        if (!invariant(_reserve0 + amount0In, _reserve1 + amount1In, _totalLiquidity + liquidity))
            revert InvariantError();

        reserve0 = _reserve0 + SafeCast.toUint120(amount0In); // SSTORE
        reserve1 = _reserve1 + SafeCast.toUint120(amount1In); // SSTORE
        totalLiquidity = _totalLiquidity + liquidity; // SSTORE

        emit Mint(amount0In, amount1In, liquidity);
    }

    /// @dev assumes liquidity is non-zero
    function burn(address to, uint256 liquidity) internal returns (uint256 amount0, uint256 amount1) {
        uint120 _reserve0 = reserve0; // SLOAD
        uint120 _reserve1 = reserve1; // SLOAD
        uint256 _totalLiquidity = totalLiquidity; // SLOAD

        amount0 = FullMath.mulDiv(_reserve0, liquidity, _totalLiquidity);
        amount1 = FullMath.mulDiv(_reserve1, liquidity, _totalLiquidity);
        if (amount0 == 0 && amount1 == 0) revert InsufficientOutputError();

        if (amount0 > 0) SafeTransferLib.safeTransfer(token0, to, amount0);
        if (amount1 > 0) SafeTransferLib.safeTransfer(token1, to, amount1);

        // Extra check of the invariant
        if (!invariant(_reserve0 - amount0, _reserve1 - amount1, _totalLiquidity - liquidity)) revert InvariantError();

        reserve0 = _reserve0 - SafeCast.toUint120(amount0); // SSTORE
        reserve1 = _reserve1 - SafeCast.toUint120(amount1); // SSTORE
        totalLiquidity = _totalLiquidity - liquidity; // SSTORE

        emit Burn(amount0, amount1, liquidity, to);
    }

    function swap(
        address to,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputError();

        uint120 _reserve0 = reserve0; // SLOAD
        uint120 _reserve1 = reserve1; // SLOAD

        if (amount0Out > 0) SafeTransferLib.safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) SafeTransferLib.safeTransfer(token1, to, amount1Out);

        uint256 balance0Before = Balance.balance(token0);
        uint256 balance1Before = Balance.balance(token1);
        ISwapCallback(msg.sender).swapCallback(amount0Out, amount1Out, data);
        uint256 amount0In = Balance.balance(token0) - balance0Before;
        uint256 amount1In = Balance.balance(token1) - balance1Before;

        if (!invariant(_reserve0 + amount0In - amount0Out, _reserve1 + amount1In - amount1Out, totalLiquidity))
            revert InvariantError();

        reserve0 = _reserve0 + SafeCast.toUint120(amount0In) - SafeCast.toUint120(amount0Out); // SSTORE
        reserve1 = _reserve1 + SafeCast.toUint120(amount1In) - SafeCast.toUint120(amount1Out); // SSTORE

        emit Swap(amount0Out, amount1Out, amount0In, amount1In, to);
    }
}
