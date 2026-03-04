import type { Address } from "@liquity2/uikit";
import { createPublicClient, hexToBigInt, http, toHex, isAddressEqual, zeroAddress } from "viem";
import { CONTRACTS } from "./contracts";
import { BranchId, CombinedTroveData, DebtPerInterestRate, PrefixedTroveId, ReturnCombinedTroveReadCallData, ReturnTroveReadCallData, Trove, TroveStatusEnum } from "./types";
import { CHAIN_RPC_URL, CHAIN_ID, CHAIN_NAME, CHAIN_CURRENCY } from "./env";
import { getCollToken, getPrefixedTroveId, parsePrefixedTroveId } from "./liquity-utils";

export function getPublicClient() {
  const chain = {
    id: CHAIN_ID,
    name: CHAIN_NAME,
    nativeCurrency: CHAIN_CURRENCY,
    rpcUrls: {
      default: { http: [CHAIN_RPC_URL] },
    },
  };
  return createPublicClient({
    chain: chain as any,
    transport: http(CHAIN_RPC_URL),
  });
}

// Check if contracts are deployed (not placeholder addresses)
function isContractDeployed(address: string | undefined): boolean {
  if (!address) return false;
  return !isAddressEqual(address as Address, zeroAddress);
}

export async function getAllTroves(): Promise<Record<BranchId, CombinedTroveData[]>> {
  const client = getPublicClient();
  const troves: Record<BranchId, CombinedTroveData[]> = {} as any;
  
  // Initialize for all branch IDs
  for (let i = 0; i <= 9; i++) {
    troves[i as BranchId] = [];
  }

  // Check if MultiTroveGetter is deployed
  if (!CONTRACTS.MultiTroveGetter || !isContractDeployed(CONTRACTS.MultiTroveGetter.address)) {
    console.warn("MultiTroveGetter not deployed, returning empty troves");
    return troves;
  }
  
  try {
    const validBranches = CONTRACTS.branches.filter((branch: any) => 
      branch.contracts.TroveManager && 
      isContractDeployed(branch.contracts.TroveManager.address)
    );

    if (validBranches.length === 0) {
      console.warn("No valid branches with deployed contracts found");
      return troves;
    }

    const output = await client.multicall({
      contracts: validBranches.map((branch: any) => ({
        ...CONTRACTS.MultiTroveGetter,
        functionName: "getMultipleSortedTroves",
        args: [branch.id, 0n, 1_000_000_000n],
      })),
    });

    validBranches.forEach((branch: any, index: number) => {
      const result = output[index];
      if (result?.status === "success") {
        troves[branch.id as BranchId] = result.result as unknown as CombinedTroveData[];
      }
    });
  } catch (error) {
    console.error("Error fetching all troves:", error);
  }

  return troves;
}

export async function getTroveById(id: PrefixedTroveId): Promise<ReturnTroveReadCallData | undefined> {
  const client = getPublicClient();
  const { branchId, troveId } = parsePrefixedTroveId(id);
  const tokenId = hexToBigInt(troveId);
  
  const branch = CONTRACTS.branches.find((b: any) => b.id === branchId);
  if (!branch) return undefined;
  
  if (!isContractDeployed(branch.contracts.TroveNFT?.address) || 
      !isContractDeployed(branch.contracts.TroveManager?.address)) {
    console.warn(`Branch ${branchId} contracts not deployed`);
    return undefined;
  }
  
  try {
    const output = await client.multicall({
      contracts: [
        {
          ...branch.contracts.TroveNFT,
          functionName: "ownerOf",
          args: [tokenId],
        },
        {
          ...branch.contracts.TroveManager,
          functionName: "Troves",
          args: [tokenId],
        }
      ]
    });

    const collateral = getCollToken(branchId);
    if (!collateral) return undefined;
    
    const trove = output[1]?.result ? {
      debt: output[1]?.result[0],
      coll: output[1]?.result[1],
      stake: output[1]?.result[2],
      status: output[1]?.result[3],
      arrayIndex: output[1]?.result[4],
      lastDebtUpdateTime: output[1]?.result[5],
      lastInterestRateAdjTime: output[1]?.result[6],
      annualInterestRate: output[1]?.result[7],
      interestBatchManager: output[1]?.result[8],
      batchDebtShares: output[1]?.result[9],
    } as Trove : undefined;
    
    const owner = output[0]?.result as Address;
    if (!owner || !trove) return undefined;

    return {
      ...trove,
      id,
      troveId,
      borrower: owner,
      deposit: trove.coll,
      interestRate: trove.annualInterestRate,
      collateral: {
        id: branchId.toString(),
        token: {
          symbol: collateral.symbol,
          name: collateral.name,
        },
        minCollRatio: collateral.collateralRatio,
        branchId,
      },
      interestBatch: {
        annualInterestRate: trove.annualInterestRate,
        batchManager: trove.interestBatchManager,
      }
    };
  } catch (error) {
    console.error(`Error fetching trove ${id}:`, error);
    return undefined;
  }
}

