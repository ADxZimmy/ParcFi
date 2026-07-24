# Verification

## Automated Checks

- Command: `forge fmt --check`
  Result: Pass (2026-07-24).
  Notes: Run from `contracts/`. Foundry v1.7.1.
- Command: `forge build`
  Result: Pass (2026-07-24).
  Notes: `via_ir = true` required — the 8-field `AgreementCreated` event overflowed the stack under the legacy pipeline. Only advisory `block-timestamp` lints remain (inherent to a time-windowed escrow); the two `unsafe-typecast` lints are annotated safe (n ≤ MAX_OBLIGATIONS).
- Command: `forge test`
  Result: Pass — 66 passed, 0 failed, 0 skipped (2026-07-24).
  Notes: 64 unit/negative-path (`ParcFiEscrow.t.sol`) + 2 golden-path (`GoldenPath.t.sol`). Gas snapshot recorded in `contracts/.gas-snapshot`.
- Command: Fuzz/invariant suite (`test/invariant/*`)
  Result: Not run — deferred to the Fable 5 (High-tier) pass per `.planning/MODEL-POLICY.md` step-9 routing.
  Notes: A targeted conservation + solvency assertion (`_assertConservationAndSolvency`) already runs inside the golden-path and isolation tests over the known actor set; the unbounded-actor invariant harness is still to come.

## Manual Checks

- Check: State/accounting table review (SPEC.md ↔ implementation)
  Result: Pass for the transitions implemented; each of T1–T10 maps to a function with matching preconditions, effects, and events.
  Notes: Full adversarial security review is Gate G1 (Fable 5), not yet run.

- Check: Requirement trace
  Result: F-01..F-10 and NF-02..NF-04 implemented and unit-tested (creation, funding, attestation, challenge, finalize, pull claims, resolve split, expiry, refund, events, authorization reverts, bounded loops, SafeERC20/reentrancy/CEI). NF-01 (conservation) has targeted coverage; full invariant proof is step 9. NF-05 (fuzz/invariant depth) pending step 9.
  Notes: F-11..F-14 belong to Phase 003/004.

## Residual Risk

- Risk: Fuzz/invariant suite (step 9) and the G1 adversarial security review are not yet run; conservation is currently proven only over the known actor set, not unbounded fuzzing.
  Owner: Phase 002 High-tier (Fable 5) pass.

- Risk: Testnet prototype is unaudited and must not hold real value.
  Owner: Founder.

- Risk: CI uses Foundry `stable`; if a future stable release changes `forge fmt` output, the format check could drift from the locally pinned v1.7.1.
  Owner: Phase 004 (pin the CI toolchain version if drift appears).
