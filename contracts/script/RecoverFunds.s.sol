// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IStabilityPool} from "src/Interfaces/IStabilityPool.sol";
import {ITroveManager} from "src/Interfaces/ITroveManager.sol";
import {IBorrowerOperations} from "src/Interfaces/IBorrowerOperations.sol";
import {ITroveNFT} from "src/Interfaces/ITroveNFT.sol";
import {IPriceFeed} from "src/Interfaces/IPriceFeed.sol";
import {IEvroToken} from "src/Interfaces/IEvroToken.sol";
import {LatestTroveData} from "src/Types/LatestTroveData.sol";

import {
    CCR_WETH, CCR_SETH, CCR_GNO, CCR_SDAI, CCR_WBTC, CCR_OSGNO,
    SCR_WETH, SCR_SETH, SCR_GNO, SCR_SDAI, SCR_WBTC, SCR_OSGNO,
    MIN_DEBT, DECIMAL_PRECISION
} from "src/Dependencies/Constants.sol";

struct BranchInfo {
    string collSymbol;
    address stabilityPool;
    address troveManager;
    address borrowerOperations;
    address troveNFT;
    address priceFeed;
    uint256 ccr;
    uint256 scr;
}

// //# Dry run (simulation)
// source .env && forge script script/RecoverFunds.s.sol:RecoverFundsScript --rpc-url $GNOSIS_RPC_URL --account deployerKey

// # Actual execution
// source .env && forge script script/RecoverFunds.s.sol:RecoverFundsScript --rpc-url $GNOSIS_RPC_URL --account deployerKey --broadcast

