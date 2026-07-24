# Plan

## Outcome

A reviewer can complete the three-line invoice scenario in a polished web app against a public ParcFi contract on Arc Testnet.

Target: 2026-08-04.

## Scope

Included:

- Next.js UI and server routes.
- Circle modular wallet onboarding/signing.
- Custom contract deployment through Circle Contracts.
- Arc Testnet USDC funding, attestation, challenge, release, claims, resolution, and explorer links.
- Transaction pending/success/failure states.

Excluded:

- Real document upload, production database/indexer, FX, compliance engine, and cross-chain flow.

## Steps

1. Scaffold the web app and shared contract types/ABI, and extend CI with typecheck, lint, unit tests, and production build.
2. Build wallet onboarding and network/balance guards.
3. Fund demo wallets: obtain Arc Testnet USDC from the faucet, confirm Gas Station sponsorship covers user-controlled wallet operations, and document the refill procedure plus one pre-funded backup wallet.
4. Deploy the verified bytecode through Circle Contracts; record address and transaction.
5. Build the seeded invoice overview with per-line state.
6. Implement fund/approve, attest, dispute, finalize, claim, resolve, and refund actions.
7. Add transaction receipts, explorer links, and human-readable errors.
8. Add a one-click demo reset/seed strategy that does not mutate production-like records.
9. Complete the first eight customer/problem interviews and summarize quantified evidence, contradictions, and product changes without blocking the demo build; if fewer than eight are done by the Phase 004 feature freeze, proceed anyway and keep every commercial claim hypothesis-labeled per `PROJECT.md`.
10. Execute the golden path from fresh wallets and update verification artifacts.

## Model Routing

Per `.planning/MODEL-POLICY.md`. High = Fable 5, Medium = Opus 4.8, Low = Sonnet 5/Haiku 4.5.

| Steps | Tier | Why |
|---|---|---|
| 2, 4–10 | Medium | Wallet onboarding, Circle Contracts deployment, UI actions, receipts/errors, demo seeding, interview synthesis, and the golden-path run are integration work against a verified contract and documented APIs. |
| 1, 3 | Low | Web app and shared-package scaffolding plus CI wiring; faucet funding and refill documentation are operational steps. |

Escalation: any funds-flow discrepancy, authorization surprise, or wallet-signing ambiguity goes to High before a workaround is coded. If interview evidence contradicts the wedge, the product decision (not the summary) is made on High.

## Verification

- Check: Typecheck, lint, unit tests, and production build
  Expected: Pass locally and in CI.
- Check: Demo wallet funding
  Expected: Every demo wallet holds sufficient Arc Testnet USDC, operations are gas-sponsored or funded, and the refill procedure plus backup wallet are documented.
- Check: Arc explorer
  Expected: Contract and every golden-path transaction are publicly verifiable.
- Check: Fresh-session UAT
  Expected: Golden path completes in under five minutes without manual contract calls.

## Rollback

If modular-wallet integration is unstable by 2026-08-02, use a supported Circle user-controlled wallet flow or an external EVM wallet for interaction while retaining Circle Contracts deployment. Surface the limitation honestly.
