-- FactoryOS RBAC scope hardening.
-- Apply immediately after 01_core.sql and before operational module schemas.
--
-- The original compatibility helper treated target_factory_id = NULL as "any scope",
-- which allowed a factory/warehouse/department-scoped role to satisfy organization-level checks.
-- This migration makes scope explicit and keeps private.has_permission only as a compatibility
-- wrapper for organization/factory checks used by existing module schemas.

create or replace function private.has_any_permission(
  target_organization_id uuid,
  permission_key text
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
     );
$$;

create or replace function private.has_org_permission(
  target_organization_id uuid,
  permission_key text
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
         and ur.factory_id is null
         and ur.warehouse_id is null
         and ur.department_id is null
         and (ur.starts_at is null or ur.starts_at <= now())
         and (ur.ends_at is null or ur.ends_at > now())
     );
$$;

create or replace function private.has_factory_permission(
  target_organization_id uuid,
  permission_key text,
  target_factory_id uuid
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
         and exists (
           select 1 from public.factories f
           where f.id = target_factory_id
             and f.organization_id = target_organization_id
         )
         and (
           (ur.factory_id is null and ur.warehouse_id is null and ur.department_id is null)
           or
           (ur.factory_id = target_factory_id and ur.warehouse_id is null and ur.department_id is null)
         )
         and (ur.starts_at is null or ur.starts_at <= now())
         and (ur.ends_at is null or ur.ends_at > now())
     );
$$;

create or replace function private.has_warehouse_permission(
  target_organization_id uuid,
  permission_key text,
  target_warehouse_id uuid
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
       join public.warehouses w
         on w.id = target_warehouse_id
        and w.organization_id = target_organization_id
       where m.organization_id = target_organization_id
         and m.user_id = (select auth.uid())
         and m.status = 'active'
         and p.key = permission_key
         and (
           (ur.factory_id is null and ur.warehouse_id is null and ur.department_id is null)
           or
           (ur.factory_id is not distinct from w.factory_id and ur.warehouse_id is null and ur.department_id is null)
           or
           (ur.warehouse_id = w.id and ur.department_id is null)
         )
         and (ur.starts_at is null or ur.starts_at <= now())
         and (ur.ends_at is null or ur.ends_at > now())
     );
$$;

create or replace function private.has_department_permission(
  target_organization_id uuid,
  permission_key text,
  target_department_id uuid
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
       join public.departments d
         on d.id = target_department_id
        and d.organization_id = target_organization_id
       where m.organization_id = target_organization_id
         and m.user_id = (select auth.uid())
         and m.status = 'active'
         and p.key = permission_key
         and (
           (ur.factory_id is null and ur.warehouse_id is null and ur.department_id is null)
           or
           (ur.factory_id is not distinct from d.factory_id and ur.warehouse_id is null and ur.department_id is null)
           or
           (ur.department_id = d.id and ur.warehouse_id is null)
         )
         and (ur.starts_at is null or ur.starts_at <= now())
         and (ur.ends_at is null or ur.ends_at > now())
     );
$$;

-- Compatibility wrapper used by existing schemas. NULL now means organization-wide only.
-- A non-null factory allows an organization-wide role or an assignment to that exact factory,
-- but never a narrower warehouse/department role.
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
  select case
    when target_factory_id is null
      then private.has_org_permission(target_organization_id, permission_key)
    else private.has_factory_permission(target_organization_id, permission_key, target_factory_id)
  end;
$$;

create or replace function private.can_access_factory(
  target_organization_id uuid,
  target_factory_id uuid
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
       where m.organization_id = target_organization_id
         and m.user_id = (select auth.uid())
         and m.status = 'active'
         and exists (
           select 1 from public.factories f
           where f.id = target_factory_id
             and f.organization_id = target_organization_id
         )
         and (
           (ur.factory_id is null and ur.warehouse_id is null and ur.department_id is null)
           or (ur.factory_id = target_factory_id and ur.warehouse_id is null and ur.department_id is null)
           or exists (
             select 1 from public.warehouses w
             where w.id = ur.warehouse_id and w.organization_id = target_organization_id and w.factory_id = target_factory_id
           )
           or exists (
             select 1 from public.departments d
             where d.id = ur.department_id and d.organization_id = target_organization_id and d.factory_id = target_factory_id
           )
         )
         and (ur.starts_at is null or ur.starts_at <= now())
         and (ur.ends_at is null or ur.ends_at > now())
     );
$$;

