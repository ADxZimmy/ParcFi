/** Mirrors IParcFiEscrow.ObligationStatus — order must match the Solidity enum. */
export const ObligationStatus = {
  Pending: 0,
  Attested: 1,
  Challenged: 2,
  Finalized: 3,
  Resolved: 4,
  Expired: 5,
} as const;

export type ObligationStatusValue = (typeof ObligationStatus)[keyof typeof ObligationStatus];

export const OBLIGATION_STATUS_LABELS: Record<ObligationStatusValue, string> = {
  [ObligationStatus.Pending]: "Pending",
  [ObligationStatus.Attested]: "Attested",
  [ObligationStatus.Challenged]: "Disputed",
  [ObligationStatus.Finalized]: "Released",
  [ObligationStatus.Resolved]: "Resolved",
  [ObligationStatus.Expired]: "Expired",
};

export function isTerminal(status: ObligationStatusValue): boolean {
  return (
    status === ObligationStatus.Finalized ||
    status === ObligationStatus.Resolved ||
    status === ObligationStatus.Expired
  );
}

export interface AgreementLike {
  fullyFunded: boolean;
  cumulativeRefunded: bigint;
  locked: bigint;
}

export type DerivedAgreementStatus =
  | "Awaiting funding"
  | "Reclaimed"
  | "Active"
  | "Disputed"
  | "Settled";

/**
 * Agreement-level status is DERIVED, never stored on-chain (contracts/SPEC.md):
 * the contract keeps per-line truth only, and the UI computes the rollup.
 */
export function deriveAgreementStatus(
  agreement: AgreementLike,
  statuses: readonly ObligationStatusValue[],
): DerivedAgreementStatus {
  if (!agreement.fullyFunded) {
    return agreement.cumulativeRefunded > 0n ? "Reclaimed" : "Awaiting funding";
  }
  if (statuses.some((s) => s === ObligationStatus.Challenged)) return "Disputed";
  if (statuses.every((s) => isTerminal(s))) return "Settled";
  return "Active";
}
