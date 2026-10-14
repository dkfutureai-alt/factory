-- Fleet trigger hardening discovered by PostgreSQL CI.
-- Apply after 07b_fleet_commands.sql and before Fleet demo seeds.
--
-- The original generic validator used expressions such as
--   tg_table_name = 'fuel_entries' AND new.trip_id IS NOT NULL
-- while also running for public.trips. PostgreSQL resolves NEW fields for the active record type,
-- so trips (which has no trip_id column) failed before boolean short-circuiting could help.
-- Keep every table-specific field reference inside its own table-specific branch.

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
    if new.factory_id is not null and not exists(
      select 1 from public.factories f
      where f.id = new.factory_id
        and f.organization_id = new.organization_id
    ) then
      raise exception 'vehicle factory organization mismatch';
    end if;
    return new;
  end if;

  if tg_table_name = 'vehicle_documents' then
    select organization_id into vehicle_org
    from public.vehicles where id = new.vehicle_id;
    if vehicle_org is null or vehicle_org <> new.organization_id then
      raise exception 'vehicle document organization mismatch';
    end if;
    return new;
  end if;

  if tg_table_name = 'driver_profiles' then
    select organization_id into employee_org
    from public.employees where id = new.employee_id;
    if employee_org is null or employee_org <> new.organization_id then
      raise exception 'driver employee organization mismatch';
    end if;
    return new;
  end if;

  if tg_table_name = 'vehicle_driver_assignments' then
    select organization_id, factory_id into vehicle_org, vehicle_factory
    from public.vehicles where id = new.vehicle_id;
    select organization_id, factory_id into employee_org, employee_factory
    from public.employees where id = new.driver_employee_id;

    if vehicle_org is null or employee_org is null
       or new.organization_id <> vehicle_org
       or new.organization_id <> employee_org then
      raise exception 'vehicle assignment organization mismatch';
    end if;
    if new.factory_id is distinct from vehicle_factory
       or new.factory_id is distinct from employee_factory then
      raise exception 'vehicle assignment factory mismatch';
    end if;
    if not exists(
      select 1 from public.driver_profiles dp
      where dp.employee_id = new.driver_employee_id
        and dp.organization_id = new.organization_id
        and dp.status = 'active'
    ) then
      raise exception 'employee is not an active driver';
    end if;
    return new;
  end if;

  if tg_table_name = 'trips' then
    select organization_id, factory_id into vehicle_org, vehicle_factory
    from public.vehicles where id = new.vehicle_id;
    select organization_id, factory_id into employee_org, employee_factory
    from public.employees where id = new.driver_employee_id;

    if vehicle_org is null or employee_org is null
       or new.organization_id <> vehicle_org
       or new.organization_id <> employee_org then
      raise exception 'fleet operation organization mismatch';
    end if;
    if new.factory_id is distinct from vehicle_factory
       or new.factory_id is distinct from employee_factory then
      raise exception 'fleet operation factory mismatch';
    end if;

    select exists(
      select 1 from public.vehicle_driver_assignments a
      where a.organization_id = new.organization_id
        and a.vehicle_id = new.vehicle_id
        and a.driver_employee_id = new.driver_employee_id
        and a.assigned_from <= coalesce(new.created_at, now())
        and (a.assigned_until is null or a.assigned_until >= coalesce(new.created_at, now()))
    ) into assignment_ok;
    if not assignment_ok then raise exception 'driver is not assigned to vehicle'; end if;

    if new.sales_order_id is not null then
      select organization_id into sales_org
      from public.sales_orders where id = new.sales_order_id;
      if sales_org is null or sales_org <> new.organization_id then
        raise exception 'trip sales order organization mismatch';
      end if;
    end if;
    return new;
  end if;

  if tg_table_name = 'vehicle_inspections' then
    select organization_id, factory_id into vehicle_org, vehicle_factory
    from public.vehicles where id = new.vehicle_id;
    select organization_id, factory_id into employee_org, employee_factory
    from public.employees where id = new.driver_employee_id;

    if vehicle_org is null or employee_org is null
       or new.organization_id <> vehicle_org
       or new.organization_id <> employee_org then
      raise exception 'fleet operation organization mismatch';
    end if;
    if new.factory_id is distinct from vehicle_factory
       or new.factory_id is distinct from employee_factory then
      raise exception 'fleet operation factory mismatch';
    end if;

    select exists(
      select 1 from public.vehicle_driver_assignments a
      where a.organization_id = new.organization_id
        and a.vehicle_id = new.vehicle_id
        and a.driver_employee_id = new.driver_employee_id
        and a.assigned_from <= coalesce(new.created_at, now())
        and (a.assigned_until is null or a.assigned_until >= coalesce(new.created_at, now()))
    ) into assignment_ok;
    if not assignment_ok then raise exception 'driver is not assigned to vehicle'; end if;

    if new.trip_id is not null and not exists(
      select 1 from public.trips t
      where t.id = new.trip_id
        and t.organization_id = new.organization_id
        and t.vehicle_id = new.vehicle_id
        and t.driver_employee_id = new.driver_employee_id
    ) then
      raise exception 'inspection trip assignment mismatch';
    end if;
    return new;
  end if;

  if tg_table_name = 'fuel_entries' then
    select organization_id, factory_id into vehicle_org, vehicle_factory
    from public.vehicles where id = new.vehicle_id;
    select organization_id, factory_id into employee_org, employee_factory
    from public.employees where id = new.driver_employee_id;

    if vehicle_org is null or employee_org is null
       or new.organization_id <> vehicle_org
       or new.organization_id <> employee_org then
      raise exception 'fleet operation organization mismatch';
    end if;
    if new.factory_id is distinct from vehicle_factory
       or new.factory_id is distinct from employee_factory then
      raise exception 'fleet operation factory mismatch';
    end if;

    select exists(
      select 1 from public.vehicle_driver_assignments a
      where a.organization_id = new.organization_id
        and a.vehicle_id = new.vehicle_id
        and a.driver_employee_id = new.driver_employee_id
        and a.assigned_from <= coalesce(new.created_at, now())
        and (a.assigned_until is null or a.assigned_until >= coalesce(new.created_at, now()))
    ) into assignment_ok;
    if not assignment_ok then raise exception 'driver is not assigned to vehicle'; end if;

    if new.trip_id is not null and not exists(
      select 1 from public.trips t
      where t.id = new.trip_id
        and t.organization_id = new.organization_id
        and t.vehicle_id = new.vehicle_id
        and t.driver_employee_id = new.driver_employee_id
    ) then
      raise exception 'fuel trip assignment mismatch';
    end if;
    return new;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_fleet_refs() from public;
