begin;

DO $$
DECLARE required_table text; rls_enabled boolean;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'warehouse_putaway_tasks','warehouse_pick_lists','warehouse_pick_lines','warehouse_dispatch_handoffs',
    'warehouse_cycle_counts','warehouse_cycle_count_lines','warehouse_stock_adjustments'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN RAISE EXCEPTION 'missing Phase 8 table: %',required_table; END IF;
    SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid=to_regclass('public.' || required_table);
    IF NOT rls_enabled THEN RAISE EXCEPTION 'RLS disabled on Phase 8 table: %',required_table; END IF;
  END LOOP;
END $$;

DO $$
BEGIN
  IF NOT EXISTS(select 1 from public.stock_locations where id='96000000-0000-4000-8000-000000000002' and location_type='zone' and parent_location_id='44000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'warehouse zone demo missing'; END IF;
  IF NOT EXISTS(select 1 from public.stock_locations where id='96000000-0000-4000-8000-000000000003' and location_type='bin' and parent_location_id='96000000-0000-4000-8000-000000000002') THEN RAISE EXCEPTION 'warehouse bin demo missing'; END IF;
  IF NOT EXISTS(select 1 from public.stock_locations where id='96000000-0000-4000-8000-000000000006' and location_type='staging') THEN RAISE EXCEPTION 'warehouse staging demo missing'; END IF;
  IF NOT EXISTS(select 1 from public.warehouse_putaway_tasks where task_no='PUT-DEMO-P8-001' and status='pending' and quantity=20) THEN RAISE EXCEPTION 'warehouse putaway demo missing'; END IF;
  IF NOT EXISTS(select 1 from public.warehouse_pick_lists where pick_list_no='PICK-DEMO-P8-001' and status='released') THEN RAISE EXCEPTION 'warehouse pick-list demo missing'; END IF;
  IF NOT EXISTS(select 1 from public.warehouse_pick_lines where pick_list_id='96200000-0000-4000-8000-000000000001' and quantity_required=4 and status='pending') THEN RAISE EXCEPTION 'warehouse pick line demo missing'; END IF;
  IF NOT EXISTS(select 1 from public.warehouse_cycle_counts where count_no='CC-DEMO-P8-001' and status='approved') THEN RAISE EXCEPTION 'warehouse cycle-count demo missing'; END IF;
END $$;

DO $$
BEGIN
  IF to_regprocedure('public.warehouse_create_putaway_task(uuid,uuid,uuid,uuid,numeric,uuid,text)') IS NULL THEN RAISE EXCEPTION 'warehouse_create_putaway_task missing'; END IF;
  IF to_regprocedure('public.warehouse_start_putaway(uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse_start_putaway missing'; END IF;
  IF to_regprocedure('public.warehouse_complete_putaway(uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse_complete_putaway missing'; END IF;
  IF to_regprocedure('public.warehouse_create_pick_list(uuid,uuid,text,text)') IS NULL THEN RAISE EXCEPTION 'warehouse_create_pick_list missing'; END IF;
  IF to_regprocedure('public.warehouse_start_pick_list(uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse_start_pick_list missing'; END IF;
  IF to_regprocedure('public.warehouse_confirm_pick_line(uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse_confirm_pick_line missing'; END IF;
  IF to_regprocedure('public.warehouse_stage_pick_list(uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse_stage_pick_list missing'; END IF;
  IF to_regprocedure('public.warehouse_handoff_pick_list(uuid,text)') IS NULL THEN RAISE EXCEPTION 'warehouse_handoff_pick_list missing'; END IF;
  IF to_regprocedure('public.warehouse_create_cycle_count(uuid,uuid,text)') IS NULL THEN RAISE EXCEPTION 'warehouse_create_cycle_count missing'; END IF;
  IF to_regprocedure('public.warehouse_record_cycle_count_line(uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'warehouse_record_cycle_count_line missing'; END IF;
  IF to_regprocedure('public.warehouse_submit_cycle_count(uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse_submit_cycle_count missing'; END IF;
  IF to_regprocedure('public.warehouse_approve_cycle_count(uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse_approve_cycle_count missing'; END IF;
  IF to_regprocedure('public.warehouse_adjust_stock(uuid,uuid,uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'warehouse_adjust_stock missing'; END IF;
  IF to_regprocedure('public.warehouse_dashboard_summary(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse dashboard RPC missing'; END IF;
  IF to_regprocedure('public.warehouse_bin_stock_report(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'warehouse stock report missing'; END IF;
  IF to_regprocedure('public.warehouse_putaway_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'warehouse putaway report missing'; END IF;
  IF to_regprocedure('public.warehouse_pick_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'warehouse pick report missing'; END IF;
  IF to_regprocedure('public.warehouse_cycle_count_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'warehouse cycle count report missing'; END IF;
END $$;

DO $$
DECLARE glove_stock numeric; oxygen_stock numeric;
BEGIN
  SELECT coalesce(sum(quantity_delta),0) INTO glove_stock FROM public.stock_ledger_entries WHERE item_id='43000000-0000-4000-8000-000000000005' AND location_id='44000000-0000-4000-8000-000000000001';
  SELECT coalesce(sum(quantity_delta),0) INTO oxygen_stock FROM public.stock_ledger_entries WHERE item_id='43000000-0000-4000-8000-000000000006' AND location_id='44000000-0000-4000-8000-000000000003';
  IF glove_stock < 20 THEN RAISE EXCEPTION 'putaway source stock does not cover demo task: %',glove_stock; END IF;
  IF oxygen_stock < 4 THEN RAISE EXCEPTION 'pick source stock does not cover demo list: %',oxygen_stock; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='warehouse_putaway_tasks' and policyname='warehouse_putaway_select') THEN RAISE EXCEPTION 'putaway RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='warehouse_pick_lists' and policyname='warehouse_pick_lists_select') THEN RAISE EXCEPTION 'pick-list RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='warehouse_cycle_counts' and policyname='warehouse_cycle_counts_select') THEN RAISE EXCEPTION 'cycle-count RLS policy missing'; END IF;
END $$;

rollback;
select 'warehouse smoke checks passed' as result;
