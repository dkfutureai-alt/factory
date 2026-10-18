# Phase 16 — Optional CI Release Candidate

This document preserves the existing, independently merged release-candidate workflow and offline tests. For current FactoryOS production release architecture, safeguards and owner-controlled go-live, see `PHASE_16_PRODUCTION_RELEASE.md` and `PRODUCTION_GO_LIVE_CHECKLIST.md`.

## Status: release engineering in progress (not live)

Phase 0–15 was already merged/CI validated. Phase 16 adds a manually triggered, fail-closed web/Android QA release-candidate pipeline and offline test coverage. This phase does not redesign approved screens or modify operational data, business logic or tenant policies.

There is currently **no connected dedicated FactoryOS Supabase project**. The connected projects are salon-production and janseva-production. Neither may be reset, migrated, seeded or used for FactoryOS. No live FactoryOS deployment has been made.

## Release candidate automation

Workflow: .github/workflows/release-candidate.yml

- Pull requests and branch pushes touching release tooling trigger offline Python regression tests.
- A maintainer may manually select a GitHub environment (staging or production) and release target (web or android-qa).
- Production dispatch is allowed only from main; use protected production GitHub Environment reviewer approvals.
- The run stops before building if the environment is missing a plausible HTTPS Supabase URL, a client sb_publishable_ key or a valid web base path. Android identity comes from the committed native project rather than an operator-supplied override.
- Web builds run shared-core analysis/tests, Admin analysis, a release web build and existing size budgets (main JS <= 5 MiB; total <= 50 MiB). The result is an artifact for an explicitly approved hosting deployment, **not a hosted live site**.
- Android QA builds run mobile analysis/tests, verify the committed Android application ID and namespace (`com.dkappsstudio.factoryos`), check manifest permission idempotency without modifying tracked files and produce an APK. Native scaffolding is **not regenerated**. The result is **not a signed Play Store release**.
- The workflow does not run database migrations or automatically deploy anything.

## GitHub Environment configuration

In repository Settings → Environments, set up staging and production separately, with the following environment **variables**:

| Name | Value |
| --- | --- |
| FACTORYOS_SUPABASE_URL | Verified HTTPS API origin for a dedicated FactoryOS project |
| FACTORYOS_SUPABASE_PUBLISHABLE_KEY | The same project's sb_publishable_ frontend key; NEVER service_role/sb_secret_ |

Protect the production environment with reviewers where possible. Provide the actual web hosting subpath (root is /). The Android QA workflow uses the existing `com.dkappsstudio.factoryos` package identity and does not accept arbitrary package-organization input.

Frontend build constants are visible in compiled web/mobile code by design. Never embed service-role keys, FCM server credentials, database passwords or signing keys in frontend build arguments. Format checks do NOT establish live endpoint reachability, correct ownership or successful authorization.

## Required live production gates (not yet passed)

1. Connect/create a **separate** FactoryOS Supabase project and have the human owner verify its ref and organization. Set up staging and backup/restore plans.
2. Review migrations 0001–0040, apply to staging, review live RLS/security/storage policies and only then plan a controlled production migration. Do not run local supabase db reset or sample seeds against a live client database.
3. Configure Auth site URL, redirect allowlist, email confirmation/SMTP and invite-user Edge Function secrets. Verify user invitations, expiration, onboarding, login and factory assignment with test accounts.
4. Set up send-notifications Edge Function with FCM HTTP v1 server credentials and Android/iOS Firebase platform registration. Keep FCM secrets server-side.
5. Verify cross-factory/cross-org restrictions, private maintenance/POD media, SECURITY DEFINER grants, audit immutability, reporting and notification rules against the actual remote project.
6. Select real Admin hosting and a real domain; upload the verified web artifact, configure SPA fallback/HTTPS/auth redirects, and test real login/role-specific operations.
7. Test Android QA on a real device, including scanner, camera/photo, HR check-in, warehouse picking, dispatch/POD, driver and technician flows. Add final app icons/branding, release signing/keystore and Play Store AAB review before publishing.
8. For an iOS release: use the committed iOS native project and confirmed bundle ID, then provide Apple signing/provisioning and physical-device tests. This optional release-candidate workflow does not publish an iOS artifact; the separate Mobile Release Quality workflow checks an unsigned iOS build.
9. Capture production post-deploy smoke results and rollback/recovery procedure. Get explicit go-live signoff.

## Verification checklist

- [x] Phase 0–15 source branch merged into main
- [x] Release candidate tooling and fail-closed validation authored
- [x] Python regression suite included in the release-candidate GitHub workflow
- [x] Initial release-candidate workflow merged and validated by GitHub CI
- [ ] Dedicated FactoryOS Supabase remote project and ownership verified
- [ ] Live migrations, security, Auth, FCM and storage verified
- [ ] Approved Admin domain/hosting live and smoke tested
- [ ] Signed Android release and physical-device QA complete
- [ ] iOS store release completed if included in launch scope
- [ ] Recovery and production operational QA signed off

**Not FINAL READY. Do not conflate release candidate artifact generation with production deployment.**
