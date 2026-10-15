# Phase 3 — HR, Attendance, Leave and Holidays

## Status

**Complete at the core application/database level and CI validated.**

Phase 3 turns the `hr` module into a real factory HR workflow rather than a dashboard placeholder.

Business flow:

`Departments/Designations → Shifts → Employee master → Daily attendance → Leave request/approval → Holidays → HR reports`

## Data model

- `departments` — organization-level department master.
- `designations` — organization-level designation master, optionally tied to a department.
- `shifts` — organization/factory shift definitions with grace and half-day thresholds.
- `employees` — HR employee records; login account is optional, so non-app workers remain manageable.
- `attendance_records` — one attendance row per employee/work date.
- `leave_types` — configurable paid/unpaid leave categories.
- `leave_requests` — employee requests with manager decision history.
- `holidays` — organization-wide or factory-specific holidays.

## Admin experience

The responsive admin portal now contains an HR workspace with:

- live HR KPI dashboard;
- employee create/edit/activate/deactivate;
- optional FactoryOS user linking;
- department and designation management;
- shift management;
- daily attendance correction;
- leave approval/rejection;
- leave type configuration;
- organization/factory holiday management;
- bounded attendance reporting;
- database report functions for headcount and leave reporting.

## Employee mobile experience

The mobile HR module now provides:

- linked employee profile;
- factory, department, designation and shift context;
- daily self check-in/check-out;
- recent attendance history;
- leave request creation and cancellation;
- leave status history;
- upcoming organization/factory holidays.

Drivers retain HR access for attendance and leave even when their operational module list is otherwise limited.

## Permission model

- Platform Owner / Organization Admin: organization-wide HR management.
- Factory Manager: employee, shift, attendance, leave and factory-holiday management only for assigned factories.
- Supervisor: read-only visibility for assigned-factory employee/attendance context.
- Employee/Driver: only their linked HR profile, attendance and leave information.
- Employee leave creation and attendance actions are RPC-only; direct privileged writes are denied by RLS.
- Factory-specific shifts and holidays are hidden from users assigned to other factories.
- A linked app user must be an active organization member and, for factory-scoped roles, assigned to the same factory as the employee record.

## Atomic workflows

- `mark_my_attendance('check_in'|'check_out')` validates the authenticated employee, factory timezone, night shifts, duplicate actions and grace minutes.
- `admin_set_attendance(...)` validates manager scope and performs an atomic manager correction.
- attendance normalization triggers clear invalid time data for absent/leave/holiday/week-off statuses and calculate worked/late minutes.
- `request_my_leave(...)` validates leave type, dates and overlapping requests.
- `cancel_my_leave(...)` allows only the requesting employee to cancel a pending request.
- `decide_leave_request(...)` validates manager scope and marks approved dates as `on_leave` where appropriate.
- `hr_dashboard_summary(...)` calculates live HR KPIs from database records.
- `hr_attendance_report(...)`, `hr_headcount_report(...)` and `hr_leave_report(...)` provide bounded role-checked report surfaces.

## Integrity and auditability

- Employee manager references are constrained to the same organization.
- Employee designation/department and shift/factory combinations are validated at the database boundary.
- HR master changes, employee changes, attendance, leave and holiday changes are written to the shared `audit_logs` stream by database triggers.
- Historical employee records use status/soft deactivation rather than destructive deletion.

## Demo data

The seed contains only fictional data for the fictional Aarohan Solapur Plant, including departments, designations, three shifts, leave types, eight employees, attendance, leave requests and holidays. Dashboard counts remain database-driven.

## Validation

Passed in CI:

- invitation Edge Function Deno type-check;
- clean local Supabase start/reset and all migrations;
- fictional seed load;
- all foundation/access/HR SQL smoke tests;
- real employee signup/password login/JWT/PostgREST factory RLS;
- employee HR-record isolation;
- employee self-profile RPC;
- employee self check-in RPC;
- employee leave request RPC + RLS;
- factory-manager attendance correction RPC;
- factory-manager cross-factory attendance denial;
- shared Flutter core tests;
- admin analysis + release web build;
- mobile analysis including HR self-service.

## Next

Phase 4 — Inventory: item master → categories/units → stock locations → receive/issue/transfer → QR/barcode scan → stock ledger → reorder alerts → inventory reports.
