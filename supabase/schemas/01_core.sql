-- FactoryOS core declarative schema
-- Foundation only: organizations, factories, memberships, RBAC, module config and audit.
-- Operational module schemas are intentionally added later in dependency order.

create schema if not exists private;

create type public.membership_status as enum ('invited', 'active', 'suspended', 'inactive');
create type public.entity_status as enum ('active', 'inactive', 'archived');
create type public.audit_action as enum ('create', 'update', 'archive', 'restore', 'delete', 'approve', 'reject', 'login', 'logout', 'other');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  slug text not null,
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organizations_code_nonempty check (length(btrim(code)) > 0),
  constraint organizations_name_nonempty check (length(btrim(name)) > 0),
  constraint organizations_slug_nonempty check (length(btrim(slug)) > 0),
  constraint organizations_code_unique unique (code),
  constraint organizations_slug_unique unique (slug)
);

create table public.organization_settings (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  currency_code text not null default 'INR',
  timezone text not null default 'Asia/Kolkata',
  financial_year_start_month smallint not null default 4,
  default_language text not null default 'en',
  app_display_name text,
  primary_color text,
  secondary_color text,
  support_email text,
  support_phone text,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organization_settings_fy_month check (financial_year_start_month between 1 and 12),
  constraint organization_settings_currency check (currency_code ~ '^[A-Z]{3}$')
);

create table public.factories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  timezone text,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  country_code text not null default 'IN',
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint factories_org_code_unique unique (organization_id, code),
  constraint factories_name_nonempty check (length(btrim(name)) > 0)
);

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  code text not null,
  name text not null,
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint departments_org_factory_code_unique unique nulls not distinct (organization_id, factory_id, code)
);

create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  code text not null,
  name text not null,
  warehouse_type text not null default 'general',
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint warehouses_org_code_unique unique (organization_id, code)
);

create table public.warehouse_locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  code text not null,
  name text,
  zone text,
  aisle text,
  rack text,
  bin text,
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint warehouse_locations_code_unique unique (warehouse_id, code)
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  avatar_path text,
  locale text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_name_nonempty check (length(btrim(full_name)) > 0)
);

create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status public.membership_status not null default 'invited',
  invited_by uuid references auth.users(id) on delete set null,
  invited_at timestamptz not null default now(),
  activated_at timestamptz,
  deactivated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organization_memberships_unique unique (organization_id, user_id)
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  key text not null,
  name text not null,
  description text,
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_key_nonempty check (length(btrim(key)) > 0),
  constraint roles_scope_key_unique unique nulls not distinct (organization_id, key)
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  module_key text not null,
  description text,
  created_at timestamptz not null default now(),
  constraint permissions_key_nonempty check (length(btrim(key)) > 0)
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  factory_id uuid references public.factories(id) on delete cascade,
  warehouse_id uuid references public.warehouses(id) on delete cascade,
  department_id uuid references public.departments(id) on delete cascade,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_roles_scope_unique unique nulls not distinct (
    organization_id, user_id, role_id, factory_id, warehouse_id, department_id
  ),
  constraint user_roles_time_window check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create table public.organization_modules (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  module_key text not null,
  is_enabled boolean not null default true,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (organization_id, module_key)
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  action public.audit_action not null,
  entity_type text not null,
  entity_id text,
  old_values jsonb,
  new_values jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint audit_logs_entity_type_nonempty check (length(btrim(entity_type)) > 0)
);

create index organization_memberships_user_status_idx
  on public.organization_memberships (user_id, status, organization_id);
create index factories_org_status_idx on public.factories (organization_id, status);
create index departments_org_factory_idx on public.departments (organization_id, factory_id, status);
create index warehouses_org_factory_idx on public.warehouses (organization_id, factory_id, status);
create index user_roles_user_org_active_idx on public.user_roles (user_id, organization_id, is_active);
create index user_roles_role_idx on public.user_roles (role_id);
create index role_permissions_permission_idx on public.role_permissions (permission_id);
create index audit_logs_org_created_idx on public.audit_logs (organization_id, created_at desc);
create index audit_logs_entity_idx on public.audit_logs (organization_id, entity_type, entity_id, created_at desc);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger organizations_set_updated_at before update on public.organizations
for each row execute function private.set_updated_at();
create trigger organization_settings_set_updated_at before update on public.organization_settings
for each row execute function private.set_updated_at();
create trigger factories_set_updated_at before update on public.factories
for each row execute function private.set_updated_at();
create trigger departments_set_updated_at before update on public.departments
for each row execute function private.set_updated_at();
create trigger warehouses_set_updated_at before update on public.warehouses
for each row execute function private.set_updated_at();
create trigger warehouse_locations_set_updated_at before update on public.warehouse_locations
for each row execute function private.set_updated_at();
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function private.set_updated_at();
create trigger organization_memberships_set_updated_at before update on public.organization_memberships
for each row execute function private.set_updated_at();
create trigger roles_set_updated_at before update on public.roles
for each row execute function private.set_updated_at();
create trigger user_roles_set_updated_at before update on public.user_roles
for each row execute function private.set_updated_at();
create trigger organization_modules_set_updated_at before update on public.organization_modules
for each row execute function private.set_updated_at();

