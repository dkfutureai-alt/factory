-- FactoryOS Fleet / vehicle / driver / trip / fuel schema
-- Depends on 01_core.sql and 05_hr.sql.

create type public.vehicle_operational_status as enum ('available','assigned','on_trip','service_due','maintenance','inactive');
create type public.trip_status as enum ('planned','assigned','ready','in_progress','completed','blocked','cancelled');
create type public.fuel_entry_status as enum ('submitted','approved','rejected','reversed');

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  registration_number text not null,
  vehicle_code text not null,
  vehicle_type text not null,
  make text not null,
  model text not null,
  capacity_label text,
  fuel_type text not null check (fuel_type in ('diesel','petrol','cng','electric','other')),
  current_odometer_km integer not null default 0 check (current_odometer_km >= 0),
  next_service_odometer_km integer check (next_service_odometer_km is null or next_service_odometer_km >= 0),
  status public.vehicle_operational_status not null default 'available',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, registration_number),
  unique (organization_id, vehicle_code)
);

create table public.vehicle_documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  document_type text not null check (document_type in ('insurance','fitness','puc','permit','registration','other')),
  document_number text,
  valid_from date,
  valid_until date,
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_id, document_type)
);

-- Drivers remain HR employees. Fleet stores only driver-specific operational qualifications.
create table public.driver_profiles (
  employee_id uuid primary key references public.employees(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  license_number text not null,
  license_class text not null,
  license_valid_until date not null,
  medical_valid_until date,
  safety_training_valid_until date,
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, license_number)
);

create table public.vehicle_driver_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  driver_employee_id uuid not null references public.employees(id) on delete restrict,
  assigned_from timestamptz not null default now(),
  assigned_until timestamptz,
  is_primary boolean not null default true,
  created_at timestamptz not null default now(),
  check (assigned_until is null or assigned_until > assigned_from)
);

create unique index vehicle_primary_active_driver_idx
on public.vehicle_driver_assignments(vehicle_id)
where is_primary and assigned_until is null;

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  trip_number text not null,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  driver_employee_id uuid not null references public.employees(id) on delete restrict,
  sales_order_id uuid references public.sales_orders(id) on delete set null,
  origin_label text not null,
  destination_label text not null,
  planned_start_at timestamptz not null,
  actual_start_at timestamptz,
  completed_at timestamptz,
  start_odometer_km integer check (start_odometer_km is null or start_odometer_km >= 0),
  end_odometer_km integer check (end_odometer_km is null or end_odometer_km >= 0),
  status public.trip_status not null default 'planned',
  block_reason text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, trip_number),
  check (end_odometer_km is null or start_odometer_km is null or end_odometer_km >= start_odometer_km),
  check (completed_at is null or actual_start_at is null or completed_at >= actual_start_at),
  check (status <> 'blocked' or length(btrim(coalesce(block_reason,''))) > 0)
);

create table public.vehicle_inspections (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  driver_employee_id uuid references public.employees(id) on delete restrict,
  trip_id uuid references public.trips(id) on delete set null,
  inspected_at timestamptz not null default now(),
  odometer_km integer not null check (odometer_km >= 0),
  brakes_ok boolean not null,
  tyres_ok boolean not null,
  lights_ok boolean not null,
  fluids_ok boolean not null,
  documents_ok boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

create table public.fuel_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  entry_number text not null,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  driver_employee_id uuid not null references public.employees(id) on delete restrict,
  trip_id uuid references public.trips(id) on delete set null,
  fueled_at timestamptz not null default now(),
  odometer_km integer not null check (odometer_km >= 0),
  litres numeric(10,2) not null check (litres > 0),
  amount numeric(12,2) not null check (amount >= 0),
  vendor_name text,
  receipt_reference text,
  status public.fuel_entry_status not null default 'submitted',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  reversal_of_fuel_entry_id uuid references public.fuel_entries(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, entry_number),
  check (status <> 'approved' or reviewed_at is not null),
  check (status <> 'rejected' or length(btrim(coalesce(rejection_reason,''))) > 0),
  check (status <> 'reversed' or reversal_of_fuel_entry_id is not null)
);

