# Customer Interview Kit

Purpose: falsify or support the wedge with primary evidence (target: 8 interviews; gates in `RESEARCH.md`). Ask about the most recent disputed invoice — never pitch blockchain.

Privacy rule: **no names, companies, emails, or notes with PII in this repository.** Keep the contact list and raw notes in a private tracker; commit only anonymized summaries (e.g. "Forwarder A, 12 staff, Lagos–Rotterdam").

## Quota

| Slot | Profile | Status |
|---|---|---|
| 1–3 | Freight forwarder finance/operations lead | Not scheduled |
| 4–5 | Shipper AP / logistics lead | Not scheduled |
| 6–7 | Carrier or service-provider finance lead | Not scheduled |
| 8 | Freight-audit / freight-payment specialist | Not scheduled |

Sourcing: existing logistics contacts, LinkedIn (search: "freight audit", "AP manager freight", "forwarder operations"), Nigerian/West-African forwarder associations, hackathon mentor network.

## Outreach template (short, problem-first)

> Subject: 20 minutes on disputed freight invoices?
>
> Hi [name] — I'm researching how [forwarders/shippers/carriers] handle invoices where one charge is disputed but the rest is fine. I'm trying to learn what actually happens operationally, not sell anything. Could I get 20 minutes this week? Happy to share what I learn across interviews.

## Question script (from RESEARCH.md falsification plan)

1. Walk me through the last invoice that missed its payment date.
2. Which line caused the exception?
3. Was the undisputed balance paid on time, or held with the dispute?
4. How many people/systems touched it, and for how long?
5. Who had authority to approve evidence and resolve the dispute?
6. What did the delay cost — fees, financing, cargo hold, relationship, staff time?
7. At what point could funds have been committed safely?
8. Would you use or pay for partial settlement if counterparties used embedded wallets?

Listen for (score afterwards, not during): line-level exceptions freezing payable value (Y/N), quantified days/amount/effort, who they'd trust as attestor/resolver, willingness to pre-fund.

## Evidence log (anonymized, append per interview)

| # | Date | Profile | Line-level freeze? | Quantified impact | Attestor/resolver candidate | Would pre-fund? | Follow-up? |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — |

## Gates (decided after 8 interviews — from RESEARCH.md)

- Go signals: ≥5/8 report material line-level delay; ≥3 quantify it; ≥2 share a redacted workflow or agree to test; ≥1 buyer requests follow-up.
- Kill signals: undisputed lines already paid easily; delays are cash-driven not trust-driven; nobody will pre-fund or accept stablecoin; onboarding cost exceeds benefit.

Interviews never block the demo build (Phase 003 step 9): if fewer than eight complete by the feature freeze, all commercial claims stay hypothesis-labeled.
