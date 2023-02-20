// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

/// @notice Library for computing the address of a lendgine using only its inputs
library LendgineAddress {
  uint256 internal constant INIT_CODE_HASH =
    54_077_118_415_036_375_799_727_632_405_414_219_288_686_146_435_384_080_671_378_369_222_491_001_741_386;

  function computeAddress(
    address factory,
    address token0,
    address token1,
    uint256 token0Exp,
    uint256 token1Exp,
    uint256 upperBound
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
              keccak256(abi.encode(token0, token1, token0Exp, token1Exp, upperBound)),
              bytes32(INIT_CODE_HASH)
            )
          )
        )
      )
    );
  }
}
