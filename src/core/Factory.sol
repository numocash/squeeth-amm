// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Lendgine } from "./Lendgine.sol";

contract Factory {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LendgineCreated(
        address indexed token0,
        address indexed token1,
        uint256 token0Scale,
        uint256 token1Scale,
        uint256 indexed upperBound,
        address lendgine
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SameTokenError();

    error ZeroAddressError();

    error DeployedError();

    /*//////////////////////////////////////////////////////////////
                            FACTORY STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(address => mapping(uint256 => mapping(uint256 => mapping(uint256 => address)))))
        public getLendgine;

    /*//////////////////////////////////////////////////////////////
                        TEMPORARY DEPLOY STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Parameters {
        address token0;
        address token1;
        uint256 token0Scale;
        uint256 token1Scale;
        uint256 upperBound;
    }

    Parameters public parameters;

    /*//////////////////////////////////////////////////////////////
                              FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function createLendgine(
        address token0,
        address token1,
        uint256 token0Scale,
        uint256 token1Scale,
        uint256 upperBound
    ) external returns (address lendgine) {
        if (token0 == token1) revert SameTokenError();
        if (token0 == address(0) || token1 == address(0)) revert ZeroAddressError();
        if (getLendgine[token0][token1][token0Scale][token1Scale][upperBound] != address(0)) revert DeployedError();

        parameters = Parameters({
            token0: token0,
            token1: token1,
            token0Scale: token0Scale,
            token1Scale: token1Scale,
            upperBound: upperBound
        });

        lendgine = address(
            new Lendgine{ salt: keccak256(abi.encode(token0, token1, token0Scale, token1Scale, upperBound)) }()
        );

        delete parameters;

        getLendgine[token0][token1][token0Scale][token1Scale][upperBound] = lendgine;
        emit LendgineCreated(token0, token1, token0Scale, token1Scale, upperBound, lendgine);
    }
}
