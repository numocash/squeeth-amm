// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

/// @notice Library for computing the address of a lendgine using only its inputs
library LendgineAddress {
  uint256 internal constant INIT_CODE_HASH =
    71_695_300_681_742_793_458_567_320_549_603_773_755_938_496_017_772_337_363_704_152_556_600_186_974;

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