create index vehicles_org_factory_status_idx on public.vehicles(organization_id, factory_id, status);
create index vehicle_assignments_driver_active_idx on public.vehicle_driver_assignments(organization_id, driver_employee_id, assigned_until);
create index trips_org_factory_status_idx on public.trips(organization_id, factory_id, status, planned_start_at);
create index trips_driver_status_idx on public.trips(driver_employee_id, status, planned_start_at);
create index fuel_entries_vehicle_time_idx on public.fuel_entries(vehicle_id, fueled_at desc);
create index fuel_entries_driver_time_idx on public.fuel_entries(driver_employee_id, fueled_at desc);

create trigger vehicles_set_updated_at before update on public.vehicles for each row execute function private.set_updated_at();
create trigger vehicle_documents_set_updated_at before update on public.vehicle_documents for each row execute function private.set_updated_at();
create trigger driver_profiles_set_updated_at before update on public.driver_profiles for each row execute function private.set_updated_at();
create trigger trips_set_updated_at before update on public.trips for each row execute function private.set_updated_at();
create trigger fuel_entries_set_updated_at before update on public.fuel_entries for each row execute function private.set_updated_at();

create or replace function private.current_employee_id(target_organization_id uuid)
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select e.id
  from public.employees e
  where e.organization_id = target_organization_id
    and e.profile_user_id = auth.uid()
    and e.status = 'active'
  limit 1
$$;

revoke all on function private.current_employee_id(uuid) from public;
grant execute on function private.current_employee_id(uuid) to authenticated;

create or replace function private.validate_fleet_refs()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  vehicle_org uuid;
  vehicle_factory uuid;
  employee_org uuid;
  employee_factory uuid;
  sales_org uuid;
  assignment_ok boolean;
begin
  if tg_table_name = 'vehicles' then
    if new.factory_id is not null and not exists(select 1 from public.factories f where f.id=new.factory_id and f.organization_id=new.organization_id) then
      raise exception 'vehicle factory organization mismatch';
    end if;
    return new;
  end if;

  if tg_table_name = 'vehicle_documents' then
    select organization_id into vehicle_org from public.vehicles where id=new.vehicle_id;
    if vehicle_org is null or vehicle_org <> new.organization_id then raise exception 'vehicle document organization mismatch'; end if;
    return new;
  end if;

  if tg_table_name = 'driver_profiles' then
    select organization_id into employee_org from public.employees where id=new.employee_id;
    if employee_org is null or employee_org <> new.organization_id then raise exception 'driver employee organization mismatch'; end if;
    return new;
  end if;

  if tg_table_name = 'vehicle_driver_assignments' then
    select organization_id, factory_id into vehicle_org, vehicle_factory from public.vehicles where id=new.vehicle_id;
    select organization_id, factory_id into employee_org, employee_factory from public.employees where id=new.driver_employee_id;
    if vehicle_org is null or employee_org is null or new.organization_id <> vehicle_org or new.organization_id <> employee_org then raise exception 'vehicle assignment organization mismatch'; end if;
    if new.factory_id is distinct from vehicle_factory or new.factory_id is distinct from employee_factory then raise exception 'vehicle assignment factory mismatch'; end if;
    if not exists(select 1 from public.driver_profiles dp where dp.employee_id=new.driver_employee_id and dp.status='active') then raise exception 'employee is not an active driver'; end if;
    return new;
  end if;

  if tg_table_name in ('trips','vehicle_inspections','fuel_entries') then
    select organization_id, factory_id into vehicle_org, vehicle_factory from public.vehicles where id=new.vehicle_id;
    select organization_id, factory_id into employee_org, employee_factory from public.employees where id=new.driver_employee_id;
    if vehicle_org is null or employee_org is null or new.organization_id <> vehicle_org or new.organization_id <> employee_org then raise exception 'fleet operation organization mismatch'; end if;
    if new.factory_id is distinct from vehicle_factory or new.factory_id is distinct from employee_factory then raise exception 'fleet operation factory mismatch'; end if;

    select exists(
      select 1 from public.vehicle_driver_assignments a
      where a.organization_id=new.organization_id
        and a.vehicle_id=new.vehicle_id
        and a.driver_employee_id=new.driver_employee_id
        and a.assigned_from <= coalesce(new.created_at, now())
        and (a.assigned_until is null or a.assigned_until >= coalesce(new.created_at, now()))
    ) into assignment_ok;
    if not assignment_ok then raise exception 'driver is not assigned to vehicle'; end if;

    if tg_table_name = 'trips' and new.sales_order_id is not null then
      select organization_id into sales_org from public.sales_orders where id=new.sales_order_id;
      if sales_org is null or sales_org <> new.organization_id then raise exception 'trip sales order organization mismatch'; end if;
    end if;

    if tg_table_name = 'fuel_entries' and new.trip_id is not null and not exists(
      select 1 from public.trips t where t.id=new.trip_id and t.organization_id=new.organization_id and t.vehicle_id=new.vehicle_id and t.driver_employee_id=new.driver_employee_id
    ) then raise exception 'fuel trip assignment mismatch'; end if;

    if tg_table_name = 'vehicle_inspections' and new.trip_id is not null and not exists(
      select 1 from public.trips t where t.id=new.trip_id and t.organization_id=new.organization_id and t.vehicle_id=new.vehicle_id and t.driver_employee_id=new.driver_employee_id
    ) then raise exception 'inspection trip assignment mismatch'; end if;

    return new;
  end if;
  return new;
