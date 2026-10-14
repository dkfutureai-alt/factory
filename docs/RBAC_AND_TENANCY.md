# FactoryOS RBAC and Tenancy

## Principles

1. Deny by default.
2. Tenant isolation is enforced by the database, not only by UI.
3. A user may belong to one or more organizations through explicit memberships.
4. Roles are organization-scoped unless a platform-level role is explicitly intended.
5. Factory scope is applied where a role should operate only inside assigned factories.
6. Module availability and action permission are separate concerns.
7. Sensitive actions require explicit permission and are audited.

## Platform Role

### Super Admin
DK Apps Studio platform administration only.

Capabilities may include:
- create/suspend organizations
- configure subscriptions/modules
- view platform-level health
- impersonation only if separately designed, protected and audited

Super Admin must not casually bypass tenant boundaries in client-facing application flows.

## Organization Roles

### Company Owner
Full organization operational visibility, configuration and approvals, excluding protected platform administration.

### Factory Manager
Broad operational access to assigned factories including production, inventory, logistics and approvals.

### Production Manager
Production planning/execution, material requests, production reporting, relevant quality data.

### Warehouse Manager
Inventory, receiving, warehouse transfers, picking, dispatch preparation and stock reports.

### HR Manager
Employees, attendance, shifts, leave, holidays and HR reports.

### Maintenance Manager
Assets, maintenance schedules/jobs, spares usage, downtime and maintenance reports.

### Sales Manager
Customers, quotations, sales orders, invoices/payments subject to configured finance boundaries.

### Supervisor
Assigned production/operational teams, tasks, material requests, quality issues and limited approvals.

### Driver
Only assigned vehicle/trip/delivery operations, inspections, fuel entries, breakdown and POD.

### Employee
Self-service attendance, shift, assigned work, scan actions relevant to job, leave and announcements.

## Permission Naming

Use stable action-oriented keys:

- `organization.read`
- `organization.update`
- `factory.read`
- `factory.manage`
- `employee.read`
- `employee.create`
- `employee.update`
- `employee.deactivate`
- `attendance.read`
- `attendance.self_checkin`
- `attendance.manage`
- `leave.self_create`
- `leave.approve`
- `inventory.read`
- `inventory.receive`
- `inventory.issue`
- `inventory.transfer`
- `inventory.adjust`
- `production.read`
- `production.create`
- `production.start`
- `production.complete`
- `quality.read`
- `quality.inspect`
- `quality.release`
- `sales.read`
- `sales.manage`
- `purchase.read`
- `purchase.manage`
- `dispatch.read`
- `dispatch.manage`
- `vehicle.read`
- `vehicle.manage`
- `trip.assigned_read`
- `trip.assigned_update`
- `fuel.create`
- `fuel.manage`
- `delivery.assigned_read`
- `delivery.assigned_update`
- `maintenance.read`
- `maintenance.manage`
- `report.read`
- `approval.read`
- `approval.act`
- `audit.read`
- `settings.manage`

## Scope Model

Membership establishes the organization boundary.

Optional role assignment fields:
- organization_id
- factory_id nullable
- warehouse_id nullable where needed
- department_id nullable where needed

A null narrower scope does not imply global platform access; it means the role follows its organization-level scope unless policy says otherwise.

## RLS Pattern

Every tenant table must check organization membership.

Typical predicate:

```sql
organization_id in (
  select organization_id
  from organization_memberships
  where user_id = auth.uid()
    and status = 'active'
)
```

Mutation policies additionally verify an effective permission. Permission evaluation should be centralized through a stable SQL function rather than duplicating complex joins in every policy.

## Factory Restriction

Where a role assignment is factory-limited, reads/writes must validate the record's `factory_id` against an active role assignment or an organization-wide role.

## Protected Examples

- Driver accessing HR administration: denied.
- Employee creating stock adjustment: denied.
- Warehouse user accessing another organization: denied by RLS.
- HR manager modifying sales invoice: denied unless separately granted.
- User changing role/permission definitions without `settings.manage`: denied.

## Audit Requirements

Audit at minimum:
- role assignment changes
- permission changes
- stock adjustments
- employee deactivation
- QC release/rejection
- production completion/cancellation
- dispatch cancellation
- exceptional approvals

## Testing Matrix

For each main role test:
- successful login
- allowed navigation
- allowed CRUD/action calls
- direct API/database access to prohibited records
- cross-tenant access attempt
- cross-factory access attempt where scoped
- deactivated membership
- disabled module

A hidden button is not considered authorization.