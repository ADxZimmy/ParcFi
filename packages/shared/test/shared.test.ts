import { describe, expect, it } from "vitest";
import { deriveAgreementStatus, ObligationStatus } from "../src/status";
import { formatUsdc, parseUsdc } from "../src/format";
import { goldenPathFixture } from "../src/fixture";

const { Pending, Attested, Challenged, Finalized, Resolved, Expired } = ObligationStatus;

describe("deriveAgreementStatus", () => {
  const funded = { fullyFunded: true, cumulativeRefunded: 0n, locked: 1n };

  it("is Awaiting funding before the latch", () => {
    expect(
      deriveAgreementStatus({ fullyFunded: false, cumulativeRefunded: 0n, locked: 0n }, [Pending]),
    ).toBe("Awaiting funding");
  });

  it("is Reclaimed after an unfunded reclaim", () => {
    expect(
      deriveAgreementStatus({ fullyFunded: false, cumulativeRefunded: 500n, locked: 0n }, [Expired]),
    ).toBe("Reclaimed");
  });

  it("is Disputed whenever any line is challenged", () => {
    expect(deriveAgreementStatus(funded, [Finalized, Challenged, Attested])).toBe("Disputed");
  });

  it("is Active while any line is open and none disputed", () => {
    expect(deriveAgreementStatus(funded, [Finalized, Attested, Pending])).toBe("Active");
  });

  it("is Settled when every line is terminal", () => {
    expect(deriveAgreementStatus(funded, [Finalized, Resolved, Expired])).toBe("Settled");
  });
});

describe("USDC formatting", () => {
  it("formats 6-decimal amounts as dollars", () => {
    expect(formatUsdc(7_500_000_000n)).toBe("7,500.00");
    expect(formatUsdc(600_000_000n)).toBe("600.00");
    expect(formatUsdc(1n)).toBe("0.00");
    expect(formatUsdc(10_000n)).toBe("0.01");
  });

  it("parses and round-trips", () => {
    expect(parseUsdc("7500")).toBe(7_500_000_000n);
    expect(parseUsdc("7,500.25")).toBe(7_500_250_000n);
    expect(() => parseUsdc("abc")).toThrow();
    expect(() => parseUsdc("1.1234567")).toThrow();
  });
});

describe("golden path fixture", () => {
  it("line items sum to the required total", () => {
    const sum = goldenPathFixture.lineItems.reduce((acc, li) => acc + li.amount, 0n);
    expect(sum).toBe(goldenPathFixture.requiredTotal);
  });

  it("resolution split conserves the disputed amount", () => {
    const line = goldenPathFixture.lineItems.find(
      (li) => li.obligationId === goldenPathFixture.resolution.obligationId,
    );
    expect(line).toBeDefined();
    expect(
      goldenPathFixture.resolution.amountToBeneficiary + goldenPathFixture.resolution.amountToPayer,
    ).toBe(line!.amount);
  });
});
