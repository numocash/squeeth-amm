// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { PositionMath } from "./PositionMath.sol";
import { FullMath } from "../../libraries/FullMath.sol";

/// @notice Library for handling Lendgine liquidity positions
/// @author Kyle Scott (kyle@numoen.com)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/Position.sol)
library Position {
  /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Error for trying to update a position with no size
  error NoPositionError();

  /*//////////////////////////////////////////////////////////////
                            POSITION STRUCT
    //////////////////////////////////////////////////////////////*/

  /**
   * @param size The size of the position
   * @param rewardPerPositionPaid The reward per unit of size as of the last update to position or tokensOwed
   * @param tokensOwed The fees owed to the position owner in `speculative` tokens
   */
  struct Info {
    uint256 size;
    uint256 rewardPerPositionPaid;
    uint256 tokensOwed;
  }

  /*//////////////////////////////////////////////////////////////
                              POSITION LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @notice Helper function for updating a position by increasing/decreasing its size or accruing interest
  function update(
    mapping(address => Position.Info) storage self,
    address owner,
    int256 sizeDelta,
    uint256 rewardPerPosition
  )
    internal
  {
    Position.Info storage positionInfo = self[owner];
    Position.Info memory _positionInfo = positionInfo;

    uint256 tokensOwed;
    if (_positionInfo.size > 0) {
      tokensOwed = newTokensOwed(_positionInfo, rewardPerPosition);
    }

    uint256 sizeNext;
    if (sizeDelta == 0) {
      if (_positionInfo.size == 0) revert NoPositionError();
      sizeNext = _positionInfo.size;
    } else {
      sizeNext = PositionMath.addDelta(_positionInfo.size, sizeDelta);
    }

    if (sizeDelta != 0) positionInfo.size = sizeNext;
    positionInfo.rewardPerPositionPaid = rewardPerPosition;
    if (tokensOwed > 0) positionInfo.tokensOwed = _positionInfo.tokensOwed + tokensOwed;
  }

  /// @notice Helper function for determining the amount of tokens owed to a position
  /// @param rewardPerPosition The global accrued interest
  function newTokensOwed(Position.Info memory position, uint256 rewardPerPosition) internal pure returns (uint256) {
    return FullMath.mulDiv(position.size, rewardPerPosition - position.rewardPerPositionPaid, 1 ether);
  }

  function convertLiquidityToPosition(
    uint256 liquidity,
    uint256 totalLiquiditySupplied,
    uint256 totalPositionSize
  )
    internal
    pure
    returns (uint256)
  {
    return
      totalLiquiditySupplied == 0 ? liquidity : FullMath.mulDiv(liquidity, totalPositionSize, totalLiquiditySupplied);
  }

  function convertPositionToLiquidity(
    uint256 position,
    uint256 totalLiquiditySupplied,
    uint256 totalPositionSize
  )
    internal
    pure
    returns (uint256)
  {
    return FullMath.mulDiv(position, totalLiquiditySupplied, totalPositionSize);
  }
}
