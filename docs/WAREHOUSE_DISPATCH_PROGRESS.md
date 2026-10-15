# FactoryOS Warehouse & Dispatch checkpoint (2026-10-14)

## Scope

Repository/local-PostgreSQL implementation of Warehouse transfer execution and Dispatch load/finalization through the existing Inventory ledger, Sales, Fleet/Trip and Delivery foundations.

This milestone does **not** deploy to Supabase and does not touch `janseva-production`.

## Design-first surfaces

The approved dashboard patterns were preserved and extended with:

- `designs/48_warehouse_transfer_detail.svg`
- `designs/49_dispatch_load_detail.svg`

FactoryOS now has **49 design-first SVG specifications**.

## Warehouse transaction foundation

`supabase/schemas/11_warehouse_dispatch.sql` adds:

- `warehouse_transfers`
- `warehouse_transfer_lines`
- transfer lifecycle statuses
- organization/factory/warehouse/location/item/batch/serial validation
- warehouse-aware RLS

`public.complete_warehouse_transfer(uuid)` implements the golden stock rule:

1. validate authenticated warehouse-management and inventory-posting authority;
2. require a ready/in-progress transfer with lines;
3. create an idempotent `transfer_out` ledger transaction;
4. create an idempotent `transfer_in` ledger transaction;
5. post both through the hardened Inventory posting function;
6. mark the transfer complete only after both ledger sides post successfully.

The command never directly updates inventory balances. A completed internal transfer is quantity-neutral across the two posted ledger transactions.

## Warehouse-scoped Inventory posting

The Inventory posting RPC now supports a warehouse-scoped operator only when **every** transaction line is within a warehouse for which the user has `inventory.post` authority. Existing organization/factory authority remains supported.

This closes the gap between hardened warehouse RBAC and legitimate warehouse operations without reintroducing upward scope escalation.

## Dispatch transaction foundation

The schema adds:

- `dispatch_orders`
- `dispatch_lines`
- `dispatch_checks`
- `dispatch_events`
- dispatch lifecycle statuses
- Sales-order quantity validation
- item/batch/serial/location validation
- factory/warehouse-aware RLS
- immutable dispatch-line protection after stock-ledger linkage

Dispatch stock and finalization are intentionally separate commands.

### `public.post_dispatch_stock(uuid)`

Requires:

- authenticated dispatch-management authority;
- authorized Inventory posting for the outbound warehouse;
- ready/loading dispatch state;
- loaded quantities and source locations.

It then:

- creates one idempotent `sales_dispatch` stock transaction;
- posts negative Inventory ledger lines;
- links each dispatch line to its posted stock-transaction line;
- advances the dispatch to `loaded`;
- writes dispatch events.

### `public.finalize_dispatch(uuid)`

Finalization is blocked until:

- dispatch state is `loaded`;
- every planned quantity is fully loaded;
- every dispatch line reconciles exactly to a posted `sales_dispatch` ledger line;
- all required dispatch checks are complete;
- a valid same-tenant/same-factory/same-sales-order trip is assigned and ready.

On success the command:

- creates or reuses the matching Delivery record;
- creates/reconciles Delivery lines from loaded dispatch quantities;
- adds the loaded Delivery event;
- marks Dispatch as dispatched;
- advances the Sales order to dispatched when its full ordered quantity has been dispatched;
- advances a planned/assigned Trip to ready.

Replay is idempotent: it does not duplicate the outbound stock transaction or Delivery record.

## Review fixes found by executable database tests

Real PostgreSQL execution exposed and fixed several issues during this milestone:

1. Warehouse transfer seed needed an explicit nullable-key conflict target.
2. Inventory idempotency uses a partial unique index, so Warehouse/Dispatch upserts must repeat `WHERE idempotency_key IS NOT NULL`.
3. The original RBAC test harness used `\quit 1`, which PostgreSQL `psql` ignored as a numeric exit argument. Assertions now fail fast with SQL errors under `ON_ERROR_STOP=1`.
4. The production child-row RBAC assertion needed a deterministic CI-only material-requirement fixture because the product demo seed intentionally contains no such rows.
5. The Dispatch test fixture had to follow the real Sales lifecycle: draft order → add lines → ready/confirmed.
6. Dispatch finalization used a local `delivery_id` identifier that collided with a table column; the review fix uses an unambiguous `target_delivery_id`.

## Demo / preview alignment

The fictional DKIM seed now includes:

- staging locations `RM-STAGE-01` and `FG-STAGE-01`;
- Warehouse transfer `TRF-2026-00218` with three staged raw-material lines;
- historical Dispatch `DSP-2026-00417` linked to `SO-2026-01842` and `TRIP-2026-00814`;
- posted `sales_dispatch` ledger evidence for that historical dispatch;
- completed invoice/e-way-bill/packing-list/vehicle-weight checks.

Flutter preview repositories use these same references rather than unrelated parallel demo data.

## Flutter surfaces

Implemented:

- Warehouse Dashboard → `TRF-2026-00218` → Warehouse Transfer Detail
- Dispatch Dashboard → `DSP-2026-00417` → Dispatch Load Detail
- Dispatch Load Detail → existing Delivery Detail handoff

The detail pages show ledger/check/trip gates explicitly. Live mutation buttons remain disabled in preview mode because no dedicated FactoryOS Supabase repository is connected yet; the UI does not pretend that a local preview has executed a production RPC.

## Verification

Accepted code head:

`3764ec31bdb745330d3eee9b504bd81d695f27c1`

Database CI run `38576444179` passed:

- Supabase compatibility bootstrap;
- complete FactoryOS schema/review/command chain through Warehouse/Dispatch review fixes;
- all current fictional seeds;
- hardened RBAC/RLS assertions;
- Warehouse transfer command assertions;
- Dispatch stock/finalization/check/handoff/idempotency assertions.

Flutter CI run `38576444051` passed:

- `flutter analyze --fatal-infos`;
- **59/59 tests**;
- Warehouse Dashboard → Transfer Detail at 1440×1024 with zero render exceptions;
- Dispatch Dashboard → Load Detail → Delivery Detail at 1440×1024 with zero render exceptions;
- four Warehouse/Dispatch domain tests for quantity safety, ledger-pair state, loaded-rate bounds and finalization gates.

## Still not production-complete

- No dedicated FactoryOS Supabase project has been created or connected.
- Warehouse/Dispatch Flutter repositories are still preview adapters.
- The verified RPCs have not yet been exercised through real Supabase Auth/JWT/Data API contexts.
- Supabase security/performance advisors have not been run on a FactoryOS deployment.
- Delivery return → approved `customer_return` → Warehouse receipt remains to be verified as a deployed full E2E workflow.
- POD storage and mobile scanner/camera integrations remain pending.

## Next dependency order

1. Create/connect a dedicated FactoryOS Supabase project only after organization/cost confirmation; never reuse `janseva-production`.
2. Deploy the verified schema chain including Warehouse/Dispatch migrations and run real Auth/JWT/RLS/RPC/security-advisor tests.
3. Replace preview Auth and operational repositories with Supabase-backed implementations.
4. Verify the complete Dispatch → Trip → Delivery → Return → Warehouse workflow against the deployed environment.
5. Continue trusted FCM dispatch, live Reporting aggregates/exports, POD/scanner platform integration and production E2E QA.

**This is a verified repository/local-PostgreSQL transaction milestone, not a deployed-Supabase or production-completion claim.**
