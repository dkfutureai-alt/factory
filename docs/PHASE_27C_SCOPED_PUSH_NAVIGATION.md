# Phase 27C — mobile push route tenant and recipient isolation

## Problem

The previous FCM payload contained only a route (for example `inventory`) and an entity ID, without the notification's authoritative organization and recipient identifiers. A shared device or an account that changed workspace could therefore open a route from the wrong organization's push notification. The existing mobile guard already refuses ambiguous multi-organization accounts, but notification routing also needs an independent fail-closed boundary.

## Implemented scope

- The trusted `send-notifications` Edge Function now includes `organization_id` and `recipient_user_id` from the stored notification row in each FCM data payload. The mobile app does **not** derive either ID from user-editable FCM metadata.
- `apps/mobile/lib/scoped_push_route.dart` parses the payload and requires a nonblank `organization_id`, `recipient_user_id` and `action_route`. Old unscoped pushes remain visible as system notifications but **do not automatically navigate**.
- `PushNotificationService.attachRouteHandler` binds a route handler to the currently authenticated user's ID and the bootstrapped organization ID. Both must exactly match the payload and the live signed-in user before navigation.
- Cold-start notifications held before a handler is attached are consumed only by their exact recipient and organization. Mismatches discard the pending navigation. The service cancels queued navigation on sign-out and checks the handler again before delayed microtask delivery.
- Mobile device token registration is now restricted to the exact active single-membership workspace. The app does **not** silently subscribe the current handset to all organizations; multi-organization mobile switching remains blocked pending safely scoped RPCs. Registration and token refresh verify the active user and workspace.
- `apps/mobile/test/scoped_push_route_test.dart` covers missing or malformed scope, other tenants, other users, shared devices, pending route consumption and sign-out; the Edge Function Deno helper test enforces the FCM payload fields.

## Acceptance and limitations

This adds navigation safety; database RLS remains the actual authorization boundary for every screen and RPC. It does **not** implement mobile multi-organization switching or prove native push receipt.

Before customer rollout, deploy the updated **send-notifications** Edge Function using the protected FactoryOS-only `release_scope=full` workflow **after approved database migrations**, SMTP/Auth setup and dedicated FCM secrets. Then test on actual Android and iOS handsets: valid same-organization push, cross-organization push, different-user shared device, sign-out, cold-start, delayed tap, rotated FCM token and revoked membership. Record evidence and ensure a notification for a different organization never causes navigation or a data mutation.

Production database and Edge Functions remain undeployed until the release owner reviews and approves the release. Never reuse Janseva/Salon Firebase projects or Supabase resources.
