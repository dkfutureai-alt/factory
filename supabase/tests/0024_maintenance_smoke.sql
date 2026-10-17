begin;

do $$
begin
  if to_regclass('public.maintenance_assets') is null then raise exception 'maintenance_assets missing'; end if;
  if to_regclass('public.maintenance_requests') is null then raise exception 'maintenance_requests missing'; end if;
  if to_regclass('public.maintenance_plans') is null then raise exception 'maintenance_plans missing'; end if;
  if to_regclass('public.maintenance_work_orders') is null then raise exception 'maintenance_work_orders missing'; end if;
  if to_regclass('public.maintenance_spare_usage') is null then raise exception 'maintenance_spare_usage missing'; end if;
  if to_regclass('public.maintenance_downtime_events') is null then raise exception 'maintenance_downtime_events missing'; end if;

  if to_regprocedure('public.maintenance_create_asset(uuid,text,text,text,uuid,uuid,text,text,text,text,text,text)') is null then raise exception 'maintenance_create_asset missing'; end if;
  if to_regprocedure('public.maintenance_create_request(uuid,text,text,text)') is null then raise exception 'maintenance_create_request missing'; end if;
  if to_regprocedure('public.maintenance_create_plan(uuid,text,text,text,integer,date,uuid,text,integer,text)') is null then raise exception 'maintenance_create_plan missing'; end if;
  if to_regprocedure('public.maintenance_create_work_order(uuid,text,text,text,uuid,uuid,uuid,timestamp with time zone,timestamp with time zone)') is null then raise exception 'maintenance_create_work_order missing'; end if;
  if to_regprocedure('public.maintenance_start_work_order(uuid)') is null then raise exception 'maintenance_start_work_order missing'; end if;
  if to_regprocedure('public.maintenance_use_spare(uuid,uuid,uuid,numeric,numeric,text)') is null then raise exception 'maintenance_use_spare missing'; end if;
  if to_regprocedure('public.maintenance_start_downtime(uuid,text)') is null then raise exception 'maintenance_start_downtime missing'; end if;
  if to_regprocedure('public.maintenance_complete_work_order(uuid,text,integer,numeric)') is null then raise exception 'maintenance_complete_work_order missing'; end if;
  if to_regprocedure('public.maintenance_dashboard_summary(uuid,uuid)') is null then raise exception 'maintenance_dashboard_summary missing'; end if;
end $$;

do $$
declare v_enabled boolean;
begin
  select relrowsecurity into v_enabled from pg_class where oid='public.maintenance_work_orders'::regclass;
  if not v_enabled then raise exception 'maintenance_work_orders RLS is not enabled'; end if;
  select relrowsecurity into v_enabled from pg_class where oid='public.maintenance_spare_usage'::regclass;
  if not v_enabled then raise exception 'maintenance_spare_usage RLS is not enabled'; end if;
end $$;

do $$
declare v_count integer;
begin
  select count(*) into v_count from public.maintenance_assets where factory_id='20000000-0000-4000-8000-000000000001';
  if v_count < 5 then raise exception 'Phase 11 maintenance seed assets missing'; end if;
  select count(*) into v_count from public.maintenance_plans where factory_id='20000000-0000-4000-8000-000000000001';
  if v_count < 4 then raise exception 'Phase 11 preventive plans missing'; end if;
  select count(*) into v_count from public.maintenance_work_orders where factory_id='20000000-0000-4000-8000-000000000001';
  if v_count < 3 then raise exception 'Phase 11 work-order seed missing'; end if;
end $$;

rollback;
