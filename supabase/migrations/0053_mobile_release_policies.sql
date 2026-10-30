begin;

-- App package release metadata is intentionally public before authentication.
-- It is not a factory membership, tenant data, or a source of authorization.
create table public.mobile_release_policies (
  application_id text not null
    check (application_id ~ '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*){2,}$'),
  platform text not null check (platform in ('android', 'ios')),
  minimum_version text not null
    check (minimum_version ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\+(0|[1-9][0-9]*))?$'),
  latest_version text not null
    check (latest_version ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\+(0|[1-9][0-9]*))?$'),
  download_url text not null
    check (char_length(download_url) between 12 and 2048
      and download_url ~ '^https://[^[:space:]@/]+/[^[:space:]]*'),
  release_notes text not null default '' check (char_length(release_notes) <= 2000),
  maintenance_mode boolean not null default false,
  enabled boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  primary key (application_id, platform)
);

-- Keep the audit actor FK efficiently indexable (structural integrity gate).
create index mobile_release_updated_by_idx
on public.mobile_release_policies(updated_by);

alter table public.mobile_release_policies enable row level security;

-- Published rows are readable by authenticated clients. Anonymous clients
-- use the least-privilege SECURITY DEFINER RPC below, not direct table access.
create policy mobile_release_authenticated_read on public.mobile_release_policies
for select to authenticated using (enabled);

-- Only an actual active platform owner can see draft versions or mutate policy.
-- Organization administrators cannot modify another client's version policy.
create policy mobile_release_owner_read on public.mobile_release_policies
for select to authenticated using (public.is_platform_owner());

create policy mobile_release_owner_insert on public.mobile_release_policies
for insert to authenticated with check (public.is_platform_owner());

create policy mobile_release_owner_update on public.mobile_release_policies
for update to authenticated
using (public.is_platform_owner())
with check (public.is_platform_owner());

create policy mobile_release_owner_delete on public.mobile_release_policies
for delete to authenticated using (public.is_platform_owner());

-- No anonymous table privileges. This preserves the foundational security
-- invariant that all FactoryOS public tables are inaccessible to anon.
revoke all on public.mobile_release_policies from public, anon, authenticated;
grant select, insert, update, delete on public.mobile_release_policies to authenticated;
grant select, insert, update, delete on public.mobile_release_policies to service_role;

-- The ONLY pre-login data exposed is this published application release DTO.
-- This function cannot return drafts, staff, tenant IDs, credentials, audit
-- columns or arbitrary rows. The indexed package ID/platform pair is mandatory.
create function public.get_mobile_release_policy(
  p_application_id text,
  p_platform text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $
  select jsonb_build_object(
    'minimum_version', rp.minimum_version,
    'latest_version', rp.latest_version,
    'download_url', rp.download_url,
    'release_notes', rp.release_notes,
    'maintenance_mode', rp.maintenance_mode,
    'enabled', rp.enabled
  )
  from public.mobile_release_policies rp
  where rp.enabled
    and rp.application_id = p_application_id
    and rp.platform = p_platform
    and length(p_application_id) <= 200
  limit 1;
$;
revoke all on function public.get_mobile_release_policy(text, text)
  from public, anon, authenticated;
grant execute on function public.get_mobile_release_policy(text, text)
  to anon, authenticated;

-- Platform-owner-only edits are automatically stamped with server Auth identity.
create function public.mobile_release_stamp_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;

revoke all on function public.mobile_release_stamp_update() from public, anon, authenticated;
create trigger mobile_release_stamp
before insert or update on public.mobile_release_policies
for each row execute function public.mobile_release_stamp_update();

commit;
