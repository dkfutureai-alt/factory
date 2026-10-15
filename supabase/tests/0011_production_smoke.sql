begin;

DO $$
DECLARE
  required_table text;
  rls_enabled boolean;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'production_recipes','production_recipe_components','work_centers','production_orders','production_batches',
    'production_material_issues','production_outputs','production_scrap_events','production_downtime_events'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN
      RAISE EXCEPTION 'missing production table: %', required_table;
    END IF;
    SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid=to_regclass('public.' || required_table);
    IF NOT rls_enabled THEN RAISE EXCEPTION 'RLS disabled on production table: %', required_table; END IF;
  END LOOP;
END $$;

DO $$
DECLARE
  oxygen_balance numeric;
  cylinder_balance numeric;
  valve_balance numeric;
  finished_balance numeric;
BEGIN
  IF (SELECT count(*) FROM public.production_recipes WHERE organization_id='10000000-0000-4000-8000-000000000001') < 1 THEN
    RAISE EXCEPTION 'production recipe demo data missing';
  END IF;
  IF (SELECT count(*) FROM public.work_centers WHERE factory_id='20000000-0000-4000-8000-000000000001') < 3 THEN
    RAISE EXCEPTION 'work-center demo data incomplete';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.production_orders WHERE order_no='PO-DEMO-001' AND status='in_progress') THEN
    RAISE EXCEPTION 'active production demo order missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.production_outputs WHERE id='57000000-0000-4000-8000-000000000001' AND good_quantity=8 AND scrap_quantity=1) THEN
    RAISE EXCEPTION 'production output demo record missing';
  END IF;

  SELECT coalesce(sum(quantity_delta),0) INTO oxygen_balance FROM public.stock_ledger_entries
  WHERE item_id='43000000-0000-4000-8000-000000000001' AND location_id='44000000-0000-4000-8000-000000000001';
  SELECT coalesce(sum(quantity_delta),0) INTO cylinder_balance FROM public.stock_ledger_entries
  WHERE item_id='43000000-0000-4000-8000-000000000003' AND location_id='44000000-0000-4000-8000-000000000003';
  SELECT coalesce(sum(quantity_delta),0) INTO valve_balance FROM public.stock_ledger_entries
  WHERE item_id='43000000-0000-4000-8000-000000000004' AND location_id='44000000-0000-4000-8000-000000000001';
  SELECT coalesce(sum(quantity_delta),0) INTO finished_balance FROM public.stock_ledger_entries
  WHERE item_id='43000000-0000-4000-8000-000000000006' AND location_id='44000000-0000-4000-8000-000000000003';

  IF oxygen_balance<>770 THEN RAISE EXCEPTION 'unexpected production-consumed oxygen balance: %',oxygen_balance; END IF;
  IF cylinder_balance<>82 THEN RAISE EXCEPTION 'unexpected cylinder balance: %',cylinder_balance; END IF;
  IF valve_balance<>8 THEN RAISE EXCEPTION 'unexpected valve balance: %',valve_balance; END IF;
  IF finished_balance<>8 THEN RAISE EXCEPTION 'unexpected finished-goods balance: %',finished_balance; END IF;
END $$;

DO $$
BEGIN
  IF to_regprocedure('public.production_create_order(uuid,uuid,uuid,numeric,timestamptz,timestamptz,text,text)') IS NULL THEN RAISE EXCEPTION 'production_create_order missing'; END IF;
  IF to_regprocedure('public.production_start_batch(uuid,text,numeric,uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'production_start_batch missing'; END IF;
  IF to_regprocedure('public.production_issue_material(uuid,uuid,uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'production_issue_material missing'; END IF;
  IF to_regprocedure('public.production_record_output(uuid,numeric,numeric,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'production_record_output missing'; END IF;
  IF to_regprocedure('public.production_log_downtime(uuid,text,integer,text,timestamptz)') IS NULL THEN RAISE EXCEPTION 'production_log_downtime missing'; END IF;
  IF to_regprocedure('public.production_set_batch_status(uuid,text)') IS NULL THEN RAISE EXCEPTION 'production_set_batch_status missing'; END IF;
  IF to_regprocedure('public.production_dashboard_summary(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'production_dashboard_summary missing'; END IF;
  IF to_regprocedure('public.production_order_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'production_order_report missing'; END IF;
  IF to_regprocedure('public.production_bom_requirements(uuid)') IS NULL THEN RAISE EXCEPTION 'production_bom_requirements missing'; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='production_orders' AND policyname='production_orders_select') THEN RAISE EXCEPTION 'production order RLS policy missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='production_outputs' AND policyname='production_outputs_select') THEN RAISE EXCEPTION 'production output RLS policy missing'; END IF;
END $$;

DO $$
BEGIN
  BEGIN
    update public.production_outputs set good_quantity=99 where id='57000000-0000-4000-8000-000000000001';
    RAISE EXCEPTION 'production history immutability trigger did not block update';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='production history immutability trigger did not block update' THEN RAISE; END IF;
  END;
END $$;

DO $$
BEGIN
  BEGIN
    insert into public.production_recipe_components(organization_id,recipe_id,item_id,quantity_required)
    values('10000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000006',1);
    RAISE EXCEPTION 'recipe self-consumption integrity check did not block insert';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='recipe self-consumption integrity check did not block insert' THEN RAISE; END IF;
  END;
END $$;

rollback;