# Plan

## Outcome

A public, judge-readable project page and repository that make the differentiated thesis, Arc architecture, implementation progress, and final-demo plan credible by 2026-07-26 18:00 WAT.

## Scope

Included:

- Encode application/project page, DeFi track selection, team details.
- Working pitch, competitor distinction, problem evidence, architecture, contract interface/invariants, public repo scaffold, and progress summary.
- A single golden-path demo script.

Excluded:

- Production UI, completed contract, real integrations, real freight data, token economics, AI agents, and real-money claims.

## Steps

1. Create/apply to the Encode project and confirm Checkpoint 2 submission access.
2. Publish this one-sentence thesis: "ParcFi releases the undisputed line items of a freight invoice immediately and holds only the exceptions in programmable USDC escrow."
3. State the boundary: freight-service invoices, not goods payment, title transfer, or eBL issuance.
4. Create the public repository with a concise README, architecture diagram, source links, roadmap, and honest testnet disclaimer.
5. Scaffold `apps/web`, `contracts`, and `packages/shared` without adding nonessential infrastructure.
6. Specify the contract roles, states, events, custom errors, invariants, maximum obligation count, and Arc USDC interface.
7. Add a minimal Foundry test scaffold with the golden-path scenario named, even if Phase 002 completes the implementation.
8. Build an interview list and schedule the first two calls; ask about the most recent disputed invoice rather than pitching blockchain.
9. Submit the repository link and a progress summary that names completed research, architecture, and the next two milestones.
10. Save a screenshot/copy of the submitted checkpoint and update `STATE.md`.

## Model Routing

Per `.planning/MODEL-POLICY.md`. High = Fable 5, Medium = Opus 4.8, Low = Sonnet 5/Haiku 4.5.

| Steps | Tier | Why |
|---|---|---|
| 6 | High | The contract specification (roles, states, events, errors, invariants, obligation bound, USDC interface) is the design decision every later phase builds on. |
| 2, 3, 4, 7, 9 | Medium | Judge-facing copy, README/architecture, test scaffold, and progress summary follow decisions already made in research. |
| 1, 5, 8, 10 | Low | Account/admin actions (founder-driven; model drafts text only), directory scaffolding, interview-list assembly, record-keeping. |

Escalation: if step 6 surfaces a state-machine ambiguity, resolve it on High before drafting any dependent copy.

## Verification

- Check: Project page
  Expected: DeFi track selected, pitch is visible, and checkpoint submission is accepted.

- Check: Public repository
  Expected: An unauthenticated reader can open it and understand problem, differentiation, Arc use, scope, architecture, and schedule in under two minutes.

- Check: Contract specification
  Expected: Every money state transition and authority is explicit; no eBL-oracle or global-atomicity claim remains.

- Check: Scope review
  Expected: The golden path contains exactly one payer, one attestor, one resolver, three obligations, one dispute, and two independent claims.

## Rollback

If registration is unavailable or mentors reject the logistics overlap, keep the settlement engine chain-agnostic and reposition the demo as a general B2B invoice-exception primitive. Do not spend time renaming the contract before the core tests pass.
