# FactoryOS — Product Requirements / Industrial Gas Operations

**Purpose:** Multi-tenant factory management for manufacturing and industrial gas/oxygen operations. This product requirements record is a direction and acceptance map; its presence does not mean every capability is live.

## Actors
Platform owner, organization admin, factory manager, supervisor, employee, technician, storekeeper, sales/purchase staff, driver, viewer and opt-in pilot tester. Each action is constrained by authenticated role, tenant and factory membership on the server.

## Business value stream
**Onboard factory → invite employee → shifts/attendance → purchase raw materials/cylinders → receive/inspect → ledger stock → production/filling → quality release → warehouse put-away → sales allocation/invoice → dispatch vehicle/driver → delivery POD → empty-cylinder pickup → receiving/quarantine → inspection/reuse**. Support fleet fuel, assets/maintenance, reporting, audits and notifications throughout.

## Non-negotiable acceptance
- Every mutation checks server-assigned factory/tenant scope and role.
- Units, batches, serials, Dura/cylinder identities, quantity ledger and custody evidence reconcile. A registration/attestation is not physical scan proof.
- Damage, quarantine and uninspected returnables are segregated from sellable stock.
- Auth, timeout, retries and idempotency never silently duplicate inventory or financial events.
- All critical actions expose an audit trail and meaningful success/error outcomes.
- Supervisors/employees/driver receive only relevant actions and no access to unrelated factories.
- Screens retain readable 320px/mobile and full desktop use, high contrast and accessible reduced motion.
- Real customer tests require explicit consent and measurable acceptance; production requires owner approval.

## Required deliverables per module
Requirement/flow diagram, schema and RLS/RPC, Flutter/Admin surface, success+failure+denial tests, screenshots, accessibility/motion spec, telemetry or audit where permitted, release gating and a link to status evidence. Use [QA_MATRIX.md](QA_MATRIX.md) for scenarios and [QUALITY_GATES.md](QUALITY_GATES.md) for completion.
