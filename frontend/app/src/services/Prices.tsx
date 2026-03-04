"use client";

import type { CollateralSymbol } from "@/src/types";
import type { UseQueryResult } from "@tanstack/react-query";
import type { Dnum } from "dnum";

import { PRICE_REFRESH_INTERVAL } from "@/src/constants";
import { getBranchContract } from "@/src/contracts";
import { dnum18, dnumOrNull } from "@/src/dnum-utils";
import { isCollateralSymbol } from "@liquity2/uikit";
import { useQuery } from "@tanstack/react-query";
import { useConfig as useWagmiConfig, useReadContracts } from "wagmi";
import { readContract } from "wagmi/actions";

async function fetchCollateralPrice(
  symbol: CollateralSymbol,
  config: ReturnType<typeof useWagmiConfig>,
): Promise<Dnum> {
  const [price] = await readContract(config, {
    ...getBranchContract(symbol, "PriceFeed"),
    functionName: "fetchPrice",
  });

  return dnum18(price);
}

export function usePrice(symbol: string | null): UseQueryResult<Dnum | null> {
  const config = useWagmiConfig();
  return useQuery({
    queryKey: ["usePrice", symbol],
    queryFn: async () => {
      if (symbol === null) {
        return null;
      }

      const response = await fetch("/api/prices");
      if (!response.ok) {
        throw new Error(`Failed to fetch prices: ${response.status}`);
      }
      const data = await response.json();
      const statsPrices = data.prices as Record<string, string>;

      const priceFromStats = statsPrices?.[symbol] ?? null;
      if (priceFromStats !== null) {
        return dnumOrNull(priceFromStats, 18);
      }

      if (isCollateralSymbol(symbol)) {
        return fetchCollateralPrice(symbol, config);
      }

      throw new Error(`The price for ${symbol} could not be found.`);
    },
    enabled: symbol !== null,
    refetchInterval: PRICE_REFRESH_INTERVAL,
  });
}

export function useCollateralPrices(symbols: CollateralSymbol[]) {
  return useReadContracts({
    allowFailure: false,

    contracts: symbols.map((symbol) => ({
      ...getBranchContract(symbol, "PriceFeed"),
      functionName: "fetchPrice",
    } as const)),

    query: {
      select: (data) => data.map(([price]) => dnum18(price)),
      refetchInterval: 12_000,
    },
  });
}
