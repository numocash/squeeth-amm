// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

/// @notice Manages the recording and creation of Numoen markets
/// @author Kyle Scott (https://github.com/numoen/contracts-mono/blob/master/src/Factory.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Factory.sol)
/// and Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveFactory.sol)
interface IFactory {
  /// @notice Returns the lendgine address for a given pair of tokens and upper bound
  /// @dev returns address 0 if it doesn't exist
  function getLendgine(
    address token0,
    address token1,
    uint256 token0Exp,
    uint256 token1Exp,
    uint256 upperBound
  )
    external
    view
    returns (address lendgine);

  /// @notice Get the parameters to be used in constructing the lendgine, set
  /// transiently during lendgine creation
  /// @dev Called by the immutable state constructor to fetch the parameters of the lendgine
  function parameters()
    external
    view
    returns (address token0, address token1, uint128 token0Exp, uint128 token1Exp, uint256 upperBound);

  /// @notice Deploys a lendgine contract by transiently setting the parameters storage slots
  /// and clearing it after the lendgine has been deployed
  function createLendgine(
    address token0,
    address token1,
    uint8 token0Exp,
    uint8 token1Exp,
    uint256 upperBound
  )
    external
    returns (address);
}
