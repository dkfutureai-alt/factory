begin;

-- Supabase projects created after the 2026 Data API privilege-default change do
-- not automatically expose new public tables. Earlier FactoryOS migrations
-- explicitly grant module tables but its 0001 foundation predated this rule.
-- RLS is still the row-level authorization boundary; these are only API grants.
--
-- Do not grant anonymous access to factory or customer data. Keep backend-only
-- service_role access explicit without giving clients a secret key.
revoke all privileges on all tables in schema public from anon;
revoke all privileges on all sequences in schema public from anon;

-- Normalize the original eight foundation tables regardless of whether the
-- project was created with legacy automatic CRUD privileges or the new defaults.
revoke all privileges on
  public.organizations,
  public.factories,
  public.profiles,
  public.organization_members,
  public.factory_members,
  public.app_modules,
  public.organization_modules,
  public.audit_logs
from authenticated;

-- Organizations and profile creation are controlled by privileged onboarding
-- paths. Direct authenticated clients only read/update rows allowed by RLS.
grant select, update on public.organizations, public.profiles to authenticated;

-- Factory, membership and module management retain the existing Phase 1 RLS
-- policy enforcement and subsequent scoped role hardening.
grant select, insert, update, delete on
  public.factories,
  public.organization_members,
  public.factory_members,
  public.organization_modules
to authenticated;

-- Reference modules and the tamper-protected audit history are read only.
grant select on public.app_modules, public.audit_logs to authenticated;

-- Edge Functions need a service-role client for authorized invitations and
-- dispatch. The privileged server role is never placed in web/mobile clients.
-- Limit these grants to ordinary DML; do not grant TRUNCATE or TRIGGER.
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

commit;
