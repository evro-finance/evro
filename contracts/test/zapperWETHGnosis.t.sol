// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "src/Zappers/WETHZapper.sol";
import "src/Zappers/Interfaces/IZapper.sol";
import "src/Interfaces/IAddressesRegistry.sol";
import "src/Interfaces/IBorrowerOperations.sol";
import "src/Interfaces/ITroveManager.sol";
import "src/Interfaces/ITroveNFT.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "src/Interfaces/IWETH.sol";
import "src/Dependencies/Constants.sol";

contract ZapperWETHGnosisTest is Test {
    // Deployed addresses on Gnosis - update these from deployment manifest
    address constant ADDRESSES_REGISTRY = 0x1533D536399ee60Ac2F417bFafD7CEC74Fcd09f9;
    address constant WETH_ZAPPER = 0xD91aBe4177bd6B2956e25D19A3E35e57d5c5993A;

    IAddressesRegistry addressesRegistry;
    WETHZapper wethZapper;
    IBorrowerOperations borrowerOperations;
    ITroveManager troveManager;
    ITroveNFT troveNFT;
    IERC20 boldToken;
    IWETH weth;

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

    address A;
    address B;

    function setUp() public {
        // Fork Gnosis
        try vm.envString("GNOSIS_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl);
        } catch {
            // Fallback to public RPC
            vm.createSelectFork("https://rpc.gnosis.gateway.fm");
        }

        // Load the zapper and get addresses from it (the zapper was deployed with its own set of contracts)
        wethZapper = WETHZapper(payable(WETH_ZAPPER));
        borrowerOperations = wethZapper.borrowerOperations();
        troveManager = wethZapper.troveManager();
        troveNFT = troveManager.troveNFT();
        // Deployed contract has boldToken(), local code has evroToken() - use low-level call
        (bool success, bytes memory data) = WETH_ZAPPER.staticcall(abi.encodeWithSignature("boldToken()"));
        require(success, "Failed to get boldToken");
        boldToken = IERC20(abi.decode(data, (address)));
        weth = IWETH(wethZapper.WETH());
        
        // Also load the registry for reference
        addressesRegistry = IAddressesRegistry(ADDRESSES_REGISTRY);

        // Setup test accounts
        A = makeAddr("A");
        B = makeAddr("B");

        // Fund test accounts with xDAI
        deal(A, 10000 ether);
        deal(B, 10000 ether);
    }

    function testCanOpenTrove() external {
        uint256 collAmount = 4000 ether; // Need 150% CCR at 0.85 EUR/xDAI
        uint256 boldAmount = 2000e18;

        uint256 balanceBefore = A.balance;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: 0, // not needed for WETHZapper
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
        uint256 troveId = wethZapper.openTroveWithRawETH{value: collAmount + ETH_GAS_COMPENSATION}(params);
        vm.stopPrank();

        // Verify trove was created
        assertGt(troveId, 0, "Trove ID should be non-zero");
        assertEq(troveNFT.ownerOf(troveId), A, "A should own the trove");
        
        // Verify BOLD was received
        assertEq(boldToken.balanceOf(A), boldAmount, "A should have received BOLD");
        
        // Verify ETH was spent
        assertEq(A.balance, balanceBefore - collAmount - ETH_GAS_COMPENSATION, "ETH balance mismatch");
    }

    function testCanAddCollateral() external {
        // First open a trove
        uint256 initialColl = 4000 ether;
        uint256 boldAmount = 2000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: 0,
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
        uint256 troveId = wethZapper.openTroveWithRawETH{value: initialColl + ETH_GAS_COMPENSATION}(params);

        // Add more collateral
        uint256 addAmount = 5 ether;
        uint256 collBefore = _getTroveColl(troveId);
        
        wethZapper.addCollWithRawETH{value: addAmount}(troveId);
        vm.stopPrank();

        uint256 collAfter = _getTroveColl(troveId);
        assertEq(collAfter, collBefore + addAmount, "Collateral should increase");
    }

    function testCanWithdrawCollateral() external {
        // First open a trove with extra collateral
        uint256 initialColl = 5000 ether;
        uint256 boldAmount = 2000e18;

        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: 0,
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
        uint256 troveId = wethZapper.openTroveWithRawETH{value: initialColl + ETH_GAS_COMPENSATION}(params);

        // Set zapper as receiver for withdrawals
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wethZapper), address(wethZapper));

        // Withdraw some collateral
        uint256 withdrawAmount = 5 ether;
        uint256 ethBalanceBefore = A.balance;
        
        wethZapper.withdrawCollToRawETH(troveId, withdrawAmount);
        vm.stopPrank();

        assertEq(A.balance, ethBalanceBefore + withdrawAmount, "Should receive ETH");
    }

    function testCanCloseTrove() external {
        // First open a trove with B so A isn't the only trove
        uint256 initialColl = 4000 ether;
        uint256 boldAmount = 2000e18;

        IZapper.OpenTroveParams memory paramsB = IZapper.OpenTroveParams({
            owner: B,
            ownerIndex: 0,
            collAmount: 0,
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

        vm.prank(B);
        wethZapper.openTroveWithRawETH{value: initialColl + ETH_GAS_COMPENSATION}(paramsB);

        // Now open A's trove
        IZapper.OpenTroveParams memory params = IZapper.OpenTroveParams({
            owner: A,
            ownerIndex: 0,
            collAmount: 0,
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
        uint256 troveId = wethZapper.openTroveWithRawETH{value: initialColl + ETH_GAS_COMPENSATION}(params);

        // Set zapper as receiver
        borrowerOperations.setRemoveManagerWithReceiver(troveId, address(wethZapper), address(wethZapper));

        // Get debt to repay (includes upfront fee)
        uint256 debtToRepay = _getTroveDebt(troveId);
        
        // Deal extra BOLD to cover the upfront fee
        uint256 boldBalance = boldToken.balanceOf(A);
        if (debtToRepay > boldBalance) {
            deal(address(boldToken), A, debtToRepay);
        }
        
        // Approve BOLD for repayment
        boldToken.approve(address(wethZapper), debtToRepay);

        uint256 ethBalanceBefore = A.balance;
        
        // Close trove
        wethZapper.closeTroveToRawETH(troveId);
        vm.stopPrank();

        // Verify trove is closed
        assertEq(_getTroveColl(troveId), 0, "Trove should have no collateral");
        
        // Should have received ETH back (minus gas comp used)
        assertGt(A.balance, ethBalanceBefore, "Should receive ETH back");
    }

    function testContractAddresses() external view {
        // Verify all registry addresses are set
        assertTrue(address(borrowerOperations) != address(0), "BorrowerOps should be set");
        assertTrue(address(troveManager) != address(0), "TroveManager should be set");
        assertTrue(address(troveNFT) != address(0), "TroveNFT should be set");
        assertTrue(address(boldToken) != address(0), "EvroToken should be set");
        assertTrue(address(weth) != address(0), "WETH should be set");
        
        // Log the addresses for debugging
        console.log("Registry:", address(addressesRegistry));
        console.log("BorrowerOperations:", address(borrowerOperations));
        console.log("TroveManager:", address(troveManager));
        console.log("TroveNFT:", address(troveNFT));
        console.log("EvroToken:", address(boldToken));
        console.log("WETH:", address(weth));
        console.log("WETHZapper:", address(wethZapper));
        console.log("Zapper's BorrowerOps:", address(wethZapper.borrowerOperations()));
    }
}
