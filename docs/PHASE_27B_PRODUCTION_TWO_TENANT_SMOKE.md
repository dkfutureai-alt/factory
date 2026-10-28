# Phase 27B — authenticated two-organization production RLS smoke

**Status:** source/CI guard, **not** a claim of actual production tenant isolation until run against the deployed FactoryOS service with two populated, approved test organizations.

## Why

The earlier `Production Smoke Verification` validated that a single test user could sign in and read JSON arrays, but a success response alone did not prove that a real member of Organization A could not read Organization B data. An empty table is not useful evidence of correct RLS.

## How it works

The protected, manually confirmed GitHub workflow now runs `python3 scripts/production_tenant_isolation_smoke.py` before module-level read-only probes. It uses only the dedicated FactoryOS Supabase API origin `https://zevrmvhnibztbxizswgu.supabase.co`; even a self-consistent alternate project reference and URL is rejected. Redirects are refused so credentials cannot be forwarded to an unexpected host.

The owner must provision **two real test identities that they control**, each with **exactly one active membership** in a **different dedicated, consented pilot/test organization**. Each must be a non-platform-owner role, with at least one active factory visible to that identity (grant the relevant factory assignment for viewer/employee/driver roles). This test needs *populated* core membership and factory fixtures; it will intentionally block instead of reporting a meaningless pass from empty tables. Never use unrelated Salon/Janseva accounts, actual customer production records or privileged service-role keys as smoke identities.

Configure protected GitHub environment secrets:
- Existing `FACTORYOS_SMOKE_EMAIL`, `FACTORYOS_SMOKE_PASSWORD`
- New `FACTORYOS_SMOKE_SECOND_EMAIL`, `FACTORYOS_SMOKE_SECOND_PASSWORD`

Both identities use normal Supabase Auth password sign-in. The script checks individual user identity, single active organization membership, distinct account/organization IDs, own organization visibility, own membership visibility, and own active factory visibility. It then checks that **both users** see **no rows** in the other organization's `organizations`, `organization_members`, `factories`, or `factory_members`. Only the sign-in calls are POST; every table check is GET. No fixture creation, changes, invitations or enrollment happen in the smoke run. Identifiers, emails, passwords, response bodies and access tokens are not logged.

## Limits and acceptance

- This is a targeted, positive-control/negative-control authorization smoke for the **four core tables**, not comprehensive cross-tenant E2E for all FactoryOS modules.
- Empty module tables, FCM, SMTP, mobile storage/media, stock reconciliation, two-organization users with multiple memberships, real devices, customers and physical cylinder scans remain separately unverified.
- A tester must not have `platform_owner` privileges because such accounts are expected to bypass tenant boundaries.
- Use existing `scripts/tests/test_production_tenant_isolation_smoke.py` synthetic offline regressions to verify fail-closed behavior in CI before deployment.
- Once the protected workflow actually passes, retain the run ID, timestamp, deployed commit SHA, evidence of two authorized test organizations and release-owner sign-off in the go-live record. Do not record real credentials or contact information in issues.

This is a **release gate**, not permission to deploy the empty production database without owner review. Complete the migration/backups approval and production deployment checklist first.
