# Phase 16 — Production Release

## Status: release engineering in progress (not live)

Phase 0–15 was already merged/CI validated. Phase 16 adds a manually triggered, fail-closed web/Android QA release-candidate pipeline and offline test coverage. This phase does not redesign approved screens or modify operational data, business logic or tenant policies.

There is currently **no connected dedicated FactoryOS Supabase project**. The connected projects are salon-production and janseva-production. Neither may be reset, migrated, seeded or used for FactoryOS. No live FactoryOS deployment has been made.

## Release candidate automation

Workflow: .github/workflows/release-candidate.yml

- Pull requests and branch pushes touching release tooling trigger offline Python regression tests.
- A maintainer may manually select a GitHub environment (staging or production) and release target (web or android-qa).
- Production dispatch is allowed only from main; use protected production GitHub Environment reviewer approvals.
- The run stops before building if the environment is missing a plausible HTTPS Supabase URL, a client sb_publishable_ key, a valid web base path or an approved Android reverse-domain org.
- Web builds run shared-core analysis/tests, Admin analysis, a release web build and existing size budgets (main JS <= 5 MiB; total <= 50 MiB). The result is an artifact for an explicitly approved hosting deployment, **not a hosted live site**.
- Android QA builds run mobile analysis/tests, generate Android scaffolding from the provided reverse-domain organization, add INTERNET/CAMERA permissions and produce an APK. It is **not a signed Play Store release**.
- The workflow does not run database migrations or automatically deploy anything.

## GitHub Environment configuration

In repository Settings → Environments, set up staging and production separately, with the following environment **variables**:

| Name | Value |
| --- | --- |
| FACTORYOS_SUPABASE_URL | Verified HTTPS API origin for a dedicated FactoryOS project |
| FACTORYOS_SUPABASE_PUBLISHABLE_KEY | The same project's sb_publishable_ frontend key; NEVER service_role/sb_secret_ |

Protect the production environment with reviewers where possible. Provide the actual web hosting subpath (root is /). For Android QA, provide the approved brand organization namespace; the generated app package ends in .factoryos_mobile. Confirm final application IDs before Play Store submission.

Frontend build constants are visible in compiled web/mobile code by design. Never embed service-role keys, FCM server credentials, database passwords or signing keys in frontend build arguments. Format checks do NOT establish live endpoint reachability, correct ownership or successful authorization.

## Required live production gates (not yet passed)

1. Connect/create a **separate** FactoryOS Supabase project and have the human owner verify its ref and organization. Set up staging and backup/restore plans.
2. Review migrations 0001–0039, apply to staging, review live RLS/security/storage policies and only then plan a controlled production migration. Do not run local supabase db reset or sample seeds against a live client database.
3. Configure Auth site URL, redirect allowlist, email confirmation/SMTP and invite-user Edge Function secrets. Verify user invitations, expiration, onboarding, login and factory assignment with test accounts.
4. Set up send-notifications Edge Function with FCM HTTP v1 server credentials and Android/iOS Firebase platform registration. Keep FCM secrets server-side.
5. Verify cross-factory/cross-org restrictions, private maintenance/POD media, SECURITY DEFINER grants, audit immutability, reporting and notification rules against the actual remote project.
6. Select real Admin hosting and a real domain; upload the verified web artifact, configure SPA fallback/HTTPS/auth redirects, and test real login/role-specific operations.
7. Test Android QA on a real device, including scanner, camera/photo, HR check-in, warehouse picking, dispatch/POD, driver and technician flows. Add final app icons/branding, release signing/keystore and Play Store AAB review before publishing.
8. For an iOS release: generate iOS platform files on macOS after confirming approved bundle ID; add camera/photo Info.plist descriptions, Apple signing/provisioning and physical-device tests. There is no iOS artifact in this release-candidate workflow.
9. Capture production post-deploy smoke results and rollback/recovery procedure. Get explicit go-live signoff.

## Verification checklist

- [x] Phase 0–15 source branch merged into main
- [x] Release candidate tooling and fail-closed validation authored
- [x] Python offline regression suite validated locally before push
- [ ] Release workflow green on GitHub and PR merged
- [ ] Dedicated FactoryOS Supabase remote project and ownership verified
- [ ] Live migrations, security, Auth, FCM and storage verified
- [ ] Approved Admin domain/hosting live and smoke tested
- [ ] Signed Android release and physical-device QA complete
- [ ] iOS store release completed if included in launch scope
- [ ] Recovery and production operational QA signed off

**Not FINAL READY. Do not conflate release candidate artifact generation with production deployment.**
