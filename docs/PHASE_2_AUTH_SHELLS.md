# Phase 2 — Authentication and Application Shells

## Implemented

- Shared Flutter package with FactoryOS design tokens, roles and module model.
- Supabase configuration via `--dart-define`; no secret/service-role keys are committed.
- Admin Web sign-in and authenticated bootstrap.
- Admin access restricted in the client to management roles, with RLS remaining authoritative.
- Live organization, factory, member-count and enabled-module data on the admin dashboard.
- Responsive admin layout.
- Organization settings edit form for Organization Admin and Platform Owner.
- Factory create, edit and soft-deactivate management for Organization Admin and Platform Owner.
- Factory Manager remains read-only for organization/factory setup while retaining admin-portal access.
- Server-side automatic audit logging for organization and factory inserts/updates/deletes.
- Mobile sign-in and authenticated context bootstrap.
- Mobile bottom navigation and database-driven module cards.
- Missing-configuration, loading, access-error and sign-out states.
- Tenant policy hardening so regular employees see only assigned factories and their own membership rows.
- Flutter CI for core tests, static analysis and admin web release build.
- Supabase migration/reset/seed/smoke-test CI.
- Supabase Flutter 2.18.x `publishableKey` initialization, with temporary environment fallback for legacy `SUPABASE_ANON_KEY` deployments.

## Permission Notes

- `platform_owner`: admin portal + organization/factory setup management.
- `org_admin`: admin portal + own organization/factory setup management.
- `factory_manager`: admin portal + operational management, but no organization/factory setup writes.
- RLS is authoritative; hiding an action in Flutter is not treated as a security boundary.

## Not Yet Claimed Complete

Platform runner files for Android/iOS, invitation/onboarding and role-management forms remain to be finished and tested before Phase 2 is closed.

## Run Admin Web

```bash
cd apps/admin_web
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Run Mobile Source Shell

Generate/restore platform runners for the target Flutter version, then:

```bash
cd apps/mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```
