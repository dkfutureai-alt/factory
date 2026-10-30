# FactoryOS premium UX implementation checkpoint

Date: 2026-10-30 (IST).
Base: PR #70 documentation branch, not main. This is source work only.

## Repository findings

- The shared Flutter theme only exposed a light palette and basic spacing.
- Compact Admin Web placed every authorized module in a single bottom navigation bar; desktop NavigationRail could exceed vertical viewport.
- Mobile Home used a fixed two-column module grid irrespective of screen size or text scaling.
- Mobile Reports repeated a separate KPI implementation.

## Code changes

- Added Material 3 light/dark shared themes, optional visual brand-color parameter, responsive grid rule, and reduced-motion duration rule in factoryos_core.
- Added reusable operational KPI, textual safety status, and loading/empty/error/offline/permission state widgets.
- Mobile and Admin shells now choose the operating-system light/dark preference.
- Admin Web compact layout now offers a few quick destinations and a complete scrollable authorized-module drawer. Desktop uses a scrollable sidebar.
- Mobile Home module tiles become one column on narrow devices or large text. Mobile Reports uses shared data-only KPI widgets.
- Added core widget regression tests for themes, responsive columns, motion, KPI text, retry, and labeled warning.

## Not done, not verified, and no-go boundaries

The code does not yet provide persisted Super Admin branding, factory logo uploads, onboarding/banner editing, translated strings, native SVG assets, offline write queues/conflict resolution, full module-by-module polish or customer-visible designs. No fake data or privileged operations were added. It does not change Supabase policies, migrations, transactions, inventory ledgers or cylinder return workflows.

Flutter/Dart SDK was unavailable in the local execution environment. Formatting, analyzer, Flutter tests, Android/iOS builds, admin web build, pixel screenshots, real devices, FPS, large-font layouts and actual two-tenant workflows remain unverified until named CI/runtime evidence is recorded. An added automated test is NOT a pass result. Do not claim this work is production ready.

## Evidence and QA matrix

| Area | Expected behavior | Verification state |
| --- | --- | --- |
| Admin compact 320-900dp, many roles | All authorized modules reachable, 2-4 quick items | Code only; device QA needed |
| Admin desktop | Long sidebar scrolls, navigation remains role scoped | Code only; visual QA needed |
| Mobile module home 320dp/200% | One column, no clipped control | Added test; CI pending |
| Mobile Reports | Only server-provided KPI values | Code only; live report QA needed |
| Light/dark | Palette resolves platform mode | Added test; CI pending |
| Motion | Reduced-motion duration becomes zero | Added test; CI pending |
| Safety | Icons and readable text for holds | Added test; integration pending |
| Inventory/dispatch/return | No data-layer change introduced | Source-only, E2E unchanged |

## Next steps

1. Review and fix exact-head PR Flutter Quality failures; run format, analyze, core/admin/mobile widget tests and admin web build.
2. Inspect and compare actual screenshots at 320, 360, 390, 600, 900 and 1280dp and 200% text; keyboard, screen reader, light/dark and RTL readiness.
3. Integrate shared components screen-by-screen without changing permissions or inventing success after network timeout.
4. Propose a separately reviewed Supabase tenant-branding API/storage policy with Super Admin authorization; require explicit approval for migrations.
5. Preserve the existing guarded production rollout, real pilot and cylinder-custody gates.

Commands for an authorized Flutter workstation: flutter pub get, dart format ., flutter analyze, flutter test in packages/factoryos_core, apps/admin_web and apps/mobile; flutter build web --release in apps/admin_web with placeholder build-time settings. Run actual cross-tenant and physical device E2E only in approved isolated environments.
