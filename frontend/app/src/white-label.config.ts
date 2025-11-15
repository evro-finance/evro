/**
 * WHITE-LABEL CONFIGURATION
 *
 * This is the master configuration file for customizing the platform for different clients.
 * When creating a new fork, update all values in this file according to the client's requirements.
 */

export const WHITE_LABEL_CONFIG = {
  brandColors: {
    primary: "black:700" as const, // #1d1c1f (shark dark)
    primaryContent: "white" as const,
    primaryContentAlt: "gray:300" as const,

    secondary: "silver:100" as const,
    secondaryContent: "black:700" as const,
    secondaryContentAlt: "black:400" as const,

    accent1: "evro:orange" as const, // #efa960 (Evro brand orange)
    accent1Content: "white" as const,
    accent1ContentAlt: "white" as const,

    accent2: "evro:blue" as const, // #7176ca (vivid blue for CTAs/links)
    accent2Content: "white" as const,
    accent2ContentAlt: "evro:blueLight" as const,
  },

  // ===========================
  // TYPOGRAPHY
  // ===========================
  typography: {
    // Font family for CSS (used in Panda config)
    fontFamily: "Oswald, Lexend Zetta, sans-serif",
    // Next.js font import name (should match the import)
    fontImport: "Oswald, Lexend Zetta" as const,
  },

  // ===========================
  // UNIFIED TOKENS CONFIGURATION
  // ===========================
  tokens: {
    // Main protocol stablecoin
    mainToken: {
      name: "EVRO",
      symbol: "EVRO" as const,
      ticker: "EVRO",
      decimals: 18,
      description: "Euro-pegged stablecoin by EVRO Finance",
      icon: "main-token",
      // Core protocol contracts (deployment addresses TBD)
      deployments: {
        646: {
          // Ronin
          token: "0x0000000000000000000000000000000000000000", // TBD - EVRO deployment
          collateralRegistry: "0x0000000000000000000000000000000000000000", // TBD
          governance: "0x0000000000000000000000000000000000000000", // TBD
          hintHelpers: "0x0000000000000000000000000000000000000000", // TBD
          multiTroveGetter: "0x0000000000000000000000000000000000000000", // TBD
          exchangeHelpers: "0x0000000000000000000000000000000000000000", // TBD
        },
        // Placeholder for build compatibility (remove after deployment)
        1: {
          // Mainnet (placeholder)
          token: "0x0000000000000000000000000000000000000000",
          collateralRegistry: "0x0000000000000000000000000000000000000000",
          governance: "0x0000000000000000000000000000000000000000",
          hintHelpers: "0x0000000000000000000000000000000000000000",
          multiTroveGetter: "0x0000000000000000000000000000000000000000",
          exchangeHelpers: "0x0000000000000000000000000000000000000000",
        },
        11155111: {
          // Sepolia (placeholder)
          token: "0x0000000000000000000000000000000000000000",
          collateralRegistry: "0x0000000000000000000000000000000000000000",
          governance: "0x0000000000000000000000000000000000000000",
          hintHelpers: "0x0000000000000000000000000000000000000000",
          multiTroveGetter: "0x0000000000000000000000000000000000000000",
          exchangeHelpers: "0x0000000000000000000000000000000000000000",
        },
      },
    },

    evro: {
      name: "EVRO",
      symbol: "EVRO" as const,
      ticker: "EVRO",
      icon: "evro",
      decimals: 18,
      description: "Euro-pegged stablecoin by EVRO Finance",
      deployments: {
        646: {
          token: "0x0000000000000000000000000000000000000000",
          collateralRegistry: "0x0000000000000000000000000000000000000000",
          governance: "0x0000000000000000000000000000000000000000",
          hintHelpers: "0x0000000000000000000000000000000000000000",
          multiTroveGetter: "0x0000000000000000000000000000000000000000",
          exchangeHelpers: "0x0000000000000000000000000000000000000000",
        },
      },
    },

    // Governance token (exists but no functionality at launch)
    governanceToken: {
      name: "EVRO Governance Token",
      symbol: "GOV" as const,
      ticker: "GOV",
      icon: "main-token",
      // Only used as collateral, no governance features
      deployments: {
        646: {
          // Ronin mainnet
          token: "0x0000000000000000000000000000000000000000",
          staking: "0x0",
        },
        1: {
          token: "0x0000000000000000000000000000000000000000",
          staking: "0x0",
        },
        11155111: {
          token: "0x0000000000000000000000000000000000000000",
          staking: "0x0",
        },
      },
    },

    // Collateral tokens (for borrowing) - Multi-chain support
    collaterals: [
      // === ETH-based collaterals (110% MCR, 90.91% max LTV) ===
      {
        symbol: "ETH" as const,
        name: "ETH",
        icon: "eth",
        collateralRatio: 1.1, // 110% MCR
        maxDeposit: "100000000", // $100M initial debt limit
        maxLTV: 0.9091, // 90.91% max LTV
        // Deployment info (per chain)
        deployments: {
          646: {
            // EVRO Finance chain ID (TBD - needs actual deployment)
            collToken: "0x0000000000000000000000000000000000000000", // TBD
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
          },
          // Placeholder deployments for build compatibility
          1: {
            collToken: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
            leverageZapper: "0x978d7188ae01881d254ad7e94874653b0c268004",
            stabilityPool: "0xf69eb8c0d95d4094c16686769460f678727393cf",
            troveManager: "0x81d78814df42da2cab0e8870c477bc3ed861de66",
          },
          11155111: {
            collToken: "0x8116d0a0e8d4f0197b428c520953f302adca0b50",
            leverageZapper: "0x482bf4d6a2e61d259a7f97ef6aac8b3ce5dd9f99",
            stabilityPool: "0x89fb98c98792c8b9e9d468148c6593fa0fc47b40",
            troveManager: "0x364038750236739e0cd96d5754516c9b8168fb0c",
          },
        },
      },
      {
        symbol: "RETH" as const,
        name: "Rocket Pool ETH",
        icon: "reth",
        collateralRatio: 1.1, // 110% MCR for LSTs
        maxDeposit: "25000000", // $25M initial debt limit
        maxLTV: 0.9091, // 90.91% max LTV
        deployments: {
          646: {
            // EVRO Finance chain ID (TBD - needs actual rETH deployment)
            collToken: "0x0000000000000000000000000000000000000000", // TBD
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
          },
          // Placeholder deployments for build compatibility
          1: {
            collToken: "0xae78736cd615f374d3085123a210448e74fc6393",
            leverageZapper: "0x7d5f19a1e48479a95c4eb40fd1a534585026e7e5",
            stabilityPool: "0xc4463b26be1a6064000558a84ef9b6a58abe4f7a",
            troveManager: "0xde026433882a9dded65cac4fff8402fafff40fca",
          },
          11155111: {
            collToken: "0xbdb72f78302e6174e48aa5872f0dd986ed6d98d9",
            leverageZapper: "0x251dfe2078a910c644289f2344fac96bffea7c02",
            stabilityPool: "0x8492ad1df9f89e4b6c54c81149058172592e1c94",
            troveManager: "0x310fa1d1d711c75da45952029861bcf0d330aa81",
          },
        },
      },
    ],

    // Other tokens in the protocol
    otherTokens: {
      // ETH for display purposes
      eth: {
        symbol: "ETH" as const,
        name: "ETH",
        icon: "eth",
      },
      // SBOLD - yield-bearing version of the main token
      sbold: {
        symbol: "SBOLD" as const,
        name: "sEVRO Token",
        icon: "sbold",
      },
      // Staked version of main token
      staked: {
        symbol: "sEVRO" as const,
        name: "Staked EVRO",
        icon: "main-token",
      },
      lusd: {
        symbol: "LUSD" as const,
        name: "LUSD",
        icon: "legacy-stablecoin",
      },
    },
  },

  // ===========================
  // BRANDING & CONTENT
  // ===========================
  branding: {
    // Core app identity
    appName: "EVRO Portal", // Full app name for titles, about pages
    brandName: "EVRO", // Core brand name for protocol/version references
    appTagline: "Multi-chain stablecoin protocol",
    appDescription: "Borrow EVRO against multiple collateral types",
    appUrl: "https://evrofinance.com/",

    // External links
    links: {
      docs: {
        base: "https://docs.evrofinance.com/",
        redemptions: "https://docs.evrofinance.com/redemptions",
        liquidations: "https://docs.evrofinance.com/liquidations",
        delegation: "https://docs.evrofinance.com/delegation",
        interestRates: "https://docs.evrofinance.com/interest-rates",
        earn: "https://docs.evrofinance.com/earn",
        staking: "https://docs.evrofinance.com/staking",
      },
      dune: "https://dune.com/evrofinance",
      discord: "https://discord.gg/evrofinance",
      github: "https://github.com/evrofinance/evrofinance",
      x: "https://x.com/evrofinance",
      friendlyForkProgram: "https://evrofinance.com/ecosystem",
    },

    // Feature flags and descriptions
    features: {
      showV1Legacy: false, // No V1 legacy content
      friendlyFork: {
        enabled: true,
        title: "Learn more about the Friendly Fork Program",
        description: "A program for collaborative protocol development",
      },
    },

    // Navigation configuration
    navigation: {
      showBorrow: true,
      showEarn: true,
      showStake: false,
    },

    // Menu labels (can be customized per deployment)
    menu: {
      dashboard: "Dashboard",
      borrow: "Borrow",
      multiply: "Multiply",
      earn: "Earn",
      stake: "Stake",
    },

    // Common UI text
    ui: {
      connectWallet: "Connect",
      wrongNetwork: "Wrong network",
      loading: "Loading...",
      error: "Error",
    },
  },

  // ===========================
  // EARN POOLS CONFIGURATION
  // ===========================
  earnPools: {
    enableStakedMainToken: false,

    // Enable/disable stability pools for collaterals
    enableStabilityPools: true,

    // Custom pools configuration (beyond collateral stability pools)
    customPools: [] as Array<{
      symbol: string;
      name: string;
      enabled: boolean;
    }>,
  },
};

