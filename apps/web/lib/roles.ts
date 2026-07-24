import { DEMO_ROLES, type DemoRole } from "@parcfi/shared";
import { privateKeyToAccount, type PrivateKeyAccount } from "viem/accounts";
import type { Hex } from "viem";

/**
 * Demo burner accounts, one per role, in DEMO_ROLES order:
 * payer, attestor, resolver, carrier, terminal, forwarder.
 *
 * Defaults are the canonical anvil development keys — public knowledge, safe
 * ONLY on a local chain. For Arc Testnet set NEXT_PUBLIC_DEMO_KEYS to six
 * comma-separated fresh burner keys that hold nothing but demo funds. These are
 * throwaway demo credentials by design (testnet-only, synthetic data); real
 * users are onboarded through Circle user-controlled wallets instead.
 */
const ANVIL_KEYS: Hex[] = [
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
  "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
  "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a",
  "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
];

function demoKeys(): Hex[] {
  const raw = process.env.NEXT_PUBLIC_DEMO_KEYS;
  if (!raw) return ANVIL_KEYS;
  const keys = raw.split(",").map((k) => k.trim()) as Hex[];
  if (keys.length !== DEMO_ROLES.length || keys.some((k) => !/^0x[0-9a-fA-F]{64}$/.test(k))) {
    throw new Error(`NEXT_PUBLIC_DEMO_KEYS must be ${DEMO_ROLES.length} comma-separated 32-byte hex keys`);
  }
  return keys;
}

export interface RoleAccount {
  role: DemoRole;
  account: PrivateKeyAccount;
}

let cached: Map<DemoRole, RoleAccount> | null = null;

export function roleAccounts(): Map<DemoRole, RoleAccount> {
  if (!cached) {
    const keys = demoKeys();
    cached = new Map(
      DEMO_ROLES.map((role, i) => [role, { role, account: privateKeyToAccount(keys[i]!) }]),
    );
  }
  return cached;
}

export function accountFor(role: DemoRole): PrivateKeyAccount {
  const entry = roleAccounts().get(role);
  if (!entry) throw new Error(`Unknown role: ${role}`);
  return entry.account;
}
