begin;

-- Phase 9: Vehicles, Drivers, Trips & Fuel.
-- Fleet uses the existing factory membership model and creates one Inventory vehicle location
-- per vehicle so Phase 10 Dispatch can move stock onto a vehicle without introducing a second stock truth.

create table public.fleet_vehicles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  stock_location_id uuid not null unique,
  vehicle_code text not null check (vehicle_code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  registration_no text not null check (char_length(trim(registration_no)) between 3 and 40),
  vehicle_type text not null default 'truck' check (vehicle_type in ('truck','tanker','van','pickup','forklift','other')),
  make text,
  model text,
  model_year integer check (model_year is null or model_year between 1980 and 2100),
  fuel_type text not null default 'diesel' check (fuel_type in ('diesel','petrol','cng','electric','other')),
  capacity_quantity numeric(18,4) check (capacity_quantity is null or capacity_quantity >= 0),
  capacity_unit text,
  current_odometer_km numeric(18,2) not null default 0 check (current_odometer_km >= 0),
  insurance_expiry date,
  fitness_expiry date,
  permit_expiry date,
  puc_expiry date,
  status text not null default 'active' check (status in ('active','maintenance','out_of_service','inactive')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, vehicle_code),
  unique (organization_id, registration_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (stock_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict
);
create index fleet_vehicles_factory_status_idx on public.fleet_vehicles(factory_id,status,vehicle_code);

create table public.fleet_drivers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  employee_id uuid not null,
  license_no text not null check (char_length(trim(license_no)) between 3 and 60),
  license_type text not null check (char_length(trim(license_type)) between 1 and 40),
  license_expiry date not null,
  emergency_phone text,
  status text not null default 'active' check (status in ('active','suspended','inactive')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, employee_id),
  unique (organization_id, license_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (employee_id, organization_id) references public.employees(id, organization_id) on delete restrict
);
create index fleet_drivers_factory_status_idx on public.fleet_drivers(factory_id,status,license_expiry);

create table public.fleet_vehicle_driver_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  vehicle_id uuid not null,
  driver_id uuid not null,
  effective_from timestamptz not null default now(),
  ended_at timestamptz,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (vehicle_id, factory_id) references public.fleet_vehicles(id, factory_id) on delete restrict,
  foreign key (driver_id, factory_id) references public.fleet_drivers(id, factory_id) on delete restrict,
  check (ended_at is null or ended_at >= effective_from)
);
create unique index fleet_assignment_active_vehicle_unique on public.fleet_vehicle_driver_assignments(vehicle_id) where ended_at is null;
create unique index fleet_assignment_active_driver_unique on public.fleet_vehicle_driver_assignments(driver_id) where ended_at is null;
create index fleet_assignment_factory_date_idx on public.fleet_vehicle_driver_assignments(factory_id,effective_from desc);

create table public.fleet_trips (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  trip_no text not null default ('TRIP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  vehicle_id uuid not null,
  driver_id uuid not null,
  sales_order_id uuid references public.sales_orders(id) on delete restrict,
  warehouse_handoff_id uuid references public.warehouse_dispatch_handoffs(id) on delete restrict,
  origin text not null check (char_length(trim(origin)) between 2 and 180),
  destination text not null check (char_length(trim(destination)) between 2 and 180),
  status text not null default 'assigned' check (status in ('planned','assigned','started','arrived','completed','cancelled')),
  planned_start_at timestamptz not null,
  planned_end_at timestamptz,
  started_at timestamptz,
  arrived_at timestamptz,
  completed_at timestamptz,
  start_odometer_km numeric(18,2),
  arrival_odometer_km numeric(18,2),
  end_odometer_km numeric(18,2),
  cancellation_reason text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  started_by uuid references auth.users(id) on delete set null,
  completed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,trip_no),
  unique (id,organization_id),
  unique (id,factory_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (vehicle_id,factory_id) references public.fleet_vehicles(id,factory_id) on delete restrict,
  foreign key (driver_id,factory_id) references public.fleet_drivers(id,factory_id) on delete restrict,
  check (planned_end_at is null or planned_end_at >= planned_start_at),
  check (start_odometer_km is null or start_odometer_km >= 0),
  check (arrival_odometer_km is null or arrival_odometer_km >= coalesce(start_odometer_km,0)),
  check (end_odometer_km is null or end_odometer_km >= coalesce(arrival_odometer_km,start_odometer_km,0)),
  check ((status='completed' and completed_at is not null and end_odometer_km is not null) or status<>'completed'),
  check ((status='cancelled' and char_length(trim(coalesce(cancellation_reason,''))) >= 3) or status<>'cancelled')
);
create unique index fleet_trips_active_vehicle_unique on public.fleet_trips(vehicle_id) where status in ('planned','assigned','started','arrived');
create unique index fleet_trips_active_driver_unique on public.fleet_trips(driver_id) where status in ('planned','assigned','started','arrived');
create index fleet_trips_factory_status_idx on public.fleet_trips(factory_id,status,planned_start_at desc);

create table public.fleet_odometer_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  vehicle_id uuid not null,
  trip_id uuid,
  reading_km numeric(18,2) not null check (reading_km >= 0),
  source text not null check (source in ('trip_start','trip_arrival','trip_complete','fuel','manual')),
  recorded_at timestamptz not null default now(),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (vehicle_id,factory_id) references public.fleet_vehicles(id,factory_id) on delete restrict,
  foreign key (trip_id,factory_id) references public.fleet_trips(id,factory_id) on delete restrict
);
create index fleet_odometer_vehicle_date_idx on public.fleet_odometer_logs(vehicle_id,recorded_at desc);

create table public.fleet_fuel_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  vehicle_id uuid not null,
  driver_id uuid,
  trip_id uuid,
  fuel_type text not null check (fuel_type in ('diesel','petrol','cng','other')),
  quantity_liters numeric(18,3) not null check (quantity_liters > 0),
  price_per_liter numeric(18,3) not null check (price_per_liter >= 0),
  total_amount numeric(18,2) generated always as (round(quantity_liters * price_per_liter,2)) stored,
  odometer_km numeric(18,2) not null check (odometer_km >= 0),
  filled_at timestamptz not null default now(),
  vendor text,
  receipt_reference text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (id,organization_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (vehicle_id,factory_id) references public.fleet_vehicles(id,factory_id) on delete restrict,
  foreign key (driver_id,factory_id) references public.fleet_drivers(id,factory_id) on delete restrict,
  foreign key (trip_id,factory_id) references public.fleet_trips(id,factory_id) on delete restrict
);
create index fleet_fuel_factory_date_idx on public.fleet_fuel_entries(factory_id,filled_at desc);
create index fleet_fuel_vehicle_date_idx on public.fleet_fuel_entries(vehicle_id,filled_at desc);

create table public.fleet_service_reminders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  vehicle_id uuid not null,
  reminder_type text not null check (reminder_type in ('service','insurance','fitness','permit','puc','tyre','other')),
  title text not null check (char_length(trim(title)) between 3 and 120),
  due_date date,
  due_odometer_km numeric(18,2) check (due_odometer_km is null or due_odometer_km >= 0),
  status text not null default 'open' check (status in ('open','completed','cancelled')),
  completed_at timestamptz,
  completed_odometer_km numeric(18,2),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  completed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,organization_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (vehicle_id,factory_id) references public.fleet_vehicles(id,factory_id) on delete restrict,
  check (due_date is not null or due_odometer_km is not null),
  check ((status='completed' and completed_at is not null) or status<>'completed')
);
create index fleet_service_factory_status_idx on public.fleet_service_reminders(factory_id,status,due_date);

