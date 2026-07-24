# State

Last updated: 2026-07-24

## Current Focus

Phase 003 build: the web demo works end-to-end locally (golden path verified in-browser). Remaining: founder-side Circle account + faucet funding, then the Arc Testnet run. Checkpoint 2 submission still due 2026-07-26 18:00 WAT.

## Completed

- Initialized GSD Hybrid planning artifacts.
- Recovered and analyzed the original CargoBill-inspired proposal.
- Researched the hackathon, Arc/Circle capabilities, logistics payment incumbents, freight escrow competitors, eBL law/standards, and compliance risks.
- Rejected the broad "stablecoin freight payments/escrow" concept as insufficiently differentiated.
- Defined the narrower ParcFi wedge: release clean freight invoice lines and hold only disputed exceptions.
- Planned four deadline-driven hackathon phases plus post-hackathon validation gates.
- Initialized Git, created the public GitHub repository, and pushed `main`.
- Re-validated the idea and plan (2026-07-24): independent review concurred with the conditional-go verdict; re-verified Arc/Circle capability and hackathon-brief claims from public sources.
- Added `.planning/MODEL-POLICY.md` and per-phase Model Routing sections (Fable 5 for high-reasoning/security-critical steps and gates G1–G3, Opus 4.8 for spec-following work, optional light tier for mechanical steps).
- Patched three planning gaps (2026-07-24): CI steps in Phases 002/003, interview slip fallback, and explicit demo-wallet USDC/gas funding step.
- Executed Phase 001 repo work (2026-07-24): contract specification (`contracts/SPEC.md`) and full Solidity interface (`IParcFiEscrow.sol`); Foundry scaffold (`foundry.toml`, golden-path test names); synthetic invoice fixture; judge-readable root README (thesis, differentiation table, golden path, architecture, honest limitations); interview kit (`.planning/INTERVIEWS.md`); paste-ready Checkpoint 2 draft (`phases/001-initial-phase/CHECKPOINT2.md`).
- Executed Phase 002 Medium-tier work (2026-07-24, Opus 4.8): installed Foundry v1.7.1; vendored forge-std + OpenZeppelin v5.1.0; implemented `ParcFiEscrow.sol` (T1–T10) against the spec with `SafeERC20`, `ReentrancyGuard`, and checks-effects-interactions; wrote `MockUSDC` (6-decimal, blocklist) and 66 tests (unit, negative-path, boundary, isolation, golden path) — all green; added GitHub Actions CI (`forge fmt`/`build`/`test`), exported the ABI to `packages/shared/abi/`, and recorded `.gas-snapshot`.
- Closed Phase 002 High-tier work (2026-07-24, Fable 5): G1 adversarial review found and fixed G1-F1 (fund-after-reclaim stranded deposits and broke conservation — medium severity) and documented five informational findings in SPEC.md; built the invariant suite (10-actor handler over all T1–T10 with time warping, fail-on-revert, ghost accounting) proving solvency-exact, two-regime conservation, locked-vs-open consistency, and terminal-status stickiness across 128×64 campaigns; added three stateless fuzz properties; proved test power by mutation (guard removed → regression + all 4 campaigns fail; restored → 74/74 green).
- Built Phase 003 machine-side work (2026-07-24): npm workspaces; `@parcfi/shared` (typed ABI, Arc chain config incl. chain id 5042002 / RPC / Arcscan / USDC 0x3600…0000, status derivation, USDC formatting, fixture — 9 unit tests); Next.js demo app (role-switching six demo accounts, per-line statuses with countdowns, fund/attest/dispute/release/resolve/claim/refund actions, event-sourced activity log, explorer links, demo reset, anvil time-skip); deploy scripts (`DeployLocal.s.sol`, `DeployArc.s.sol` fallback; Circle Contracts documented as primary); web CI. Golden path executed in the real browser against anvil: agreement ended Settled with claimed $9,600 + refunded $400 = funded $10,000.

## In Progress

- Founder Encode-account actions for Checkpoint 2: create/confirm the project page (DeFi track), paste the CHECKPOINT2.md update with the repo link, submit, screenshot.
- Scheduling the first two customer interviews from the kit.

