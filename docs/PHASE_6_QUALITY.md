# Phase 6 — Quality

## Status

**Complete at the core application/database level and CI validated.**

Phase 6 connects inspection and quality disposition directly to existing Production, Inventory, HR, tenancy and audit foundations.

Business flow:

`Inspection Plans & Checklists → Incoming / In-Process / Final Inspection → Sampling & Results → Pass / Fail / Hold → NCR / Deviation → Quarantine → Release / Disposition → Quality Certificate → Quality Reports`

## Design-first implementation

The Quality module was designed before implementation using the existing FactoryOS industrial design system: responsive Material surfaces, clean operational hierarchy, mobile-first floor actions, database-backed metrics and no hardcoded release KPIs.

### Admin — Quality dashboard

Implemented live metrics for:

- inspections today;
- passed inspections;
- failed inspections;
- held inspections;
- open NCRs;
- quarantined quantity.

Quick actions start inspections, create NCRs and move failed/held stock into quarantine.

### Inspection plans & checklists

Implemented organization-scoped versioned inspection plans linked to Inventory Item Master.

Supported plan types:

- incoming;
- in-process;
- final.

Supported sampling methods:

- full / 100%;
- fixed sample;
- percentage;
- AQL metadata.

Checklist parameters support:

- visual checks;
- numeric tolerance checks;
- boolean / yes-no checks;
- text checks;
- required/optional state;
- min/max/target/unit metadata;
- acceptance criteria.

Shared plan/checklist masters are restricted to Platform Owner / Organization Admin management.

### Inspection execution

Implemented factory-scoped inspections with:

- plan and item selection;
- optional Production Order / Batch linkage;
- lot/batch reference;
- sample size;
- optional HR inspector link;
- in-progress / completed / cancelled state;
- pass / fail / hold result;
- timestamps and remarks.

Incoming inspections cannot incorrectly link to Production execution. Final/in-process inspections can link to production batches/orders and validate the item/factory relationship.

### Result capture

Quality result entry is server validated.

Numeric checks automatically derive pass/fail from configured min/max tolerance. Boolean checks automatically compare the observed value with the expected value. Required checklist parameters must be completed before an inspection can be completed.

The inspection result is derived as:

- **fail** when any checklist result fails;
- **hold** when the operator explicitly places the inspection on hold;
- **pass** when all required checks are complete and none fail.

### NCR / deviation

Implemented NCR records linked to failed/held inspections with:

- severity;
- category;
- description;
- assigned employee;
- due date;
- root cause;
- corrective action;
- status lifecycle;
- disposition.

Employees/supervisors can raise an NCR. Quality approval actions remain manager/supervisor scoped.

### Quarantine and Inventory integration

Quality does not maintain a second stock balance.

Quarantine creates an Inventory transfer transaction plus signed Stock Ledger entries in the same server operation. The source stock balance is transaction-locked and checked before movement.

A quarantine destination must be an active Inventory location of type `quarantine` in the same factory.

Release from quarantine:

- requires supervisor/manager approval;
- requires linked NCRs to be closed;
- transfers stock back through the Inventory ledger;
- supports release, rework or use-as-is disposition.

### Quality certificate

Passed completed inspections can generate an immutable quality certificate.

Certificate snapshot contains:

- inspection number/type;
- lot/batch number;
- sample size;
- item/SKU;
- plan/version;
- checklist results;
- issued timestamp/user.

Employees cannot issue certificates. Supervisor/manager approval is required.

### Reports

Implemented:

- quality dashboard summary;
- inspection report;
- NCR report;
- certificate list;
- live quarantine state.

All report values come from database records.

## Data model

- `quality_inspection_plans`
- `quality_plan_checks`
- `quality_inspections`
- `quality_inspection_results`
- `quality_ncrs`
- `quality_quarantine_lots`
- `quality_certificates`

## Server RPCs

- `quality_start_inspection(...)`
- `quality_record_result(...)`
- `quality_complete_inspection(...)`
- `quality_create_ncr(...)`
- `quality_update_ncr(...)`
- `quality_quarantine_stock(...)`
- `quality_release_quarantine(...)`
- `quality_issue_certificate(...)`
- `quality_dashboard_summary(...)`
- `quality_inspection_report(...)`
- `quality_ncr_report(...)`

## Permission model

- Platform Owner / Organization Admin: plan/checklist masters plus all factory Quality operations.
- Factory Manager: Quality execution and approvals only in assigned factories.
- Supervisor: Quality execution and approval actions in assigned factories.
- Employee: inspection execution, result capture, NCR creation and quarantine in assigned factories.
- Employee cannot release quarantine or issue a certificate.
- Cross-tenant and cross-factory access is protected by RLS and server permission checks.

## Mobile Quality

The mobile app now links the Quality module from the role-aware module grid.

Supported mobile operations include:

- live Quality KPIs;
- start inspection;
- record checklist results;
- complete / fail / hold inspection;
- create NCR;
- quarantine stock;
- view open NCRs and quarantine;
- supervisor/manager quarantine release;
- supervisor/manager certificate issue.

## Fictional demo data

The Aarohan Solapur demo now includes:

- Medical Oxygen 47L final inspection plan;
- valve incoming inspection plan;
- oxygen filling in-process plan;
- visual, numeric tolerance and boolean checks;
- a passed final oxygen-cylinder inspection;
- a failed incoming valve inspection;
- a high-severity NCR;
- two valves moved from Raw Material Store to `QC-HOLD` using the real Inventory ledger;
- an issued oxygen quality certificate.

## Validation

Passed in CI:

- clean local Supabase start/reset;
- migrations `0001` through `0013`;
- base seed + Phase 5 Production seed + Phase 6 Quality seed;
- Foundation, Access, HR, Inventory, Production and Quality SQL smoke tests;
- Quality table/RLS/RPC existence checks;
- immutable quality-certificate protection;
- real signup → password login → JWT → PostgREST flow;
- assigned employee inspection start;
- required checklist result capture;
- numeric tolerance auto-fail logic;
- passed inspection completion;
- failed inspection completion;
- employee certificate issue denial;
- manager certificate issue;
- employee NCR creation;
- employee quarantine ledger transfer;
- employee quarantine-release denial;
- manager NCR closure;
- manager quarantine release;
- quarantine/release Inventory balance verification;
- Factory Manager cross-factory Quality denial;
- shared Flutter analysis/tests;
- Admin Analyze;
- admin release web build;
- Mobile Analyze with Quality linked from the module grid.

## Compare / fix notes

The Design → Build → Connect → Run → Compare → Fix loop found and corrected two real integration issues:

1. Admin Quality initially contained analyzer/deprecated-form-field issues; these were corrected and the full Flutter workflow passed.
2. Production smoke validation assumed valve stock never moved after Production. Phase 6 legitimately quarantines two valves, so the test was corrected to verify total stock plus Raw Material Store / QC-HOLD split instead of treating Quality movement as a regression.

## Next

Phase 7 — Purchase & Sales: suppliers/customers → purchase requisition / PO → goods receipt → incoming quality → supplier invoice/payment status → quotation / sales order → stock allocation → dispatch readiness → customer invoice/payment status → purchase/sales reports.