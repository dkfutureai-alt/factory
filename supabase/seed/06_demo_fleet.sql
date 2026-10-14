-- FactoryOS fictional Fleet demo seed
-- Depends on 01_demo_foundation.sql, 04_demo_hr.sql, 06_sales.sql and 07_fleet.sql.
-- Reuses 10 existing DEMO employees as drivers so the HR demo remains 40 employees total.

with driver_people(employee_code,first_name,last_name,driver_code,license_number,license_class,license_valid_until) as (
  values
    ('DEMO-001','Rahul','Jadhav','DRV-0001','DEMO-MH-DRV-0001','HMV / Transport',date '2029-08-18'),
    ('DEMO-002','Suresh','More','DRV-0002','DEMO-MH-DRV-0002','HMV / Transport',date '2029-11-05'),
    ('DEMO-003','Amit','Pawar','DRV-0003','DEMO-MH-DRV-0003','LMV / Transport',date '2028-07-22'),
    ('DEMO-004','Ganesh','Kale','DRV-0004','DEMO-MH-DRV-0004','HMV / Transport',date '2030-01-12'),
    ('DEMO-005','Prasad','Mane','DRV-0005','DEMO-MH-DRV-0005','HMV / Transport',date '2029-03-30'),
    ('DEMO-006','Nitin','Shinde','DRV-0006','DEMO-MH-DRV-0006','LMV / Transport',date '2028-12-11'),
    ('DEMO-007','Sachin','Patil','DRV-0007','DEMO-MH-DRV-0007','HMV / Transport',date '2030-06-17'),
    ('DEMO-008','Rohan','Chavan','DRV-0008','DEMO-MH-DRV-0008','LMV / Transport',date '2029-09-09'),
    ('DEMO-009','Vikas','Sawant','DRV-0009','DEMO-MH-DRV-0009','HMV / Transport',date '2029-04-26'),
    ('DEMO-010','Yogesh','Kadam','DRV-0010','DEMO-MH-DRV-0010','LMV / Transport',date '2028-10-14')
)
update public.employees e
set first_name=p.first_name,
    last_name=p.last_name,
    designation='Transport Driver',
    department_id=d.id,
    updated_at=now()
from driver_people p
join public.organizations o on o.code='DKIM'
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.departments d on d.organization_id=o.id and d.factory_id=f.id and d.code='LOG'
where e.organization_id=o.id and e.employee_code=p.employee_code;

insert into public.driver_profiles (employee_id,organization_id,license_number,license_class,license_valid_until,medical_valid_until,safety_training_valid_until,status)
select e.id,e.organization_id,p.license_number,p.license_class,p.license_valid_until,date '2027-06-30',date '2027-03-31','active'
from (values
  ('DEMO-001','DEMO-MH-DRV-0001','HMV / Transport',date '2029-08-18'),
  ('DEMO-002','DEMO-MH-DRV-0002','HMV / Transport',date '2029-11-05'),
  ('DEMO-003','DEMO-MH-DRV-0003','LMV / Transport',date '2028-07-22'),
  ('DEMO-004','DEMO-MH-DRV-0004','HMV / Transport',date '2030-01-12'),
  ('DEMO-005','DEMO-MH-DRV-0005','HMV / Transport',date '2029-03-30'),
  ('DEMO-006','DEMO-MH-DRV-0006','LMV / Transport',date '2028-12-11'),
  ('DEMO-007','DEMO-MH-DRV-0007','HMV / Transport',date '2030-06-17'),
  ('DEMO-008','DEMO-MH-DRV-0008','LMV / Transport',date '2029-09-09'),
  ('DEMO-009','DEMO-MH-DRV-0009','HMV / Transport',date '2029-04-26'),
  ('DEMO-010','DEMO-MH-DRV-0010','LMV / Transport',date '2028-10-14')
) p(employee_code,license_number,license_class,license_valid_until)
join public.organizations o on o.code='DKIM'
join public.employees e on e.organization_id=o.id and e.employee_code=p.employee_code
on conflict (employee_id) do update set license_number=excluded.license_number,license_class=excluded.license_class,license_valid_until=excluded.license_valid_until,medical_valid_until=excluded.medical_valid_until,safety_training_valid_until=excluded.safety_training_valid_until,status=excluded.status;

