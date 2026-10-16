begin;

-- Phase 9 hardening: organization-wide reports are admin-only and factory-scoped
-- reports must prove the factory belongs to the requested organization.

create or replace function public.fleet_assert_report_scope(
  p_organization_id uuid,
  p_factory_id uuid default null
) returns void
language plpgsql stable security definer set search_path=public as $$
begin
  if p_factory_id is null then
    if not (
      public.is_platform_owner()
      or public.has_org_role(p_organization_id,array['org_admin']::public.app_role[])
    ) then
      raise exception 'Organization-wide fleet reports require organization admin access';
    end if;
    return;
  end if;

  if not exists(
    select 1 from public.factories
    where id=p_factory_id
      and organization_id=p_organization_id
      and is_active
  ) then
    raise exception 'Factory does not belong to this organization';
  end if;

  if not public.can_view_fleet_factory(p_factory_id) then
    raise exception 'Factory access required';
  end if;
end; $$;
grant execute on function public.fleet_assert_report_scope(uuid,uuid) to authenticated;

create or replace function public.fleet_record_fuel(
  p_vehicle_id uuid,
  p_driver_id uuid,
  p_trip_id uuid,
  p_quantity_liters numeric,
  p_price_per_liter numeric,
  p_odometer_km numeric,
  p_filled_at timestamptz default now(),
  p_vendor text default null,
  p_receipt_reference text default null,
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare
  v_vehicle public.fleet_vehicles%rowtype;
  v_trip public.fleet_trips%rowtype;
  v_id uuid;
  v_is_manager boolean:=false;
begin
  select * into v_vehicle from public.fleet_vehicles where id=p_vehicle_id for update;
  if v_vehicle.id is null then raise exception 'Vehicle not found'; end if;

  v_is_manager:=public.can_manage_factory(v_vehicle.factory_id);

  if not v_is_manager then
    if p_driver_id is null or not public.fleet_driver_is_current_user(p_driver_id) then
      raise exception 'Fuel entry not allowed';
    end if;
    if not exists(
      select 1 from public.fleet_vehicle_driver_assignments a
      where a.factory_id=v_vehicle.factory_id
        and a.vehicle_id=p_vehicle_id
        and a.driver_id=p_driver_id
        and a.ended_at is null
        and a.effective_from<=now()
    ) then
      raise exception 'Driver is not actively assigned to this vehicle';
    end if;
  end if;

  if p_driver_id is not null and not exists(
    select 1 from public.fleet_drivers
    where id=p_driver_id
      and factory_id=v_vehicle.factory_id
      and status='active'
  ) then
    raise exception 'Driver not found in this factory';
  end if;

  if p_trip_id is not null then
    select * into v_trip from public.fleet_trips where id=p_trip_id;
    if v_trip.id is null or v_trip.factory_id<>v_vehicle.factory_id or v_trip.vehicle_id<>p_vehicle_id then
      raise exception 'Trip does not belong to this vehicle/factory';
    end if;
    if p_driver_id is not null and v_trip.driver_id<>p_driver_id then
      raise exception 'Fuel driver does not match trip driver';
    end if;
    if not v_is_manager and v_trip.driver_id<>p_driver_id then
      raise exception 'Driver can record fuel only for their assigned trip';
    end if;
  end if;

  if v_vehicle.fuel_type='electric' then raise exception 'Electric vehicle does not accept liquid fuel entries'; end if;
  if p_quantity_liters is null or p_quantity_liters<=0 then raise exception 'Fuel quantity must be greater than zero'; end if;
  if p_price_per_liter is null or p_price_per_liter<0 then raise exception 'Fuel price cannot be negative'; end if;
  if p_odometer_km is null or p_odometer_km<v_vehicle.current_odometer_km then
    raise exception 'Fuel odometer cannot be below current vehicle odometer %',v_vehicle.current_odometer_km;
  end if;

  insert into public.fleet_fuel_entries(
    organization_id,factory_id,vehicle_id,driver_id,trip_id,fuel_type,quantity_liters,price_per_liter,
    odometer_km,filled_at,vendor,receipt_reference,notes,created_by
  ) values(
    v_vehicle.organization_id,v_vehicle.factory_id,p_vehicle_id,p_driver_id,p_trip_id,v_vehicle.fuel_type,
    p_quantity_liters,p_price_per_liter,p_odometer_km,coalesce(p_filled_at,now()),
    nullif(trim(coalesce(p_vendor,'')),''),nullif(trim(coalesce(p_receipt_reference,'')),''),
    nullif(trim(coalesce(p_notes,'')),''),auth.uid()
  ) returning id into v_id;

  update public.fleet_vehicles set current_odometer_km=p_odometer_km where id=p_vehicle_id;

  insert into public.fleet_odometer_logs(
    organization_id,factory_id,vehicle_id,trip_id,reading_km,source,notes,created_by
  ) values(
    v_vehicle.organization_id,v_vehicle.factory_id,p_vehicle_id,p_trip_id,p_odometer_km,'fuel','Fuel entry',auth.uid()
  );

  return v_id;
end; $$;
grant execute on function public.fleet_record_fuel(uuid,uuid,uuid,numeric,numeric,numeric,timestamptz,text,text,text) to authenticated;

create or replace function public.fleet_dashboard_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_result jsonb;
begin
  perform public.fleet_assert_report_scope(p_organization_id,p_factory_id);
  select jsonb_build_object(
    'active_vehicles',count(*) filter(where v.status='active'),
    'maintenance_vehicles',count(*) filter(where v.status='maintenance'),
    'active_drivers',(select count(*) from public.fleet_drivers d where d.organization_id=p_organization_id and (p_factory_id is null or d.factory_id=p_factory_id) and d.status='active'),
    'open_trips',(select count(*) from public.fleet_trips t where t.organization_id=p_organization_id and (p_factory_id is null or t.factory_id=p_factory_id) and t.status in ('planned','assigned','started','arrived')),
    'fuel_cost_30d',(select coalesce(sum(f.total_amount),0) from public.fleet_fuel_entries f where f.organization_id=p_organization_id and (p_factory_id is null or f.factory_id=p_factory_id) and f.filled_at>=now()-interval '30 days'),
    'overdue_service',(select count(*) from public.fleet_service_reminders r join public.fleet_vehicles rv on rv.id=r.vehicle_id where r.organization_id=p_organization_id and (p_factory_id is null or r.factory_id=p_factory_id) and r.status='open' and ((r.due_date is not null and r.due_date<current_date) or (r.due_odometer_km is not null and r.due_odometer_km<=rv.current_odometer_km))),
    'expiring_documents_30d',count(*) filter(where v.status='active' and ((v.insurance_expiry between current_date and current_date+30) or (v.fitness_expiry between current_date and current_date+30) or (v.permit_expiry between current_date and current_date+30) or (v.puc_expiry between current_date and current_date+30)))
  ) into v_result
  from public.fleet_vehicles v
  where v.organization_id=p_organization_id and (p_factory_id is null or v.factory_id=p_factory_id);
  return coalesce(v_result,'{}'::jsonb);
end; $$;
grant execute on function public.fleet_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.fleet_trip_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 100)
returns table(
  trip_id uuid,trip_no text,factory_id uuid,vehicle_code text,registration_no text,driver_name text,status text,
  origin text,destination text,planned_start_at timestamptz,started_at timestamptz,completed_at timestamptz,distance_km numeric
) language plpgsql stable security definer set search_path=public as $$
begin
  perform public.fleet_assert_report_scope(p_organization_id,p_factory_id);
  return query
  select t.id,t.trip_no,t.factory_id,v.vehicle_code,v.registration_no,e.full_name,t.status,t.origin,t.destination,t.planned_start_at,t.started_at,t.completed_at,
         case when t.start_odometer_km is not null and t.end_odometer_km is not null then t.end_odometer_km-t.start_odometer_km else null end
  from public.fleet_trips t
  join public.fleet_vehicles v on v.id=t.vehicle_id
  join public.fleet_drivers d on d.id=t.driver_id
  join public.employees e on e.id=d.employee_id
  where t.organization_id=p_organization_id and (p_factory_id is null or t.factory_id=p_factory_id)
  order by t.planned_start_at desc
  limit greatest(1,least(coalesce(p_limit,100),500));
