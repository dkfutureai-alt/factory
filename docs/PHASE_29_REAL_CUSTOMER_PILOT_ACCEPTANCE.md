# Phase 29 — evidence-based real-customer pilot acceptance gate

**Status: implemented as a protected workflow, not run against production.** The dedicated FactoryOS production project was empty (zero application tables, zero applied migrations, zero Auth accounts) when this was prepared. A green repository test is never a customer acceptance record.

## Prerequisites (human release owner)

1. Review backup/restore evidence, then complete the guarded, owner-approved migration plan/database-only release for the *dedicated* Supabase FactoryOS project `zevrmvhnibztbxizswgu`. Configure SMTP, Auth, FCM and the Admin/Mobile app using FactoryOS credentials only. Do not use Salon/Janseva projects or their users.
2. With clear prior consent, provision **two different real pilot organizations**, factories and **one active organization admin account per organization**. Neither pilot admin can have a membership in the other organization; neither may be a platform owner. Grant normal supported factory/workspace access.
3. Have the two pilot administrators personally sign in, opt into **Profile → Customer pilot**, and actually complete the real workflows. Each admin must submit results for **all 14 scenarios**:
   onboarding, HR, inventory, production, quality, purchasing, sales, warehouse, fleet, delivery, maintenance, reports, notifications, security.
4. Required positive operational evidence for **each** tenant (not merely fictional local seed data): HR attendance; Inventory transaction; Production order; Quality inspection; Purchase order; Sales order; Warehouse pick list; Fleet trip; Delivery; returnable warehouse intake; Maintenance work order; serialized cylinder/Dura record; and a cylinder-to-ledger transaction attestation. Inspect scans, physical custody, condition/quarantine and financial totals separately. A visible record alone is not proof the transaction was correct.
5. Under the protected GitHub environment `factoryos-production` (required reviewers; main-only releases), provision **only** these environment secrets:
   - Existing `FACTORYOS_SUPABASE_PROJECT_REF`, `FACTORYOS_SUPABASE_URL`, and `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`.
   - New `FACTORYOS_PILOT_ADMIN_A_EMAIL`, `FACTORYOS_PILOT_ADMIN_A_PASSWORD`, `FACTORYOS_PILOT_ADMIN_B_EMAIL`, `FACTORYOS_PILOT_ADMIN_B_PASSWORD`. Use dedicated consenting test identities, not customer-owner personal accounts, and rotate/revoke them after the pilot. Do not put secrets or identifying details in PRs, chat or Actions summaries.
6. On `main` manually run **FactoryOS Real Customer Pilot Acceptance**, supply `confirm=VERIFY_PILOT` and independently type project ref `zevrmvhnibztbxizswgu`. Reviewers must authorize the environment. Capture the run URL, commit SHA, timestamp, explicit consent evidence and actual tester/device records, without exposing customer private information.

## What this gate actually measures

For each account (signed in with its own JWT, **no service-role key**), it requires:
- A single active membership, role exactly `org_admin`, distinct user and organization from the other pilot account, an organization/factory positive control and reciprocal denial for the four core membership/factory tables.
- Its own `pilot_participants` consent row.
- A **non-truncated** feedback response; one **latest** report (ordered by server timestamp plus record ID) for every one of the 14 scenarios; latest result must be `passed` and within the last **14 days**. A later Failed or Blocked result overrides an earlier Passed result.
- At least one accessible, organization-matching record in **each** of the 13 operational evidence tables listed above; no missing module is silently treated as completed.
- Read-only queries must return **zero** foreign-organization rows for those 13 operational tables plus both pilot tables, **in both directions**. The peer account first proves it can read at least one positive row in every operational table, so tests cannot pass solely because the tables are empty.

The script sends only password-sign-in POSTs to Supabase Auth and GETs to the fixed FactoryOS Data API origin; it does not seed customer records, invite users, modify reports, change financial data, grant permissions or write approvals. It does not forward auth tokens on HTTP redirects and does not log passwords, IDs, row data or response bodies. If the API is unavailable, returns malformed/oversized/truncated data, or unexpectedly exposes another tenant, the gate blocks.

## Not proved, even by a green live gate

- The pilot feedback is **user-reported**, not cryptographically bound to the current mobile/web build; a human must witness/preserve independent screenshots, transaction IDs, app versions and results.
- A visible operational record does not verify **correct stock balances, financial posting, legal cylinder safety, physical custody or successful QR scans**.
- The gate does not automatically prove cross-factory restrictions **within a tenant**, write privilege escalation denial, FCM push receipt, SMTP inbox delivery, real Android/iOS devices, signed app bundles, backups, store approval, accessibility or restore time.
- Two admin accounts are necessary positive controls, **not** a substitute for real employee, supervisor, warehouse, driver, finance and low-privilege user role tests. Do these manually with consent and record evidence.
- Never mark the system production complete merely because this script or GitHub CI is green. The release owner must approve all items of `docs/PRODUCTION_GO_LIVE_CHECKLIST.md`.

## Regessions and failure behavior

Offline tests in `scripts/tests/test_verify_production_pilot_acceptance.py` cover missing consent; missing workflow; stale feedback; latest failed superseding an old pass; empty operational table; cross-organization exposure in each operational and pilot table; wrong role/project/credentials; malformed timestamps; and 1,000-row report truncation. These use synthetic data and make **no network calls**.
