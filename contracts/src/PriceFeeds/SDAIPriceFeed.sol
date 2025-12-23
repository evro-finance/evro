// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./MainnetPriceFeedBase.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract SDAIPriceFeed is MainnetPriceFeedBase {
    IERC4626 public immutable sdai;
    Oracle public eurUsdOracle;

    constructor(address _daiUsdOracleAddress, address _eurUsdOracleAddress, uint256 _daiUsdStalenessThreshold, uint256 _usdEurStalenessThreshold, address _borrowerOperationsAddress, address _sdaiAddress)
        MainnetPriceFeedBase(_daiUsdOracleAddress, _daiUsdStalenessThreshold, _borrowerOperationsAddress)
    {
        eurUsdOracle.aggregator = AggregatorV3Interface(_eurUsdOracleAddress);
        eurUsdOracle.stalenessThreshold = _usdEurStalenessThreshold;
        eurUsdOracle.decimals = eurUsdOracle.aggregator.decimals();

        sdai = IERC4626(_sdaiAddress);
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
        
        (uint256 daiUSDPrice, bool daiEurOracleDown) = _getOracleAnswer(ethUsdOracle);
        (uint256 eurUsdPrice, bool eurUsdOracleDown) = _getOracleAnswer(eurUsdOracle);

        // Get the DAI rate of the SDAI vault
        uint256 sdaiDaiRate = sdai.convertToAssets(1e18);

        // If the DAI-EUR Chainlink response was invalid in this transaction, return the last good ETH-USD price calculated
        if (daiEurOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(ethUsdOracle.aggregator)), true);
        if (sdaiDaiRate == 0) return (_shutDownAndSwitchToLastGoodPrice(address(sdai)), true);
        if (eurUsdOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(eurUsdOracle.aggregator)), true);
        
        uint256 sdaiUSDPrice = FixedPointMathLib.mulWadUp(daiUSDPrice, sdaiDaiRate);
        lastGoodPrice = FixedPointMathLib.divWad(sdaiUSDPrice, eurUsdPrice);

        return (lastGoodPrice, false);
    }
}
