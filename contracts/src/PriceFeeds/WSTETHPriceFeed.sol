// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./CompositePriceFeed.sol";
import "../Interfaces/IWSTETH.sol";
import "../Interfaces/IWSTETHPriceFeed.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";


contract WSTETHPriceFeed is CompositePriceFeed, IWSTETHPriceFeed {
    Oracle public stEthUsdOracle;
    Oracle public rateProviderOracle;
    uint256 public constant STETH_USD_DEVIATION_THRESHOLD = 1e16; // 1%

    constructor(
        address _ethUsdOracleAddress,
        address _stEthUsdOracleAddress,
        address _wstEthTokenAddress,
        address _eurUsdOracleAddress,
        uint256 _ethUsdStalenessThreshold,
        uint256 _stEthUsdStalenessThreshold,
        uint256 _eurUsdStalenessThreshold,
        uint256 _rateProviderStalenessThreshold,
        address _rateProviderOracleAddress,
        address _borrowerOperationsAddress
    )
        CompositePriceFeed(_ethUsdOracleAddress, _wstEthTokenAddress, _ethUsdStalenessThreshold, _eurUsdOracleAddress, _eurUsdStalenessThreshold, _borrowerOperationsAddress)
    {
        stEthUsdOracle.aggregator = AggregatorV3Interface(_stEthUsdOracleAddress);
        stEthUsdOracle.stalenessThreshold = _stEthUsdStalenessThreshold;
        stEthUsdOracle.decimals = stEthUsdOracle.aggregator.decimals();

        rateProviderOracle.aggregator = AggregatorV3Interface(_rateProviderOracleAddress);
        rateProviderOracle.stalenessThreshold = _rateProviderStalenessThreshold;
        rateProviderOracle.decimals = rateProviderOracle.aggregator.decimals();

        _fetchPricePrimary(false);

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    function _fetchPricePrimary(bool _isRedemption) internal override returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 stEthUsdPrice, bool stEthUsdOracleDown) = _getOracleAnswer(stEthUsdOracle);
        (uint256 stEthPerWstEth, bool exchangeRateIsDown) = _getCanonicalRate();
        (uint256 ethUsdPrice, bool ethUsdOracleDown) = _getOracleAnswer(ethUsdOracle);
        (uint256 eurUsdPrice, bool eurUsdOracleDown) = _getOracleAnswer(eurUsdOracle);

        // - If exchange rate or ETH-USD is down, shut down and switch to last good price. Reasoning:
        // - Exchange rate is used in all price calcs
        // - ETH-USD is used in the fallback calc, and for redemptions in the primary price calc
        if (exchangeRateIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(rateProviderOracle.aggregator)), true);
        }
        if (ethUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(ethUsdOracle.aggregator)), true);
        }
        if (eurUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(eurUsdOracle.aggregator)), true);
        }

        // If the STETH-USD feed is down, shut down and try to substitute it with the ETH-USD price
        if (stEthUsdOracleDown) {
            return (_shutDownAndSwitchToETHUSDxCanonical(address(stEthUsdOracle.aggregator), ethUsdPrice), true);
        }

        // Otherwise, use the primary price calculation:
        uint256 wstEthUsdPrice;

        if (_isRedemption && _withinDeviationThreshold(stEthUsdPrice, ethUsdPrice, STETH_USD_DEVIATION_THRESHOLD)) {
            // If it's a redemption and within 1%, take the max of (STETH-USD, ETH-USD) to mitigate unwanted redemption arb and convert to WSTETH-USD
            wstEthUsdPrice = LiquityMath._max(stEthUsdPrice, ethUsdPrice) * stEthPerWstEth / 1e18;
        } else {
            // Otherwise, just calculate WSTETH-USD price: USD_per_WSTETH = USD_per_STETH * STETH_per_WSTETH
            wstEthUsdPrice = stEthUsdPrice * stEthPerWstEth / 1e18;
        }

        // Convert USD to EUR
        uint256 wstEthEurPrice = FixedPointMathLib.divWad(wstEthUsdPrice, eurUsdPrice);

        lastGoodPrice = wstEthEurPrice;

        return (wstEthEurPrice, false);
    }

    function _getCanonicalRate() internal view override returns (uint256, bool) {
        // since we areon gnosis the rate provider is an oracle
        (uint256 stEthPerWstEth, bool isDown) =  _getOracleAnswer(rateProviderOracle);
        if (isDown) {
            return (0, true);
        }
        return (stEthPerWstEth, false);
    }
}
