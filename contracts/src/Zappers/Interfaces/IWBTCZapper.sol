// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IZapper.sol";

interface IWBTCZapper is IZapper {
    function openTroveWithWBTC(OpenTroveParams calldata _params) external payable returns (uint256);
    function closeTroveToWBTC(uint256 _troveId) external;
    function addCollWithWBTC(uint256 _troveId, uint256 _amount) external;
    function withdrawCollToWBTC(uint256 _troveId, uint256 _amount) external;
    function adjustTroveWithWBTC(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _evroChange,
        bool _isDebtIncrease,
        uint256 _maxUpfrontFee
    ) external;
    function adjustZombieTroveWithWBTC(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _evroChange,
        bool _isDebtIncrease,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external;
    function withdrawEvro(uint256 _troveId, uint256 _evroAmount, uint256 _maxUpfrontFee) external;
    function repayEvro(uint256 _troveId, uint256 _evroAmount) external;
}