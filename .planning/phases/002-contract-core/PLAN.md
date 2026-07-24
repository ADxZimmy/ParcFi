# Plan

## Outcome

A Foundry test suite proves that clean obligations finalize and pay independently while disputed value remains conserved and recoverable.

Target: 2026-07-30.

## Scope

Included:

- Custom errors, events, roles, obligation states, funding, attestation, challenge, finalization, claims, dispute split, expiry, and refund.
- Mock six-decimal USDC and malicious/reverting recipient fixtures.
- Unit, fuzz, and invariant tests.

Excluded:

- UI, Circle SDKs, CCTP, real oracles, upgradeability, fees, and production governance.

## Steps

1. Write the contract interface and state/accounting table before implementation.
2. Implement bounded agreement/obligation creation and funding with `SafeERC20`.
3. Implement unique evidence attestations and challenge deadlines.
4. Implement independent finalization into claimable balances.
5. Implement beneficiary pull claims with reentrancy protection.
6. Implement resolver split and payer refund credits.
7. Implement expiry rules and surplus refund.
8. Add unit tests for every authorized and unauthorized transition.
9. Add fuzz/invariant tests for value conservation, no double claim/refund, and obligation isolation.
10. Generate ABI and record gas snapshots.
11. Add GitHub Actions CI that runs `forge fmt --check`, `forge build`, and the full test suite on every push; keep it green from the first commit.

## Model Routing

Per `.planning/MODEL-POLICY.md`. High = Fable 5, Medium = Opus 4.8, Low = Sonnet 5/Haiku 4.5.

| Steps | Tier | Why |
|---|---|---|
| 1, 9 | High | The interface/state/accounting table and the fuzz/invariant design (value conservation, no double claim/refund, obligation isolation) are where subtle fund-loss bugs are prevented or created. |
| 2–8 | Medium | Implementation and unit tests against the locked step-1 spec and a defined transition matrix. |
| 10, 11 | Low | ABI generation, gas-snapshot recording, and CI workflow setup. |

Gate G1: before closing this phase, a Fable 5 review of the full contract source and invariant suite against NF-01 through NF-05. Any accounting or authorization ambiguity found during steps 2–8 escalates to High immediately.

## Verification

- Check: `forge fmt --check`
  Expected: Pass.
- Check: `forge build`
  Expected: Pass without warnings that affect safety.
- Check: `forge test -vvv`
  Expected: All unit and negative-path tests pass.
- Check: `forge test --match-path 'test/invariant/*'`
  Expected: Conservation and isolation invariants hold.
- Check: GitHub Actions
  Expected: The Foundry workflow passes on `main`.

## Rollback

If dispute splitting makes the model unstable, restrict resolution to a binary payer/payee outcome for the hackathon and document proportional splits as post-hackathon work.
