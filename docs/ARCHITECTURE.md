# FactoryOS System Architecture

## 1. Architectural Goals

FactoryOS is designed as a reusable commercial platform for multiple factory clients. The architecture must remain:

- multi-tenant
- modular
- configurable
- white-label ready
- auditable
- secure by default
- usable on intermittent mobile connectivity
- capable of real operational reporting

## 2. Application Surfaces

### Admin Web
Responsive management portal for company owners, factory managers and department managers.

Responsibilities:
- master data
- approvals
- operational monitoring
- production, inventory, sales, purchase and logistics control
- HR and maintenance administration
- reporting
- configuration

### Mobile App
Role-aware Flutter application for operational users.

Primary modes:
- Employee
- Supervisor
- Driver

The home experience and available actions are derived from effective permissions, not from hardcoded account names.

## 3. Backend

Primary backend: PostgreSQL through Supabase.

Core backend responsibilities:
- Auth integration
- relational data model
- RLS tenant enforcement
- transactional business functions
- secure file storage
- realtime updates where operationally useful
- server-side reporting/aggregation
- audit data

FCM may be used for push notifications. Supabase remains the source of operational truth.

## 4. Layering

### Presentation
Flutter widgets, responsive layouts, role-aware navigation, forms, tables, charts, scanner and offline state.

### Application
Use-case services orchestrating domain workflows such as:
- receive goods
- issue production material
- complete production batch
- approve leave
- assign vehicle
- start trip
- record fuel
- complete delivery
- close maintenance job

### Domain
Typed domain entities and policies independent of UI:
- Organization
- Factory
- Employee
- Item
- Batch
- ProductionOrder
- QualityCheck
- SalesOrder
- Vehicle
- Trip
- Delivery
- Asset
- MaintenanceJob
- Approval

### Infrastructure
- Supabase repositories
- storage client
- auth/session adapter
- notification adapter
- offline sync adapter
- scan/barcode adapter
- logging/telemetry adapter

## 5. Multi-Tenant Context

Every business record that belongs to a client must carry `organization_id` directly or inherit it through a parent that is safely enforced.

Most operational tables also carry `factory_id` when factory scope matters.

The active application context consists of:
- authenticated user
- organization membership
- selected/assigned factory
- roles
- effective permissions
- enabled modules

The UI may hide unavailable actions, but database policies are authoritative.

## 6. Module Boundaries

### Platform
Organizations, factories, memberships, roles, permissions, settings, module configuration, numbering, audit, notifications.

### HR
Employees, departments, designations, shifts, attendance, leave, holidays, documents.

### Inventory
Items, categories, units, batches, serials, warehouse locations, balances, stock transactions.

### Purchase
Purchase requests, approvals, purchase orders, goods receipts, supplier invoices/returns.

### Production
Production orders, material requirements, material consumption, production batches, outputs, wastage.

### Quality
Inspection plans/checks, results, holds, rejections, corrective actions.

### Sales
Customers, quotations, sales orders, invoices, payments, returns.

### Warehouse / Dispatch
Pick/pack, transfer, dispatch, loading, delivery preparation.

### Fleet / Logistics
Vehicles, drivers, assignments, inspections, trips, fuel, breakdowns, deliveries, POD.

### Maintenance
Assets, schedules, work orders, parts consumption, downtime, root cause and cost.

### Reporting
Server-side aggregations over operational source records.

## 7. Inventory Invariant

Inventory quantity is never changed without a stock transaction.

Balance formula:

`opening + receipts - issues +/- adjustments = current balance`

`inventory_balances` is a derived operational balance/cache. `stock_transactions` is the historical ledger.

Critical stock mutations should run in database transactions or RPC functions so the business event and ledger remain atomic.

## 8. Atomic Workflows

Examples requiring transactional execution:

### Goods Receipt
1. validate purchase order and receipt
2. create goods receipt lines
3. create batch/serial records when required
4. create stock transactions
5. update inventory balances
6. update PO received quantities/status

### Production Completion
1. validate order/batch state
2. validate available material
3. consume raw materials
4. record wastage/rejection
5. create finished-goods batch/output
6. create stock transactions
7. update balances
8. update production status

### Delivery Completion
1. validate dispatch/trip/delivery state
2. record delivered quantities
3. record POD
4. mark delivery completed/partial/failed
5. update dispatch/order fulfillment state
6. append audit event

## 9. Approval Engine

One reusable approval model handles leave, expense, purchase request, stock adjustment, overtime, maintenance approval and exceptional dispatch.

Lifecycle:
`draft -> submitted -> in_review -> approved|rejected|cancelled`

Approval history is append-oriented and auditable.

## 10. Audit

Important writes emit audit records containing:
- actor
- organization/factory
- entity type/id
- action
- old values where appropriate
- new values where appropriate
- timestamp
- request/session metadata where appropriate

Normal users cannot delete audit records.

## 11. Offline Strategy

Offline-first is targeted only where operational value is high:
- attendance
- assigned driver trip actions
- fuel entry
- delivery/POD capture
- barcode/QR scan events

Offline writes use a client-generated idempotency key. Synchronization must reject duplicate replays.

## 12. Search and Scale

Large tables use:
- server-side filtering
- indexed sort fields
- bounded pagination
- search indexes appropriate to data type
- date/factory/warehouse/status filters

Do not fetch entire operational tables into the client.

## 13. Configuration

Organization settings should eventually control:
- company identity and branding
- currency
- timezone
- financial year
- numbering patterns
- enabled modules
- factories/warehouses
- tax settings
- default language
- support information

## 14. White Label

Brand configuration is data-driven and may provide:
- application display name
- organization logo
- primary/secondary colors
- report/invoice headers
- support details

No client branding should require rebuilding domain logic.

## 15. Repository Structure

```text
apps/
  admin_web/
  mobile/
packages/
  factoryos_core/
supabase/
  migrations/
  seed/
  tests/
docs/
  ARCHITECTURE.md
  RBAC_AND_TENANCY.md
  BUSINESS_FLOWS.md
  WORK_LOG.md
```

## 16. Definition of Done

A feature is not complete merely because UI renders. It requires database integration, permissions, validation, realistic seed data, loading/error states and verified workflow behavior.