# Phase 14 — Audit & Security Hardening

## Status

Implemented on top of the validated Phase 13 main branch. The substantive Phase 14 source head passed both Flutter Application Quality and Supabase Foundation Checks, including the complete authenticated Phase 1–14 workflow chain. Merge still requires the final documentation head to retain those exact green gates.

## Design-first reference

`docs/designs/phase14_audit_security.svg`

The design defines:

- Security health KPIs
- recent sensitive activity
- Audit Explorer
- Access Review
- security findings
- audit integrity controls

## Migrations

Phase 14 uses migrations `0034`–`0038`:

- `0034_audit_security_hardening.sql` — factory-scope correction, audit hash chain, security RPCs and Admin security domain.
- `0035_security_trigger_hardening.sql` — lifecycle-safe INSERT/UPDATE/DELETE handling for security configuration auditing.
- `0036_security_policy_recursion_hardening.sql` — recursion-safe member/profile visibility helpers and factory-scoped security KPIs.
- `0037_audit_immutability_enforcement.sql` — independent SECURITY INVOKER audit mutation enforcement.
- `0038_security_function_privilege_hardening.sql` — removes PUBLIC/anon execution from privileged RPCs and pins Phase 14 SECURITY DEFINER functions to an empty search path.

## Security boundary

Phase 14 preserves the existing FactoryOS role model. No separate security role is introduced.

- Platform Owner: platform-wide authority through the existing role model.
- Organization Admin: organization-wide security visibility.
- Factory Manager: visibility only for factories they are actively assigned to manage.
- Supervisor / Employee / Driver / Viewer: no security-admin RPC access.

## Factory-scope hardening

The original foundation helper `is_factory_member()` treated any organization-level Factory Manager as a member of every factory in the organization. Phase 14 corrects it so:

- Organization Admin remains organization-wide.
- Factory Manager access requires an active `factory_members` assignment.
- other factory-scoped roles continue to require their active assignment.

Read policies are tightened for:

- `organization_members`
- `factory_members`
- `profiles`
- `audit_logs`

The member/profile policies use recursion-safe SECURITY DEFINER visibility helpers with explicit caller filtering. Factory Managers can no longer read another factory's member assignments, profiles or audit records merely because the factory belongs to the same organization.

## Audit integrity

The canonical `audit_logs` table remains the single audit history. Phase 14 adds:

- `severity`
- `source`
- `request_id`
- `previous_hash`
- `integrity_hash`

Existing rows are backfilled into an ordered per-organization SHA-256 chain. New audit inserts:

1. take an organization-scoped advisory transaction lock,
2. read the previous audit hash,
3. derive severity,
4. capture a request correlation ID when available,
5. compute the new integrity hash.

Authenticated clients retain read-only access within their permitted scope. Authenticated INSERT/UPDATE/DELETE privileges remain revoked, and a SECURITY INVOKER trigger independently rejects non-administrative audit UPDATE/DELETE attempts if privileges are ever broadened later.

The integrity chain is tamper-evident rather than a substitute for database backups or external immutable log retention.

## Function hardening

Phase 14 follows the current Supabase/Postgres privileged-function security model:

- privileged Admin Security RPCs are not executable by PUBLIC or `anon`;
- only `authenticated` receives explicit execute permission for the guarded Admin RPCs;
- every Phase 14 SECURITY DEFINER function has a pinned empty `search_path`;
- project relations and project functions used from those privileged functions are schema-qualified;
- every user-facing privileged RPC performs organization/factory scope authorization before returning data.

## Sensitive configuration auditing

Organization-module enable/disable changes are written to the canonical audit log. Existing membership, invitation, notification-rule, maintenance and other module-specific audit writers continue to use the same table and therefore inherit the Phase 14 integrity chain.

## Security RPCs

### `security_admin_summary`

Returns scoped security KPIs:

- audit events in the last 24 hours
- high/critical-risk changes in the last 7 days
- access anomalies
- privileged-member count
- stale notification devices
- audit-integrity status

Factory-scoped counts only include members/devices associated with the selected factory.

### `security_audit_feed`

Returns a scoped recent audit feed with actor, severity, action, entity, request ID and integrity hash.

### `security_access_review`

Returns visible member access with active factory scopes and anomaly flags such as:

- inactive profile with active organization access
- required factory assignment missing
- active assignment to an inactive factory

### `security_verify_audit_integrity`

Recomputes recent row hashes and chain links. Organization Admins can verify organization scope; Factory Managers can invoke the check only from an assigned factory security scope.

## Admin web

`apps/admin_web/lib/security_center.dart`

The Admin navigation now includes **Audit & Security** for existing Admin-portal roles.

Surfaces:

- Overview
- Audit Explorer
- Access Review

The workspace uses the same factory selector pattern as Reports, Notifications and Maintenance. Factory Managers default to one of their assigned factories; Organization Admins and Platform Owners may use organization-wide scope.

## Module registration

`security` is registered in `app_modules` and enabled for existing organizations. A guarded organization trigger enables it for newly created organizations so security visibility is not lost through module configuration drift.

## Validation

Phase 14 adds:

- `supabase/tests/0034_security_hardening_smoke.sql`
- `supabase/tests/security_auth_e2e.sh`
- CI execution after the existing Phase 1–13 authenticated chain

SQL smoke/integrity coverage verifies:

- security module and RPC installation
- audit integrity columns/triggers
- hash generation and recomputation
- authenticated audit write privileges remain revoked
- privileged Security RPCs remain unavailable to `anon`
- authenticated execute grants exist only for intended user-facing Security RPCs
- SECURITY DEFINER search paths are explicitly pinned
- audit mutation enforcement remains SECURITY INVOKER

Authenticated E2E verifies:

1. Factory Manager is a member of the assigned factory.
2. Factory Manager is not treated as a member of an unassigned factory.
3. blocked-factory organization member data is hidden from the Factory Manager.
4. blocked-factory profile data is hidden.
5. blocked-factory assignment rows are hidden.
6. the security module is enabled for a newly created organization.
7. Factory Manager can read the assigned-factory security summary.
8. Factory Manager cannot read organization-wide or blocked-factory security summaries.
9. Employee cannot use the security summary.
10. Organization Admin can read organization-wide security state.
11. Factory Manager Access Review excludes a blocked-factory user.
12. Organization Admin Access Review includes organization-wide members.
13. audit integrity verifies with zero broken hashes/links.
14. Factory Manager audit feed contains only the allowed factory.
15. direct audit-log RLS hides blocked-factory rows.
16. authenticated audit mutation is denied.

## Phase boundary

Phase 14 hardens application-level tenant access and canonical audit visibility/integrity. It does not claim to replace external SIEM, WAF, infrastructure monitoring, Supabase project backup policy, secret rotation or device-platform security.

Next development phase after merge: **Phase 15 — Full QA & Performance**.
