# FactoryOS RBAC and Tenancy

## Principles

1. Deny by default.
2. Tenant isolation is enforced by the database, not only by UI.
3. A user may belong to one or more organizations through explicit active memberships.
4. Roles are organization-scoped unless a platform-level role is explicitly intended.
5. Narrow role assignments must never authorize a broader scope than they were assigned.
6. Module availability and action permission are separate concerns.
7. Sensitive actions require explicit permission and should be audited.
8. Hiding a UI control is never considered authorization.

## Platform Role

### Super Admin
DK Apps Studio platform administration only.

Capabilities may include:
- create/suspend organizations;
- configure subscriptions/modules;
- view platform-level health;
- impersonation only if separately designed, protected and audited.

Super Admin must not casually bypass tenant boundaries in client-facing application flows.

## Organization Roles

### Company Owner
Full organization operational visibility, configuration and approvals, excluding protected platform administration.

### Factory Manager
Broad operational access to assigned factories including production, inventory, logistics and approvals.

### Production Manager
Production planning/execution, material requests, production reporting and relevant quality data within assigned scope.

### Warehouse Manager
Inventory, receiving, warehouse transfers, picking, dispatch preparation and stock reports within assigned warehouse/factory scope.

### HR Manager
Employees, attendance, shifts, leave, holidays and HR reports within assigned scope.

### Maintenance Manager
Assets, maintenance schedules/jobs, spares usage, downtime and maintenance reports within assigned scope.

### Sales Manager
Customers, sales orders and payments subject to configured commercial boundaries and assigned scope.

### Supervisor
Assigned production/operational teams, tasks, material requests, quality issues and limited approvals.

### Driver
Only assigned vehicle/trip/delivery operations, inspections, fuel entries, breakdown and POD.

### Employee
Self-service attendance, shift, assigned work, scan actions relevant to job, leave and announcements.

## Permission Naming

Stable action-oriented keys are used, including:

- `factory.manage`
- `employee.read`
- `employee.sensitive.read`
- `employee.sensitive.manage`
- `attendance.read`
- `attendance.manage`
- `leave.read`
- `leave.manage`
- `inventory.read`
- `inventory.manage`
- `inventory.transact`
- `inventory.receive`
- `inventory.post`
- `production.read`
- `production.manage`
- `quality.read`
- `quality.manage`
- `sales.read`
- `sales.manage`
- `purchase.read`
- `purchase.manage`
- `dispatch.read`
- `dispatch.manage`
- `delivery.read`
- `delivery.manage`
- `vehicle.read`
- `vehicle.manage`
- `trip.assigned_read`
- `trip.assigned_update`
- `fuel.create`
- `fuel.manage`
- `maintenance.read`
- `maintenance.manage`
- `notification.read`
- `notification.manage`
- `report.read`
- `audit.read`
- `settings.manage`

Do not introduce a second permission vocabulary for an existing action without a deliberate project-wide migration.

## Scope Model

Membership establishes the organization boundary. An active `user_roles` assignment can then narrow the effective role with:

- `organization_id` — always required;
- `factory_id` — nullable;
- `warehouse_id` — nullable;
- `department_id` — nullable.

The effective hierarchy is:

**organization → factory → warehouse OR department**

A warehouse and a department may not be combined on one assignment. Warehouse and department assignments must reference the same parent factory stored on the role assignment.

A null narrower scope means organization-wide scope only when **all** narrower scope columns are null. It never means platform-global access.

### No upward scope inheritance

Narrower assignments can inherit access downward where a policy explicitly supports it, but they cannot satisfy a broader permission check:

- organization-wide role → may satisfy organization, factory, warehouse or department checks when permission is granted;
- factory-wide role → may satisfy that factory and its explicitly supported child scopes, but not organization-wide checks;
- warehouse role → may satisfy only its warehouse-specific checks, not factory- or organization-wide checks;
- department role → may satisfy only its department-specific checks, not factory- or organization-wide checks.

This prevents a warehouse/department/factory assignment from becoming an organization administrator simply because the same permission key exists on the role.

## Central Permission Helpers

`supabase/schemas/01a_rbac_scope_hardening.sql` defines the canonical helpers:

- `private.has_any_permission(org, key)` — the user has the permission on at least one active role assignment in that organization. Use only for intentionally shared organization master data where the row itself has no narrower operational scope.
- `private.has_org_permission(org, key)` — requires a truly organization-wide assignment.
- `private.has_factory_permission(org, key, factory)` — permits an organization-wide assignment or an assignment to that exact factory; warehouse/department assignments do not satisfy it.
- `private.has_warehouse_permission(org, key, warehouse)` — permits organization-wide, parent-factory-wide, or exact-warehouse assignment.
- `private.has_department_permission(org, key, department)` — permits organization-wide, parent-factory-wide, or exact-department assignment.
- `private.can_access_factory`, `private.can_access_warehouse`, `private.can_access_department` — scope-aware visibility helpers for structural records.

