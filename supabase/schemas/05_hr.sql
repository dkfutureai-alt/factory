-- FactoryOS HR, attendance, leave and holiday schema
-- Depends on 01_core.sql.

create type public.employment_status as enum ('active', 'inactive', 'notice_period', 'terminated');
create type public.attendance_day_status as enum ('present', 'late', 'absent', 'leave', 'holiday', 'weekly_off');
create type public.leave_request_status as enum ('draft', 'pending', 'approved', 'rejected', 'cancelled');
create type public.holiday_kind as enum ('mandatory', 'optional', 'plant_closure');

create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  code text not null,
  name text not null,
  start_time time not null,
  end_time time not null,
  late_grace_minutes integer not null default 10 check (late_grace_minutes between 0 and 180),
  break_minutes integer not null default 60 check (break_minutes between 0 and 300),
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shifts_scope_code_unique unique nulls not distinct (organization_id, factory_id, code)
);

create table public.employees (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  department_id uuid references public.departments(id) on delete restrict,
  profile_user_id uuid references public.profiles(user_id) on delete set null,
  shift_id uuid references public.shifts(id) on delete set null,
  employee_code text not null,
  first_name text not null,
  last_name text not null,
  designation text not null,
  employee_type text not null default 'full_time' check (employee_type in ('full_time','contract','trainee','temporary')),
  grade text,
  reports_to_employee_id uuid references public.employees(id) on delete set null,
  joining_date date not null,
  weekly_off smallint not null default 7 check (weekly_off between 1 and 7),
  status public.employment_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, employee_code),
  unique nulls not distinct (organization_id, profile_user_id),
  check (length(btrim(first_name)) > 0),
  check (length(btrim(last_name)) > 0),
  check (length(btrim(designation)) > 0)
);

-- Sensitive HR information is isolated from normal operational employee reads.
create table public.employee_private_details (
  employee_id uuid primary key references public.employees(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  mobile_e164 text,
  emergency_contact_name text,
  emergency_mobile_e164 text,
  bank_account_last4 text check (bank_account_last4 is null or bank_account_last4 ~ '^[0-9]{4}$'),
  tax_id_last4 text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  employee_id uuid not null references public.employees(id) on delete restrict,
  work_date date not null,
  shift_id uuid references public.shifts(id) on delete set null,
  check_in_at timestamptz,
  check_out_at timestamptz,
  status public.attendance_day_status not null,
  worked_minutes integer not null default 0 check (worked_minutes >= 0),
  late_minutes integer not null default 0 check (late_minutes >= 0),
  overtime_minutes integer not null default 0 check (overtime_minutes >= 0),
  source text not null default 'manual' check (source in ('mobile','web','device','manual','import')),
  note text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, employee_id, work_date),
  check (check_out_at is null or check_in_at is null or check_out_at > check_in_at)
);

create table public.attendance_corrections (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  attendance_record_id uuid not null references public.attendance_records(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  requested_check_in_at timestamptz,
  requested_check_out_at timestamptz,
  reason text not null,
  status public.leave_request_status not null default 'pending',
  requested_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(btrim(reason)) > 0)
);

