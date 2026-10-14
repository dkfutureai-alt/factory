-- FactoryOS Fleet review fixes.
-- Apply after 07_fleet.sql and before 06_demo_fleet.sql.

alter table public.driver_profiles
add column if not exists driver_code text;

create unique index if not exists driver_profiles_org_driver_code_unique
on public.driver_profiles(organization_id, driver_code)
where driver_code is not null;

alter table public.vehicle_inspections
alter column driver_employee_id set not null;

create or replace function private.validate_fuel_reversal()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  original_org uuid;
  original_vehicle uuid;
  original_status public.fuel_entry_status;
begin
  if new.reversal_of_fuel_entry_id is null then return new; end if;
  if new.reversal_of_fuel_entry_id = new.id then raise exception 'fuel entry cannot reverse itself'; end if;
  select organization_id, vehicle_id, status into original_org, original_vehicle, original_status
  from public.fuel_entries where id=new.reversal_of_fuel_entry_id;
  if original_org is null then raise exception 'reversed fuel entry not found'; end if;
  if original_org <> new.organization_id or original_vehicle <> new.vehicle_id then raise exception 'fuel reversal must reference same tenant and vehicle'; end if;
  if original_status <> 'approved' then raise exception 'only approved fuel entries may be reversed'; end if;
  return new;
end;
$$;

create trigger fuel_entries_validate_reversal
before insert or update on public.fuel_entries
for each row execute function private.validate_fuel_reversal();

-- Approved/reversed entries remain immutable, but a truly no-op idempotent upsert is permitted.
create or replace function private.guard_fuel_finalized()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status in ('approved','reversed') then
    if tg_op='UPDATE'
       and new.organization_id is not distinct from old.organization_id
       and new.factory_id is not distinct from old.factory_id
       and new.entry_number is not distinct from old.entry_number
       and new.vehicle_id is not distinct from old.vehicle_id
       and new.driver_employee_id is not distinct from old.driver_employee_id
       and new.trip_id is not distinct from old.trip_id
       and new.fueled_at is not distinct from old.fueled_at
       and new.odometer_km is not distinct from old.odometer_km
       and new.litres is not distinct from old.litres
       and new.amount is not distinct from old.amount
       and new.vendor_name is not distinct from old.vendor_name
       and new.receipt_reference is not distinct from old.receipt_reference
       and new.status is not distinct from old.status
       and new.reviewed_by is not distinct from old.reviewed_by
       and new.reviewed_at is not distinct from old.reviewed_at
       and new.rejection_reason is not distinct from old.rejection_reason
       and new.reversal_of_fuel_entry_id is not distinct from old.reversal_of_fuel_entry_id
    then
      return new;
    end if;
    raise exception 'approved/reversed fuel entry is immutable';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

-- Drivers may read only their currently assigned vehicle and its compliance documents.
drop policy if exists vehicles_select on public.vehicles;
create policy vehicles_select on public.vehicles for select to authenticated
using (
  (select private.has_permission(organization_id,'vehicle.read',factory_id))
  or exists (
    select 1 from public.vehicle_driver_assignments a
    where a.vehicle_id=vehicles.id
      and a.organization_id=vehicles.organization_id
      and a.driver_employee_id=(select private.current_employee_id(vehicles.organization_id))
      and a.assigned_until is null
  )
);

drop policy if exists vehicle_documents_select on public.vehicle_documents;
create policy vehicle_documents_select on public.vehicle_documents for select to authenticated
using (
  (select private.has_permission(organization_id,'vehicle.read',null))
  or exists (
    select 1 from public.vehicle_driver_assignments a
    where a.vehicle_id=vehicle_documents.vehicle_id
      and a.organization_id=vehicle_documents.organization_id
      and a.driver_employee_id=(select private.current_employee_id(vehicle_documents.organization_id))
      and a.assigned_until is null
  )
);

-- Drivers can submit inspections for their own assigned vehicle using their assigned-trip permission.
create policy inspections_driver_insert on public.vehicle_inspections for insert to authenticated
with check (
  driver_employee_id=(select private.current_employee_id(organization_id))
  and (select private.has_permission(organization_id,'trip.assigned_update',factory_id))
  and exists (
    select 1 from public.vehicle_driver_assignments a
    where a.organization_id=vehicle_inspections.organization_id
      and a.vehicle_id=vehicle_inspections.vehicle_id
      and a.driver_employee_id=vehicle_inspections.driver_employee_id
      and a.assigned_until is null
  )
);

-- Direct driver fuel inserts may only create a fresh submitted record; review state stays manager controlled.
drop policy if exists fuel_driver_insert on public.fuel_entries;
create policy fuel_driver_insert on public.fuel_entries for insert to authenticated
with check (
  driver_employee_id=(select private.current_employee_id(organization_id))
  and status='submitted'
  and reviewed_by is null
  and reviewed_at is null
  and rejection_reason is null
  and reversal_of_fuel_entry_id is null
  and (select private.has_permission(organization_id,'fuel.create',factory_id))
);
