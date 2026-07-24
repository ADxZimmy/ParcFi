# Model Routing Policy

Added: 2026-07-24

Purpose: every phase plan states which AI model tier executes each step, so reasoning depth matches task difficulty and tokens are spent where they buy correctness instead of everywhere.

## Tiers

| Tier | Model | Model ID | Use for |
|---|---|---|---|
| High | Claude Fable 5 | `claude-fable-5` | Open-ended design, money/security-critical reasoning, invariant design, adversarial review |
| Medium | Claude Opus 4.8 | `claude-opus-4-8` | Implementation against a locked spec, integrations, UI, docs, tests from a defined matrix |
| Low (optional) | Claude Sonnet 5 or Haiku 4.5 | `claude-sonnet-5` / `claude-haiku-4-5-20251001` | Mechanical edits, scaffolding, formatting, running recorded commands, record-keeping |

Defaults:

- Run working sessions on Opus 4.8; switch to Fable 5 only for steps tagged High and for the review gates below.
- The Low tier is an optimization, not a requirement. If unavailable, or if a Low task turns out to need judgment, do it on Medium. Never downgrade a High task silently.
- Long mechanical stretches on Opus 4.8 may use fast mode; never use fast mode for contract-code review.

## Routing Rules

1. Each phase `PLAN.md` tags its steps in a `## Model Routing` section. The tag is the default for that step, chosen by reasoning depth, not importance.
2. Escalate one tier when a step fails twice, produces contradictory results, or surfaces any ambiguity in funds accounting, authorization, or state transitions. Anything that changes who can move money is High.
3. De-escalate freely for mechanical follow-through inside a High step (renames, formatting, re-running tests).
4. Design on High, type on Medium: money-state logic in `ParcFiEscrow.sol` is specified and reviewed on Fable 5 even when the code is written on Opus 4.8.
5. Record a tier escalation and its trigger in the phase `VERIFICATION.md` notes if it changed the outcome.

## Review Gates (always Fable 5, high reasoning effort)

- G1 — Phase 002 close: review the full contract source and invariant suite against NF-01 through NF-05 before Phase 003 builds on it.
- G2 — Phase 004 step 1: the security, authorization, dependency, and secret review.
- G3 — Pre-submission: review deck and README claims against the honest-labeling agreements in `PROJECT.md` (testnet-only, no atomicity claims, hypotheses labeled as hypotheses).

## Rationale

Fable 5 buys the most where mistakes are subtle or irreversible: escrow state machines, conservation invariants, dispute edge cases, and the final claims audit. Opus 4.8 is strong and cheaper for spec-following work, which is most of the build by volume. The split concentrates the expensive model on the ~15% of steps where its marginal quality prevents fund-loss bugs or a discrediting pitch claim.
