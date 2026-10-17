begin;

-- Factory Managers may inspect organization-default rules that apply to their
-- assigned factories, but never factory-specific rules outside their scope.
drop policy if exists notification_rules_select on public.notification_rules;
create policy notification_rules_select on public.notification_rules
for select to authenticated
using(
  public.has_org_role(organization_id,array['org_admin']::public.app_role[])
  or (
    factory_id is null
    and public.has_org_role(organization_id,array['factory_manager']::public.app_role[])
  )
  or (
    factory_id is not null
    and public.can_manage_factory(factory_id)
  )
);

commit;
