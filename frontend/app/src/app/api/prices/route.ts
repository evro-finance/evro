import { NextResponse } from "next/server";
import { z } from "zod";

const COINGECKO_URL =
  "https://api.coingecko.com/api/v3/simple/price" +
  "?ids=gnosis,savings-xdai,gnosis-xdai-bridged-wbtc-gnosis-chain,stakewise-staked-gno-2" +
  "&vs_currencies=usd";

const FRANKFURTER_FX_URL = "https://api.frankfurter.dev/v1/latest?from=USD&to=EUR";

const FIVE_MIN_SECONDS = 5 * 60;

const CoinGeckoSimplePriceSchema = z.object({
  gnosis: z.object({ usd: z.number() }).optional(),
  "savings-xdai": z.object({ usd: z.number() }).optional(),
  "gnosis-xdai-bridged-wbtc-gnosis-chain": z.object({ usd: z.number() }).optional(),
  "stakewise-staked-gno-2": z.object({ usd: z.number() }).optional(),
});

const FrankfurterSchema = z.object({
  rates: z.object({
    EUR: z.number(),
  }),
});

const PricesSchema = z.object({
  prices: z.object({
    EVRO: z.string(),
    XDAI: z.string(),
    GNO: z.string(),
    SDAI: z.string(),
    WBTC: z.string(),
    OSGNO: z.string(),
  }),
});

type PricesResponse = z.infer<typeof PricesSchema>;

function getCacheControlHeader(seconds: number) {
  return `public, s-maxage=${seconds}, max-age=${seconds}, stale-while-revalidate=60`;
}

function usdToEurString(usd: number, usdToEurRate: number) {
  return (usd * usdToEurRate).toFixed(6);
}

export async function GET() {
  try {
    const [cgRes, fxRes] = await Promise.all([
      fetch(COINGECKO_URL, { next: { revalidate: FIVE_MIN_SECONDS } }),
      fetch(FRANKFURTER_FX_URL, { next: { revalidate: FIVE_MIN_SECONDS } }),
    ]);

    if (!cgRes.ok) {
      throw new Error(`CoinGecko error: ${cgRes.status} ${cgRes.statusText}`);
    }
    if (!fxRes.ok) {
      throw new Error(`Frankfurter error: ${fxRes.status} ${fxRes.statusText}`);
    }

    const [cgJson, fxJson] = await Promise.all([cgRes.json(), fxRes.json()]);

    const parsed = CoinGeckoSimplePriceSchema.parse(cgJson);
    const fxParsed = FrankfurterSchema.parse(fxJson);

    const usdToEurRate = fxParsed.rates.EUR;
    if (!Number.isFinite(usdToEurRate) || usdToEurRate <= 0) {
      throw new Error("Invalid USD→EUR rate from Frankfurter");
    }

    if (
      parsed.gnosis?.usd === undefined ||
      parsed["savings-xdai"]?.usd === undefined ||
      parsed["gnosis-xdai-bridged-wbtc-gnosis-chain"]?.usd === undefined ||
      parsed["stakewise-staked-gno-2"]?.usd === undefined
    ) {
      throw new Error("Missing required price(s) from CoinGecko response");
    }

    const prices: PricesResponse["prices"] = {
      EVRO: "1",

      XDAI: usdToEurRate.toString(),
      SDAI: usdToEurString(parsed["savings-xdai"].usd, usdToEurRate),
      GNO: usdToEurString(parsed.gnosis.usd, usdToEurRate),
      WBTC: usdToEurString(parsed["gnosis-xdai-bridged-wbtc-gnosis-chain"].usd, usdToEurRate),
      OSGNO: usdToEurString(parsed["stakewise-staked-gno-2"].usd, usdToEurRate),
    };

    const body: PricesResponse = { prices };
    PricesSchema.parse(body);

    return NextResponse.json(body, {
      headers: {
        "Cache-Control": getCacheControlHeader(FIVE_MIN_SECONDS),
      },
    });
  } catch (error) {
    console.error("[/api/prices] fetch failed:", error);

    let errorType = "unknown";
    let errorMessage = "Failed to fetch prices";
    if (error instanceof z.ZodError) {
      errorType = "validation_error";
      errorMessage = error.message;
    } else if (error instanceof Error) {
      if (error.message.startsWith("CoinGecko error:")) {
        errorType = "coingecko_api_error";
        errorMessage = error.message;
      } else if (error.message.startsWith("Frankfurter error:")) {
        errorType = "fx_api_error";
        errorMessage = error.message;
      } else {
        errorType = "network_or_internal_error";
        errorMessage = error.message;
      }
    }

    return NextResponse.json(
      { error: "Failed to fetch prices", errorType, errorMessage },
      {
        status: 502,
        headers: { "Cache-Control": "no-store" },
      },
    );
  }
}
