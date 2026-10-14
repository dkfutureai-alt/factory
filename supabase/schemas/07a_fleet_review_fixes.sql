-- FactoryOS Fleet review fixes.
-- Apply after 07_fleet.sql and before 06_demo_fleet.sql.

alter table public.driver_profiles
add column if not exists driver_code text;

create unique index if not exists driver_profiles_org_driver_code_unique
on public.driver_profiles(organization_id, driver_code)
where driver_code is not null;

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

-- Direct driver inserts may only create a fresh submitted record; review state stays manager controlled.
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
