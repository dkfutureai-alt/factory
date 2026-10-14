-- FactoryOS Dispatch finalization review fix.
-- Disambiguates the local delivery identifier from delivery_lines.delivery_id.

create or replace function public.finalize_dispatch(target_dispatch_id uuid)
returns public.dispatch_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  d public.dispatch_orders;
  trip_row public.trips;
  so public.sales_orders;
  target_delivery_id uuid;
  target_delivery_number text;
  invalid_count bigint;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  select * into d from public.dispatch_orders where id=target_dispatch_id for update;
  if d.id is null then raise exception 'dispatch order not found'; end if;
  if d.status='dispatched' then return d; end if;
  if d.status<>'loaded' then raise exception 'dispatch stock must be loaded before finalization'; end if;
  if not (private.has_factory_permission(d.organization_id,'dispatch.manage',d.factory_id)
          or private.has_warehouse_permission(d.organization_id,'dispatch.manage',d.warehouse_id)) then
    raise exception 'dispatch permission denied';
  end if;
  if d.trip_id is null then raise exception 'dispatch requires a trip'; end if;

  select * into trip_row from public.trips where id=d.trip_id for update;
  if trip_row.id is null or trip_row.organization_id<>d.organization_id or trip_row.factory_id is distinct from d.factory_id then raise exception 'dispatch trip scope mismatch'; end if;
  if trip_row.sales_order_id is distinct from d.sales_order_id then raise exception 'dispatch trip must reference the same sales order'; end if;
  if trip_row.status not in ('planned','assigned','ready') then raise exception 'dispatch trip is not ready'; end if;

  if exists(select 1 from public.dispatch_checks where dispatch_order_id=d.id and is_required and not is_complete) then raise exception 'required dispatch checks are incomplete'; end if;
  if not exists(select 1 from public.dispatch_lines where dispatch_order_id=d.id) then raise exception 'dispatch has no lines'; end if;
  if exists(select 1 from public.dispatch_lines where dispatch_order_id=d.id and loaded_quantity<>planned_quantity) then raise exception 'dispatch line quantities are not fully loaded'; end if;

  select count(*) into invalid_count
  from public.dispatch_lines dl
  left join public.stock_transaction_lines stl on stl.id=dl.stock_transaction_line_id
  left join public.stock_transactions st on st.id=stl.stock_transaction_id
  where dl.dispatch_order_id=d.id and (
    stl.id is null or st.status<>'posted' or st.transaction_type<>'sales_dispatch'
    or st.reference_type<>'dispatch_order' or st.reference_id<>d.id
    or stl.organization_id<>d.organization_id or stl.warehouse_id<>d.warehouse_id
    or stl.item_id<>dl.item_id or stl.batch_id is distinct from dl.batch_id
    or stl.serial_number_id is distinct from dl.serial_number_id
    or stl.location_id is distinct from dl.source_location_id
    or stl.quantity_delta<>-dl.loaded_quantity
  );
  if invalid_count>0 then raise exception 'dispatch ledger reconciliation failed'; end if;

  select * into so from public.sales_orders where id=d.sales_order_id;
  target_delivery_number:=regexp_replace(d.dispatch_number,'^DSP-','DEL-');
  select dv.id into target_delivery_id
  from public.deliveries dv
  where dv.organization_id=d.organization_id and dv.trip_id=d.trip_id and dv.sales_order_id=d.sales_order_id;

  if target_delivery_id is null then
    insert into public.deliveries(
      organization_id,factory_id,delivery_number,sales_order_id,trip_id,customer_id,ship_to_address_id,
      driver_employee_id,vehicle_id,planned_delivery_at,status,created_by,updated_by
    )
    values(
      d.organization_id,d.factory_id,target_delivery_number,d.sales_order_id,d.trip_id,so.customer_id,so.ship_to_address_id,
      trip_row.driver_employee_id,trip_row.vehicle_id,
      case when so.requested_delivery_date is null then null else so.requested_delivery_date::timestamptz+interval '10 hours' end,
      'loaded',(select auth.uid()),(select auth.uid())
    )
    returning id into target_delivery_id;
  elsif exists(select 1 from public.deliveries dv where dv.id=target_delivery_id and dv.status not in ('planned','loaded')) then
    raise exception 'existing delivery has already progressed beyond loading';
  end if;

  insert into public.delivery_lines(organization_id,delivery_id,sales_order_line_id,item_id,planned_quantity)
  select dl.organization_id,target_delivery_id,dl.sales_order_line_id,dl.item_id,dl.loaded_quantity
  from public.dispatch_lines dl
  where dl.dispatch_order_id=d.id
  on conflict (delivery_id,sales_order_line_id) do update set planned_quantity=excluded.planned_quantity;

  if not exists(
    select 1 from public.delivery_events de
    where de.delivery_id=target_delivery_id and de.event_type='loaded'
  ) then
    insert into public.delivery_events(organization_id,delivery_id,event_type,actor_user_id,note)
    values(d.organization_id,target_delivery_id,'loaded',(select auth.uid()),'Created from finalized dispatch');
  end if;

  update public.dispatch_orders
  set status='dispatched',dispatched_at=now(),updated_by=(select auth.uid())
  where id=d.id
  returning * into d;

  insert into public.dispatch_events(organization_id,dispatch_order_id,event_type,actor_user_id,note)
  values(d.organization_id,d.id,'dispatched',(select auth.uid()),'Dispatch finalized and handed to Delivery');

  if not exists(
    select 1 from public.sales_order_lines sol
    where sol.sales_order_id=d.sales_order_id
      and coalesce((
        select sum(dl.planned_quantity)
        from public.dispatch_lines dl
        join public.dispatch_orders dx on dx.id=dl.dispatch_order_id
        where dl.sales_order_line_id=sol.id and dx.status='dispatched'
      ),0) < sol.ordered_quantity
  ) then
    update public.sales_orders
    set status='dispatched'
    where id=d.sales_order_id and status not in ('delivered','closed','cancelled');
  end if;

  update public.trips
  set status='ready',updated_by=(select auth.uid())
  where id=d.trip_id and status in ('planned','assigned');

  return d;
end;
$$;

revoke all on function public.finalize_dispatch(uuid) from public;
grant execute on function public.finalize_dispatch(uuid) to authenticated;
