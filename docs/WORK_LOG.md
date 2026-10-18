# FactoryOS Work Log

## 2026-10-14 — Phase 0

- Repository initialized.
- Audit confirmed no application code, schema or tests existed.
- Product goal and development sequence recorded in README.

## 2026-10-15 — Phase 1 Rework

- Re-inspected `main`; only README and the initial commit were present.
- Re-established repository state as source of truth rather than assuming prior chat work had been committed.
- Created Phase 1 architecture, tenancy/RBAC, business-flow and design-system documentation.
- Added core Supabase migration with organizations, factories, profiles, membership, module catalog and audit logs.
- Added RLS helper functions and tenant policies.
- Added fictional seed tenant/factory data and SQL smoke checks.
- GitHub Actions validation passed: Supabase start/reset, migrations, seed and foundation smoke checks.

## 2026-10-15 — Phase 2 Authentication + Management

- Added shared Flutter core package with roles, module model and theme tokens.
- Added Supabase-aware responsive admin web and employee mobile shells.
- Added email/password authentication and current Supabase `publishableKey` configuration.
- Added Organization Admin/Platform Owner organization settings and factory create/edit/soft-deactivate management.
- Added server-side organization/factory access audit logging.
- Added invitation records with expiry, lifecycle state, requested role and requested factory assignments.
- Added server-side `invite-user` Supabase Auth Edge Function; service credentials remain server-side only.
- Added first-login onboarding on Admin Web and Mobile for profile, phone and password completion.
- Added atomic invitation acceptance that activates organization membership and factory assignments.
- Added Admin Users & Access UI for invitation, role reassignment, factory reassignment, invitation revocation and access deactivation.
- Added role-escalation protection so Organization Admins cannot create Platform Owners or remove their own admin role.
- Tightened Factory Manager membership management to factories actually assigned to that manager.
- Kept employee factory reads restricted to assigned factories through RLS.
- Added role-aware mobile module visibility.
- Expanded audit logging to invitation, organization-member and factory-member changes.
- Added SQL tests for invitation acceptance, role/factory reassignment, escalation denial and Factory Manager scope.
- Added Edge Function Deno type-checking to CI.
- Added real local Supabase authentication validation: signup -> password login -> JWT -> PostgREST -> assigned-factory-only RLS.
- Validation passed: Supabase Edge Function check/start/reset/migrations/seed/all SQL smoke tests/real Auth+RLS flow; shared core analysis and 5 permission tests; admin analysis; admin release web build; mobile analysis.

### Phase 2 status

Core access workflow is complete and validated. Production SMTP/invite redirects and Android/iOS release configuration remain deployment/release configuration tasks.

## 2026-10-15 — Phase 3 HR + Attendance + Leave

- Created the Phase 3 HR design direction before implementation.
- Added departments, designations, shifts, employees, leave types, leave requests, holidays and attendance records.
- Added realistic fictional HR demo data for the Aarohan Solapur Plant.
- Added tenant/factory RLS for HR records and factory-scoped shift/holiday visibility.
- Added employee records that can exist without app accounts, plus optional secure FactoryOS-user linking.
- Added same-organization manager integrity and designation/department + shift/factory validation.
- Added admin HR workspace: live KPIs, employees, attendance, leave, masters, holidays and reports.
- Added mobile HR self-service: employee profile, check-in/out, attendance history, leave requests/cancellation and holidays.
- Added timezone-aware/night-shift-aware self attendance with grace handling.
- Added atomic manager attendance correction and database attendance normalization.
- Added employee leave request validation, overlap protection, manager decisions and approved-leave attendance marking.
- Added HR dashboard, attendance, headcount and leave report database functions.
- Added HR audit triggers into the shared audit log.
- Added SQL smoke tests for schema/RLS/integrity/normalization/report surfaces.
- Extended real Auth+RLS CI through employee HR isolation, self-profile, self check-in, leave requests, factory-manager attendance correction and cross-factory denial.
- Added workflow concurrency so superseded Supabase validation runs are cancelled.
- Flutter validation passed: shared tests, admin analysis, admin release web build and mobile analysis.
- Supabase validation passed: Edge Function check, clean start/reset, all migrations, seed, all SQL tests and real JWT/RLS HR flow.

### Phase 3 status

Core HR, attendance, leave, holiday and report workflows are complete and validated.

## 2026-10-15 — Phase 4 Inventory

