# RBAC and Tenancy

## Roles

| Role | Scope | Purpose |
| --- | --- | --- |
| `platform_owner` | platform | DK Apps Studio super-admin capabilities |
| `org_admin` | organization | client owner / authorized admin |
| `factory_manager` | factory/organization | factory operations manager |
| `supervisor` | factory | shift/department supervisor |
| `employee` | factory | employee operational workflows |
| `driver` | factory | assigned trip/delivery workflows |
| `viewer` | organization/factory | read-only reporting access |

A user can have memberships in multiple organizations, but each organization membership has one primary role. Factory membership narrows access where required.

## Authorization Principles

1. Supabase Auth proves identity; it does not grant tenant access by itself.
2. Organization access comes from active `organization_members` rows.
3. Factory access comes from the organization plus active `factory_members` rows for factory-restricted roles.
4. `platform_owner` is represented explicitly in membership data; it is not inferred from email address.
5. RLS is enabled on every tenant-owned table.
6. Service-role credentials never ship in client applications.
7. Sensitive mutations should use RPC/functions where atomic validation or audit behavior is required.

## Future Permission Layer

Module/action permissions will be added on top of the role defaults. Expected actions include `view`, `create`, `update`, `approve`, `cancel`, `export` and `admin`.

The database remains the final authorization boundary even when UI navigation hides unavailable actions.
