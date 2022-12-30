// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

library Balance {
    error BalanceReturnError();

    function balance(address token) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("balanceOf(address)"))), address(this))
        );
        if (!success || data.length < 32) revert BalanceReturnError();
        return abi.decode(data, (uint256));
    }
}