end; $$;
grant execute on function public.fleet_trip_report(uuid,uuid,integer) to authenticated;

create or replace function public.fleet_fuel_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 100)
returns table(
  fuel_entry_id uuid,factory_id uuid,vehicle_code text,registration_no text,driver_name text,trip_no text,filled_at timestamptz,
  quantity_liters numeric,price_per_liter numeric,total_amount numeric,odometer_km numeric,vendor text
) language plpgsql stable security definer set search_path=public as $$
begin
  perform public.fleet_assert_report_scope(p_organization_id,p_factory_id);
  return query
  select f.id,f.factory_id,v.vehicle_code,v.registration_no,e.full_name,t.trip_no,f.filled_at,f.quantity_liters,f.price_per_liter,f.total_amount,f.odometer_km,f.vendor
  from public.fleet_fuel_entries f
  join public.fleet_vehicles v on v.id=f.vehicle_id
  left join public.fleet_drivers d on d.id=f.driver_id
  left join public.employees e on e.id=d.employee_id
  left join public.fleet_trips t on t.id=f.trip_id
  where f.organization_id=p_organization_id and (p_factory_id is null or f.factory_id=p_factory_id)
  order by f.filled_at desc
  limit greatest(1,least(coalesce(p_limit,100),500));
end; $$;
grant execute on function public.fleet_fuel_report(uuid,uuid,integer) to authenticated;

create or replace function public.fleet_service_due_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 100)
returns table(
  reminder_id uuid,factory_id uuid,vehicle_code text,registration_no text,reminder_type text,title text,due_date date,due_odometer_km numeric,
  current_odometer_km numeric,due_state text
) language plpgsql stable security definer set search_path=public as $$
begin
  perform public.fleet_assert_report_scope(p_organization_id,p_factory_id);
  return query
  select r.id,r.factory_id,v.vehicle_code,v.registration_no,r.reminder_type,r.title,r.due_date,r.due_odometer_km,v.current_odometer_km,
    case
      when (r.due_date is not null and r.due_date<current_date) or (r.due_odometer_km is not null and r.due_odometer_km<=v.current_odometer_km) then 'overdue'
      when (r.due_date is not null and r.due_date<=current_date+30) or (r.due_odometer_km is not null and r.due_odometer_km<=v.current_odometer_km+1000) then 'due_soon'
      else 'upcoming'
    end
  from public.fleet_service_reminders r
  join public.fleet_vehicles v on v.id=r.vehicle_id
  where r.organization_id=p_organization_id and r.status='open' and (p_factory_id is null or r.factory_id=p_factory_id)
  order by case when r.due_date is null then 1 else 0 end,r.due_date,r.due_odometer_km
  limit greatest(1,least(coalesce(p_limit,100),500));
end; $$;
grant execute on function public.fleet_service_due_report(uuid,uuid,integer) to authenticated;

commit;