create trigger fleet_vehicles_set_updated_at before update on public.fleet_vehicles for each row execute function public.set_updated_at();
create trigger fleet_drivers_set_updated_at before update on public.fleet_drivers for each row execute function public.set_updated_at();
create trigger fleet_assignments_set_updated_at before update on public.fleet_vehicle_driver_assignments for each row execute function public.set_updated_at();
create trigger fleet_trips_set_updated_at before update on public.fleet_trips for each row execute function public.set_updated_at();
create trigger fleet_service_set_updated_at before update on public.fleet_service_reminders for each row execute function public.set_updated_at();

create or replace function public.can_view_fleet_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_view_inventory_factory(target_factory_id);
$$;
grant execute on function public.can_view_fleet_factory(uuid) to authenticated;

create or replace function public.fleet_driver_is_current_user(target_driver_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1
    from public.fleet_drivers d
    join public.employees e on e.id=d.employee_id and e.organization_id=d.organization_id
    join public.organization_members om on om.organization_id=d.organization_id and om.user_id=e.user_id and om.is_active
    join public.factory_members fm on fm.organization_id=d.organization_id and fm.factory_id=d.factory_id and fm.user_id=e.user_id and fm.is_active
    where d.id=target_driver_id
      and d.status='active'
      and e.status='active'
      and e.user_id=auth.uid()
      and om.role='driver'
  );
