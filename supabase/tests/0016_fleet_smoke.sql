begin;

DO $$
DECLARE required_table text; rls_enabled boolean;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'fleet_vehicles','fleet_drivers','fleet_vehicle_driver_assignments','fleet_trips',
    'fleet_odometer_logs','fleet_fuel_entries','fleet_service_reminders'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN
      RAISE EXCEPTION 'missing Phase 9 table: %', required_table;
    END IF;
    SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid=to_regclass('public.' || required_table);
    IF NOT rls_enabled THEN
      RAISE EXCEPTION 'RLS disabled on Phase 9 table: %', required_table;
    END IF;
  END LOOP;
END $$;

DO $$
DECLARE fuel_total numeric; distance_km numeric;
BEGIN
  IF NOT EXISTS(
    select 1 from public.fleet_vehicles
    where id='97100000-0000-4000-8000-000000000001'
      and vehicle_code='TRK01'
      and status='active'
      and stock_location_id='97000000-0000-4000-8000-000000000001'
  ) THEN RAISE EXCEPTION 'fleet vehicle demo missing'; END IF;

  IF NOT EXISTS(
    select 1 from public.stock_locations
    where id='97000000-0000-4000-8000-000000000001'
      and location_type='vehicle'
      and factory_id='20000000-0000-4000-8000-000000000001'
  ) THEN RAISE EXCEPTION 'vehicle Inventory location demo missing'; END IF;

  IF NOT EXISTS(
    select 1 from public.fleet_drivers
    where id='97200000-0000-4000-8000-000000000001'
      and status='active'
      and license_expiry>current_date
  ) THEN RAISE EXCEPTION 'fleet driver demo missing'; END IF;

  IF NOT EXISTS(
    select 1 from public.fleet_vehicle_driver_assignments
    where id='97300000-0000-4000-8000-000000000001'
      and vehicle_id='97100000-0000-4000-8000-000000000001'
      and driver_id='97200000-0000-4000-8000-000000000001'
      and ended_at is null
  ) THEN RAISE EXCEPTION 'active vehicle-driver assignment demo missing'; END IF;

  IF NOT EXISTS(
    select 1 from public.fleet_trips
    where trip_no='TRIP-DEMO-P9-001' and status='assigned'
  ) THEN RAISE EXCEPTION 'assigned trip demo missing'; END IF;

  select end_odometer_km-start_odometer_km into distance_km
  from public.fleet_trips where trip_no='TRIP-DEMO-P9-000';
  IF distance_km<>160 THEN RAISE EXCEPTION 'completed trip demo distance invalid: %',distance_km; END IF;

  select total_amount into fuel_total
  from public.fleet_fuel_entries where id='97600000-0000-4000-8000-000000000001';
  IF fuel_total<>3647.88 THEN RAISE EXCEPTION 'generated fuel total invalid: %',fuel_total; END IF;

  IF NOT EXISTS(
    select 1 from public.fleet_service_reminders
    where id='97700000-0000-4000-8000-000000000001' and status='open'
  ) THEN RAISE EXCEPTION 'fleet service/compliance reminder demo missing'; END IF;
END $$;