create or replace function private.can_access_warehouse(
  target_organization_id uuid,
  target_warehouse_id uuid
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
       join public.warehouses w
         on w.id = target_warehouse_id
        and w.organization_id = target_organization_id
       where m.organization_id = target_organization_id
         and m.user_id = (select auth.uid())
         and m.status = 'active'
         and (
           (ur.factory_id is null and ur.warehouse_id is null and ur.department_id is null)
           or (ur.factory_id is not distinct from w.factory_id and ur.warehouse_id is null and ur.department_id is null)
           or ur.warehouse_id = w.id
         )
         and (ur.starts_at is null or ur.starts_at <= now())
         and (ur.ends_at is null or ur.ends_at > now())
     );
$$;

create or replace function private.can_access_department(
  target_organization_id uuid,
  target_department_id uuid
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
       join public.departments d
         on d.id = target_department_id
        and d.organization_id = target_organization_id
       where m.organization_id = target_organization_id
         and m.user_id = (select auth.uid())
         and m.status = 'active'
         and (
           (ur.factory_id is null and ur.warehouse_id is null and ur.department_id is null)
           or (ur.factory_id is not distinct from d.factory_id and ur.warehouse_id is null and ur.department_id is null)
           or ur.department_id = d.id
         )
         and (ur.starts_at is null or ur.starts_at <= now())
         and (ur.ends_at is null or ur.ends_at > now())
     );
$$;

revoke all on function private.has_any_permission(uuid, text) from public;
revoke all on function private.has_org_permission(uuid, text) from public;
revoke all on function private.has_factory_permission(uuid, text, uuid) from public;
revoke all on function private.has_warehouse_permission(uuid, text, uuid) from public;
revoke all on function private.has_department_permission(uuid, text, uuid) from public;
revoke all on function private.can_access_factory(uuid, uuid) from public;
revoke all on function private.can_access_warehouse(uuid, uuid) from public;
revoke all on function private.can_access_department(uuid, uuid) from public;
revoke all on function private.has_permission(uuid, text, uuid) from public;

grant execute on function private.has_any_permission(uuid, text) to authenticated;
grant execute on function private.has_org_permission(uuid, text) to authenticated;
grant execute on function private.has_factory_permission(uuid, text, uuid) to authenticated;
grant execute on function private.has_warehouse_permission(uuid, text, uuid) to authenticated;
grant execute on function private.has_department_permission(uuid, text, uuid) to authenticated;
grant execute on function private.can_access_factory(uuid, uuid) to authenticated;
grant execute on function private.can_access_warehouse(uuid, uuid) to authenticated;
grant execute on function private.can_access_department(uuid, uuid) to authenticated;
grant execute on function private.has_permission(uuid, text, uuid) to authenticated;

-- A role assignment may have exactly one effective narrow scope. Warehouse/department scopes
-- are tied to their parent factory, and the role itself must belong to the same organization
-- (or be an explicitly global/system role).
create or replace function private.validate_user_role_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  role_org uuid;
  factory_org uuid;
  warehouse_org uuid;
  warehouse_factory uuid;
  department_org uuid;
  department_factory uuid;
begin
  select r.organization_id into role_org from public.roles r where r.id = new.role_id;
  if not found then raise exception 'role not found'; end if;
  if role_org is not null and role_org <> new.organization_id then
    raise exception 'role assignment organization mismatch';
  end if;

  if not exists (
    select 1 from public.organization_memberships m
    where m.organization_id = new.organization_id and m.user_id = new.user_id
  ) then
    raise exception 'role assignment requires organization membership';
  end if;

  if new.warehouse_id is not null and new.department_id is not null then
    raise exception 'role assignment cannot combine warehouse and department scopes';
  end if;

  if new.factory_id is not null then
    select f.organization_id into factory_org from public.factories f where f.id = new.factory_id;
    if factory_org is null or factory_org <> new.organization_id then
      raise exception 'role assignment factory organization mismatch';
    end if;
  end if;

  if new.warehouse_id is not null then
    select w.organization_id, w.factory_id into warehouse_org, warehouse_factory
    from public.warehouses w where w.id = new.warehouse_id;
    if warehouse_org is null or warehouse_org <> new.organization_id then
      raise exception 'role assignment warehouse organization mismatch';
    end if;
    if new.factory_id is distinct from warehouse_factory then
      raise exception 'role assignment warehouse/factory scope mismatch';
    end if;
  end if;

  if new.department_id is not null then
    select d.organization_id, d.factory_id into department_org, department_factory
    from public.departments d where d.id = new.department_id;
    if department_org is null or department_org <> new.organization_id then
      raise exception 'role assignment department organization mismatch';
    end if;
    if new.factory_id is distinct from department_factory then
      raise exception 'role assignment department/factory scope mismatch';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_user_role_scope() from public;
