-- Fictional Maintenance assets and preventive schedules.
insert into public.maintenance_assets(organization_id,factory_id,asset_code,name,asset_category,serial_number,location_label,status,operating_hours)
select o.id,f.id,v.code,v.name,v.category,v.serial,v.location,v.status::public.maintenance_asset_status,v.hours
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
cross join (values
 ('AC-02','Air Compressor','utility','DEMO-AC-002','Line 02','maintenance',8420),
 ('CL-01','CNC Lathe','machine','DEMO-CL-001','Line 01','service_due',10230),
 ('CV-03','Packing Conveyor','conveyor','DEMO-CV-003','Packing','operational',4260),
 ('DG-01','Diesel Generator','utility','DEMO-DG-001','Utilities','operational',3310)
) v(code,name,category,serial,location,status,hours)
where o.code='DKIM'
on conflict (organization_id,asset_code) do nothing;

insert into public.maintenance_plans(organization_id,factory_id,asset_id,schedule_code,task_name,interval_days,next_due_on,last_completed_on)
select a.organization_id,a.factory_id,a.id,p.code,p.task,p.days,p.due,p.previous
from (values
 ('AC-02','PM-AC-02','Bearing and oil check',30,date '2026-10-18',date '2026-09-18'),
 ('CL-01','PM-CL-01','Drive belt inspection',30,date '2026-10-15',date '2026-09-15'),
 ('CV-03','PM-CV-03','Belt alignment',60,date '2026-10-19',date '2026-08-20'),
 ('DG-01','PM-DG-01','Fuel filter service',90,date '2026-10-21',date '2026-07-23')
) p(asset_code,code,task,days,due,previous)
join public.maintenance_assets a on a.asset_code=p.asset_code
join public.organizations o on o.id=a.organization_id and o.code='DKIM'
on conflict (organization_id,schedule_code) do nothing;