DO $$
BEGIN
  IF to_regprocedure('public.can_view_fleet_factory(uuid)') IS NULL THEN RAISE EXCEPTION 'can_view_fleet_factory missing'; END IF;
  IF to_regprocedure('public.fleet_driver_is_current_user(uuid)') IS NULL THEN RAISE EXCEPTION 'fleet_driver_is_current_user missing'; END IF;
  IF to_regprocedure('public.fleet_can_operate_trip(uuid)') IS NULL THEN RAISE EXCEPTION 'fleet_can_operate_trip missing'; END IF;
  IF to_regprocedure('public.fleet_assert_report_scope(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'fleet_assert_report_scope missing'; END IF;
  IF to_regprocedure('public.fleet_create_vehicle(uuid,text,text,text,text,text,text,numeric,text,numeric,text)') IS NULL THEN RAISE EXCEPTION 'fleet_create_vehicle missing'; END IF;
  IF to_regprocedure('public.fleet_create_driver(uuid,uuid,text,text,date,text,text)') IS NULL THEN RAISE EXCEPTION 'fleet_create_driver missing'; END IF;
  IF to_regprocedure('public.fleet_assign_driver(uuid,uuid,timestamptz,text)') IS NULL THEN RAISE EXCEPTION 'fleet_assign_driver missing'; END IF;
  IF to_regprocedure('public.fleet_create_trip(uuid,uuid,uuid,text,text,timestamptz,timestamptz,uuid,uuid,text)') IS NULL THEN RAISE EXCEPTION 'fleet_create_trip missing'; END IF;
  IF to_regprocedure('public.fleet_start_trip(uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'fleet_start_trip missing'; END IF;
  IF to_regprocedure('public.fleet_mark_trip_arrived(uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'fleet_mark_trip_arrived missing'; END IF;
  IF to_regprocedure('public.fleet_complete_trip(uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'fleet_complete_trip missing'; END IF;
  IF to_regprocedure('public.fleet_cancel_trip(uuid,text)') IS NULL THEN RAISE EXCEPTION 'fleet_cancel_trip missing'; END IF;
  IF to_regprocedure('public.fleet_record_fuel(uuid,uuid,uuid,numeric,numeric,numeric,timestamptz,text,text,text)') IS NULL THEN RAISE EXCEPTION 'fleet_record_fuel missing'; END IF;
  IF to_regprocedure('public.fleet_create_service_reminder(uuid,text,text,date,numeric,text)') IS NULL THEN RAISE EXCEPTION 'fleet_create_service_reminder missing'; END IF;
  IF to_regprocedure('public.fleet_complete_service_reminder(uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'fleet_complete_service_reminder missing'; END IF;
  IF to_regprocedure('public.fleet_dashboard_summary(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'fleet dashboard RPC missing'; END IF;
  IF to_regprocedure('public.fleet_trip_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'fleet trip report missing'; END IF;
  IF to_regprocedure('public.fleet_fuel_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'fleet fuel report missing'; END IF;
  IF to_regprocedure('public.fleet_service_due_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'fleet service report missing'; END IF;
END $$;

DO $$
DECLARE regression_blocked boolean:=false;
BEGIN
  IF NOT EXISTS(
    select 1 from pg_trigger
    where tgrelid='public.fleet_vehicles'::regclass
      and tgname='fleet_vehicle_odometer_monotonic'
      and not tgisinternal
  ) THEN RAISE EXCEPTION 'vehicle odometer monotonic trigger missing'; END IF;

  IF NOT EXISTS(
    select 1 from pg_indexes
    where schemaname='public'
      and tablename='fleet_trips'
      and indexname='fleet_trips_handoff_active_unique'
  ) THEN RAISE EXCEPTION 'warehouse handoff trip uniqueness index missing'; END IF;

  BEGIN
    update public.fleet_vehicles
    set current_odometer_km=current_odometer_km-1
    where id='97100000-0000-4000-8000-000000000001';
  EXCEPTION WHEN OTHERS THEN
    regression_blocked:=position('cannot move backward' in SQLERRM)>0;
  END;

  IF NOT regression_blocked THEN
    RAISE EXCEPTION 'vehicle odometer regression was not blocked';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='fleet_vehicles' and policyname='fleet_vehicles_select') THEN RAISE EXCEPTION 'fleet vehicle RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='fleet_drivers' and policyname='fleet_drivers_select') THEN RAISE EXCEPTION 'fleet driver RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='fleet_trips' and policyname='fleet_trips_select') THEN RAISE EXCEPTION 'fleet trip RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='fleet_fuel_entries' and policyname='fleet_fuel_select') THEN RAISE EXCEPTION 'fleet fuel RLS policy missing'; END IF;
END $$;

rollback;
select 'fleet smoke checks passed' as result;
