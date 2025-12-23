// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./MainnetPriceFeedBase.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract WETHPriceFeed is MainnetPriceFeedBase {
    Oracle public eurUsdOracle;
    constructor(address _ethUsdOracleAddress, address _eurUsdOracleAddress, uint256 _ethUsdStalenessThreshold, uint256 _usdEurStalenessThreshold, address _borrowerOperationsAddress)
        MainnetPriceFeedBase(_ethUsdOracleAddress, _ethUsdStalenessThreshold, _borrowerOperationsAddress)
    {
        eurUsdOracle.aggregator = AggregatorV3Interface(_eurUsdOracleAddress);
        eurUsdOracle.stalenessThreshold = _usdEurStalenessThreshold;
        eurUsdOracle.decimals = eurUsdOracle.aggregator.decimals();
        assert(eurUsdOracle.decimals != 0);
        _fetchPricePrimary();

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    function fetchPrice() public returns (uint256, bool) {
        // If branch is live and the primary oracle setup has been working, try to use it
        if (priceSource == PriceSource.primary) return _fetchPricePrimary();

        // Otherwise if branch is shut down and already using the lastGoodPrice, continue with it
        assert(priceSource == PriceSource.lastGoodPrice);
        return (lastGoodPrice, false);
    }

    function fetchRedemptionPrice() external returns (uint256, bool) {
        // Use same price for redemption as all other ops in WETH branch
        return fetchPrice();
    }

    //  _fetchPricePrimary returns:
    // - The price
    // - A bool indicating whether a new oracle failure was detected in the call
    function _fetchPricePrimary() internal returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 ethUsdPrice, bool ethUsdOracleDown) = _getOracleAnswer(ethUsdOracle);
        (uint256 eurUsdPrice, bool eurUsdOracleDown) = _getOracleAnswer(eurUsdOracle);

        // If the ETH-USD Chainlink response was invalid in this transaction, return the last good ETH-USD price calculated
        if (ethUsdOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(ethUsdOracle.aggregator)), true);
        if (eurUsdOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(eurUsdOracle.aggregator)), true);

        uint256 wETHEurPrice = FixedPointMathLib.divWad(ethUsdPrice, eurUsdPrice);
        lastGoodPrice = wETHEurPrice;
        return (wETHEurPrice, false);
    }
}