- Created the Phase 4 inventory workflow and screen specification before implementation.
- Added organization category/unit/item masters with SKU, item type, barcode, QR code and batch-tracking metadata.
- Added factory-scoped stock locations for warehouse/bin/production/quality/dispatch/vehicle/quarantine use cases.
- Added immutable inventory transactions and signed stock-ledger entries as the only stock source of truth.
- Added atomic receive, issue and transfer RPCs with role/factory validation.
- Added transaction-scoped balance locking and insufficient-stock rejection for issue/transfer.
- Added factory reorder rules plus dashboard, stock, movement and reorder report functions.
- Added scan lookup by SKU/barcode/QR code with assigned-factory filtering.
- Added inventory master/transaction audit logging and immutable transaction/ledger protection.
- Added realistic fictional gas-factory inventory demo data: oxygen, CO2, cylinders, valves, PPE, warehouses, production/QC/dispatch locations and opening balances.
- Added responsive Admin Inventory workspace with dashboard, items, locations, movements, reorder rules, masters and reports.
- Added role-aware admin inventory actions: organization masters for Organization Admin/Platform Owner, factory operations for assigned Factory Managers and read-only supervisor access.
- Added mobile camera barcode/QR scanning and manual code entry for industrial handheld scanners.
- Connected inventory scanning to the mobile Inventory module and main Scan tab.
- Added inventory schema/RLS/RPC/immutability SQL smoke coverage.
- Added real authenticated inventory E2E validation chained to the existing employee/manager JWT flow.
- Authenticated validation covers employee scan scope, manager receive/transfer/issue, ledger-derived balances, insufficient-stock rejection, cross-factory denial and employee write denial.
- Flutter validation passed: shared analysis/tests, admin analysis, admin release web build, mobile dependencies and mobile analysis.
- Supabase validation passed: Edge Function check, clean start/reset, all migrations/seed, all SQL smoke tests and the complete real Auth/RLS/inventory flow.

### Phase 4 status

Core Inventory is complete and validated.

## 2026-10-15 — Phase 5 Production

- Created the Production screen/system design before implementation, preserving the existing FactoryOS visual language and mobile-first operations pattern.
- Reused Inventory Item Master as the product/material source rather than creating a duplicate product catalog.
- Added versioned production recipes/BOMs with output yield, material quantities and scrap allowance.
- Added factory-scoped work centers/machines/lines/stations with capacity metadata.
- Added production orders with product/recipe, work center, planned quantity, priority and lifecycle timestamps/status.
- Added production batches linked to optional HR shifts and operators.
- Added production-specific operator permissions so assigned supervisors/employees can execute production without receiving general Inventory write access.
- Added immutable material-consumption history backed by the existing Inventory transaction + signed stock ledger.
- Added transaction-scoped stock locking and insufficient-stock rejection for production material issue.
- Added production output recording with good/scrap quantities, lot/batch reference and atomic finished-goods Inventory receipt.
- Added immutable scrap and downtime event history.
- Added derived WIP, production dashboard, order report and BOM-requirement report functions.
- Hardened batch completion so the full batch plan must be accounted for before completion; order completion uses total processed quantity (good + scrap).
- Added audit logging for production masters and operational records.
- Added fictional oxygen-cylinder production demo data, including a 47L fill recipe, filling/preparation/QC work centers, orders, active batch, consumption, finished output, scrap and downtime.
- Added responsive Admin Production workspace with dashboard, BOM/recipes, work centers, orders, execution and reports.
- Added mobile Production execution workflow linked from the role-aware module grid.
- Mobile production supports batch start, BOM material issue, output/scrap receipt, downtime and pause/resume/complete actions.
- Added Phase 5 SQL smoke coverage for schema/RLS/RPCs, seed balances, recipe integrity and immutable production history.
- Added real authenticated Production E2E coverage for manager order creation, employee order-creation denial, employee batch execution, BOM accounting, negative-stock rejection, finished-goods receipt, output-over-plan rejection, batch completion, ledger balance verification and cross-factory denial.
- Flutter validation passed: shared analysis/tests, admin analysis, admin release web build and mobile analysis with Production linked.
- Supabase validation passed: Edge Function check, clean start/reset, migrations `0001`–`0012`, base + Phase 5 seeds, every SQL smoke test and the complete authenticated HR/Inventory/Production chain.

### Phase 5 status

Core Production is complete and validated.

## 2026-10-16 — Phase 6 Quality

