begin;

DO $$
DECLARE required_table text; rls_enabled boolean;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'maintenance_assets','maintenance_plans','maintenance_requests','maintenance_work_orders',
    'maintenance_part_usages','maintenance_downtime_events','maintenance_work_logs'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN
      RAISE EXCEPTION 'missing Phase 11 table: %', required_table;
    END IF;
    SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid=to_regclass('public.' || required_table);
    IF NOT rls_enabled THEN RAISE EXCEPTION 'RLS disabled on Phase 11 table: %', required_table; END IF;
  END LOOP;
END $$;

DO $$
BEGIN
  IF NOT EXISTS(
    select 1 from public.maintenance_assets
    where id='61000000-0000-4000-8000-000000000001'
      and asset_code='CMP-O2-01' and criticality='critical' and current_meter=2840
  ) THEN RAISE EXCEPTION 'maintenance compressor demo missing'; END IF;

  IF NOT EXISTS(
    select 1 from public.maintenance_plans
    where id='62000000-0000-4000-8000-000000000001'
      and next_due_at<=now() and is_active
  ) THEN RAISE EXCEPTION 'overdue preventive plan demo missing'; END IF;

  IF NOT EXISTS(
    select 1 from public.maintenance_requests
    where id='63000000-0000-4000-8000-000000000001'
      and request_type='breakdown' and status='in_progress' and safety_stop
  ) THEN RAISE EXCEPTION 'breakdown request demo missing'; END IF;

  IF NOT EXISTS(
    select 1 from public.maintenance_work_orders
    where id='64000000-0000-4000-8000-000000000001'
      and status='in_progress' and assigned_employee_id='35000000-0000-4000-8000-000000000003'
  ) THEN RAISE EXCEPTION 'in-progress maintenance work demo missing'; END IF;

  IF NOT EXISTS(
    select 1 from public.maintenance_downtime_events
    where work_order_id='64000000-0000-4000-8000-000000000001' and ended_at is null
  ) THEN RAISE EXCEPTION 'open downtime demo missing'; END IF;
END $$;

DO $$
BEGIN
  IF to_regprocedure('public.maintenance_current_employee(uuid)') IS NULL THEN RAISE EXCEPTION 'maintenance_current_employee missing'; END IF;
  IF to_regprocedure('public.maintenance_can_supervise_factory(uuid)') IS NULL THEN RAISE EXCEPTION 'maintenance_can_supervise_factory missing'; END IF;
  IF to_regprocedure('public.maintenance_can_operate_work_order(uuid)') IS NULL THEN RAISE EXCEPTION 'maintenance_can_operate_work_order missing'; END IF;
  IF to_regprocedure('public.maintenance_report_request(uuid,text,text,text,text,boolean)') IS NULL THEN RAISE EXCEPTION 'maintenance_report_request missing'; END IF;
  IF to_regprocedure('public.maintenance_create_work_order(uuid,text,text,text,text,uuid,uuid,uuid,timestamptz,timestamptz,text)') IS NULL THEN RAISE EXCEPTION 'maintenance_create_work_order missing'; END IF;
  IF to_regprocedure('public.maintenance_assign_work_order(uuid,uuid,timestamptz,timestamptz)') IS NULL THEN RAISE EXCEPTION 'maintenance_assign_work_order missing'; END IF;
  IF to_regprocedure('public.maintenance_start_work_order(uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'maintenance_start_work_order missing'; END IF;
  IF to_regprocedure('public.maintenance_hold_work_order(uuid,text)') IS NULL THEN RAISE EXCEPTION 'maintenance_hold_work_order missing'; END IF;
  IF to_regprocedure('public.maintenance_resume_work_order(uuid,text)') IS NULL THEN RAISE EXCEPTION 'maintenance_resume_work_order missing'; END IF;
  IF to_regprocedure('public.maintenance_add_work_log(uuid,text)') IS NULL THEN RAISE EXCEPTION 'maintenance_add_work_log missing'; END IF;
  IF to_regprocedure('public.maintenance_issue_part(uuid,uuid,uuid,numeric,numeric,text)') IS NULL THEN RAISE EXCEPTION 'maintenance_issue_part missing'; END IF;
  IF to_regprocedure('public.maintenance_complete_work_order(uuid,text,text,numeric,text)') IS NULL THEN RAISE EXCEPTION 'maintenance_complete_work_order missing'; END IF;
  IF to_regprocedure('public.maintenance_record_asset_meter(uuid,numeric,text)') IS NULL THEN RAISE EXCEPTION 'maintenance_record_asset_meter missing'; END IF;
  IF to_regprocedure('public.maintenance_generate_due_work_orders(uuid)') IS NULL THEN RAISE EXCEPTION 'maintenance_generate_due_work_orders missing'; END IF;
  IF to_regprocedure('public.maintenance_dashboard_summary(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'maintenance_dashboard_summary missing'; END IF;
  IF to_regprocedure('public.maintenance_work_order_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'maintenance_work_order_report missing'; END IF;
END $$;

DO $$
DECLARE blocked boolean:=false;
BEGIN
  BEGIN
    update public.maintenance_assets
    set factory_id='20000000-0000-4000-8000-000000000001', organization_id='10000000-0000-4000-8000-000000000001'
    where id='61000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN OTHERS THEN
    blocked:=false;
  END;

  BEGIN
    update public.maintenance_plans
    set asset_id='61000000-0000-4000-8000-000000000003'
    where id='62000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN OTHERS THEN
    blocked:=position('plan asset is immutable' in SQLERRM)>0;
  END;
  IF NOT blocked THEN RAISE EXCEPTION 'maintenance plan asset reassignment was not blocked'; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS(select 1 from pg_indexes where schemaname='public' and tablename='maintenance_work_orders' and indexname='maintenance_plan_active_work_unique') THEN
    RAISE EXCEPTION 'maintenance active-plan work-order uniqueness index missing';
  END IF;
  IF NOT EXISTS(select 1 from pg_indexes where schemaname='public' and tablename='maintenance_downtime_events' and indexname='maintenance_downtime_open_work_unique') THEN
    RAISE EXCEPTION 'maintenance open-downtime uniqueness index missing';
  END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='maintenance_assets' and policyname='maintenance_assets_select') THEN RAISE EXCEPTION 'maintenance asset RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='maintenance_work_orders' and policyname='maintenance_work_orders_select') THEN RAISE EXCEPTION 'maintenance work-order RLS policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='maintenance_part_usages' and policyname='maintenance_parts_select') THEN RAISE EXCEPTION 'maintenance part-usage RLS policy missing'; END IF;
END $$;

rollback;
select 'maintenance smoke checks passed' as result;
