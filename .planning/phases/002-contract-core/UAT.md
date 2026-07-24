# UAT

## Scenario

Create three obligations, fund them, attest all three, dispute only demurrage, finalize the other two, claim them from different recipients, split the disputed amount, and verify total value is conserved.

## Result

Pass with the mock token (2026-07-24): `test_GoldenPath_EndToEnd` executes exactly this scenario — $10,000 funded, three lines attested, only demurrage challenged, carrier and terminal claim $7,500/$1,500 independently while the dispute is open, resolver splits demurrage 60/40, payer withdraws $400, final accounting `cumulativeClaimed + cumulativeRefunded == fundedTotal` and the contract balance drains to zero.

## Notes

Repeat on Arc Testnet with real transactions in Phase 003 (the "fresh wallets" golden-path step). The blocked-recipient variant also passes: a blocklisted carrier strands only its own claim and recovers it after unblocking.
