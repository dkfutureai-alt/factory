begin;

create extension if not exists pgcrypto;

create type public.app_role as enum (
  'platform_owner',
  'org_admin',
  'factory_manager',
  'supervisor',
  'employee',
  'driver',
  'viewer'
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 120),
  code text not null unique check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  legal_name text,
  country_code text not null default 'IN' check (char_length(country_code) = 2),
  timezone text not null default 'Asia/Kolkata',
  currency_code text not null default 'INR' check (char_length(currency_code) = 3),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.factories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (char_length(trim(name)) between 2 and 120),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  country_code text not null default 'IN' check (char_length(country_code) = 2),
  timezone text not null default 'Asia/Kolkata',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (id, organization_id)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  locale text not null default 'en-IN',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  is_active boolean not null default true,
  joined_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create table public.factory_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  factory_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete cascade,
  unique (factory_id, user_id)
);

create table public.app_modules (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{1,63}$'),
  name text not null,
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

create table public.organization_modules (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  module_key text not null references public.app_modules(key) on delete restrict,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (organization_id, module_key)
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index organization_members_user_idx on public.organization_members(user_id) where is_active;
create index factory_members_user_idx on public.factory_members(user_id) where is_active;
create index factories_org_idx on public.factories(organization_id) where is_active;
create index audit_logs_org_created_idx on public.audit_logs(organization_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger organizations_set_updated_at before update on public.organizations
for each row execute function public.set_updated_at();
create trigger factories_set_updated_at before update on public.factories
for each row execute function public.set_updated_at();
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger organization_members_set_updated_at before update on public.organization_members
for each row execute function public.set_updated_at();
create trigger factory_members_set_updated_at before update on public.factory_members
for each row execute function public.set_updated_at();
create trigger organization_modules_set_updated_at before update on public.organization_modules
for each row execute function public.set_updated_at();

create or replace function public.is_platform_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members om
    where om.user_id = auth.uid()
      and om.role = 'platform_owner'
      and om.is_active
  );
$$;

create or replace function public.is_org_member(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner() or exists (
    select 1
    from public.organization_members om
    where om.organization_id = target_organization_id
      and om.user_id = auth.uid()
      and om.is_active
  );
$$;

create or replace function public.has_org_role(target_organization_id uuid, allowed_roles public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner() or exists (
    select 1
    from public.organization_members om
    where om.organization_id = target_organization_id
      and om.user_id = auth.uid()
      and om.is_active
      and om.role = any(allowed_roles)
  );
$$;

create or replace function public.is_factory_member(target_factory_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner() or exists (
    select 1
    from public.factory_members fm
    join public.organization_members om
      on om.organization_id = fm.organization_id
     and om.user_id = fm.user_id
     and om.is_active
    where fm.factory_id = target_factory_id
      and fm.user_id = auth.uid()
      and fm.is_active
  ) or exists (
    select 1
    from public.factories f
    join public.organization_members om on om.organization_id = f.organization_id
    where f.id = target_factory_id
      and om.user_id = auth.uid()
      and om.is_active
      and om.role in ('org_admin', 'factory_manager')
  );
$$;

grant execute on function public.is_platform_owner() to authenticated;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.has_org_role(uuid, public.app_role[]) to authenticated;
grant execute on function public.is_factory_member(uuid) to authenticated;

alter table public.organizations enable row level security;
alter table public.factories enable row level security;
alter table public.profiles enable row level security;
alter table public.organization_members enable row level security;
alter table public.factory_members enable row level security;
alter table public.app_modules enable row level security;
alter table public.organization_modules enable row level security;
alter table public.audit_logs enable row level security;

create policy organizations_select on public.organizations
for select to authenticated
using (public.is_org_member(id));

create policy organizations_update on public.organizations
for update to authenticated
using (public.has_org_role(id, array['org_admin']::public.app_role[]))
with check (public.has_org_role(id, array['org_admin']::public.app_role[]));

create policy factories_select on public.factories
for select to authenticated
using (public.is_org_member(organization_id));

create policy factories_manage on public.factories
for all to authenticated
using (public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy profiles_select_self_or_coworker on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or public.is_platform_owner()
  or exists (
    select 1
    from public.organization_members mine
    join public.organization_members theirs on theirs.organization_id = mine.organization_id
    where mine.user_id = auth.uid()
      and mine.is_active
      and theirs.user_id = profiles.id
      and theirs.is_active
  )
);

create policy profiles_update_self on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy organization_members_select on public.organization_members
for select to authenticated
using (public.is_org_member(organization_id));

create policy organization_members_manage on public.organization_members
for all to authenticated
using (public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy factory_members_select on public.factory_members
for select to authenticated
using (public.is_org_member(organization_id));

create policy factory_members_manage on public.factory_members
for all to authenticated
using (public.has_org_role(organization_id, array['org_admin','factory_manager']::public.app_role[]))
with check (public.has_org_role(organization_id, array['org_admin','factory_manager']::public.app_role[]));

create policy app_modules_read on public.app_modules
for select to authenticated
using (is_active or public.is_platform_owner());

create policy organization_modules_read on public.organization_modules
for select to authenticated
using (public.is_org_member(organization_id));

create policy organization_modules_manage on public.organization_modules
for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy audit_logs_read on public.audit_logs
for select to authenticated
using (
  public.is_platform_owner()
  or (organization_id is not null and public.has_org_role(organization_id, array['org_admin','factory_manager']::public.app_role[]))
);

revoke insert, update, delete on public.audit_logs from authenticated;

insert into public.app_modules (key, name, description, sort_order) values
  ('dashboard', 'Dashboard', 'Operational dashboard and exceptions', 10),
  ('hr', 'HR & Attendance', 'Employees, attendance, leave and holidays', 20),
  ('inventory', 'Inventory', 'Stock, scanning and movement ledger', 30),
  ('production', 'Production', 'Production planning and execution', 40),
  ('quality', 'Quality', 'Inspection and quality controls', 50),
  ('purchase', 'Purchase', 'Suppliers and purchase operations', 60),
  ('sales', 'Sales', 'Customers, orders and sales operations', 70),
  ('warehouse', 'Warehouse', 'Warehouse operations', 80),
  ('vehicles', 'Vehicles & Drivers', 'Fleet, drivers, trips and fuel', 90),
  ('delivery', 'Dispatch & Delivery', 'Dispatch, proof of delivery and returns', 100),
  ('maintenance', 'Maintenance', 'Assets, work orders and downtime', 110),
  ('reports', 'Reports', 'Operational and management reports', 120)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  sort_order = excluded.sort_order;

commit;