insert into public.vehicles (organization_id,factory_id,registration_number,vehicle_code,vehicle_type,make,model,capacity_label,fuel_type,current_odometer_km,next_service_odometer_km,status)
select o.id,f.id,v.registration,v.code,v.vehicle_type,v.make,v.model,v.capacity,v.fuel_type,v.odometer,v.service_due,v.status::public.vehicle_operational_status
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
cross join (values
  ('MH 13 DK 4521','VEH-001','Medium truck','Tata','Ultra T.9','4.5T','diesel',84260,85000,'on_trip'),
  ('MH 12 AB 7742','VEH-002','LCV','Ashok Leyland','Dost+','1.5T','diesel',61885,65000,'available'),
  ('MH 14 KT 1188','VEH-003','Pickup','Mahindra','Bolero Pik-Up','1.7T','diesel',42100,42000,'service_due'),
  ('MH 13 QP 3304','VEH-004','Medium truck','Eicher','Pro 2059','4.5T','diesel',73550,76000,'available'),
  ('MH 12 TY 9021','VEH-005','LCV','Tata','407 Gold','2.2T','diesel',55480,58000,'assigned'),
  ('MH 15 NA 6612','VEH-006','Pickup','Isuzu','S-CAB','1.2T','diesel',38420,40000,'available'),
  ('MH 13 XR 7190','VEH-007','Medium truck','BharatBenz','914R','5.0T','diesel',91200,93000,'assigned'),
  ('MH 14 PL 2088','VEH-008','LCV','Mahindra','Furio 7','3.0T','diesel',46770,49000,'available'),
  ('MH 12 VN 5844','VEH-009','Pickup','Tata','Intra V50','1.5T','diesel',29780,32000,'maintenance'),
  ('MH 13 GH 1406','VEH-010','Medium truck','Eicher','Pro 2095XP','5.5T','diesel',68110,70000,'available')
) v(registration,code,vehicle_type,make,model,capacity,fuel_type,odometer,service_due,status)
where o.code='DKIM'
on conflict (organization_id,registration_number) do update set vehicle_code=excluded.vehicle_code,vehicle_type=excluded.vehicle_type,make=excluded.make,model=excluded.model,capacity_label=excluded.capacity_label,fuel_type=excluded.fuel_type,current_odometer_km=excluded.current_odometer_km,next_service_odometer_km=excluded.next_service_odometer_km,status=excluded.status;

insert into public.vehicle_driver_assignments (organization_id,factory_id,vehicle_id,driver_employee_id,assigned_from,is_primary)
select v.organization_id,v.factory_id,v.id,e.id,timestamptz '2026-10-01 09:00:00+05:30',true
from (values
  ('VEH-001','DEMO-001'),('VEH-002','DEMO-002'),('VEH-003','DEMO-003'),('VEH-004','DEMO-004'),('VEH-005','DEMO-005'),
  ('VEH-006','DEMO-006'),('VEH-007','DEMO-007'),('VEH-008','DEMO-008'),('VEH-009','DEMO-009'),('VEH-010','DEMO-010')
) x(vehicle_code,employee_code)
join public.organizations o on o.code='DKIM'
join public.vehicles v on v.organization_id=o.id and v.vehicle_code=x.vehicle_code
join public.employees e on e.organization_id=o.id and e.employee_code=x.employee_code
where not exists (select 1 from public.vehicle_driver_assignments a where a.vehicle_id=v.id and a.is_primary and a.assigned_until is null);

insert into public.vehicle_documents (organization_id,vehicle_id,document_type,document_number,valid_from,valid_until,status)
select v.organization_id,v.id,d.document_type,d.document_number,date '2026-01-01',d.valid_until,'active'
from public.vehicles v
join public.organizations o on o.id=v.organization_id and o.code='DKIM'
cross join lateral (values
  ('insurance','DEMO-INS-'||v.vehicle_code,date '2027-02-28'),
  ('fitness','DEMO-FIT-'||v.vehicle_code,date '2027-01-12'),
  ('puc','DEMO-PUC-'||v.vehicle_code,case when v.vehicle_code='VEH-001' then date '2026-10-22' else date '2027-01-31' end),
  ('permit','DEMO-PERMIT-'||v.vehicle_code,date '2027-12-31')
) d(document_type,document_number,valid_until)
on conflict (vehicle_id,document_type) do update set document_number=excluded.document_number,valid_from=excluded.valid_from,valid_until=excluded.valid_until,status=excluded.status;

insert into public.trips (organization_id,factory_id,trip_number,vehicle_id,driver_employee_id,sales_order_id,origin_label,destination_label,planned_start_at,actual_start_at,completed_at,start_odometer_km,end_odometer_km,status,block_reason)
select v.organization_id,v.factory_id,t.trip_number,v.id,e.id,so.id,'Main Manufacturing Plant',t.destination,t.planned_start,
       case when t.status in ('in_progress','completed') then t.planned_start + interval '8 minutes' else null end,
       case when t.status='completed' then t.planned_start + interval '2 hours' else null end,
       case when t.status in ('in_progress','completed') then v.current_odometer_km-120 else null end,
       case when t.status='completed' then v.current_odometer_km else null end,
       t.status::public.trip_status,
       case when t.status='blocked' then 'Vehicle service hold' else null end