create table public.leave_types (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  annual_quota numeric(8,2) not null default 0 check (annual_quota >= 0),
  is_paid boolean not null default true,
  carry_forward_limit numeric(8,2) not null default 0 check (carry_forward_limit >= 0),
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.leave_balances (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  employee_id uuid not null references public.employees(id) on delete cascade,
  leave_type_id uuid not null references public.leave_types(id) on delete restrict,
  balance_year integer not null check (balance_year between 2000 and 2200),
  allocated_days numeric(8,2) not null default 0 check (allocated_days >= 0),
  used_days numeric(8,2) not null default 0 check (used_days >= 0),
  pending_days numeric(8,2) not null default 0 check (pending_days >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (employee_id, leave_type_id, balance_year),
  check (used_days + pending_days <= allocated_days + 366)
);

create table public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  employee_id uuid not null references public.employees(id) on delete restrict,
  leave_type_id uuid not null references public.leave_types(id) on delete restrict,
  start_date date not null,
  end_date date not null,
  requested_days numeric(8,2) not null check (requested_days > 0),
  reason text,
  status public.leave_request_status not null default 'pending',
  requested_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create table public.holidays (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  holiday_date date not null,
  name text not null,
  kind public.holiday_kind not null default 'mandatory',
  is_paid boolean not null default true,
  applies_to_all_shifts boolean not null default true,
  note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint holidays_scope_date_name_unique unique nulls not distinct (organization_id, factory_id, holiday_date, name),
  check (length(btrim(name)) > 0)
);

create index employees_org_factory_status_idx on public.employees (organization_id, factory_id, status);
create index employees_org_department_idx on public.employees (organization_id, department_id);
create index attendance_org_date_idx on public.attendance_records (organization_id, work_date desc);
create index attendance_employee_date_idx on public.attendance_records (employee_id, work_date desc);
create index leave_requests_org_status_date_idx on public.leave_requests (organization_id, status, start_date);
create index leave_requests_employee_idx on public.leave_requests (employee_id, start_date desc);
create index holidays_org_date_idx on public.holidays (organization_id, holiday_date);

create trigger shifts_set_updated_at before update on public.shifts for each row execute function private.set_updated_at();
create trigger employees_set_updated_at before update on public.employees for each row execute function private.set_updated_at();
create trigger employee_private_set_updated_at before update on public.employee_private_details for each row execute function private.set_updated_at();
create trigger attendance_records_set_updated_at before update on public.attendance_records for each row execute function private.set_updated_at();
create trigger attendance_corrections_set_updated_at before update on public.attendance_corrections for each row execute function private.set_updated_at();
create trigger leave_types_set_updated_at before update on public.leave_types for each row execute function private.set_updated_at();
create trigger leave_balances_set_updated_at before update on public.leave_balances for each row execute function private.set_updated_at();
create trigger leave_requests_set_updated_at before update on public.leave_requests for each row execute function private.set_updated_at();
create trigger holidays_set_updated_at before update on public.holidays for each row execute function private.set_updated_at();

-- Tenant/reference validation for employee-linked HR rows.
create or replace function private.validate_hr_employee_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  employee_org uuid;
  employee_factory uuid;
begin
  select organization_id, factory_id into employee_org, employee_factory
  from public.employees where id = new.employee_id;
  if employee_org is null then raise exception 'employee not found'; end if;
  if new.organization_id <> employee_org then raise exception 'HR row organization mismatch'; end if;
  if to_jsonb(new) ? 'factory_id' and new.factory_id is distinct from employee_factory then
    raise exception 'HR row factory mismatch';
  end if;
  return new;
end;
$$;

create trigger attendance_validate_scope before insert or update on public.attendance_records for each row execute function private.validate_hr_employee_scope();
create trigger leave_requests_validate_scope before insert or update on public.leave_requests for each row execute function private.validate_hr_employee_scope();

create or replace function private.validate_employee_private_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare employee_org uuid;
begin
  select organization_id into employee_org from public.employees where id = new.employee_id;
  if employee_org is null or employee_org <> new.organization_id then raise exception 'private employee scope mismatch'; end if;
  return new;
end;
$$;
create trigger employee_private_validate_scope before insert or update on public.employee_private_details for each row execute function private.validate_employee_private_scope();

alter table public.shifts enable row level security;
alter table public.employees enable row level security;
alter table public.employee_private_details enable row level security;
alter table public.attendance_records enable row level security;
alter table public.attendance_corrections enable row level security;
alter table public.leave_types enable row level security;
alter table public.leave_balances enable row level security;
alter table public.leave_requests enable row level security;
alter table public.holidays enable row level security;

create policy shifts_read on public.shifts for select to authenticated
using ((select private.is_org_member(organization_id)));
create policy shifts_manage on public.shifts for all to authenticated
using ((select private.has_permission(organization_id, 'attendance.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'attendance.manage', factory_id)));

create policy employees_read on public.employees for select to authenticated
using (
  profile_user_id = (select auth.uid())
  or (select private.has_permission(organization_id, 'employee.read', factory_id))
);
create policy employees_insert on public.employees for insert to authenticated
with check ((select private.has_permission(organization_id, 'employee.create', factory_id)));
create policy employees_update on public.employees for update to authenticated
using ((select private.has_permission(organization_id, 'employee.update', factory_id)))
with check ((select private.has_permission(organization_id, 'employee.update', factory_id)));

create policy employee_private_read on public.employee_private_details for select to authenticated
using (
  exists (select 1 from public.employees e where e.id = employee_id and e.profile_user_id = (select auth.uid()))
  or (select private.has_permission(organization_id, 'employee.sensitive.read', null))
);
create policy employee_private_manage on public.employee_private_details for all to authenticated
using ((select private.has_permission(organization_id, 'employee.sensitive.manage', null)))
with check ((select private.has_permission(organization_id, 'employee.sensitive.manage', null)));

create policy attendance_read on public.attendance_records for select to authenticated
using (
  exists (select 1 from public.employees e where e.id = employee_id and e.profile_user_id = (select auth.uid()))
  or (select private.has_permission(organization_id, 'attendance.read', factory_id))
);
create policy attendance_self_insert on public.attendance_records for insert to authenticated
with check (
  (select private.has_permission(organization_id, 'attendance.self_checkin', factory_id))
  and exists (select 1 from public.employees e where e.id = employee_id and e.profile_user_id = (select auth.uid()))
);
create policy attendance_manage on public.attendance_records for all to authenticated
using ((select private.has_permission(organization_id, 'attendance.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'attendance.manage', factory_id)));

create policy attendance_corrections_read on public.attendance_corrections for select to authenticated
using (
  exists (select 1 from public.employees e where e.id = employee_id and e.profile_user_id = (select auth.uid()))
  or (select private.has_permission(organization_id, 'attendance.manage', null))
);
create policy attendance_corrections_self_insert on public.attendance_corrections for insert to authenticated
with check (
  requested_by = (select auth.uid())
  and exists (select 1 from public.employees e where e.id = employee_id and e.profile_user_id = (select auth.uid()))
);
create policy attendance_corrections_manage on public.attendance_corrections for update to authenticated
using ((select private.has_permission(organization_id, 'attendance.manage', null)))
with check ((select private.has_permission(organization_id, 'attendance.manage', null)));

create policy leave_types_read on public.leave_types for select to authenticated
using ((select private.is_org_member(organization_id)));
create policy leave_types_manage on public.leave_types for all to authenticated
using ((select private.has_permission(organization_id, 'leave.manage', null)))
with check ((select private.has_permission(organization_id, 'leave.manage', null)));

create policy leave_balances_read on public.leave_balances for select to authenticated
using (
  exists (select 1 from public.employees e where e.id = employee_id and e.profile_user_id = (select auth.uid()))
  or (select private.has_permission(organization_id, 'leave.read', null))
);
create policy leave_balances_manage on public.leave_balances for all to authenticated
using ((select private.has_permission(organization_id, 'leave.manage', null)))
with check ((select private.has_permission(organization_id, 'leave.manage', null)));

create policy leave_requests_read on public.leave_requests for select to authenticated
using (
  exists (select 1 from public.employees e where e.id = employee_id and e.profile_user_id = (select auth.uid()))
  or (select private.has_permission(organization_id, 'leave.read', factory_id))
);
create policy leave_requests_self_insert on public.leave_requests for insert to authenticated
with check (
  (select private.has_permission(organization_id, 'leave.self_create', factory_id))
  and requested_by = (select auth.uid())
  and exists (select 1 from public.employees e where e.id = employee_id and e.profile_user_id = (select auth.uid()))
  and status in ('draft','pending')
);
create policy leave_requests_approve on public.leave_requests for update to authenticated
using ((select private.has_permission(organization_id, 'leave.approve', factory_id)))
with check ((select private.has_permission(organization_id, 'leave.approve', factory_id)));

create policy holidays_read on public.holidays for select to authenticated
using ((select private.is_org_member(organization_id)));
create policy holidays_manage on public.holidays for all to authenticated
using ((select private.has_permission(organization_id, 'holiday.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'holiday.manage', factory_id)));

grant select, insert, update on public.shifts to authenticated;
grant select, insert, update on public.employees to authenticated;
grant select, insert, update on public.employee_private_details to authenticated;
grant select, insert, update on public.attendance_records to authenticated;
grant select, insert, update on public.attendance_corrections to authenticated;
grant select, insert, update on public.leave_types to authenticated;
grant select, insert, update on public.leave_balances to authenticated;
grant select, insert, update on public.leave_requests to authenticated;
grant select, insert, update on public.holidays to authenticated;
