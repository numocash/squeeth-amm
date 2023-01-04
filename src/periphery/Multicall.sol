// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IMulticall.sol";

/// @title Multicall
/// @notice Enables calling multiple methods in a single call to the contract
/// @author Muffin (https://github.com/muffinfi/muffin/blob/master/contracts/periphery/base/Multicall.sol)
/// @dev Widened solidity version from 0.8.10
abstract contract Multicall is IMulticall {
  /// @inheritdoc IMulticall
  function multicall(bytes[] calldata data) public payable override returns (bytes[] memory results) {
    results = new bytes[](data.length);
    unchecked {
      for (uint256 i = 0; i < data.length; i++) {
        (bool success, bytes memory result) = address(this).delegatecall(data[i]);

        if (!success) {
          if (result.length == 0) revert();
          assembly {
            revert(add(32, result), mload(result))
          }
        }

        results[i] = result;
      }
    }
  }
}
