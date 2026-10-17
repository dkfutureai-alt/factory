begin;

DO $$
DECLARE rls_enabled boolean;
BEGIN
  IF to_regclass('public.report_saved_views') IS NULL THEN
    RAISE EXCEPTION 'report_saved_views table missing';
  END IF;
  SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid=to_regclass('public.report_saved_views');
  IF NOT rls_enabled THEN RAISE EXCEPTION 'RLS disabled on report_saved_views'; END IF;
END $$;

DO $$
BEGIN
  IF to_regprocedure('public.reports_can_view_factory(uuid)') IS NULL THEN RAISE EXCEPTION 'reports_can_view_factory missing'; END IF;
  IF to_regprocedure('public.reports_scope_allowed(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'reports_scope_allowed missing'; END IF;
  IF to_regprocedure('public.reports_executive_dashboard(uuid,uuid,date,date)') IS NULL THEN RAISE EXCEPTION 'reports_executive_dashboard missing'; END IF;
  IF to_regprocedure('public.reports_daily_trend(uuid,uuid,date,date)') IS NULL THEN RAISE EXCEPTION 'reports_daily_trend missing'; END IF;
  IF to_regprocedure('public.reports_operational_exceptions(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'reports_operational_exceptions missing'; END IF;
  IF to_regprocedure('public.reports_recent_activity(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'reports_recent_activity missing'; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='report_saved_views' and policyname='report_saved_views_select') THEN RAISE EXCEPTION 'saved-view select policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='report_saved_views' and policyname='report_saved_views_insert') THEN RAISE EXCEPTION 'saved-view insert policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='report_saved_views' and policyname='report_saved_views_update') THEN RAISE EXCEPTION 'saved-view update policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_policies where schemaname='public' and tablename='report_saved_views' and policyname='report_saved_views_delete') THEN RAISE EXCEPTION 'saved-view delete policy missing'; END IF;
  IF NOT EXISTS(select 1 from pg_indexes where schemaname='public' and tablename='report_saved_views' and indexname='report_saved_views_default_unique') THEN RAISE EXCEPTION 'saved-view default uniqueness index missing'; END IF;
END $$;

DO $$
DECLARE blocked boolean:=false;
BEGIN
  BEGIN
    perform public.reports_validate_range(current_date,current_date-1,366);
  EXCEPTION WHEN OTHERS THEN
    blocked:=position('end date cannot be before start date' in SQLERRM)>0;
  END;
  IF NOT blocked THEN RAISE EXCEPTION 'invalid report date range was not rejected'; END IF;

  blocked:=false;
  BEGIN
    perform public.reports_validate_range(current_date-500,current_date,366);
  EXCEPTION WHEN OTHERS THEN
    blocked:=position('range cannot exceed' in SQLERRM)>0;
  END;
  IF NOT blocked THEN RAISE EXCEPTION 'oversized report date range was not rejected'; END IF;
END $$;

rollback;
select 'reports and dashboards smoke checks passed' as result;
