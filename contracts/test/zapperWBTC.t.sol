// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./TestContracts/DevTestSetup.sol";
import "./TestContracts/WETH.sol";
import "src/Zappers/WBTCZapper.sol";
import "src/Dependencies/WBTCWrapper.sol";
import "src/Dependencies/Constants.sol";
import "src/Interfaces/ITroveManager.sol";
import {ERC20MinterMock} from "./TestContracts/ERC20MinterMock.sol";


contract WBTC is ERC20MinterMock {
    constructor()
        ERC20MinterMock("Wrapped Bitcoin", "WBTC")
    {}

    function decimals() public view override returns (uint8) {
        return 8;
    }
}

contract ZapperWBTCTest is DevTestSetup {
    WBTCZapper public wbtcZapper;
    WBTCWrapper public wbtcWrapper;
    ERC20MinterMock public wbtc;

    function setUp() public override {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        (A, B, C, D, E, F, G) = (
            accountsList[0],
            accountsList[1],
            accountsList[2],
            accountsList[3],
            accountsList[4],
            accountsList[5],
            accountsList[6]
        );

        wbtc = new WBTC();
        WETH = new WETH9();

        TestDeployer.TroveManagerParams[] memory troveManagerParams = new TestDeployer.TroveManagerParams[](2);
        troveManagerParams[0] = TestDeployer.TroveManagerParams(150e16, 110e16, 10e16, 110e16, 5e16, 10e16);
        troveManagerParams[1] = TestDeployer.TroveManagerParams(150e16, 110e16, 10e16, 110e16, 5e16, 10e16);

        TestDeployer deployer = new TestDeployer();
        TestDeployer.LiquityContractsDev[] memory contractsArray;
        TestDeployer.Zappers[] memory zappersArray;
        (contractsArray, collateralRegistry, evroToken,,, zappersArray, wbtcWrapper) =
            deployer.deployAndConnectContractsWithWBTC(troveManagerParams, WETH, address(wbtc));

        // Set price feeds
        contractsArray[0].priceFeed.setPrice(2000e18);
        contractsArray[1].priceFeed.setPrice(2000e18);

        // Set first branch as default
        addressesRegistry = contractsArray[1].addressesRegistry;
        borrowerOperations = contractsArray[1].borrowerOperations;
        troveManager = contractsArray[1].troveManager;
        troveNFT = contractsArray[1].troveNFT;
        wbtcZapper = zappersArray[1].wbtcZapper;

        // Give some Collateral to test accounts
        uint256 initialCollateralAmount = 10_000e18;

        // A to F
        for (uint256 i = 0; i < 6; i++) {
            // Give some raw ETH to test accounts
            deal(accountsList[i], initialCollateralAmount);
            //give some wbtc to test accounts
            wbtc.mint(accountsList[i], initialCollateralAmount);
            //approve wbtc to zapper
            wbtc.approve(address(wbtcZapper), initialCollateralAmount);
        }
    }

    function testZapperCanOpenTrove() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount = 10000e18;

        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);
        assertGt(wbtcBalanceBefore, 0, "WBTC bal 0");

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        assertEq(troveNFT.ownerOf(troveId), A, "Wrong owner");
        assertGt(troveId, 0, "Trove id should be set");
        assertEq(troveManager.getTroveEntireColl(troveId), wwbtcAmount, "Coll mismatch");
        assertGt(troveManager.getTroveEntireDebt(troveId), evroAmount, "Debt mismatch");
        assertEq(evroToken.balanceOf(A), evroAmount, "BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), wbtcBalanceBefore - wbtcAmount, "WBTC bal mismatch");
    }

    function testCanOpenTroveWithBatchManager() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount = 10000e18;

        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);
        assertGt(wbtcBalanceBefore, 0, "WBTC bal 0");

        registerBatchManager(B);

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 0,
            batchManager: B,
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);

        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        assertEq(troveNFT.ownerOf(troveId), A, "Wrong owner");
        assertGt(troveId, 0, "Trove id should be set");
        assertEq(troveManager.getTroveEntireColl(troveId), wwbtcAmount, "Coll mismatch");
        assertGt(troveManager.getTroveEntireDebt(troveId), evroAmount, "Debt mismatch");
        assertEq(evroToken.balanceOf(A), evroAmount, "BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), wbtcBalanceBefore - wbtcAmount, "WBTC bal mismatch");
        assertEq(borrowerOperations.interestBatchManagerOf(troveId), B, "Wrong batch manager");
        (,,,,,,,, address tmBatchManagerAddress,) = troveManager.Troves(troveId);
        assertEq(tmBatchManagerAddress, B, "Wrong batch manager (TM)");
    }

    function testCanNotOpenTroveWithBatchManagerAndInterest() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 evroAmount = 10000e18;

        registerBatchManager(B);

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16,
            batchManager: B,
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        vm.expectRevert("WBTCZapper: Cannot choose interest if joining a batch");
        wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();
    }
    
    function testCanAddColl() external {
        uint256 wwbtcAmount1 = 10 ether;
        uint256 wbtcAmount1 = wwbtcAmount1 / 1e10;
        uint256 wwbtcAmount2 = 5 ether;
        uint256 wbtcAmount2 = wwbtcAmount2 / 1e10;
        uint256 evroAmount = 10000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount1,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount2);
        wbtcZapper.addCollWithWBTC(troveId, wwbtcAmount2);
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), wwbtcAmount1 + wwbtcAmount2, "Coll mismatch");
        assertGt(troveManager.getTroveEntireDebt(troveId), evroAmount, "Debt mismatch");
        assertEq(evroToken.balanceOf(A), evroAmount, "BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), wbtcBalanceBefore - wbtcAmount2, "WBTC bal mismatch");
    }

    function testCanWithdrawColl() external {
        uint256 wwbtcAmount1 = 10 ether;
        uint256 wbtcAmount1 = wwbtcAmount1 / 1e10;
        uint256 wwbtcAmount2 = 1 ether;
        uint256 wbtcAmount2 = wwbtcAmount2 / 1e10;
        uint256 evroAmount = 10000e18;


        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount1,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount2);
        wbtcZapper.withdrawCollToWBTC(troveId, wwbtcAmount2);
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), wwbtcAmount1 - wwbtcAmount2, "Coll mismatch");
        assertGt(troveManager.getTroveEntireDebt(troveId), evroAmount, "Debt mismatch");
        assertEq(evroToken.balanceOf(A), evroAmount, "BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), wbtcBalanceBefore + wbtcAmount2, "WBTC bal mismatch");
    }

    function testCannotWithdrawCollIfZapperIsNotReceiver() external {
        uint256 wwbtcAmount1 = 10 ether;
        uint256 wbtcAmount1 = wwbtcAmount1 / 1e10;
        uint256 wwbtcAmount2 = 1 ether;
        uint256 wbtcAmount2 = wwbtcAmount2 / 1e10;
        uint256 evroAmount = 10000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount1,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        vm.startPrank(A);
        // Change receiver in BO
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wbtcZapper), B);
        wbtc.approve(address(wbtcZapper), wbtcAmount2);
        vm.expectRevert("BZ: Zapper is not receiver for this trove");
        wbtcZapper.withdrawCollToWBTC(troveId, wwbtcAmount2);
        vm.stopPrank();
    }

    function testCanNotAddReceiverWithoutRemoveManager() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount1 = 10000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        // Try to add a receiver for the zapper without remove manager
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        vm.expectRevert(AddRemoveManagers.EmptyManager.selector);
        wbtcZapper.setRemoveManagerWithReceiver(troveId, address(0), B);
        vm.stopPrank();
    }

    function testCanRepayEvro() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount1 = 10000e18;
        uint256 evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        uint256 evroBalanceBeforeA = evroToken.balanceOf(A);
        uint256 evroBalanceBeforeB = evroToken.balanceOf(B);

        // Add a remove manager for the zapper, and send evro
        vm.startPrank(A);
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        evroToken.transfer(B, evroAmount2);
        vm.stopPrank();

        // Approve and repay
        vm.startPrank(B);
        evroToken.approve(address(wbtcZapper), evroAmount2);
        wbtcZapper.repayEvro(troveId, evroAmount2);
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), wwbtcAmount, "Trove coll mismatch");
        assertApproxEqAbs(
            troveManager.getTroveEntireDebt(troveId), evroAmount1 - evroAmount2, 2e18, "Trove  debt mismatch"
        );
        assertEq(evroToken.balanceOf(A), evroBalanceBeforeA - evroAmount2, "A BOLD bal mismatch");
        assertEq(evroToken.balanceOf(B), evroBalanceBeforeB, "B BOLD bal mismatch");
    }

    function testCanWithdrawEvro() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount1 = 10000e18;
        uint256 evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        uint256 evroBalanceBeforeA = evroToken.balanceOf(A);
        uint256 evroBalanceBeforeB = evroToken.balanceOf(B);

        // Add a remove manager for the zapper
        vm.startPrank(A);
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        vm.stopPrank();

        // Withdraw evro
        vm.startPrank(B);
        wbtcZapper.withdrawEvro(troveId, evroAmount2, evroAmount2);
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), wwbtcAmount, "Trove coll mismatch");
        assertApproxEqAbs(
            troveManager.getTroveEntireDebt(troveId), evroAmount1 + evroAmount2, 2e18, "Trove  debt mismatch"
        );
        assertEq(evroToken.balanceOf(A), evroBalanceBeforeA + evroAmount2, "A BOLD bal mismatch");
        assertEq(evroToken.balanceOf(B), evroBalanceBeforeB, "B BOLD bal mismatch");
    }

    function testCannotWithdrawEvroIfZapperIsNotReceiver() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount1 = 10000e18;
        uint256 evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        // Add a remove manager for the zapper
        vm.startPrank(A);
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        // Change receiver in BO
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wbtcZapper), C);
        vm.stopPrank();

        // Withdraw evro
        vm.startPrank(B);
        vm.expectRevert("BZ: Zapper is not receiver for this trove");
        wbtcZapper.withdrawEvro(troveId, evroAmount2, evroAmount2);
        vm.stopPrank();
    }

    // TODO: more adjustment combinations
    function testCanAdjustTroveWithdrawCollAndEvro() external {
        uint256 wwbtcAmount1 = 10 ether;
        uint256 wbtcAmount1 = wwbtcAmount1 / 1e10;
        uint256 wwbtcAmount2 = 1 ether;
        uint256 wbtcAmount2 = wwbtcAmount2 / 1e10;
        uint256 evroAmount1 = 10000e18;
        uint256 evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount1,
            evroAmount: evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        uint256 evroBalanceBeforeA = evroToken.balanceOf(A);
        uint256 wbtcBalanceBeforeA = wbtc.balanceOf(A);
        uint256 evroBalanceBeforeB = evroToken.balanceOf(B);
        uint256 wbtcBalanceBeforeB = wbtc.balanceOf(B);

        // Add a remove manager for the zapper
        vm.startPrank(A);
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        vm.stopPrank();

        // Adjust (withdraw coll and Evro)
        vm.startPrank(B);
        wbtcZapper.adjustTroveWithWBTC(troveId, wwbtcAmount2, false, evroAmount2, true, evroAmount2);
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), wwbtcAmount1 - wwbtcAmount2, "Trove coll mismatch");
        assertApproxEqAbs(
            troveManager.getTroveEntireDebt(troveId), evroAmount1 + evroAmount2, 2e18, "Trove  debt mismatch"
        );
        assertEq(evroToken.balanceOf(A), evroBalanceBeforeA + evroAmount2, "A BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), wbtcBalanceBeforeA + wbtcAmount2, "A WBTC bal mismatch");
        assertEq(evroToken.balanceOf(B), evroBalanceBeforeB, "B BOLD bal mismatch");
        assertEq(wbtc.balanceOf(B), wbtcBalanceBeforeB, "B WBTC bal mismatch");
    }

    function testCannotAdjustTroveWithdrawCollAndEvroIfZapperIsNotReceiver() external {
        uint256 wwbtcAmount1 = 10 ether;
        uint256 wbtcAmount1 = wwbtcAmount1 / 1e10;
        uint256 wwbtcAmount2 = 1 ether;
        uint256 evroAmount1 = 10000e18;
        uint256 evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount1,
            evroAmount: evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        vm.startPrank(A);
        // Add a remove manager for the zapper
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        // Change receiver in BO
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wbtcZapper), C);
        vm.stopPrank();

        // Adjust (withdraw coll and Evro)
        vm.startPrank(B);
        vm.expectRevert("BZ: Zapper is not receiver for this trove");
        wbtcZapper.adjustTroveWithWBTC(troveId, wwbtcAmount2, false, evroAmount2, true, evroAmount2);
        vm.stopPrank();
    }

    function testCanAdjustTroveAddCollAndEvro() external {
        uint256 wwbtcAmount1 = 10 ether;
        uint256 wbtcAmount1 = wwbtcAmount1 / 1e10;
        uint256 wwbtcAmount2 = 1 ether;
        uint256 wbtcAmount2 = wwbtcAmount2 / 1e10;
        uint256 evroAmount1 = 10000e18;
        uint256 evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount1,
            evroAmount: evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        // A sends Evro to B
        evroToken.transfer(B, evroAmount2);
        vm.stopPrank();

        uint256 evroBalanceBeforeA = evroToken.balanceOf(A);
        uint256 wbtcBalanceBeforeA = wbtc.balanceOf(A);
        uint256 evroBalanceBeforeB = evroToken.balanceOf(B);
        uint256 wbtcBalanceBeforeB = wbtc.balanceOf(B);

        // Add an add manager for the zapper
        vm.startPrank(A);
        wbtcZapper.setAddManager(troveId, B);
        vm.stopPrank();

        // Adjust (add coll and Evro)
        vm.startPrank(B);
        wbtc.approve(address(wbtcZapper), wbtcAmount2);
        evroToken.approve(address(wbtcZapper), evroAmount2);
        wbtcZapper.adjustTroveWithWBTC(troveId, wwbtcAmount2, true, evroAmount2, false, evroAmount2);
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), wwbtcAmount1 + wwbtcAmount2, "Trove coll mismatch");
        assertApproxEqAbs(
            troveManager.getTroveEntireDebt(troveId), evroAmount1 - evroAmount2, 2e18, "Trove  debt mismatch"
        );
        assertEq(evroToken.balanceOf(A), evroBalanceBeforeA, "A BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), wbtcBalanceBeforeA, "A WBTC bal mismatch");
        assertEq(evroToken.balanceOf(B), evroBalanceBeforeB - evroAmount2, "B BOLD bal mismatch");
        assertEq(wbtc.balanceOf(B), wbtcBalanceBeforeB - wbtcAmount2, "B WBTC bal mismatch");
    }
    
    struct CollData {
        uint256 wwbtcAmount1;
        uint256 wbtcAmount1;
        uint256 wwbtcAmount2;
        uint256 wbtcAmount2;
        uint256 evroAmount1;
        uint256 evroAmount2;
        uint256 wbtcBalanceBeforeA;
        uint256 wbtcBalanceBeforeB;
        uint256 evroBalanceBeforeA;
        uint256 troveCollBefore;
    }
    function testCanAdjustZombieTroveWithdrawCollAndEvro() external {
        CollData memory collData;
        collData.wwbtcAmount1 = 10 ether;
        collData.wbtcAmount1 = collData.wwbtcAmount1 / 1e10;
        collData.wwbtcAmount2 = 1 ether;
        collData.wbtcAmount2 = collData.wwbtcAmount2 / 1e10;
        collData.evroAmount1 = 10000e18;
        collData.evroAmount2 = 1000e18;
        uint256 troveId;

        {
        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: collData.wwbtcAmount1,
            evroAmount: collData.evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), collData.wbtcAmount1);
        troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

                // Add a remove manager for the zapper
        vm.startPrank(A);
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        vm.stopPrank();
        }



        // Redeem to make trove zombie (need to redeem enough so remaining debt < MIN_DEBT)
        vm.startPrank(A);
        uint256 currentDebt = troveManager.getTroveEntireDebt(troveId);
        // Redeem enough to get below MIN_DEBT, but leave some room for the adjustment
        uint256 redeemAmount = currentDebt - MIN_DEBT / 2;
        collateralRegistry.redeemCollateral(redeemAmount, 10, 1e18);
        vm.stopPrank();

        // Verify trove is zombie
        assertEq(uint256(troveManager.getTroveStatus(troveId)), uint256(ITroveManager.Status.zombie), "Trove should be zombie");

        collData.troveCollBefore = troveManager.getTroveEntireColl(troveId);
        collData.evroBalanceBeforeA = evroToken.balanceOf(A);
        collData.wbtcBalanceBeforeA = wbtc.balanceOf(A);
        collData.wbtcBalanceBeforeB = wbtc.balanceOf(B);

        // Adjust (withdraw coll and Evro)
        vm.startPrank(B);
        wbtcZapper.adjustZombieTroveWithWBTC(troveId, collData.wwbtcAmount2, false, collData.evroAmount2, true, 0, 0, collData.evroAmount2);
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), collData.troveCollBefore - collData.wwbtcAmount2, "Trove coll mismatch");
        // After adjustment, debt should be MIN_DEBT/2 + collData.evroAmount2 (withdrawn)
        uint256 expectedDebt = MIN_DEBT / 2 + collData.evroAmount2;
        assertApproxEqAbs(troveManager.getTroveEntireDebt(troveId), expectedDebt, 2e18, "Trove  debt mismatch");
        assertEq(evroToken.balanceOf(A), collData.evroBalanceBeforeA + collData.evroAmount2, "A BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), collData.wbtcBalanceBeforeA + collData.wbtcAmount2, "A WBTC bal mismatch");
        assertEq(evroToken.balanceOf(B), 0, "B BOLD bal mismatch");
        assertEq(wbtc.balanceOf(B), collData.wbtcBalanceBeforeB, "B WBTC bal mismatch");
    }

    function testCannotAdjustZombieTroveWithdrawCollAndEvroIfZapperIsNotReceiver() external {
        CollData memory collData;   
        collData.wwbtcAmount1 = 10 ether;
        collData.wbtcAmount1 = collData.wwbtcAmount1 / 1e10;
        collData.wwbtcAmount2 = 1 ether;
        collData.wbtcAmount2 = collData.wwbtcAmount2 / 1e10;
        collData.evroAmount1 = 10000e18;
        collData.evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: collData.wwbtcAmount1,
            evroAmount: collData.evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), collData.wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        vm.startPrank(A);
        // Add a remove manager for the zapper
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        // Change receiver in BO
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wbtcZapper), C);
        vm.stopPrank();

        // Redeem to make trove zombie (need to redeem enough so remaining debt < MIN_DEBT)
        vm.startPrank(A);
        uint256 currentDebt = troveManager.getTroveEntireDebt(troveId);
        uint256 redeemAmount = currentDebt - MIN_DEBT / 2;
        collateralRegistry.redeemCollateral(redeemAmount, 10, 1e18);
        vm.stopPrank();

        // Verify trove is zombie
        assertEq(uint256(troveManager.getTroveStatus(troveId)), uint256(ITroveManager.Status.zombie), "Trove should be zombie");

        // Adjust (withdraw coll and Evro)
        vm.startPrank(B);
        vm.expectRevert("BZ: Zapper is not receiver for this trove");
        wbtcZapper.adjustZombieTroveWithWBTC(troveId, collData.wwbtcAmount2, false, collData.evroAmount2, true, 0, 0, collData.evroAmount2);
        vm.stopPrank();
    }

    function testCanAdjustZombieTroveAddCollAndWithdrawEvro() external {
        CollData memory collData;
        collData.wwbtcAmount1 = 10 ether;
        collData.wbtcAmount1 = collData.wwbtcAmount1 / 1e10;
        collData.wwbtcAmount2 = 1 ether;
        collData.wbtcAmount2 = collData.wwbtcAmount2 / 1e10;
        collData.evroAmount1 = 10000e18;
        collData.evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: collData.wwbtcAmount1,
            evroAmount: collData.evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), collData.wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        // Add a remove manager for the zapper
        vm.startPrank(A);
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        vm.stopPrank();

        // Redeem to make trove zombie (need to redeem enough so remaining debt < MIN_DEBT)
        vm.startPrank(A);
        uint256 currentDebt = troveManager.getTroveEntireDebt(troveId);
        // Redeem enough to get below MIN_DEBT, but leave some room for the adjustment
        uint256 redeemAmount = currentDebt - MIN_DEBT / 2;
        collateralRegistry.redeemCollateral(redeemAmount, 10, 1e18);
        vm.stopPrank();

        // Verify trove is zombie
        assertEq(uint256(troveManager.getTroveStatus(troveId)), uint256(ITroveManager.Status.zombie), "Trove should be zombie");

        collData.troveCollBefore = troveManager.getTroveEntireColl(troveId);
        collData.evroBalanceBeforeA = evroToken.balanceOf(A);
        collData.wbtcBalanceBeforeA = wbtc.balanceOf(A);
        collData.wbtcBalanceBeforeB = wbtc.balanceOf(B);

        // Adjust (add coll and withdraw Evro)
        vm.startPrank(B);
        wbtc.approve(address(wbtcZapper), collData.wbtcAmount2);
        wbtcZapper.adjustZombieTroveWithWBTC(
            troveId, collData.wwbtcAmount2, true, collData.evroAmount2, true, 0, 0, collData.evroAmount2
        );
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), collData.troveCollBefore + collData.wwbtcAmount2, "Trove coll mismatch");
        // After adjustment, debt should be MIN_DEBT/2 + evroAmount2 (withdrawn)
        uint256 expectedDebt = MIN_DEBT / 2 + collData.evroAmount2;
        assertApproxEqAbs(troveManager.getTroveEntireDebt(troveId), expectedDebt, 2e18, "Trove  debt mismatch");
        assertEq(evroToken.balanceOf(A), collData.evroBalanceBeforeA + collData.evroAmount2, "A BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), collData.wbtcBalanceBeforeA, "A WBTC bal mismatch");
        assertEq(evroToken.balanceOf(B), 0, "B BOLD bal mismatch");
        assertEq(wbtc.balanceOf(B), collData.wbtcBalanceBeforeB - collData.wbtcAmount2, "B WBTC bal mismatch");
    }

    function testCannotAdjustZombieTroveAddCollAndWithdrawEvroIfZapperIsNotReceiver() external {
        uint256 wwbtcAmount1 = 10 ether;
        uint256 wbtcAmount1 = wwbtcAmount1 / 1e10;
        uint256 wwbtcAmount2 = 1 ether;
        uint256 evroAmount1 = 10000e18;
        uint256 evroAmount2 = 1000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount1,
            evroAmount: evroAmount1,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount1);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        vm.startPrank(A);
        // Add a remove manager for the zapper
        wbtcZapper.setRemoveManagerWithReceiver(troveId, B, A);
        // Change receiver in BO
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wbtcZapper), C);
        vm.stopPrank();

        // Redeem to make trove zombie (need to redeem enough so remaining debt < MIN_DEBT)
        vm.startPrank(A);
        uint256 currentDebt = troveManager.getTroveEntireDebt(troveId);
        uint256 redeemAmount = currentDebt - MIN_DEBT / 2;
        collateralRegistry.redeemCollateral(redeemAmount, 10, 1e18);
        vm.stopPrank();

        // Verify trove is zombie
        assertEq(uint256(troveManager.getTroveStatus(troveId)), uint256(ITroveManager.Status.zombie), "Trove should be zombie");

        // Adjust (add coll and withdraw Evro)
        vm.startPrank(B);
        vm.expectRevert("BZ: Zapper is not receiver for this trove");
        wbtcZapper.adjustZombieTroveWithWBTC(
            troveId, wwbtcAmount2, true, evroAmount2, true, 0, 0, evroAmount2
        );
        vm.stopPrank();
    }

    function testCanCloseTrove() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount = 10000e18;

        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        // Give B WBTC (8 decimals) - 10 WBTC = 10 * 1e8
        uint256 wbtcAmount2 = 10 * 1e8;
        // Convert to wrapped WBTC (18 decimals) = 10 * 1e8 * 1e10 = 10 ether
        uint256 wwbtcAmount2 = wbtcAmount2 * 1e10;

        wbtc.mint(B, wbtcAmount2);

        // open a 2nd trove so we can close the 1st one, and send Evro to account for interest and fee
        vm.startPrank(B);
        // Give B WETH for gas compensation
        deal(address(WETH), B, ETH_GAS_COMPENSATION);
        WETH.approve(address(borrowerOperations), ETH_GAS_COMPENSATION);
        wbtc.approve(address(wbtcWrapper), wbtcAmount2);
        wbtcWrapper.depositFor(B, wbtcAmount2);
        wbtcWrapper.approve(address(borrowerOperations), wwbtcAmount2);
        borrowerOperations.openTrove(
            B,
            0, // index,
            wwbtcAmount2, // coll,
            10000e18, //evroAmount,
            0, // _upperHint
            0, // _lowerHint
            MIN_ANNUAL_INTEREST_RATE, // annualInterestRate,
            10000e18, // upfrontFee
            address(0),
            address(0),
            address(0)
        );
        evroToken.transfer(A, troveManager.getTroveEntireDebt(troveId) - evroAmount);
        vm.stopPrank();

        vm.startPrank(A);
        evroToken.approve(address(wbtcZapper), type(uint256).max);
        wbtcZapper.closeTroveToWBTC(troveId);
        vm.stopPrank();

        assertEq(troveManager.getTroveEntireColl(troveId), 0, "Coll mismatch");
        assertEq(troveManager.getTroveEntireDebt(troveId), 0, "Debt mismatch");
        assertEq(evroToken.balanceOf(A), 0, "BOLD bal mismatch");
        assertEq(wbtc.balanceOf(A), wbtcBalanceBefore, "WBTC bal mismatch");
    }

    function testCannotCloseTroveIfZapperIsNotReceiver() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount = 10000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        // open a 2nd trove so we can close the 1st one, and send Evro to account for interest and fee

        uint256 wbtcAmount2 = 10 * 1e8;
        uint256 wwbtcAmount2 = wbtcAmount2 * 1e10;

        wbtc.mint(B, wbtcAmount2);
        vm.startPrank(B);
        deal(address(WETH), B, ETH_GAS_COMPENSATION);
        WETH.approve(address(borrowerOperations), ETH_GAS_COMPENSATION);
        wbtc.approve(address(wbtcWrapper), wbtcAmount2);
        wbtcWrapper.depositFor(B, wbtcAmount2);
        wbtcWrapper.approve(address(borrowerOperations), wwbtcAmount2);
        borrowerOperations.openTrove(
            B,
            0, // index,
            wwbtcAmount2, // coll,
            10000e18, //evroAmount,
            0, // _upperHint
            0, // _lowerHint
            MIN_ANNUAL_INTEREST_RATE, // annualInterestRate,
            10000e18, // upfrontFee
            address(0),
            address(0),
            address(0)
        );
        evroToken.transfer(A, troveManager.getTroveEntireDebt(troveId) - evroAmount);
        vm.stopPrank();

        vm.startPrank(A);
        // Change receiver in BO
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wbtcZapper), C);

        evroToken.approve(address(wbtcZapper), type(uint256).max);
        vm.expectRevert("BZ: Zapper is not receiver for this trove");
        wbtcZapper.closeTroveToWBTC(troveId);
        vm.stopPrank();
    }

    function testExcessRepaymentByAdjustGoesBackToUser() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount = 10000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);
        uint256 collBalanceBefore = WETH.balanceOf(A);
        uint256 evroDebtBefore = troveManager.getTroveEntireDebt(troveId);

        // Adjust trove: remove 1 wWBTC and try to repay 9k (only will repay ~8k, up to MIN_DEBT)
        vm.startPrank(A);
        evroToken.approve(address(wbtcZapper), type(uint256).max);
        wbtcZapper.adjustTroveWithWBTC(troveId, 1 ether, false, 9000e18, false, 0);
        vm.stopPrank();

        assertEq(evroToken.balanceOf(A), evroAmount + MIN_DEBT - evroDebtBefore, "BOLD bal mismatch");
        assertEq(evroToken.balanceOf(address(wbtcZapper)), 0, "Zapper BOLD bal should be zero");
        assertEq(wbtc.balanceOf(A), wbtcBalanceBefore + (1 ether / 1e10), "WBTC bal mismatch");
        assertEq(address(wbtcZapper).balance, 0, "Zapper ETH bal should be zero");
        assertEq(WETH.balanceOf(A), collBalanceBefore, "Coll bal mismatch");
        assertEq(WETH.balanceOf(address(wbtcZapper)), 0, "Zapper Coll bal should be zero");
    }

    function testExcessRepaymentByRepayGoesBackToUser() external {
        uint256 wwbtcAmount = 10 ether;
        uint256 wbtcAmount = wwbtcAmount / 1e10;
        uint256 evroAmount = 10000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: wwbtcAmount,
            evroAmount: evroAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: MIN_ANNUAL_INTEREST_RATE,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });
        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), wbtcAmount);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        uint256 evroDebtBefore = troveManager.getTroveEntireDebt(troveId);
        uint256 collBalanceBefore = WETH.balanceOf(A);

        // Adjust trove: try to repay 9k (only will repay ~8k, up to MIN_DEBT)
        vm.startPrank(A);
        evroToken.approve(address(wbtcZapper), type(uint256).max);
        wbtcZapper.repayEvro(troveId, 9000e18);
        vm.stopPrank();

        assertEq(evroToken.balanceOf(A), evroAmount + MIN_DEBT - evroDebtBefore, "BOLD bal mismatch");
        assertEq(evroToken.balanceOf(address(wbtcZapper)), 0, "Zapper BOLD bal should be zero");
        assertEq(address(wbtcZapper).balance, 0, "Zapper ETH bal should be zero");
        assertEq(WETH.balanceOf(A), collBalanceBefore, "Coll bal mismatch");
        assertEq(WETH.balanceOf(address(wbtcZapper)), 0, "Zapper Coll bal should be zero");
    }

    // TODO: tests for add/remove managers of zapper contract
}