- Created the Quality dashboard design before implementation and preserved the existing FactoryOS visual system.
- Added versioned incoming, in-process and final inspection plans linked to Inventory Item Master.
- Added visual, numeric, boolean and text checklist parameters with required state, tolerance ranges, units and acceptance criteria.
- Added factory-scoped inspection execution with optional Production Order/Batch and HR inspector links.
- Added server-derived numeric/boolean pass/fail logic and required-check completion validation.
- Added pass/fail/hold inspection completion state.
- Added NCR/deviation records with severity, category, assignee, root cause, corrective action, status and disposition.
- Added Quality quarantine as an atomic Inventory transfer into quarantine-type stock locations.
- Added supervisor/manager-only quarantine release with linked-NCR closure requirement and Inventory ledger transfer back to released stock.
- Added immutable quality certificates for passed completed inspections with inspection/item/plan/result snapshot data.
- Added Quality dashboard, inspection and NCR reporting functions.
- Added Quality RLS and server permission helpers for view, operate and approve scopes.
- Employees can execute inspections, raise NCRs and quarantine assigned-factory stock without receiving unrestricted Inventory write access.
- Employees cannot release quarantine or issue certificates; supervisor/manager approval is enforced server-side.
- Added fictional Aarohan Quality demo data: final oxygen inspection, incoming valve inspection, in-process oxygen plan, checklist results, failed valve NCR, QC-HOLD quarantine stock and quality certificate.
- Added responsive Admin Quality workspace with dashboard, plans/checklists, inspections, NCR, quarantine/release, certificates and reports.
- Added mobile Quality execution workflow and connected it to the role-aware module grid.
- Added Phase 6 SQL smoke coverage for schema/RPCs, fictional seed integrity, quarantine ledger balance and certificate immutability.
- Added real authenticated Quality E2E validation for employee inspection start, checklist capture, numeric auto-fail, pass/fail completion, employee certificate denial, manager certificate issue, NCR creation, quarantine movement, employee release denial, manager NCR closure/release, ledger balances and cross-factory denial.
- Run/compare/fix found and corrected Admin Flutter analyzer issues.
- Run/compare/fix also corrected an older Production smoke-test assumption so post-Quality valve stock is validated by total stock plus Raw Material/QC-HOLD split.
- Flutter validation passed: shared analysis/tests, Admin Analyze, release web build and Mobile Analyze with Quality linked.
- Supabase validation passed: clean start/reset, migrations `0001`–`0013`, all three seed layers, all SQL smoke tests and the full authenticated HR/Inventory/Production/Quality chain.

### Phase 6 status

Core Quality is complete and validated.

## 2026-10-16 — Phase 7 Purchase & Sales

- Created the Phase 7 Purchase & Sales design before implementation and preserved the existing FactoryOS visual language.
- Added organization business-partner masters for suppliers, customers and dual-role partners.
- Added factory-scoped Purchase Requisitions with multi-line item requests and supervisor/manager creation scope.
- Added manager-only requisition decisions and Purchase Order creation with supplier, ETA, currency, price and tax lines.
- Added Goods Receipt with remaining-quantity validation and atomic Inventory `receive` transaction + stock-ledger entries.
- Added automatic incoming Quality inspection creation when a receipt line requires inspection; an active incoming plan is mandatory.
- Added Quality-to-GRN synchronization for pending/pass/hold results.
- Added Goods Receipt release as an atomic Inventory transfer from Incoming QC/receiving location to available warehouse stock.
- Added Supplier Invoice and immutable Supplier Payment history with overpayment protection.
- Added Quotations with customer, validity, multi-line item pricing and tax.
- Added atomic Quotation-to-Sales-Order conversion.
- Added ledger-derived Sales stock availability and reservation without prematurely issuing Inventory.
- Added transaction-scoped allocation locking and active-reservation subtraction.
- Added Dispatch Readiness requiring every Sales Order line to be fully allocated.
- Added Customer Invoice and immutable Customer Payment history with overpayment protection.
- Added commercial dashboard, Purchase Order report, Sales Order report and partner-ledger database functions.
- Added commercial RLS, server permission helpers and audit logging across partner/purchase/sales/financial records.
- Added fictional Phase 7 data including suppliers/customers, a PPE PR/PO, Incoming QC location, passed gloves inspection, ledger-backed GRN release, supplier billing, quotation, allocated dispatch-ready Sales Order and customer billing.
- Added responsive Admin Purchase & Sales workspace with Dashboard, Partners, Purchase, Goods Receipt, Supplier Billing, Sales, Allocation, Customer Billing and Reports sections.
- Connected Purchase & Sales to existing Admin navigation when either commercial module is enabled.
- Added mobile commercial operations for supervisor/manager goods receipt, incoming-QC release, Sales allocation and Dispatch Readiness.
- Connected both Purchase and Sales module cards to the mobile commercial workspace.
- Added Phase 7 SQL smoke coverage for schema/RLS/seed integrity, ledger movements, RPC surfaces and payment immutability.
- Added real authenticated Phase 7 E2E coverage for employee denial, supervisor PR/GRN/allocation actions, manager approval/PO/financial actions, automatic incoming Quality, GRN status sync, ledger release, dispatch readiness and Factory Manager cross-factory denial.
- Run/compare/fix moved authenticated report-result assumptions out of unauthenticated SQL smoke context.
- Run/compare/fix corrected generated Admin Flutter analyzer errors before release build.
- Supabase validation passed: clean start/reset, migrations `0001`–`0014`, all four seed layers, every SQL smoke test and the full authenticated HR/Inventory/Production/Quality/Purchase/Sales chain.
- Flutter validation passed: shared analyze/tests, Admin Analyze, Admin release web build, Mobile dependencies and Mobile Analyze with commercial navigation connected.

