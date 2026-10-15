begin;

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 100),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (id, organization_id)
);

create table public.designations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  department_id uuid,
  name text not null check (char_length(trim(name)) between 2 and 100),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (id, organization_id),
  foreign key (department_id, organization_id)
    references public.departments(id, organization_id) on delete restrict
);

create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid,
  name text not null check (char_length(trim(name)) between 2 and 80),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  start_time time not null,
  end_time time not null,
  crosses_midnight boolean not null default false,
  grace_minutes integer not null default 10 check (grace_minutes between 0 and 180),
  half_day_after_minutes integer not null default 240 check (half_day_after_minutes between 60 and 720),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (id, organization_id),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict
);

create table public.employees (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  employee_code text not null check (employee_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  full_name text not null check (char_length(trim(full_name)) between 2 and 120),
  email text,
  phone text,
  primary_factory_id uuid not null,
  department_id uuid,
  designation_id uuid,
  shift_id uuid,
  manager_employee_id uuid references public.employees(id) on delete set null,
  join_date date not null default current_date,
  exit_date date,
  employment_type text not null default 'full_time' check (employment_type in ('full_time','part_time','contract','temporary','intern')),
  status text not null default 'active' check (status in ('active','inactive','on_notice','exited')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, employee_code),
  unique (id, organization_id),
  foreign key (primary_factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict,
  foreign key (department_id, organization_id)
    references public.departments(id, organization_id) on delete restrict,
  foreign key (designation_id, organization_id)
    references public.designations(id, organization_id) on delete restrict,
  foreign key (shift_id, organization_id)
    references public.shifts(id, organization_id) on delete restrict,
  check (exit_date is null or exit_date >= join_date)
);

create unique index employees_org_user_unique
  on public.employees (organization_id, user_id)
  where user_id is not null;
create index employees_factory_status_idx on public.employees(primary_factory_id, status);
create index employees_department_idx on public.employees(department_id) where status = 'active';

create table public.leave_types (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  is_paid boolean not null default true,
  max_days_per_year numeric(6,2) check (max_days_per_year is null or max_days_per_year >= 0),
  requires_approval boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (id, organization_id)
);

create table public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id uuid not null,
  leave_type_id uuid not null,
  start_date date not null,
  end_date date not null,
  requested_days numeric(6,2) not null check (requested_days > 0),
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  approver_user_id uuid references auth.users(id) on delete set null,
  decision_note text,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (employee_id, organization_id)
    references public.employees(id, organization_id) on delete restrict,
  foreign key (leave_type_id, organization_id)
    references public.leave_types(id, organization_id) on delete restrict,
  check (end_date >= start_date)
);
create index leave_requests_employee_idx on public.leave_requests(employee_id, start_date desc);
create index leave_requests_org_status_idx on public.leave_requests(organization_id, status, start_date);

create table public.holidays (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid,
  holiday_date date not null,
  name text not null check (char_length(trim(name)) between 2 and 100),
  holiday_type text not null default 'company' check (holiday_type in ('national','state','festival','company','optional')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete cascade
);
create unique index holidays_scope_date_name_unique on public.holidays(organization_id, coalesce(factory_id, '00000000-0000-0000-0000-000000000000'::uuid), holiday_date, name);
create index holidays_date_idx on public.holidays(organization_id, holiday_date) where is_active;

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid not null,
  employee_id uuid not null,
  shift_id uuid,
  work_date date not null,
  status text not null default 'present' check (status in ('present','absent','on_leave','half_day','holiday','week_off')),
  check_in_at timestamptz,
  check_out_at timestamptz,
  worked_minutes integer check (worked_minutes is null or worked_minutes >= 0),
  late_minutes integer not null default 0 check (late_minutes >= 0),
  source text not null default 'admin' check (source in ('self','admin','system','import')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (employee_id, work_date),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict,
  foreign key (employee_id, organization_id)
    references public.employees(id, organization_id) on delete restrict,
  foreign key (shift_id, organization_id)
    references public.shifts(id, organization_id) on delete restrict,
  check (check_out_at is null or check_in_at is null or check_out_at >= check_in_at)
);
create index attendance_factory_date_idx on public.attendance_records(factory_id, work_date desc);
create index attendance_employee_date_idx on public.attendance_records(employee_id, work_date desc);

create trigger departments_set_updated_at before update on public.departments for each row execute function public.set_updated_at();
create trigger designations_set_updated_at before update on public.designations for each row execute function public.set_updated_at();
create trigger shifts_set_updated_at before update on public.shifts for each row execute function public.set_updated_at();
create trigger employees_set_updated_at before update on public.employees for each row execute function public.set_updated_at();
create trigger leave_types_set_updated_at before update on public.leave_types for each row execute function public.set_updated_at();
create trigger leave_requests_set_updated_at before update on public.leave_requests for each row execute function public.set_updated_at();
create trigger holidays_set_updated_at before update on public.holidays for each row execute function public.set_updated_at();
create trigger attendance_records_set_updated_at before update on public.attendance_records for each row execute function public.set_updated_at();

create or replace function public.is_hr_employee_self(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.employees e
    join public.organization_members om
      on om.organization_id = e.organization_id
     and om.user_id = auth.uid()
     and om.is_active
    where e.id = target_employee_id
      and e.user_id = auth.uid()
      and e.status = 'active'
  );
$$;

create or replace function public.can_view_hr_employee(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
    or public.is_hr_employee_self(target_employee_id)
    or exists (
      select 1
      from public.employees e
      join public.organization_members om
        on om.organization_id = e.organization_id
       and om.user_id = auth.uid()
       and om.is_active
      left join public.factory_members fm
        on fm.organization_id = e.organization_id
       and fm.factory_id = e.primary_factory_id
       and fm.user_id = auth.uid()
       and fm.is_active
      where e.id = target_employee_id
        and (
          om.role = 'org_admin'
          or (om.role in ('factory_manager','supervisor') and fm.id is not null)
        )
    );
$$;

create or replace function public.can_manage_hr_employee(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
    or exists (
      select 1
      from public.employees e
      join public.organization_members om
        on om.organization_id = e.organization_id
       and om.user_id = auth.uid()
       and om.is_active
      left join public.factory_members fm
        on fm.organization_id = e.organization_id
       and fm.factory_id = e.primary_factory_id
       and fm.user_id = auth.uid()
       and fm.is_active
      where e.id = target_employee_id
        and (om.role = 'org_admin' or (om.role = 'factory_manager' and fm.id is not null))
    );
$$;

grant execute on function public.is_hr_employee_self(uuid) to authenticated;
grant execute on function public.can_view_hr_employee(uuid) to authenticated;
grant execute on function public.can_manage_hr_employee(uuid) to authenticated;

alter table public.departments enable row level security;
alter table public.designations enable row level security;
alter table public.shifts enable row level security;
alter table public.employees enable row level security;
alter table public.leave_types enable row level security;
alter table public.leave_requests enable row level security;
alter table public.holidays enable row level security;
alter table public.attendance_records enable row level security;

grant select, insert, update on public.departments to authenticated;
grant select, insert, update on public.designations to authenticated;
grant select, insert, update on public.shifts to authenticated;
grant select, insert, update on public.employees to authenticated;
grant select, insert, update on public.leave_types to authenticated;
grant select, insert, update on public.leave_requests to authenticated;
grant select, insert, update on public.holidays to authenticated;
grant select, insert, update on public.attendance_records to authenticated;

create policy departments_select on public.departments for select to authenticated
using (public.is_org_member(organization_id));
create policy departments_manage on public.departments for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy designations_select on public.designations for select to authenticated
using (public.is_org_member(organization_id));
create policy designations_manage on public.designations for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy shifts_select on public.shifts for select to authenticated
using (public.is_org_member(organization_id));
create policy shifts_manage on public.shifts for all to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or (factory_id is not null and public.can_manage_factory(factory_id))
)
with check (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or (factory_id is not null and public.can_manage_factory(factory_id))
);

create policy employees_select on public.employees for select to authenticated
using (public.can_view_hr_employee(id));
create policy employees_insert on public.employees for insert to authenticated
with check (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or public.can_manage_factory(primary_factory_id)
);
create policy employees_update on public.employees for update to authenticated
using (public.can_manage_hr_employee(id))
with check (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or public.can_manage_factory(primary_factory_id)
);

create policy leave_types_select on public.leave_types for select to authenticated
using (public.is_org_member(organization_id));
create policy leave_types_manage on public.leave_types for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy leave_requests_select on public.leave_requests for select to authenticated
using (public.can_view_hr_employee(employee_id));
create policy leave_requests_insert on public.leave_requests for insert to authenticated
with check (public.is_hr_employee_self(employee_id) or public.can_manage_hr_employee(employee_id));
create policy leave_requests_update on public.leave_requests for update to authenticated
using (public.can_manage_hr_employee(employee_id))
with check (public.can_manage_hr_employee(employee_id));

create policy holidays_select on public.holidays for select to authenticated
using (public.is_org_member(organization_id));
create policy holidays_manage on public.holidays for all to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or (factory_id is not null and public.can_manage_factory(factory_id))
)
with check (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or (factory_id is not null and public.can_manage_factory(factory_id))
);

create policy attendance_select on public.attendance_records for select to authenticated
using (public.can_view_hr_employee(employee_id));
create policy attendance_insert on public.attendance_records for insert to authenticated
with check (public.can_manage_hr_employee(employee_id));
create policy attendance_update on public.attendance_records for update to authenticated
using (public.can_manage_hr_employee(employee_id))
with check (public.can_manage_hr_employee(employee_id));

create or replace function public.my_employee_record()
returns table (
  employee_id uuid,
  organization_id uuid,
  employee_code text,
  full_name text,
  factory_id uuid,
  factory_name text,
  department_name text,
  designation_name text,
  shift_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select e.id, e.organization_id, e.employee_code, e.full_name,
         e.primary_factory_id, f.name, d.name, des.name, s.name
  from public.employees e
  join public.factories f on f.id = e.primary_factory_id
  left join public.departments d on d.id = e.department_id
  left join public.designations des on des.id = e.designation_id
  left join public.shifts s on s.id = e.shift_id
  where e.user_id = auth.uid() and e.status = 'active'
  order by e.created_at
  limit 1;
$$;
grant execute on function public.my_employee_record() to authenticated;

create or replace function public.mark_my_attendance(p_action text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  emp public.employees%rowtype;
  fac public.factories%rowtype;
  existing public.attendance_records%rowtype;
  local_date date;
  now_ts timestamptz := now();
  start_ts timestamptz;
  late_mins integer := 0;
begin
  select * into emp from public.employees
  where user_id = auth.uid() and status = 'active'
  order by created_at limit 1;
  if not found then raise exception 'No active employee profile is linked to this account'; end if;

  select * into fac from public.factories where id = emp.primary_factory_id and is_active;
  if not found then raise exception 'Assigned factory is inactive'; end if;
  local_date := (now_ts at time zone fac.timezone)::date;

  select * into existing from public.attendance_records
  where employee_id = emp.id and work_date = local_date
  for update;

  if p_action = 'check_in' then
    if found and existing.check_in_at is not null then raise exception 'Already checked in today'; end if;
    if emp.shift_id is not null then
      select (local_date + s.start_time) at time zone fac.timezone
        into start_ts from public.shifts s where s.id = emp.shift_id;
      late_mins := greatest(0, floor(extract(epoch from (now_ts - start_ts)) / 60)::integer);
    end if;
    insert into public.attendance_records (
      organization_id, factory_id, employee_id, shift_id, work_date,
      status, check_in_at, late_minutes, source, created_by, updated_by
    ) values (
      emp.organization_id, emp.primary_factory_id, emp.id, emp.shift_id, local_date,
      'present', now_ts, late_mins, 'self', auth.uid(), auth.uid()
    )
    on conflict (employee_id, work_date) do update set
      check_in_at = coalesce(public.attendance_records.check_in_at, excluded.check_in_at),
      status = 'present', late_minutes = excluded.late_minutes,
      source = 'self', updated_by = auth.uid();
  elsif p_action = 'check_out' then
    if not found or existing.check_in_at is null then raise exception 'Check in before checking out'; end if;
    if existing.check_out_at is not null then raise exception 'Already checked out today'; end if;
    update public.attendance_records
      set check_out_at = now_ts,
          worked_minutes = greatest(0, floor(extract(epoch from (now_ts - existing.check_in_at)) / 60)::integer),
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
    where ar.employee_id = emp.id and ar.work_date = local_date
  );
end;
$$;
grant execute on function public.mark_my_attendance(text) to authenticated;

create or replace function public.request_my_leave(
  p_leave_type_id uuid,
  p_start_date date,
  p_end_date date,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  emp public.employees%rowtype;
  request_id uuid;
  day_count numeric(6,2);
begin
  if p_end_date < p_start_date then raise exception 'End date cannot be before start date'; end if;
  select * into emp from public.employees where user_id = auth.uid() and status = 'active' order by created_at limit 1;
  if not found then raise exception 'No active employee profile is linked to this account'; end if;
  if not exists (select 1 from public.leave_types where id = p_leave_type_id and organization_id = emp.organization_id and is_active) then
    raise exception 'Leave type is unavailable';
  end if;
  if exists (
    select 1 from public.leave_requests lr
    where lr.employee_id = emp.id and lr.status in ('pending','approved')
      and daterange(lr.start_date, lr.end_date, '[]') && daterange(p_start_date, p_end_date, '[]')
  ) then raise exception 'Leave dates overlap an existing request'; end if;

  day_count := (p_end_date - p_start_date + 1)::numeric;
  insert into public.leave_requests (
    organization_id, employee_id, leave_type_id, start_date, end_date, requested_days, reason
  ) values (
    emp.organization_id, emp.id, p_leave_type_id, p_start_date, p_end_date, day_count, nullif(trim(coalesce(p_reason,'')), '')
  ) returning id into request_id;
  return request_id;
end;
$$;
grant execute on function public.request_my_leave(uuid, date, date, text) to authenticated;

create or replace function public.cancel_my_leave(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.leave_requests lr
  set status = 'cancelled', decided_at = now(), decision_note = 'Cancelled by employee'
  where lr.id = p_request_id
    and lr.status = 'pending'
    and public.is_hr_employee_self(lr.employee_id);
  if not found then raise exception 'Pending leave request not found'; end if;
end;
$$;
grant execute on function public.cancel_my_leave(uuid) to authenticated;

create or replace function public.decide_leave_request(
  p_request_id uuid,
  p_decision text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req public.leave_requests%rowtype;
  emp public.employees%rowtype;
  work_day date;
begin
  if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
  select * into req from public.leave_requests where id = p_request_id for update;
  if not found or req.status <> 'pending' then raise exception 'Pending leave request not found'; end if;
  if not public.can_manage_hr_employee(req.employee_id) then raise exception 'Not authorized to decide this leave request'; end if;
  select * into emp from public.employees where id = req.employee_id;

  update public.leave_requests set
    status = p_decision,
    approver_user_id = auth.uid(),
    decision_note = nullif(trim(coalesce(p_note,'')), ''),
    decided_at = now()
  where id = req.id;

  if p_decision = 'approved' then
    for work_day in select generate_series(req.start_date, req.end_date, interval '1 day')::date loop
      insert into public.attendance_records (
        organization_id, factory_id, employee_id, shift_id, work_date, status, source, created_by, updated_by
      ) values (
        emp.organization_id, emp.primary_factory_id, emp.id, emp.shift_id, work_day, 'on_leave', 'system', auth.uid(), auth.uid()
      )
      on conflict (employee_id, work_date) do update set
        status = case when attendance_records.check_in_at is null then 'on_leave' else attendance_records.status end,
        updated_by = auth.uid();
    end loop;
  end if;
end;
$$;
grant execute on function public.decide_leave_request(uuid, text, text) to authenticated;

create or replace function public.hr_dashboard_summary(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_work_date date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  total_count integer;
  present_count integer;
  leave_count integer;
  pending_count integer;
  late_count integer;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Not authorized'; end if;
  if p_factory_id is not null and not exists (
    select 1 from public.factories where id = p_factory_id and organization_id = p_organization_id
  ) then raise exception 'Factory does not belong to organization'; end if;

  select count(*) into total_count from public.employees e
    where e.organization_id = p_organization_id and e.status = 'active'
      and (p_factory_id is null or e.primary_factory_id = p_factory_id)
      and public.can_view_hr_employee(e.id);
  select count(*) into present_count from public.attendance_records ar
    where ar.organization_id = p_organization_id and ar.work_date = p_work_date
      and ar.status in ('present','half_day')
      and (p_factory_id is null or ar.factory_id = p_factory_id)
      and public.can_view_hr_employee(ar.employee_id);
  select count(*) into leave_count from public.attendance_records ar
    where ar.organization_id = p_organization_id and ar.work_date = p_work_date
      and ar.status = 'on_leave'
      and (p_factory_id is null or ar.factory_id = p_factory_id)
      and public.can_view_hr_employee(ar.employee_id);
  select count(*) into pending_count from public.leave_requests lr
    join public.employees e on e.id = lr.employee_id
    where lr.organization_id = p_organization_id and lr.status = 'pending'
      and (p_factory_id is null or e.primary_factory_id = p_factory_id)
      and public.can_view_hr_employee(e.id);
  select count(*) into late_count from public.attendance_records ar
    where ar.organization_id = p_organization_id and ar.work_date = p_work_date and ar.late_minutes > 0
      and (p_factory_id is null or ar.factory_id = p_factory_id)
      and public.can_view_hr_employee(ar.employee_id);

  return jsonb_build_object(
    'employees', total_count,
    'present', present_count,
    'absent', greatest(total_count - present_count - leave_count, 0),
    'on_leave', leave_count,
    'pending_leave', pending_count,
    'late', late_count
  );
end;
$$;
grant execute on function public.hr_dashboard_summary(uuid, uuid, date) to authenticated;

create or replace function public.hr_attendance_report(
  p_organization_id uuid,
  p_factory_id uuid,
  p_from date,
  p_to date
)
returns table (
  employee_code text,
  employee_name text,
  department_name text,
  work_date date,
  attendance_status text,
  check_in_at timestamptz,
  check_out_at timestamptz,
  worked_minutes integer,
  late_minutes integer
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
  ) then raise exception 'Not authorized to run HR report'; end if;

  return query
  select e.employee_code, e.full_name, coalesce(d.name,''), ar.work_date, ar.status,
         ar.check_in_at, ar.check_out_at, ar.worked_minutes, ar.late_minutes
  from public.attendance_records ar
  join public.employees e on e.id = ar.employee_id
  left join public.departments d on d.id = e.department_id
  where ar.organization_id = p_organization_id
    and (p_factory_id is null or ar.factory_id = p_factory_id)
    and ar.work_date between p_from and p_to
  order by ar.work_date desc, e.full_name;
end;
$$;
grant execute on function public.hr_attendance_report(uuid, uuid, date, date) to authenticated;

create or replace function public.audit_hr_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  payload jsonb := case when tg_op = 'INSERT' then to_jsonb(new) when tg_op = 'UPDATE' then jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new)) else to_jsonb(old) end;
  target_org uuid;
  target_factory uuid;
  target_id text;
begin
  target_org := coalesce((payload #>> '{after,organization_id}')::uuid, (payload ->> 'organization_id')::uuid, (payload #>> '{before,organization_id}')::uuid);
  target_factory := coalesce((payload #>> '{after,factory_id}')::uuid, (payload ->> 'factory_id')::uuid, (payload #>> '{before,factory_id}')::uuid,
                             (payload #>> '{after,primary_factory_id}')::uuid, (payload ->> 'primary_factory_id')::uuid, (payload #>> '{before,primary_factory_id}')::uuid);
  target_id := coalesce(payload #>> '{after,id}', payload ->> 'id', payload #>> '{before,id}');
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(target_org,target_factory,auth.uid(),lower(tg_op),tg_table_name,target_id,payload);
  return coalesce(new,old);
end;
$$;
revoke all on function public.audit_hr_change() from public;

create trigger departments_audit after insert or update on public.departments for each row execute function public.audit_hr_change();
create trigger designations_audit after insert or update on public.designations for each row execute function public.audit_hr_change();
create trigger shifts_audit after insert or update on public.shifts for each row execute function public.audit_hr_change();
create trigger employees_audit after insert or update on public.employees for each row execute function public.audit_hr_change();
create trigger leave_types_audit after insert or update on public.leave_types for each row execute function public.audit_hr_change();
create trigger leave_requests_audit after insert or update on public.leave_requests for each row execute function public.audit_hr_change();
create trigger holidays_audit after insert or update on public.holidays for each row execute function public.audit_hr_change();
create trigger attendance_records_audit after insert or update on public.attendance_records for each row execute function public.audit_hr_change();

commit;
