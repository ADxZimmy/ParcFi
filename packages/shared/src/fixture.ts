import goldenPathJson from "../fixtures/golden-path-invoice.json";

export type DemoRole = "payer" | "attestor" | "resolver" | "carrier" | "terminal" | "forwarder";

export interface FixtureLineItem {
  obligationId: number;
  label: string;
  beneficiaryRole: Exclude<DemoRole, "payer" | "attestor" | "resolver">;
  amount: bigint;
  requiredEvidenceType: string;
  challengeDurationSeconds: number;
}

export interface GoldenPathFixture {
  invoiceId: string;
  requiredTotal: bigint;
  lineItems: FixtureLineItem[];
  challengeObligationIds: number[];
  resolution: { obligationId: number; amountToBeneficiary: bigint; amountToPayer: bigint };
}

/** The synthetic three-line demo invoice, typed and bigint-parsed. */
export const goldenPathFixture: GoldenPathFixture = {
  invoiceId: goldenPathJson.invoiceId,
  requiredTotal: BigInt(goldenPathJson.requiredTotal),
  lineItems: goldenPathJson.lineItems.map((li) => ({
    obligationId: li.obligationId,
    label: li.label,
    beneficiaryRole: li.beneficiaryRole as FixtureLineItem["beneficiaryRole"],
    amount: BigInt(li.amount),
    requiredEvidenceType: li.requiredEvidenceType,
    challengeDurationSeconds: li.challengeDurationSeconds,
  })),
  challengeObligationIds: goldenPathJson.demoScript.challengeObligationIds,
  resolution: {
    obligationId: goldenPathJson.demoScript.resolution.obligationId,
    amountToBeneficiary: BigInt(goldenPathJson.demoScript.resolution.amountToBeneficiary),
    amountToPayer: BigInt(goldenPathJson.demoScript.resolution.amountToPayer),
  },
};

export const DEMO_ROLES: DemoRole[] = ["payer", "attestor", "resolver", "carrier", "terminal", "forwarder"];
