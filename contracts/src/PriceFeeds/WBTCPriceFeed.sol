// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;
 
import "./CompositePriceFeed.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract WBTCPriceFeed is CompositePriceFeed {
    Oracle public btcUsdOracle;
    Oracle public wBTCUsdOracle;

    uint256 public constant BTC_WBTC_DEVIATION_THRESHOLD = 2e16; // 2%

    constructor(
        address _wBTCUsdOracleAddress, 
        address _btcUsdOracleAddress,
        address _eurUsdOracleAddress,
        uint256 _wBTCUsdStalenessThreshold,
        uint256 _btcUsdStalenessThreshold,
        uint256 _usdEurStalenessThreshold,
        address _borrowerOperationsAddress
    ) CompositePriceFeed(_wBTCUsdOracleAddress, _btcUsdOracleAddress, _wBTCUsdStalenessThreshold, _eurUsdOracleAddress, _usdEurStalenessThreshold, _borrowerOperationsAddress)
    {
        // Store BTC-USD oracle
        btcUsdOracle.aggregator = AggregatorV3Interface(_btcUsdOracleAddress);
        btcUsdOracle.stalenessThreshold = _btcUsdStalenessThreshold;
        btcUsdOracle.decimals = btcUsdOracle.aggregator.decimals();

        // Store wBTC-USD oracle
        wBTCUsdOracle.aggregator = AggregatorV3Interface(_wBTCUsdOracleAddress);
        wBTCUsdOracle.stalenessThreshold = _wBTCUsdStalenessThreshold;
        wBTCUsdOracle.decimals = wBTCUsdOracle.aggregator.decimals();

        _fetchPricePrimary(false);

        // Check the oracles didn't already fail
        assert(priceSource == PriceSource.primary);
        assert(eurUsdOracle.decimals == 8);
    }

    function _fetchPricePrimary(bool _isRedemption) internal override returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 wBTCUsdPrice, bool wBTCUsdOracleDown) = _getOracleAnswer(wBTCUsdOracle);
        (uint256 btcUsdPrice, bool btcOracleDown) = _getOracleAnswer(btcUsdOracle);

        (uint256 eurUsdPrice, bool eurUsdOracleDown) = _getOracleAnswer(eurUsdOracle);
        if (eurUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(eurUsdOracle.aggregator)), true);
        }

        // wBTC oracle is down or invalid answer
        if (wBTCUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(wBTCUsdOracle.aggregator)), true);
        }

        // BTC oracle is down or invalid answer
        if (btcOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(btcUsdOracle.aggregator)), true);
        }

        // Otherwise, use the primary price calculation:
        if (_isRedemption && _withinDeviationThreshold(wBTCUsdPrice, btcUsdPrice, BTC_WBTC_DEVIATION_THRESHOLD)) {
            // If it's a redemption and within 2%, take the max of (wBTC-USD, BTC-USD) to prevent value leakage and convert to wBTC-USD
            wBTCUsdPrice = LiquityMath._max(wBTCUsdPrice, btcUsdPrice);
        }else{
            // Take the minimum of (market, canonical) in order to mitigate against upward market price manipulation.
            wBTCUsdPrice = LiquityMath._min(wBTCUsdPrice, btcUsdPrice);
        }
        
        uint256 wBTCEurPrice = FixedPointMathLib.divWad(wBTCUsdPrice, eurUsdPrice);
        lastGoodPrice = wBTCEurPrice;
        return (wBTCEurPrice, false);
    }

    function _getCanonicalRate() internal pure override returns (uint256, bool) {
        return (1 * 10 ** 18, false); // always return 1 BTC per wBTC by default.
    }
}   


