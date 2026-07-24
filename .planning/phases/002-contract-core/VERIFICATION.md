# Verification

## Automated Checks

- Command: `forge fmt --check`
  Result: Pass (2026-07-24).
  Notes: Run from `contracts/`. Foundry v1.7.1.
- Command: `forge build`
  Result: Pass (2026-07-24).
  Notes: `via_ir = true` required — the 8-field `AgreementCreated` event overflowed the stack under the legacy pipeline. Only advisory `block-timestamp` lints remain (inherent to a time-windowed escrow); the two `unsafe-typecast` lints are annotated safe (n ≤ MAX_OBLIGATIONS).
- Command: `forge test`
  Result: Pass — 74 passed, 0 failed, 0 skipped (2026-07-24, final).
  Notes: 65 unit/negative-path (incl. the G1-F1 regression) + 2 golden-path + 3 stateless fuzz properties + 4 invariant campaigns. Gas snapshot regenerated in `contracts/.gas-snapshot`.
- Command: `forge test --match-path "test/invariant/*"` (Fable 5 / High-tier, 2026-07-24)
  Result: Pass — 4 invariant campaigns (solvency-exact, two-regime conservation, locked-vs-open-obligations, terminal-status stickiness), each 128 runs × depth 64 over a 10-actor pool driving all T1–T10 transitions with time warping. Runs with `fail-on-revert = true` and zero handler reverts: the handler mirrors contract preconditions exactly, so any unexpected revert is itself a finding. Includes an active G1-F1 probe (`expectRevert` on fund-after-reclaim).
- Command: Mutation test (test-power check)
  Result: Pass — with the G1-F1 guard deliberately removed, the regression test AND all 4 invariant campaigns fail ("next call did not revert as expected"); with the guard restored, all 74 pass. The suite provably defends the invariant rather than passing vacuously.
- Command: Stateless fuzz properties (`FuzzProperties.t.sol`)
  Result: Pass — for arbitrary amounts/splits/durations: resolve splits conserve exactly with no rounding loss and drain to zero; partial funding never latches, over-funding always reverts, the exact remainder latches with `locked == requiredTotal`; the challenge/finalize deadline boundary is exclusive and gapless.

## Manual Checks

- Check: State/accounting table review (SPEC.md ↔ implementation)
  Result: Pass; each of T1–T10 maps to a function with matching preconditions, effects, and events.
  Notes: Superseded by the full G1 review below.

- Check: Gate G1 — adversarial security review (Fable 5, high effort, 2026-07-24)
  Result: Complete. One real defect found and fixed; five informational findings documented in SPEC.md; core safety mechanisms verified.
  Notes — findings register:
  - G1-F1 (MEDIUM, FIXED): fund-after-reclaim stranded funds and broke INV-1. T8 returned the deposit but left `fundedTotal` intact, so a later `fund()` could latch `fullyFunded` against terminally Expired obligations, locking the new deposit forever with no reachable transition. Fix: `fund()` rejects any agreement whose obligation 0 is not `Pending` (sound sentinel: pre-full-funding, T8 is the only status-flipping transition and it flips all lines atomically). Covered by a deterministic regression test, an active invariant probe, and the mutation test.
  - G1-F2 (LOW, documented): funding after `expiry` on a never-reclaimed agreement is permitted; if it latches, every unit is recoverable via T7 + T10. Wasteful but safe; SPEC notes it.
  - G1-F3 (INFO, documented): roles are not required to be distinct (payer may name itself attestor/resolver). Demo uses distinct parties; production needs role-separation governance.
  - G1-F4 (INFO, documented): T8 emits per-line `ObligationExpired` with face amounts while the money returned is `fundedTotal`; `UnfundedReclaimed` is the money-authoritative event for indexers.
  - G1-F5 (INFO, documented): `docHash` may be zero — anchored metadata only, gates nothing.
  - Reviewed-safe: reentrancy surface (nonReentrant + CEI on all token paths; external call last in `fund`, atomically reverted with the outer tx on failure; USDC has no transfer hooks); `locked` underflow impossible (each obligation terminalizes exactly once, Σ amounts == requiredTotal); uint64 deadline arithmetic checked and in-bounds; permissionless `finalizeObligation`/`expireObligation` can only execute objectively-ready transitions and cannot redirect value; duplicate beneficiaries accumulate correctly; cross-agreement isolation via per-agreement ledgers; non-fee-on-transfer token assumption documented (true for USDC).

- Check: Requirement trace
  Result: F-01..F-10 and NF-01..NF-05 fully implemented and tested — NF-01 conservation now proven by invariant campaigns over unbounded action sequences, NF-05 depth met (happy path, partial/over-funding, duplicate attestation, challenge boundaries, rounding-free splits, expiry, blocked recipient, dispute splits, fuzz + invariants).
  Notes: F-11..F-14 belong to Phase 003/004.

- Check: Model-routing record (per MODEL-POLICY.md rule 5)
  Result: Steps 1–8/10/11 ran on Opus 4.8 (Medium) as planned; step 9 and Gate G1 ran on Fable 5 (High) as planned. The High-tier pass changed the outcome: it found and fixed G1-F1, which the Medium-tier unit suite had not surfaced.

## Residual Risk

- Risk: Testnet prototype is unaudited by a third party and must not hold real value.
  Owner: Founder.

- Risk: Resolver liveness — a Challenged obligation waits indefinitely for its resolver (documented SPEC limitation, accepted for MVP).
  Owner: Phase 006 production discovery.

- Risk: CI uses Foundry `stable`; if a future stable release changes `forge fmt` output, the format check could drift from the locally pinned v1.7.1.
  Owner: Phase 004 (pin the CI toolchain version if drift appears).
