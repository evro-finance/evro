// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IDelegationPool {
    function delegatee() external view returns (address);
    function collateralToken() external view returns (address);
    function balance() external view returns (uint256);
}