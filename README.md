# ParcFi

Programmable settlement for freight-invoice exceptions.

> Release the undisputed line items immediately; hold only the disputed exceptions in programmable USDC escrow.

## Status

Planning complete. This repository is a minimal scaffold for the Arc Programmable Money Hackathon. The initial implementation targets Arc Testnet and synthetic data only.

## Repository layout

- `apps/web` — future Next.js demo application.
- `contracts` — future Foundry Solidity project for the settlement contract.
- `packages/shared` — shared ABI, types, and fixture definitions.
- `.planning` — GSD project memory, research, requirements, roadmap, and phase plans.

## Product boundary

ParcFi settles freight-service invoice obligations. It does not transfer goods, issue electronic bills of lading, or claim production readiness.

## Next step

Execute Phase 001 in `.planning/phases/001-initial-phase/PLAN.md`.

