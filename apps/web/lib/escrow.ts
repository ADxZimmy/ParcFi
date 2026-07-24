import {
  createPublicClient,
  createTestClient,
  createWalletClient,
  erc20Abi,
  http,
  keccak256,
  parseEventLogs,
  stringToHex,
  toBytes,
  type Address,
  type Hash,
  type PublicClient,
} from "viem";
import { goldenPathFixture, parcFiEscrowAbi, type DemoRole } from "@parcfi/shared";
import { getConfig, type AppConfig } from "./config";
import { accountFor, roleAccounts } from "./roles";

export interface AgreementView {
  payer: Address;
  attestor: Address;
  resolver: Address;
  docHash: `0x${string}`;
  expiry: bigint;
  obligationCount: number;
  fullyFunded: boolean;
  requiredTotal: bigint;
  fundedTotal: bigint;
  locked: bigint;
  cumulativeClaimed: bigint;
  cumulativeRefunded: bigint;
}

export interface ObligationView {
  beneficiary: Address;
  amount: bigint;
  requiredEvidenceType: `0x${string}`;
  challengeDuration: bigint;
  status: number;
  evidenceHash: `0x${string}`;
  attestedAt: bigint;
  challengeDeadline: bigint;
}

export interface ActivityEntry {
  blockNumber: bigint;
  txHash: Hash;
  label: string;
}

const config = getConfig();

export function appConfig(): AppConfig {
  return config;
}

export const publicClient: PublicClient = createPublicClient({
  chain: config.chain,
  transport: http(config.rpcUrl),
});

function walletFor(role: DemoRole) {
  return createWalletClient({
    account: accountFor(role),
    chain: config.chain,
    transport: http(config.rpcUrl),
  });
}

function escrowAddress(): Address {
  if (!config.escrowAddress) throw new Error("Escrow address not configured");
  return config.escrowAddress;
}

// ---------------------------------------------------------------------- reads

export async function readAgreementCount(): Promise<bigint> {
  return publicClient.readContract({
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "agreementCount",
  });
}

export async function readAgreement(id: bigint): Promise<AgreementView> {
  const a = await publicClient.readContract({
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "getAgreement",
    args: [id],
  });
  return { ...a, obligationCount: Number(a.obligationCount) };
}

export async function readObligations(id: bigint, count: number): Promise<ObligationView[]> {
  const reads = Array.from({ length: count }, (_, i) =>
    publicClient.readContract({
      address: escrowAddress(),
      abi: parcFiEscrowAbi,
      functionName: "getObligation",
      args: [id, BigInt(i)],
    }),
  );
  const raw = await Promise.all(reads);
  return raw.map((o) => ({ ...o, status: Number(o.status) }));
}

export async function readClaimable(id: bigint, account: Address): Promise<bigint> {
  return publicClient.readContract({
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "claimableOf",
    args: [id, account],
  });
}

export async function readRefundable(id: bigint, account: Address): Promise<bigint> {
  return publicClient.readContract({
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "refundableOf",
    args: [id, account],
  });
}

export async function readUsdcBalance(account: Address): Promise<bigint> {
  return publicClient.readContract({
    address: config.usdcAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [account],
  });
}

export async function readChainTimestamp(): Promise<bigint> {
  const block = await publicClient.getBlock();
  return block.timestamp;
}

// --------------------------------------------------------------------- writes

async function send(role: DemoRole, request: Parameters<ReturnType<typeof walletFor>["writeContract"]>[0]): Promise<Hash> {
  const wallet = walletFor(role);
  const hash = await wallet.writeContract(request);
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error(`Transaction reverted: ${hash}`);
  return hash;
}

/** Payer creates the fixture agreement (expiry: now + 7 days). Returns tx hash. */
export async function createDemoAgreement(): Promise<Hash> {
  const attestor = accountFor("attestor").address;
  const resolver = accountFor("resolver").address;
  const now = await readChainTimestamp();
  const docHash = keccak256(toBytes(`ParcFi demo invoice ${goldenPathFixture.invoiceId}`));
  const obligations = goldenPathFixture.lineItems.map((li) => ({
    beneficiary: accountFor(li.beneficiaryRole).address,
    amount: li.amount,
    requiredEvidenceType: stringToHex(li.requiredEvidenceType, { size: 32 }),
    challengeDuration: BigInt(li.challengeDurationSeconds),
  }));
  return send("payer", {
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "createAgreement",
    args: [docHash, attestor, resolver, now + 7n * 86_400n, obligations],
    chain: config.chain,
    account: accountFor("payer"),
  });
}

export async function approveUsdc(amount: bigint): Promise<Hash> {
  return send("payer", {
    address: config.usdcAddress,
    abi: erc20Abi,
    functionName: "approve",
    args: [escrowAddress(), amount],
    chain: config.chain,
    account: accountFor("payer"),
  });
}

export async function fund(id: bigint, amount: bigint): Promise<Hash> {
  return send("payer", {
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "fund",
    args: [id, amount],
    chain: config.chain,
    account: accountFor("payer"),
  });
}

