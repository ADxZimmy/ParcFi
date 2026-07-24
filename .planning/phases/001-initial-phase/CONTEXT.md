# Context

## Goal

Lock a differentiated thesis and submit a credible Checkpoint 2 package by 2026-07-26.

## Relevant Files

- Path: `.planning/RESEARCH.md`
  Why it matters: Evidence, competitor analysis, validation score, and falsification gates.

- Path: `.planning/PROJECT.md`
  Why it matters: Stable product boundary and hackathon constraints.

- Path: `.planning/REQUIREMENTS.md`
  Why it matters: Testable MVP behavior and explicit non-goals.

- Path: `README.md`
  Why it matters: Must communicate the thesis, architecture, progress, and setup from the public repository.

- Path: `contracts/`
  Why it matters: Will contain the escrow interface and implementation scaffold.

## Decisions

- Decision: Enter the DeFi track only.
  Reason: The core is conditional payments and multi-step settlement; an AI wrapper would not satisfy real agent autonomy.

- Decision: Settle freight-service invoice line items, not the underlying goods or eBL.
  Reason: This avoids a direct collision with CargoX/Standage and avoids pretending a document hash transfers legal title.

- Decision: Lead with exception isolation.
  Reason: CargoBill and PayCargo move money; CargoEscrow holds shipment funds; freight-audit tools find exceptions. ParcFi's testable difference is releasing undisputed value while quarantining only disputed obligations.

- Decision: Do not full-prefund a multi-week voyage in the MVP story.
  Reason: That creates a working-capital cost that can exceed the payment benefit. Fund at invoice approval or a defined milestone.

- Decision: Circle Wallets + Circle Contracts are critical; App Kit Bridge is optional.
  Reason: They demonstrate meaningful Circle integration without making asynchronous cross-chain behavior a dependency.

## Risks

- Risk: The idea remains adjacent to CargoEscrow's self-described milestone and dispute features.
  Mitigation: Show line-level partial settlement, bounded exception states, independent claims, and DCSA-invoice alignment in the first 30 seconds.

- Risk: Checkpoint 1 has already passed.
  Mitigation: The programme still accepts applications; create the project now and make Checkpoint 2 exceptionally concrete.

- Risk: No customer evidence before the final.
  Mitigation: Run eight focused interviews in parallel with implementation and label all commercial claims honestly.

- Risk: Scope exceeds the remaining time.
  Mitigation: One synthetic invoice, three obligations, one dispute, two claims, one resolution. Everything else is a stretch.