$$;
grant execute on function public.fleet_driver_is_current_user(uuid) to authenticated;

create or replace function public.fleet_can_operate_trip(target_trip_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.fleet_trips t
    where t.id=target_trip_id
      and (public.can_manage_factory(t.factory_id) or public.fleet_driver_is_current_user(t.driver_id))
  );
$$;
grant execute on function public.fleet_can_operate_trip(uuid) to authenticated;

alter table public.fleet_vehicles enable row level security;
alter table public.fleet_drivers enable row level security;
alter table public.fleet_vehicle_driver_assignments enable row level security;
alter table public.fleet_trips enable row level security;
alter table public.fleet_odometer_logs enable row level security;
alter table public.fleet_fuel_entries enable row level security;
alter table public.fleet_service_reminders enable row level security;

grant select,update on public.fleet_vehicles,public.fleet_drivers to authenticated;
grant select on public.fleet_vehicle_driver_assignments,public.fleet_trips,public.fleet_odometer_logs,public.fleet_fuel_entries,public.fleet_service_reminders to authenticated;

create policy fleet_vehicles_select on public.fleet_vehicles for select to authenticated using (public.can_view_fleet_factory(factory_id));
create policy fleet_vehicles_update on public.fleet_vehicles for update to authenticated using (public.can_manage_factory(factory_id)) with check (public.can_manage_factory(factory_id));
create policy fleet_drivers_select on public.fleet_drivers for select to authenticated using (public.can_view_fleet_factory(factory_id));
create policy fleet_drivers_update on public.fleet_drivers for update to authenticated using (public.can_manage_factory(factory_id)) with check (public.can_manage_factory(factory_id));
create policy fleet_assignments_select on public.fleet_vehicle_driver_assignments for select to authenticated using (public.can_view_fleet_factory(factory_id));
create policy fleet_trips_select on public.fleet_trips for select to authenticated using (public.can_view_fleet_factory(factory_id));
create policy fleet_odometer_select on public.fleet_odometer_logs for select to authenticated using (public.can_view_fleet_factory(factory_id));
create policy fleet_fuel_select on public.fleet_fuel_entries for select to authenticated using (public.can_view_fleet_factory(factory_id));
create policy fleet_service_select on public.fleet_service_reminders for select to authenticated using (public.can_view_fleet_factory(factory_id));

create or replace function public.prevent_fleet_scope_change()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.organization_id<>old.organization_id or new.factory_id<>old.factory_id then
    raise exception 'Fleet organization/factory scope is immutable';
  end if;
  if tg_table_name='fleet_vehicles' and new.stock_location_id<>old.stock_location_id then
    raise exception 'Vehicle Inventory location is immutable';
  end if;
  if tg_table_name='fleet_drivers' and new.employee_id<>old.employee_id then
    raise exception 'Driver employee link is immutable';
  end if;
  return new;
end; $$;
revoke all on function public.prevent_fleet_scope_change() from public;
create trigger fleet_vehicles_scope_immutable before update on public.fleet_vehicles for each row execute function public.prevent_fleet_scope_change();
create trigger fleet_drivers_scope_immutable before update on public.fleet_drivers for each row execute function public.prevent_fleet_scope_change();

create or replace function public.prevent_fleet_history_change()
returns trigger language plpgsql set search_path=public as $$
begin
  raise exception 'Fleet history is immutable';
end; $$;
revoke all on function public.prevent_fleet_history_change() from public;
create trigger fleet_odometer_immutable before update or delete on public.fleet_odometer_logs for each row execute function public.prevent_fleet_history_change();
create trigger fleet_fuel_immutable before update or delete on public.fleet_fuel_entries for each row execute function public.prevent_fleet_history_change();

create or replace function public.audit_fleet_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_factory uuid; v_id text; v_meta jsonb;
begin
  v_org:=coalesce(new.organization_id,old.organization_id);
  v_factory:=coalesce(new.factory_id,old.factory_id);
  v_id:=coalesce(new.id,old.id)::text;
  if tg_op='INSERT' then v_meta:=jsonb_build_object('after',to_jsonb(new));
  elsif tg_op='UPDATE' then v_meta:=jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new));
  else v_meta:=jsonb_build_object('before',to_jsonb(old)); end if;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_org,v_factory,auth.uid(),lower(tg_op),tg_table_name,v_id,v_meta);
  return coalesce(new,old);
