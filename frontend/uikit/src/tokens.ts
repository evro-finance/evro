import tokenMainToken from "./token-icons/main-token.svg";
import tokenLusd from "./token-icons/lusd.svg";
import tokenSbold from "./token-icons/sbold.svg";
import evroToken from "./token-icons/evro.svg";
import { WHITE_LABEL_CONFIG } from "../../app/src/white-label.config";

// Import all available collateral icons
import tokenXdai from "./token-icons/xdai.webp";
import tokenGno from "./token-icons/gno.webp";
import tokenSdai from "./token-icons/sdai.webp";
import tokenWwbtc from "./token-icons/wwbtc.webp";
import tokenOsgno from "./token-icons/osgno.webp";
import tokenWsteth from "./token-icons/wsteth.svg";

// Map of available token icons by icon name from config
const tokenIconMap: Record<string, string> = {
  "main-token": tokenMainToken,
  "governance-token": tokenMainToken,
  "legacy-stablecoin": tokenLusd,
  "staked-main-token": tokenSbold,
  evro: evroToken,
  xdai: tokenXdai,
  gno: tokenGno,
  sdai: tokenSdai,
  wwbtc: tokenWwbtc,
  osgno: tokenOsgno,
  wsteth: tokenWsteth,
};

// any external token, without a known symbol
export type ExternalToken = {
  icon: string;
  name: string;
  symbol: string;
};

// a token with a known symbol (TokenSymbol)
export type Token = ExternalToken & {
  icon: string;
  name: string;
  symbol: TokenSymbol;
};

// Generate types from config
type ConfigCollateralSymbol =
  (typeof WHITE_LABEL_CONFIG.tokens.collaterals)[number]["symbol"];

export type TokenSymbol =
  | typeof WHITE_LABEL_CONFIG.tokens.mainToken.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.governanceToken.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.eth.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.staked.symbol
  | typeof WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.symbol
  | ConfigCollateralSymbol;

export type CollateralSymbol = ConfigCollateralSymbol;

export function isTokenSymbol(symbolOrUrl: string): symbolOrUrl is TokenSymbol {
  return (
    symbolOrUrl === WHITE_LABEL_CONFIG.tokens.mainToken.symbol ||
    symbolOrUrl === WHITE_LABEL_CONFIG.tokens.governanceToken.symbol ||
    symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.eth.symbol ||
    symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.symbol ||
    symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.staked.symbol ||
    symbolOrUrl === WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.symbol ||
    WHITE_LABEL_CONFIG.tokens.collaterals.some((c) => c.symbol === symbolOrUrl)
  );
}

export function isCollateralSymbol(symbol: string): symbol is CollateralSymbol {
  return WHITE_LABEL_CONFIG.tokens.collaterals.some((c) => c.symbol === symbol);
}

export type CollateralToken = Token & {
  collateralRatio: number;
  maxDeposit: string;
  symbol: CollateralSymbol;
};

// Generate all tokens from unified config
const MAIN_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.mainToken.icon],
  name: WHITE_LABEL_CONFIG.tokens.mainToken.name,
  symbol: WHITE_LABEL_CONFIG.tokens.mainToken.symbol,
} as const;

const GOVERNANCE_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.governanceToken.icon],
  name: WHITE_LABEL_CONFIG.tokens.governanceToken.name,
  symbol: WHITE_LABEL_CONFIG.tokens.governanceToken.symbol,
} as const;

const ETH_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.eth.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.eth.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.eth.symbol,
} as const;

const SBOLD_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.symbol,
} as const;

const STAKED_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.staked.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.staked.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.staked.symbol,
} as const;

const LUSD_TOKEN: Token = {
  icon: tokenIconMap[WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.icon],
  name: WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.name,
  symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.symbol,
} as const;

// Generate collaterals from config using dynamic icons
export const COLLATERALS: CollateralToken[] =
  WHITE_LABEL_CONFIG.tokens.collaterals.map((collateral) => {
    const iconUrl = tokenIconMap[collateral.icon];
    if (!iconUrl) {
      console.warn(
        `Missing icon mapping for "${collateral.icon}" (${collateral.symbol}), using fallback`
      );
    }
    return {
      collateralRatio: collateral.collateralRatio,
      icon: iconUrl || tokenIconMap["main-token"], // fallback to main token icon
      maxDeposit: collateral.maxDeposit,
      name: collateral.name,
      symbol: collateral.symbol,
    };
  });

// Build tokens map from config-driven definitions
const tokensMap: Record<string, Token | CollateralToken> = {
  [WHITE_LABEL_CONFIG.tokens.mainToken.symbol]: MAIN_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.governanceToken.symbol]: GOVERNANCE_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.eth.symbol]: ETH_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.sbold.symbol]: SBOLD_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.staked.symbol]: STAKED_TOKEN,
  [WHITE_LABEL_CONFIG.tokens.otherTokens.lusd.symbol]: LUSD_TOKEN,
};

// Add all collaterals to the map
COLLATERALS.forEach((collateral) => {
  tokensMap[collateral.symbol] = collateral;
});

export const TOKENS_BY_SYMBOL = tokensMap as Record<
  TokenSymbol,
  Token | CollateralToken
>;
