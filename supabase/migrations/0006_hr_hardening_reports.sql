begin;

alter table public.employees
  add constraint employees_manager_same_organization_fk
  foreign key (manager_employee_id, organization_id)
  references public.employees(id, organization_id)
  on delete set null;

create or replace function public.validate_employee_hr_scope()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  shift_factory uuid;
  designation_department uuid;
begin
  if new.shift_id is not null then
    select factory_id into shift_factory from public.shifts where id = new.shift_id;
    if shift_factory is not null and shift_factory <> new.primary_factory_id then
      raise exception 'Employee shift belongs to a different factory';
    end if;
  end if;

  if new.designation_id is not null and new.department_id is not null then
    select department_id into designation_department
    from public.designations where id = new.designation_id;
    if designation_department is not null and designation_department <> new.department_id then
      raise exception 'Employee designation belongs to a different department';
    end if;
  end if;

  return new;
end;
$$;

create trigger employees_validate_hr_scope
before insert or update of primary_factory_id, department_id, designation_id, shift_id
on public.employees
for each row execute function public.validate_employee_hr_scope();

-- Factory-scoped master records must not leak to users assigned elsewhere.
drop policy if exists shifts_select on public.shifts;
create policy shifts_select on public.shifts
for select to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or (factory_id is null and public.is_org_member(organization_id))
  or (factory_id is not null and public.is_factory_member(factory_id))
);

drop policy if exists holidays_select on public.holidays;
create policy holidays_select on public.holidays
for select to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or (factory_id is null and public.is_org_member(organization_id))
  or (factory_id is not null and public.is_factory_member(factory_id))
);

