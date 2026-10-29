# FactoryOS real-user UAT and consenting pilot playbook

## Strict acceptance boundaries

Code tests and fictional-data simulations do **not** prove the app works for actual factories. The dedicated FactoryOS environment must be safely deployed using owner-reviewed workflows before inviting real users. Collect explicit consent and comply with applicable privacy terms. Never create fake acceptance records or manufacture customers to satisfy a release gate.

## Owners and isolation

- Product owner approves pilot scope, privacy, recovery and release readiness.
- Factory owner/manager authorizes the company's participation and participant roles.
- QA lead runs scripted acceptance and records true outcomes.
- Security/release reviewer verifies tenant isolation, redacted evidence and change approvals.
- At least **two separate consenting organizations** must be represented to validate multi-tenant isolation, matching the repository's protected pilot acceptance expectations.

## Preconditions

- [ ] Owner-approved staging/production environment with verified migration history and right FactoryOS project.
- [ ] Working SMTP invite/sign-in and role/factory assignment, plus encrypted backup and **witnessed isolated restore**.
- [ ] Admin and Mobile usable through real accessible URLs/installable signed builds as required.
- [ ] Actual Android/iOS device models, OS/build versions and camera/notification permissions documented.
- [ ] RLS/Storage/FCM/privacy checks passed; sensitive logs redacted and access revocable.
- [ ] Participants received a plain-language consent statement, data handling expectations and opt-out process.
- [ ] Pilot includes rollback, support contact, issue severity and emergency stop.

## Pilot scenario register

| ID | Actor | Real task | Evidence |
| --- | --- | --- | --- |
| U01 | Organization admin | Invite employee, assign role/factory, revoke | Authorized and denied views |
| U02 | HR/employee | Check in/out across assigned shift; leave request | Shift and server timestamps |
| U03 | Purchase/warehouse | Approved PO → GRN → ledger stock | PO, GRN and reconciled quantities |
| U04 | Production | Batch plan/consume materials/output | Before/after ledger |
| U05 | Quality | Inspect; reject/hold; release approved items | Inspection + inventory movement |
| U06 | Warehouse | Bin, pick, stage and dispatch handoff | Locations/reservations reconcile |
| U07 | Sales/admin | Quote/order/invoice and safe permissions | Authorized status + audit |
| U08 | Fleet/driver | Vehicle assignment, fuel/trip execution | Trip, odometer and fuel scope |
| U09 | Driver | Delivery + real POD and return pickup | POD on physical phone |
| U10 | Warehouse | Receive good/damaged empties separately | Quarantine vs ready stock |
| U11 | Maintenance | Scan asset, work order, spares | Asset and stock ledger |
| U12 | Manager | Tenant/factory-scoped reports and audit | Figures match transactions |
| U13 | Mobile user | Push received/opened; logout/switch users | Actual handset route authorization |
| U14 | Cross-tenant QA | Org A vs Org B denial in all sensitive paths | Signed-in access denies |

This register complements—but does **not replace**—the actual protected [PHASE_29_REAL_CUSTOMER_PILOT_ACCEPTANCE.md](PHASE_29_REAL_CUSTOMER_PILOT_ACCEPTANCE.md) scripted acceptance contract. Inspect its authoritative definitions at execution time.

## Test record

```text
Scenario:
Date/time + timezone:
Consenting organization alias / participant role (no public personal details):
Environment / URL / app build / exact commit:
Phone model, OS, network:
Actions and observed outputs:
Expected result:
PASS / FAIL / BLOCKED / NOT_RUN:
Sanitized evidence reference:
Defect issue and owner:
Retest after fix / acceptance by actual responsible person:
```

Never mark device receipt from FCM provider acceptance; observe it on handset. Never infer successful physical cylinder custody from a serial-only record. Keep separate QA notes for mandatory safety inspections/expiry, damaged empties and actual inventory balance.

## Go/no-go criteria

All P0 security/stock/safety scenarios pass on the actual intended environment. No serious unresolved defects. Complete consent and retention/erasure workflow. Owner signs acceptance of known issues. Protected production deployment and rollback/restore proofs exist. If any mandatory item is missing, the result is **NO-GO** and issue #12 remains open.