end;
$$;

create trigger vehicles_validate_refs before insert or update on public.vehicles for each row execute function private.validate_fleet_refs();
create trigger vehicle_documents_validate_refs before insert or update on public.vehicle_documents for each row execute function private.validate_fleet_refs();
create trigger driver_profiles_validate_refs before insert or update on public.driver_profiles for each row execute function private.validate_fleet_refs();
create trigger vehicle_driver_assignments_validate_refs before insert or update on public.vehicle_driver_assignments for each row execute function private.validate_fleet_refs();
create trigger trips_validate_refs before insert or update on public.trips for each row execute function private.validate_fleet_refs();
create trigger vehicle_inspections_validate_refs before insert or update on public.vehicle_inspections for each row execute function private.validate_fleet_refs();
create trigger fuel_entries_validate_refs before insert or update on public.fuel_entries for each row execute function private.validate_fleet_refs();

create or replace function private.validate_fuel_odometer()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  latest_odometer integer;
begin
  select max(fe.odometer_km) into latest_odometer
  from public.fuel_entries fe
  where fe.vehicle_id=new.vehicle_id
    and fe.status in ('submitted','approved')
    and fe.id <> coalesce(new.id, gen_random_uuid());
  if latest_odometer is not null and new.odometer_km < latest_odometer then
    raise exception 'fuel odometer cannot move backwards';
  end if;
  return new;
end;
$$;

create trigger fuel_entries_validate_odometer before insert or update on public.fuel_entries for each row execute function private.validate_fuel_odometer();

create or replace function private.guard_fuel_finalized()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status in ('approved','reversed') then raise exception 'approved/reversed fuel entry is immutable'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create trigger fuel_entries_guard_finalized before update or delete on public.fuel_entries for each row execute function private.guard_fuel_finalized();

alter table public.vehicles enable row level security;
alter table public.vehicle_documents enable row level security;
alter table public.driver_profiles enable row level security;
alter table public.vehicle_driver_assignments enable row level security;
alter table public.trips enable row level security;
alter table public.vehicle_inspections enable row level security;
alter table public.fuel_entries enable row level security;

