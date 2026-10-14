# Notifications & FCM development checkpoint (2026-10-14)

## Scope

Design-first Notifications / FCM foundation for FactoryOS. SVG designs 44–47 cover Admin Notification Center, Mobile Notification Inbox, Notification Preferences and Alert Rules / Templates.

## Flutter implementation

- Added typed notification models for normal/high/critical priorities, in-app/push channels, notification records, preferences, overview counts and alert rules.
- Added a replaceable `NotificationRepository` with fictional DKIM preview data.
- Added Admin Notification Center with unread, critical, action-required and push-enabled KPIs plus live inbox navigation.
- Added Admin Alert Rules & Templates screen for role-scoped operational triggers.
- Added Employee and Driver mobile notification inboxes from the existing notification-bell affordances.
- Added Notification Preferences with mandatory critical alerts, user-selectable non-critical categories and quiet-hours presentation.
- Added a `NotificationPushPort` boundary for device registration / unregistration.
- `PreviewNotificationPushPort.supportsPush` is intentionally `false`; no Firebase SDK, Firebase project credentials or platform push configuration is claimed in this milestone.

## Backend foundation

Repository-only schema `supabase/schemas/10_notifications.sql` adds:

- notification templates;
- role/factory-scoped notification rules;
- per-user device tokens;
- notification preferences and quiet hours;
- notification event records;
- per-user recipients/read state/push status;
- service-side delivery-attempt audit records;
- factory/template/recipient tenant-integrity guards;
- mandatory critical-alert preference enforcement;
- self-only `mark_notification_read(uuid)` RPC.

Security intent:

- device tokens are readable/mutable only by their owning authenticated user through RLS;
- delivery-attempt records have no authenticated client policies and are intended for trusted service-side dispatch only;
- notification and recipient mutations are not exposed directly to authenticated clients;
- critical alerts cannot be disabled by user preferences;
- push bodies must not include private employee fields, credentials or secrets;
- managers may read only notifications allowed by notification RBAC/factory scope, not raw device-token diagnostics.

The existing global `private.has_permission(..., target_factory_id null)` scope-semantics concern remains a pre-deployment review item and has **not** been represented as verified database isolation.

## Demo seed

`supabase/seed/09_demo_notifications.sql` adds:

- `notification.read` and `notification.manage` permissions;
- Company Owner and Factory Manager permission grants;
- fictional templates for low stock, maintenance breakdown, leave approval and assigned delivery;
- PLANT-01 role/factory alert rules;
- fictional notification event rows only.

No auth users, recipient rows, device tokens or real FCM tokens are seeded.

## Verification

- Flutter 3.47.7 analysis passes with `--fatal-infos` on accepted Notifications code head `eb1cea5b2cd0530d8b161d1c9fc57e0dd1be5ba5`.
- Complete Flutter suite passes **53 tests** at that code milestone.
- Admin → Notifications → Alert Rules is widget-tested at 1440×1024 with zero render exceptions.
- Employee → notification bell → inbox → preferences is widget-tested at 390×844 with zero render exceptions.
- Driver → notification bell → assigned-driver inbox is widget-tested at 390×844 with zero render exceptions.
- Notification domain tests verify unread/critical/action counts, bounded zero-safe push-enabled rate, mandatory critical preferences, push-channel rule derivation and device-registration validation.
- QA exposed older mobile layout defects while exercising the new notification routes: Employee quick-action cards overflowed by up to ~11 px and Driver cards by up to 28 px. Both grids were made mobile-safe.
- The taller corrected Driver grid exposed an older brittle Driver → Delivery test; the test now settles `ensureVisible` scrolling before tapping, matching actual mobile interaction.
- All previously accepted Inventory, Production, Purchase, HR, Sales, Fleet, Delivery, Maintenance, Reporting, Warehouse and Dispatch Flutter tests remain green.

## Not yet production-complete

- The Notifications schema has **not** been applied to a dedicated FactoryOS Supabase project.
- Notification RLS, cross-tenant guards, critical-preference trigger and mark-read RPC have not been executed in PostgreSQL.
- No Firebase project/configuration is connected to FactoryOS.
- Android/iOS/web FCM platform setup, permissions, token refresh lifecycle and foreground/background handlers are not implemented.
- There is no trusted server-side dispatcher/worker yet to resolve recipients, respect non-critical quiet hours, send FCM messages, retry failures and record delivery attempts.
- Preview notification state is local/static and is not synced to Supabase.

## Next dependency order

1. Pre-deployment RBAC / permission-scope hardening and database integration-test harness.
2. Create/connect a dedicated FactoryOS Supabase project after organization/cost confirmation; never reuse `janseva-production`.
3. Apply schemas in dependency order through Notifications and run RLS/RPC/cross-tenant/ledger/security/performance tests.
4. Replace preview Auth and repositories with live Supabase-backed implementations.
5. Add trusted notification dispatch plus real FCM Android/iOS/web registration and delivery lifecycle.
6. Connect authorized live Reporting aggregates and audited exports.
7. Complete Warehouse / Dispatch transactional backend and full E2E workflow.
8. Add scanner/POD mobile platform integrations and run production E2E QA.

**This is a verified repository development milestone, not a live FCM or production-completion claim.**
