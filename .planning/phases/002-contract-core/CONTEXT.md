# Context

## Goal

Implement and verify the smallest safe contract that proves invoice-line exception isolation.

## Relevant Files

- Path: `contracts/src/ParcFiEscrow.sol`
  Why it matters: Core settlement state and accounting.
- Path: `contracts/test/`
  Why it matters: Unit, negative-path, and invariant coverage.
- Path: `.planning/REQUIREMENTS.md`
  Why it matters: F-01 through F-10 and NF-01 through NF-05 are the acceptance contract.

## Decisions

- One agreement contains a bounded set of independent obligations.
- Agreement status is derived; each obligation owns its lifecycle.
- Finalization credits internal claimable balances; recipients pull funds.
- Evidence is a hash plus typed metadata, never a document body.
- App Kit, wallets, and UI are excluded until the core invariants pass.

## Risks

- Risk: Funds can become stuck through state or arithmetic errors.
  Mitigation: Model conservation explicitly and use invariant/fuzz tests.
- Risk: One malicious beneficiary can block settlement.
  Mitigation: Never call beneficiaries during release; isolate withdrawal.
- Risk: Admin/resolver power is too broad.
  Mitigation: Explicit roles, immutable agreement authorities where practical, events, and tests for every unauthorized path.