create policy vehicles_select on public.vehicles for select to authenticated using ((select private.has_permission(organization_id,'vehicle.read',factory_id)));
create policy vehicles_manage on public.vehicles for all to authenticated using ((select private.has_permission(organization_id,'vehicle.manage',factory_id))) with check ((select private.has_permission(organization_id,'vehicle.manage',factory_id)));
create policy vehicle_documents_select on public.vehicle_documents for select to authenticated using ((select private.has_permission(organization_id,'vehicle.read',null)));
create policy vehicle_documents_manage on public.vehicle_documents for all to authenticated using ((select private.has_permission(organization_id,'vehicle.manage',null))) with check ((select private.has_permission(organization_id,'vehicle.manage',null)));
create policy driver_profiles_select on public.driver_profiles for select to authenticated using ((select private.has_permission(organization_id,'vehicle.read',null)) or employee_id=(select private.current_employee_id(organization_id)));
create policy driver_profiles_manage on public.driver_profiles for all to authenticated using ((select private.has_permission(organization_id,'vehicle.manage',null))) with check ((select private.has_permission(organization_id,'vehicle.manage',null)));
create policy assignments_select on public.vehicle_driver_assignments for select to authenticated using ((select private.has_permission(organization_id,'vehicle.read',factory_id)) or driver_employee_id=(select private.current_employee_id(organization_id)));
create policy assignments_manage on public.vehicle_driver_assignments for all to authenticated using ((select private.has_permission(organization_id,'vehicle.manage',factory_id))) with check ((select private.has_permission(organization_id,'vehicle.manage',factory_id)));
create policy trips_select on public.trips for select to authenticated using ((select private.has_permission(organization_id,'vehicle.read',factory_id)) or (driver_employee_id=(select private.current_employee_id(organization_id)) and (select private.has_permission(organization_id,'trip.assigned_read',factory_id))));
create policy trips_manage on public.trips for all to authenticated using ((select private.has_permission(organization_id,'vehicle.manage',factory_id))) with check ((select private.has_permission(organization_id,'vehicle.manage',factory_id)));
create policy inspections_select on public.vehicle_inspections for select to authenticated using ((select private.has_permission(organization_id,'vehicle.read',factory_id)) or driver_employee_id=(select private.current_employee_id(organization_id)));
create policy inspections_manage on public.vehicle_inspections for all to authenticated using ((select private.has_permission(organization_id,'vehicle.manage',factory_id))) with check ((select private.has_permission(organization_id,'vehicle.manage',factory_id)));
create policy fuel_select on public.fuel_entries for select to authenticated using ((select private.has_permission(organization_id,'vehicle.read',factory_id)) or driver_employee_id=(select private.current_employee_id(organization_id)));
create policy fuel_manage on public.fuel_entries for all to authenticated using ((select private.has_permission(organization_id,'fuel.manage',factory_id))) with check ((select private.has_permission(organization_id,'fuel.manage',factory_id)));
create policy fuel_driver_insert on public.fuel_entries for insert to authenticated with check (driver_employee_id=(select private.current_employee_id(organization_id)) and status='submitted' and reviewed_by is null and reviewed_at is null and (select private.has_permission(organization_id,'fuel.create',factory_id)));

grant select on public.vehicles, public.vehicle_documents, public.driver_profiles, public.vehicle_driver_assignments, public.trips, public.vehicle_inspections, public.fuel_entries to authenticated;
grant insert, update, delete on public.vehicles, public.vehicle_documents, public.driver_profiles, public.vehicle_driver_assignments, public.trips, public.vehicle_inspections, public.fuel_entries to authenticated;

create or replace function public.update_assigned_trip_status(target_trip_id uuid, target_status public.trip_status, odometer_km integer default null)
returns public.trips
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  t public.trips;
  employee_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into t from public.trips where id=target_trip_id for update;
  if t.id is null then raise exception 'trip not found'; end if;
  employee_id := private.current_employee_id(t.organization_id);
  if employee_id is null or employee_id <> t.driver_employee_id then raise exception 'trip is not assigned to current driver'; end if;
  if not private.has_permission(t.organization_id,'trip.assigned_update',t.factory_id) then raise exception 'permission denied'; end if;
  if t.status in ('completed','cancelled') then raise exception 'finalized trip cannot be updated'; end if;
  if target_status not in ('ready','in_progress','completed','blocked') then raise exception 'driver cannot set requested trip status'; end if;
  if target_status='in_progress' and t.actual_start_at is null then
    update public.trips set status=target_status, actual_start_at=now(), start_odometer_km=coalesce(odometer_km,start_odometer_km), updated_by=auth.uid() where id=t.id returning * into t;
  elsif target_status='completed' then
    if t.actual_start_at is null then raise exception 'trip must be started before completion'; end if;
    if odometer_km is null then raise exception 'completion odometer required'; end if;
    update public.trips set status=target_status, completed_at=now(), end_odometer_km=odometer_km, updated_by=auth.uid() where id=t.id returning * into t;
  else
    update public.trips set status=target_status, updated_by=auth.uid() where id=t.id returning * into t;
  end if;
  return t;
end;
$$;

revoke all on function public.update_assigned_trip_status(uuid,public.trip_status,integer) from public;
grant execute on function public.update_assigned_trip_status(uuid,public.trip_status,integer) to authenticated;
