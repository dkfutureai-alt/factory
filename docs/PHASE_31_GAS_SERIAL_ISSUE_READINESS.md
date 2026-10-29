# Phase 31 — Serialized customer-issue readiness guard

**Source status: proposed; production deployment and physical acceptance pending.**

## Gap addressed

The Phase 21B `gas_link_container_transaction` RPC already requires an existing immutable
Inventory posting, matching factory/item/serial, existing customer POD and a valid
custody sequence before attesting a customer `issue`. However the existing
serialized evidence path checked only whether a container was `retired`.
It did **not** fail closed on `hold`, `quarantined`, `unverified`,
a missing inspection, or an expired/missing test due date.

## Migration and behavior

Migration `0050_gas_serial_customer_issue_readiness.sql` installs a narrow
`BEFORE INSERT` trigger on `public.gas_container_transaction_links`.
When an attempted serial attestation declares `transaction_type='issue'`,
it rejects the evidence unless the registered physical container:

1. Is scoped to the same organization and factory as the proposed link.
2. Has state `inspection_recorded` and condition `good`.
3. Has a recorded inspection timestamp not later than the server clock.
4. Has a known `test_due_on` date that has **not expired**.

The trigger runs for authorized RPC insertions and other privileged insertions
without granting a new public client mutation capability. Internal
`transfer` links and receipts are **not** subject to this customer-issue
readiness gate: an unfit container must be able to move into a documented
quarantine or maintenance workflow.

All rejection occurs before the link insert, so a failed attempt does not
create false serial issue evidence or its audit event. Existing links are
immutable and are not retrospectively modified by later inspections.

## Verification

`supabase/tests/0050_gas_serial_customer_issue_readiness_smoke.sql` runs
against *isolated local* Supabase with a transaction rollback. It tests:

- Uninspected/hold cylinders rejected.
- Damaged/quarantined cylinders rejected.
- Missing or expired test due date rejected.
- Missing or future-dated inspection rejected.
- A documented good, non-overdue inspected container is not blocked by this
  **specific trigger**; underlying RPC's separate ledger/POD checks still apply.
- A quarantined internal transfer is still allowed through this specific
  trigger, so repair/inspection logistics remain possible.
- No rejected evidence row persists and no anon/authenticated EXECUTE on the
  trigger function is available.

Existing `0048` and real Auth/JWT tests continue checking sequence,
capacity, idempotent requests, factory ownership, POD denial and RLS.
CI must pass full new-migration replay and tests before merge.

## Limits / safety

**This is a serial-attestation guard, not a dispatch blockade.** Existing
quantity-only Inventory/Dispatch workflows can still move stock without a
serialized scan; missing scanned coverage remains visible through the Phase
21C `gas_serial_attestation_coverage` report. This change does not prove
pressure certification, gas compatibility, cylinder condition on site,
manufacturer certification, regulatory compliance, physically authenticated
QR scans, or complete custody. Test dates and inspection states can only be
trusted after actual competent physical examination and proper evidence.

A later **approved** integration must require an actual scan/asset-specific
approval **before** creating the customer Dispatch issue, couple it
transactionally with the ledger and POD, and record exception handling for
blocked/expired assets. Physical staff devices and consenting pilots remain
essential. Keep issue #27 open and do not describe the software as certified
serial tracking or complete cylinder custody.

No live FactoryOS schema changes are performed by adding this migration to
Git; production remains on the separate reviewed plan/release workflow.
