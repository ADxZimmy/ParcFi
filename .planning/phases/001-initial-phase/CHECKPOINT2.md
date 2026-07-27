# Checkpoint 2 Submission

Deadline correction 2026-07-27: the live submission form shows **Monday, July 27, 2026, 12:59 PM (Africa/Lagos)** — not Sunday the 26th as first planned. Form fields: Link to Code (required), Link to Presentation (required — "Google Slides, DocSend, Canva"), track selection (DeFi / Agentic Economy, multi-select).

Confirmed requirement (hackathon FAQ): "A mid-hackathon progress update with your repo and presentation links." Checkpoints 1 and 2 may be placeholders/works-in-progress; only the final checkpoint must be complete.

Presentation deck: `docs/ParcFi-Checkpoint2.pptx` (10 slides, built 2026-07-27). To get a link: upload to Google Drive → Open with Google Slides → Share → "Anyone with the link: Viewer" → copy link.

## Founder actions (in order)

1. Log in to the Encode project page (create the project if Checkpoint 1's "create your project, add your team, share your idea" was never done — placeholders are acceptable).
2. Select the **DeFi track**. (Multi-track entry is allowed only if the project genuinely meets each track's requirements — ParcFi does not claim the Agentic track.)
3. Paste the progress update below, add the repo link, and use the repo README as the presentation link unless a deck exists by then.
4. Submit, screenshot the confirmation, save it outside the repo, and update `STATE.md`.

## Paste-ready progress update

---

**ParcFi — release the clean lines, hold only the exceptions.**

One disputed demurrage line should not freeze every legitimate payee. ParcFi turns each line item of a multi-party freight invoice into an independently settleable USDC obligation on Arc: attested, unchallenged charges finalize and are claimed per-beneficiary via pull payments, while a disputed charge is quarantined — money conserved — until a mutually appointed resolver splits, releases, or refunds just that line.

**Progress since kickoff:**

- Deep validation research: hackathon brief, Arc/Circle capability verification, competitive landscape (CargoBill, CargoEscrow, PayCargo, freight-audit platforms, CargoX×Standage), DCSA invoicing-standard evidence, compliance risk map. We rejected our broader "stablecoin freight payments" concept as underdifferentiated and narrowed to invoice-exception settlement.
- Full contract specification committed: roles, per-obligation state machine (`Pending → Attested → Challenged|Finalized → Resolved/Expired`), transition table, conservation invariants, events, custom errors, bounds (`contracts/SPEC.md`) plus the complete Solidity interface (`IParcFiEscrow.sol`).
- Foundry scaffold with the golden-path scenario named as tests: a synthetic $10,000 invoice — $7,500 base freight, $1,500 port handling, $1,000 demurrage — where only demurrage is disputed, the carrier and terminal claim independently, and the resolver later splits demurrage 60/40.
- Architecture locked: Arc Testnet USDC (6-decimal ERC-20 interface), Circle user-controlled modular wallets, custom deployment through Circle Contracts, Next.js + viem, events as the settlement source of truth. Arc App Kit Bridge is a stretch feature, not a dependency.
- Public repository with research, requirements (14 functional, 9 non-functional), phased plan, and honest testnet-only limitations: **[REPO LINK]**

**Next two milestones:**

1. 2026-07-30 — contract core complete: Foundry unit, fuzz, and invariant suites prove value conservation, obligation isolation, and every authorized/unauthorized transition.
2. 2026-08-04 — end-to-end demo on Arc Testnet: Circle wallet onboarding, Circle Contracts deployment, funding → attestation → challenge → independent claims → resolution, with explorer links throughout.

Everything demoed is testnet-only with synthetic data; commercial hypotheses are being tested in parallel through customer interviews and are labeled as hypotheses until then.

---

## Record of submission

- Submitted at: (pending)
- Confirmation screenshot saved: (pending)
