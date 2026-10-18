# Phase 16 — Production Release

## Status

Phase 16 converts the validated FactoryOS application into a production-release-ready repository.

Source-controlled release work is implemented on `work/phase16-production-release`. Live production deployment is intentionally gated by external credentials and the exact FactoryOS cloud projects; no unrelated Supabase/Firebase project may be used as a substitute. Manual production jobs now require an independent typed confirmation of the project reference in addition to the stored reference and matching project URL.

First production mobile version: `1.0.0+1`.

## Mobile production foundation

Flutter stable generated the missing native projects from the existing mobile application source (the temporary self-modifying generator workflow has been retired after these platform shells were committed):

- `apps/mobile/android`
- `apps/mobile/ios`

Base production identity:

- Android application id: `com.dkappsstudio.factoryos`
- iOS bundle id: `com.dkappsstudio.factoryos`
- app display name: `FactoryOS`

The generated projects preserve the existing Flutter UI and workflows; Phase 16 does not introduce a new major screen.

### Android release requirements

The main Android manifest explicitly provides the permissions required by the production build:

- Internet access for Supabase/API traffic
- Camera access for QR/barcode scanning and work evidence
- Android notification permission

The camera feature is optional so devices without a camera are not excluded from installation.

Release signing is environment-driven. Store publishing must set:

- `FACTORYOS_ANDROID_KEYSTORE_PATH`
- `FACTORYOS_ANDROID_KEYSTORE_PASSWORD`
- `FACTORYOS_ANDROID_KEY_ALIAS`
- `FACTORYOS_ANDROID_KEY_PASSWORD`
- `FACTORYOS_REQUIRE_RELEASE_SIGNING=true`

When production signing is explicitly required, the Gradle build fails if any signing value is missing. Ordinary CI is still allowed to compile a release bundle using the generated debug signing configuration solely as a compile-time validation artifact.

### iOS release requirements

The iOS project includes:

- camera privacy description;
- photo-library privacy description;
- background remote-notification mode;
- `Runner.entitlements` for APNs;
- development APNs environment for Debug;
- production APNs environment for Release/Profile.

Final App Store signing still requires the external Apple Developer distribution identity/provisioning profile.

## Mobile Firebase/FCM client

`apps/mobile/lib/push_notifications.dart` completes the client side of the Phase 13 push worker.

When Firebase runtime configuration is supplied, the app now:

1. initializes Firebase;
2. requests notification permission;
3. waits for the APNs token on iOS before requesting the FCM token;
4. registers the same physical push target for every active organization membership owned by the signed-in user;
5. refreshes all active tenant registrations when Firebase rotates the token;
6. opens supported FactoryOS workflows from `action_route` when a push is tapped;
7. disables the current physical push target across the user's active tenant registrations before signing out.

Registering against every active membership avoids coupling FCM registration to an arbitrary `limit(1)` tenant lookup and matches the tenant-aware device key introduced in migration `0040`.

When no Firebase configuration is supplied, push setup is a safe no-op so local development and application QA continue to work without production credentials.

Required mobile runtime defines are:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- optional `FIREBASE_STORAGE_BUCKET`
- iOS: `FIREBASE_IOS_BUNDLE_ID=com.dkappsstudio.factoryos`

Android and iOS normally have different Firebase app IDs, so each store build must receive the app ID for its own Firebase platform app.

## Shared-device notification security

Migration:

`supabase/migrations/0040_notification_device_session_hardening.sql`

The migration:

- changes device uniqueness to organization + user + token fingerprint;
- pins the registration RPC SECURITY DEFINER search path;
- deactivates an active token owned by another user when a shared factory handset is claimed by the current user;
- adds `notification_disable_current_device` so sign-out can invalidate the current push target without trusting a client-stored database id;
- denies anonymous execution and preserves explicit authenticated access.

Regression checks:

`supabase/tests/0040_notification_device_session_qa.sql`

The existing authenticated Notification E2E remains the live device-registration workflow test. Migration `0040`, its SQL checks and the full existing authenticated Auth/JWT/RLS/module chain passed in the Phase 16 Supabase CI run.

## Release CI

### Normal application quality

`.github/workflows/flutter-quality.yml`

Continues to enforce shared tests, Admin analysis/release web build, Mobile analysis/tests and Admin bundle budgets.

Flutter's generated template test was replaced with a FactoryOS Firebase release-configuration regression test so generated scaffolding cannot reference a nonexistent template `MyApp`.

### Native mobile release compilation

`.github/workflows/mobile-release-quality.yml`

Build gates:

- Android release `.aab` on Linux;
- iOS Release app on macOS with `--no-codesign`;
- Android release artifact existence/size check.

These jobs use placeholder Supabase values and no Firebase runtime values. Their purpose is to prove the production native projects compile without requiring production credentials.

### Android signed production bundle

`.github/workflows/android-production-bundle.yml`

Manual guarded workflow. Type `BUILD` and independently provide `confirm_project_ref` matching the configured FactoryOS project ref to create a signed AAB after the required repository secrets are configured. The Supabase URL must resolve to that exact project, and the Firebase app ID must identify an Android app. It restores the production keystore only inside the runner, enables the Gradle hard signing requirement, injects production Supabase/Firebase defines, verifies the bundle and stores the AAB as a short-retention workflow artifact.

The workflow does not publish to Google Play automatically; Play publishing remains an explicit release-owner action until a Play Console service account is connected.

## Supabase production release

`.github/workflows/supabase-production-release.yml`

Manual guarded workflow. Type `DEPLOY` and independently provide `confirm_project_ref` matching the configured FactoryOS Supabase project ref. The workflow additionally verifies `FACTORYOS_SUPABASE_URL` resolves to that exact ref, requires an HTTPS invite redirect URL, and uses the `factoryos-production` GitHub environment. Configure required reviewers on this GitHub environment for a human release approval. Only then may the job:

