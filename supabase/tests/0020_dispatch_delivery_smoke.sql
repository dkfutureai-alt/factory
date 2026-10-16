begin;

DO $$
DECLARE required_table text; rls_enabled boolean;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'dispatch_deliveries','dispatch_delivery_lines','dispatch_returnable_pickups',
    'dispatch_returnable_lines','dispatch_delivery_exceptions'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN
      RAISE EXCEPTION 'missing Phase 10 table: %', required_table;
    END IF;
    SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid=to_regclass('public.' || required_table);
    IF NOT rls_enabled THEN
      RAISE EXCEPTION 'RLS disabled on Phase 10 table: %', required_table;
    END IF;
  END LOOP;
END $$;

DO $$
BEGIN
  IF NOT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='inventory_items'
      AND column_name='is_returnable' AND data_type='boolean'
  ) THEN RAISE EXCEPTION 'inventory_items.is_returnable missing'; END IF;

  IF to_regprocedure('public.can_view_dispatch_factory(uuid)') IS NULL THEN RAISE EXCEPTION 'can_view_dispatch_factory missing'; END IF;
  IF to_regprocedure('public.dispatch_driver_can_access_delivery(uuid)') IS NULL THEN RAISE EXCEPTION 'dispatch driver scope RPC missing'; END IF;
  IF to_regprocedure('public.dispatch_create_delivery(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'dispatch_create_delivery missing'; END IF;
  IF to_regprocedure('public.dispatch_confirm_vehicle_load(uuid)') IS NULL THEN RAISE EXCEPTION 'dispatch_confirm_vehicle_load missing'; END IF;
  IF to_regprocedure('public.dispatch_begin_delivery(uuid)') IS NULL THEN RAISE EXCEPTION 'dispatch_begin_delivery missing'; END IF;
  IF to_regprocedure('public.dispatch_mark_arrived(uuid)') IS NULL THEN RAISE EXCEPTION 'dispatch_mark_arrived missing'; END IF;
  IF to_regprocedure('public.dispatch_complete_delivery(uuid,text,text,text,text,text)') IS NULL THEN RAISE EXCEPTION 'dispatch_complete_delivery missing'; END IF;
  IF to_regprocedure('public.dispatch_record_returnable(uuid,uuid,numeric,text,text)') IS NULL THEN RAISE EXCEPTION 'dispatch_record_returnable missing'; END IF;
  IF to_regprocedure('public.dispatch_complete_returnables(uuid,text)') IS NULL THEN RAISE EXCEPTION 'dispatch_complete_returnables missing'; END IF;
  IF to_regprocedure('public.dispatch_report_exception(uuid,text,text,uuid,numeric)') IS NULL THEN RAISE EXCEPTION 'dispatch_report_exception missing'; END IF;
  IF to_regprocedure('public.dispatch_resolve_exception(uuid,text)') IS NULL THEN RAISE EXCEPTION 'dispatch_resolve_exception missing'; END IF;
  IF to_regprocedure('public.dispatch_dashboard_summary(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'dispatch dashboard RPC missing'; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='dispatch_deliveries' and policyname='dispatch_deliveries_select') THEN RAISE EXCEPTION 'delivery RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='dispatch_delivery_lines' and policyname='dispatch_lines_select') THEN RAISE EXCEPTION 'delivery line RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='dispatch_returnable_pickups' and policyname='dispatch_returnable_pickups_select') THEN RAISE EXCEPTION 'returnable pickup RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='dispatch_delivery_exceptions' and policyname='dispatch_exceptions_select') THEN RAISE EXCEPTION 'delivery exception RLS policy missing'; END IF;
END $$;

DO $$
DECLARE status_constraint text;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO status_constraint
  FROM pg_constraint
  WHERE conrelid='public.dispatch_deliveries'::regclass AND contype='c'
    AND pg_get_constraintdef(oid) ILIKE '%ready_to_load%';
  IF status_constraint IS NULL OR status_constraint NOT ILIKE '%delivered%' THEN
    RAISE EXCEPTION 'dispatch delivery lifecycle status constraint missing';
  END IF;
END $$;

rollback;
select 'dispatch delivery smoke checks passed' as result;