end; $$;
revoke all on function public.audit_fleet_change() from public;
create trigger fleet_vehicles_audit after insert or update on public.fleet_vehicles for each row execute function public.audit_fleet_change();
create trigger fleet_drivers_audit after insert or update on public.fleet_drivers for each row execute function public.audit_fleet_change();
create trigger fleet_assignments_audit after insert or update on public.fleet_vehicle_driver_assignments for each row execute function public.audit_fleet_change();
create trigger fleet_trips_audit after insert or update on public.fleet_trips for each row execute function public.audit_fleet_change();
create trigger fleet_odometer_audit after insert on public.fleet_odometer_logs for each row execute function public.audit_fleet_change();
create trigger fleet_fuel_audit after insert on public.fleet_fuel_entries for each row execute function public.audit_fleet_change();
create trigger fleet_service_audit after insert or update on public.fleet_service_reminders for each row execute function public.audit_fleet_change();

create or replace function public.fleet_create_vehicle(
  p_factory_id uuid,
  p_vehicle_code text,
  p_registration_no text,
  p_vehicle_type text,
  p_make text default null,
  p_model text default null,
  p_fuel_type text default 'diesel',
  p_capacity_quantity numeric default null,
  p_capacity_unit text default null,
  p_current_odometer_km numeric default 0,
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_vehicle uuid; v_location uuid; v_code text; v_reg text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Fleet management access required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  v_code:=upper(trim(coalesce(p_vehicle_code,'')));
  v_reg:=upper(trim(coalesce(p_registration_no,'')));
  if v_code !~ '^[A-Z0-9][A-Z0-9_-]{1,19}$' then raise exception 'Invalid vehicle code'; end if;
  if char_length(v_reg)<3 then raise exception 'Registration number is required'; end if;
  if p_vehicle_type not in ('truck','tanker','van','pickup','forklift','other') then raise exception 'Unsupported vehicle type'; end if;
  if p_fuel_type not in ('diesel','petrol','cng','electric','other') then raise exception 'Unsupported fuel type'; end if;
  if coalesce(p_current_odometer_km,0)<0 then raise exception 'Odometer cannot be negative'; end if;

  insert into public.stock_locations(organization_id,factory_id,name,code,location_type,is_active)
  values(v_org,p_factory_id,'Vehicle '||v_code,'VEH-'||v_code,'vehicle',true)
  returning id into v_location;

  insert into public.fleet_vehicles(
    organization_id,factory_id,stock_location_id,vehicle_code,registration_no,vehicle_type,make,model,fuel_type,
    capacity_quantity,capacity_unit,current_odometer_km,notes,created_by
  ) values(
    v_org,p_factory_id,v_location,v_code,v_reg,p_vehicle_type,nullif(trim(coalesce(p_make,'')),''),nullif(trim(coalesce(p_model,'')),''),p_fuel_type,
    p_capacity_quantity,nullif(trim(coalesce(p_capacity_unit,'')),''),coalesce(p_current_odometer_km,0),nullif(trim(coalesce(p_notes,'')),''),auth.uid()
  ) returning id into v_vehicle;

  return v_vehicle;
end; $$;
grant execute on function public.fleet_create_vehicle(uuid,text,text,text,text,text,text,numeric,text,numeric,text) to authenticated;

create or replace function public.fleet_create_driver(
  p_factory_id uuid,
  p_employee_id uuid,
  p_license_no text,
  p_license_type text,
  p_license_expiry date,
  p_emergency_phone text default null,
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Fleet management access required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.employees where id=p_employee_id and organization_id=v_org and primary_factory_id=p_factory_id and status='active') then
    raise exception 'Active employee in this factory not found';
  end if;
  if char_length(trim(coalesce(p_license_no,'')))<3 then raise exception 'License number is required'; end if;
  if char_length(trim(coalesce(p_license_type,'')))<1 then raise exception 'License type is required'; end if;
  if p_license_expiry is null then raise exception 'License expiry is required'; end if;

  insert into public.fleet_drivers(organization_id,factory_id,employee_id,license_no,license_type,license_expiry,emergency_phone,notes,created_by)
  values(v_org,p_factory_id,p_employee_id,upper(trim(p_license_no)),trim(p_license_type),p_license_expiry,nullif(trim(coalesce(p_emergency_phone,'')),''),nullif(trim(coalesce(p_notes,'')),''),auth.uid())
  returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.fleet_create_driver(uuid,uuid,text,text,date,text,text) to authenticated;

create or replace function public.fleet_assign_driver(
  p_vehicle_id uuid,
  p_driver_id uuid,
  p_effective_from timestamptz default now(),
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_vehicle public.fleet_vehicles%rowtype; v_driver public.fleet_drivers%rowtype; v_id uuid; v_effective timestamptz;
begin
  select * into v_vehicle from public.fleet_vehicles where id=p_vehicle_id for update;
  if v_vehicle.id is null then raise exception 'Vehicle not found'; end if;
  if not public.can_manage_factory(v_vehicle.factory_id) then raise exception 'Fleet management access required'; end if;
  select * into v_driver from public.fleet_drivers where id=p_driver_id for update;
  if v_driver.id is null or v_driver.factory_id<>v_vehicle.factory_id then raise exception 'Driver not found in this factory'; end if;
  if v_vehicle.status<>'active' then raise exception 'Only active vehicles can be assigned'; end if;
  if v_driver.status<>'active' then raise exception 'Only active drivers can be assigned'; end if;
  v_effective:=coalesce(p_effective_from,now());

  update public.fleet_vehicle_driver_assignments
    set ended_at=v_effective
    where ended_at is null and (vehicle_id=p_vehicle_id or driver_id=p_driver_id);

  insert into public.fleet_vehicle_driver_assignments(organization_id,factory_id,vehicle_id,driver_id,effective_from,notes,created_by)
  values(v_vehicle.organization_id,v_vehicle.factory_id,p_vehicle_id,p_driver_id,v_effective,nullif(trim(coalesce(p_notes,'')),''),auth.uid())
  returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.fleet_assign_driver(uuid,uuid,timestamptz,text) to authenticated;

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
declare v_org uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Fleet management access required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.fleet_vehicles where id=p_vehicle_id and factory_id=p_factory_id and status='active') then raise exception 'Active vehicle not found'; end if;
  if not exists(select 1 from public.fleet_drivers where id=p_driver_id and factory_id=p_factory_id and status='active' and license_expiry>=current_date) then raise exception 'Active licensed driver not found'; end if;
  if not exists(select 1 from public.fleet_vehicle_driver_assignments where vehicle_id=p_vehicle_id and driver_id=p_driver_id and ended_at is null and effective_from<=now()) then raise exception 'Vehicle and driver are not actively assigned'; end if;
  if p_planned_start_at is null then raise exception 'Planned start is required'; end if;
  if p_planned_end_at is not null and p_planned_end_at<p_planned_start_at then raise exception 'Planned end cannot be before planned start'; end if;
  if char_length(trim(coalesce(p_origin,'')))<2 or char_length(trim(coalesce(p_destination,'')))<2 then raise exception 'Origin and destination are required'; end if;
  if p_sales_order_id is not null and not exists(select 1 from public.sales_orders where id=p_sales_order_id and factory_id=p_factory_id) then raise exception 'Sales order not found in this factory'; end if;
  if p_warehouse_handoff_id is not null and not exists(select 1 from public.warehouse_dispatch_handoffs where id=p_warehouse_handoff_id and factory_id=p_factory_id and status='handed_off') then raise exception 'Completed warehouse handoff not found in this factory'; end if;

  insert into public.fleet_trips(
    organization_id,factory_id,vehicle_id,driver_id,sales_order_id,warehouse_handoff_id,origin,destination,status,
    planned_start_at,planned_end_at,notes,created_by
  ) values(
    v_org,p_factory_id,p_vehicle_id,p_driver_id,p_sales_order_id,p_warehouse_handoff_id,trim(p_origin),trim(p_destination),'assigned',
    p_planned_start_at,p_planned_end_at,nullif(trim(coalesce(p_notes,'')),''),auth.uid()
  ) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.fleet_create_trip(uuid,uuid,uuid,text,text,timestamptz,timestamptz,uuid,uuid,text) to authenticated;

create or replace function public.fleet_start_trip(p_trip_id uuid,p_odometer_km numeric,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_trip public.fleet_trips%rowtype; v_vehicle public.fleet_vehicles%rowtype;
begin
  select * into v_trip from public.fleet_trips where id=p_trip_id for update;
  if v_trip.id is null then raise exception 'Trip not found'; end if;
  if not public.fleet_can_operate_trip(p_trip_id) then raise exception 'Trip operation not allowed'; end if;
  if v_trip.status not in ('planned','assigned') then raise exception 'Trip cannot start from status %',v_trip.status; end if;
  select * into v_vehicle from public.fleet_vehicles where id=v_trip.vehicle_id for update;
  if v_vehicle.status<>'active' then raise exception 'Vehicle is not active'; end if;
  if p_odometer_km is null or p_odometer_km<v_vehicle.current_odometer_km then raise exception 'Start odometer cannot be below current vehicle odometer %',v_vehicle.current_odometer_km; end if;
  update public.fleet_trips set status='started',started_at=now(),start_odometer_km=p_odometer_km,started_by=auth.uid(),notes=coalesce(nullif(trim(coalesce(p_notes,'')),''),notes) where id=p_trip_id;
  update public.fleet_vehicles set current_odometer_km=p_odometer_km where id=v_vehicle.id;
  insert into public.fleet_odometer_logs(organization_id,factory_id,vehicle_id,trip_id,reading_km,source,notes,created_by)
  values(v_trip.organization_id,v_trip.factory_id,v_trip.vehicle_id,v_trip.id,p_odometer_km,'trip_start',nullif(trim(coalesce(p_notes,'')),''),auth.uid());
end; $$;
grant execute on function public.fleet_start_trip(uuid,numeric,text) to authenticated;

create or replace function public.fleet_mark_trip_arrived(p_trip_id uuid,p_odometer_km numeric,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_trip public.fleet_trips%rowtype; v_vehicle public.fleet_vehicles%rowtype;
begin
  select * into v_trip from public.fleet_trips where id=p_trip_id for update;
  if v_trip.id is null then raise exception 'Trip not found'; end if;
  if not public.fleet_can_operate_trip(p_trip_id) then raise exception 'Trip operation not allowed'; end if;
  if v_trip.status<>'started' then raise exception 'Trip can arrive only from started status'; end if;
  select * into v_vehicle from public.fleet_vehicles where id=v_trip.vehicle_id for update;
  if p_odometer_km is null or p_odometer_km<v_vehicle.current_odometer_km then raise exception 'Arrival odometer cannot be below current vehicle odometer %',v_vehicle.current_odometer_km; end if;
  update public.fleet_trips set status='arrived',arrived_at=now(),arrival_odometer_km=p_odometer_km,notes=coalesce(nullif(trim(coalesce(p_notes,'')),''),notes) where id=p_trip_id;
  update public.fleet_vehicles set current_odometer_km=p_odometer_km where id=v_vehicle.id;
  insert into public.fleet_odometer_logs(organization_id,factory_id,vehicle_id,trip_id,reading_km,source,notes,created_by)
  values(v_trip.organization_id,v_trip.factory_id,v_trip.vehicle_id,v_trip.id,p_odometer_km,'trip_arrival',nullif(trim(coalesce(p_notes,'')),''),auth.uid());
end; $$;
grant execute on function public.fleet_mark_trip_arrived(uuid,numeric,text) to authenticated;

create or replace function public.fleet_complete_trip(p_trip_id uuid,p_odometer_km numeric,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_trip public.fleet_trips%rowtype; v_vehicle public.fleet_vehicles%rowtype;
begin
  select * into v_trip from public.fleet_trips where id=p_trip_id for update;
  if v_trip.id is null then raise exception 'Trip not found'; end if;
  if not public.fleet_can_operate_trip(p_trip_id) then raise exception 'Trip operation not allowed'; end if;
  if v_trip.status not in ('started','arrived') then raise exception 'Trip cannot complete from status %',v_trip.status; end if;
  select * into v_vehicle from public.fleet_vehicles where id=v_trip.vehicle_id for update;
  if p_odometer_km is null or p_odometer_km<v_vehicle.current_odometer_km then raise exception 'End odometer cannot be below current vehicle odometer %',v_vehicle.current_odometer_km; end if;
  update public.fleet_trips set status='completed',completed_at=now(),end_odometer_km=p_odometer_km,completed_by=auth.uid(),notes=coalesce(nullif(trim(coalesce(p_notes,'')),''),notes) where id=p_trip_id;
  update public.fleet_vehicles set current_odometer_km=p_odometer_km where id=v_vehicle.id;
  insert into public.fleet_odometer_logs(organization_id,factory_id,vehicle_id,trip_id,reading_km,source,notes,created_by)
  values(v_trip.organization_id,v_trip.factory_id,v_trip.vehicle_id,v_trip.id,p_odometer_km,'trip_complete',nullif(trim(coalesce(p_notes,'')),''),auth.uid());
end; $$;
grant execute on function public.fleet_complete_trip(uuid,numeric,text) to authenticated;

create or replace function public.fleet_cancel_trip(p_trip_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
declare v_trip public.fleet_trips%rowtype;
begin
  select * into v_trip from public.fleet_trips where id=p_trip_id for update;
  if v_trip.id is null then raise exception 'Trip not found'; end if;
  if not public.can_manage_factory(v_trip.factory_id) then raise exception 'Fleet management access required'; end if;
  if v_trip.status in ('completed','cancelled') then raise exception 'Trip cannot be cancelled from status %',v_trip.status; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Cancellation reason is required'; end if;
  update public.fleet_trips set status='cancelled',cancellation_reason=trim(p_reason) where id=p_trip_id;
end; $$;
grant execute on function public.fleet_cancel_trip(uuid,text) to authenticated;

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
declare v_vehicle public.fleet_vehicles%rowtype; v_trip public.fleet_trips%rowtype; v_id uuid; v_allowed boolean:=false;
begin
  select * into v_vehicle from public.fleet_vehicles where id=p_vehicle_id for update;
  if v_vehicle.id is null then raise exception 'Vehicle not found'; end if;
  if public.can_manage_factory(v_vehicle.factory_id) then v_allowed:=true;
  elsif p_driver_id is not null and public.fleet_driver_is_current_user(p_driver_id) then v_allowed:=true;
  end if;
  if not v_allowed then raise exception 'Fuel entry not allowed'; end if;
  if p_driver_id is not null and not exists(select 1 from public.fleet_drivers where id=p_driver_id and factory_id=v_vehicle.factory_id and status='active') then raise exception 'Driver not found in this factory'; end if;
  if p_trip_id is not null then
    select * into v_trip from public.fleet_trips where id=p_trip_id;
    if v_trip.id is null or v_trip.factory_id<>v_vehicle.factory_id or v_trip.vehicle_id<>p_vehicle_id then raise exception 'Trip does not belong to this vehicle/factory'; end if;
    if p_driver_id is not null and v_trip.driver_id<>p_driver_id then raise exception 'Fuel driver does not match trip driver'; end if;
  end if;
  if v_vehicle.fuel_type='electric' then raise exception 'Electric vehicle does not accept liquid fuel entries'; end if;
  if p_quantity_liters is null or p_quantity_liters<=0 then raise exception 'Fuel quantity must be greater than zero'; end if;
  if p_price_per_liter is null or p_price_per_liter<0 then raise exception 'Fuel price cannot be negative'; end if;
  if p_odometer_km is null or p_odometer_km<v_vehicle.current_odometer_km then raise exception 'Fuel odometer cannot be below current vehicle odometer %',v_vehicle.current_odometer_km; end if;

  insert into public.fleet_fuel_entries(
    organization_id,factory_id,vehicle_id,driver_id,trip_id,fuel_type,quantity_liters,price_per_liter,odometer_km,filled_at,vendor,receipt_reference,notes,created_by
  ) values(
    v_vehicle.organization_id,v_vehicle.factory_id,p_vehicle_id,p_driver_id,p_trip_id,v_vehicle.fuel_type,p_quantity_liters,p_price_per_liter,p_odometer_km,
    coalesce(p_filled_at,now()),nullif(trim(coalesce(p_vendor,'')),''),nullif(trim(coalesce(p_receipt_reference,'')),''),nullif(trim(coalesce(p_notes,'')),''),auth.uid()
  ) returning id into v_id;
  update public.fleet_vehicles set current_odometer_km=p_odometer_km where id=p_vehicle_id;
  insert into public.fleet_odometer_logs(organization_id,factory_id,vehicle_id,trip_id,reading_km,source,notes,created_by)
  values(v_vehicle.organization_id,v_vehicle.factory_id,p_vehicle_id,p_trip_id,p_odometer_km,'fuel','Fuel entry',auth.uid());
  return v_id;
end; $$;
grant execute on function public.fleet_record_fuel(uuid,uuid,uuid,numeric,numeric,numeric,timestamptz,text,text,text) to authenticated;

create or replace function public.fleet_create_service_reminder(
  p_vehicle_id uuid,
  p_reminder_type text,
  p_title text,
  p_due_date date default null,
  p_due_odometer_km numeric default null,
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_vehicle public.fleet_vehicles%rowtype; v_id uuid;
begin
  select * into v_vehicle from public.fleet_vehicles where id=p_vehicle_id;
  if v_vehicle.id is null then raise exception 'Vehicle not found'; end if;
  if not public.can_manage_factory(v_vehicle.factory_id) then raise exception 'Fleet management access required'; end if;
  if p_reminder_type not in ('service','insurance','fitness','permit','puc','tyre','other') then raise exception 'Unsupported reminder type'; end if;
  if char_length(trim(coalesce(p_title,'')))<3 then raise exception 'Reminder title is required'; end if;
  if p_due_date is null and p_due_odometer_km is null then raise exception 'Due date or due odometer is required'; end if;
  if p_due_odometer_km is not null and p_due_odometer_km<v_vehicle.current_odometer_km then raise exception 'Due odometer cannot be below current vehicle odometer'; end if;
  insert into public.fleet_service_reminders(organization_id,factory_id,vehicle_id,reminder_type,title,due_date,due_odometer_km,notes,created_by)
  values(v_vehicle.organization_id,v_vehicle.factory_id,p_vehicle_id,p_reminder_type,trim(p_title),p_due_date,p_due_odometer_km,nullif(trim(coalesce(p_notes,'')),''),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.fleet_create_service_reminder(uuid,text,text,date,numeric,text) to authenticated;

create or replace function public.fleet_complete_service_reminder(
  p_reminder_id uuid,
  p_completed_odometer_km numeric default null,
  p_notes text default null
) returns void
language plpgsql security definer set search_path=public as $$
declare v_rem public.fleet_service_reminders%rowtype; v_vehicle public.fleet_vehicles%rowtype; v_odo numeric;
begin
  select * into v_rem from public.fleet_service_reminders where id=p_reminder_id for update;
  if v_rem.id is null then raise exception 'Service reminder not found'; end if;
  if not public.can_manage_factory(v_rem.factory_id) then raise exception 'Fleet management access required'; end if;
  if v_rem.status<>'open' then raise exception 'Only open reminders can be completed'; end if;
  select * into v_vehicle from public.fleet_vehicles where id=v_rem.vehicle_id for update;
  v_odo:=coalesce(p_completed_odometer_km,v_vehicle.current_odometer_km);
  if v_odo<v_vehicle.current_odometer_km then raise exception 'Completed odometer cannot be below current vehicle odometer'; end if;
  update public.fleet_service_reminders set status='completed',completed_at=now(),completed_odometer_km=v_odo,completed_by=auth.uid(),notes=coalesce(nullif(trim(coalesce(p_notes,'')),''),notes) where id=p_reminder_id;
  if v_odo>v_vehicle.current_odometer_km then
    update public.fleet_vehicles set current_odometer_km=v_odo where id=v_vehicle.id;
    insert into public.fleet_odometer_logs(organization_id,factory_id,vehicle_id,reading_km,source,notes,created_by)
    values(v_vehicle.organization_id,v_vehicle.factory_id,v_vehicle.id,v_odo,'manual','Service completion odometer',auth.uid());
  end if;
end; $$;
grant execute on function public.fleet_complete_service_reminder(uuid,numeric,text) to authenticated;

create or replace function public.fleet_dashboard_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_result jsonb;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access required'; end if;
  if p_factory_id is not null and not public.can_view_fleet_factory(p_factory_id) then raise exception 'Factory access required'; end if;
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
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access required'; end if;
  if p_factory_id is not null and not public.can_view_fleet_factory(p_factory_id) then raise exception 'Factory access required'; end if;
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
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access required'; end if;
  if p_factory_id is not null and not public.can_view_fleet_factory(p_factory_id) then raise exception 'Factory access required'; end if;
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
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access required'; end if;
  if p_factory_id is not null and not public.can_view_fleet_factory(p_factory_id) then raise exception 'Factory access required'; end if;
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
