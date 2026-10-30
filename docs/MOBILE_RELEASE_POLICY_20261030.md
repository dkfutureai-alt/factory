# FactoryOS Mobile Release Policies — Source Implementation (2026-10-30)

Status: **CODED**, exact-head CI/STAGING/DEVICE/PRODUCTION verification to be recorded separately.

## Architecture

- Schema: `supabase/migrations/0053_mobile_release_policies.sql` (REVIEW ONLY; never deploy ad hoc).
- App identity is the **installed** Android applicationId / iOS CFBundleIdentifier, read via `package_info_plus`; installed version/build from the native app.
- Super Admin: `apps/admin_web/lib/mobile_release_management.dart` lists and edits release policies only when `AppRole.platformOwner`; Supabase RLS is the final security boundary. No other tenant can edit another company's app policy.
- Pre-login Mobile: `apps/mobile/lib/mobile_release_gate.dart` queries a package/platform-scoped **public non-secret** policy. Semantic versions are compared numerically by `factoryos_core`.
- A published policy has min/latest version, HTTPS update URL, release notes, maintenance mode, and enabled. Default is **no active policy**. No stock writes or authentication bypasses are added.
- Optional updates may be deferred during that app session. Forced updates and maintenance prevent the normal workspace from mounting when **a valid policy is received**. The user opens a web/store link explicitly; no silent APK installation.
- On network or policy-read failure, the app displays an **unverified policy** page with Retry and explicit Continue for now. This is a **fail-open availability choice** for existing industrial operations, NOT an enforcement guarantee. Evaluate signed cached policy or mandatory connectivity requirements before a regulated rollout.
- A resumed app rechecks policy, but its workspace is not unmounted just for a pending network refresh.

## Server authorization

- Table has RLS enabled; **anonymous users have zero direct table privileges**. The narrow `public.get_mobile_release_policy(application_id, platform)` SECURITY DEFINER RPC returns published release fields only. Authenticated clients can read published rows; active platform owners can additionally read drafts.
- Only active `platform_owner` may create/update/delete policies. Anonymous users cannot write; authenticated non-platform owners also fail RLS.
- Source tests check grants/RLS plus anon RPC published/draft/platform behavior at local reset; **JWT actor-level negative tests** remain required for security approval.
- This is package-level release metadata, not per-factory authorization. Package IDs must be unique per client, managed by a future approved white-label build registry. No tenant/customer data should ever appear in public policy rows.
- Backend must validate release policy data independently; direct API access and concurrency must be exercised in isolated staging. No production migration applied.

## Automated checks

- `packages/factoryos_core/test/app_release_policy_test.dart`: numeric semver order, forced/optional/maintenance/current, malformed policy/URL.
- `apps/mobile/test/mobile_release_gate_test.dart`: block forced/maintenance, optional defer, explicit network error and deliberate HTTPS link open.
- `supabase/tests/mobile_release_policy_security.sql`: zero anonymous table grants, published-only scoped RPC, RLS policy presence (not proof of live actor isolation).

Required source CI:
`Flutter Application Quality`, `Mobile Release Quality`, `Supabase Foundation Checks`, `Release Workflow Lint` on the **exact PR head**, plus reviewed staging Auth/RLS.
Review `pubspec.lock` resolution when the new Flutter plugins are added.

## Follow-on A–Z roadmap (NOT delivered by this PR)

1. Create a security-reviewed per-tenant white-label configuration and protected signing/build registry, with unique package identity and audit; distinguish native build-time branding from dynamic runtime content.
2. Separate signing/deployment from preview/QA artifacts; never share signing credentials with tenant operators.
3. Implement and test client ads and scheduled announcements with tenant RLS, role visibility, accessible state and upload/storage policies. Safety alerts take priority.
4. Add network request timeouts, read caches, authenticated session restoration tests, and server-idempotent queued operations **only for explicitly safe classes of writes**. Inventory/dispatch/POD/cylinder financial transitions require server-side idempotency keys and authoritative reconciliation before any offline queue.
5. Complete hardware Android/iOS checks, screen readers, 320dp/200% font, actual network loss, app store links, versioned APK/AAB production gates, backup/restore, two-tenant customer pilot.

## Release gate

No production or migration changes without independently owner-approved FactoryOS release procedure, exact SHA checks, protected secrets and restore proof. Source implementation is not live functionality and not customer acceptance.
