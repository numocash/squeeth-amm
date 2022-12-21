// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

/// @notice Casting library
/// @author Kyle Scott (https://github.com/Numoen/core/blob/master/src/libraries/SafeCast.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/SafeCast.sol)
library SafeCast {
    function toUint128(uint256 y) internal pure returns (uint128 z) {
        require((z = uint128(y)) == y);
    }
}
