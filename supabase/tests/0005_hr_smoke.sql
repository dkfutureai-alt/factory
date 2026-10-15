begin;

DO $$
DECLARE
  required_table text;
  rls_enabled boolean;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'departments','designations','shifts','employees','leave_types','leave_requests','holidays','attendance_records'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN
      RAISE EXCEPTION 'missing HR table: %', required_table;
    END IF;
    SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid = to_regclass('public.' || required_table);
    IF NOT rls_enabled THEN RAISE EXCEPTION 'RLS disabled on HR table: %', required_table; END IF;
  END LOOP;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.departments WHERE organization_id='10000000-0000-4000-8000-000000000001' AND code='PROD') THEN
    RAISE EXCEPTION 'HR seed department missing';
  END IF;
  IF (SELECT count(*) FROM public.employees WHERE organization_id='10000000-0000-4000-8000-000000000001') < 6 THEN
    RAISE EXCEPTION 'HR employee demo data is incomplete';
  END IF;
  IF (SELECT count(*) FROM public.leave_types WHERE organization_id='10000000-0000-4000-8000-000000000001') < 3 THEN
    RAISE EXCEPTION 'leave type seed data incomplete';
  END IF;
  IF (SELECT count(*) FROM public.shifts WHERE organization_id='10000000-0000-4000-8000-000000000001') < 2 THEN
    RAISE EXCEPTION 'shift seed data incomplete';
  END IF;
END $$;

DO $$
BEGIN
  IF to_regprocedure('public.mark_my_attendance(text)') IS NULL THEN RAISE EXCEPTION 'mark_my_attendance missing'; END IF;
  IF to_regprocedure('public.request_my_leave(uuid,date,date,text)') IS NULL THEN RAISE EXCEPTION 'request_my_leave missing'; END IF;
  IF to_regprocedure('public.decide_leave_request(uuid,text,text)') IS NULL THEN RAISE EXCEPTION 'decide_leave_request missing'; END IF;
  IF to_regprocedure('public.hr_dashboard_summary(uuid,uuid,date)') IS NULL THEN RAISE EXCEPTION 'hr_dashboard_summary missing'; END IF;
  IF to_regprocedure('public.hr_attendance_report(uuid,uuid,date,date)') IS NULL THEN RAISE EXCEPTION 'hr_attendance_report missing'; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='employees' AND policyname='employees_select'
  ) THEN RAISE EXCEPTION 'employees RLS policy missing'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='attendance_records' AND policyname='attendance_select'
  ) THEN RAISE EXCEPTION 'attendance RLS policy missing'; END IF;
END $$;

rollback;
