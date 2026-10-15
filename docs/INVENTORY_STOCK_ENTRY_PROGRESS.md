# FactoryOS Inventory Stock Entry checkpoint (2026-10-15)

FactoryOS now has a design-first, ledger-controlled **Inventory Stock Entry** workflow for manual stock adjustments. This checkpoint is repository/local-PostgreSQL verified and is **not** a deployed-Supabase or production-completion claim.

## Design

- `designs/51_inventory_stock_entry.svg`
- Admin workflow: Stock In / Stock Out → Item → Warehouse / Location → Batch or Serial when required → Quantity / Unit Cost → Reason → Projected Stock review → Post.
- The screen explicitly limits this workflow to manual adjustments. Purchase receipts, Production movements, Warehouse transfers, Dispatch, Customer Returns and Maintenance continue through their dedicated transactional workflows.

## Flutter implementation

- Inventory Dashboard now exposes **Stock entry**.
- `InventoryStockEntryPage` implements responsive entry and review surfaces.
- Typed domain models validate signed quantity, batch/serial requirements, reason and unit cost.
- Preview repository is interactive but mutation-disabled; it never fabricates a successful stock write.
- Supabase repository reads only RLS-visible Inventory masters/balances and posts only through `post_manual_stock_adjustment`.
- Projected negative Stock Out is blocked in the UI and remains independently protected by the database ledger guard.
- Live service composition and `/inventory/stock-entry` routing are wired through the existing preview/Supabase service graph.

## PostgreSQL command

`public.post_manual_stock_adjustment(...)`:

- derives organization/factory from the selected warehouse instead of accepting tenant scope from the client;
- requires authenticated access plus exact-warehouse `inventory.adjust` and `inventory.post` permissions;
- accepts only `adjustment` stock movement semantics;
- validates active Item/Warehouse/Location relationships;
- enforces batch-tracked and serial-tracked item requirements;
- requires serial adjustment quantity to be exactly one unit;
- prevents duplicate positive stock for a serial already on hand;
- creates one draft stock transaction and one ledger line, then delegates posting to the existing immutable `post_stock_transaction` function;
- inherits the central negative-stock guard;
- reconciles serial warehouse/location/status only after ledger posting succeeds;
- supports idempotent replay and rejects idempotency-key payload conflicts;
- writes an authenticated audit record with `source = manual_stock_entry`;
- is executable only by `authenticated`, not `public`.

## Database regression coverage

Exact runtime/code head: `7baf8cb14864dea7b27f42277972256a93d90a3b`

Database CI run `38694945245`: **success**.

The dedicated Stock Entry command suite verifies:

- authorized RM-WH Stock In posts an immutable adjustment ledger line;
- identical replay does not duplicate transactions or lines;
- a warehouse-scoped manager cannot adjust a sibling warehouse even when the forbidden UUID is already known;
- a batch-tracked item cannot post without a valid batch;
- an impossible Stock Out is rejected and leaves no transaction side effects;
- serial Stock In is exactly +1 and reconciles serial location/status;
- duplicate serial Stock In is rejected;
- serial Stock Out is exactly -1 and returns serial ledger quantity to zero;
- a Production-scoped user without `inventory.adjust` cannot use manual Stock Entry even with known valid RM scope UUIDs;
- successful manual adjustments create audit rows.

All earlier schema/seed/RBAC/RLS, Notifications, Warehouse/Dispatch, Dispatch partial-load and Production completion database gates remain green in the same run.

## Flutter regression coverage

Flutter CI run `38694945352`: **success**.

- `flutter analyze --fatal-infos`: no issues.
- **71/71 tests passed**.
- New coverage verifies direction/sign handling and tracking validation.
- Preview mode is proven mutation-disabled.
- Inventory Dashboard → Stock Entry navigation renders without exceptions.
- A live-capable fake repository verifies posting goes through the repository command boundary.
- All previously accepted application regressions remain green.

## Still pending before production acceptance

- No dedicated FactoryOS Supabase project has been created or connected.
- The schema/RPC has not yet been exercised through a real FactoryOS Supabase JWT/Data API session.
- Real Supabase RLS/RPC/security-advisor/performance-advisor verification remains pending.
- No production Stock Entry should be enabled until the dedicated FactoryOS Supabase environment is deployed and role provisioning is verified.
- `janseva-production` was not modified.
