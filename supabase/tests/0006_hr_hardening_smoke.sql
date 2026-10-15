begin;

DO $$
BEGIN
  IF to_regprocedure('public.admin_set_attendance(uuid,date,text,timestamptz,timestamptz,text)') IS NULL THEN
    RAISE EXCEPTION 'admin_set_attendance missing';
  END IF;
  IF to_regprocedure('public.hr_headcount_report(uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'hr_headcount_report missing';
  END IF;
  IF to_regprocedure('public.hr_leave_report(uuid,uuid,date,date)') IS NULL THEN
    RAISE EXCEPTION 'hr_leave_report missing';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'employees_manager_same_organization_fk'
      AND conrelid = 'public.employees'::regclass
  ) THEN
    RAISE EXCEPTION 'same-organization employee manager constraint missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'employees_validate_hr_scope'
      AND tgrelid = 'public.employees'::regclass
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'employee HR scope validation trigger missing';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'shifts'
      AND policyname = 'shifts_select'
      AND qual ILIKE '%is_factory_member%'
  ) THEN
    RAISE EXCEPTION 'factory-scoped shift select policy missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'holidays'
      AND policyname = 'holidays_select'
      AND qual ILIKE '%is_factory_member%'
  ) THEN
    RAISE EXCEPTION 'factory-scoped holiday select policy missing';
  END IF;
END $$;

DO $$
DECLARE
  report_rows integer;
BEGIN
  -- Seed data should support the report query surface at the SQL layer.
  SELECT count(*) INTO report_rows
  FROM public.employees
  WHERE organization_id = '10000000-0000-4000-8000-000000000001'
    AND status = 'active';
  IF report_rows < 6 THEN
    RAISE EXCEPTION 'insufficient active HR report seed data';
  END IF;
END $$;

rollback;
