# FactoryOS production migration history proof (Phase 23)

A successful `supabase db push` exit code is not independently sufficient evidence that **every committed migration is applied to the intended project**. The protected `Supabase Production Release` now checks the linked Supabase migration-list table before and after the write.

- First, the protected workflow confirms `main`, the exact human-typed target ref, API URL and required secrets; it links **only FactoryOS**.
- Preflight: `supabase migration list --linked` is parsed by `scripts/verify_production_migrations.py`; remote versions must all be recognized local committed versions. New migrations may be pending, but missing/unknown local versions or remote-only versions stop the workflow before `db push`.
- Then `supabase db push --dry-run` and `supabase db push` run as before, with the existing protected GitHub environment, confirmation and no seed/reset.
- Postdeploy: a fresh `migration list --linked` must exactly match the committed migration versions. Any missing remote version fails the job, so an incomplete migration cannot be reported as a green database release.
- The tool compares versions, **not SQL file content hashes, remote schema drift or backup readiness**. Drift still requires separately approved `db diff`/read-only schema review and actual production RLS/REST checks.
- The parser handles both ASCII and Unicode table separators, ignores harmless CLI banner lines, and fails closed on malformed/empty output. Unit tests cover initial install, partial deployment, unknown remote version, incomplete release, duplicates and invalid names.

This change performs **no remote deployment by itself**. Owner-approved environment secrets and manual dispatch remain necessary. Real-user acceptance, SMTP, Firebase and device tests remain required before a release sign-off.

Reference: Supabase's migration list and migration tracking behavior, https://supabase.com/docs/guides/deployment/database-migrations.