from (values
  ('TRIP-2026-00814','VEH-001','DEMO-001','SO-2026-01842','CityCare Hospital',timestamptz '2026-10-14 10:30:00+05:30','in_progress'),
  ('TRIP-2026-00815','VEH-002','DEMO-002','SO-2026-01843','Metro Engineering',timestamptz '2026-10-14 13:30:00+05:30','ready'),
  ('TRIP-2026-00816','VEH-003','DEMO-003',null,'Nashik Automation',timestamptz '2026-10-14 15:00:00+05:30','blocked'),
  ('TRIP-2026-00817','VEH-004','DEMO-004',null,'Pimpri Warehouse',timestamptz '2026-10-14 09:00:00+05:30','completed'),
  ('TRIP-2026-00818','VEH-005','DEMO-005',null,'Bhosari MIDC',timestamptz '2026-10-14 11:00:00+05:30','assigned'),
  ('TRIP-2026-00819','VEH-006','DEMO-006',null,'Chakan Industrial Area',timestamptz '2026-10-14 12:00:00+05:30','completed'),
  ('TRIP-2026-00820','VEH-007','DEMO-007',null,'Talegaon Industrial Estate',timestamptz '2026-10-14 14:15:00+05:30','assigned'),
  ('TRIP-2026-00821','VEH-008','DEMO-008',null,'Ranjangaon MIDC',timestamptz '2026-10-14 08:30:00+05:30','completed'),
  ('TRIP-2026-00822','VEH-010','DEMO-010',null,'Hadapsar Industrial Estate',timestamptz '2026-10-14 16:00:00+05:30','planned')
) t(trip_number,vehicle_code,employee_code,sales_order_number,destination,planned_start,status)
join public.organizations o on o.code='DKIM'
join public.vehicles v on v.organization_id=o.id and v.vehicle_code=t.vehicle_code
join public.employees e on e.organization_id=o.id and e.employee_code=t.employee_code
left join public.sales_orders so on so.organization_id=o.id and so.order_number=t.sales_order_number
on conflict (organization_id,trip_number) do update set vehicle_id=excluded.vehicle_id,driver_employee_id=excluded.driver_employee_id,sales_order_id=excluded.sales_order_id,origin_label=excluded.origin_label,destination_label=excluded.destination_label,planned_start_at=excluded.planned_start_at,actual_start_at=excluded.actual_start_at,completed_at=excluded.completed_at,start_odometer_km=excluded.start_odometer_km,end_odometer_km=excluded.end_odometer_km,status=excluded.status,block_reason=excluded.block_reason;

insert into public.vehicle_inspections (organization_id,factory_id,vehicle_id,driver_employee_id,trip_id,inspected_at,odometer_km,brakes_ok,tyres_ok,lights_ok,fluids_ok,documents_ok,notes)
select t.organization_id,t.factory_id,t.vehicle_id,t.driver_employee_id,t.id,t.planned_start_at-interval '20 minutes',coalesce(t.start_odometer_km,v.current_odometer_km),true,true,true,true,true,'Demo pre-trip inspection passed'
from public.trips t
join public.vehicles v on v.id=t.vehicle_id
join public.organizations o on o.id=t.organization_id and o.code='DKIM'
where t.trip_number in ('TRIP-2026-00814','TRIP-2026-00815')
and not exists(select 1 from public.vehicle_inspections i where i.trip_id=t.id);

insert into public.fuel_entries (organization_id,factory_id,entry_number,vehicle_id,driver_employee_id,trip_id,fueled_at,odometer_km,litres,amount,vendor_name,receipt_reference,status,reviewed_at)
select v.organization_id,v.factory_id,f.entry_number,v.id,e.id,t.id,f.fueled_at,f.odometer,f.litres,f.amount,'Demo Fuel Station',f.receipt_reference,'approved'::public.fuel_entry_status,f.fueled_at+interval '30 minutes'
from (values
  ('FUEL-01470','VEH-003','DEMO-003',null,timestamptz '2026-10-13 17:20:00+05:30',42100,22.5::numeric,2228::numeric,'DEMO-RCP-01470'),
  ('FUEL-01471','VEH-002','DEMO-002','TRIP-2026-00815',timestamptz '2026-10-14 08:10:00+05:30',61885,31.0::numeric,3068::numeric,'DEMO-RCP-01471'),
  ('FUEL-01472','VEH-001','DEMO-001','TRIP-2026-00814',timestamptz '2026-10-14 09:45:00+05:30',84260,38.2::numeric,3780::numeric,'DEMO-RCP-01472')
) f(entry_number,vehicle_code,employee_code,trip_number,fueled_at,odometer,litres,amount,receipt_reference)
join public.organizations o on o.code='DKIM'
join public.vehicles v on v.organization_id=o.id and v.vehicle_code=f.vehicle_code
join public.employees e on e.organization_id=o.id and e.employee_code=f.employee_code
left join public.trips t on t.organization_id=o.id and t.trip_number=f.trip_number
on conflict (organization_id,entry_number) do update set vehicle_id=excluded.vehicle_id,driver_employee_id=excluded.driver_employee_id,trip_id=excluded.trip_id,fueled_at=excluded.fueled_at,odometer_km=excluded.odometer_km,litres=excluded.litres,amount=excluded.amount,vendor_name=excluded.vendor_name,receipt_reference=excluded.receipt_reference;
