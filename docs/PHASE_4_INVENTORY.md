# Phase 4 — Inventory

## Status

**Complete at the core application/database level and CI validated.**

Phase 4 turns the `inventory` module into a ledger-backed factory stock workflow.

Business flow:

`Categories/Units → Item master → Stock locations → Receive → Issue → Transfer → QR/Barcode scan → Stock ledger → Reorder alerts → Inventory reports`

## Admin experience

The responsive admin portal now contains a dedicated Inventory workspace with:

- live inventory KPIs for active items, ledger quantity, low-stock items and today's movements;
- category and unit masters;
- item/SKU master with item type, barcode, QR value, batch-tracking flag, notes and active status;
- factory-scoped warehouses/stock locations including warehouse, bin, production, quality, dispatch, vehicle, quarantine and other locations;
- receive, issue and transfer dialogs backed by server-side atomic RPCs;
- immutable transaction references and movement history;
- configurable per-factory reorder rules;
- current-stock and low-stock reports derived from ledger entries;
- loading/error/refresh states and role-aware actions.

Organization Admins/Platform Owners manage shared item/category/unit masters. Factory Managers can manage locations, reorder rules and movements only within factories they are assigned to. Supervisors remain read/scan-only.

## Mobile inventory experience

The mobile app now provides a real Inventory scan workflow through both the Inventory module tile and the bottom Scan tab:

- camera barcode/QR scanning;
- manual SKU/barcode/QR entry for industrial handheld scanners or damaged labels;
- item identity, SKU, type and base unit display;
- accessible factory/location stock balances;
- factory-scoped read visibility through RLS;
- employee/supervisor scan access without stock-write privileges.

Mobile platform packaging/permission metadata remains part of the later production-release phase because this repository currently contains the Flutter application source without generated Android/iOS platform projects.

## Data model

- `inventory_categories` — organization item category master.
- `inventory_units` — units of measure and decimal precision.
- `inventory_items` — organization SKU/item master with optional barcode and QR code.
- `stock_locations` — factory-scoped warehouses/bins/production/quality/dispatch locations.
- `inventory_transactions` — immutable movement headers.
- `stock_ledger_entries` — immutable signed stock entries and the source of truth for quantity.
- `inventory_reorder_rules` — per-factory reorder threshold and recommended reorder quantity.

Parent stock locations are validated to remain inside the same organization and factory.

## Ledger rules

- Receive creates one positive ledger entry at the destination.
- Issue creates one negative ledger entry at the source.
- Transfer creates two entries atomically: negative source + positive destination.
- Issue/transfer acquire a transaction-scoped advisory lock for the item/location balance before checking stock.
- Insufficient stock is rejected before a negative balance can be created.
- Direct authenticated inserts/updates/deletes are not granted for transaction/ledger records.
- Transaction and ledger rows are immutable after creation.
- Quantities are positive decimal movement inputs; signed deltas exist only in ledger entries.
- Dashboard and report quantities are calculated from the ledger rather than editable stock counters.

## Permission model

- Platform Owner / Organization Admin: organization-wide inventory master management and factory inventory operations.
- Factory Manager: stock locations, reorder rules and movements only for assigned factories.
- Supervisor: read assigned-factory inventory, scan items and review stock/ledger.
- Employee: read/scan inventory for assigned factories.
- Driver: inventory module is not enabled by default.
- Cross-tenant and cross-factory access is enforced with RLS and role-aware RPC validation.

## Atomic/report RPCs

- `inventory_receive_stock(...)`
- `inventory_issue_stock(...)`
- `inventory_transfer_stock(...)`
- `inventory_lookup_scan(...)`
- `inventory_dashboard_summary(...)`
- `inventory_stock_report(...)`
- `inventory_movement_report(...)`
- `inventory_reorder_report(...)`

## Auditability

Inventory master changes and movement transaction headers are written into the shared audit stream. Historical items use active/inactive state rather than destructive deletion in the UI. Transaction and stock-ledger history is immutable.

## Demo data

The fictional Aarohan Solapur Plant seed now includes:

- industrial gas, cylinder/container, spare and safety-consumable categories;
- KG, PCS, LTR and M3 units;
- oxygen, CO2, cylinder, valve and PPE items with scan codes;
- raw-material, production, finished-goods, quality-hold and dispatch locations;
- reorder rules;
- realistic opening ledger balances.

All UI totals remain database-driven.

## Validation

Passed in CI:

- shared Flutter core analysis/tests;
- admin dependencies and analysis;
- admin release web build;
- mobile dependencies and analysis with camera barcode/QR scanner integration;
- invitation Edge Function Deno check;
- clean local Supabase start/reset;
- all migrations and fictional seed load;
- all foundation/access/HR/inventory SQL smoke tests;
- inventory schema/RLS/RPC existence checks;
- immutable stock-ledger enforcement;
- real employee signup/password-login/JWT flow;
- employee inventory scan restricted to assigned factory;
- Factory Manager receive RPC;
- Factory Manager transfer RPC;
- Factory Manager issue RPC;
- ledger-derived post-movement balance verification;
- insufficient-stock rejection;
- Factory Manager cross-factory inventory rejection;
- employee inventory-write rejection.

## Next

Phase 5 — Production: product/BOM or recipe setup → work centers/machines → production orders → material issue/consumption → batch/shift execution → WIP/output → scrap/downtime → finished-goods receipt → production reports.