### Phase 7 status

Core Purchase & Sales is complete and validated through **Dispatch Readiness**. Physical dispatch/Inventory issue remains intentionally reserved for the Dispatch/Delivery phase.

### Next

Start Phase 8: Warehouse — warehouse/zone/bin structure -> put-away -> stock availability/reservation -> pick list -> staging -> dispatch handoff -> cycle count -> stock adjustment -> warehouse reports, while preserving the Inventory ledger as stock truth.
## 2026-10-16 — Phase 8 Warehouse

- Created the Warehouse design direction before implementation and preserved the existing FactoryOS visual system.
- Reused `stock_locations` as the canonical warehouse/location hierarchy and added warehouse, zone, bin, receiving and staging semantics plus capacity/aisle/rack/level metadata.
- Added put-away tasks linked to optional Goods Receipts with operational source-stock reservation and ledger-backed source → bin completion.
- Added warehouse pick lists generated from existing Sales allocations instead of introducing a second reservation system.
- Added employee pick confirmation that physically transfers stock into staging and synchronizes the Sales allocation location.
- Added fully-picked staging and supervisor Dispatch handoff while intentionally leaving physical dispatch/Inventory issue for the Dispatch & Delivery phase.
- Added location cycle counts with ledger snapshots, employee count entry/submission, manager approval and stale-snapshot rejection.
- Added manager-only manual stock adjustments with reason validation, negative-stock protection and immutable adjustment history.
- Added Warehouse dashboard, bin stock/on-hand/reserved/available, put-away, pick and cycle-count report RPCs.
- Added Warehouse RLS, factory visibility, employee/supervisor operational permissions, manager approval controls and audit logging.
- Added fictional warehouse zones, bins, receiving/staging, put-away, pick-list and historical cycle-count seed data.
- Added responsive Admin Warehouse workspace with dashboard, locations, put-away, picking/staging/handoff, cycle counts, adjustments and reports.
- Added mobile Warehouse operations for employee put-away, picking, staging and cycle counts plus supervisor Dispatch handoff.
- Added Phase 8 SQL smoke coverage and authenticated Warehouse E2E validation chained after Purchase/Sales.
- Run/compare/fix corrected the missing Phase 8 seed registration in local Supabase configuration.
- Supabase validation passed: clean start/reset, migrations `0001`–`0015`, all five seed layers, every SQL smoke test and full authenticated HR/Inventory/Production/Quality/Purchase/Sales/Warehouse chain.
- Flutter validation passed: shared analysis/tests, Admin Analyze, Admin release web build and Mobile Analyze with Warehouse navigation connected.

### Phase 8 status

Core Warehouse is complete and validated through **Dispatch Handoff**. Physical dispatch/Inventory issue remains intentionally reserved for the Dispatch & Delivery phase.

### Next

Start Phase 9: Vehicles, Drivers, Trips & Fuel — vehicle/driver masters -> assignments -> trip lifecycle -> odometer/fuel controls -> driver mobile workflow -> route/dispatch linkage -> service reminders -> fleet reports.

## 2026-10-18 — Phase 16 Production Release hardening

- Inspected the existing Phase 16 branch, native Android/iOS shells, Firebase client, migration `0040`, and previously successful Flutter, mobile-native and Supabase quality runs.
- Confirmed the connected Supabase account has no dedicated FactoryOS production project; existing Salon/Janseva projects remain untouched.
- Added an independent exact project-ref confirmation and matching FactoryOS URL requirement to guarded production migration/deploy, Android signing and production smoke workflows.
- Added a project URL/ref consistency check to Admin Pages publishing, and moved the web base-href input into a shell environment variable to avoid expression injection; the base href is validated as a normalized safe path.
- Tightened production smoke membership checks to the authenticated test user's own active membership.
- Retired the temporary write-enabled native project generation workflow after committing platform shells.
- Added a pinned actionlint CI gate for release workflows.
- Updated release documentation and status. No production cloud data was mutated.

### Remaining external go-live blockers

- Establish and connect a dedicated FactoryOS production Supabase project, obtain cost/organization approval, configure Auth redirect/SMTP and upload scoped release secrets.
- Set up a production Firebase project/platform registration and configure trusted FCM + APNs.
- Configure GitHub `factoryos-production` environment reviewers, production Admin Pages, signed Android bundle / iOS distribution and store records.
- Run remote migrations, authenticated production smoke and end-to-end user acceptance on that dedicated environment.
