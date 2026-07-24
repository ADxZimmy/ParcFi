import type { Chain } from "viem";

/**
 * Arc Testnet. USDC is the NATIVE gas asset with 18-decimal accounting at the
 * protocol level; application transfers use the 6-decimal ERC-20 interface at
 * `ARC_TESTNET_USDC`. Never mix the two representations (contracts/SPEC.md).
 */
export const arcTestnet: Chain = {
  id: 5_042_002,
  name: "Arc Testnet",
  nativeCurrency: { name: "USDC", symbol: "USDC", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://rpc.testnet.arc.network"] },
  },
  blockExplorers: {
    default: { name: "Arcscan", url: "https://testnet.arcscan.app" },
  },
  testnet: true,
};

/** The 6-decimal ERC-20 interface of native USDC on Arc Testnet. */
export const ARC_TESTNET_USDC = "0x3600000000000000000000000000000000000000" as const;

/** Circle developer-platform blockchain identifier for Arc Testnet (Circle Contracts / Wallets APIs). */
export const CIRCLE_BLOCKCHAIN_ID = "ARC-TESTNET" as const;

/** Local anvil chain for development. */
export const anvilLocal: Chain = {
  id: 31_337,
  name: "Anvil (local)",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: ["http://127.0.0.1:8545"] },
  },
  testnet: true,
};

export const ARC_FAUCET_URL = "https://faucet.circle.com" as const;
