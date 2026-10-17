begin;

-- A completed/cancelled returnable pickup is immutable. The driver may add
-- multiple lines while the pickup is open, but no inventory receipt can be
-- posted after the pickup has been closed.
create or replace function public.dispatch_record_returnable(
  p_delivery_id uuid,
  p_item_id uuid,
  p_quantity numeric,
  p_condition text default 'good',
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_d public.dispatch_deliveries%rowtype;
  v_pickup public.dispatch_returnable_pickups%rowtype;
  v_tx uuid;
  v_line uuid;
begin
  select * into v_d
  from public.dispatch_deliveries
  where id=p_delivery_id
  for update;

  if v_d.id is null then raise exception 'Delivery not found'; end if;
  if not public.can_manage_factory(v_d.factory_id)
     and not public.dispatch_driver_can_access_delivery(v_d.id) then
    raise exception 'Delivery access denied';
  end if;
  if v_d.status not in ('arrived','delivered') then
    raise exception 'Returnables can be recorded only at customer';
  end if;
  if p_quantity is null or p_quantity<=0 then
    raise exception 'Quantity must be greater than zero';
  end if;
  if p_condition not in ('good','damaged','rejected') then
    raise exception 'Invalid returnable condition';
  end if;
  if not exists(
    select 1
    from public.inventory_items
    where id=p_item_id
      and organization_id=v_d.organization_id
      and is_active
      and (is_returnable or item_type='cylinder')
  ) then
    raise exception 'Item is not configured as returnable';
  end if;

  select * into v_pickup
  from public.dispatch_returnable_pickups
  where delivery_id=v_d.id
  for update;

  if v_pickup.id is null then
    insert into public.dispatch_returnable_pickups(
      organization_id,factory_id,delivery_id,created_by
    ) values(
      v_d.organization_id,v_d.factory_id,v_d.id,auth.uid()
    )
    returning * into v_pickup;
  elsif v_pickup.status<>'open' then
    raise exception 'Returnable pickup is closed';
  end if;

  v_tx:=public.dispatch_post_receive(
    v_d.factory_id,
    p_item_id,
    v_d.vehicle_location_id,
    p_quantity,
    v_d.delivery_no,
    'Customer returnable pickup'
  );

  insert into public.dispatch_returnable_lines(
    organization_id,pickup_id,item_id,quantity,condition,
    vehicle_receive_transaction_id,notes
  ) values(
    v_d.organization_id,v_pickup.id,p_item_id,p_quantity,p_condition,
    v_tx,nullif(trim(coalesce(p_notes,'')),'')
  )
  returning id into v_line;

  return v_line;
end;
$$;

grant execute on function public.dispatch_record_returnable(uuid,uuid,numeric,text,text) to authenticated;

commit;
