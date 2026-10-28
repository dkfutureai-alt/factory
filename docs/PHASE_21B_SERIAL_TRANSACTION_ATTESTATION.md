# Phase 21B — Serial / Inventory Transaction Attestation

**Status:** source candidate pending isolated GitHub CI and security review. No production schema has been changed.

Phase 21A establishes unique cylinder/Dura serial identity. Phase 21B creates a **manager-attested, read-only-to-clients link** between a scanned serial and an already posted immutable Inventory transaction.

## Operator workflow

1. Manager registers the physical container in Admin → Cylinders (Phase 21A).
2. The Inventory / production / warehouse / dispatch workflow posts its quantity transaction through existing RPCs. This stage never creates or modifies Inventory transactions or balances.
3. Manager opens the container → **Attach serial to movement**; selects a recent transaction for the same item and enters/scans the physical label. An application-generated UUID acts as the retry/idempotency key.
4. The database validates organization, factory, Inventory item, QR/serial, matching ledger debit/credit, transaction capacity, and previous *verified* location sequence before recording the link.
5. For a customer issue, the transaction must correspond to an existing **delivered Dispatch/POD** record; after that, a linked receive must be from a documented returnable pickup for the same customer. Reconciliation rejects arbitrary customer handovers.
6. The Admin history shows **transaction-linked attestations** separately from physical inspection events. A scan is not a pressure-safety certification.

## Data and security

- Migration `0048_gas_serial_transaction_links.sql` introduces append-only `gas_container_transaction_links`.
- A link is unique per asset+transaction. An organization-scoped request UUID may be retried with the same asset and transaction, returning the prior ID.
- Count of registered serial links may not exceed the **integer** quantity of the Inventory transaction. The transaction row is locked when checking capacity.
- First link must be an Inventory opening/receive, later transfer/issue must start at the most recently **verified** destination, and a customer return receipt must match the previously linked customer.
- `gas_link_container_transaction(asset,transaction,scanned_code,request_key)` is restricted to authenticated factory managers; RLS reads are factory-scoped. No direct authenticated table writes or anonymous grants.
- Hash-chained business audit logs record new attestations. SQL trigger rejects later link mutations.
- Structural QA requires indexes for all foreign keys.

## Automated tests

`supabase/tests/0048_gas_serial_transaction_links_smoke.sql` runs rollback-only runtime checks for first-receipt requirement, QR/serial validation, safe retries, 1-unit transaction capacity, warehouse-to-vehicle continuity, customer issue without POD rejection, tamper-evident audit and RLS/write denials. The full Supabase Foundation suite must replay migrations through `0048`; Flutter quality must pass the Admin UI.

## Limitations and release gates

**Serial-to-ledger assignment is not full custody reconciliation.** Existing aggregate Inventory/Dispatch workflows can still post transactions before or without serial attestation. This stage does not intercept or block those postings, nor prove complete stock serial counts, physical customer pickup or actual label scanning. The Admin picker shows the most recent 200 transactions only and requires operator selection.

Before claiming a complete system, finish real-time serialized scan enforcement at stock write boundaries, per-transaction unlinked-quantity reports, driver/warehouse mobile scan integration, offline replay/conflict prevention, label printing, exception handling and physical handover acceptance on both platforms. Industrial-gas safety, testing and cylinder regulatory compliance require separate expert-reviewed controls.

All production credentials, backup/restore, user identities and physical-device acceptance remain protected release-owner gates. Do not run migration 0048 manually in the dedicated FactoryOS production database outside the approved migration-history workflow.
