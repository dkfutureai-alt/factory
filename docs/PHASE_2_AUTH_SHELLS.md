# Phase 2 — Authentication, Onboarding and Access

## Implemented

- Supabase email/password sign-in for Admin Web and Mobile.
- Server-side Supabase Auth invitation function; client apps never receive a service-role key.
- Invitation intent stores role, factory assignments, expiry and lifecycle status separately from credentials.
- First-login onboarding on both web and mobile for profile, phone and password completion.
- Atomic invitation acceptance creates/reactivates organization membership and factory assignments.
- Admin user-access screen to invite users, edit roles, reassign factories, revoke invitations and deactivate access.
- Role-escalation protection prevents Organization Admins from creating Platform Owners or removing their own admin role.
- Factory Manager membership administration is scoped to factories the manager is actually assigned to.
- Employee-facing factory reads remain restricted to assigned factories by RLS.
- Mobile module visibility is role-aware; module-specific business RLS continues in each later module phase.
- Access changes are audited without writing invitation email addresses into audit metadata.
- Supabase Flutter uses the current `publishableKey` API with temporary legacy environment-key fallback.

## Automated validation

The Supabase workflow validates clean migrations, seed data, RLS structure, invitation acceptance, role reassignment, factory reassignment, role-escalation denial and Factory Manager scope denial. The Flutter workflow validates shared core tests, admin analysis, an admin release web build and mobile analysis.

## Production configuration required

Before production invitation email delivery, deploy `invite-user`, configure Supabase Auth email/SMTP settings and set `FACTORYOS_INVITE_REDIRECT_URL` for the production web/deep-link destination. Local validation covers the application and database access flow but does not claim third-party SMTP delivery.

## Phase 2 completion boundary

The core invitation → onboarding → role assignment → factory assignment → authenticated access flow is implemented. Android/iOS release runners, production SMTP and production deep-link configuration remain environment/release tasks rather than access-logic gaps.
