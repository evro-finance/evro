// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "src/Zappers/WBTCZapper.sol";
import "src/Zappers/Interfaces/IZapper.sol";
import "src/Interfaces/IAddressesRegistry.sol";
import "src/Interfaces/IBorrowerOperations.sol";
import "src/Interfaces/ITroveManager.sol";
import "src/Interfaces/ITroveNFT.sol";
import "src/Interfaces/IBoldToken.sol";
import "src/Interfaces/IWBTCWrapper.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ZapperWBTCGnosisTest is Test {
    // Deployed addresses on Gnosis from gnosis-test-deployment-low-debt-limit-new.json
    address constant WBTC_ZAPPER = 0x40f189c16cA6AA9A0bdf3C9FDf895C1a0D7115CC;
    address constant ADDRESSES_REGISTRY = 0xc6e530990ADb1bdec61c0a5Fbd1Ad226906C88DE;
    
    // Use deployment value (1 ether) instead of code constant (0.00375 ether)
    uint256 constant DEPLOYED_ETH_GAS_COMPENSATION = 1 ether;

    WBTCZapper wbtcZapper;
    IAddressesRegistry addressesRegistry;
    IBorrowerOperations borrowerOperations;
    ITroveManager troveManager;
    ITroveNFT troveNFT;
    IBoldToken boldToken;
    IWBTCWrapper wbtcWrapper;
    IERC20 wbtc; // Underlying WBTC (8 decimals)

    address A;
    address B;

    // Helper to get trove collateral
    function _getTroveColl(uint256 _troveId) internal view returns (uint256) {
        (, uint256 coll,,,,,,,,) = troveManager.Troves(_troveId);
        return coll;
    }

    // Helper to get trove debt
    function _getTroveDebt(uint256 _troveId) internal view returns (uint256) {
        (uint256 debt,,,,,,,,,) = troveManager.Troves(_troveId);
        return debt;
    }

    function setUp() public {
        // Fork Gnosis
        try vm.envString("GNOSIS_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl);
        } catch {
            vm.createSelectFork("https://rpc.gnosis.gateway.fm");
        }

        // Load the zapper and get addresses from it
        wbtcZapper = WBTCZapper(payable(WBTC_ZAPPER));
        borrowerOperations = wbtcZapper.borrowerOperations();
        troveManager = wbtcZapper.troveManager();
        troveNFT = troveManager.troveNFT();
        boldToken = wbtcZapper.boldToken();
        wbtcWrapper = wbtcZapper.wBTCWrapper();
        wbtc = wbtcZapper.wBTC();

        // Also load registry for reference
        addressesRegistry = IAddressesRegistry(ADDRESSES_REGISTRY);

        // Setup test accounts
        A = makeAddr("A");
        B = makeAddr("B");

        // Fund test accounts with ETH for gas compensation
        deal(A, 10 ether);
        deal(B, 10 ether);

        // Fund test accounts with WBTC (8 decimals)
        // 1 WBTC = 1e8 units, give them 10 WBTC each
        deal(address(wbtc), A, 10e8);
        deal(address(wbtc), B, 10e8);
    }

    function testCanOpenTrove() external {
        // WBTC uses 8 decimals, but collAmount is in 18 decimals (wrapped)
        uint256 collAmount = 1e18; // 1 wWBTC (18 decimals) = 0.00000001 WBTC (8 decimals)
        // Actually: 1e18 wrapped / 1e10 = 1e8 WBTC = 1 WBTC
        uint256 boldAmount = 2000e18;

        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: collAmount, // 18 decimals (wrapped)
            boldAmount: boldAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16, // 5%
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: address(0),
            removeManager: address(0),
            receiver: address(0)
        });

        vm.startPrank(A);
        // Approve WBTC to zapper
        wbtc.approve(address(wbtcZapper), type(uint256).max);
        
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: DEPLOYED_ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        // Verify trove was created
        assertGt(troveId, 0, "Trove ID should be non-zero");
        assertEq(troveNFT.ownerOf(troveId), A, "A should own the trove");
        
        // Verify BOLD was received
        assertEq(boldToken.balanceOf(A), boldAmount, "A should have received BOLD");
        
        // Verify WBTC was spent (8 decimals)
        uint256 wbtcSpent = collAmount / 1e10; // Convert 18 decimals to 8 decimals
        assertEq(wbtc.balanceOf(A), wbtcBalanceBefore - wbtcSpent, "WBTC balance mismatch");
    }

    function testCanAddCollateral() external {
        // First open a trove
        uint256 initialColl = 1e18; // 1 wWBTC
        uint256 boldAmount = 2000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: initialColl,
            boldAmount: boldAmount,
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
        wbtc.approve(address(wbtcZapper), type(uint256).max);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: DEPLOYED_ETH_GAS_COMPENSATION}(params);

        // Add more collateral
        uint256 addAmount = 5e17; // 0.5 wWBTC (18 decimals)
        uint256 collBefore = _getTroveColl(troveId);
        
        wbtcZapper.addCollWithWBTC(troveId, addAmount);
        vm.stopPrank();

        uint256 collAfter = _getTroveColl(troveId);
        assertEq(collAfter, collBefore + addAmount, "Collateral should increase");
    }

    function testCanWithdrawCollateral() external {
        // First open a trove with extra collateral
        uint256 initialColl = 2e18; // 2 wWBTC
        uint256 boldAmount = 2000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: initialColl,
            boldAmount: boldAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: A,
            removeManager: A,
            receiver: A
        });

        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), type(uint256).max);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: DEPLOYED_ETH_GAS_COMPENSATION}(params);

        // Set zapper as receiver for withdrawals
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wbtcZapper), address(wbtcZapper));

        // Withdraw some collateral
        uint256 withdrawAmount = 5e17; // 0.5 wWBTC (18 decimals)
        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);
        
        wbtcZapper.withdrawCollToWBTC(troveId, withdrawAmount);
        vm.stopPrank();

        // Should receive WBTC (8 decimals)
        uint256 expectedWbtc = withdrawAmount / 1e10;
        assertEq(wbtc.balanceOf(A), wbtcBalanceBefore + expectedWbtc, "Should receive WBTC");
    }

    function testCanCloseTrove() external {
        // First open a trove with B so A isn't the only trove
        uint256 initialColl = 1e18;
        uint256 boldAmount = 2000e18;

        IZapper.OpenTroveParams memory paramsB = IZapper.OpenTroveParams({
            owner: B,
            ownerIndex: 0,
            collAmount: initialColl,
            boldAmount: boldAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: B,
            removeManager: B,
            receiver: B
        });

        vm.startPrank(B);
        wbtc.approve(address(wbtcZapper), type(uint256).max);
        wbtcZapper.openTroveWithWBTC{value: DEPLOYED_ETH_GAS_COMPENSATION}(paramsB);
        vm.stopPrank();

        // Now open A's trove
        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: initialColl,
            boldAmount: boldAmount,
            upperHint: 0,
            lowerHint: 0,
            annualInterestRate: 5e16,
            batchManager: address(0),
            maxUpfrontFee: 1000e18,
            addManager: A,
            removeManager: A,
            receiver: A
        });

        vm.startPrank(A);
        wbtc.approve(address(wbtcZapper), type(uint256).max);
        uint256 troveId = wbtcZapper.openTroveWithWBTC{value: DEPLOYED_ETH_GAS_COMPENSATION}(params);

        // Set zapper as receiver
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wbtcZapper), address(wbtcZapper));

        // Get debt to repay (includes upfront fee)
        uint256 debtToRepay = _getTroveDebt(troveId);
        
        // Deal extra BOLD to cover the upfront fee
        uint256 boldBalance = boldToken.balanceOf(A);
        if (debtToRepay > boldBalance) {
            deal(address(boldToken), A, debtToRepay);
        }
        
        // Approve BOLD for repayment
        boldToken.approve(address(wbtcZapper), debtToRepay);

        uint256 wbtcBalanceBefore = wbtc.balanceOf(A);
        
        // Close trove
        wbtcZapper.closeTroveToWBTC(troveId);
        vm.stopPrank();

        // Verify trove is closed
        assertEq(_getTroveColl(troveId), 0, "Trove should have no collateral");
        
        // Should have received WBTC back
        assertGt(wbtc.balanceOf(A), wbtcBalanceBefore, "Should receive WBTC back");
    }

    function testContractAddresses() external view {
        // Verify all addresses are set
        assertTrue(address(borrowerOperations) != address(0), "BorrowerOps should be set");
        assertTrue(address(troveManager) != address(0), "TroveManager should be set");
        assertTrue(address(troveNFT) != address(0), "TroveNFT should be set");
        assertTrue(address(boldToken) != address(0), "BoldToken should be set");
        assertTrue(address(wbtcWrapper) != address(0), "WBTCWrapper should be set");
        assertTrue(address(wbtc) != address(0), "WBTC should be set");
        
        // Log the addresses for debugging
        console.log("Registry:", address(addressesRegistry));
        console.log("BorrowerOperations:", address(borrowerOperations));
        console.log("TroveManager:", address(troveManager));
        console.log("TroveNFT:", address(troveNFT));
        console.log("BoldToken:", address(boldToken));
        console.log("WBTCWrapper:", address(wbtcWrapper));
        console.log("WBTC:", address(wbtc));
        console.log("WBTCZapper:", address(wbtcZapper));
    }
}

