# ParcFi web app

Next.js demo for the three-line invoice golden path: fund → attest → dispute one line → release and claim the clean lines independently → resolve the exception.

## Run locally (no external services)

```bash
# 0. once: install deps at the repo root
npm install

# 1. terminal A — local chain
anvil

# 2. terminal B — deploy escrow + mock USDC (from contracts/)
forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 3. paste the two logged addresses into apps/web/.env.local
#    NEXT_PUBLIC_ESCROW_ADDRESS=0x...
#    NEXT_PUBLIC_USDC_ADDRESS=0x...

# 4. run the app
npm run dev
```

The six demo roles (payer, attestor, resolver, carrier, terminal, forwarder) are backed by the canonical anvil dev accounts; switch roles in the UI. On the local chain a **⏩ skip challenge window** button time-travels past open windows.

## Run against Arc Testnet

1. Deploy `ParcFiEscrow` — primary path: import bytecode/ABI into [Circle Contracts](https://developers.circle.com/contracts) (blockchain `ARC-TESTNET`); fallback: `forge script script/DeployArc.s.sol --rpc-url https://rpc.testnet.arc.network --broadcast --private-key $DEPLOYER_KEY`.
2. Generate six fresh burner keys, put them in `NEXT_PUBLIC_DEMO_KEYS` (comma-separated, role order above). They are testnet-only throwaways.
3. Fund the payer (and gas for the others) with Arc Testnet USDC from the [Circle faucet](https://faucet.circle.com). Gas on Arc is paid in native USDC.
4. Set in `.env.local`:

```env
NEXT_PUBLIC_NETWORK=arc
NEXT_PUBLIC_ESCROW_ADDRESS=0x...        # from step 1
NEXT_PUBLIC_USDC_ADDRESS=0x3600000000000000000000000000000000000000
NEXT_PUBLIC_START_BLOCK=<deploy block>  # bounds event queries
NEXT_PUBLIC_DEMO_KEYS=0x...,0x...,0x...,0x...,0x...,0x...
```

Explorer links (Arcscan) appear on every transaction and activity entry automatically.

## Status

- Working now: full golden path against anvil and (given a deployment + funded wallets) Arc Testnet; per-line state, countdowns, role gating, receipts, event-sourced activity log, demo reset.
- Pending: Circle user-controlled wallet onboarding for the payer/beneficiary roles (server-side `CIRCLE_API_KEY` / `CIRCLE_APP_ID`, never `NEXT_PUBLIC`); Circle Contracts deployment record.
- Demo roles are burner accounts by design — synthetic data, testnet only, nothing custodial.
