-- FactoryOS HR demo seed
-- Depends on 01_core.sql, 05_hr.sql and 01_demo_foundation.sql.
-- All people below are fictional demo data. Protected contact/banking fields are intentionally not seeded.

insert into public.permissions (key, module_key, description)
values
  ('employee.sensitive.read', 'hr', 'Read protected employee contact/private HR details'),
  ('employee.sensitive.manage', 'hr', 'Manage protected employee contact/private HR details'),
  ('leave.read', 'hr', 'Read organization leave records'),
  ('leave.manage', 'hr', 'Manage leave types and balances'),
  ('holiday.manage', 'hr', 'Manage organization and factory holidays')
on conflict (key) do update set module_key = excluded.module_key, description = excluded.description;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id = r.organization_id and o.code = 'DKIM'
join public.permissions p on (
  r.key = 'company_owner'
  or (r.key = 'hr_manager' and p.key = any(array['employee.sensitive.read','employee.sensitive.manage','leave.read','leave.manage','holiday.manage']))
  or (r.key = 'factory_manager' and p.key = any(array['leave.read']))
)
where p.key = any(array['employee.sensitive.read','employee.sensitive.manage','leave.read','leave.manage','holiday.manage'])
on conflict do nothing;

insert into public.shifts (organization_id, factory_id, code, name, start_time, end_time, late_grace_minutes, break_minutes)
select o.id, f.id, v.code, v.name, v.start_time, v.end_time, 10, 60
from public.organizations o
join public.factories f on f.organization_id = o.id and f.code = 'PLANT-01'
cross join (values
  ('MORN','Morning Shift','09:00'::time,'18:00'::time),
  ('QC','Quality Shift','08:30'::time,'17:30'::time),
  ('SALES','Sales Shift','09:30'::time,'18:30'::time)
) v(code,name,start_time,end_time)
where o.code = 'DKIM'
on conflict (organization_id,factory_id,code) do update set name=excluded.name,start_time=excluded.start_time,end_time=excluded.end_time;

insert into public.employees (
  organization_id,factory_id,department_id,shift_id,employee_code,first_name,last_name,designation,employee_type,grade,joining_date,status
)
select o.id,f.id,d.id,s.id,v.code,v.first_name,v.last_name,v.designation,'full_time',v.grade,v.joining_date,'active'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join (values
  ('EMP-0018','Ravi','Patil','PROD','MORN','Production Operator','OP-2','2025-02-03'::date),
  ('EMP-0007','Sneha','Kulkarni','QC','QC','Quality Inspector','QC-2','2024-08-12'::date),
  ('EMP-0024','Akash','More','WH','MORN','Warehouse Associate','WH-2','2025-05-21'::date),
  ('EMP-0032','Meera','Jadhav','SAL','SALES','Sales Coordinator','SAL-2','2024-11-18'::date),
  ('EMP-0011','Priya','Shinde','HR','MORN','HR Executive','HR-2','2025-01-06'::date),
  ('EMP-0029','Sunil','Pawar','MNT','MORN','Maintenance Technician','MNT-2','2024-06-10'::date)
) v(code,first_name,last_name,department_code,shift_code,designation,grade,joining_date) on true
join public.departments d on d.organization_id=o.id and d.factory_id=f.id and d.code=v.department_code
join public.shifts s on s.organization_id=o.id and s.factory_id=f.id and s.code=v.shift_code
where o.code='DKIM'
on conflict (organization_id,employee_code) do update set
  first_name=excluded.first_name,last_name=excluded.last_name,department_id=excluded.department_id,shift_id=excluded.shift_id,
  designation=excluded.designation,grade=excluded.grade,joining_date=excluded.joining_date,status=excluded.status;

with people(first_name,last_name,ordinal) as (
  select * from unnest(
    array['Aarav','Aditya','Aniket','Arjun','Darshan','Devendra','Ganesh','Harshad','Kiran','Mahesh','Manoj','Nikhil','Nitin','Omkar','Prasad','Rahul','Rohan','Sachin','Sagar','Sameer','Sanket','Shubham','Swapnil','Vikas','Yogesh','Aditi','Anjali','Bhavna','Kavita','Neha','Pooja','Rutuja','Sayali','Vaishnavi'],
    array['Joshi','Deshmukh','Kale','Sawant','Bhosale','Gaikwad','Mane','Chavan','Shinde','Patil','Jadhav','Pawar','More','Kulkarni','Kadam','Wagh','Shah','Naik','Salunkhe','Raut','Gore','Sutar','Londhe','Thorat','Gavhane','Khot','Ghadge','Nale','Babar','Dhumal','Kore','Jagtap','Rane','Mohite']
  ) with ordinality
)
insert into public.employees (
  organization_id,factory_id,department_id,shift_id,employee_code,first_name,last_name,designation,employee_type,grade,joining_date,status
)
select o.id,f.id,d.id,s.id,'DEMO-'||lpad(p.ordinal::text,3,'0'),p.first_name,p.last_name,
       case d.code when 'PROD' then 'Production Associate' when 'WH' then 'Warehouse Associate' when 'QC' then 'Quality Associate' when 'MNT' then 'Maintenance Associate' else 'Operations Associate' end,
       'full_time','L1',date '2025-01-01' + p.ordinal::integer,'active'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join people p on true
join public.departments d on d.organization_id=o.id and d.factory_id=f.id and d.code = case
  when p.ordinal <= 14 then 'PROD'
  when p.ordinal <= 21 then 'WH'
  when p.ordinal <= 26 then 'QC'
  when p.ordinal <= 30 then 'MNT'
  else 'ADM' end
