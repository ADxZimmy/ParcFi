import { anvilLocal, arcTestnet, ARC_TESTNET_USDC } from "@parcfi/shared";
import type { Address, Chain } from "viem";

export interface AppConfig {
  chain: Chain;
  rpcUrl: string;
  escrowAddress: Address | null;
  usdcAddress: Address;
  explorerBase: string | null;
  /** Anvil-only conveniences (time skip) are enabled when true. */
  isLocal: boolean;
  startBlock: bigint;
}

function readAddress(value: string | undefined): Address | null {
  if (!value || !/^0x[0-9a-fA-F]{40}$/.test(value)) return null;
  return value as Address;
}

/**
 * All configuration is NEXT_PUBLIC_* because the demo is a client-signed flow
 * against a public testnet with synthetic data. Server-held secrets (Circle API
 * keys) belong in server-only env vars once that integration lands.
 */
export function getConfig(): AppConfig {
  const network = process.env.NEXT_PUBLIC_NETWORK === "arc" ? "arc" : "anvil";
  const chain = network === "arc" ? arcTestnet : anvilLocal;
  const rpcUrl =
    process.env.NEXT_PUBLIC_RPC_URL ?? chain.rpcUrls.default.http[0] ?? "http://127.0.0.1:8545";
  const usdcAddress =
    readAddress(process.env.NEXT_PUBLIC_USDC_ADDRESS) ??
    (network === "arc" ? (ARC_TESTNET_USDC as Address) : null);

  return {
    chain,
    rpcUrl,
    escrowAddress: readAddress(process.env.NEXT_PUBLIC_ESCROW_ADDRESS),
    // On anvil the USDC address comes from the local deploy script via env; a
    // placeholder keeps the config total until the setup panel takes over.
    usdcAddress: usdcAddress ?? ("0x0000000000000000000000000000000000000000" as Address),
    explorerBase: chain.blockExplorers?.default.url ?? null,
    isLocal: network === "anvil",
    startBlock: BigInt(process.env.NEXT_PUBLIC_START_BLOCK ?? "0"),
  };
}

export function explorerTxUrl(config: AppConfig, hash: string): string | null {
  return config.explorerBase ? `${config.explorerBase}/tx/${hash}` : null;
}

export function explorerAddressUrl(config: AppConfig, address: string): string | null {
  return config.explorerBase ? `${config.explorerBase}/address/${address}` : null;
}
