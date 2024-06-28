// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

import { Lendgine } from "../../core/Lendgine.sol";

/// @notice Library for computing the address of a lendgine using only its inputs
library LendgineAddress {

  function computeAddress(
    address factory,
    address token0,
    address token1,
    uint256 token0Exp,
    uint256 token1Exp,
    uint256 strike
  )
    internal
    pure
    returns (address lendgine)
  {
    lendgine = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              factory,
              keccak256(abi.encode(token0, token1, token0Exp, token1Exp, strike)),
              keccak256(type(Lendgine).creationCode)
            )
          )
        )
      )
    );
  }
}
