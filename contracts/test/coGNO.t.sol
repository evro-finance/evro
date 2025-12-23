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
        uint256 _evroAmount,
        uint256 _annualInterestRate
    ) internal returns (uint256 troveId) {
        TroveChange memory troveChange;
        troveChange.debtIncrease = _evroAmount;
        troveChange.newWeightedRecordedDebt = troveChange.debtIncrease * _annualInterestRate;
        uint256 avgInterestRate =
            contractsArray[0].activePool.getNewApproxAvgInterestRateFromTroveChange(troveChange);
        uint256 upfrontFee = calcUpfrontFee(troveChange.debtIncrease, avgInterestRate);

        vm.startPrank(_account);
        troveId = contractsArray[0].borrowerOperations.openTrove(
            _account,
            _index,
            _coll,
            _evroAmount,
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
        (_contractsArray, collateralRegistry, evroToken,,, WETH,) =
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
        deal(address(evroToken), A, debtToRepay);

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

    // ============ Invariant Tests ============

    /// @dev Calculate expected balance by summing collateral from all user troves
    function _calculateExpectedBalance(address user) internal view returns (uint256 expected) {
        ITroveNFT troveNFT = contractsArray[0].troveManager.troveNFT();
        uint256[] memory userTroveIds = troveNFT.ownerToTroveIds(user);
        
        for (uint256 i = 0; i < userTroveIds.length; i++) {
            LatestTroveData memory troveData = contractsArray[0].troveManager.getLatestTroveData(userTroveIds[i]);
            expected += troveData.entireColl;
        }
    }

    /// @dev Check invariant: coGNO.balanceOf(user) == sum of user's trove collaterals
    function _assertBalanceInvariant(address user) internal {
        uint256 coGNOBalance = coGNO.balanceOf(user);
        uint256 expectedBalance = _calculateExpectedBalance(user);
        assertEq(coGNOBalance, expectedBalance, "Invariant violated: coGNO balance != trove collateral sum");
    }

    /// @dev Check invariant: coGNO.totalSupply() == branch total collateral
    function _assertTotalSupplyInvariant() internal {
        uint256 coGNOSupply = coGNO.totalSupply();
        uint256 branchColl = contractsArray[0].troveManager.getEntireBranchColl();
        assertEq(coGNOSupply, branchColl, "Invariant violated: coGNO totalSupply != branch collateral");
    }

    function testInvariant_BalanceMatchesTroveCollateral() public {
        // Open multiple troves for multiple users
        _openTrove(A, 0, 100e18, 2000e18, 5e16);
        _openTrove(A, 1, 150e18, 2000e18, 6e16);
        _openTrove(B, 0, 200e18, 2000e18, 5e16);
        _openTrove(C, 0, 300e18, 2000e18, 7e16);

        // Check invariants for all users
        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);
        _assertBalanceInvariant(C);
        _assertTotalSupplyInvariant();
    }

    function testInvariant_AfterAddCollateral() public {
        uint256 troveId = _openTrove(A, 0, 100e18, 2000e18, 5e16);
        _assertBalanceInvariant(A);

        vm.prank(A);
        contractsArray[0].borrowerOperations.addColl(troveId, 50e18);

        _assertBalanceInvariant(A);
        _assertTotalSupplyInvariant();
    }

    function testInvariant_AfterWithdrawCollateral() public {
        uint256 troveId = _openTrove(A, 0, 200e18, 2000e18, 5e16);
        _assertBalanceInvariant(A);

        vm.prank(A);
        contractsArray[0].borrowerOperations.withdrawColl(troveId, 50e18);

        _assertBalanceInvariant(A);
        _assertTotalSupplyInvariant();
    }

    function testInvariant_AfterCloseTrove() public {
        // Need another trove to keep system alive
        _openTrove(B, 0, 200e18, 2000e18, 5e16);
        
        uint256 troveIdA = _openTrove(A, 0, 100e18, 2000e18, 5e16);
        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);

        uint256 debtToRepay = contractsArray[0].troveManager.getTroveEntireDebt(troveIdA);
        deal(address(evroToken), A, debtToRepay);

        vm.prank(A);
        contractsArray[0].borrowerOperations.closeTrove(troveIdA);

        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);
        _assertTotalSupplyInvariant();
    }

    function testInvariant_AfterTroveTransfer() public {
        uint256 troveId = _openTrove(A, 0, 100e18, 2000e18, 5e16);
        
        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);

        // Transfer trove NFT from A to B
        ITroveNFT troveNFT = contractsArray[0].troveManager.troveNFT();
        vm.prank(A);
        troveNFT.transferFrom(A, B, troveId);

        // After transfer, A's balance should be 0, B's should have the collateral
        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);
        _assertTotalSupplyInvariant();
    }

    function testInvariant_ComplexScenario() public {
        // Open troves for multiple users
        uint256 troveA1 = _openTrove(A, 0, 100e18, 2000e18, 5e16);
        uint256 troveA2 = _openTrove(A, 1, 150e18, 2000e18, 6e16);
        uint256 troveB1 = _openTrove(B, 0, 200e18, 2000e18, 5e16);
        _openTrove(C, 0, 300e18, 2000e18, 7e16);

        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);
        _assertBalanceInvariant(C);
        _assertTotalSupplyInvariant();

        // Add collateral to A's first trove
        vm.prank(A);
        contractsArray[0].borrowerOperations.addColl(troveA1, 25e18);

        _assertBalanceInvariant(A);
        _assertTotalSupplyInvariant();

        // Withdraw from A's second trove
        vm.prank(A);
        contractsArray[0].borrowerOperations.withdrawColl(troveA2, 30e18);

        _assertBalanceInvariant(A);
        _assertTotalSupplyInvariant();

        // Transfer B's trove to D
        ITroveNFT troveNFT = contractsArray[0].troveManager.troveNFT();
        vm.prank(B);
        troveNFT.transferFrom(B, D, troveB1);

        _assertBalanceInvariant(B);
        _assertBalanceInvariant(D);
        _assertTotalSupplyInvariant();

        // Close A's first trove
        uint256 debtToRepay = contractsArray[0].troveManager.getTroveEntireDebt(troveA1);
        deal(address(evroToken), A, debtToRepay);
        vm.prank(A);
        contractsArray[0].borrowerOperations.closeTrove(troveA1);

        _assertBalanceInvariant(A);
        _assertTotalSupplyInvariant();

        // Final check all users
        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);
        _assertBalanceInvariant(C);
        _assertBalanceInvariant(D);
    }

    /// @dev Fuzz test: random collateral amounts, verify invariant holds
    function testFuzz_InvariantHoldsForRandomAmounts(
        uint256 collA,
        uint256 collB,
        uint256 addAmount
    ) public {
        // Bound inputs to reasonable ranges
        collA = bound(collA, 50e18, 1000e18);
        collB = bound(collB, 50e18, 1000e18);
        addAmount = bound(addAmount, 1e18, 100e18);

        uint256 troveIdA = _openTrove(A, 0, collA, 2000e18, 5e16);
        _openTrove(B, 0, collB, 2000e18, 5e16);

        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);
        _assertTotalSupplyInvariant();

        // Add collateral
        vm.prank(A);
        contractsArray[0].borrowerOperations.addColl(troveIdA, addAmount);

        _assertBalanceInvariant(A);
        _assertBalanceInvariant(B);
        _assertTotalSupplyInvariant();
    }
}

