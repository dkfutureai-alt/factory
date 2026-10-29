# Phase 32 — Serialized Inventory evidence source integrity

**Status:** source change under isolated CI verification. The guarded FactoryOS production release has **not** been run and no customer cylinder has been inspected.

## Why this safeguard matters

The normal manager-only `gas_link_container_transaction` RPC already reads the immutable Inventory transaction and checks its type, item, organization, factory, source and destination, serial capacity, ledger quantity, and relevant POD / return chain. However, trusted service-role integrations may also insert `gas_container_transaction_links` directly. Earlier table constraints linked the evidence to valid assets and transaction IDs but did not enforce that the **claim's transaction_type, item and locations** matched the original Inventory transaction.

In particular, Phase 31 migration `0050` rejects an unsafe customer `issue` **when the evidence row says `issue`**. A privileged direct writer could falsely label a genuine Inventory `issue` as a `transfer` and bypass the issue-readiness trigger, even though no ordinary authenticated mobile user has direct INSERT access.

## Migration 0051

`0051_gas_serial_link_source_integrity.sql` adds the independent `gas_serial_link_source_integrity` trigger on every serial evidence INSERT, whether invoked by the manager RPC or a privileged service. It:

1. Requires the serial's authoritative asset organization/factory to equal the evidence row's organization/factory.
2. Requires the actual Inventory transaction to belong to the same organization, factory **and asset item**. No cross-item or cross-tenant evidence.
3. Requires the evidence's claimed `transaction_type`, `from_location_id`, and `to_location_id` to **exactly match** those on the immutable source transaction. The already-existing Phase 31 customer-issue readiness trigger therefore cannot be bypassed by pretending a real `issue` was a `transfer`.
4. Requires positive integer transaction quantity. Locks the underlying Inventory transaction while counting existing serial links, so even a privileged direct writer cannot exceed posted whole-unit capacity during a concurrent insertion.
5. Keeps the trigger function SECURITY INVOKER, a pinned empty `search_path`, and no anonymous/authenticated EXECUTE grant. Normal authenticated users still use the manager RPC and its existing RLS/RBAC/POD safeguards.

A valid privileged receive insertion still succeeds; the data and audit rows are otherwise unchanged. The constraint is applied only to **new** evidence inserts, not retroactively to the historical audit trail.

## Tests

`supabase/tests/0051_gas_serial_link_source_integrity_smoke.sql` uses rollback-only fictional database fixtures to prove the new guard rejects:

- An actual Inventory customer `issue` forged as `transfer` to evade migration 0050.
- Mismatched source or destination location.
- A serial tied to a different Inventory item.
- Fractional serialized container quantities.
- A second physical serial mapped to a single-unit received transaction.
- Anonymous/authenticated execution of the internal trigger function.

It accepts a matching direct receive attestation, verifies rejected claims leave no persisted evidence, and runs in the full local Supabase Foundation migration/SQL/Auth suite.

## Critical remaining limitations

**This is evidence-integrity hardening, not mandatory serialized dispatch or certified cylinder safety.** Privileged direct insertion of otherwise self-consistent records still does not prove the actual stock ledger movement, approved signed POD, verified customer custody, physically scanned QR, pressure testing, or a location sequence. The manager RPC separately checks several of those conditions, but a later project phase must enforce serialized scans **transactionally before** Inventory/dispatch posting, reconcile all individual asset counts, control exception approvals, and validate offline driver capture/idempotent replay. Quantity-based flows may still move without a serial link. Keep issue #27 open.

Actual regulated gas-cylinder inspection and transport standards must be reviewed by competent factory safety personnel. This migration only prevents incorrect software claims, not unsafe physical handling.

## Deployment and rollback

The sole authorized production path is the protected FactoryOS `Supabase Production Plan` (dry run and owner approval) → same-SHA `Supabase Production Release` (database-only first) after backup/restore evidence. Do not run `apply_migration`/ad hoc SQL against `zevrmvhnibztbxizswgu` or reuse Salon/Janseva resources. No migration or pilot action was performed in production while preparing this source change.
