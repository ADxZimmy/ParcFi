# ParcFi contracts

Foundry project for `ParcFiEscrow` — bounded invoice obligations, per-line challenge windows, independent pull-based claims, dispute splits, expiry, and refunds on Arc Testnet.

- [SPEC.md](SPEC.md) — the acceptance spec: roles, state machine, transition table, accounting invariants, events, errors, bounds.
- [src/interfaces/IParcFiEscrow.sol](src/interfaces/IParcFiEscrow.sol) — the full external interface.
- [test/GoldenPath.t.sol](test/GoldenPath.t.sol) — named golden-path scenario, implemented in Phase 002.

## Setup (Phase 002)

Requires [Foundry](https://getfoundry.sh). `lib/` is gitignored, so install dependencies after cloning:

```bash
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts
```

Then:

```bash
forge fmt --check && forge build && forge test -vvv
```

Phase 002 adds the implementation (`src/ParcFiEscrow.sol`), a 6-decimal mock USDC, malicious-recipient fixtures, and unit/fuzz/invariant suites per `.planning/phases/002-contract-core/PLAN.md`.
