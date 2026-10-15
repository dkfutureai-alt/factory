-- FactoryOS Fleet transactional command hardening.
-- Apply after 07_fleet.sql and 07a_fleet_review_fixes.sql.

create or replace function public.update_assigned_trip_status(target_trip_id uuid, target_status public.trip_status, odometer_km integer default null)
returns public.trips
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  t public.trips;
  employee_id uuid;
  v public.vehicles;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into t from public.trips where id=target_trip_id for update;
  if t.id is null then raise exception 'trip not found'; end if;
  select * into v from public.vehicles where id=t.vehicle_id for update;
  if v.id is null then raise exception 'vehicle not found'; end if;

  employee_id := private.current_employee_id(t.organization_id);
  if employee_id is null or employee_id <> t.driver_employee_id then raise exception 'trip is not assigned to current driver'; end if;
  if not private.has_permission(t.organization_id,'trip.assigned_update',t.factory_id) then raise exception 'permission denied'; end if;
  if t.status in ('completed','cancelled') then raise exception 'finalized trip cannot be updated'; end if;
  if target_status not in ('ready','in_progress','completed','blocked') then raise exception 'driver cannot set requested trip status'; end if;

  if odometer_km is not null and odometer_km < v.current_odometer_km then
    raise exception 'odometer cannot move backwards';
  end if;

  if target_status='in_progress' then
    if odometer_km is null then raise exception 'start odometer required'; end if;
    update public.trips
      set status='in_progress', actual_start_at=coalesce(actual_start_at,now()), start_odometer_km=coalesce(start_odometer_km,odometer_km), updated_by=auth.uid()
      where id=t.id returning * into t;
    update public.vehicles set current_odometer_km=greatest(current_odometer_km,odometer_km), status='on_trip' where id=v.id;
  elsif target_status='completed' then
    if t.actual_start_at is null then raise exception 'trip must be started before completion'; end if;
    if odometer_km is null then raise exception 'completion odometer required'; end if;
    if t.start_odometer_km is not null and odometer_km < t.start_odometer_km then raise exception 'completion odometer cannot be before trip start'; end if;
    update public.trips
      set status='completed', completed_at=now(), end_odometer_km=odometer_km, updated_by=auth.uid()
      where id=t.id returning * into t;
    update public.vehicles
      set current_odometer_km=greatest(current_odometer_km,odometer_km),
          status=case when next_service_odometer_km is not null and odometer_km >= next_service_odometer_km then 'service_due'::public.vehicle_operational_status else 'available'::public.vehicle_operational_status end
      where id=v.id;
  else
    update public.trips set status=target_status, updated_by=auth.uid() where id=t.id returning * into t;
  end if;
  return t;
end;
$$;

revoke all on function public.update_assigned_trip_status(uuid,public.trip_status,integer) from public;
grant execute on function public.update_assigned_trip_status(uuid,public.trip_status,integer) to authenticated;

create or replace function public.review_fuel_entry(target_fuel_entry_id uuid, decision public.fuel_entry_status, rejection_note text default null)
returns public.fuel_entries
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  f public.fuel_entries;
  v public.vehicles;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if decision not in ('approved','rejected') then raise exception 'decision must be approved or rejected'; end if;

  select * into f from public.fuel_entries where id=target_fuel_entry_id for update;
  if f.id is null then raise exception 'fuel entry not found'; end if;
  if f.status <> 'submitted' then raise exception 'only submitted fuel entries may be reviewed'; end if;
  if not private.has_permission(f.organization_id,'fuel.manage',f.factory_id) then raise exception 'permission denied'; end if;

  select * into v from public.vehicles where id=f.vehicle_id for update;
  if v.id is null then raise exception 'vehicle not found'; end if;

  if decision='approved' then
    if f.odometer_km < v.current_odometer_km then raise exception 'fuel odometer cannot be behind trusted vehicle odometer'; end if;
    update public.fuel_entries
      set status='approved', reviewed_by=auth.uid(), reviewed_at=now(), rejection_reason=null
      where id=f.id returning * into f;
    update public.vehicles set current_odometer_km=greatest(current_odometer_km,f.odometer_km) where id=v.id;
  else
    if length(btrim(coalesce(rejection_note,'')))=0 then raise exception 'rejection reason required'; end if;
    update public.fuel_entries
      set status='rejected', reviewed_by=auth.uid(), reviewed_at=now(), rejection_reason=rejection_note
      where id=f.id returning * into f;
  end if;
  return f;
end;
$$;

revoke all on function public.review_fuel_entry(uuid,public.fuel_entry_status,text) from public;
grant execute on function public.review_fuel_entry(uuid,public.fuel_entry_status,text) to authenticated;
