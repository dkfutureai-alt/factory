begin;

alter table public.employees
  drop constraint if exists employees_manager_same_organization_fk;

alter table public.employees
  add constraint employees_manager_same_organization_fk
  foreign key (manager_employee_id, organization_id)
  references public.employees(id, organization_id)
  on delete restrict;

create or replace function public.validate_employee_hr_scope()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  shift_factory uuid;
  designation_department uuid;
  linked_role public.app_role;
begin
  if new.shift_id is not null then
    select factory_id into shift_factory
    from public.shifts
    where id = new.shift_id and organization_id = new.organization_id;
    if shift_factory is not null and shift_factory <> new.primary_factory_id then
      raise exception 'Employee shift belongs to a different factory';
    end if;
  end if;

  if new.designation_id is not null and new.department_id is not null then
    select department_id into designation_department
    from public.designations
    where id = new.designation_id and organization_id = new.organization_id;
    if designation_department is not null and designation_department <> new.department_id then
      raise exception 'Employee designation belongs to a different department';
    end if;
  end if;

  if new.user_id is not null then
    select role into linked_role
    from public.organization_members
    where organization_id = new.organization_id
      and user_id = new.user_id
      and is_active
    limit 1;

    if linked_role is null then
      raise exception 'Linked FactoryOS user is not an active organization member';
    end if;

    if linked_role not in ('org_admin') and not exists (
      select 1
      from public.factory_members fm
      where fm.organization_id = new.organization_id
        and fm.factory_id = new.primary_factory_id
        and fm.user_id = new.user_id
        and fm.is_active
    ) then
      raise exception 'Linked FactoryOS user is not assigned to the employee factory';
    end if;
  end if;

  return new;
end;
$$;

-- Employee self-service leave creation is intentionally RPC-only so clients cannot
-- spoof requested_days or bypass overlap validation with direct table inserts.
drop policy if exists leave_requests_insert on public.leave_requests;
create policy leave_requests_insert on public.leave_requests
for insert to authenticated
with check (public.can_manage_hr_employee(employee_id));

commit;
