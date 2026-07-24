# Context

## Goal

Make the product reliable, legible to judges, and submitted one day before the internal deadline.

## Decisions

- Feature freeze: 2026-08-05 18:00 WAT.
- App Kit Bridge ships only if the complete core remains green and the bridge flow works by the freeze.
- Demo uses one rehearsed scenario; negative paths live in tests/UAT, not the three-minute pitch.
- Submission language says testnet prototype and production path, never production-ready.

## Risks

- Risk: A late integration breaks the demo.
  Mitigation: Feature flag and remove it at the first core regression.
- Risk: Video exceeds time or obscures the value.
  Mitigation: Script to 165 seconds and reserve 15 seconds.
- Risk: Public repo leaks secrets or private freight data.
  Mitigation: Synthetic data, secret scan, dependency/security review, and fresh clone test.
