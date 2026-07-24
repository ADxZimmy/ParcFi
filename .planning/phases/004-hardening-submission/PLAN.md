# Plan

## Outcome

A public, reproducible Arc Testnet MVP, three-minute video, deck, and final submission are complete by 2026-08-08 18:00 WAT.

## Scope

Included:

- Security review, negative-path UAT, accessibility/responsive polish, documentation, deployment, optional bridge, deck, video, and submission.

Excluded:

- New product features after feature freeze.

## Steps

1. Run dependency, secret, contract-security, and authorization reviews.
2. Execute all automated checks and every requirement trace.
3. Test duplicate attestation, partial/over-funding, expiry, deadline boundaries, malicious recipient, and failed/retried transactions.
4. Decide the App Kit Bridge feature at the freeze; remove it if incomplete.
5. Deploy the final web build and verify from a clean browser/session.
6. Write the README quickstart, architecture, contract address, limitations, and production path.
7. Build a concise deck: problem, wedge, demo, Arc advantage, evidence, architecture, risks, next validation.
8. Record a 165–175 second demo and verify audio, legibility, and public access.
9. Submit by the internal deadline and capture proof.
10. Update `STATE.md`, verification, and UAT with exact results and residual risks.

## Model Routing

Per `.planning/MODEL-POLICY.md`. High = Fable 5, Medium = Opus 4.8, Low = Sonnet 5/Haiku 4.5.

| Steps | Tier | Why |
|---|---|---|
| 1 | High | Gate G2: the security, authorization, dependency, and secret review runs on Fable 5 at high reasoning effort. |
| 2–7 | Medium | Check execution, requirement tracing, negative-path UAT, the pre-criteria'd bridge freeze decision, deployment, README, and deck drafting. |
| 8, 9, 10 | Low | Video recording logistics, submission mechanics, and state updates. |

Gate G3: before submitting, a Fable 5 pass over the deck and README claims against the honest-labeling agreements in `PROJECT.md`. Any UAT failure that touches funds accounting escalates to High.

## Verification

- Check: Fresh clone
  Expected: Documented setup and checks work without local hidden state.
- Check: Full CI/local suite
  Expected: All critical checks pass.
- Check: Public deployment
  Expected: Golden path works from an unauthenticated browser with test wallets.
- Check: Submission package
  Expected: Repository, Arc deployment, deck, and video links are public and final form is accepted.

## Rollback

Disable bridge and nonessential animations first. If live transaction reliability is poor, keep a pre-seeded onchain agreement plus one live claim transaction; never replace the working prototype with a video-only mock.
