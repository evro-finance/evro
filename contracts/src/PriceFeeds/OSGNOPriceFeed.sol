// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./MainnetPriceFeedBase.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

//  OSGNO/GNO price feed on gnosis 0x9B1b13afA6a57e54C03AD0428a4766C39707D272
contract OSGNOPriceFeed is MainnetPriceFeedBase {
    Oracle public gnoUsdOracle;
    
    constructor(address _osgnoGnoOracleAddress, address _gnoUSDOracleAddress, address _eurUsdOracleAddress, uint256 _osgnoGnoStalenessThreshold, uint256 _gnoUSDStalenessThreshold, uint256 _usdEurStalenessThreshold, address _borrowerOperationsAddress)
        MainnetPriceFeedBase(_osgnoGnoOracleAddress, _osgnoGnoStalenessThreshold, _borrowerOperationsAddress, _eurUsdOracleAddress, _usdEurStalenessThreshold)
    {
        gnoUsdOracle.aggregator = AggregatorV3Interface(_gnoUSDOracleAddress);
        gnoUsdOracle.stalenessThreshold = _gnoUSDStalenessThreshold;
        gnoUsdOracle.decimals = gnoUsdOracle.aggregator.decimals();

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
        // ethUsd is the osGno/Gno oracle
        (uint256 osGnoGnoPrice, bool ethUsdOracleDown) = _getOracleAnswer(ethUsdOracle);
        (uint256 gnoUSDPrice, bool gnoEurOracleDown) = _getOracleAnswer(gnoUsdOracle);
        (uint256 eurUsdPrice, bool eurUsdOracleDown) = _getOracleAnswer(eurUsdOracle);

        // If the ETH-USD Chainlink response was invalid in this transaction, return the last good ETH-USD price calculated
        if (ethUsdOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(ethUsdOracle.aggregator)), true);
        if (gnoEurOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(gnoUsdOracle.aggregator)), true);
        if (eurUsdOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(eurUsdOracle.aggregator)), true);

        // convert usd to eur
        uint256 osgnoUsdPrice = FixedPointMathLib.mulWadUp(osGnoGnoPrice, gnoUSDPrice);
        uint256 osgnoEurPrice = FixedPointMathLib.divWad(osgnoUsdPrice, eurUsdPrice);
        
        lastGoodPrice = osgnoEurPrice;
        return (osgnoEurPrice, false);
    }
}
