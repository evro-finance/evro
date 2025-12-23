// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILQTYStaking {
    function setAddresses(
        address _lqtyTokenAddress,
        address _evroTokenAddress,
        address _troveManagerAddress,
        address _borrowerOperationsAddress,
        address _activePoolAddress
    ) external;

    function stake(uint256 _LQTYamount) external;

    function unstake(uint256 _LQTYamount) external;

    function increaseF_ETH(uint256 _ETHFee) external;

    function increaseF_evro(uint256 _LQTYFee) external;

    function getPendingETHGain(address _user) external view returns (uint256);

    function getPendingEvroGain(address _user) external view returns (uint256);
}
