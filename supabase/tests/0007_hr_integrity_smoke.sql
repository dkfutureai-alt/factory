begin;

DO $$
DECLARE
  policy_qual text;
BEGIN
  SELECT with_check INTO policy_qual
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'leave_requests'
    AND policyname = 'leave_requests_insert';

  IF policy_qual IS NULL OR policy_qual NOT ILIKE '%can_manage_hr_employee%' THEN
    RAISE EXCEPTION 'leave requests must use manager-only direct insert policy';
  END IF;

  IF policy_qual ILIKE '%is_hr_employee_self%' THEN
    RAISE EXCEPTION 'employee direct leave insert is still enabled';
  END IF;
END $$;

DO $$
DECLARE
  delete_action "char";
BEGIN
  SELECT confdeltype INTO delete_action
  FROM pg_constraint
  WHERE conname = 'employees_manager_same_organization_fk'
    AND conrelid = 'public.employees'::regclass;

  IF delete_action <> 'r' THEN
    RAISE EXCEPTION 'employee manager FK must restrict deletes';
  END IF;
END $$;

rollback;