drop trigger if exists user_roles_validate_scope on public.user_roles;
create trigger user_roles_validate_scope
before insert or update on public.user_roles
for each row execute function private.validate_user_role_scope();

-- Core scope-aware RLS policies.
drop policy if exists organization_settings_update_admin on public.organization_settings;
create policy organization_settings_update_admin on public.organization_settings
for update to authenticated
using ((select private.has_org_permission(organization_id, 'settings.manage')))
with check ((select private.has_org_permission(organization_id, 'settings.manage')));

drop policy if exists factories_select_member on public.factories;
create policy factories_select_member on public.factories
for select to authenticated
using ((select private.can_access_factory(organization_id, id)));

drop policy if exists factories_insert_admin on public.factories;
create policy factories_insert_admin on public.factories
for insert to authenticated
with check ((select private.has_org_permission(organization_id, 'factory.manage')));

drop policy if exists factories_update_admin on public.factories;
create policy factories_update_admin on public.factories
for update to authenticated
using ((select private.has_factory_permission(organization_id, 'factory.manage', id)))
with check ((select private.has_factory_permission(organization_id, 'factory.manage', id)));

drop policy if exists departments_select_member on public.departments;
create policy departments_select_member on public.departments
for select to authenticated
using ((select private.can_access_department(organization_id, id)));

drop policy if exists departments_manage_admin on public.departments;
create policy departments_manage_admin on public.departments
for all to authenticated
using (
  case when factory_id is null
    then (select private.has_org_permission(organization_id, 'factory.manage'))
    else (select private.has_factory_permission(organization_id, 'factory.manage', factory_id))
  end
)
with check (
  case when factory_id is null
    then (select private.has_org_permission(organization_id, 'factory.manage'))
    else (select private.has_factory_permission(organization_id, 'factory.manage', factory_id))
  end
);

drop policy if exists warehouses_select_member on public.warehouses;
create policy warehouses_select_member on public.warehouses
for select to authenticated
using ((select private.can_access_warehouse(organization_id, id)));

drop policy if exists warehouses_manage_admin on public.warehouses;
create policy warehouses_manage_admin on public.warehouses
for all to authenticated
using (
  case when factory_id is null
    then (select private.has_org_permission(organization_id, 'factory.manage'))
    else (select private.has_factory_permission(organization_id, 'factory.manage', factory_id))
  end
)
with check (
  case when factory_id is null
    then (select private.has_org_permission(organization_id, 'factory.manage'))
    else (select private.has_factory_permission(organization_id, 'factory.manage', factory_id))
  end
);

drop policy if exists warehouse_locations_select_member on public.warehouse_locations;
create policy warehouse_locations_select_member on public.warehouse_locations
for select to authenticated
using ((select private.can_access_warehouse(organization_id, warehouse_id)));

drop policy if exists warehouse_locations_manage_admin on public.warehouse_locations;
create policy warehouse_locations_manage_admin on public.warehouse_locations
for all to authenticated
using ((select private.has_warehouse_permission(organization_id, 'factory.manage', warehouse_id)))
with check ((select private.has_warehouse_permission(organization_id, 'factory.manage', warehouse_id)));

drop policy if exists memberships_select_org_member on public.organization_memberships;
create policy memberships_select_org_member on public.organization_memberships
for select to authenticated
using (
  user_id = (select auth.uid())
  or (select private.has_org_permission(organization_id, 'settings.manage'))
);

drop policy if exists user_roles_select_member on public.user_roles;
create policy user_roles_select_member on public.user_roles
for select to authenticated
using (
  user_id = (select auth.uid())
  or (select private.has_org_permission(organization_id, 'settings.manage'))
);

drop policy if exists organization_modules_manage_admin on public.organization_modules;
create policy organization_modules_manage_admin on public.organization_modules
for all to authenticated
using ((select private.has_org_permission(organization_id, 'settings.manage')))
with check ((select private.has_org_permission(organization_id, 'settings.manage')));

drop policy if exists audit_logs_select_authorized on public.audit_logs;
create policy audit_logs_select_authorized on public.audit_logs
for select to authenticated
using (
  organization_id is not null
  and (
    (factory_id is null and (select private.has_org_permission(organization_id, 'audit.read')))
    or
    (factory_id is not null and (select private.has_factory_permission(organization_id, 'audit.read', factory_id)))
  )
);
