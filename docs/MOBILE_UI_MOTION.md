# FactoryOS Mobile — Motion & International UI Pass

Branch: `ui/mobile-motion-polish-20261026`. Scope: the existing Flutter mobile app in `dkfutureai-alt/factory`; the separate `gas_factory` repository does not yet contain a Flutter mobile implementation.

## Visual decisions

- Restrained navy/blue/white system with crisp type hierarchy, neutral backgrounds, accessible borders and 48dp minimum action sizing.
- Auth, home and profile refreshed without altering login, tenant, role, notifications, module access or sign-out logic.
- Fluid home layout: two module columns on small phones; three or four on larger widths. Bounded desktop/tablet content width.
- The home header reflects only live bootstrap fields: organization, member role, assigned factory count and enabled workspace count.
- Real empty states replace decorative fake dashboard metrics.

## Motion contract

| Interaction | Nominal duration | Fallback |
| --- | --- | --- |
| Press feedback | 140ms | Disabled under Reduce Motion |
| Home-tab fade | 220ms | Disabled under Reduce Motion |
| New tool/notification route | 260ms | Disabled under Reduce Motion |
| One-time page reveal | 260ms | Disabled under Reduce Motion |
| Scanner tab entry/exit | 0ms | Immediate, to avoid retaining a camera view behind a transition |

No continuous animations, shimmer loops, sounds, animation packages or fabricated operational data. Animations use Flutter's own widgets and respect `MediaQueryData.disableAnimations`.

## Permissions preserved

- Module list comes from existing role-filtered mobile bootstrap only.
- Existing `WorkspaceAccessPolicy.mobileNotificationDestination` validates notification deep links unchanged.
- Module-open restrictions and error banners are unchanged.
- No backend, RLS, database, schema, inventory ledger or deployment changes.
- No change to FCM token handling or authentication.

## Validation required before merging

1. `cd packages/factoryos_core && flutter pub get && flutter analyze && flutter test`
2. `cd apps/mobile && flutter pub get && flutter analyze && flutter test`
3. Complete `.github/workflows/flutter-quality.yml` checks on this exact commit.
4. Manual screen QA at 320px / 375px / 430px widths, landscape, tablet, 200% text scaling, RTL locales and Reduce Motion.
5. Verify scanner camera release on tab exit, push-route handling, sign-in errors and sign-out on an actual device.
6. Compare screenshots against the UI specification and resolve overflow/contrast issues.

This is a code review candidate, not a verified mobile store release.