join public.shifts s on s.organization_id=o.id and s.factory_id=f.id and s.code='MORN'
where o.code='DKIM'
on conflict (organization_id,employee_code) do update set first_name=excluded.first_name,last_name=excluded.last_name,department_id=excluded.department_id,shift_id=excluded.shift_id,status='active';

insert into public.leave_types (organization_id,code,name,annual_quota,is_paid,carry_forward_limit)
select o.id,v.code,v.name,v.quota,true,v.carry
from public.organizations o
cross join (values ('CL','Casual Leave',8::numeric,0::numeric),('SL','Sick Leave',6::numeric,0::numeric),('PL','Paid Leave',12::numeric,5::numeric)) v(code,name,quota,carry)
where o.code='DKIM'
on conflict (organization_id,code) do update set name=excluded.name,annual_quota=excluded.annual_quota,is_paid=excluded.is_paid,carry_forward_limit=excluded.carry_forward_limit;

insert into public.leave_balances (organization_id,employee_id,leave_type_id,balance_year,allocated_days,used_days,pending_days)
select e.organization_id,e.id,lt.id,2026,lt.annual_quota,
       case when e.employee_code='EMP-0018' and lt.code='CL' then 3 when e.employee_code='EMP-0018' and lt.code='SL' then 2 when e.employee_code='EMP-0018' and lt.code='PL' then 4 else 0 end,
       0
from public.employees e
join public.organizations o on o.id=e.organization_id and o.code='DKIM'
join public.leave_types lt on lt.organization_id=o.id
on conflict (employee_id,leave_type_id,balance_year) do update set allocated_days=excluded.allocated_days,used_days=excluded.used_days,pending_days=excluded.pending_days;

insert into public.attendance_records (
  organization_id,factory_id,employee_id,work_date,shift_id,check_in_at,status,worked_minutes,late_minutes,overtime_minutes,source,note
)
select e.organization_id,e.factory_id,e.id,date '2026-10-14',e.shift_id,
       case
         when e.employee_code='EMP-0032' then null
         when e.employee_code='EMP-0024' then '2026-10-14 09:18+05:30'::timestamptz
         when e.employee_code='DEMO-034' then '2026-10-14 09:16+05:30'::timestamptz
         when e.employee_code='EMP-0007' then '2026-10-14 08:54+05:30'::timestamptz
         when e.employee_code='EMP-0018' then '2026-10-14 09:01+05:30'::timestamptz
         else '2026-10-14 08:58+05:30'::timestamptz end,
       case when e.employee_code='EMP-0032' then 'absent'::public.attendance_day_status when e.employee_code in ('EMP-0024','DEMO-034') then 'late'::public.attendance_day_status else 'present'::public.attendance_day_status end,
       case when e.employee_code='EMP-0032' then 0 else 252 end,
       case when e.employee_code='EMP-0024' then 18 when e.employee_code='DEMO-034' then 16 else 0 end,
       0,'mobile','Demo attendance snapshot'
from public.employees e
join public.organizations o on o.id=e.organization_id and o.code='DKIM'
where e.status='active'
on conflict (organization_id,employee_id,work_date) do update set check_in_at=excluded.check_in_at,status=excluded.status,worked_minutes=excluded.worked_minutes,late_minutes=excluded.late_minutes,source=excluded.source,note=excluded.note;

insert into public.leave_requests (organization_id,factory_id,employee_id,leave_type_id,start_date,end_date,requested_days,reason,status)
select e.organization_id,e.factory_id,e.id,lt.id,v.start_date,v.end_date,v.days,v.reason,v.status::public.leave_request_status
from (values
  ('EMP-0011','CL','2026-10-18'::date,'2026-10-19'::date,2::numeric,'Personal leave','pending'),
  ('EMP-0029','SL','2026-10-21'::date,'2026-10-21'::date,1::numeric,'Medical rest','pending'),
  ('EMP-0018','CL','2026-10-04'::date,'2026-10-04'::date,1::numeric,'Personal work','approved')
) v(employee_code,leave_code,start_date,end_date,days,reason,status)
join public.organizations o on o.code='DKIM'
join public.employees e on e.organization_id=o.id and e.employee_code=v.employee_code
join public.leave_types lt on lt.organization_id=o.id and lt.code=v.leave_code
where not exists (
  select 1 from public.leave_requests lr where lr.employee_id=e.id and lr.leave_type_id=lt.id and lr.start_date=v.start_date and lr.end_date=v.end_date
);

insert into public.holidays (organization_id,factory_id,holiday_date,name,kind,is_paid,applies_to_all_shifts,note)
select o.id,null,v.holiday_date,v.name,v.kind::public.holiday_kind,true,true,v.note
from public.organizations o
cross join (values
  ('2026-10-20'::date,'Diwali','mandatory','All Maharashtra plants'),
  ('2026-10-22'::date,'Bhau Beej','mandatory','All Maharashtra plants'),
  ('2026-12-25'::date,'Christmas','mandatory','All plants'),
  ('2026-10-19'::date,'Diwali Eve','optional','Optional local observance')
) v(holiday_date,name,kind,note)
where o.code='DKIM'
on conflict (organization_id,factory_id,holiday_date,name) do update set kind=excluded.kind,is_paid=excluded.is_paid,applies_to_all_shifts=excluded.applies_to_all_shifts,note=excluded.note;
