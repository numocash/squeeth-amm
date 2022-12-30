// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "./Factory.sol";

abstract contract ImmutableState {
    address public immutable factory;

    address public immutable token0;

    address public immutable token1;

    uint256 public immutable token0Scale;

    uint256 public immutable token1Scale;

    uint256 public immutable upperBound;

    constructor() {
        factory = msg.sender;

        uint256 _token0Exp;
        uint256 _token1Exp;

        (token0, token1, _token0Exp, _token1Exp, upperBound) = Factory(msg.sender).parameters();

        token0Scale = 10**(18 - _token0Exp);
        token1Scale = 10**(18 - _token1Exp);
    }
}
