// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC20 } from "../../../src/core/ERC20.sol";

contract MockERC20 is ERC20 {
  constructor() ERC20() { }

  function mint(address to, uint256 value) public virtual {
    _mint(to, value);
  }

  function burn(address from, uint256 value) public virtual {
    _burn(from, value);
  }
}