`private.has_permission(org, key, factory)` remains only as a compatibility wrapper:

- `factory IS NULL` means **organization-wide permission**, not “any scope”;
- non-null factory means `has_factory_permission`.

New policies should prefer the explicit helper that matches the data row’s actual scope.

## Role Assignment Integrity

The `user_roles_validate_scope` trigger rejects:

- role/organization mismatch;
- assignment to a user without organization membership;
- factory references from another organization;
- warehouse or department references from another organization;
- warehouse/department parent-factory mismatch;
- combined warehouse + department scopes.

These checks prevent malformed assignments from weakening otherwise-correct RLS predicates.

## RLS Pattern

Every tenant table must establish organization isolation first and then enforce the narrowest meaningful record scope.

Examples:

- a factory transaction checks `has_factory_permission` against the row’s `factory_id`;
- a warehouse location checks `has_warehouse_permission` / `can_access_warehouse`;
- a child row without `factory_id` resolves its parent transaction/order and uses the parent factory;
- organization-global catalogs may use `has_any_permission` for read access only when sharing that catalog across assigned factories is intentional;
- organization configuration mutations require `has_org_permission`.

Do not pass `NULL` merely because a child table lacks a direct `factory_id`; resolve the authoritative parent scope instead.

## Core Visibility Rules

- Factory metadata is visible only when the active role assignment reaches that factory.
- Warehouse metadata is visible only when the assignment reaches that warehouse through organization, parent factory or exact warehouse scope.
- Department metadata follows the equivalent organization/factory/department rule.
- Non-admin users may read their own membership and role assignments; organization-wide settings administrators may enumerate them for administration.
- Suspended memberships confer no effective permission even if role rows remain present.

## Protected Examples

- Factory Manager with PLANT-01 assignment attempting organization settings update: denied.
- Factory Manager with PLANT-01 assignment reading PLANT-02 operational rows: denied.
- Warehouse Manager assigned RM-WH reading sibling FG-WH metadata: denied.
- Production Manager assigned PROD department reading a sibling department through department-scoped helper: denied.
- Driver accessing HR administration: denied.
- Employee creating a stock adjustment: denied.
- User from another organization: denied by tenant/RLS boundary.
- User changing role/permission definitions without organization-wide settings authority: denied.

## Audit Requirements

Audit at minimum:
- role assignment changes;
- permission changes;
- stock adjustments/posting;
- employee deactivation;
- QC release/rejection;
- production completion/cancellation;
- dispatch/delivery exceptions;
- exceptional approvals;
- security-sensitive configuration changes.

## Executable Security Gate

`.github/workflows/factoryos_db_ci.yml` provisions a temporary PostgreSQL 16 database and:

1. installs a minimal CI-only Supabase `auth.uid()` compatibility layer;
2. applies every FactoryOS schema/review/command migration in dependency order;
3. applies every fictional demo seed in dependency order;
4. executes `supabase/tests/01_rbac_scope_security.sql` as both privileged setup and the `authenticated` role.

Current assertions cover:
- organization-, factory-, warehouse- and department-scope helper semantics;
- no upward scope escalation;
- cross-factory denial;
- cross-warehouse denial;
- cross-department denial;
- cross-tenant denial;
- suspended membership denial;
- malformed role-assignment rejection;
- self-only membership/role visibility for non-admins;
- denial of organization-level module mutation from a factory-scoped manager;
- factory-scoped visibility of Inventory, Production, Purchase, Sales and Delivery child rows through their authoritative parent records.

This local PostgreSQL gate verifies SQL execution and RLS behavior in an isolated database. It does **not** replace final testing on a dedicated Supabase project, Supabase security/performance advisors, storage policies, Auth configuration or production E2E testing.

## Production Test Matrix

Before production, each main role still requires:
- successful real Supabase authentication;
- allowed navigation;
- allowed CRUD/action RPC calls;
- direct Data API/database attempts against prohibited records;
- cross-tenant access attempts;
- cross-factory/warehouse/department attempts where scoped;
- deactivated/suspended membership behavior;
- disabled-module behavior;
- RPC privilege and `SECURITY DEFINER` review;
- Supabase security/performance advisor review.

A passing Flutter screen is not authorization, and a passing local PostgreSQL test is not a substitute for the final deployed Supabase security gate.
