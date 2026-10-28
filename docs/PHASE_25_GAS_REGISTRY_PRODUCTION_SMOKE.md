# Phase 25 — production gas registry read-only API evidence

FactoryOS Phase 21A introduces `gas_container_assets` and `gas_container_asset_events` in migration 0047. The gated `Production Smoke Verification` checks the *deployed*, approved FactoryOS project after an authorized smoke-account login. For each table it requires an authenticated PostgREST `GET` yielding a valid JSON array (possibly empty), and a publishable-key request with **no user JWT** yielding an explicit 4xx denial.

This check is read-only, creates no container/inspection/test accounts and never changes stock. The existing `VERIFY` confirmation, exact separately typed project ref, protected `factoryos-production` environment, and main-branch restriction remain unchanged.

This test is **not** customer acceptance and does not verify QR scanner hardware, serial custody ledger reconciliation, inspection certification, offline idempotency, or release eligibility. Those are still separate conditions of issue #27. Do not market cylinders as fully traceable from this check alone.

A successful GitHub build on a source branch does not substitute for actually running the protected smoke against an installed database with migration 0047. The dedicated Supabase project remains empty until owner-approved deployment.