## Blocked

- Item: Hackathon registration, project-page access, and team status are not visible in this local workspace.
  Reason: Applying and submitting require the participant's Encode account; the programme page says late applications are still open and registration closes 2026-08-08.
  Update 2026-07-24: FAQ confirms Checkpoints 1 and 2 may be placeholders/works-in-progress and only the final checkpoint must be complete, so the missed Checkpoint 1 is low-risk.

## Next Action

Founder, in order: (1) submit Checkpoint 2 (`CHECKPOINT2.md` — can now claim: contract + 74 tests + security review + working local demo); (2) create the Circle developer account and an Arc Testnet deployer wallet, get faucet USDC (https://faucet.circle.com); (3) deploy via Circle Contracts (blockchain `ARC-TESTNET`, bytecode/ABI from `contracts/out` + `packages/shared/abi`) or run `DeployArc.s.sol` as fallback; (4) generate six burner keys, fund the payer, fill `apps/web/.env.local` per `apps/web/README.md`. Then the next session runs the Arc Testnet golden path and captures Arcscan evidence.

Repository: https://github.com/ADxZimmy/ParcFi
Local toolchain: Foundry v1.7.1 installed at `~/.foundry/bin` (add to PATH: `export PATH="$HOME/.foundry/bin:$PATH"`). Dependencies vendored in `contracts/lib/` (gitignored; re-clone with the two `git clone` commands in the CI workflow).

## Verification Snapshot

- Command/check: init_gsd_hybrid.py
  Result: Planning artifacts created.
- Check: Current official hackathon brief
  Result: Checkpoint 2 is 2026-07-26; final submission is 2026-08-09 AOE; judging rewards Arc/USDC integration, real use case, execution quality, and presentation.
- Check: Current Arc deployment documentation
  Result: Public testnet is live; private/public mainnet are upcoming; mainnet contract addresses are unavailable.
- Check: Current Circle/Arc integration documentation
  Result: Arc Testnet supports custom Circle Contracts deployment, Circle wallets, App Kit Send/Bridge/Swap/Unified Balance, and CCTP standard transfers.
- Check: Competitive scan
  Result: CargoBill, CargoEscrow, PayCargo, freight-audit platforms, and CargoX/Standage invalidate a broad logistics-payment or delivery-escrow differentiation claim.
- Check: External re-verification of load-bearing claims (web, 2026-07-24)
  Result: Arc Testnet live, Circle Contracts custom deployment on Arc, Circle Wallets + Gas Station on Arc Testnet, final submission 2026-08-09, DeFi + Agentic tracks, judging language ("quality of execution over complexity", Circle tools, production viability), and 3-minute video requirement all confirmed. Not publicly verifiable: exact Checkpoint 2 date (behind Encode participant login — confirm from the account) and CargoEscrow's self-reported feature claims. CargoBill confirmed live. Note: Arc docs appear under docs.arc.network as well as docs.arc.io — re-check all README/deck links before submission.
- Check: Checkpoint 2 requirements (participant screenshot of hackathon page, 2026-07-24)
  Result: Checkpoint 2 confirmed as Sunday 26 July — "mid-submission — repository link and progress summary"; FAQ: "a mid-hackathon progress update with your repo and presentation links." Checkpoints 1 and 2 can be placeholders; only the final checkpoint must be complete. Checkpoint 1 (Sunday 19 July) was create-project/add-team/share-idea.
- Command: `forge fmt --check && forge build && forge test` (2026-07-24, Foundry v1.7.1)
  Result: fmt clean; build successful (`via_ir = true`); 66 tests passed, 0 failed, 0 skipped.
- Check: Planning consistency review (2026-07-24)
  Result: Dates, requirement-to-phase traceability (F-01..F-14, NF-01..NF-09 all covered), scope discipline, and rollback paths are consistent. Three gaps found and patched same day: CI steps added (Phase 002 step 11 for the Foundry suite, Phase 003 step 1 extends CI with web checks), the eight-interview target now carries an explicit non-blocking fallback (Phase 003 step 9), and demo-wallet USDC/gas funding is now an explicit step with refill procedure and backup wallet (Phase 003 step 3).
