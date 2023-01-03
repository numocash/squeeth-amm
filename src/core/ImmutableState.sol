// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "./Factory.sol";

import { IImmutableState } from "./interfaces/IImmutableState.sol";

abstract contract ImmutableState is IImmutableState {
  /// @inheritdoc IImmutableState
  address public immutable factory;

  /// @inheritdoc IImmutableState
  address public immutable token0;

  /// @inheritdoc IImmutableState
  address public immutable token1;

  /// @inheritdoc IImmutableState
  uint256 public immutable token0Scale;

  /// @inheritdoc IImmutableState
  uint256 public immutable token1Scale;

  /// @inheritdoc IImmutableState
  uint256 public immutable upperBound;

  constructor() {
    factory = msg.sender;

    uint128 _token0Exp;
    uint128 _token1Exp;

    (token0, token1, _token0Exp, _token1Exp, upperBound) = Factory(msg.sender).parameters();

    token0Scale = 10 ** (18 - _token0Exp);
    token1Scale = 10 ** (18 - _token1Exp);
  }
}
