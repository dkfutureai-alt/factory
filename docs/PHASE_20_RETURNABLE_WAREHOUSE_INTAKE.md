# Phase 20 — Cylinder/Returnable Warehouse Intake

**Status:** source-code candidate; requires isolated GitHub CI and real-device/client acceptance. This feature does not authorize any production database migration.

## Closed reverse logistics step

The existing Phase 10 driver flow records customer returns with the immutable Inventory ledger at the truck's vehicle location. Previously no controlled return-to-warehouse step existed. Phase 20 adds:

1. Driver closes the pickup at the customer and the delivery finishes.
2. Warehouse operator opens Admin → Dispatch & Delivery → completed pickup → **Receive at warehouse**.
3. Operator selects an active `receiving` location and an active `quarantine` location in the **same factory**.
4. A single database RPC moves *all* pickup lines, debiting vehicle stock and crediting their segregated destinations. `good` lines go to **receiving**, while `damaged` and `rejected` lines go to **quarantine**.
5. The intake and every Inventory transaction are recorded. Repeating the exact request returns the already committed intake ID, not a second stock transfer.

Migration 0046 also hardens `commercial_allocate_sales_order` to **reject Sales allocation from receiving, quarantine, vehicle, production, quality and other non-saleable locations**. Only active warehouse, bin and dispatch locations are eligible; the existing valid-location Sales E2E remains part of Foundation CI.

The receiving area is intentionally **not a refill release or sales-available bin**. An authorized Quality/Warehouse process must subsequently inspect and route the returned physical cylinder before production/refilling; dangerous/failed assets stay isolated. No individual cylinder serial tracking, hydrostatic test certification or hazardous-goods compliance claim is made by this phase.

## Database

- `supabase/migrations/0046_returnable_warehouse_intake.sql`
- `public.dispatch_returnable_intakes` and `public.dispatch_returnable_intake_lines` (RLS, same-tenant FK, read-only authenticated API).
- `public.dispatch_intake_returnables(p_pickup_id,p_receiving_location_id,p_quarantine_location_id,p_notes)` requires warehouse operation access to the exact factory and a completed pickup on a finished delivery.
- Every original pickup line must be backed by a matching vehicle receive Inventory transaction.
- The RPC locks the pickup and reuses `warehouse_transfer_stock_internal`, which uses an item/source advisory transaction lock and prevents negative source stock. A failure aborts the *entire* batch.
- Separate same-factory receiving/quarantine location types are mandatory. Direct authenticated writes to intake records are prohibited.
- Audit hooks record the intake header and ledger-backed stock transfers.

## QA coverage

`supabase/tests/0046_returnable_warehouse_intake_smoke.sql` runs in a rollback-only fixture with a dedicated fictitious authenticated warehouse manager. It checks:
- Good vs damaged routing into receiving vs quarantine.
- Exact vehicle stock debit and matching immutable Inventory transactions.
- Safe repeat without duplicate intake lines.
- Rejection of mismatched destinations after receipt.
- Cross-tenant read and RPC denial under a different JWT identity.
- Anonymous denial, read-only authenticated table grants and trusted service-role grants.

Run the existing `Supabase Foundation Checks` workflow on the precise source head. Live tests need actual opt-in users, a real returned-cylinder delivery, authorized factory roles, vehicle/warehouse scan evidence and separate physical inspection sign-off. Never seed production with fictional SQL fixture rows.

## Release limits

A completed returnable warehouse intake is **not** equivalent to an individual cylinder traceability system. Serial/QR-per-cylinder ledger, custody history, pressure testing, regulatory certification, gas filling and quality-release rules must be separately specified and validated for industrial gases before claiming full gas-cylinder compliance. Phase 20 is quantity-based, matching the existing Phase 10 pickup model.
