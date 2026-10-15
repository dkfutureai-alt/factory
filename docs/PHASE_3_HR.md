# Phase 3 — HR, Attendance, Leave and Holidays

## Scope

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

## Permission model

- Platform Owner / Organization Admin: organization-wide HR management.
- Factory Manager: employee, shift, attendance, leave and factory-holiday management only for assigned factories.
- Supervisor: read-only visibility for assigned-factory employee/attendance context.
- Employee/Driver: only their linked HR profile, attendance and leave information.
- Self check-in/out and self leave requests are exposed through security-definer RPCs; direct employee attendance writes are not granted.

## Atomic workflows

- `mark_my_attendance('check_in'|'check_out')` validates the authenticated employee, assigned factory timezone and duplicate actions.
- `request_my_leave(...)` validates leave type, dates and overlapping requests.
- `decide_leave_request(...)` validates manager scope and automatically marks approved dates as `on_leave` when no check-in exists.
- `hr_dashboard_summary(...)` calculates live HR KPIs from database records.
- `hr_attendance_report(...)` provides a bounded report query with role checks.

## Auditability

HR master changes, employee changes, attendance, leave and holiday changes are written to the shared `audit_logs` stream by database triggers.

## Demo data

The seed contains only fictional names and records for the fictional Aarohan Solapur Plant. Dashboard counts must remain database-driven.

## Completion gate

Phase 3 is complete only when clean Supabase reset, HR SQL smoke tests, Flutter analysis/build and mobile HR self-service analysis all pass.
