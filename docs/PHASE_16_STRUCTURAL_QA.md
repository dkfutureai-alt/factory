# Phase 16 — Database Structural Integrity QA

This follow-up preserves the merged Phase 15 reporting-performance hardening, Phase 16 release work and Phase 16 notification dispatch migration. It forward-ports the independently verified database-wide structural QA from the earlier draft branch using **new migration/test number 0042**.

## Database-wide assertions

`supabase/tests/0042_structural_integrity_smoke.sql` fails when:

- An application-owned table in exposed `public` lacks Row-Level Security.
- An application-owned public table has no primary key.
- A public table foreign key does not have a valid, ready, nonpartial index whose leading columns match the constraint.
- Public indexes are invalid or not ready.
- RLS policies use user-editable `user_metadata` in authorization predicates.
- An RLS policy permits anonymous or PUBLIC INSERT/UPDATE/DELETE/ALL.

Extension-managed public tables are excluded from application-owned table gates. The checks are executed on the full clean local schema and rollback without changing test data.

## Missing foreign-key indexes

`supabase/migrations/0042_foreign_key_index_hardening.sql` creates any missing leading-column indexes, sorted deterministically by schema/table/constraint, after verifying whether a suitable index already exists. Names include an identifier prefix and constraint hash to avoid collisions. It does not rewrite existing valid index definitions.

**Production consideration:** `CREATE INDEX` in the migration is ordinary blocking index creation, not `CONCURRENTLY`. Assess lock windows and table volumes before applying to a populated production database. A dedicated FactoryOS production project is not currently connected, so no live schema is changed here.

## CI

The clean-schema `Supabase Foundation Checks` job now also runs `supabase db lint --level error -s public`, then all SQL smoke tests and the complete authenticated JWT/RLS/module workflow chain. Existing Flutter/native/release workflows remain unchanged.

## Release boundary

Passing these gates strengthens source-controlled schema QA. Production deployment, full workload performance testing, backup/restore rehearsal, tenant sign-off, SMTP/FCM configuration, physical-device tests and app-store credentials remain separate Phase 16 operational requirements.
