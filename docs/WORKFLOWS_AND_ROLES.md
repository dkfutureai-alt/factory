# FactoryOS domain workflows, actors and system invariants

## Actors

Platform/Super Admin manages tenants and product controls; Organization Admin manages their organization; authorized Factory Managers/Supervisors operate their assigned factories; employees, drivers, Quality, maintenance and warehouse teams use bounded workspaces. **The actual permission matrix in code and PostgreSQL is authoritative**, not this prose.

## End-to-end industrial-gas workflow

```text
Supplier -> approved Purchase Order -> GRN -> accepted Inventory ledger
       -> Production plan / batch -> consume raw materials / empty cylinders
       -> Gas fill / WIP -> Quality check -> held or released inventory
       -> Warehouse bin -> reserve/pick/stage -> Sales/Dispatch handoff
       -> Assigned driver + verified vehicle/trip -> customer delivery + POD
       -> Customer empty-cylinder pickup -> vehicle return queue
       -> warehouse receipt + inspection -> good/repair/quarantine ledger location
       -> invoice/payment reconciliation + reports/audit
```

This diagram is a *target business journey*, not proof all physical runtime steps are deployed or enforce mandatory serial-custody scans.

## Scenario contracts

| Journey | Success criteria | Failure/recovery criteria |
| --- | --- | --- |
| User invited/onboarded | Verified organization/factory/role scope, verified consent | Expired invite, wrong org, revoked role, repeated acceptance denied |
| Employee attendance | Correct shift, local time and one valid check-in/out | Midnight shift, offline retry, duplicate punch, manual correction audited |
| Purchase and GRN | Approved quantity to correct location through ledger only | Unapproved/overlimit/duplicate/cross-factory receipt denied |
| Inventory transfer | Source/destination same authorized scope; quantity ledger-balanced | Negative or insufficient stock, concurrency and offline retry denied safely |
| Production and Quality | BOM consumption, output receipt, hold/release audit | Wrong role, out-of-stock, invalid test, uninspected release denied |
| Cylinder/Dura serialization | Each physical container has authoritative identity, valid inspection and custody evidence | Missing/duplicate/expired/hold, mismatch of scan with ledger must block intended critical action when fully enforced |
| Warehouse/dispatch | Reserved stock moves only on legitimate handoff and issue | Cancel/retry has no phantom issue; staging reconciles |
| Vehicle/trip/fuel | Assigned real trip/driver, mileage and fuel records scoped | Invalid odometer, unassigned driver, repeated fuel entry corrected |
| Delivery/POD/returns | Delivery evidence and pickup distinct from inspected warehouse receipt | Loss/damage/partial return quarantined; no automatic restock |
| Maintenance | Work order, technician, downtime, private media, spares ledger | Unauthorized close, double-usage, inaccessible media denied |
| Notification | Auth-scoped event route, preferences and correct delivery status | Provider error, logout, revoked membership, stale deep link safely handled |
| Reports/audit | Tenant-scoped figures match source transaction totals | No hidden leakage or guessed KPIs; errors visible |

## Functional/nonfunctional acceptance

- Every command is role/factory scoped server side and audit traceable.
- No negative stock, duplicate financial posting or direct mutation of immutable ledgers.
- Quantity, unit, factory, actor and document references appear near approval buttons for human error prevention.
- System works under slow/unavailable networks without silently losing user input or lying about successful writes.
- Important screens are legible and usable for 320dp phones and desktop, long translations and large text.
- Reports reconcile with ledger; no static fake figures in connected release mode.
- Release requires actual device and pilot acceptance, not only schema tests.

## Change-management rule

Any addition to a workflow needs explicit involved actors, state transitions, authorization predicates, input/output models, idempotency behavior, audit footprint, UI states, automated tests and device/pilot acceptance cases. Track new scope in an issue/ADR before promising delivery.
