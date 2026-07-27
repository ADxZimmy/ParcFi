# ParcFi

## Mission

Help freight counterparties settle the undisputed parts of a multi-party invoice immediately while keeping only genuine exceptions in a transparent, recoverable hold.

Working pitch:

> ParcFi turns each freight invoice line into an independently settleable USDC obligation. Clean charges are released; disputed charges stay protected without freezing every other payee.

## Audience

Primary beachhead hypothesis:

- Small and mid-market freight forwarders that coordinate shippers, carriers, terminals, and brokers across borders.
- Their finance and operations teams, which need faster reconciliation without surrendering control of disputed charges.

Counterparties:

- Shippers or importers funding an agreement.
- Carriers, forwarders, terminals, customs brokers, and other service providers claiming approved line items.
- A mutually appointed resolver for exceptional disputes.

The buyer, corridor, and willingness to pay remain hypotheses until customer interviews validate them.

## Product Boundary

ParcFi settles freight-service invoice obligations. It is not:

- An electronic bill of lading platform.
- A transfer-of-title system.
- A payment rail for the underlying goods.
- A letter-of-credit replacement.
- A generic stablecoin wallet or remittance product.

## System Shape

- Runtime: Node.js 22+ and Solidity 0.8.x.
- Web: Next.js with TypeScript and viem.
- Contracts: Foundry-tested custom Solidity contracts deployed to Arc Testnet through Circle Contracts.
- Wallets: Circle user-controlled modular wallets for users; one developer-controlled wallet only for testnet deployment/administration.
- Money: Arc Testnet USDC through its 6-decimal ERC-20 interface.
- Data: Contract events are the settlement source of truth; documents remain offchain and only content hashes/typed metadata are anchored.
- Optional liquidity path: Arc App Kit Bridge for one asynchronous USDC funding/withdrawal route.
- Deployment: Public web demo plus verified Arc Testnet contract and public source repository.

## Constraints

- Hackathon Checkpoint 2 is due 2026-07-27 12:59 WAT (corrected 2026-07-27 from the live form; previously assumed 2026-07-26); final submission is due 2026-08-09 Anywhere on Earth. Internal final deadline: 2026-08-08 18:00 WAT.
- Arc is currently public testnet; mainnet and production addresses are not yet public.
- Arc privacy is not available. Amounts, addresses, and contract state are public.
- The MVP must use test assets and synthetic freight documents only.
- Cross-chain transfers are asynchronous and must never be described as globally atomic.
- Compliance Engine and StableFX require eligibility/access and cannot be critical-path dependencies.
- Legal, licensing, custody, sanctions, data-protection, and dispute-enforcement questions remain before real-money use.
- Quality of one complete settlement flow takes priority over integrations and breadth.

## Working Agreements

- DeFi track only unless real agent autonomy becomes core to the product; do not add an AI wrapper.
- Keep a maximum of three critical Circle integrations: Arc/USDC, Circle Wallets, and Circle Contracts. App Kit Bridge is a stretch feature.
- Keep the contract state machine explicit, bounded, and testable.
- Use pull-based beneficiary claims so one blocked or failing recipient cannot freeze others.
- Keep documents and PII offchain; anchor hashes only.
- Preserve six-decimal application accounting and never compare it directly with Arc's 18-decimal native gas representation.
- Treat unvalidated commercial numbers as hypotheses, not pitch facts.
- Route AI-assisted work by reasoning depth per `.planning/MODEL-POLICY.md`: Fable 5 for high-reasoning and money/security-critical steps and review gates, Opus 4.8 for spec-following implementation, an optional light tier for mechanical work.
- Update `STATE.md` after meaningful execution or verification.
