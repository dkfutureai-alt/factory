# FactoryOS mobile QR scanner — workspace and Auth session race QA

## Source behavior

The scanner binds every QR/serial/Inventory lookup to **both** the active organization and the signed-in Supabase Auth user. The same organization may have two users with different factory assignments and roles; an organization-only request epoch is therefore insufficient on shared devices.

- Each lookup receives a monotonic request token with its exact `organizationId` and `userId`.
- Changing organization **or** authenticated user invalidates outstanding requests and immediately clears the prior scanned asset, stock rows, manual entry, error and busy indicator.
- An Auth state-change listener invalidates scans on sign-out/account switch even without a new scan or widget remount. Signed-out and signed-in events also force invalidation for rapid **same-account** reauthentication; a routine same-user token refresh does not clear legitimate results.
- A late response is rejected in its success, error **and** completion paths if the authenticated user, organization or request epoch no longer matches.
- Starting a new request while signed out, from a different user, or from the wrong organization fails closed. Revisiting a previous user/organization never revives an earlier response.

## Regression evidence to obtain

Run `apps/mobile/test/inventory_scan_epoch_test.dart` and the full Flutter Application Quality plus Android/iOS release compilation workflows on the **exact PR head**. Pure-Dart epoch tests cover same-organization user switches, sign-out, switch-back replay, wrong-user/tenant requests, overlapping scans and explicit disposal invalidation. Source tests do **not** exercise a physical QR camera, Supabase Auth networking, FCM or actual database RLS.

## Remaining gates

The mobile app still refuses ambiguous multi-organization accounts; it does not provide complete scoped switching (issues #45/#47). PostgreSQL authorization remains the source of truth for every data query and RPC. Physical Android/iOS testing must cover: user A scan → sign out → user B in the same organization but a different role → delayed A response; changed factory; unauthorized serial; lost connectivity; background/resume; duplicate scans; camera permissions; RTL/reduced motion. Keep issue #12 open until deployment, live tenant isolation and consenting pilot acceptance are separately proven.

**No production database, credentials, actual customer data, or device provisioning are modified by this source-only guard.**
