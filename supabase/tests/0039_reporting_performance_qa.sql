begin;

-- Phase 15 regression checks for the reporting performance hardening.
do $$
declare
  v_missing text[];
  v_exec_def text;
  v_trend_def text;
  v_exec_config text;
  v_trend_config text;
begin
  select array_agg(name order by name)
  into v_missing
  from (
    values
      ('reports_customer_invoices_org_date_idx'),
      ('reports_supplier_invoices_org_date_idx'),
      ('reports_stock_ledger_factory_item_idx'),
      ('reports_production_outputs_org_date_idx'),
      ('reports_production_orders_org_plan_date_idx'),
      ('reports_quality_completed_org_date_idx'),
      ('reports_dispatch_delivered_org_date_idx'),
      ('reports_maintenance_downtime_org_date_idx'),
      ('reports_attendance_org_date_idx')
  ) required(name)
  where to_regclass('public.' || required.name) is null;

  if v_missing is not null then
    raise exception 'Missing Phase 15 performance indexes: %', v_missing;
  end if;

  select pg_get_functiondef('public.reports_executive_dashboard(uuid,uuid,date,date)'::regprocedure)
  into v_exec_def;
  select pg_get_functiondef('public.reports_daily_trend(uuid,uuid,date,date)'::regprocedure)
  into v_trend_def;

  if position('occurred_at::date between' in lower(v_exec_def)) > 0
     or position('delivered_at::date between' in lower(v_exec_def)) > 0
     or position('started_at::date between' in lower(v_exec_def)) > 0
     or position('completed_at::date between' in lower(v_exec_def)) > 0 then
    raise exception 'Executive report still casts indexed timestamp columns in range filters';
  end if;

  if position('occurred_at::date between' in lower(v_trend_def)) > 0
     or position('delivered_at::date between' in lower(v_trend_def)) > 0 then
    raise exception 'Daily trend still casts indexed timestamp columns in range filters';
  end if;

  select coalesce(array_to_string(p.proconfig, ','), '')
  into v_exec_config
  from pg_proc p
  where p.oid='public.reports_executive_dashboard(uuid,uuid,date,date)'::regprocedure;

  select coalesce(array_to_string(p.proconfig, ','), '')
  into v_trend_config
  from pg_proc p
  where p.oid='public.reports_daily_trend(uuid,uuid,date,date)'::regprocedure;

  if v_exec_config not like '%search_path=""%' then
    raise exception 'Executive report SECURITY DEFINER search_path is not pinned: %', v_exec_config;
  end if;
  if v_trend_config not like '%search_path=""%' then
    raise exception 'Daily trend SECURITY DEFINER search_path is not pinned: %', v_trend_config;
  end if;

  if has_function_privilege('anon','public.reports_executive_dashboard(uuid,uuid,date,date)','EXECUTE')
     or has_function_privilege('anon','public.reports_daily_trend(uuid,uuid,date,date)','EXECUTE') then
    raise exception 'Anonymous role can execute privileged reporting RPCs';
  end if;

  if not has_function_privilege('authenticated','public.reports_executive_dashboard(uuid,uuid,date,date)','EXECUTE')
     or not has_function_privilege('authenticated','public.reports_daily_trend(uuid,uuid,date,date)','EXECUTE') then
    raise exception 'Authenticated role lost reporting RPC access';
  end if;
end;
$$;

rollback;
