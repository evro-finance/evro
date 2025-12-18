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
        100: {
          token: "0x091b87551e14fc1b82367ce8908739e89d63f13d",
          collateralRegistry: "0xb9605ae6a03d31e5efc1ddfce4226b0c5a519c0f",
          governance: "0x09d5bd4a4f1da1a965fe24ea54bce3d37661e056",
          hintHelpers: "0xc5c1e2cfadb8f86580f5c7ea2f6d2691809c91ab",
          multiTroveGetter: "0x7a9a2d7ca836838c6fe42818d6d505eccf2e0e04",
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
        100: {
          token: "0x0000000000000000000000000000000000000000",
          staking: "0x0",
        },
      },
    },

    // Collateral tokens (for borrowing) - Multi-chain support
    collaterals: [
      {
        symbol: "XDAI" as const,
        name: "xDAI",
        icon: "xdai",
        collateralRatio: 1.1, // 110% MCR
        maxDeposit: "100000000", // €100M initial debt limit
        maxLTV: 0.9091, // 90.91% max LTV
        deployments: {
          100: {
            collToken: "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d",
            leverageZapper: "0x21c26321e43a0ff9170ce010c25ce7a3f73b2d77",
            stabilityPool: "0x68d0d846c89b3b7017d12a9a3ae51ddde9ccf56c",
            troveManager: "0x6e995ce9897840131fef1ff7871f96b67a343517",
            sortedTroves: "0x762e4127446c029030a3208538645b24243f6bce",
          },
        },
      },
      {
        symbol: "GNO" as const,
        name: "Gnosis",
        icon: "gno",
        collateralRatio: 1.4, // 140% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.7143, // 71.43% max LTV
        deployments: {
          100: {
            collToken: "0x9c58bacc331c9aa871afd802db6379a98e80cedb",
            leverageZapper: "0xb8648cbd215f97faf2c4c0eee5302bbed4f2aaec",
            stabilityPool: "0xb91f03813346d0b3371860b022909f6b0758adf4",
            troveManager: "0x315f40df9e11322e80369e496aec5ed617122d00",
            sortedTroves: "0x891307d242cf3249bbabf6778eb098aba10c3729",
          },
        },
      },
      {
        symbol: "SDAI" as const,
        name: "Savings xDAI",
        icon: "sdai",
        collateralRatio: 1.3, // 130% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.7692, // 76.92% max LTV
        deployments: {
          100: {
            collToken: "0xaf204776c7245bf4147c2612bf6e5972ee483701",
            leverageZapper: "0x063b0d2d57d5ff770e0188c80887adea87dbaa7d",
            stabilityPool: "0x33d1c95678c47acc31617725dc606c7d86602ad9",
            troveManager: "0x79e7c6b871b4b8c52b8df07e01b5cb3320159654",
            sortedTroves: "0x80e6c800e7a28b5005c32ecb77e3f4c671ef78cd",
          },
        },
      },
      {
        symbol: "WBTC" as const,
        name: "Gnosis xDai Bridged WBTC",
        icon: "wbtc",
        collateralRatio: 1.15, // 115% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.8696, // 86.96% max LTV
        deployments: {
          100: {
            collToken: "0x8e5bbbb09ed1ebde8674cda39a0c169401db4252",
            leverageZapper: "0x128ceaf0b986aeeb1f6c57d2e9965e54f2e201a1",
            stabilityPool: "0x37a0fcf6c5c20ec57ebe0b6b96299359637a286a",
            troveManager: "0xc47e2197d9380ccd56692d26ea0542a5fe2b8ce4",
            sortedTroves: "0xde8493a814e06ec366fefc5a335cffc8a00c1005",
          },
        },
      },
      {
        symbol: "OSGNO" as const,
        name: "StakeWise Staked GNO",
        icon: "osgno",
        collateralRatio: 1.4, // 140% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.7143, // 71.43% max LTV
        deployments: {
          100: {
            collToken: "0xf490c80aae5f2616d3e3bda2483e30c4cb21d1a0",
            leverageZapper: "0xce20c227e74a95b9288a47878146584a89d55785",
            stabilityPool: "0x82ab6396483ce5889809f34fff619f4c411539f7",
            troveManager: "0x9d16b7e044b3fc04cc040e853e7a080333d18b66",
            sortedTroves: "0xd8e0436774f0f9a2973542a7fbb5b14dd0c0c04c",
          },
        },
      },
      {
        symbol: "WSTETH" as const,
        name: "Wrapped Staked ETH",
        icon: "wsteth",
        collateralRatio: 1.3, // 130% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.7692, // 76.92% max LTV
        deployments: {
          100: {
            collToken: "0x6c76971f98945ae98dd7d4dfca8711ebea946ea6",
            leverageZapper: "0x865824c0b85325ec23a41257ebcd289e0caaaddc",
            stabilityPool: "0x1d6f305fdf625fdf76c0be0d2a5cd19aeb897e22",
            troveManager: "0x9ce05112a2f1b9d395af3ce16ba58f0031dfb977",
            sortedTroves: "0x79ae05720b4148d03efc2219bb623b3c7664abb2",
          },
        },
      },
    ],

    // Other tokens in the protocol
    otherTokens: {
      // ETH for display purposes
      eth: {
        symbol: "XDAI" as const,
        name: "xDAI",
        icon: "xdai",
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
    appUrl: "https://app.evro.finance/",

    // External links
    links: {
      docs: {
        base: "https://docs.evro.finance/",
        redemptions: "https://docs.evro.finance/redemptions",
        liquidations: "https://docs.evro.finance/liquidations",
        delegation: "https://docs.evro.finance/delegation",
        interestRates: "https://docs.evro.finance/interest-rates",
        earn: "https://docs.evro.finance/earn",
        staking: "https://docs.evro.finance/staking",
      },
      dune: "https://dune.com/evrofinance",
      discord: "https://discord.gg/evrofinance",
      github: "https://github.com/evrofinance/evrofinance",
      x: "https://x.com/evrofinance",
      friendlyForkProgram: "https://evro.finance/ecosystem",
    },

    // Feature flags and descriptions
    // features: {
    //   showV1Legacy: false, // No V1 legacy content
    //   friendlyFork: {
    //     enabled: true,
    //     title: "Learn more about the Friendly Fork Program",
    //     description: "A program for collaborative protocol development",
    //   },
    // },

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
