// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "src/EvroToken.sol";

contract EvroTokenTester is EvroToken {
    constructor(address _owner) EvroToken(_owner) {}

    function unprotectedMint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }
}