contract RecoverFundsScript is Script {
    uint256 constant WXDAI_TROVE_ID = 100720499990859913759626226721235127574922345158207643347086497804012622629549;
    uint256 constant GNO_TROVE_ID = 68935444862134280974422941262044780337742151103896206120753910235561102633376;
    uint256 constant SDAI_TROVE_ID = 12143259174366024529922558994427140534397299657491541086796734917898831179944;
    address constant DEPLOYER_ADDRESS = 0x09D5Bd4a4f1dA1A965fE24EA54bce3d37661E056;

    // Deployment file path
    string constant DEPLOYMENT_FILE = "gnosis-deployment-v1.json";
    string constant OUTPUT_FILE = "contracts/recovery-results.json";
    
    // Branch indices with open troves (WXDAI, GNO, sDAI)
    uint256[] troveBranchIndices = [0, 1, 2]; // WXDAI, GNO, sDAI
    
    // All branch indices for SP withdrawals
    uint256[] allBranchIndices = [0, 1, 2, 3, 4, 5]; // All 6 branches
    
    address evroToken;
    
    // Track results
    string[] public spWithdrawals;
    string[] public troveWithdrawals;
    uint256 public totalEvroRecovered;
    uint256 public spWithdrawalCount;
    uint256 public troveWithdrawalCount;
    bool public isBroadcasting;
    
    function run() external {
        address deployer = DEPLOYER_ADDRESS;
        
        console2.log("=== Recovery Script Started ===");
        console2.log("Deployer address:", deployer);
        
        
        // Load deployment data
        string memory deploymentJson = vm.readFile(DEPLOYMENT_FILE);
        evroToken = vm.parseJsonAddress(deploymentJson, ".evroToken");
        
        console2.log("EVRO Token:", evroToken);
        console2.log("");
        
        // Check if we're on Gnosis mainnet (chain ID 100)
        uint256 chainId = block.chainid;
        console2.log("Chain ID:", chainId);
        isBroadcasting = (chainId == 100);
        
        if (isBroadcasting) {
            console2.log("Detected Gnosis mainnet - will save results on completion");
        } else {
            console2.log("Not on Gnosis mainnet - running in simulation mode");
        }
        console2.log("");
        
        vm.startBroadcast();
        
        // Phase 1: Withdraw from all Stability Pools
        console2.log("=== PHASE 1: Withdrawing from Stability Pools ===");
        withdrawAllStabilityPools(deploymentJson, deployer);
        
        // Phase 2: Query trove states and calculate safe withdrawals
        console2.log("");
        console2.log("=== PHASE 2: Analyzing Trove Positions ===");
        analyzeTroves(deploymentJson, deployer);
        
        // Phase 3: Execute safe withdrawals
        console2.log("");
        console2.log("=== PHASE 3: Executing Safe Withdrawals ===");
        executeSafeWithdrawals(deploymentJson, deployer);
        
        vm.stopBroadcast();
        
        // Only write results JSON if we actually broadcasted transactions
        if (isBroadcasting && (spWithdrawalCount > 0 || troveWithdrawalCount > 0)) {
            writeResultsToJson();
            console2.log("");
            console2.log("=== Recovery Script Completed ===");
            console2.log("Total EVRO recovered from SPs:", totalEvroRecovered / 1e18);
            console2.log("SP withdrawals:", spWithdrawalCount);
            console2.log("Trove withdrawals:", troveWithdrawalCount);
            console2.log("");
            console2.log("Results saved to:", OUTPUT_FILE);
            console2.log("");
            console2.log("Transaction hashes can be found in:");
            console2.log("  contracts/broadcast/RecoverFunds.s.sol/100/run-latest.json");
        } else {
            console2.log("");
            console2.log("=== Simulation Completed ===");
            console2.log("SP withdrawals to execute:", spWithdrawalCount);
            console2.log("Trove withdrawals to execute:", troveWithdrawalCount);
            console2.log("");
            console2.log("Run with --broadcast to execute transactions and save results.");
        }
    }
    
    function withdrawAllStabilityPools(string memory deploymentJson, address deployer) internal {
        console2.log("Checking all 6 branches for SP deposits...");
        for (uint256 i = 0; i < allBranchIndices.length; i++) {
            uint256 branchIdx = allBranchIndices[i];
            BranchInfo memory branch = getBranchInfo(deploymentJson, branchIdx);
            
            console2.log("");
            console2.log("Branch", branchIdx, ":", branch.collSymbol);
            console2.log("  SP Address:", branch.stabilityPool);
            
            IStabilityPool sp = IStabilityPool(branch.stabilityPool);
            uint256 deposit = sp.deposits(deployer);
            
            if (deposit > 0) {
                console2.log("  SP Deposit:", deposit / 1e18, "EVRO");
                
                // Leave MIN_EVRO_IN_SP (1 EVRO) in the pool to avoid minimum deposit requirement
                uint256 minToLeave = 1e18; // 1 EVRO
                uint256 withdrawAmount = deposit > minToLeave ? deposit - minToLeave : 0;
                
                if (withdrawAmount > 0) {
                    console2.log("  Withdrawing:", withdrawAmount / 1e18, "EVRO (leaving 1 EVRO minimum)");
                    console2.log("  TX: withdrawFromSP on", branch.collSymbol);
                    // Withdraw (doClaim = true to get any rewards)
                    sp.withdrawFromSP(withdrawAmount, true);
                    console2.log("  Withdrawn successfully");
                    console2.log("");
                    
                    // Track result
                    totalEvroRecovered += withdrawAmount;
                    string memory result = string.concat(
                        '{"branch":"', branch.collSymbol,
                        '","pool":"', vm.toString(branch.stabilityPool),
                        '","amount":"', vm.toString(withdrawAmount),
                        '"}'
                    );
                    spWithdrawals.push(result);
                    spWithdrawalCount++;
                } else {
                    console2.log("  Cannot withdraw - would violate minimum deposit");
                    console2.log("");
                }
            } else {
                console2.log("  No SP deposit");
                console2.log("");
            }
        }
    }
    
    function analyzeTroves(string memory deploymentJson, address deployer) internal {
        for (uint256 i = 0; i < troveBranchIndices.length; i++) {
            uint256 branchIdx = troveBranchIndices[i];
            BranchInfo memory branch = getBranchInfo(deploymentJson, branchIdx);
            
            ITroveManager tm = ITroveManager(branch.troveManager);
            ITroveNFT nft = ITroveNFT(branch.troveNFT);
            IPriceFeed priceFeed = IPriceFeed(branch.priceFeed);
            
            // Get trove ID for this branch
            uint256 troveId = getKnownTroveId(branchIdx);
            
            if (troveId == 0) {
                console2.log("Branch:", branch.collSymbol, "- No trove found");
                continue;
            }
            
            // Get trove data
            LatestTroveData memory trove = tm.getLatestTroveData(troveId);
            (uint256 price,) = priceFeed.fetchPrice();
            
            // Calculate current CR
            uint256 currentCR = (trove.entireColl * price * DECIMAL_PRECISION) / (trove.entireDebt * DECIMAL_PRECISION);
            
            console2.log("Branch:", branch.collSymbol);
            console2.log("  Trove ID:", troveId);
            console2.log("  Collateral:", trove.entireColl / 1e18);
            console2.log("  Debt:", trove.entireDebt / 1e18, "EVRO");
            console2.log("  Price:", price / 1e18);
            console2.log("  Current CR:", (currentCR * 100) / DECIMAL_PRECISION, "%");
            console2.log("  CCR:", (branch.ccr * 100) / DECIMAL_PRECISION, "%");
            console2.log("  SCR:", (branch.scr * 100) / DECIMAL_PRECISION, "%");
            
            // Calculate safe withdrawal amount
            // Target CR = CCR + 0.01% buffer (minimal safety margin)
            // This is 1e14 (0.01% of 1e18)
            uint256 minBuffer = DECIMAL_PRECISION / 10000; // 0.01%
            uint256 targetCR = branch.ccr + minBuffer;
            
            // Required collateral at target CR = (debt * targetCR) / price
            uint256 requiredColl = (trove.entireDebt * targetCR) / price;
            
            console2.log("  Target CR:", (targetCR * 100) / DECIMAL_PRECISION, "%");
            console2.log("  Target CR (raw):", targetCR);
            console2.log("  Required Coll (raw):", requiredColl);
            console2.log("  Required Coll:", requiredColl / 1e18);
            console2.log("  Current Coll (raw):", trove.entireColl);
            
            if (trove.entireColl > requiredColl) {
                uint256 withdrawable = trove.entireColl - requiredColl;
                console2.log("  Withdrawable (raw):", withdrawable);
                // Display with more precision (2 decimals)
                uint256 withdrawableDisplay = (withdrawable * 100) / 1e18;
                console2.log("  Withdrawable:", withdrawableDisplay / 100, ".", withdrawableDisplay % 100);
            } else {
                console2.log("  Withdrawable: 0 (already at or below target CR)");
                console2.log("  Shortfall:", requiredColl - trove.entireColl);
            }
        }
    }
    
    function executeSafeWithdrawals(string memory deploymentJson, address deployer) internal {
        for (uint256 i = 0; i < troveBranchIndices.length; i++) {
            uint256 branchIdx = troveBranchIndices[i];
            BranchInfo memory branch = getBranchInfo(deploymentJson, branchIdx);
            
            ITroveManager tm = ITroveManager(branch.troveManager);
            IBorrowerOperations bo = IBorrowerOperations(branch.borrowerOperations);
            ITroveNFT nft = ITroveNFT(branch.troveNFT);
            IPriceFeed priceFeed = IPriceFeed(branch.priceFeed);
            
            // Get trove ID for this branch
            uint256 troveId = getKnownTroveId(branchIdx);
            
            if (troveId == 0) {
                console2.log("Branch:", branch.collSymbol, "- No trove to withdraw from");
                continue;
            }
            
            // Get trove data
            LatestTroveData memory trove = tm.getLatestTroveData(troveId);
            (uint256 price,) = priceFeed.fetchPrice();
            
            // Calculate safe withdrawal amount
            // Target CR = CCR + 0.01% buffer (minimal safety margin)
            uint256 minBuffer = DECIMAL_PRECISION / 10000; // 0.01%
            uint256 targetCR = branch.ccr + minBuffer;
            
            // Required collateral at target CR = (debt * targetCR) / price
            uint256 requiredColl = (trove.entireDebt * targetCR) / price;
            
            if (trove.entireColl > requiredColl) {
                uint256 withdrawAmount = trove.entireColl - requiredColl;
                
                console2.log("Branch:", branch.collSymbol);
                uint256 withdrawDisplay = (withdrawAmount * 100) / 1e18;
                console2.log("  Withdrawing:", withdrawDisplay / 100, ".", withdrawDisplay % 100);
                console2.log("  TX: withdrawColl on", branch.collSymbol, "trove", troveId);
                
                bo.withdrawColl(troveId, withdrawAmount);
                console2.log("  Withdrawal successful");
                console2.log("");
                
                // Track result
                string memory result = string.concat(
                    '{"branch":"', branch.collSymbol,
                    '","troveId":"', vm.toString(troveId),
                    '","amount":"', vm.toString(withdrawAmount),
                    '","remainingColl":"', vm.toString(requiredColl),
                    '","targetCR":"', vm.toString((targetCR * 100) / DECIMAL_PRECISION),
                    '"}'
                );
                troveWithdrawals.push(result);
                troveWithdrawalCount++;
            } else {
                console2.log("Branch:", branch.collSymbol, "- No withdrawal needed");
                console2.log("");
            }
        }
    }
    
    function getBranchInfo(string memory deploymentJson, uint256 branchIdx) internal pure returns (BranchInfo memory) {
        string memory branchPath = string.concat(".branches[", vm.toString(branchIdx), "]");
        
        BranchInfo memory branch;
        branch.collSymbol = vm.parseJsonString(deploymentJson, string.concat(branchPath, ".collSymbol"));
        branch.stabilityPool = vm.parseJsonAddress(deploymentJson, string.concat(branchPath, ".stabilityPool"));
        branch.troveManager = vm.parseJsonAddress(deploymentJson, string.concat(branchPath, ".troveManager"));
        branch.borrowerOperations = vm.parseJsonAddress(deploymentJson, string.concat(branchPath, ".borrowerOperations"));
        branch.troveNFT = vm.parseJsonAddress(deploymentJson, string.concat(branchPath, ".troveNFT"));
        branch.priceFeed = vm.parseJsonAddress(deploymentJson, string.concat(branchPath, ".priceFeed"));
        
        // Set CCR and SCR based on collateral type
        if (keccak256(bytes(branch.collSymbol)) == keccak256(bytes("WXDAI"))) {
            branch.ccr = CCR_WETH;
            branch.scr = SCR_WETH;
        } else if (keccak256(bytes(branch.collSymbol)) == keccak256(bytes("GNO"))) {
            branch.ccr = CCR_GNO;
            branch.scr = SCR_GNO;
        } else if (keccak256(bytes(branch.collSymbol)) == keccak256(bytes("sDAI"))) {
            branch.ccr = CCR_SDAI;
            branch.scr = SCR_SDAI;
        } else if (keccak256(bytes(branch.collSymbol)) == keccak256(bytes("wWBTC"))) {
            branch.ccr = CCR_WBTC;
            branch.scr = SCR_WBTC;
        } else if (keccak256(bytes(branch.collSymbol)) == keccak256(bytes("osGNO"))) {
            branch.ccr = CCR_OSGNO;
            branch.scr = SCR_OSGNO;
        } else if (keccak256(bytes(branch.collSymbol)) == keccak256(bytes("wstETH"))) {
            branch.ccr = CCR_SETH;
            branch.scr = SCR_SETH;
        }
        
        return branch;
    }
    
    function getKnownTroveId(uint256 branchIdx) internal pure returns (uint256) {
        if (branchIdx == 0) return WXDAI_TROVE_ID; // WXDAI
        if (branchIdx == 1) return GNO_TROVE_ID;   // GNO
        if (branchIdx == 2) return SDAI_TROVE_ID;  // sDAI
        return 0;
    }
    
    function findTroveId(ITroveNFT nft, address owner) internal view returns (uint256) {
        console2.log("  Searching for trove owned by:", owner);
        // Iterate through possible trove IDs to find one owned by deployer
        // Start from 1 as 0 is invalid
        for (uint256 i = 1; i <= 100; i++) { // Reduced to 100 for faster execution
            try nft.ownerOf(i) returns (address troveOwner) {
                if (troveOwner == owner) {
                    console2.log("  Found trove ID:", i);
                    return i;
                }
            } catch {
                // Token doesn't exist, continue
                // Stop early if we hit too many non-existent tokens in a row
                if (i > 10) {
                    console2.log("  No trove found after checking", i, "IDs");
                    return 0;
                }
            }
        }
        console2.log("  No trove found after checking 100 IDs");
        return 0; // Not found
    }
    
    function writeResultsToJson() internal {
        // Build JSON structure
        string memory json = "recovery";
        
        vm.serializeAddress(json, "deployer", DEPLOYER_ADDRESS);
        vm.serializeUint(json, "timestamp", block.timestamp);
        vm.serializeUint(json, "totalEvroRecovered", totalEvroRecovered);
        vm.serializeUint(json, "spWithdrawalCount", spWithdrawalCount);
        vm.serializeUint(json, "troveWithdrawalCount", troveWithdrawalCount);
        
        // Serialize arrays
        string memory spArray = "[";
        for (uint256 i = 0; i < spWithdrawals.length; i++) {
            spArray = string.concat(spArray, spWithdrawals[i]);
            if (i < spWithdrawals.length - 1) {
                spArray = string.concat(spArray, ",");
            }
        }
        spArray = string.concat(spArray, "]");
        
        string memory troveArray = "[";
        for (uint256 i = 0; i < troveWithdrawals.length; i++) {
            troveArray = string.concat(troveArray, troveWithdrawals[i]);
            if (i < troveWithdrawals.length - 1) {
                troveArray = string.concat(troveArray, ",");
            }
        }
        troveArray = string.concat(troveArray, "]");
        
        // Build final JSON
        string memory output = string.concat(
            '{"deployer":"', vm.toString(DEPLOYER_ADDRESS),
            '","timestamp":"', vm.toString(block.timestamp),
            '","totalEvroRecovered":"', vm.toString(totalEvroRecovered),
            '","spWithdrawalCount":', vm.toString(spWithdrawalCount),
            ',"troveWithdrawalCount":', vm.toString(troveWithdrawalCount),
            ',"spWithdrawals":', spArray,
            ',"troveWithdrawals":', troveArray,
            '}'
        );
        
        vm.writeFile(OUTPUT_FILE, output);
    }
}
