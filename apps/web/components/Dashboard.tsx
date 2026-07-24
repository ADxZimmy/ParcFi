"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  DEMO_ROLES,
  OBLIGATION_STATUS_LABELS,
  ObligationStatus,
  deriveAgreementStatus,
  formatUsdc,
  goldenPathFixture,
  shortAddress,
  type DemoRole,
  type ObligationStatusValue,
} from "@parcfi/shared";
import {
  appConfig,
  approveUsdc,
  attest,
  challenge,
  claim,
  createDemoAgreement,
  fastForward,
  finalizeObligation,
  fund,
  readActivity,
  readAgreement,
  readAgreementCount,
  readChainTimestamp,
  readClaimable,
  readObligations,
  readRefundable,
  readUsdcBalance,
  resolve,
  withdrawRefund,
  type ActivityEntry,
  type AgreementView,
  type ObligationView,
} from "../lib/escrow";
import { explorerTxUrl } from "../lib/config";
import { roleAccounts } from "../lib/roles";

const BENEFICIARY_ROLES: DemoRole[] = ["carrier", "terminal", "forwarder"];

type TxState =
  | { kind: "idle" }
  | { kind: "pending"; label: string }
  | { kind: "success"; label: string; hash: string }
  | { kind: "error"; label: string; message: string };

const STATUS_CLASS: Record<ObligationStatusValue, string> = {
  [ObligationStatus.Pending]: "pending",
  [ObligationStatus.Attested]: "attested",
  [ObligationStatus.Challenged]: "disputed",
  [ObligationStatus.Finalized]: "released",
  [ObligationStatus.Resolved]: "resolved",
  [ObligationStatus.Expired]: "expired",
};

function StatusChip({ status }: { status: ObligationStatusValue }) {
  return <span className={`chip ${STATUS_CLASS[status]}`}>{OBLIGATION_STATUS_LABELS[status]}</span>;
}

function Stat({ k, v }: { k: string; v: string }) {
  return (
    <div className="stat">
      <div className="k">{k}</div>
      <div className="v">{v}</div>
    </div>
  );
}

function errorMessage(err: unknown): string {
  if (err && typeof err === "object") {
    const e = err as { shortMessage?: string; message?: string };
    return (e.shortMessage ?? e.message ?? String(err)).split("\n")[0] ?? "Unknown error";
  }
  return String(err);
}

