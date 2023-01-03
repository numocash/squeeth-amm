// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Lendgine } from "./Lendgine.sol";

import { IFactory } from "./interfaces/IFactory.sol";

contract Factory is IFactory {
  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

  event LendgineCreated(
    address indexed token0,
    address indexed token1,
    uint256 token0Exp,
    uint256 token1Exp,
    uint256 indexed upperBound,
    address lendgine
  );

  /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

  error SameTokenError();

  error ZeroAddressError();

  error DeployedError();

  error ScaleError();

  /*//////////////////////////////////////////////////////////////
                            FACTORY STORAGE
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IFactory
  mapping(address => mapping(address => mapping(uint256 => mapping(uint256 => mapping(uint256 => address)))))
    public
    override getLendgine;

  /*//////////////////////////////////////////////////////////////
                        TEMPORARY DEPLOY STORAGE
    //////////////////////////////////////////////////////////////*/

  struct Parameters {
    address token0;
    address token1;
    uint128 token0Exp;
    uint128 token1Exp;
    uint256 upperBound;
  }

  /// @inheritdoc IFactory
  Parameters public override parameters;

  /*//////////////////////////////////////////////////////////////
                              FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IFactory
  function createLendgine(
    address token0,
    address token1,
    uint8 token0Exp,
    uint8 token1Exp,
    uint256 upperBound
  )
    external
    override
    returns (address lendgine)
  {
    if (token0 == token1) revert SameTokenError();
    if (token0 == address(0) || token1 == address(0)) revert ZeroAddressError();
    if (getLendgine[token0][token1][token0Exp][token1Exp][upperBound] != address(0)) revert DeployedError();
    if (token0Exp > 18 || token0Exp < 6 || token1Exp > 18 || token1Exp < 6) revert ScaleError();

    parameters =
      Parameters({token0: token0, token1: token1, token0Exp: token0Exp, token1Exp: token1Exp, upperBound: upperBound});

    lendgine = address(new Lendgine{ salt: keccak256(abi.encode(token0, token1, token0Exp, token1Exp, upperBound)) }());

    delete parameters;

    getLendgine[token0][token1][token0Exp][token1Exp][upperBound] = lendgine;
    emit LendgineCreated(token0, token1, token0Exp, token1Exp, upperBound, lendgine);
  }
}
