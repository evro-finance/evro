// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEvroRewardsReceiver {
    function triggerEvroRewards(uint256 _evroYield) external;
}
