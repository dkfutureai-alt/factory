# Phase 4 — Inventory

## Status

**In development.**

Phase 4 turns the `inventory` module into a ledger-backed factory stock workflow.

Business flow:

`Categories/Units → Item master → Stock locations → Receive → Issue → Transfer → QR/Barcode scan → Stock ledger → Reorder alerts → Inventory reports`

## Design-first screen specification

The Phase 4 UI follows the existing FactoryOS design system: clean Material surfaces, compact cards, clear status chips, responsive desktop tables and simple mobile-first actions.

### Admin — Inventory dashboard

- Header: Inventory + active factory filter.
- KPI row: active items, stock quantity, low-stock items, today's movements.
- Exception panel: low stock and zero stock first.
- Recent movement list: transaction type, item, location, quantity, timestamp and actor.
- Primary actions: Receive, Issue, Transfer, Scan.

### Admin — Item master

- Search by item name, SKU or scan code.
- Filters: category, item type, active/inactive.
- Columns/cards: item, SKU, category, unit, total stock, reorder level, status.
- Editor fields: name, SKU, category, base unit, item type, barcode, QR code, reorder level/reorder quantity, notes, active status.
- Historical items are deactivated rather than destructively deleted.

### Admin — Locations

- Factory-scoped location cards/table.
- Location types: warehouse, bin, production, quality, dispatch, vehicle, quarantine, other.
- Location code is unique per organization/factory.
- Factory Manager can manage only assigned factories.

### Admin — Stock movement workspace

- Receive: destination, item, quantity, unit cost, external reference, notes.
- Issue: source, item, quantity, reference, notes.
- Transfer: source → destination, item, quantity, reference, notes.
- Server rejects negative/insufficient stock and cross-factory invalid transfers.
- Successful movements show immutable transaction reference.

### Admin — Ledger and reports

- Date range, factory, location and item filters.
- Running movement list with signed quantity.
- Current balance report aggregated from ledger entries.
- Reorder report highlights items where available stock is at/below configured reorder level.

### Mobile — Inventory scan

- Large scan action using camera barcode/QR detection.
- Manual code entry remains available for industrial handheld scanners and damaged labels.
- Scan result: item identity, SKU, category, unit, current accessible-location balances.
- Supervisors/employees can scan/read; stock write actions are role-protected by the backend.

## Data model

- `inventory_categories` — organization item category master.
- `inventory_units` — units of measure.
- `inventory_items` — SKU/item master with optional barcode and QR code.
- `stock_locations` — factory-scoped warehouses/bins/production/quality/dispatch locations.
- `inventory_transactions` — immutable movement headers.
- `stock_ledger_entries` — immutable signed stock entries; source of truth for quantity.
- `inventory_reorder_rules` — per-factory reorder threshold and recommended reorder quantity.

## Ledger rules

- Receive creates a positive ledger entry at one destination location.
- Issue creates a negative ledger entry at one source location and is blocked when stock is insufficient.
- Transfer creates two entries in one transaction: negative source + positive destination.
- Direct authenticated writes to ledger tables are denied; movement RPCs own the write path.
- Quantities are positive decimal inputs; signed deltas exist only inside ledger entries.
- Current stock is derived from the ledger, never from editable dashboard counters.

## Permission model

- Platform Owner / Organization Admin: organization-wide inventory management.
- Factory Manager: manage inventory for assigned factories.
- Supervisor: read assigned-factory inventory, scan items and review stock/ledger.
- Employee: read/scan inventory for assigned factories.
- Driver: no inventory module by default.
- Cross-tenant and cross-factory access remains protected by RLS.

## Atomic RPCs

- `inventory_receive_stock(...)`
- `inventory_issue_stock(...)`
- `inventory_transfer_stock(...)`
- `inventory_lookup_scan(...)`
- `inventory_dashboard_summary(...)`
- `inventory_stock_report(...)`
- `inventory_movement_report(...)`
- `inventory_reorder_report(...)`

## Auditability

Master-data changes and every stock transaction are written to the shared audit stream. Ledger rows remain immutable after creation.

## Completion gate

Phase 4 is complete only when:

- clean Supabase reset/migrations/seed passes;
- inventory SQL smoke tests pass;
- real authenticated RLS/movement flow passes;
- admin inventory analysis and web build pass;
- mobile inventory scanner analysis passes;
- insufficient-stock and cross-factory movement denial are tested.
