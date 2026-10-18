# Phase 15 — Full QA & Performance

## Status

**In progress; not a production release.** This phase extends the verified Phase 1–14 repository and local Supabase workflow chain. Its design-first reference is `docs/designs/phase15_qa_performance.svg`.

The first Phase 15 head (`312d319137852a88920eb456f1725351d3ba7ba1`) passed Flutter Application Quality and Supabase Foundation Checks on 2026-10-17. Additional reliability fixes were subsequently committed and must pass the complete pipeline at their own final head. Passing CI is a local/repository quality signal, not evidence of a deployed FactoryOS tenant.

## Quality gates

- Full clean local Supabase startup, migrations, fictional seed and reset.
- PostgreSQL lint at error severity, all SQL workflow smoke tests and structural checks.
- Public application-table RLS and primary-key coverage.
- Usable leading indexes on public-table foreign keys; no invalid/not-ready indexes.
- Policy checks for user-editable `user_metadata` authorization and anonymous mutating policies.
- Real authenticated JWT/Data API exercises for Auth, Inventory, Production, Quality, Purchase, Sales, Warehouse, Fleet, Dispatch, Maintenance, Reports, Notifications and Audit/Security.
- Deno type checks for privileged invitation and notification-delivery Edge Functions.
- Shared Flutter analyze/tests, Admin Flutter analyze/widget tests/release web build, mobile analyze/tests.
- Admin `main.dart.js` release payload budget capped at 5 MiB, with full web output reported separately.
- Local index diagnostics captured to the CI step summary.

## Performance changes

Migration `0039_performance_index_hardening.sql` adds missing leading-column foreign-key indexes where no valid usable nonpartial index already exists. Test `0039_full_qa_performance_smoke.sql` enforces structural regression gates.

Migration `0040_notification_dispatch_claims.sql` closes an overlapping-dispatch-worker race in the push outbox:

1. Worker-only `notification_claim_push_deliveries` atomically claims at most 20 queued push rows using `FOR UPDATE SKIP LOCKED`.
2. A delivery changes to `processing` and receives an incremented attempt count, a 15-minute lease timestamp and a random fencing token.
3. Concurrent workers skip leased rows.
4. A crashed worker's stale lease becomes reclaimable with a *new* token. Previous workers cannot write completion status under an obsolete token.
5. Normal completion or failure clears the active claim fields.
6. `anon` and `authenticated` cannot invoke the claim RPC; only `service_role` has explicit execute access and it runs as `SECURITY INVOKER`.

The Edge worker accepts PostgREST embedded notification values as either an object or an array, instead of assuming every relation is array-valued.

SQL test `0040_notification_dispatch_claims_smoke.sql` checks claim creation, second-worker exclusion, stale-lease recovery, token fencing, finalization, attempt cap and privilege boundaries.

**Delivery semantics:** FCM is an external side effect, so a worker crash after FCM accepts a send but before the database records it can still cause a duplicate on lease recovery. This is **at-least-once**, not an exactly-once delivery guarantee. No client should depend on a push arriving exactly once.

## Release blockers / environment work

- No verified dedicated production FactoryOS Supabase project and no controlled real tenant/JWT/RLS test identities.
- No complete deployed cross-factory E2E test with actual client roles and real project Security/Performance Advisors.
- No verified production SMTP/invite redirect, Android/iOS platform release signing or FCM secrets/platform setup.
- Browser-level end-to-end flows and physical device push, camera/QR, offline handling and POD uploads still need testing against a deployed build.
- Load tests under representative factory volume and concurrency, backup/restore rehearsal, incident alerts and rollback drill remain open.
- Real integrations, operational ownership and production acceptance are not verified.

A new dedicated Supabase project must not be created or billed without organization and expected-cost confirmation. Never reuse an unrelated production project.

## Release decision

**NO-GO for client production until the above deployment and acceptance items pass.** QA-only CI passes may justify merging the Phase 15 branch, but they cannot be substituted for deployed environment security, device and operational verification.

## Next action sequence

1. Confirm all mandatory checks on the *exact Phase 15 final code head* are green; resolve failures.
2. Review CI diagnostics and archive an exact-commit checklist.
3. Merge the draft Phase 15 PR only after required reviews and checks are complete.
4. Confirm FactoryOS Supabase organization, budget and project; provision isolated staging.
5. Test staging JWT, role/tenant RLS, transactional workflows and push worker with controlled test users.
6. Validate browser, Android, driver, QR and POD scenarios on real devices, conduct load tests and rehearse backups.
7. Execute Phase 16 release checklist; deploy only with explicit go-live approval.
