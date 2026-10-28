# Phase 21C — Serial Attestation Coverage (Source Candidate)

FactoryOS now has unique cylinder/Dura identity (0047) and optional scanned serial ↔ immutable Inventory transaction attestation (0048). Phase 21C exposes **what quantity remains without serial evidence**, without falsely identifying a lost physical cylinder.

## Report and operator flow

- Migration `0049_gas_serial_attestation_coverage.sql` adds a **read-only**, authenticated, factory/organization-scoped RPC `gas_serial_attestation_coverage(organization_id,factory_id,limit)`.
- Query is based on committed `inventory_transactions` for cylinder/returnable item types; count of **recorded** `gas_container_transaction_links` is compared with the whole/dimensional quantity.
- Results: `fully_attested`, `partially_attested` or `not_attested`, linked serial count, unattested quantity, transaction reference, SKU, operation type and timestamp.
- Default 200 rows; the API rejects limits outside 1–500 and does not reveal factories outside the authenticated user's assigned scope.
- Admin → **Cylinders** → **Serial evidence reconciliation** lists the last 200 transaction statuses with up to 30 recent exceptions. It is deliberately labelled **unattested**, not missing inventory, lost cylinder or noncompliance.
- No role can use this report to insert, alter or delete Inventory ledger entries or attestations.

## CI evidence

`supabase/tests/0049_gas_serial_attestation_coverage_smoke.sql` runs with fictitious data in a rollback-only transaction and verifies an unlinked 2-unit receipt reports 2 unattested; after one valid serial attestation the report shows exactly 1/2 linked and partial; bounded results and scope restrictions reject unauthorized requests; anonymous execute is not granted. Full Supabase Foundation and Flutter Admin CI must pass on the final source head.

## Limits

This reports **evidence coverage**, not physical stock reconciliation, certification or end-to-end chain-of-custody completeness. Current quantity-based operational RPCs can commit stock without mandatory serial scans. A complete gas-cylinder system additionally needs transaction-bound scan enforcement for every handoff, serialized physical counts, exception approvals, signed/customer POD, offline scanner conflict resolution, inspection/certification safeguards and physical-device pilot evidence. Not yet a production go-live acceptance.

Migration `0049` must not be applied directly to the dedicated FactoryOS production Supabase project outside the guarded owner-approved migration-history workflow.
