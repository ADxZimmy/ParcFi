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

1. Scaffold the web app and shared contract types/ABI.
2. Build wallet onboarding and network/balance guards.
3. Deploy the verified bytecode through Circle Contracts; record address and transaction.
4. Build the seeded invoice overview with per-line state.
5. Implement fund/approve, attest, dispute, finalize, claim, resolve, and refund actions.
6. Add transaction receipts, explorer links, and human-readable errors.
7. Add a one-click demo reset/seed strategy that does not mutate production-like records.
8. Complete the first eight customer/problem interviews and summarize quantified evidence, contradictions, and product changes without blocking the demo build.
9. Execute the golden path from fresh wallets and update verification artifacts.

## Verification

- Check: Typecheck, lint, unit tests, and production build
  Expected: Pass.
- Check: Arc explorer
  Expected: Contract and every golden-path transaction are publicly verifiable.
- Check: Fresh-session UAT
  Expected: Golden path completes in under five minutes without manual contract calls.

## Rollback

If modular-wallet integration is unstable by 2026-08-02, use a supported Circle user-controlled wallet flow or an external EVM wallet for interaction while retaining Circle Contracts deployment. Surface the limitation honestly.
