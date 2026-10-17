# Phase 13 — Notifications

## Status

Implemented on top of the validated Phase 12 main branch. The phase is complete only after the final branch head passes both Flutter Application Quality and Supabase Foundation Checks and is merged.

## Design-first reference

`docs/designs/phase13_notifications.svg`

The design defines four primary surfaces:

1. Admin/Manager Notification Center with delivery-health KPIs.
2. Rules and templates with factory scope, audience roles and channel selection.
3. Mobile Alerts inbox, detail/action flow and read state.
4. User preferences for in-app/push delivery, quiet hours and critical-alert bypass.

## Data model

Migration `0028_notifications.sql` adds:

- `notification_templates`
- `notification_rules`
- `notification_preferences`
- `notification_devices`
- `notifications`
- `notification_deliveries`

Hardening migrations:

- `0029_notification_rule_audit_hardening.sql` — safe rule audit handling for INSERT/UPDATE/DELETE.
- `0030_notification_scope_hardening.sql` — exact factory rule scope, organization-bound device identity and factory-aware device KPIs.
- `0031_notification_rule_visibility.sql` — Factory Managers can inspect organization-default rules without seeing another factory's scoped rules.

The `notifications` row is the canonical user notification. Channel delivery state is kept separately in `notification_deliveries`, so push retries never duplicate the inbox item.

## Security and tenancy

- Every notification belongs to an organization and may be factory scoped.
- Factory-scoped recipients must be authorized for that factory unless they are an organization/platform administrator.
- Push devices are bound to organization + user + token fingerprint.
- Users can read only their own inbox, preferences, devices and delivery rows.
- Direct authenticated writes to inbox, delivery and device tables are revoked; guarded RPCs own those mutations.
- Organization-wide notification administration requires Organization Admin or Platform Owner access.
- Factory Managers administer only their allowed factory scope and cannot inspect other factories' scoped rules.
- Rule mutations are audit logged.

## Default event automation

Default templates/rules are installed for every existing and future organization for:

- Maintenance work-order assignment
- Dispatch delivery exception
- HR leave approval/rejection
- Dispatch delivery completion

The notification engine also exposes a manager broadcast RPC for scoped operational announcements.

## Preferences

Each user can independently control:

- in-app notifications
- push notifications
- quiet-hours start/end
- critical-alert bypass during quiet hours
- muted notification categories

Muted categories are suppressed before a notification is created for that user.

## Admin web

`apps/admin_web/lib/notification_center.dart`

Capabilities:

- organization/factory scope selection based on role
- last-24-hours, unread, actionable, push queued/failed, active device and rule KPIs
- rules and templates
- rule enable/disable with scope enforcement
- new rule creation
- manager/admin broadcast
- recent in-app/push delivery status

The page is registered through the `notifications` organization module and is wired into the main Admin navigation.

## Mobile

`apps/mobile/lib/notification_inbox.dart`

The existing Alerts bottom-navigation destination is now a live notification inbox with:

- all/unread filters
- unread badge
- mark-one / mark-all read state
- category and priority context
- notification detail sheet
- related-module navigation for supported mobile workflows
- user notification preferences

The `notifications` module also appears in the mobile module grid when enabled.

## Push delivery

`supabase/functions/send-notifications/index.ts`

Push delivery uses FCM HTTP v1 and an outbox model. No Firebase service-account credential is stored in the repository or database. Device lookup is organization-scoped before a push is attempted.

Production deployment must provide Edge Function secrets:

- `NOTIFICATION_DISPATCH_SECRET`
- `FCM_PROJECT_ID`
- `FCM_CLIENT_EMAIL`
- `FCM_PRIVATE_KEY`

The mobile platform projects must also provide their normal Firebase/FCM platform configuration before a real device token can be registered. This is a deployment/release requirement, not an in-app notification logic dependency.

## Validation

Phase 13 adds:

- `supabase/tests/0028_notifications_smoke.sql`
- `supabase/tests/notifications_auth_e2e.sh`
- `supabase/tests/notifications_scope_e2e.sh`
- Deno type-check for the notification delivery worker
- existing Admin web release build and mobile analysis/tests covering the newly wired source tree

Authenticated E2E verifies:

1. Employee updates notification preferences.
2. Employee registers a device token through the guarded RPC.
3. Factory Manager broadcasts to the allowed factory.
4. Employee receives exactly one in-app notification.
5. In-app delivery is marked sent and push delivery is queued.
6. Employee marks the notification read.
7. Factory Manager can view factory notification health.
8. Factory Manager cannot access organization-wide or blocked-factory notification health.
9. Employee cannot broadcast.
10. Muted category preferences suppress matching notifications.
11. Factory Manager can inspect organization-default rules but cannot read another factory's scoped rule.

## Phase boundary

Phase 13 delivers the notification domain, in-app inbox, admin controls and a production-safe FCM delivery worker contract. Actual external FCM delivery requires deployment credentials and generated mobile platform configuration.

Next development phase after validation and merge: **Phase 14 — Audit & Security Hardening**.
