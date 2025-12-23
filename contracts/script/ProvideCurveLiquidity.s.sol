// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {UseDeployment} from "test/Utils/UseDeployment.sol";

contract ProvideCurveLiquidity is Script, UseDeployment {
    function run() external {
        vm.startBroadcast();
        _loadDeploymentFromManifest("deployment-manifest.json");

        uint256 evroAmount = 200_000 ether;
        uint256 usdcAmount = evroAmount * 10 ** usdc.decimals() / 10 ** evroToken.decimals();

        uint256[] memory amounts = new uint256[](2);
        (amounts[0], amounts[1]) = curveUsdcEvro.coins(0) == BOLD ? (evroAmount, usdcAmount) : (usdcAmount, evroAmount);

        evroToken.approve(address(curveUsdcEvro), evroAmount);
        usdc.approve(address(curveUsdcEvro), usdcAmount);
        curveUsdcEvro.add_liquidity(amounts, 0);
    }
}
