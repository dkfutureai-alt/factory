begin;

-- Keep vehicle odometer monotonic even when managers edit vehicle master fields directly.
create or replace function public.prevent_fleet_odometer_regression()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.current_odometer_km < old.current_odometer_km then
    raise exception 'Vehicle odometer cannot move backward from % to %',old.current_odometer_km,new.current_odometer_km;
  end if;
  return new;
end; $$;
revoke all on function public.prevent_fleet_odometer_regression() from public;
create trigger fleet_vehicle_odometer_monotonic
before update of current_odometer_km on public.fleet_vehicles
for each row execute function public.prevent_fleet_odometer_regression();

-- One warehouse handoff can have only one non-cancelled fleet trip. A cancelled trip may be replanned.
create unique index fleet_trips_handoff_active_unique
  on public.fleet_trips(warehouse_handoff_id)
  where warehouse_handoff_id is not null and status<>'cancelled';

create or replace function public.fleet_create_trip(
  p_factory_id uuid,
  p_vehicle_id uuid,
  p_driver_id uuid,
  p_origin text,
  p_destination text,
  p_planned_start_at timestamptz,
  p_planned_end_at timestamptz default null,
  p_sales_order_id uuid default null,
  p_warehouse_handoff_id uuid default null,
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare
  v_org uuid;
  v_id uuid;
  v_handoff public.warehouse_dispatch_handoffs%rowtype;
  v_sales_order_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Fleet management access required'; end if;

  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;

  if not exists(
    select 1 from public.fleet_vehicles
    where id=p_vehicle_id and factory_id=p_factory_id and status='active'
  ) then raise exception 'Active vehicle not found'; end if;

  if not exists(
    select 1 from public.fleet_drivers
    where id=p_driver_id
      and factory_id=p_factory_id
      and status='active'
      and license_expiry>=current_date
  ) then raise exception 'Active licensed driver not found'; end if;

  if not exists(
    select 1 from public.fleet_vehicle_driver_assignments
    where vehicle_id=p_vehicle_id
      and driver_id=p_driver_id
      and ended_at is null
      and effective_from<=now()
  ) then raise exception 'Vehicle and driver are not actively assigned'; end if;

  if p_planned_start_at is null then raise exception 'Planned start is required'; end if;
  if p_planned_end_at is not null and p_planned_end_at<p_planned_start_at then
    raise exception 'Planned end cannot be before planned start';
  end if;
  if char_length(trim(coalesce(p_origin,'')))<2 or char_length(trim(coalesce(p_destination,'')))<2 then
    raise exception 'Origin and destination are required';
  end if;

  v_sales_order_id:=p_sales_order_id;

  if p_warehouse_handoff_id is not null then
    select * into v_handoff
    from public.warehouse_dispatch_handoffs
    where id=p_warehouse_handoff_id
    for update;

    if v_handoff.id is null
       or v_handoff.factory_id<>p_factory_id
       or v_handoff.status<>'handed_off' then
      raise exception 'Completed warehouse handoff not found in this factory';
    end if;

    if v_sales_order_id is null then
      v_sales_order_id:=v_handoff.sales_order_id;
    elsif v_sales_order_id<>v_handoff.sales_order_id then
      raise exception 'Sales order does not match warehouse handoff';
    end if;

    if exists(
      select 1 from public.fleet_trips
      where warehouse_handoff_id=p_warehouse_handoff_id
        and status<>'cancelled'
    ) then
      raise exception 'Warehouse handoff already has an active/completed trip';
    end if;
  end if;

  if v_sales_order_id is not null and not exists(
    select 1 from public.sales_orders
    where id=v_sales_order_id and factory_id=p_factory_id
  ) then raise exception 'Sales order not found in this factory'; end if;

  insert into public.fleet_trips(
    organization_id,factory_id,vehicle_id,driver_id,sales_order_id,warehouse_handoff_id,
    origin,destination,status,planned_start_at,planned_end_at,notes,created_by
  ) values(
    v_org,p_factory_id,p_vehicle_id,p_driver_id,v_sales_order_id,p_warehouse_handoff_id,
    trim(p_origin),trim(p_destination),'assigned',p_planned_start_at,p_planned_end_at,
    nullif(trim(coalesce(p_notes,'')),''),auth.uid()
  ) returning id into v_id;

  return v_id;
end; $$;
grant execute on function public.fleet_create_trip(uuid,uuid,uuid,text,text,timestamptz,timestamptz,uuid,uuid,text) to authenticated;

create or replace function public.fleet_start_trip(p_trip_id uuid,p_odometer_km numeric,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare
  v_trip public.fleet_trips%rowtype;
  v_vehicle public.fleet_vehicles%rowtype;
begin
  select * into v_trip from public.fleet_trips where id=p_trip_id for update;
  if v_trip.id is null then raise exception 'Trip not found'; end if;
  if not public.fleet_can_operate_trip(p_trip_id) then raise exception 'Trip operation not allowed'; end if;
  if v_trip.status not in ('planned','assigned') then raise exception 'Trip cannot start from status %',v_trip.status; end if;

  if not exists(
    select 1 from public.fleet_drivers
    where id=v_trip.driver_id
      and factory_id=v_trip.factory_id
      and status='active'
      and license_expiry>=current_date
  ) then raise exception 'Driver licence is expired or driver is inactive'; end if;

  if not exists(
    select 1 from public.fleet_vehicle_driver_assignments
    where vehicle_id=v_trip.vehicle_id
      and driver_id=v_trip.driver_id
      and ended_at is null
      and effective_from<=now()
  ) then raise exception 'Vehicle/driver assignment is no longer active'; end if;

  select * into v_vehicle from public.fleet_vehicles where id=v_trip.vehicle_id for update;
  if v_vehicle.status<>'active' then raise exception 'Vehicle is not active'; end if;
  if p_odometer_km is null or p_odometer_km<v_vehicle.current_odometer_km then
    raise exception 'Start odometer cannot be below current vehicle odometer %',v_vehicle.current_odometer_km;
  end if;

  update public.fleet_trips
  set status='started',started_at=now(),start_odometer_km=p_odometer_km,started_by=auth.uid(),
      notes=coalesce(nullif(trim(coalesce(p_notes,'')),''),notes)
  where id=p_trip_id;

  update public.fleet_vehicles set current_odometer_km=p_odometer_km where id=v_vehicle.id;

  insert into public.fleet_odometer_logs(
    organization_id,factory_id,vehicle_id,trip_id,reading_km,source,notes,created_by
  ) values(
    v_trip.organization_id,v_trip.factory_id,v_trip.vehicle_id,v_trip.id,p_odometer_km,
    'trip_start',nullif(trim(coalesce(p_notes,'')),''),auth.uid()
  );
end; $$;
grant execute on function public.fleet_start_trip(uuid,numeric,text) to authenticated;

commit;
