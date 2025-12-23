// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IExchange {
    function swapFromEvro(uint256 _evroAmount, uint256 _minCollAmount) external;

    function swapToEvro(uint256 _collAmount, uint256 _minEvroAmount) external returns (uint256);
}