// Type exports for TypeScript support
export type WhiteLabelConfig = typeof WHITE_LABEL_CONFIG;

// Utility functions for dynamic configuration
export function getAvailableEarnPools() {
  const pools: Array<{
    symbol: string;
    name: string;
    type: "stability" | "staked" | "custom";
  }> = [];

  // Add stability pools for enabled collaterals
  if (WHITE_LABEL_CONFIG.earnPools.enableStabilityPools) {
    WHITE_LABEL_CONFIG.tokens.collaterals.forEach((collateral) => {
      pools.push({
        symbol: collateral.symbol.toLowerCase(),
        name: `${collateral.name} Stability Pool`,
        type: "stability",
      });
    });
  }

  // Add custom pools
  WHITE_LABEL_CONFIG.earnPools.customPools.forEach((pool) => {
    if (pool.enabled) {
      pools.push({
        symbol: pool.symbol.toLowerCase(),
        name: pool.name,
        type: "custom",
      });
    }
  });

  return pools;
}

export function getEarnPoolSymbols() {
  return getAvailableEarnPools().map((pool) => pool.symbol);
}

export function getCollateralSymbols() {
  return WHITE_LABEL_CONFIG.tokens.collaterals.map((collateral) =>
    collateral.symbol.toLowerCase()
  );
}
