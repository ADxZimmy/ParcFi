# Verification

## Automated Checks

- Command: `npm run typecheck && npm run lint && npm run test && npm run build`
  Result: Pass (2026-07-24). Typecheck clean in both workspaces; eslint clean; 9 shared unit tests green; production build outputs a static route at 204 kB first-load JS.
  Notes: Node 24.4.1, npm 11.9.0, Next 15.4.x, viem 2.x. Web CI added (`.github/workflows/web.yml`).
- Command: Contract integration tests
  Result: Covered by the Phase 002 suite (74 tests incl. invariants); the web app consumes the generated ABI from `packages/shared/abi/`.
  Notes: ABI is generated, not hand-written; regeneration command in `packages/shared/README.md`.

## Manual Checks

- Check: Golden path in the browser against local anvil (2026-07-24)
  Result: Pass, executed end-to-end via the real UI: create agreement → approve + fund $10,000 → attest ×3 (role-gated to attestor) → dispute only demurrage (payer) → challenge windows elapse → release both clean lines (permissionless) → carrier claims $7,500 and terminal claims $1,500 independently while the dispute is open → resolver splits demurrage 60/40 → forwarder claims $600 → payer withdraws $400. Final UI state: agreement "Settled", locked $0, claimed $9,600 + refunded $400 = funded $10,000; 17-event activity log with tx hashes; role gating verified (buttons disabled with switch-role hints for wrong roles).
  Notes: Countdown timers, derived agreement status (Awaiting funding → Active → Disputed → Settled), and balance strip all updated live. The local-only ⏩ time-skip button exists but was not needed — windows elapsed naturally during the walkthrough.

- Check: Fresh-wallet golden path on Arc Testnet
  Result: Not run — founder-gated. Requires: (1) escrow deployed to Arc Testnet (Circle Contracts primary, `DeployArc.s.sol` fallback), (2) six fresh burner keys in `NEXT_PUBLIC_DEMO_KEYS`, (3) payer funded from https://faucet.circle.com. Steps documented in `apps/web/README.md`.
  Notes: Explorer links are wired (Arcscan) and appear automatically when `NEXT_PUBLIC_NETWORK=arc`.

- Check: Circle wallet onboarding (F-11) and Circle Contracts deployment record (F-12)
  Result: Not run — requires the founder's Circle developer account (`CIRCLE_API_KEY`/`CIRCLE_APP_ID`, server-side only). Config surface reserved in `.env.example`; the plan's rollback (external/burner wallet flow while retaining Circle Contracts deployment) is the currently working path.

## Residual Risk

- Risk: Third-party testnet services can be slow or rate-limited.
  Owner: Founder.
- Risk: Demo roles are client-side burner keys (testnet throwaways, clearly labeled). Acceptable for the hackathon demo; Circle user-controlled wallets are the production onboarding story and remain unintegrated until credentials exist.
  Owner: Founder (Circle account) + next build session.
- Risk: The event log reads from `NEXT_PUBLIC_START_BLOCK` (default 0). On Arc the founder must set the deploy block or queries may be slow/rate-limited.
  Owner: Documented in README env table.
