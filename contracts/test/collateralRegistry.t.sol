// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";
import "src/MultiTroveGetter.sol";

// Minimal TroveManager mock for testing createNewBranch revert conditions
contract MockTroveManager {
    address public stabilityPool;
    address public borrowerOperations;
    address public activePool;

    constructor(address _sp, address _bo, address _ap) {
        stabilityPool = _sp;
        borrowerOperations = _bo;
        activePool = _ap;
    }
}

// Minimal ERC20 mock for testing token validation revert conditions
contract MockCollToken {
    uint8 public decimals;
    string public symbol;
    string public name;

    constructor(uint8 _decimals, string memory _symbol, string memory _name) {
        decimals = _decimals;
        symbol = _symbol;
        name = _name;
    }
}

// Must match CollateralRegistry.NewBranchAdded exactly for vm.expectEmit topic[0]
event NewBranchAdded(IERC20Metadata _token, ITroveManager _troveManager);

contract CollateralRegistryTest is DevTestSetup {
    ICollateralRegistry internal registry;
    TestDeployer internal testDeployer;
    MultiTroveGetter internal multiTroveGetter;
    TestDeployer.TroveManagerParams internal defaultParams;

    function setUp() public override {
        super.setUp();

        registry = collateralRegistry;
        testDeployer = new TestDeployer();
        multiTroveGetter = new MultiTroveGetter(collateralRegistry);
        defaultParams = TestDeployer.TroveManagerParams(150e16, 110e16, 10e16, 110e16, 5e16, 10e16);
    }

    // Deploy a full branch and register it. Returns the branch contracts and collateral token.
    function _deployAndRegisterBranch()
        internal
        returns (TestDeployer.LiquityContractsDev memory branch, IERC20Metadata token)
    {
        (branch, token) = testDeployer.deployNewBranch(
            collateralRegistry, evroToken, WETH, hintHelpers, IMultiTroveGetter(address(multiTroveGetter)), defaultParams
        );
        // address(this) is the collateralGovernor set during deployAndConnectContracts
        registry.createNewBranch(token, ITroveManager(address(branch.troveManager)));
    }

    // Give account the WETH needed for gas compensation and approve it to borrowerOperations
    function _approveWETHGasComp(address _account, address _borrowerOperations) internal {
        deal(address(WETH), _account, 10 ether);
        vm.prank(_account);
        WETH.approve(_borrowerOperations, 10 ether);
    }

    // =========================================================================
    // Happy path
    // =========================================================================

    function test_createNewBranch_updatesTotalCollaterals() public {
        assertEq(registry.totalCollaterals(), 1);
        _deployAndRegisterBranch();
        assertEq(registry.totalCollaterals(), 2);
    }

    function test_createNewBranch_addsTokenAtNextIndex() public {
        (TestDeployer.LiquityContractsDev memory branch, IERC20Metadata token) = _deployAndRegisterBranch();
        assertEq(address(registry.getToken(1)), address(token));
    }

    function test_createNewBranch_addsTroveManagerAtNextIndex() public {
        (TestDeployer.LiquityContractsDev memory branch, IERC20Metadata token) = _deployAndRegisterBranch();
        assertEq(address(registry.getTroveManager(1)), address(branch.troveManager));
    }

    function test_createNewBranch_emitsEvent() public {
        (TestDeployer.LiquityContractsDev memory branch, IERC20Metadata token) =
            testDeployer.deployNewBranch(
                collateralRegistry, evroToken, WETH, hintHelpers,
                IMultiTroveGetter(address(multiTroveGetter)), defaultParams
            );

        vm.expectEmit(false, false, false, true);
        emit NewBranchAdded(token, ITroveManager(address(branch.troveManager)));
        registry.createNewBranch(token, ITroveManager(address(branch.troveManager)));
    }

    function test_createNewBranch_grantsMintingPermission() public {
        (TestDeployer.LiquityContractsDev memory branch,) = _deployAndRegisterBranch();

        // BorrowerOperations of the new branch can now mint EVRO
        vm.prank(address(branch.borrowerOperations));
        evroToken.mint(A, 1e18);
        assertEq(evroToken.balanceOf(A), 1e18);
    }

    function test_createNewBranch_canOpenTrove() public {
        (TestDeployer.LiquityContractsDev memory branch, IERC20Metadata token) = _deployAndRegisterBranch();

        branch.priceFeed.setPrice(2000e18);

        giveAndApproveCollateral(IERC20(address(token)), A, 10 ether, address(branch.borrowerOperations));
        _approveWETHGasComp(A, address(branch.borrowerOperations));

        vm.startPrank(A);
        uint256 troveId = branch.borrowerOperations.openTrove(
            A, 0, 10 ether, 5000e18, 0, 0, 5e16, type(uint256).max, address(0), address(0), address(0)
        );
        vm.stopPrank();

        assertEq(branch.troveNFT.ownerOf(troveId), A);
    }

    function test_createNewBranch_debtAppearsInEvroSupply() public {
        (TestDeployer.LiquityContractsDev memory branch, IERC20Metadata token) = _deployAndRegisterBranch();

        branch.priceFeed.setPrice(2000e18);
        giveAndApproveCollateral(IERC20(address(token)), A, 10 ether, address(branch.borrowerOperations));
        _approveWETHGasComp(A, address(branch.borrowerOperations));

        uint256 supplyBefore = evroToken.totalSupply();

        vm.startPrank(A);
        branch.borrowerOperations.openTrove(
            A, 0, 10 ether, 5000e18, 0, 0, 5e16, type(uint256).max, address(0), address(0), address(0)
        );
        vm.stopPrank();

        assertGt(evroToken.totalSupply(), supplyBefore);
    }

    // =========================================================================
    // Access control
    // =========================================================================

    function test_createNewBranch_revertsIfNotGovernor() public {
        IERC20Metadata token = IERC20Metadata(address(new MockCollToken(18, "TST", "Test")));
        ITroveManager tm = ITroveManager(address(new MockTroveManager(address(1), address(2), address(3))));

        vm.prank(A);
        vm.expectRevert("CR: Only collateral governor can create new branches");
        registry.createNewBranch(token, tm);
    }

    // =========================================================================
    // Cap enforcement
    // =========================================================================

    function test_createNewBranch_revertsIfMaxBranchesReached() public {
        // Fill up to 9 branches (1 already exists from setUp)
        for (uint256 i = 0; i < 9; i++) {
            IERC20Metadata token = IERC20Metadata(address(new MockCollToken(18, "TST", "Test")));
            ITroveManager tm = ITroveManager(address(new MockTroveManager(address(1), address(2), address(3))));
            registry.createNewBranch(token, tm);
        }

        IERC20Metadata extraToken = IERC20Metadata(address(new MockCollToken(18, "TST", "Test")));
        ITroveManager extraTM = ITroveManager(address(new MockTroveManager(address(1), address(2), address(3))));
        vm.expectRevert("CR: Max 10 redeemable branches");
        registry.createNewBranch(extraToken, extraTM);
    }

    // =========================================================================
    // Duplicate checks
    // =========================================================================

    function test_createNewBranch_revertsIfDuplicateToken() public {
        IERC20Metadata existingToken = registry.getToken(0);
        ITroveManager freshTM = ITroveManager(address(new MockTroveManager(address(1), address(2), address(3))));

        vm.expectRevert("CR: Token already exists");
        registry.createNewBranch(existingToken, freshTM);
    }

    function test_createNewBranch_revertsIfDuplicateTroveManager() public {
        IERC20Metadata freshToken = IERC20Metadata(address(new MockCollToken(18, "TST", "Test")));
        ITroveManager existingTM = registry.getTroveManager(0);

        vm.expectRevert("CR: Trove manager already exists");
        registry.createNewBranch(freshToken, existingTM);
    }

    // =========================================================================
    // TroveManager address validation
    // =========================================================================

    function test_createNewBranch_revertsIfStabilityPoolZero() public {
        IERC20Metadata token = IERC20Metadata(address(new MockCollToken(18, "TST", "Test")));
        ITroveManager tm = ITroveManager(address(new MockTroveManager(address(0), address(2), address(3))));

        vm.expectRevert("CR: Stability pool cannot be the zero address");
        registry.createNewBranch(token, tm);
    }

    function test_createNewBranch_revertsIfBorrowerOpsZero() public {
        IERC20Metadata token = IERC20Metadata(address(new MockCollToken(18, "TST", "Test")));
        ITroveManager tm = ITroveManager(address(new MockTroveManager(address(1), address(0), address(3))));

        vm.expectRevert("CR: Borrower operations cannot be the zero address");
        registry.createNewBranch(token, tm);
    }

    function test_createNewBranch_revertsIfActivePoolZero() public {
        IERC20Metadata token = IERC20Metadata(address(new MockCollToken(18, "TST", "Test")));
        ITroveManager tm = ITroveManager(address(new MockTroveManager(address(1), address(2), address(0))));

        vm.expectRevert("CR: Active pool cannot be the zero address");
        registry.createNewBranch(token, tm);
    }

    // =========================================================================
    // Token metadata validation
    // =========================================================================

    function test_createNewBranch_revertsIfTokenSymbolEmpty() public {
        IERC20Metadata token = IERC20Metadata(address(new MockCollToken(18, "", "Test")));
        ITroveManager tm = ITroveManager(address(new MockTroveManager(address(1), address(2), address(3))));

        vm.expectRevert("CR: Token symbol cannot be empty");
        registry.createNewBranch(token, tm);
    }

    function test_createNewBranch_revertsIfTokenNameEmpty() public {
        IERC20Metadata token = IERC20Metadata(address(new MockCollToken(18, "TST", "")));
        ITroveManager tm = ITroveManager(address(new MockTroveManager(address(1), address(2), address(3))));

        vm.expectRevert("CR: Token name cannot be empty");
        registry.createNewBranch(token, tm);
    }

    function test_createNewBranch_revertsIfTokenDecimalsZero() public {
        IERC20Metadata token = IERC20Metadata(address(new MockCollToken(0, "TST", "Test")));
        ITroveManager tm = ITroveManager(address(new MockTroveManager(address(1), address(2), address(3))));

        vm.expectRevert("CR: Token decimals cannot be zero");
        registry.createNewBranch(token, tm);
    }

    // =========================================================================
    // Redemption
    // =========================================================================

    function test_redeemCollateral_newBranchIsRedeemable() public {
        (TestDeployer.LiquityContractsDev memory branch, IERC20Metadata token) = _deployAndRegisterBranch();

        // Pass bootstrap period
        vm.warp(block.timestamp + 14 days);

        branch.priceFeed.setPrice(2000e18);

        uint256 collAmount = 20 ether;
        uint256 debtAmount = 10000e18;

        giveAndApproveCollateral(IERC20(address(token)), A, collAmount, address(branch.borrowerOperations));
        _approveWETHGasComp(A, address(branch.borrowerOperations));

        vm.startPrank(A);
        uint256 troveId = branch.borrowerOperations.openTrove(
            A, 0, collAmount, debtAmount, 0, 0, 5e16, type(uint256).max, address(0), address(0), address(0)
        );
        vm.stopPrank();

        // Transfer all EVRO to E who will redeem
        uint256 evroBalance = evroToken.balanceOf(A);
        vm.prank(A);
        evroToken.transfer(E, evroBalance);

        uint256 debtBefore = ITroveManagerTester(address(branch.troveManager)).getTroveEntireDebt(troveId);
        uint256 collBefore = ITroveManagerTester(address(branch.troveManager)).getTroveEntireColl(troveId);

        // E redeems half the debt
        uint256 redeemAmount = debtBefore / 2;
        vm.startPrank(E);
        collateralRegistry.redeemCollateral(redeemAmount, type(uint256).max, 1e18);
        vm.stopPrank();

        uint256 debtAfter = ITroveManagerTester(address(branch.troveManager)).getTroveEntireDebt(troveId);
        uint256 collAfter = ITroveManagerTester(address(branch.troveManager)).getTroveEntireColl(troveId);

        assertLt(debtAfter, debtBefore, "debt should decrease after redemption");
        assertLt(collAfter, collBefore, "collateral should decrease after redemption");
    }

    function test_redeemCollateral_newBranchCollReceivedByRedeemer() public {
        (TestDeployer.LiquityContractsDev memory branch, IERC20Metadata token) = _deployAndRegisterBranch();

        vm.warp(block.timestamp + 14 days);

        branch.priceFeed.setPrice(2000e18);

        giveAndApproveCollateral(IERC20(address(token)), A, 20 ether, address(branch.borrowerOperations));
        _approveWETHGasComp(A, address(branch.borrowerOperations));

        vm.startPrank(A);
        branch.borrowerOperations.openTrove(
            A, 0, 20 ether, 10000e18, 0, 0, 5e16, type(uint256).max, address(0), address(0), address(0)
        );
        vm.stopPrank();

        uint256 evroBalance = evroToken.balanceOf(A);
        vm.prank(A);
        evroToken.transfer(E, evroBalance);

        uint256 collBalanceBefore = token.balanceOf(E);

        vm.startPrank(E);
        collateralRegistry.redeemCollateral(5000e18, type(uint256).max, 1e18);
        vm.stopPrank();

        assertGt(token.balanceOf(E), collBalanceBefore, "redeemer should receive new branch collateral");
        assertLt(evroToken.balanceOf(E), evroBalance, "redeemer should receive less EVRO after redemption");
    }

    // =========================================================================
    // updateCollateralGovernor
    // =========================================================================

    function test_updateCollateralGovernor_updatesGovernor() public {
        registry.updateCollateralGovernor(A);
        assertEq(registry.collateralGovernor(), A);
    }

    function test_updateCollateralGovernor_revertsIfNotOwner() public {
        vm.prank(A);
        vm.expectRevert();
        registry.updateCollateralGovernor(B);
    }
}
