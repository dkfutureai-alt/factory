# Phase 5 — Production

## Status

**Complete at the core application/database level and CI validated.**

Phase 5 connects the factory production floor directly to the existing Inventory and HR foundations.

Business flow:

`Product/BOM or Recipe → Work Centers/Machines → Production Orders → Material Issue/Consumption → Batch & Shift Execution → WIP → Production Output → Scrap/Downtime → Finished Goods Receipt → Production Reports`

## Design-first implementation

The Production experience follows the existing FactoryOS industrial design system: responsive Material surfaces, strong operational hierarchy, live database metrics, simple mobile actions and no decorative fake KPIs.

### Admin — Production dashboard

Implemented live database-backed cards for:

- active production orders;
- today's good output;
- work-in-progress quantity;
- scrap quantity;
- downtime minutes;
- quick actions for new order, start batch, material issue and output receipt.

### Admin — Product / BOM / Recipe

Implemented:

- output product selection from Inventory Item Master;
- recipe/BOM name and version;
- standard output/yield quantity;
- component list with quantity required and scrap allowance;
- active/inactive recipe lifecycle;
- organization-admin control of shared BOM masters.

### Admin — Work centers / machines

Implemented factory-scoped work centers with:

- machine, line, station, area and other types;
- code, capacity/hour and notes;
- assigned-factory management scope.

### Admin — Production orders

Implemented:

- product/recipe, factory and work-center selection;
- planned quantity and priority;
- planned and actual execution timestamps;
- planned / in-progress / paused / on-hold / completed / cancelled states;
- manager/admin-only production-order creation.

### Batch & shift execution

Implemented:

- start batch from an open production order;
- optional HR shift and operator linking;
- pause/resume/complete controls;
- batch allocation cannot exceed the order plan;
- production output cannot exceed the batch plan;
- batch completion is blocked until the full planned quantity is accounted for as good output + scrap;
- order completion occurs when all active batches are closed and the planned processing quantity is fully accounted for.

### Material issue / consumption

Production does not maintain a second stock counter.

Material issue writes an immutable Inventory transaction + Stock Ledger entry and then records the production consumption reference. Source balance uses a transaction-scoped advisory lock and is checked before stock is consumed, preventing negative stock under concurrent writes.

### WIP

WIP is derived from:

`planned order quantity − good output − scrap output`

It is never an editable dashboard field.

### Output / finished goods

Good production output posts an Inventory receive transaction and positive ledger entry at the selected finished-goods location in the same server operation. Scrap is recorded separately as a production loss event.

### Scrap and downtime

Implemented immutable production history for:

- scrap quantity, reason code and remarks;
- downtime batch/work-center link, reason code, remarks, start time and duration minutes.

### Mobile production floor

The mobile app now provides a real Production module. Assigned employees/supervisors can:

- view active orders and WIP;
- start a batch against an existing order;
- issue BOM materials;
- record good output and scrap;
- post finished goods to Inventory;
- log downtime;
- pause/resume/complete batches.

Employees do not receive general Inventory write privileges. Production-specific server RPCs can write only the ledger records required by an approved production operation.

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

- Platform Owner / Organization Admin: shared recipe/BOM masters plus organization-wide factory production management.
- Factory Manager: work centers, production orders and production execution only in assigned factories.
- Supervisor: production execution in assigned factories.
- Employee: production execution in assigned factories when Production is enabled.
- Driver: Production is not enabled by default.
- Cross-tenant and cross-factory access is protected by RLS and server-side permission validation.

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

## Auditability

Recipe/BOM masters, work centers, production orders, batches, material issues, outputs, scrap and downtime are written into the shared audit stream. Material-issue/output inventory transactions remain traceable through their linked inventory transaction IDs.

## Demo data

The fictional Aarohan Solapur Plant now includes:

- Filled Medical Oxygen Cylinder 47L finished product;
- 47L oxygen filling recipe/BOM;
- empty cylinder, medical oxygen and valve components;
- filling line, cylinder preparation station and final inspection station;
- planned and in-progress production orders;
- running batch and HR shift/operator link;
- realistic material consumption;
- finished-goods receipt into Inventory;
- scrap and downtime records.

All dashboard/report values are database-driven.

## Validation

Passed in CI:

- invitation Edge Function Deno check;
- clean local Supabase start and reset;
- migrations `0001` through `0012`;
- base seed plus Phase 5 production seed;
- foundation/access/HR/inventory/production SQL smoke tests;
- production RLS/table/RPC existence checks;
- immutable production history enforcement;
- real employee/manager signup → password login → JWT → PostgREST flow;
- Factory Manager production-order creation;
- employee production-order creation denial;
- assigned employee production batch start;
- assigned employee production material issue;
- BOM requirement accounting;
- production over-consumption / negative-stock denial;
- assigned employee finished-goods receipt;
- production output-over-plan denial;
- assigned employee batch completion;
- ledger-derived production Inventory balance verification;
- Factory Manager cross-factory production denial;
- shared Flutter core analysis/tests;
- admin dependencies and analysis;
- admin release web build;
- mobile dependencies and analysis with Production execution linked from the module grid.

## Next

Phase 6 — Quality: inspection plans/checklists → incoming/in-process/final inspection → sample/results → pass/fail/hold → NCR/deviation → quarantine/release → certificate/quality reports.