-- SECURITY DEFINER is deliberately isolated in a non-exposed schema to avoid RLS recursion.
-- The function validates auth.uid(), uses a fixed search_path and is not executable by PUBLIC.
create or replace function private.is_org_member(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select (select auth.uid()) is not null
     and exists (
       select 1
       from public.organization_memberships m
       where m.organization_id = target_organization_id
         and m.user_id = (select auth.uid())
         and m.status = 'active'
     );
$$;

create or replace function private.has_permission(
  target_organization_id uuid,
  permission_key text,
  target_factory_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select (select auth.uid()) is not null
     and exists (
       select 1
       from public.organization_memberships m
       join public.user_roles ur
         on ur.organization_id = m.organization_id
        and ur.user_id = m.user_id
        and ur.is_active
       join public.roles r
         on r.id = ur.role_id
        and r.is_active
        and (r.organization_id is null or r.organization_id = target_organization_id)
       join public.role_permissions rp on rp.role_id = r.id
       join public.permissions p on p.id = rp.permission_id
       where m.organization_id = target_organization_id
         and m.user_id = (select auth.uid())
         and m.status = 'active'
         and p.key = permission_key
         and (ur.starts_at is null or ur.starts_at <= now())
         and (ur.ends_at is null or ur.ends_at > now())
         and (
           target_factory_id is null
           or ur.factory_id is null
           or ur.factory_id = target_factory_id
         )
     );
$$;

revoke all on function private.is_org_member(uuid) from public;
revoke all on function private.has_permission(uuid, text, uuid) from public;
grant execute on function private.is_org_member(uuid) to authenticated;
grant execute on function private.has_permission(uuid, text, uuid) to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_settings enable row level security;
alter table public.factories enable row level security;
alter table public.departments enable row level security;
alter table public.warehouses enable row level security;
alter table public.warehouse_locations enable row level security;
alter table public.profiles enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_roles enable row level security;
alter table public.organization_modules enable row level security;
alter table public.audit_logs enable row level security;

create policy organizations_select_member on public.organizations
for select to authenticated
using ((select private.is_org_member(id)));

create policy organization_settings_select_member on public.organization_settings
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy organization_settings_update_admin on public.organization_settings
for update to authenticated
using ((select private.has_permission(organization_id, 'settings.manage', null)))
with check ((select private.has_permission(organization_id, 'settings.manage', null)));

create policy factories_select_member on public.factories
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy factories_insert_admin on public.factories
for insert to authenticated
with check ((select private.has_permission(organization_id, 'factory.manage', id)));

create policy factories_update_admin on public.factories
for update to authenticated
using ((select private.has_permission(organization_id, 'factory.manage', id)))
with check ((select private.has_permission(organization_id, 'factory.manage', id)));

create policy departments_select_member on public.departments
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy departments_manage_admin on public.departments
for all to authenticated
using ((select private.has_permission(organization_id, 'factory.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'factory.manage', factory_id)));

create policy warehouses_select_member on public.warehouses
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy warehouses_manage_admin on public.warehouses
for all to authenticated
using ((select private.has_permission(organization_id, 'factory.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'factory.manage', factory_id)));

create policy warehouse_locations_select_member on public.warehouse_locations
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy warehouse_locations_manage_admin on public.warehouse_locations
for all to authenticated
using ((select private.has_permission(organization_id, 'factory.manage', null)))
with check ((select private.has_permission(organization_id, 'factory.manage', null)));

create policy profiles_select_self on public.profiles
for select to authenticated
using (user_id = (select auth.uid()));

create policy profiles_update_self on public.profiles
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy memberships_select_org_member on public.organization_memberships
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy roles_select_org_member on public.roles
for select to authenticated
using (organization_id is null or (select private.is_org_member(organization_id)));

create policy permissions_select_authenticated on public.permissions
for select to authenticated
using (true);

create policy role_permissions_select_member on public.role_permissions
for select to authenticated
using (
  exists (
    select 1 from public.roles r
    where r.id = role_permissions.role_id
      and (r.organization_id is null or (select private.is_org_member(r.organization_id)))
  )
);

create policy user_roles_select_member on public.user_roles
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy organization_modules_select_member on public.organization_modules
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy organization_modules_manage_admin on public.organization_modules
for all to authenticated
using ((select private.has_permission(organization_id, 'settings.manage', null)))
with check ((select private.has_permission(organization_id, 'settings.manage', null)));

create policy audit_logs_select_authorized on public.audit_logs
for select to authenticated
using (
  organization_id is not null
  and (select private.has_permission(organization_id, 'audit.read', factory_id))
);

-- Audit logs are append-only through trusted server-side workflows. No authenticated
-- INSERT/UPDATE/DELETE policy is intentionally provided here.

-- Explicit Data API grants. RLS remains authoritative for row access.
grant usage on schema public to authenticated;
grant select on public.organizations to authenticated;
grant select, update on public.organization_settings to authenticated;
grant select, insert, update on public.factories to authenticated;
grant select, insert, update, delete on public.departments to authenticated;
grant select, insert, update, delete on public.warehouses to authenticated;
grant select, insert, update, delete on public.warehouse_locations to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.organization_memberships to authenticated;
grant select on public.roles to authenticated;
grant select on public.permissions to authenticated;
grant select on public.role_permissions to authenticated;
grant select on public.user_roles to authenticated;
grant select, insert, update, delete on public.organization_modules to authenticated;
grant select on public.audit_logs to authenticated;

-- No anon grants are provided for operational data.