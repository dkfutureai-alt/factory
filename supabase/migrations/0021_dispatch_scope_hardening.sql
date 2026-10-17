begin;

create or replace function public.can_view_dispatch_delivery(target_delivery_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from public.dispatch_deliveries d
    where d.id=target_delivery_id
      and (
        public.can_manage_factory(d.factory_id)
        or public.can_plan_warehouse_factory(d.factory_id)
        or public.fleet_driver_is_current_user(d.driver_id)
      )
  );
$$;
grant execute on function public.can_view_dispatch_delivery(uuid) to authenticated;

drop policy if exists dispatch_deliveries_select on public.dispatch_deliveries;
drop policy if exists dispatch_lines_select on public.dispatch_delivery_lines;
drop policy if exists dispatch_returnable_pickups_select on public.dispatch_returnable_pickups;
drop policy if exists dispatch_returnable_lines_select on public.dispatch_returnable_lines;
drop policy if exists dispatch_exceptions_select on public.dispatch_delivery_exceptions;

create policy dispatch_deliveries_select on public.dispatch_deliveries
for select to authenticated
using (public.can_view_dispatch_delivery(id));

create policy dispatch_lines_select on public.dispatch_delivery_lines
for select to authenticated
using (public.can_view_dispatch_delivery(delivery_id));

create policy dispatch_returnable_pickups_select on public.dispatch_returnable_pickups
for select to authenticated
using (public.can_view_dispatch_delivery(delivery_id));

create policy dispatch_returnable_lines_select on public.dispatch_returnable_lines
for select to authenticated
using (
  exists(
    select 1
    from public.dispatch_returnable_pickups p
    where p.id=pickup_id
      and public.can_view_dispatch_delivery(p.delivery_id)
  )
);

create policy dispatch_exceptions_select on public.dispatch_delivery_exceptions
for select to authenticated
using (public.can_view_dispatch_delivery(delivery_id));

create or replace function public.dispatch_dashboard_summary(
  p_organization_id uuid,
  p_factory_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare result jsonb;
begin
  if not public.is_org_member(p_organization_id) and not public.is_platform_owner() then
    raise exception 'Organization access denied';
  end if;

  if p_factory_id is null then
    if not public.is_platform_owner()
      and not public.has_org_role(p_organization_id,array['org_admin']::public.app_role[]) then
      raise exception 'Organization-wide Dispatch dashboard requires organization admin access';
    end if;
  else
    if not exists(
      select 1 from public.factories f
      where f.id=p_factory_id and f.organization_id=p_organization_id and f.is_active
    ) then
      raise exception 'Factory not found in organization';
    end if;
    if not public.can_manage_factory(p_factory_id)
      and not public.can_plan_warehouse_factory(p_factory_id) then
      raise exception 'Dispatch dashboard requires factory planning access';
    end if;
  end if;

  select jsonb_build_object(
    'ready_to_load',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and d.status='ready_to_load' and (p_factory_id is null or d.factory_id=p_factory_id)),
    'loaded',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and d.status='loaded' and (p_factory_id is null or d.factory_id=p_factory_id)),
    'in_transit',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and d.status in ('in_transit','arrived') and (p_factory_id is null or d.factory_id=p_factory_id)),
    'delivered_today',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and d.status='delivered' and d.delivered_at::date=current_date and (p_factory_id is null or d.factory_id=p_factory_id)),
    'open_exceptions',(select count(*) from public.dispatch_delivery_exceptions e where e.organization_id=p_organization_id and e.status='open' and (p_factory_id is null or e.factory_id=p_factory_id)),
    'open_returnables',(select count(*) from public.dispatch_returnable_pickups p where p.organization_id=p_organization_id and p.status='open' and (p_factory_id is null or p.factory_id=p_factory_id))
  ) into result;
  return result;
end;
$$;
grant execute on function public.dispatch_dashboard_summary(uuid,uuid) to authenticated;

commit;
