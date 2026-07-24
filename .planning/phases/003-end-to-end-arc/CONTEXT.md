# Context

## Goal

Turn the verified contract into a complete Arc Testnet product demo using Circle Wallets and Circle Contracts.

## Decisions

- Use synthetic fixture data and hashes only.
- Favor a deterministic seeded demo over a general invoice builder.
- User-controlled modular wallets sign user actions.
- A developer-controlled wallet is limited to testnet deployment/admin roles.
- Contract events are the primary read model for the demo.

## Risks

- Risk: Wallet onboarding consumes the schedule.
  Mitigation: Prove one wallet path first and retain a standard viem test wallet as a developer fallback.
- Risk: Circle API credentials leak.
  Mitigation: Server-only environment variables, redacted logs, `.env.example`, and secret scanning.
- Risk: Event indexing becomes a backend project.
  Mitigation: Query bounded agreement events directly; no custom indexer for the hackathon.
- Risk: Demo wallets run out of Arc Testnet USDC or gas during rehearsal or judging.
  Mitigation: Scripted faucet/refill procedure, Gas Station sponsorship for user operations, and one pre-funded backup wallet.
- Risk: Interviews slip behind the build.
  Mitigation: Interviews never block demo work; if fewer than eight complete by the freeze, all commercial claims stay hypothesis-labeled.
