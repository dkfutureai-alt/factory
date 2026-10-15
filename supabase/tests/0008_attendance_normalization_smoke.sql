begin;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'attendance_records_normalize'
      AND tgrelid = 'public.attendance_records'::regclass
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'attendance normalization trigger missing';
  END IF;
END $$;

DO $$
DECLARE
  employee_id uuid := '35000000-0000-4000-8000-000000000001';
  row_id uuid;
  check_in_value timestamptz;
  late_value integer;
BEGIN
  insert into public.attendance_records (
    organization_id, factory_id, employee_id, shift_id, work_date,
    status, check_in_at, late_minutes, source
  ) values (
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    employee_id,
    '33000000-0000-4000-8000-000000000001',
    date '2098-01-01',
    'present',
    timestamptz '2098-01-01 01:20:00+00',
    0,
    'system'
  ) returning id, late_minutes into row_id, late_value;

  IF late_value <= 0 THEN
    RAISE EXCEPTION 'late minutes were not normalized';
  END IF;

  update public.attendance_records
  set status = 'absent'
  where id = row_id
  returning check_in_at into check_in_value;

  IF check_in_value IS NOT NULL THEN
    RAISE EXCEPTION 'absent attendance retained check-in time';
  END IF;
END $$;

rollback;
