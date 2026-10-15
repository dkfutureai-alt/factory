# FactoryOS Inventory + Production Live Integration checkpoint (2026-10-15)

## Scope

This checkpoint extends the existing Supabase-ready Flutter service graph into the already-approved Inventory and Production surfaces. No new major UI screen was created in this milestone, so the existing approved Inventory Dashboard, Inventory Item Detail, Production Dashboard and Production Order Detail designs were reused instead of introducing a new visual direction.

FactoryOS remains at **50 design-first SVG specifications**.

`janseva-production` remains untouched. No dedicated FactoryOS Supabase project has been created or connected.

## Inventory live adapter

Added:

- `SupabaseInventoryRepository`
- `SupabaseInventoryItemDetailRepository`

The Inventory overview now has a live Supabase path that reads RLS-visible normalized data from:

- `items`
- `item_categories`
- `item_units`
- `inventory_balances`
- `warehouses`
- `warehouse_locations`
- posted `stock_transactions`
- damaged/scrapped `serial_numbers`

The adapter derives stock value, active SKU count, low-stock count, today's movements, damaged/blocked serial count and per-item stock summaries from persisted database state. Inventory balances remain derived from the immutable Inventory ledger; the Flutter client does not update balances directly.

The Inventory Item Detail live adapter loads the selected SKU, category/unit, warehouse/location balances, posted movement history and optional inbound Purchase progress. If Purchase progress is not visible to an Inventory-only role, the core Inventory item still loads without widening RLS.

Current live item detail deliberately reports `reserved = 0` because the current persisted schema has no authoritative Inventory reservation field. This checkpoint does not invent reservation data.

## Selected-record navigation fix

The previous dashboard/detail route flow could open a fixed demo detail even after the user selected another row. That behavior is now corrected.

Inventory Dashboard passes the selected SKU to the detail page in both preview and live modes.

The preview repository now honors multiple sample SKUs rather than returning the same record for every selection.

The old non-functional **Stock entry** button was removed. A real stock-entry transaction workflow remains pending and must be designed image-first before implementation.

## Production live adapter

Added:

- `SupabaseProductionRepository`
- `SupabaseProductionOrderDetailRepository`

The Production overview reads RLS-visible Production orders, item names and production-line codes and derives active quantities/status alerts from stored data.

The Production Order Detail live adapter reads:

- Production order state
- latest Production batch
- latest Quality check
- Production material requirements
- current Inventory availability
- execution timestamps/timeline

The selected Production order is now opened consistently in preview and live modes rather than always opening the old fixed demo order.

The old misleading create-order button, which only opened a fixed demo record and did not create an order, was removed.

## Production completion mutation

`ProductionOrderDetailRepository` now exposes an explicit completion capability boundary.

Preview mode remains read-only and rejects completion.

Live Supabase mode resolves the active `in_production` / `qc_pending` batch and calls only the existing database command:

- `complete_production_batch`

The Flutter screen enables **Complete batch** only for a live mutation-capable repository when the current Quality result is `Pass`. It shows progress during the command, refreshes the order after success and retains user-facing success/error feedback.

The Flutter client does not duplicate the database completion rules.

## PostgreSQL production-command verification

Added:

- `supabase/tests/05_production_completion_commands.sql`

Database CI now creates an isolated CI-only completion fixture with:

- `PRD-CI-COMPLETE-001`
- `PB-CI-COMPLETE-001`
- passed QC `QC-CI-COMPLETE-001`
- batch-tracked finished good `FG-COMP-X`
- finished-goods batch `FG-CI-COMPLETE-001`
- posted `finished_goods_receipt` ledger transaction `STK-CI-FG-RECEIPT-001`
- exact Production output → stock-line → finished-batch linkage

The test proves:

1. a warehouse-scoped user cannot complete a Production batch without the Production permission;
2. the existing QC-hold demo batch remains blocked even for an authorized Factory Manager;
3. a valid authorized completion succeeds only after passed QC and posted finished-goods ledger evidence;
4. successful completion reconciles the Production batch and parent Production order quantities/status/timestamps.

During test development, the inventory tracking guard correctly rejected an early CI fixture that attempted to post a batch-tracked finished good without `batch_id`. The fixture was corrected to use a real finished-goods batch; the Inventory invariant was not weakened.

## Service graph

`FactoryOsServices` now composes preview or live implementations for:

- Authentication
- Inventory overview
- Inventory item detail
- Production overview
- Production order detail / completion
- Warehouse
- Dispatch

Runtime live routes now use these service-graph repositories for Inventory and Production.

## Verification

Accepted runtime/code head:

`b0753d85d98281e3ff81aba63bc8e4cc4486452c`

Database CI run `38691655274` passed:

- complete schema/review/command chain;
- all fictional demo seeds;
- RBAC/RLS assertions;
- Notifications security assertions;
- Warehouse/Dispatch command assertions;
- Dispatch partial-load guard;
- Production completion command assertions.

Flutter CI run `38691655283` passed:

- `flutter analyze --fatal-infos` with no issues;
- **67/67 tests**;
- selected non-default Production-order navigation;
- selected non-default Inventory-item navigation;
- live Production completion command boundary and durable completed state;
- all previously accepted module regression coverage.

The Production screen contains success/error SnackBar feedback, but this checkpoint does not claim the transient SnackBar animation itself is widget-test verified. The durable mutation state and zero-render-exception behavior are verified.

## Still not production-complete

- No dedicated FactoryOS Supabase project exists.
- FactoryOS schemas have not been deployed to Supabase.
- Real Supabase Auth/JWT/Data API/RLS/RPC behavior has not been verified against a FactoryOS deployment.
- Supabase security/performance advisors have not been run.
- Inventory and Production live adapters have not yet been exercised against real deployed FactoryOS credentials/data.
- A real Inventory Stock Entry transaction workflow is not implemented yet.
- Purchase, HR, Sales, Fleet, Delivery, Maintenance, Notifications and Reporting still need live repository migration/verification.
- Scanner camera, POD storage, trusted FCM dispatch, live Reporting exports and full production E2E QA remain pending.

## Next dependency-safe work

The deployment dependency remains a dedicated FactoryOS Supabase project after organization and estimated-cost confirmation.

If development continues before that approval, the next core P1 repo-only gap is the **Inventory Stock Entry transaction workflow**. It is a new major operational screen and therefore must follow the project rule:

**existing context → inspect ledger/RPC contract → design image first → implement → connect validated posting → test permissions/tracking/negative-stock rules → compare/fix → verify**.

**This checkpoint is a verified repository/local-PostgreSQL milestone, not a deployed-Supabase or production-completion claim.**
