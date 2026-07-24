# UAT

## Scenario

A payer opens the seeded invoice, funds USDC, observes three obligations, challenges demurrage, and watches the carrier and terminal claim the other two obligations independently. A resolver settles the final exception.

## Result

Pass on local anvil via the real browser UI (2026-07-24). The full scenario ran with role switching: fund $10,000 → attest ×3 → dispute only demurrage → clean lines released after their windows → carrier claimed $7,500 and terminal claimed $1,500 while the dispute was still open → resolver split 60/40 → forwarder claimed $600, payer withdrew $400. Agreement ended "Settled" with locked $0 and every dollar accounted for in the UI.

Not yet run on Arc Testnet (needs founder-side deployment + funded wallets; steps in `apps/web/README.md`).

## Notes

For the demo video: the moment worth showing is the "Disputed" agreement with $9,000 already claimable — the dispute quarantines $1,000 without freezing anyone else. Capture Arcscan URLs once the Arc run happens; on Arc the 120-second windows run in real time (fits a 3-minute video with one cut).
