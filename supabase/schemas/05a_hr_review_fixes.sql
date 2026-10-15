-- HR pre-deployment review fixes.
-- Applies after 05_hr.sql.

-- Optional linked auth profile must be unique only when present; many employees may be unlinked.
alter table public.employees drop constraint if exists employees_organization_id_profile_user_id_key;
create unique index if not exists employees_org_profile_user_unique_idx
  on public.employees (organization_id, profile_user_id)
  where profile_user_id is not null;

-- Leave balance cannot represent more used + pending days than allocated.
alter table public.leave_balances drop constraint if exists leave_balances_check;
alter table public.leave_balances add constraint leave_balances_within_allocation
  check (used_days + pending_days <= allocated_days);

-- Validate organization/factory/department/shift/manager references on employee rows.
create or replace function private.validate_employee_references()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  ref_org uuid;
  ref_factory uuid;
begin
  if new.factory_id is not null then
    select organization_id into ref_org from public.factories where id = new.factory_id;
    if ref_org is distinct from new.organization_id then raise exception 'employee factory organization mismatch'; end if;
  end if;

  if new.department_id is not null then
    select organization_id, factory_id into ref_org, ref_factory from public.departments where id = new.department_id;
    if ref_org is distinct from new.organization_id or ref_factory is distinct from new.factory_id then
      raise exception 'employee department scope mismatch';
    end if;
  end if;

  if new.shift_id is not null then
    select organization_id, factory_id into ref_org, ref_factory from public.shifts where id = new.shift_id;
    if ref_org is distinct from new.organization_id or ref_factory is distinct from new.factory_id then
      raise exception 'employee shift scope mismatch';
    end if;
  end if;

  if new.reports_to_employee_id is not null then
    select organization_id into ref_org from public.employees where id = new.reports_to_employee_id;
    if ref_org is distinct from new.organization_id then raise exception 'employee manager organization mismatch'; end if;
    if new.reports_to_employee_id = new.id then raise exception 'employee cannot report to self'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists employees_validate_refs on public.employees;
create trigger employees_validate_refs
before insert or update on public.employees
for each row execute function private.validate_employee_references();

-- Factory-scoped employee rows must remain in the employee's organization/factory.
create or replace function private.validate_hr_employee_factory_scope()
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
  if new.factory_id is distinct from employee_factory then raise exception 'HR row factory mismatch'; end if;
  return new;
end;
$$;

drop trigger if exists attendance_validate_scope on public.attendance_records;
create trigger attendance_validate_scope before insert or update on public.attendance_records
for each row execute function private.validate_hr_employee_factory_scope();

drop trigger if exists leave_requests_validate_scope on public.leave_requests;
create trigger leave_requests_validate_scope before insert or update on public.leave_requests
for each row execute function private.validate_hr_employee_factory_scope();

-- Organization-only employee-linked HR rows still require matching tenant references.
create or replace function private.validate_hr_employee_org_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare employee_org uuid;
begin
  select organization_id into employee_org from public.employees where id = new.employee_id;
  if employee_org is null or employee_org <> new.organization_id then raise exception 'HR employee organization mismatch'; end if;
  return new;
end;
$$;

drop trigger if exists employee_private_validate_scope on public.employee_private_details;
create trigger employee_private_validate_scope before insert or update on public.employee_private_details
for each row execute function private.validate_hr_employee_org_scope();

create trigger leave_balances_validate_scope before insert or update on public.leave_balances
for each row execute function private.validate_hr_employee_org_scope();

create trigger attendance_corrections_validate_scope before insert or update on public.attendance_corrections
for each row execute function private.validate_hr_employee_org_scope();

-- Leave type references must belong to the same tenant as balances/requests.
create or replace function private.validate_leave_type_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare leave_org uuid;
begin
  select organization_id into leave_org from public.leave_types where id = new.leave_type_id;
  if leave_org is null or leave_org <> new.organization_id then raise exception 'leave type organization mismatch'; end if;
  return new;
end;
$$;

create trigger leave_balances_validate_leave_type before insert or update on public.leave_balances
for each row execute function private.validate_leave_type_scope();
create trigger leave_requests_validate_leave_type before insert or update on public.leave_requests
for each row execute function private.validate_leave_type_scope();

-- Attendance correction must point to an attendance record for the same employee and organization.
create or replace function private.validate_attendance_correction_reference()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare attendance_org uuid; attendance_employee uuid;
begin
  select organization_id, employee_id into attendance_org, attendance_employee
  from public.attendance_records where id = new.attendance_record_id;
  if attendance_org is null or attendance_org <> new.organization_id or attendance_employee <> new.employee_id then
    raise exception 'attendance correction reference mismatch';
  end if;
  return new;
end;
$$;

create trigger attendance_corrections_validate_attendance before insert or update on public.attendance_corrections
for each row execute function private.validate_attendance_correction_reference();