1. validate all required production secrets;
2. link the exact FactoryOS Supabase project;
3. run `supabase db push --dry-run`;
4. apply only pending migrations with `supabase db push`;
5. set Edge Function runtime secrets;
6. deploy all repository Edge Functions;
7. display migration state after deployment.

The production workflow **never includes seed data** and never uses remote database reset.

Required repository secrets:

- `SUPABASE_ACCESS_TOKEN`
- `FACTORYOS_SUPABASE_PROJECT_REF`
- `FACTORYOS_SUPABASE_DB_PASSWORD`
- `FACTORYOS_SUPABASE_URL`
- `FACTORYOS_INVITE_REDIRECT_URL`
- `NOTIFICATION_DISPATCH_SECRET`
- `FCM_PROJECT_ID`
- `FCM_CLIENT_EMAIL`
- `FCM_PRIVATE_KEY`

## Push outbox scheduler

`.github/workflows/notification-dispatch.yml`

On the default branch, the workflow invokes `send-notifications` every five minutes using the same dispatch secret configured in Supabase. Before sending the secret, an offline Python guard validates `FACTORYOS_SUPABASE_PROJECT_REF` as 20 lowercase letters/digits and requires `FACTORYOS_SUPABASE_URL` to match exactly `https://<ref>.supabase.co`.

When **all three** dispatch settings (project ref, project URL and dispatch secret) are absent, the workflow skips without making a request. Partially configured, malformed or cross-project settings fail the job **before any outbound request**. Secret values are never written to logs by the guard. The regression tests run in the existing release-tool CI job (`python3 -m unittest discover -s scripts/tests -v`).

This provides a zero-infrastructure scheduler for queued external push delivery. In-app notifications remain immediate and do not depend on this scheduler.

## Admin production release

`.github/workflows/admin-production-release.yml`

Manual guarded GitHub Pages workflow. Type `PUBLISH`, provide a normalized base href without spaces, traversal or shell metacharacters (the repository Pages default is `/factory/`) and configure:

- `FACTORYOS_SUPABASE_URL`
- `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`
- `FACTORYOS_SUPABASE_PROJECT_REF` (must match `FACTORYOS_SUPABASE_URL`)

The workflow builds the Admin portal with production Supabase values and deploys only the compiled static web output. No service-role/server secret is embedded in Flutter web.

## Production smoke verification

`.github/workflows/production-smoke.yml`

Manual guarded workflow. Type `VERIFY` and independently provide the exact `confirm_project_ref` before production authentication; it refuses a URL/ref mismatch. Run only after deployment. It:

1. verifies the configured Supabase REST endpoint;
2. signs in a dedicated production smoke user;
3. masks the resulting access token before passing it between workflow steps;
4. verifies the authenticated identity;
5. confirms the smoke user can see at least one active organization membership through RLS;
6. confirms the Factory query is valid under that user's RLS scope;
7. optionally verifies the configured Admin production URL responds.

Required smoke secrets:

- `FACTORYOS_SUPABASE_URL`
- `FACTORYOS_SUPABASE_PUBLISHABLE_KEY`
- `FACTORYOS_SMOKE_EMAIL`
- `FACTORYOS_SMOKE_PASSWORD`
- `FACTORYOS_SUPABASE_PROJECT_REF`
- optional `FACTORYOS_ADMIN_URL`

The smoke account should be a dedicated low-privilege FactoryOS test member, not a production owner's everyday account. Its active membership is verified against its authenticated `user_id`, rather than accepting another user's tenant membership.

## Release workflow lint

`.github/workflows/release-workflow-lint.yml` installs the pinned `actionlint` version and checks workflow syntax, expressions and shell blocks whenever workflow files change. This is a source/CI safety check, not a substitute for the production smoke test or release-owner approval.

## External account configuration still required

These items cannot be truthfully completed from repository source alone and must belong to the actual production accounts:

### Supabase

- connect/create the actual FactoryOS production project;
- set production Auth Site URL and allowed redirect URLs;
- configure production SMTP/provider for invitation and Auth email delivery;
- add the repository secrets listed above;
- create a dedicated low-privilege production smoke account;
- run the guarded production release workflow;
- run the guarded production smoke workflow against that exact project.

The Supabase connector available during this phase does not expose a FactoryOS production project, so no live remote mutation was attempted.

### Firebase / FCM

Create/register platform apps in the intended Firebase project:

- Android package: `com.dkappsstudio.factoryos`
- iOS bundle: `com.dkappsstudio.factoryos`

Provide the mobile runtime configuration secrets and the FCM service-account values used by the Supabase Edge Function.

For iOS, upload/configure the APNs authentication key in Firebase.

### Stores

Google Play requires the final Play Console app, store listing, privacy/data-safety declarations and production signing ownership.

Apple App Store requires an Apple Developer account, App ID/capabilities, distribution signing/provisioning, App Store Connect listing and privacy declarations.

These account-level steps are release ownership/configuration, not missing FactoryOS business logic.

## Production rule

Never point FactoryOS release automation at an unrelated Supabase or Firebase project. Always verify the project reference/package/bundle identity before running a guarded production workflow.


## Independent release-candidate tooling from main

The previously merged `release-candidate.yml` and the accompanying Python release-preflight and manifest regression tests are preserved alongside the Phase 16 production workflows. They provide an alternate manual web hosting artifact or Android QA APK build, not a production deployment or a signed store release. See [`PHASE_16_RELEASE_CANDIDATE.md`](PHASE_16_RELEASE_CANDIDATE.md) for the original release-candidate configuration and gates. The Android/iOS platform shells already checked into `apps/mobile` remain the production release source.
