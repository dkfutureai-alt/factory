# Phase 15 — Full QA & Performance

## Status

Implemented on top of the validated Phase 14 main branch. The substantive Phase 15 source passed both FactoryOS quality pipelines:

- Flutter Application Quality — pass on `b5ec38645dd45d6018f9f76d038bdffff3b81736`.
- Supabase Foundation Checks — pass on `fa8ec14ffe9498b48541fa0f53afd3cfc219cd08`.

The two heads differ only by the Flutter workflow budget calibration commit; the Supabase application/database content is unchanged between them. The final documentation head must retain both gates before merge.

## Scope

Phase 15 is a QA/performance hardening phase. It intentionally does not redesign approved FactoryOS screens, so no new design image is required for this phase.

The work targets:

- role/module regression prevention;
- reporting read-path performance;
- privileged reporting RPC hardening;
- repeatable local/CI validation;
- release bundle growth detection.

## Shared workspace access policy

A single policy now owns cross-application decisions that had previously been embedded independently in Admin and Mobile UI code:

`packages/factoryos_core/lib/src/workspace_access_policy.dart`

Covered decisions:

- management-only mobile Reports visibility;
- Delivery execution availability;
- Driver-only Fleet execution;
- commercial navigation availability;
- Dispatch dependency completeness;
- generic module-enabled checks.

Both `apps/admin_web/lib/main.dart` and `apps/mobile/lib/main.dart` consume the shared policy.

Regression coverage is in:

`packages/factoryos_core/test/workspace_access_policy_test.dart`

The tests preserve the existing FactoryOS role model and do not introduce a new role.

## Reporting performance hardening

Migration:

`supabase/migrations/0039_reporting_performance_hardening.sql`

Phase 15 adds narrowly targeted indexes for executive/dashboard hot paths rather than broadly indexing write-heavy operational tables.

Covered report paths include:

- customer invoice date ranges;
- supplier invoice date ranges;
- stock ledger item/factory aggregation;
- production output date ranges;
- production plan date ranges;
- completed Quality inspections;
- delivered Dispatch records;
- Maintenance downtime date ranges;
- Attendance date ranges.

The executive dashboard and daily trend RPCs replace timestamp-column `::date` range predicates with half-open timestamp ranges:

`timestamp >= from_date AND timestamp < to_date + 1 day`

This preserves inclusive date semantics while allowing PostgreSQL to use timestamp indexes for filtering.

## Reporting RPC security

The optimized report RPCs remain SECURITY DEFINER but now also have:

- pinned empty `search_path`;
- schema-qualified project relations/functions;
- PUBLIC/`anon` execute removed;
- explicit `authenticated` execute grants;
- existing organization/factory authorization checks preserved.

SQL regression coverage:

`supabase/tests/0039_reporting_performance_qa.sql`

It verifies:

- all Phase 15 performance indexes exist;
- the hot timestamp predicates are not reintroduced as indexed-column date casts;
- report SECURITY DEFINER search paths remain pinned;
- `anon` cannot execute the privileged report RPCs;
- `authenticated` retains intended access.

## CI reliability

The Supabase workflow previously used `version: latest` for `supabase/setup-cli@v1`. During Phase 15 this caused a GitHub API rate-limit failure before any FactoryOS code ran.

The workflow now pins Supabase CLI `2.121.0`, the verified current release at the time of Phase 15, so QA does not depend on resolving the latest release at runtime.

This is a build-infrastructure reliability change, not an application behavior change.

## Release bundle budget

Flutter CI now builds the Admin portal in release mode and enforces size budgets.

Measured Phase 15 baseline:

- `main.dart.js`: 3,622,934 bytes.
- complete `build/web` payload: 42,873,372 bytes.

Budgets:

- application JS <= 5 MiB;
- complete Flutter web payload <= 50 MiB.

The total payload includes Flutter framework/engine assets, so the application JS budget is the tighter app-growth signal while the total cap protects against large packaging regressions.

## Validation

### Flutter

Validated with Flutter stable 3.47.7 during the Phase 15 run:

- shared core dependency resolution — pass;
- shared core static analysis — pass;
- 11 shared role/workspace policy tests — pass;
- Admin dependency resolution — pass;
- Admin static analysis — pass;
- Admin release web build — pass;
- Admin JS and total release bundle budgets — pass;
- Mobile dependency resolution — pass;
- Mobile static analysis — pass;
- Mobile tests — pass.

### Supabase/PostgreSQL

Validated with pinned Supabase CLI 2.121.0:

- invitation Edge Function type-check — pass;
- notification-delivery Edge Function type-check — pass;
- clean local Supabase startup — pass;
- clean database reset and migrations `0001`–`0039` — pass;
- all SQL smoke/integrity/performance tests — pass;
- complete authenticated Auth/JWT/RLS workflow chain for Inventory, Production, Quality, Purchase/Sales, Warehouse, Fleet, Dispatch, Maintenance, Reports, Notifications and Audit/Security — pass.

## Environment validation boundary

The FactoryOS production Supabase project is not available through the Supabase connector in this session, so Phase 15 does not claim a live remote migration, live database advisor result or production deployment.

The local Supabase CI environment remains the validated database source for this phase. A production release must reconnect the actual FactoryOS Supabase project and apply the repository migrations there before go-live.

## Phase boundary

Phase 15 closes application-level full QA and targeted performance hardening.

The remaining work is **Phase 16 — Production Release**, including environment-specific deployment items such as:

- reconnecting/confirming the real FactoryOS Supabase project;
- production SMTP and invite redirect configuration;
- production FCM credentials/platform registration;
- Android/iOS platform project generation and release configuration;
- signing/store configuration;
- production Admin web hosting/environment variables;
- remote migrations and post-deploy smoke verification.