export default function Dashboard() {
  const config = appConfig();
  const roles = roleAccounts();

  const [role, setRole] = useState<DemoRole>("payer");
  const [agreementId, setAgreementId] = useState<bigint | null>(null);
  const [agreement, setAgreement] = useState<AgreementView | null>(null);
  const [obligations, setObligations] = useState<ObligationView[]>([]);
  const [claimables, setClaimables] = useState<Partial<Record<DemoRole, bigint>>>({});
  const [refundable, setRefundable] = useState<bigint>(0n);
  const [balances, setBalances] = useState<Partial<Record<DemoRole, bigint>>>({});
  const [activity, setActivity] = useState<ActivityEntry[]>([]);
  const [chainNow, setChainNow] = useState<bigint>(0n);
  const [tx, setTx] = useState<TxState>({ kind: "idle" });
  const [rpcError, setRpcError] = useState<string | null>(null);
  const busy = tx.kind === "pending";
  const busyRef = useRef(false);

  const refresh = useCallback(async () => {
    if (!config.escrowAddress) return;
    try {
      const [count, now] = await Promise.all([readAgreementCount(), readChainTimestamp()]);
      setChainNow(now);
      if (count === 0n) {
        setAgreementId(null);
        setAgreement(null);
        setObligations([]);
        setActivity([]);
        setRpcError(null);
        return;
      }
      const id = count - 1n;
      const a = await readAgreement(id);
      const [obs, acts, refund, ...rest] = await Promise.all([
        readObligations(id, a.obligationCount),
        readActivity(id),
        readRefundable(id, roles.get("payer")!.account.address),
        ...BENEFICIARY_ROLES.map((r) => readClaimable(id, roles.get(r)!.account.address)),
        ...DEMO_ROLES.map((r) => readUsdcBalance(roles.get(r)!.account.address)),
      ]);
      const claimableValues = rest.slice(0, BENEFICIARY_ROLES.length) as bigint[];
      const balanceValues = rest.slice(BENEFICIARY_ROLES.length) as bigint[];
      setAgreementId(id);
      setAgreement(a);
      setObligations(obs);
      setActivity(acts);
      setRefundable(refund);
      setClaimables(Object.fromEntries(BENEFICIARY_ROLES.map((r, i) => [r, claimableValues[i]])));
      setBalances(Object.fromEntries(DEMO_ROLES.map((r, i) => [r, balanceValues[i]])));
      setRpcError(null);
    } catch (err) {
      setRpcError(errorMessage(err));
    }
  }, [config.escrowAddress, roles]);

  useEffect(() => {
    void refresh();
    const timer = setInterval(() => {
      if (!busyRef.current) void refresh();
    }, 4000);
    return () => clearInterval(timer);
  }, [refresh]);

  const run = useCallback(
    async (label: string, action: () => Promise<string | void>) => {
      if (busyRef.current) return;
      busyRef.current = true;
      setTx({ kind: "pending", label });
      try {
        const hash = await action();
        setTx({ kind: "success", label, hash: typeof hash === "string" ? hash : "" });
      } catch (err) {
        setTx({ kind: "error", label, message: errorMessage(err) });
      } finally {
        busyRef.current = false;
        void refresh();
      }
    },
    [refresh],
  );

  const derived = useMemo(
    () =>
      agreement
        ? deriveAgreementStatus(agreement, obligations.map((o) => o.status as ObligationStatusValue))
        : null,
    [agreement, obligations],
  );

  const remainingFunding = agreement ? agreement.requiredTotal - agreement.fundedTotal : 0n;
  const maxOpenDeadline = useMemo(() => {
    const deadlines = obligations
      .filter((o) => o.status === ObligationStatus.Attested && o.challengeDeadline > chainNow)
      .map((o) => o.challengeDeadline);
    return deadlines.length ? deadlines.reduce((a, b) => (a > b ? a : b)) : null;
  }, [obligations, chainNow]);

  if (!config.escrowAddress) {
    return (
      <>
        <Masthead />
        <div className="setup">
          <b>No escrow contract configured.</b> Local quickstart:
          <code>
            {`# 1. terminal A — local chain\nanvil\n\n# 2. terminal B — deploy escrow + mock USDC (from contracts/)\nforge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast \\\n  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80\n\n# 3. apps/web/.env.local — paste the two logged addresses\nNEXT_PUBLIC_ESCROW_ADDRESS=0x...\nNEXT_PUBLIC_USDC_ADDRESS=0x...\n\n# 4. restart next dev`}
          </code>
          For Arc Testnet, see <a href="https://github.com/ADxZimmy/ParcFi#readme">the README</a>: set{" "}
          <code style={{ display: "inline", padding: "1px 6px" }}>NEXT_PUBLIC_NETWORK=arc</code>, deploy via
          Circle Contracts, and fund demo wallets from the Circle faucet.
        </div>
      </>
    );
  }

  return (
    <>
      <Masthead />
      <div className="netline">
        <span>
          Network <code>{config.chain.name}</code>
        </span>
        <span>
          Escrow <code>{shortAddress(config.escrowAddress)}</code>
        </span>
        <span>
          USDC <code>{shortAddress(config.usdcAddress)}</code>
        </span>
        {derived && (
          <span>
            Agreement #{agreementId?.toString()} <span className={`chip ${derived === "Disputed" ? "disputed" : derived === "Settled" ? "settled" : "active"}`}>{derived}</span>
          </span>
        )}
        {rpcError && <span style={{ color: "var(--red)" }}>RPC: {rpcError}</span>}
      </div>

      {tx.kind !== "idle" && (
        <div className={`banner ${tx.kind}`}>
          {tx.kind === "pending" && <span className="spinner" />}
          <span>
            <b>{tx.label}</b>
            {tx.kind === "pending" && " — waiting for confirmation…"}
            {tx.kind === "error" && ` — ${tx.message}`}
            {tx.kind === "success" && " — confirmed"}
          </span>
          {tx.kind === "success" && tx.hash && explorerTxUrl(config, tx.hash) && (
            <a href={explorerTxUrl(config, tx.hash)!} target="_blank" rel="noreferrer">
              view on explorer ↗
            </a>
          )}
        </div>
      )}

      <div className="card">
        <h2>Acting as</h2>
        <div className="rolebar">
          {DEMO_ROLES.map((r) => (
            <button
              key={r}
              className={`roleselect ${r === role ? "selected" : ""}`}
              onClick={() => setRole(r)}
            >
              {r}
            </button>
          ))}
          <span className="hint">
            {shortAddress(roles.get(role)!.account.address)} · demo burner account (testnet only)
          </span>
        </div>
      </div>

      {!agreement && (
        <div className="card">
          <h2>Start the demo</h2>
          <p style={{ marginTop: 0 }}>
            Create the synthetic three-line invoice: base freight $7,500 → carrier · port handling
            $1,500 → terminal · demurrage $1,000 → forwarder.
          </p>
          <button
            className="primary"
            disabled={busy || role !== "payer"}
            onClick={() => run("Create demo agreement", () => createDemoAgreement())}
          >
            Create demo agreement
          </button>
          {role !== "payer" && <span className="hint"> — switch to the payer role</span>}
        </div>
      )}

      {agreement && (
        <>
          <div className="card">
            <h2>Money state</h2>
            <div className="stats">
              <Stat k="Required" v={`$${formatUsdc(agreement.requiredTotal)}`} />
              <Stat k="Funded" v={`$${formatUsdc(agreement.fundedTotal)}`} />
              <Stat k="Locked" v={`$${formatUsdc(agreement.locked)}`} />
              <Stat
                k="Claimable"
                v={`$${formatUsdc(BENEFICIARY_ROLES.reduce((acc, r) => acc + (claimables[r] ?? 0n), 0n))}`}
              />
              <Stat k="Refundable" v={`$${formatUsdc(refundable)}`} />
              <Stat k="Claimed" v={`$${formatUsdc(agreement.cumulativeClaimed)}`} />
              <Stat k="Refunded" v={`$${formatUsdc(agreement.cumulativeRefunded)}`} />
            </div>
            {!agreement.fullyFunded && (
              <div style={{ marginTop: 12 }}>
                <button
                  className="primary"
                  disabled={busy || role !== "payer"}
                  onClick={() =>
                    run(`Approve & fund $${formatUsdc(remainingFunding)}`, async () => {
                      await approveUsdc(remainingFunding);
                      return fund(agreementId!, remainingFunding);
                    })
                  }
                >
                  Approve &amp; fund ${formatUsdc(remainingFunding)}
                </button>
                {role !== "payer" && <span className="hint"> — switch to the payer role</span>}
              </div>
            )}
          </div>

          <div className="card">
            <h2>Invoice lines</h2>
            <table className="lines">
              <thead>
                <tr>
                  <th>Line</th>
                  <th>Beneficiary</th>
                  <th>Amount</th>
                  <th>Status</th>
                  <th style={{ textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {obligations.map((o, i) => {
                  const fixtureLine = goldenPathFixture.lineItems[i];
                  const status = o.status as ObligationStatusValue;
                  const secondsLeft =
                    status === ObligationStatus.Attested && o.challengeDeadline > chainNow
                      ? Number(o.challengeDeadline - chainNow)
                      : 0;
                  return (
                    <tr key={i}>
                      <td>
                        <div className="line-label">{fixtureLine?.label ?? `Line ${i}`}</div>
                        <div className="line-sub">
                          evidence: {fixtureLine?.requiredEvidenceType ?? "—"} · window{" "}
                          {Number(o.challengeDuration)}s
                        </div>
                      </td>
                      <td>
                        <div>{fixtureLine?.beneficiaryRole ?? shortAddress(o.beneficiary)}</div>
                        <div className="line-sub">{shortAddress(o.beneficiary)}</div>
                      </td>
                      <td>${formatUsdc(o.amount)}</td>
                      <td>
                        <StatusChip status={status} />
                        {secondsLeft > 0 && (
                          <div className="countdown">challenge closes in {secondsLeft}s</div>
                        )}
                      </td>
                      <td>
                        <div className="actions">
                          {status === ObligationStatus.Pending && agreement.fullyFunded && (
                            <button
                              disabled={busy || role !== "attestor"}
                              title={role !== "attestor" ? "Switch to the attestor role" : undefined}
                              onClick={() => run(`Attest line ${i}`, () => attest(agreementId!, i))}
                            >
                              Attest evidence
                            </button>
                          )}
                          {status === ObligationStatus.Attested && secondsLeft > 0 && (
                            <button
                              className="danger"
                              disabled={busy || role !== "payer"}
                              title={role !== "payer" ? "Switch to the payer role" : undefined}
                              onClick={() => run(`Dispute line ${i}`, () => challenge(agreementId!, i))}
                            >
                              Dispute
                            </button>
                          )}
                          {status === ObligationStatus.Attested && secondsLeft === 0 && (
                            <button
                              className="primary"
                              disabled={busy}
                              onClick={() =>
                                run(`Release line ${i}`, () => finalizeObligation(role, agreementId!, i))
                              }
                            >
                              Release
                            </button>
                          )}
                          {status === ObligationStatus.Challenged && (
                            <>
                              <button
                                disabled={busy || role !== "resolver"}
                                title={role !== "resolver" ? "Switch to the resolver role" : undefined}
                                onClick={() =>
                                  run(`Resolve line ${i}: split 60/40`, () =>
                                    resolve(agreementId!, i, (o.amount * 60n) / 100n),
                                  )
                                }
                              >
                                Split 60/40
                              </button>
                              <button
                                disabled={busy || role !== "resolver"}
                                onClick={() =>
                                  run(`Resolve line ${i}: release all`, () =>
                                    resolve(agreementId!, i, o.amount),
                                  )
                                }
                              >
                                Release all
                              </button>
                              <button
                                className="danger"
                                disabled={busy || role !== "resolver"}
                                onClick={() =>
                                  run(`Resolve line ${i}: refund all`, () => resolve(agreementId!, i, 0n))
                                }
                              >
                                Refund all
                              </button>
                            </>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            {config.isLocal && maxOpenDeadline && (
              <div style={{ marginTop: 12 }}>
                <button
                  disabled={busy}
                  onClick={() =>
                    run("Skip challenge window (local time travel)", async () => {
                      await fastForward(Number(maxOpenDeadline - chainNow) + 1);
                    })
                  }
                >
                  ⏩ Skip challenge window (local only)
                </button>
              </div>
            )}
          </div>

          <div className="card">
            <h2>Withdrawals</h2>
            <div className="rolebar" style={{ marginBottom: 10 }}>
              {BENEFICIARY_ROLES.map((r) => (
                <button
                  key={r}
                  disabled={busy || (claimables[r] ?? 0n) === 0n || role !== r}
                  title={role !== r ? `Switch to the ${r} role` : undefined}
                  onClick={() => run(`${r} claims $${formatUsdc(claimables[r] ?? 0n)}`, () => claim(r, agreementId!))}
                >
                  {r} claims ${formatUsdc(claimables[r] ?? 0n)}
                </button>
              ))}
              <button
                disabled={busy || refundable === 0n || role !== "payer"}
                title={role !== "payer" ? "Switch to the payer role" : undefined}
                onClick={() => run(`Payer withdraws $${formatUsdc(refundable)} refund`, () => withdrawRefund(agreementId!))}
              >
                payer withdraws ${formatUsdc(refundable)} refund
              </button>
            </div>
            <div className="balances">
              {DEMO_ROLES.map((r) => (
                <span key={r}>
                  {r}: <b>${formatUsdc(balances[r] ?? 0n)}</b>
                </span>
              ))}
            </div>
          </div>

          <div className="card">
            <h2>On-chain activity</h2>
            <ul className="activity">
              {activity.length === 0 && <li>No events yet.</li>}
              {activity.map((entry, i) => (
                <li key={`${entry.txHash}-${i}`}>
                  <span>{entry.label}</span>
                  {explorerTxUrl(config, entry.txHash) ? (
                    <a className="txlink" href={explorerTxUrl(config, entry.txHash)!} target="_blank" rel="noreferrer">
                      {shortAddress(entry.txHash)} ↗
                    </a>
                  ) : (
                    <span className="txlink">{shortAddress(entry.txHash)}</span>
                  )}
                </li>
              ))}
            </ul>
          </div>

          <div className="card">
            <h2>Demo reset</h2>
            <button
              disabled={busy || role !== "payer"}
              title={role !== "payer" ? "Switch to the payer role" : undefined}
              onClick={() => run("Create fresh demo agreement", () => createDemoAgreement())}
            >
              New demo agreement
            </button>
            <span className="hint">
              {" "}
              Creates a fresh agreement; prior agreements stay on-chain untouched (event history is per
              agreement).
            </span>
          </div>
        </>
      )}

      <p className="footnote">
        Testnet prototype with synthetic freight data — not production, not legal or investment advice.
        Documents stay off-chain; only content hashes are anchored. Demo roles use throwaway burner
        accounts; production users onboard through Circle user-controlled wallets.
      </p>
    </>
  );
}

function Masthead() {
  return (
    <header className="masthead">
      <h1>ParcFi</h1>
      <span className="thesis">
        Release the undisputed invoice lines immediately — hold only the exceptions in programmable
        USDC escrow.
      </span>
    </header>
  );
}
