# Phase 21C — Serial Evidence Coverage Report

**Status:** source candidate. Production remains undeployed.

## Why it matters

FactoryOS Phase 21B allows managers to attest individual cylinders/Dura containers against immutable Inventory transactions. Because those links are not yet mandatory at the stock-write boundary, a posted stock movement can still lack serial evidence. The report must show this gap rather than implying all assets have been physically scanned.

## Admin workflow

Open **Cylinders** → choose factory → **Cylinder serial evidence gaps**. The report uses `gas_serial_transaction_coverage(factory_id, limit, missing_only)`, with a filter for incomplete movement evidence. For each recent gas-cylinder or returnable Inventory transaction, it displays:

- Posted quantity from the immutable Inventory transaction.
- Count of registered serial links (distinct asset+transaction uniqueness is already enforced).
- Unlinked quantity, floored at zero, plus `missing`, `partial`, `complete` or `overlinked` status.
- Movement reference, item SKU and movement type.

Results are limited to **100 recent matching transactions** in the UI and a hard limit of 200 in the RPC. A filter returning zero records does **not** certify complete historical or physical custody. This is not a full lifetime report, regulatory certificate or approval to fill/sell a cylinder.

## Security

Migration `0049_gas_serial_evidence_coverage.sql` creates a stable, read-only RPC with required authenticated JWT and explicit factory-access check. Anonymous users cannot execute it. Cross-factory reads raise an access error. No table grants, quantity transactions, asset lifecycle states or customer records are modified by this feature.

## Acceptance

- `supabase/tests/0049_gas_serial_evidence_coverage_smoke.sql` validates missing, partial, complete, incomplete-only filter, bounded limits, role grants and cross-tenant denial in a rollback-only synthetic fixture.
- `supabase/tests/gas_asset_transaction_auth_e2e.sh` extends actual local Auth/JWT/REST tests to verify reported coverage for receipt, transfer and unlinked issue, permission denial and anonymous rejection.
- Flutter quality must validate the responsive Admin panel.

## Still required before full serialized gas operations

Enforce scan-and-match at driver, filling, warehouse, dispatch/POD and customer-return stock write boundaries; reject duplicate physical custody; provide meaningful offline queue/idempotent replay; reconcile **all** serial movements across customers and factories; gate gas quality/pressure inspection with competent technical standards. A successful evidence count is not a reason to mark these workflows finished.

Migration `0049` must be deployed only after owner approval and isolated restoration tests through the protected FactoryOS-only release pipeline. No Salon or Janseva resources may be changed.
