# Phase 5 — Production

## Status

**In development and validation.**

Phase 5 connects the factory production floor directly to the existing Inventory and HR foundations.

Business flow:

`Product/BOM or Recipe → Work Centers/Machines → Production Orders → Material Issue/Consumption → Batch & Shift Execution → WIP → Production Output → Scrap/Downtime → Finished Goods Receipt → Production Reports`

## Design-first direction

The Production experience follows the existing FactoryOS industrial design system: responsive Material surfaces, strong operational hierarchy, live database metrics, simple mobile actions and no decorative fake KPIs.

### Admin — Production dashboard

- Active production orders.
- Today's good output.
- Work-in-progress quantity.
- Scrap quantity.
- Downtime minutes.
- Quick actions for new order, start batch, material issue and output receipt.

### Admin — Product / BOM / Recipe

- Output product selection from Inventory Item Master.
- Recipe/BOM name and version.
- Standard output/yield quantity.
- Material/component list with quantity required and scrap allowance.
- Historical recipes use active/inactive state rather than destructive deletion.

### Admin — Work centers / machines

- Factory-scoped work centers.
- Types: machine, line, station, area or other.
- Code, capacity/hour and notes.
- Factory Manager scope follows assigned factories.

### Admin — Production orders

- Product/recipe, factory and work center.
- Planned quantity and priority.
- Planned and actual execution timestamps.
- Status lifecycle: planned → in progress / paused / on hold → completed / cancelled.
- Production order creation remains manager/admin controlled.

### Batch & shift execution

- Start a production batch from an open production order.
- Optional shift and operator linking from HR.
- Production operators can pause/resume/complete assigned-factory batches.
- Batch plan cannot exceed the order plan.
- Output cannot exceed the batch plan.

### Material issue / consumption

Production does not maintain a second stock counter.

Material issue writes an immutable Inventory transaction + Stock Ledger entry and then records the production consumption reference. Source balance is locked and checked inside the same database transaction before stock is consumed.

### WIP

WIP is derived from:

`planned order quantity − good output − scrap output`

It is not an editable dashboard field.

### Output / finished goods

Good production output posts an Inventory receive transaction and positive ledger entry at the selected finished-goods location. Scrap is recorded separately as a production loss event.

### Downtime

Downtime events record batch, work center, reason code, remarks, start time and duration minutes.

### Mobile production floor

Assigned employees/supervisors can:

- view active orders and WIP;
- start a batch against an existing order;
- issue BOM materials;
- record good output and scrap;
- post finished goods to inventory;
- log downtime;
- pause/resume/complete batches.

Employees do not gain general Inventory write privileges. Production-specific server RPCs perform only the ledger writes required by the approved production operation.

## Data model

- `production_recipes`
- `production_recipe_components`
- `work_centers`
- `production_orders`
- `production_batches`
- `production_material_issues`
- `production_outputs`
- `production_scrap_events`
- `production_downtime_events`

Production orders/batches keep operational state. Material issue, output, scrap and downtime history are immutable.

## Permission model

- Platform Owner / Organization Admin: shared recipe/BOM masters plus factory production management.
- Factory Manager: work centers, production orders and production execution in assigned factories.
- Supervisor: production execution in assigned factories.
- Employee: production execution in assigned factories when the Production module is enabled.
- Driver: Production is not enabled by default.
- Cross-tenant and cross-factory access is protected with RLS and server-side permission checks.

## Atomic RPCs / reports

- `production_create_order(...)`
- `production_start_batch(...)`
- `production_issue_material(...)`
- `production_record_output(...)`
- `production_log_downtime(...)`
- `production_set_batch_status(...)`
- `production_dashboard_summary(...)`
- `production_order_report(...)`
- `production_bom_requirements(...)`

## Demo data

The fictional Aarohan Solapur Plant includes a 47L medical oxygen cylinder recipe, filling/preparation/final-inspection work centers, planned/in-progress production orders, a running batch, material consumption, finished-goods receipt, scrap and downtime records.

## Completion gate

Phase 5 is complete only when:

- clean Supabase start/reset succeeds;
- migrations and both fictional seed files load;
- all foundation/access/HR/inventory/production SQL smoke tests pass;
- production history immutability passes;
- real JWT/RLS production flow passes;
- manager production-order creation passes;
- employee order-creation denial passes;
- assigned employee batch execution passes;
- BOM requirement accounting passes;
- material over-consumption / negative-stock denial passes;
- output-over-plan denial passes;
- finished-goods Inventory receipt and ledger balances pass;
- Factory Manager cross-factory production denial passes;
- admin analysis and release web build pass;
- mobile analysis with production execution passes.
