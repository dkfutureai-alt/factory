# FactoryOS Database Release Verification

This is a production release **runbook**, not an instruction to execute automatically. Never deploy FactoryOS to Janseva, Salon or any other application's Supabase project.

1. Connect the **dedicated and owner-approved** FactoryOS Supabase project. Confirm its exact 20-character project ref, region, cost plan and Auth redirect domain.
2. Require a green final-head Supabase Foundation Checks run: Deno validation, migration reset, SQL smoke/RLS and authenticated business E2E.
3. Review `supabase/migrations/0041_notification_dispatch_claims.sql`, `0042_foreign_key_index_hardening.sql` and `0043_invitation_expiry_reissue.sql` with the release owner. Review migration locks and run a backup/recovery exercise.
4. Configure project-specific SMTP and Auth Site URL/redirect allowlist, FCM service account, push worker secret, GitHub protected environment and least-privilege smoke user.
5. Use manual protected `Supabase Production Release` from `main`, with `confirm=DEPLOY` and an independently typed exact FactoryOS ref. The SQL migration runs **before** the new invite-user Edge Function is published.
6. Inspect SQL schema, private Storage/RLS, report indexes, service-role-only invitation expiration RPC and notification-claim RPC grants.
7. Run protected production smoke, Admin web sign-in, an actual invite-email roundtrip, FCM Android/iOS push, and a real-device cross-tenant role pilot.
8. Log deployment SHA, project ref, checksum, audit/notification health, test evidence, recovery owner and explicit release sign-off. Never run remote `db reset` or insert fictional seed data.

### Reissue verification

- An expired invitation can be reissued to the same normalized email **within its own organization**.
- A still-active invitation remains unique; a different organization remains untouched.
- Anonymous/authenticated callers cannot invoke `expire_stale_user_invitations` directly.
- Remote invitation redirects must be allowlisted HTTPS destinations; SMTP provider delivery is externally verified.

### Go-live limitation

Passing repository tests does not prove production SMTP, FCM/APNs, DNS/hosting or physical-device behavior. Keep issue #12 open until the production smoke and owner evidence are recorded.
