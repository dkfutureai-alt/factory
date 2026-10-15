# Phase 2 — Authentication and Application Shells

## Implemented

- Shared Flutter package with FactoryOS design tokens, roles and module model.
- Supabase configuration via `--dart-define`; no secret/service-role keys are committed.
- Admin Web sign-in and authenticated bootstrap.
- Admin access restricted in the client to management roles, with RLS remaining authoritative.
- Live organization, factory, member-count and enabled-module data on the admin dashboard.
- Responsive admin navigation for desktop and smaller widths.
- Mobile sign-in and authenticated context bootstrap.
- Mobile bottom navigation and database-driven module cards.
- Missing-configuration, loading, access-error and sign-out states.
- Tenant policy hardening so regular employees see only assigned factories and their own membership rows.
- Flutter CI for core tests, static analysis and admin web release build.

## Not Yet Claimed Complete

Platform runner files for Android/iOS, organization/factory CRUD, invitation/onboarding and role-management forms remain to be finished and tested before Phase 2 is closed.

## Run Admin Web

```bash
cd apps/admin_web
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Run Mobile Source Shell

Generate/restore platform runners for the target Flutter version, then:

```bash
cd apps/mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```
