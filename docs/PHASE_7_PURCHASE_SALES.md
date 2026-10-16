# Phase 7 — Purchase & Sales

Status: **complete and CI validated**.

## Workflow

Phase 7 connects the commercial flow to the existing Inventory and Quality truth:

**Supplier/Customer → Purchase Requisition → Purchase Order → Goods Receipt → Incoming Quality → Inventory Release → Supplier Invoice/Payment → Quotation → Sales Order → Stock Allocation → Dispatch Readiness → Customer Invoice/Payment → Reports**

The screen/system design was created before implementation and the final Admin/Mobile surfaces preserve the existing FactoryOS visual system.

## Backend

Migration: `supabase/migrations/0014_purchase_sales.sql`

Core tables:

- `business_partners`
- `purchase_requisitions`
- `purchase_requisition_lines`
- `purchase_orders`
- `purchase_order_lines`
- `goods_receipts`
- `goods_receipt_lines`
- `supplier_invoices`
- `supplier_payments`
- `quotations`
- `quotation_lines`
- `sales_orders`
- `sales_order_lines`
- `sales_allocations`
- `customer_invoices`
- `customer_payments`

All tenant/factory transactional tables use RLS. Commercial write operations run through security-definer RPCs with factory/role checks; business-partner master edits are restricted by organization roles.

## Purchase

- Supervisors/managers can create purchase requisitions for assigned factories.
- Manager approval is required before an approved requisition can be converted to a Purchase Order.
- Purchase Orders support supplier, expected date, currency, multiple items, price and tax.
- Goods receipt validates remaining ordered quantity and posts Inventory `receive` transactions plus signed stock-ledger entries atomically.
- A receipt line can require incoming Quality. In that case an active incoming inspection plan is mandatory and an inspection is created automatically.
- Goods Receipt status follows linked Quality results: pending, passed or hold.
- Passed/non-QC receipts can be released to an available warehouse using an atomic Inventory transfer.
- Supplier invoices are derived from PO values and supplier payments cannot exceed outstanding value.
- Supplier payment history is immutable.

## Sales

- Quotations support customer, validity, multiple items, quantity, unit price and tax.
- Sent/accepted quotations convert atomically to Sales Orders.
- Sales allocation reserves ledger-derived stock without prematurely issuing Inventory.
- Allocation uses transaction-scoped locking and subtracts other active reservations from available stock.
- Dispatch readiness requires all Sales Order lines to be fully allocated.
- Customer invoices are allowed only from dispatch-ready/dispatched/completed orders.
- Customer payments cannot exceed invoice outstanding value and payment history is immutable.

Actual physical dispatch/Inventory issue is intentionally left for the Dispatch/Delivery phase; Phase 7 stops at **dispatch readiness**.

## Reports

Database report surfaces:

- `commercial_dashboard_summary`
- `purchase_order_report`
- `sales_order_report`
- `commercial_partner_ledger`

Admin dashboards use database/RPC data rather than hardcoded KPIs.

## Admin Web

`apps/admin_web/lib/purchase_sales_management.dart`

Connected sections:

- Dashboard
- Suppliers & Customers
- Purchase Requisitions
- Purchase Orders
- Goods Receipt / Incoming Quality
- Supplier Invoices & Payments
- Quotations
- Sales Orders
- Stock Allocation / Dispatch Readiness
- Customer Invoices & Payments
- Purchase & Sales Reports

The module is connected when either the Purchase or Sales organization module is enabled.

## Mobile

`apps/mobile/lib/commercial_operations.dart`

Supervisor/manager operations include:

- receive PO quantities;
- select receiving/Incoming-QC location;
- start incoming inspection automatically when required;
- release passed goods to Inventory;
- allocate Sales Order stock;
- mark fully allocated Sales Orders dispatch ready.

Purchase and Sales module cards route to the same operational commercial workspace.

## Demo Data

`supabase/seed_phase7.sql`

The fictional demo includes:

- two suppliers and two customers;
- a PPE requisition and received PO;
- an Incoming Quality location;
- a gloves incoming inspection plan/checklist and passed inspection;
- ledger-backed receipt and release to Raw Material Store;
- supplier invoice and partial payment;
- customer quotation converted to a Sales Order;
- finished-goods stock allocation and dispatch-ready order;
- customer invoice and payment.

No real person/company data is used.

## Automated Validation

SQL smoke coverage: `supabase/tests/0014_purchase_sales_smoke.sql`

Authenticated E2E: `supabase/tests/purchase_sales_auth_e2e.sh`

Validated behaviors include:

- employee requisition denial;
- supervisor requisition creation;
- manager approval;
- supervisor PO-creation denial;
- manager PO creation/send;
- supervisor goods receipt;
- automatic incoming Quality creation;
- Quality completion synchronizing GRN state;
- ledger-backed GRN release;
- supplier invoice/payment;
- quotation → Sales Order conversion;
- employee allocation denial;
- supervisor stock allocation and dispatch readiness;
- customer invoice/payment;
- Factory Manager cross-factory commercial denial.

Final CI validation passed:

- clean Supabase start/reset;
- migrations `0001`–`0014`;
- base + Phase 5 + Phase 6 + Phase 7 seed layers;
- all SQL smoke/integrity tests;
- full authenticated HR → Inventory → Production → Quality → Purchase/Sales flow;
- shared Flutter core analyze/tests;
- Admin Analyze;
- Admin release web build;
- Mobile Analyze.

## Next

Phase 8: Warehouse — warehouse/zone/bin structure, put-away, stock reservation/availability, pick lists, staging, dispatch handoff, cycle counts, stock adjustments and warehouse reports while preserving the Inventory ledger as stock truth.
