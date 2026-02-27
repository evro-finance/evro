// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {StringFormatting} from "test/Utils/StringFormatting.sol";
import {IEvroToken} from "src/Interfaces/IEvroToken.sol";
import {ICollateralRegistry} from "src/Interfaces/ICollateralRegistry.sol";
import {DECIMAL_PRECISION} from "src/Dependencies/Constants.sol";

//source .env && forge script script/RedeemCollateral.s.sol --rpc-url $GNOSIS_RPC_URL
// source .env && forge script script/RedeemCollateral.s.sol --rpc-url $GNOSIS_RPC_URL --account deployerKey
contract RedeemCollateral is Script {
    using Strings for *;
    using StringFormatting for *;

    function run() external {
        string memory manifestJson;
        try vm.readFile("gnosis-deployment-v1.json") returns (string memory content) {
            manifestJson = content;
        } catch {}

        ICollateralRegistry collateralRegistry;
        try vm.envAddress("COLLATERAL_REGISTRY") returns (address value) {
            collateralRegistry = ICollateralRegistry(value);
        } catch {
            collateralRegistry = ICollateralRegistry(vm.parseJsonAddress(manifestJson, ".collateralRegistry"));
        }
        vm.label(address(collateralRegistry), "CollateralRegistry");

        IEvroToken evroToken = IEvroToken(collateralRegistry.evroToken());
        vm.label(address(evroToken), "EvroToken");

        address sender = 0x09D5Bd4a4f1dA1A965fE24EA54bce3d37661E056;
        console.log("Sender:", sender);

        uint256 evroBefore = evroToken.balanceOf(sender);
        console.log("EVRO balance:", evroBefore.decimal());
        require(evroBefore > 0, "No EVRO to redeem");

        uint256[] memory collBefore = new uint256[](collateralRegistry.totalCollaterals());
        for (uint256 i = 0; i < collBefore.length; ++i) {
            collBefore[i] = collateralRegistry.getToken(i).balanceOf(sender);
        }

        vm.startBroadcast();

        uint256 attemptedEvroAmount;
        try vm.envUint("AMOUNT") returns (uint256 amount) {
            attemptedEvroAmount = amount * DECIMAL_PRECISION;
        } catch {
            attemptedEvroAmount = evroBefore;
        }
        if (attemptedEvroAmount == 0) {
            attemptedEvroAmount = evroBefore;
        }
        console.log("Attempting to redeem (EVRO):", attemptedEvroAmount.decimal());

        uint256 maxFeePct = collateralRegistry.getRedemptionRateForRedeemedAmount(attemptedEvroAmount);
        collateralRegistry.redeemCollateral(attemptedEvroAmount, 10, maxFeePct);

        vm.stopBroadcast();

        uint256 evroAfter = evroToken.balanceOf(sender);
        console.log("EVRO balance after:", evroAfter.decimal());
        uint256 actualEvroAmount = evroBefore - evroAfter;
        console.log("Actually redeemed (EVRO):", actualEvroAmount.decimal());

        uint256[] memory collAmount = new uint256[](collBefore.length);
        for (uint256 i = 0; i < collBefore.length; ++i) {
            collAmount[i] = collateralRegistry.getToken(i).balanceOf(sender) - collBefore[i];
            console.log("Received coll", string.concat("#", i.toString(), ":"), collAmount[i].decimal());
        }
    }
}
