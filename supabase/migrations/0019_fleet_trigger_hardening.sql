begin;

-- A trigger function shared by vehicles and drivers must not directly reference
-- relation-specific NEW/OLD fields. PostgreSQL can resolve a RECORD against the
-- invoking table shape, so a vehicle update must never try to resolve employee_id.
create or replace function public.prevent_fleet_scope_change()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if new.organization_id is distinct from old.organization_id
     or new.factory_id is distinct from old.factory_id then
    raise exception 'Fleet organization/factory scope cannot be changed';
  end if;

  if tg_table_name = 'fleet_vehicles'
     and (to_jsonb(new) ->> 'stock_location_id') is distinct from (to_jsonb(old) ->> 'stock_location_id') then
    raise exception 'Fleet vehicle Inventory location cannot be changed';
  end if;

  if tg_table_name = 'fleet_drivers'
     and (to_jsonb(new) ->> 'employee_id') is distinct from (to_jsonb(old) ->> 'employee_id') then
    raise exception 'Fleet driver employee link cannot be changed';
  end if;

  return new;
end;
$$;
revoke all on function public.prevent_fleet_scope_change() from public;

commit;
