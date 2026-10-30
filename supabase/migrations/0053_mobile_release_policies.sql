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
on public.mobile_release_policies(updated_by)
where updated_by is not null;

alter table public.mobile_release_policies enable row level security;

-- Disabled / draft policies cannot be queried by anonymous users.
create policy mobile_release_public_read on public.mobile_release_policies
for select to anon, authenticated using (enabled);

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

-- Exact grants are needed on newer Supabase projects; do not grant DML to anon.
revoke all on public.mobile_release_policies from public, anon, authenticated;
grant select on public.mobile_release_policies to anon;
grant select, insert, update, delete on public.mobile_release_policies to authenticated;
grant select, insert, update, delete on public.mobile_release_policies to service_role;

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
