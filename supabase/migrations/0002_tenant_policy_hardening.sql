begin;

-- Phase 2 tightens broad Phase 1 read policies before employee-facing clients are connected.

drop policy if exists factories_select on public.factories;
create policy factories_select on public.factories
for select to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or exists (
    select 1
    from public.factory_members fm
    where fm.factory_id = factories.id
      and fm.user_id = auth.uid()
      and fm.is_active
  )
);

drop policy if exists organization_members_select on public.organization_members;
create policy organization_members_select on public.organization_members
for select to authenticated
using (
  user_id = auth.uid()
  or public.is_platform_owner()
  or public.has_org_role(
    organization_id,
    array['org_admin','factory_manager']::public.app_role[]
  )
);

drop policy if exists factory_members_select on public.factory_members;
create policy factory_members_select on public.factory_members
for select to authenticated
using (
  user_id = auth.uid()
  or public.is_platform_owner()
  or public.has_org_role(
    organization_id,
    array['org_admin','factory_manager']::public.app_role[]
  )
);

commit;
