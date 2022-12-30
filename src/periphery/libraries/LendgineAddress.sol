// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

import { Lendgine } from "../../core/Lendgine.sol";

library LendgineAddress {
    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint256 token0Scale,
        uint256 token1Scale,
        uint256 upperBound
    ) internal pure returns (address lendgine) {
        lendgine = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encode(token0, token1, token0Scale, token1Scale, upperBound)),
                            keccak256(type(Lendgine).creationCode)
                        )
                    )
                )
            )
        );
    }
}
