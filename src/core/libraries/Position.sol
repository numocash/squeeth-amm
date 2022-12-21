// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { LiquidityMath } from "./LiquidityMath.sol";
import { FullMath } from "./FullMath.sol";

/// @notice Library for handling Lendgine liquidity positions
/// @author Kyle Scott (https://github.com/Numoen/core/blob/master/src/libraries/Position.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/Position.sol)
library Position {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NoLiquidityError();

    /*//////////////////////////////////////////////////////////////
                            POSITION STRUCT
    //////////////////////////////////////////////////////////////*/

    /**
     * @param size The size of the position
     * @param rewardPerLiquidityPaid The reward per unit of liquidity as of the last update to liquidity or tokensOwed
     * @param tokensOwed The fees owed to the position owner in `speculative` tokens
     */
    struct Info {
        uint256 size;
        uint256 rewardPerLiquidityPaid;
        uint256 tokensOwed;
    }

    /*//////////////////////////////////////////////////////////////
                              POSITION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper function for determining the amount of tokens owed to a position
    /// @dev Assumes the global interest is up to date
    function update(
        mapping(address => Position.Info) storage self,
        address owner,
        int256 liquidityDelta,
        uint256 rewardPerLiquidity
    ) internal {
        Position.Info storage positionInfo = self[owner];
        Position.Info memory _positionInfo = positionInfo;

        uint256 tokensOwed;
        if (_positionInfo.size > 0) {
            tokensOwed = newTokensOwed(_positionInfo, rewardPerLiquidity);
        }

        uint256 liquidityNext;
        if (liquidityDelta == 0) {
            if (_positionInfo.size == 0) revert NoLiquidityError();
            liquidityNext = _positionInfo.size;
        } else {
            liquidityNext = LiquidityMath.addDelta(_positionInfo.size, liquidityDelta);
        }

        if (liquidityDelta != 0) positionInfo.size = liquidityNext;
        positionInfo.rewardPerLiquidityPaid = rewardPerLiquidity;
        if (tokensOwed > 0) positionInfo.tokensOwed = _positionInfo.tokensOwed + tokensOwed;
    }

    /// @notice Helper function for determining the amount of tokens owed to a position
    function newTokensOwed(Position.Info memory position, uint256 rewardPerLiquidity) internal pure returns (uint256) {
        return FullMath.mulDiv(position.size, rewardPerLiquidity - position.rewardPerLiquidityPaid, 1 ether);
    }

    function convertLiquidityToPosition(
        uint256 liquidity,
        uint256 totalLiquidity,
        uint256 totalLiquiditySupplied
    ) internal pure returns (uint256) {
        return FullMath.mulDiv(liquidity, totalLiquiditySupplied, totalLiquidity);
    }

    function convertPositionToLiquidity(
        uint256 position,
        uint256 totalLiquidity,
        uint256 totalLiquiditySupplied
    ) internal pure returns (uint256) {
        return FullMath.mulDiv(position, totalLiquidity, totalLiquiditySupplied);
    }

    /*//////////////////////////////////////////////////////////////
                           POSITION VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Return a position identified by its owner and tick
    function get(mapping(address => Info) storage self, address owner)
        internal
        view
        returns (Position.Info storage position)
    {
        position = self[owner];
    }
}
