# FactoryOS — UI Screen Inventory and Design Acceptance

**Inventory to audit, not a claim that every screen is delivered or polished.** Reconcile each row against current source and PR branches before changing it.

| Surface | Screen group / happy path | Mandatory variants | Priority |
| --- | --- | --- | --- |
| Mobile | Splash/config, Sign in, Invite/onboarding, denied workspace | Loading, invalid link, expired auth, offline | P0 |
| Mobile | Home, Work/Tasks, Scan, Alerts, Profile | Role hide/show, unread, no scanner permission, user switch | P0 |
| Mobile | HR attendance, schedule, leave | No shift, duplicate check-in, denied leave | P1 |
| Mobile | Production / quality execution | Invalid batch, bad scan, hold, blocked release | P1 |
| Mobile | Inventory / warehouse QR scan | Wrong factory, no camera, offline retry, stale response | P0 |
| Mobile | Driver vehicle/trip, dispatch, delivery POD | No assignment, lost GPS/network, denied media, duplicate submit | P0 |
| Mobile | Empty return collection / warehouse intake | Good, damaged, quarantine and not-yet-received states | P0 |
| Mobile | Maintenance task, scanned asset, work media | Unassigned asset, offline, denied private upload | P1 |
| Mobile | Reports / pilot consent and feedback | Empty, report blocked, withdraw consent | P1 |
| Admin | Sign in, organization/factory/user roles | Scope changes, revoked permissions, pending invite | P0 |
| Admin | Executive dashboard, notifications and alerts | Genuine no-data, stale and abnormal KPI states | P0 |
| Admin | HR employee/attendance/leave | Pending approval, empty, unauthorized | P1 |
| Admin | Stock master, ledger, production, quality | Validation, quarantine, idempotent retry | P0 |
| Admin | Purchase/GRN, sales, customer/invoicing | Approval, rejection, invalid totals | P0 |
| Admin | Warehouse/dispatch/fleet/fuel | Backorder, driver mismatch, late POD | P0 |
| Admin | Gas serial registry, QR print, inspection | Invalid serial, unfit cylinder, missing attestation | P0 |
| Admin | Maintenance, reporting, audit/security | Narrow screen, read-only user, export failures | P1 |
| Admin | Pilot coverage, customer feedback, release-readiness views | No real report, denied cross-tenant access | P1 |

## Screen acceptance record (copy for each)
**Screen ID / role / purpose / source path / screenshot or Figma ref / target breakpoints / states / data contract / actions / animation (with reduced-motion alternative) / semantic focus / contrast & 200%-scale / permissions / QA case IDs / screenshot comparison / exact commit / reviewer / outcome.**

Design flow: identify existing screen → functional flow map → wireframe → polished screenshot → review → implement → connect data → widget and device checks → update record. Do not invent design approval or claim a preview screen is merged into `main`. See [../ui-ux.md](../ui-ux.md) and [../motion.md](../motion.md).
