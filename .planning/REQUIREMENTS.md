# Requirements

## Functional

- F-01 Agreement creation:
  Acceptance: A payer can create an agreement with a unique ID, invoice/document hash, payer, attestor, resolver, expiry, and bounded set of line-item obligations.

- F-02 Line-item obligations:
  Acceptance: Each obligation records a beneficiary, USDC amount, evidence requirement, challenge duration, and independent status.

- F-03 USDC funding:
  Acceptance: A payer can fund the agreement with Arc Testnet USDC; the UI distinguishes required, funded, allocated, claimable, disputed, and refundable amounts.

- F-04 Evidence attestation:
  Acceptance: Only an authorized attestor can submit a typed evidence hash for an obligation, and the same attestation cannot be replayed.

- F-05 Challenge window:
  Acceptance: Attestation starts a visible challenge deadline; the payer can dispute only the affected obligation before that deadline.

- F-06 Partial release:
  Acceptance: After the challenge period, each undisputed obligation can be finalized without waiting for disputed or unrelated obligations.

- F-07 Pull-based claims:
  Acceptance: Finalization credits a beneficiary's claimable balance; each beneficiary withdraws independently and one failed withdrawal does not revert another beneficiary's entitlement.

- F-08 Dispute resolution:
  Acceptance: The appointed resolver can split, release, or refund a disputed line item without changing already-finalized obligations.

- F-09 Expiry and refund:
  Acceptance: Unallocated or unreleased funds become refundable under an explicit expiry/timeout rule, with no double-spend path.

- F-10 Audit trail:
  Acceptance: Agreement creation, funding, attestation, challenge, resolution, finalization, claim, and refund emit indexed events visible in the UI.

- F-11 Wallet onboarding:
  Acceptance: Demo users can create/connect a Circle user-controlled wallet and approve/sign required Arc Testnet transactions.

- F-12 Circle Contracts deployment:
  Acceptance: The custom escrow bytecode and ABI are deployed or imported through Circle Contracts and the public Arc explorer URL is recorded.

- F-13 End-to-end demo:
  Acceptance: A scripted synthetic shipment releases base freight and port fees, holds a disputed demurrage charge, allows two beneficiaries to claim independently, then resolves the exception.

- F-14 Optional App Kit route:
  Acceptance: If completed by the feature cutoff, one USDC bridge flow to or from Arc Testnet shows explicit source, attestation, mint, success, failure, and retry states. The core settlement works when it is disabled.

## Non-Functional

- NF-01 Accounting invariants:
  Acceptance: Tests prove `cumulative funded = locked + claimable + refundable + cumulative claimed + cumulative refunded`; the contract balance equals `locked + claimable + refundable`; all amounts use the USDC 6-decimal interface.

- NF-02 Authorization:
  Acceptance: Unauthorized funding administration, attestation, challenge, resolution, finalization, and withdrawal attempts revert.

- NF-03 Smart-contract safety:
  Acceptance: Use `SafeERC20`, reentrancy protection, checks-effects-interactions, replay protection, explicit role controls, and no unbounded external-call loops.

- NF-04 Bounded complexity:
  Acceptance: An agreement has a documented maximum obligation count and every state transition has a predictable gas bound.

- NF-05 Test depth:
  Acceptance: Unit and invariant tests cover the happy path, partial/over-funding, duplicate attestations, challenge boundaries, rounding, expiry, malicious recipient, and dispute splits.

- NF-06 Privacy:
  Acceptance: No invoice body, customer name, address, commercial terms, credentials, or PII is written onchain or committed to the repository.

- NF-07 Accessibility and clarity:
  Acceptance: Every financial action previews amount, beneficiary, state change, network, and transaction status; error states do not require reading a block explorer.

- NF-08 Observability:
  Acceptance: The demo records contract address, chain ID, transaction hashes, Circle transaction IDs where applicable, and clear retryable/non-retryable errors.

- NF-09 Demo reliability:
  Acceptance: A fresh reviewer can complete the golden-path demo from the README in under five minutes using test assets.

## Out Of Scope

- Payment for the underlying merchandise or transfer of cargo title/eBL control.
- Legal recognition of electronic bills of lading.
- Production custody, fiat on/off-ramps, lending, factoring, insurance, or FX hedging.
- JPYC, Nanopayments, Gateway, StableFX, privacy claims, or autonomous AI agents.
- Globally atomic cross-chain settlement.
- Real-world oracle integrations, GPS/IoT feeds, or claims that an uploaded PDF proves delivery.
- Production KYB/KYC, sanctions screening, Travel Rule messaging, or regulatory licensing.
- Multi-jurisdiction commercial launch during the hackathon.

## Open Questions

- Which beachhead feels the pain most: freight forwarders, shipper AP teams, or carriers?
  Status: Validate through at least eight interviews; do not infer from desk research.

- Do current systems freeze an entire invoice when one accessorial line is disputed?
  Status: Public evidence says exception queues delay payment, but workflow frequency and dollar impact need interviews.

- When should funds enter the contract: booking deposit, milestone, invoice approval, or only after an exception?
  Status: Recommend invoice/milestone funding for the MVP; test alternatives with users.

- Who can credibly attest and who resolves disputes?
  Status: Use explicit demo roles; production governance remains unresolved.

- Will a payer pre-fund, or will the payee pay for accelerated release?
  Status: Pricing and working-capital hypothesis only.

- Does the target operating model make ParcFi a VASP, money transmitter, escrow agent, or custodian in the chosen corridor?
  Status: Requires corridor-specific counsel and licensed-partner analysis before real funds.

- Is App Kit Bridge worth the demo risk?
  Status: Include only if the core flow is green by 2026-08-03.
