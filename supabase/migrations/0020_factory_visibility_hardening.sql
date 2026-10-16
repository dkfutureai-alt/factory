begin;

-- Organization membership alone must not reveal every factory to roles that are
-- explicitly factory-scoped. Organization admins keep organization-wide setup
-- visibility; all other authenticated roles see only active factory assignments.
drop policy if exists factories_select on public.factories;

create policy factories_select on public.factories
for select to authenticated
using (
  public.has_org_role(
    organization_id,
    array['org_admin']::public.app_role[]
  )
  or exists (
    select 1
    from public.factory_members fm
    where fm.organization_id = factories.organization_id
      and fm.factory_id = factories.id
      and fm.user_id = auth.uid()
      and fm.is_active
  )
);

commit;