create or replace function public.mark_my_attendance(p_action text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  emp public.employees%rowtype;
  fac public.factories%rowtype;
  sh public.shifts%rowtype;
  existing public.attendance_records%rowtype;
  local_now timestamp;
  work_day date;
  now_ts timestamptz := now();
  scheduled_start timestamptz;
  late_mins integer := 0;
begin
  select * into emp
  from public.employees
  where user_id = auth.uid() and status = 'active'
  order by created_at
  limit 1;
  if not found then
    raise exception 'No active employee profile is linked to this account';
  end if;

  select * into fac
  from public.factories
  where id = emp.primary_factory_id and is_active;
  if not found then
    raise exception 'Assigned factory is inactive';
  end if;

  local_now := now_ts at time zone fac.timezone;
  work_day := local_now::date;

  if emp.shift_id is not null then
    select * into sh from public.shifts where id = emp.shift_id and is_active;
    if found and sh.crosses_midnight and local_now::time < sh.end_time then
      work_day := work_day - 1;
    end if;
  end if;

  select * into existing
  from public.attendance_records
  where employee_id = emp.id and work_date = work_day
  for update;

  if p_action = 'check_in' then
    if found and existing.check_in_at is not null then
      raise exception 'Already checked in for this shift';
    end if;

    if emp.shift_id is not null and sh.id is not null then
      scheduled_start := (work_day + sh.start_time) at time zone fac.timezone;
      late_mins := greatest(
        0,
        floor(extract(epoch from (now_ts - scheduled_start)) / 60)::integer - sh.grace_minutes
      );
    end if;

    insert into public.attendance_records (
      organization_id, factory_id, employee_id, shift_id, work_date,
      status, check_in_at, late_minutes, source, created_by, updated_by
    ) values (
      emp.organization_id, emp.primary_factory_id, emp.id, emp.shift_id, work_day,
      'present', now_ts, late_mins, 'self', auth.uid(), auth.uid()
    )
    on conflict (employee_id, work_date) do update set
      check_in_at = coalesce(public.attendance_records.check_in_at, excluded.check_in_at),
      status = 'present',
      late_minutes = excluded.late_minutes,
      source = 'self',
      updated_by = auth.uid();

  elsif p_action = 'check_out' then
    if not found or existing.check_in_at is null then
      raise exception 'Check in before checking out';
    end if;
    if existing.check_out_at is not null then
      raise exception 'Already checked out for this shift';
    end if;

    update public.attendance_records
    set check_out_at = now_ts,
        worked_minutes = greatest(
          0,
          floor(extract(epoch from (now_ts - existing.check_in_at)) / 60)::integer
        ),
        updated_by = auth.uid()
    where id = existing.id;
  else
    raise exception 'Action must be check_in or check_out';
  end if;

  return (
    select jsonb_build_object(
      'work_date', ar.work_date,
      'status', ar.status,
      'check_in_at', ar.check_in_at,
      'check_out_at', ar.check_out_at,
      'worked_minutes', ar.worked_minutes,
      'late_minutes', ar.late_minutes
    )
    from public.attendance_records ar
    where ar.employee_id = emp.id and ar.work_date = work_day
  );
end;
$$;

create or replace function public.admin_set_attendance(
  p_employee_id uuid,
  p_work_date date,
  p_status text,
  p_check_in_at timestamptz default null,
  p_check_out_at timestamptz default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  emp public.employees%rowtype;
  fac public.factories%rowtype;
  sh public.shifts%rowtype;
  effective_check_in timestamptz;
  scheduled_start timestamptz;
  late_mins integer := 0;
  worked_mins integer;
begin
  if p_status not in ('present','absent','on_leave','half_day','holiday','week_off') then
    raise exception 'Invalid attendance status';
  end if;

  select * into emp from public.employees where id = p_employee_id;
  if not found then raise exception 'Employee not found'; end if;
  if not public.can_manage_hr_employee(emp.id) then
    raise exception 'Not authorized to manage attendance for this employee';
  end if;

  select * into fac from public.factories where id = emp.primary_factory_id;
  if emp.shift_id is not null then
    select * into sh from public.shifts where id = emp.shift_id;
  end if;

  if p_status in ('absent','on_leave','holiday','week_off') then
    effective_check_in := null;
    p_check_out_at := null;
    late_mins := 0;
    worked_mins := null;
  else
    effective_check_in := p_check_in_at;
    if effective_check_in is null then
      if sh.id is not null then
        effective_check_in := (p_work_date + sh.start_time) at time zone fac.timezone;
      elsif p_work_date = (now() at time zone fac.timezone)::date then
        effective_check_in := now();
      end if;
    end if;

    if sh.id is not null and effective_check_in is not null then
      scheduled_start := (p_work_date + sh.start_time) at time zone fac.timezone;
      late_mins := greatest(
        0,
        floor(extract(epoch from (effective_check_in - scheduled_start)) / 60)::integer - sh.grace_minutes
      );
    end if;

    if effective_check_in is not null and p_check_out_at is not null then
      if p_check_out_at < effective_check_in then
        raise exception 'Check-out cannot be before check-in';
      end if;
      worked_mins := floor(extract(epoch from (p_check_out_at - effective_check_in)) / 60)::integer;
    end if;
  end if;

  insert into public.attendance_records (
    organization_id, factory_id, employee_id, shift_id, work_date,
    status, check_in_at, check_out_at, worked_minutes, late_minutes,
    source, notes, created_by, updated_by
  ) values (
    emp.organization_id, emp.primary_factory_id, emp.id, emp.shift_id, p_work_date,
    p_status, effective_check_in, p_check_out_at, worked_mins, late_mins,
    'admin', nullif(trim(coalesce(p_notes,'')), ''), auth.uid(), auth.uid()
  )
  on conflict (employee_id, work_date) do update set
    status = excluded.status,
    check_in_at = excluded.check_in_at,
    check_out_at = excluded.check_out_at,
    worked_minutes = excluded.worked_minutes,
    late_minutes = excluded.late_minutes,
    source = 'admin',
    notes = excluded.notes,
    updated_by = auth.uid();

  return (
    select to_jsonb(ar)
    from public.attendance_records ar
    where ar.employee_id = emp.id and ar.work_date = p_work_date
  );
end;
$$;

grant execute on function public.admin_set_attendance(uuid, date, text, timestamptz, timestamptz, text) to authenticated;

create or replace function public.hr_headcount_report(
  p_organization_id uuid,
  p_factory_id uuid default null
)
returns table (
  department_name text,
  active_employees bigint,
  full_time bigint,
  contract bigint,
  temporary bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not (
    public.is_platform_owner()
    or public.has_org_role(p_organization_id, array['org_admin']::public.app_role[])
    or (p_factory_id is not null and public.can_manage_factory(p_factory_id))
  ) then
    raise exception 'Not authorized to run HR report';
  end if;

  return query
  select
    coalesce(d.name, 'Unassigned') as department_name,
    count(*) filter (where e.status = 'active') as active_employees,
    count(*) filter (where e.status = 'active' and e.employment_type = 'full_time') as full_time,
    count(*) filter (where e.status = 'active' and e.employment_type = 'contract') as contract,
    count(*) filter (where e.status = 'active' and e.employment_type = 'temporary') as temporary
  from public.employees e
  left join public.departments d on d.id = e.department_id
  where e.organization_id = p_organization_id
    and (p_factory_id is null or e.primary_factory_id = p_factory_id)
  group by d.name
  order by department_name;
end;
$$;

grant execute on function public.hr_headcount_report(uuid, uuid) to authenticated;

create or replace function public.hr_leave_report(
  p_organization_id uuid,
  p_factory_id uuid,
  p_from date,
  p_to date
)
returns table (
  employee_code text,
  employee_name text,
  leave_type text,
  start_date date,
  end_date date,
  requested_days numeric,
  request_status text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_to < p_from then raise exception 'Invalid date range'; end if;
  if p_to - p_from > 366 then raise exception 'Report range cannot exceed 366 days'; end if;
  if not (
    public.is_platform_owner()
    or public.has_org_role(p_organization_id, array['org_admin']::public.app_role[])
    or (p_factory_id is not null and public.can_manage_factory(p_factory_id))
  ) then
    raise exception 'Not authorized to run HR report';
  end if;

  return query
  select e.employee_code, e.full_name, lt.name, lr.start_date, lr.end_date,
         lr.requested_days, lr.status
  from public.leave_requests lr
  join public.employees e on e.id = lr.employee_id
  join public.leave_types lt on lt.id = lr.leave_type_id
  where lr.organization_id = p_organization_id
    and (p_factory_id is null or e.primary_factory_id = p_factory_id)
    and lr.start_date <= p_to
    and lr.end_date >= p_from
  order by lr.start_date desc, e.full_name;
end;
$$;

grant execute on function public.hr_leave_report(uuid, uuid, date, date) to authenticated;

commit;
