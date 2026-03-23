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
          token: "0xdaca5f19e7a33277dc7477067f200ea735dc6982",
          collateralRegistry: "0x9ae5b0cf832391040af0873c97c4bb4b9a397680",
          governance: "0x09d5bd4a4f1da1a965fe24ea54bce3d37661e056",
          hintHelpers: "0xcf761070094b74c15a10a062d97f3c13ed509c2f",
          multiTroveGetter: "0x143bf8f09461631cde4b9b4dd86fa62a3632ac26",
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
            leverageZapper: "0xb47884655ec6dd2822afd5de04860fa0a2187c59",
            stabilityPool: "0x26a47c21e26b315b8e536dca87ba918e49713b7e",
            troveManager: "0x5fb05da0545a7c7787f0091df80a246f8dc43a3d",
            sortedTroves: "0xc014a390e169264fb748f43d7169e351648d3562",
            borrowerOperations: "0x612d2dcfb3dbc579b65a89380f1171347cc7d280",
          },
        },
      },
      {
        symbol: "GNO" as const,
        name: "GNO",
        icon: "gno",
        collateralRatio: 1.4, // 140% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.7143, // 71.43% max LTV
        deployments: {
          100: {
            collToken: "0x9c58bacc331c9aa871afd802db6379a98e80cedb",
            leverageZapper: "0x3bf218c559c1e49debf444fcd149e67eaacef5ba",
            stabilityPool: "0x9917aba496240fa29c10f1f6312eb83abb749b58",
            troveManager: "0x91c287b9d31dbaee9ea62bd6b5ea76461c5962af",
            sortedTroves: "0x981a02639a60c0c3adf818de89d4f99f7a3ac49a",
            borrowerOperations: "0xc87b8baad859196418e255bcbc7ed732c39e191f",
          },
        },
      },
      {
        symbol: "SDAI" as const,
        name: "sDAI",
        icon: "sdai",
        collateralRatio: 1.3, // 130% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.7692, // 76.92% max LTV
        deployments: {
          100: {
            collToken: "0xaf204776c7245bf4147c2612bf6e5972ee483701",
            leverageZapper: "0xcdffc42d1c1b74cf82144c13a344dcf6a3beb004",
            stabilityPool: "0x2e687202b71eecf3dfaa846a2a96096efa5d6df2",
            troveManager: "0xbe035f27600a2db1988916ed97c2cfe6d2674970",
            sortedTroves: "0x49f6ada0c84930dd7465c26682072e4d5ead8377",
            borrowerOperations: "0x6e50fe6bfa4e69bf6dc32d3a95a63fc2fcb5ed01",
          },
        },
      },
      {
        symbol: "WBTC" as const,
        name: "wBTC",
        icon: "wbtc",
        collateralRatio: 1.15, // 115% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.8696, // 86.96% max LTV
        deployments: {
          100: {
            collToken: "0xcfa17d000980085f13ae66beb68a3fee48fab8ec",
            leverageZapper: "0xdf5f4c29187f3ef222b6a734ef1d2860a43e9585",
            stabilityPool: "0xe7f7e850e7b211d41e29a31a9e7938dfcd934539",
            troveManager: "0x83571b02fb04a92ba505843c07aa865c5ec1b131",
            sortedTroves: "0x61aeb7a5a3ada3272f517be625438a6bedb1c3b4",
            borrowerOperations: "0xfc9f712acc707bbe6124b21c1e0dc335f745a2b4",
          },
        },
      },
      {
        symbol: "OSGNO" as const,
        name: "osGNO",
        icon: "osgno",
        collateralRatio: 1.4, // 140% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.7143, // 71.43% max LTV
        deployments: {
          100: {
            collToken: "0xf490c80aae5f2616d3e3bda2483e30c4cb21d1a0",
            leverageZapper: "0xc53baeb564660bb58a401583fccb34753ba28e82",
            stabilityPool: "0x8bada3ae3dd00f6fc2b4a5705a612b5582316a83",
            troveManager: "0x364173c1b46f6fc8c12eabfe02ea8b2acde3f2fb",
            sortedTroves: "0x3aa2c64c2c04ee1a5614dd8fd20f490b621d6f62",
            borrowerOperations: "0xb09050abd02e9d728fca57e836f821fa4830ce6a",
          },
        },
      },
      {
        symbol: "WSTETH" as const,
        name: "wstETH",
        icon: "wsteth",
        collateralRatio: 1.3, // 130% MCR
        maxDeposit: "25000000", // €25M initial debt limit
        maxLTV: 0.7692, // 76.92% max LTV
        deployments: {
          100: {
            collToken: "0x6c76971f98945ae98dd7d4dfca8711ebea946ea6",
            leverageZapper: "0x712e2e94308e68b1f00cef467f400b095396a1c1",
            stabilityPool: "0xfe3155bc651424d10a044a32a05a0772c0351922",
            troveManager: "0xf9419cbb1edc917eda8ea0addb08ddcc0213dc9d",
            sortedTroves: "0x82cb0249d3a76b5450b39a827db528654628766f",
            borrowerOperations: "0x8228b4918380164dea7b2e3d0abde5ab6046fd24",
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