export async function attest(id: bigint, obligationId: number): Promise<Hash> {
  const line = goldenPathFixture.lineItems[obligationId];
  const evidenceHash = keccak256(
    toBytes(`${goldenPathFixture.invoiceId}:${obligationId}:${Date.now()}`),
  );
  return send("attestor", {
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "attest",
    args: [
      id,
      BigInt(obligationId),
      evidenceHash,
      stringToHex(line?.requiredEvidenceType ?? "EV", { size: 32 }),
    ],
    chain: config.chain,
    account: accountFor("attestor"),
  });
}

export async function challenge(id: bigint, obligationId: number): Promise<Hash> {
  return send("payer", {
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "challenge",
    args: [id, BigInt(obligationId)],
    chain: config.chain,
    account: accountFor("payer"),
  });
}

export async function finalizeObligation(role: DemoRole, id: bigint, obligationId: number): Promise<Hash> {
  return send(role, {
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "finalizeObligation",
    args: [id, BigInt(obligationId)],
    chain: config.chain,
    account: accountFor(role),
  });
}

export async function resolve(id: bigint, obligationId: number, amountToBeneficiary: bigint): Promise<Hash> {
  return send("resolver", {
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "resolve",
    args: [id, BigInt(obligationId), amountToBeneficiary],
    chain: config.chain,
    account: accountFor("resolver"),
  });
}

export async function claim(role: DemoRole, id: bigint): Promise<Hash> {
  return send(role, {
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "claim",
    args: [id],
    chain: config.chain,
    account: accountFor(role),
  });
}

export async function withdrawRefund(id: bigint): Promise<Hash> {
  return send("payer", {
    address: escrowAddress(),
    abi: parcFiEscrowAbi,
    functionName: "withdrawRefund",
    args: [id],
    chain: config.chain,
    account: accountFor("payer"),
  });
}

/** Anvil-only: jump past challenge windows so the demo needn't wait in real time. */
export async function fastForward(seconds: number): Promise<void> {
  if (!config.isLocal) throw new Error("Time skip is only available on the local chain");
  const testClient = createTestClient({
    mode: "anvil",
    chain: config.chain,
    transport: http(config.rpcUrl),
  });
  await testClient.increaseTime({ seconds });
  await testClient.mine({ blocks: 1 });
}

// --------------------------------------------------------------------- events

export async function readActivity(id: bigint): Promise<ActivityEntry[]> {
  const logs = await publicClient.getLogs({
    address: escrowAddress(),
    fromBlock: config.startBlock,
    toBlock: "latest",
  });
  const parsed = parseEventLogs({ abi: parcFiEscrowAbi, logs });
  const roleByAddress = new Map(
    [...roleAccounts().values()].map((r) => [r.account.address.toLowerCase(), r.role]),
  );
  const who = (addr: string) => roleByAddress.get(addr.toLowerCase()) ?? addr.slice(0, 8);
  const usd = (v: bigint) => `$${(Number(v) / 1e6).toLocaleString("en-US")}`;

  return parsed
    .filter((log) => !("agreementId" in log.args) || log.args.agreementId === id)
    .map((log) => {
      const a = log.args as Record<string, unknown>;
      let label = log.eventName as string;
      switch (log.eventName) {
        case "AgreementCreated":
          label = `Agreement created by ${who(a.payer as string)} — ${usd(a.requiredTotal as bigint)} across ${a.obligationCount} lines`;
          break;
        case "ObligationCreated":
          label = `Line ${a.obligationId}: ${usd(a.amount as bigint)} to ${who(a.beneficiary as string)}`;
          break;
        case "Funded":
          label = `Funded ${usd(a.amount as bigint)} (total ${usd(a.fundedTotal as bigint)})`;
          break;
        case "FullyFunded":
          label = "Agreement fully funded — obligations are attestable";
          break;
        case "Attested":
          label = `Line ${a.obligationId} attested — challenge window open`;
          break;
        case "Challenged":
          label = `Line ${a.obligationId} disputed by payer`;
          break;
        case "ObligationFinalized":
          label = `Line ${a.obligationId} released — ${usd(a.amount as bigint)} claimable by ${who(a.beneficiary as string)}`;
          break;
        case "ObligationResolved":
          label = `Line ${a.obligationId} resolved — ${usd(a.amountToBeneficiary as bigint)} to beneficiary, ${usd(a.amountToPayer as bigint)} refunded`;
          break;
        case "ObligationExpired":
          label = `Line ${a.obligationId} expired — ${usd(a.amount as bigint)} refundable`;
          break;
        case "Claimed":
          label = `${who(a.beneficiary as string)} claimed ${usd(a.amount as bigint)}`;
          break;
        case "RefundWithdrawn":
          label = `${who(a.payer as string)} withdrew ${usd(a.amount as bigint)} refund`;
          break;
        case "UnfundedReclaimed":
          label = `Payer reclaimed ${usd(a.amount as bigint)} from unfunded agreement`;
          break;
      }
      return { blockNumber: log.blockNumber ?? 0n, txHash: log.transactionHash as Hash, label };
    })
    .reverse();
}