export async function getTrovesByAccount(account: Address): Promise<ReturnCombinedTroveReadCallData[]> {
  const client = getPublicClient();

  try {
    const allTroves = Object.entries(await getAllTroves()).flatMap(([branchId, troves]) => {
      const branch = CONTRACTS.branches.find((b: any) => b.id === Number(branchId) as BranchId);
      if (!branch) return [];
      return troves.map(trove => ({
        ...trove,
        branch,
      }));
    });

    if (allTroves.length === 0) {
      return [];
    }

    // Filter branches with deployed contracts
    const validTroves = allTroves.filter(trove => 
      isContractDeployed(trove.branch.contracts.TroveNFT?.address) &&
      isContractDeployed(trove.branch.contracts.TroveManager?.address)
    );

    if (validTroves.length === 0) {
      return [];
    }

    const troveOwners = await client.multicall({
      contracts: validTroves.flatMap(trove => [
        {
          ...trove.branch.contracts.TroveNFT,
          functionName: "ownerOf",
          args: [trove.id],
        },
        {
          ...trove.branch.contracts.TroveManager,
          functionName: "Troves",
          args: [trove.id],
        }
      ]),
    });

    const owners = troveOwners.filter((_, index) => index % 2 === 0).map(owner => owner.result as string | undefined);
    const troves = troveOwners.filter((_, index) => index % 2 === 1).map(trove => trove.result as unknown as Trove | undefined);

    return validTroves
      .filter((_, index) => owners[index]?.toLowerCase() === account.toLowerCase())
      .map((trove, index) => {
        const collateral = getCollToken(trove.branch.id);
        if (!collateral) return null as any;
        
        const troveId = toHex(trove.id, { size: 32 });
        return {
          ...trove,
          id: getPrefixedTroveId(trove.branch.id, troveId),
          troveId,
          borrower: owners[index] as Address,
          debt: trove.entireDebt,
          deposit: trove.entireColl,
          interestRate: trove.annualInterestRate,
          status: troves[index]?.status ?? TroveStatusEnum.nonExistent,
          collateral: {
            id: trove.branch.id.toString(),
            token: {
              symbol: collateral.symbol,
              name: collateral.name,
            },
            minCollRatio: collateral.collateralRatio,
            branchId: trove.branch.id,
          },
          interestBatch: {
            annualInterestRate: trove.annualInterestRate,
            batchManager: trove.interestBatchManager,
          }
        };
      })
      .filter((trove): trove is ReturnCombinedTroveReadCallData => trove !== null);
  } catch (error) {
    console.error("Error fetching troves by account:", error);
    return [];
  }
}

export async function getAllDebtPerInterestRate(): Promise<Record<BranchId, DebtPerInterestRate[]>> {
  const client = getPublicClient();
  const debtPerInterestRate: Record<BranchId, DebtPerInterestRate[]> = {} as any;
  
  // Initialize for all branch IDs
  for (let i = 0; i <= 9; i++) {
    debtPerInterestRate[i as BranchId] = [];
  }

  // Check if MultiTroveGetter is deployed
  if (!CONTRACTS.MultiTroveGetter || !isContractDeployed(CONTRACTS.MultiTroveGetter.address)) {
    console.warn("MultiTroveGetter not deployed, returning empty debt per interest rate");
    return debtPerInterestRate;
  }
  
  try {
    const validBranches = CONTRACTS.branches.filter((branch: any) => 
      branch.contracts.TroveManager && 
      isContractDeployed(branch.contracts.TroveManager.address)
    );

    if (validBranches.length === 0) {
      return debtPerInterestRate;
    }

    const output = await client.multicall({
      contracts: validBranches.map((branch: any) => ({
        ...CONTRACTS.MultiTroveGetter,
        functionName: "getDebtPerInterestRateAscending",
        args: [branch.id, 0n, 10n],
      })),
    });

    validBranches.forEach((branch: any, index: number) => {
      const result = output[index];
      if (result?.status === "success") {
        debtPerInterestRate[branch.id as BranchId] = (result.result as unknown as [DebtPerInterestRate[], bigint])[0];
      }
    });
  } catch (error) {
    console.error("Error fetching debt per interest rate:", error);
  }

  return debtPerInterestRate;
}