// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "src/CoGNO.sol";

contract CoGNOTest is DevTestSetup {
    uint256 constant NUM_COLLATERALS = 1;
    TestDeployer.LiquityContractsDev[] public contractsArray;
    CollateralGNO coGNO;
    
    uint256[] troveIds;

    function _openTrove(
        address _account,
        uint256 _index,
        uint256 _coll,
        uint256 _boldAmount,
        uint256 _annualInterestRate
    ) internal returns (uint256 troveId) {
        TroveChange memory troveChange;
        troveChange.debtIncrease = _boldAmount;
        troveChange.newWeightedRecordedDebt = troveChange.debtIncrease * _annualInterestRate;
        uint256 avgInterestRate =
            contractsArray[0].activePool.getNewApproxAvgInterestRateFromTroveChange(troveChange);
        uint256 upfrontFee = calcUpfrontFee(troveChange.debtIncrease, avgInterestRate);

        vm.startPrank(_account);
        troveId = contractsArray[0].borrowerOperations.openTrove(
            _account,
            _index,
            _coll,
            _boldAmount,
            0,
            0,
            _annualInterestRate,
            upfrontFee,
            address(0),
            address(0),
            address(0)
        );
        vm.stopPrank();
    }

    function setUp() public override {
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

        TestDeployer.TroveManagerParams[] memory troveManagerParamsArray =
            new TestDeployer.TroveManagerParams[](NUM_COLLATERALS);
        // GNO-like params: CCR 165%, MCR 140%, SCR 115%
        troveManagerParamsArray[0] = TestDeployer.TroveManagerParams(165e16, 140e16, 10e16, 115e16, 5e16, 10e16);

        TestDeployer deployer = new TestDeployer();
        TestDeployer.LiquityContractsDev[] memory _contractsArray;
        (_contractsArray, collateralRegistry, boldToken,,, WETH,) =
            deployer.deployAndConnectContractsMultiColl(troveManagerParamsArray);
        
        for (uint256 c = 0; c < NUM_COLLATERALS; c++) {
            contractsArray.push(_contractsArray[c]);
        }

        // Set price feed
        contractsArray[0].priceFeed.setPrice(200e18); // GNO ~$200

        // Deploy CoGNO pointing to the trove manager
        coGNO = new CollateralGNO(address(contractsArray[0].troveManager));

        // Give collateral to test accounts
        uint256 initialCollateralAmount = 10_000e18;
        for (uint256 i = 0; i < 6; i++) {
            giveAndApproveCollateral(
                contractsArray[0].collToken,
                accountsList[i],
                initialCollateralAmount,
                address(contractsArray[0].borrowerOperations)
            );
            vm.startPrank(accountsList[i]);
            WETH.approve(address(contractsArray[0].borrowerOperations), type(uint256).max);
            vm.stopPrank();
        }
    }

    // ============ Constructor Tests ============

    function testConstructorRevertsOnZeroAddress() public {
        vm.expectRevert("Invalid trove manager address");
        new CollateralGNO(address(0));
    }

    function testConstructorSetsTroveManager() public {
        assertEq(address(coGNO.troveManager()), address(contractsArray[0].troveManager));
    }

    function testTokenNameAndSymbol() public {
        assertEq(coGNO.name(), "coGNO");
        assertEq(coGNO.symbol(), "coGNO");
    }

    // ============ balanceOf Tests ============

    function testBalanceOfZeroForNoTroves() public {
        assertEq(coGNO.balanceOf(A), 0);
    }

    function testBalanceOfSingleTrove() public {
        uint256 collAmount = 100e18;
        _openTrove(A, 0, collAmount, 2000e18, 5e16);

        assertEq(coGNO.balanceOf(A), collAmount);
    }

    function testBalanceOfMultipleTroves() public {
        uint256 coll1 = 100e18;
        uint256 coll2 = 200e18;
        uint256 coll3 = 300e18;

        _openTrove(A, 0, coll1, 2000e18, 5e16);
        _openTrove(A, 1, coll2, 2000e18, 6e16);
        _openTrove(A, 2, coll3, 2000e18, 7e16);

        assertEq(coGNO.balanceOf(A), coll1 + coll2 + coll3);
    }

    function testBalanceOfMultipleUsers() public {
        uint256 collA = 100e18;
        uint256 collB = 200e18;

        _openTrove(A, 0, collA, 2000e18, 5e16);
        _openTrove(B, 0, collB, 2000e18, 5e16);

        assertEq(coGNO.balanceOf(A), collA);
        assertEq(coGNO.balanceOf(B), collB);
    }

    function testBalanceUpdatesOnAddCollateral() public {
        uint256 initialColl = 100e18;
        uint256 addColl = 50e18;
        
        uint256 troveId = _openTrove(A, 0, initialColl, 2000e18, 5e16);
        assertEq(coGNO.balanceOf(A), initialColl);

        vm.startPrank(A);
        contractsArray[0].borrowerOperations.addColl(troveId, addColl);
        vm.stopPrank();

        assertEq(coGNO.balanceOf(A), initialColl + addColl);
    }

    function testBalanceUpdatesOnWithdrawCollateral() public {
        uint256 initialColl = 200e18;
        uint256 withdrawColl = 50e18;
        
        uint256 troveId = _openTrove(A, 0, initialColl, 2000e18, 5e16);
        assertEq(coGNO.balanceOf(A), initialColl);

        vm.startPrank(A);
        contractsArray[0].borrowerOperations.withdrawColl(troveId, withdrawColl);
        vm.stopPrank();

        assertEq(coGNO.balanceOf(A), initialColl - withdrawColl);
    }

    function testBalanceUpdatesOnCloseTrove() public {
        // Open two troves so we can close one
        uint256 coll1 = 100e18;
        uint256 coll2 = 200e18;
        
        uint256 troveId1 = _openTrove(A, 0, coll1, 2000e18, 5e16);
        _openTrove(B, 0, coll2, 2000e18, 5e16);

        assertEq(coGNO.balanceOf(A), coll1);

        // Get debt to repay
        uint256 debtToRepay = contractsArray[0].troveManager.getTroveEntireDebt(troveId1);
        deal(address(boldToken), A, debtToRepay);

        vm.startPrank(A);
        contractsArray[0].borrowerOperations.closeTrove(troveId1);
        vm.stopPrank();

        assertEq(coGNO.balanceOf(A), 0);
    }

    // ============ totalSupply Tests ============

    function testTotalSupplyZeroInitially() public {
        assertEq(coGNO.totalSupply(), 0);
    }

    function testTotalSupplyMatchesBranchCollateral() public {
        uint256 collA = 100e18;
        uint256 collB = 200e18;

        _openTrove(A, 0, collA, 2000e18, 5e16);
        _openTrove(B, 0, collB, 2000e18, 5e16);

        assertEq(coGNO.totalSupply(), collA + collB);
    }

    function testTotalSupplyUpdatesOnAddCollateral() public {
        uint256 initialColl = 100e18;
        uint256 addColl = 50e18;
        
        uint256 troveId = _openTrove(A, 0, initialColl, 2000e18, 5e16);
        assertEq(coGNO.totalSupply(), initialColl);

        vm.startPrank(A);
        contractsArray[0].borrowerOperations.addColl(troveId, addColl);
        vm.stopPrank();

        assertEq(coGNO.totalSupply(), initialColl + addColl);
    }

    // ============ Non-Transferable Tests ============

    function testTransferReverts() public {
        _openTrove(A, 0, 100e18, 2000e18, 5e16);

        vm.prank(A);
        vm.expectRevert("Token is non-transferable");
        coGNO.transfer(B, 50e18);
    }

    function testTransferFromReverts() public {
        _openTrove(A, 0, 100e18, 2000e18, 5e16);

        vm.prank(A);
        vm.expectRevert("Token is non-transferable");
        coGNO.transferFrom(A, B, 50e18);
    }

    function testApproveReverts() public {
        vm.prank(A);
        vm.expectRevert("Token is non-transferable");
        coGNO.approve(B, 100e18);
    }

    // ============ Edge Cases ============

    function testBalanceOfNonExistentAccount() public {
        address nobody = address(0xdead);
        assertEq(coGNO.balanceOf(nobody), 0);
    }

    function testDecimalsIs18() public {
        assertEq(coGNO.decimals(), 18);
    }

    function testAllowanceAlwaysZero() public {
        // Since approve reverts, allowance should always be 0
        assertEq(coGNO.allowance(A, B), 0);
    }
}

