-- Phase 11 fictional Maintenance demo data.

insert into public.maintenance_assets(
  id,organization_id,factory_id,asset_code,name,category,manufacturer,model,serial_number,area,criticality,status,commissioning_date,warranty_expiry,meter_type,current_meter,notes
) values
 ('61000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','CMP-O2-01','Oxygen Booster Compressor','machine','Demo Industrial Systems','BC-45','DEMO-CMP-001','Compression Bay','critical','active','2024-02-15','2027-02-14','hours',2840,'Fictional demo asset'),
 ('61000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','MAN-FILL-01','Cylinder Filling Manifold','machine','Demo Gas Equipment','FM-24','DEMO-MAN-001','Filling Bay','high','down','2023-08-10',null,'cycles',18620,'Fictional demo asset'),
 ('61000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','DG-250-01','250 kVA Diesel Generator','utility','Demo Power Works','DG250','DEMO-DG-001','Utility Yard','high','active','2022-06-01',null,'hours',4210,'Emergency power demo asset'),
 ('61000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','FIRE-PUMP-01','Fire Hydrant Pump','safety','Demo Safety Pumps','HP-80','DEMO-FP-001','Fire Pump Room','critical','active','2025-01-10','2027-01-09','hours',615,'Safety-critical fictional demo asset')
on conflict (id) do nothing;

insert into public.maintenance_plans(
  id,organization_id,factory_id,asset_id,plan_code,title,maintenance_type,frequency_days,meter_interval,estimated_minutes,checklist,last_done_at,last_meter,next_due_at,next_due_meter,is_active,notes
) values
 ('62000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000001','PM-CMP-30D','Compressor 30-day preventive service','preventive',30,500,120,'["Check oil level","Inspect belts","Check discharge temperature","Inspect vibration","Clean filters"]',now()-interval '32 days',2340,now()-interval '2 days',2840,true,'Date and meter based preventive plan'),
 ('62000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000002','INSP-MAN-14D','Filling manifold leak inspection','inspection',14,2500,60,'["Soap-test joints","Inspect hoses","Check gauges","Verify isolation valves"]',now()-interval '12 days',16400,now()+interval '2 days',18900,true,'Routine leak inspection'),
 ('62000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000003','PM-DG-250H','Generator 250-hour service','preventive',90,250,150,'["Change engine oil","Inspect coolant","Check battery","Inspect fuel filter","Run load test"]',now()-interval '65 days',4000,now()+interval '25 days',4250,true,'Meter-driven service'),
 ('62000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000004','TEST-FIRE-WEEK','Weekly fire pump run test','inspection',7,null,30,'["Start pump","Verify pressure","Check leaks","Record run time"]',now()-interval '5 days',null,now()+interval '2 days',null,true,'Safety inspection plan')
on conflict (id) do nothing;

insert into public.maintenance_requests(
  id,organization_id,factory_id,asset_id,request_no,request_type,priority,title,description,status,safety_stop,reported_at
) values
 ('63000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000002','MR-DEMO-001','breakdown','high','Manifold isolation valve leaking','Operator noticed leakage around the isolation valve during pre-start check.','in_progress',true,now()-interval '55 minutes'),
 ('63000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000003','MR-DEMO-002','service','medium','Generator battery terminal cleaning','Routine observation: battery terminals need cleaning before next load test.','open',false,now()-interval '4 hours')
on conflict (id) do nothing;

insert into public.maintenance_work_orders(
  id,organization_id,factory_id,asset_id,request_id,plan_id,work_order_no,work_type,priority,title,description,status,assigned_employee_id,scheduled_start_at,started_at,meter_at_start,notes
) values
 ('64000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000002','63000000-0000-4000-8000-000000000001',null,'MWO-DEMO-001','breakdown','high','Replace leaking manifold isolation valve','Isolate manifold, replace valve, leak-test and return to service.','in_progress','35000000-0000-4000-8000-000000000003',now()-interval '45 minutes',now()-interval '42 minutes',18620,'Demo breakdown in execution'),
 ('64000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000001',null,'62000000-0000-4000-8000-000000000001','MWO-DEMO-002','preventive','critical','Compressor 30-day preventive service','Generated from overdue preventive plan.','planned',null,now()+interval '1 hour',null,null,'Ready for assignment')
on conflict (id) do nothing;

insert into public.maintenance_downtime_events(
  id,organization_id,factory_id,asset_id,work_order_id,started_at,reason
) values
 ('65000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000001',now()-interval '55 minutes','Breakdown - valve leakage')
on conflict (id) do nothing;

insert into public.maintenance_work_logs(
  id,organization_id,factory_id,work_order_id,log_type,message,logged_at
) values
 ('66000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001','start','Manifold isolated and depressurized. Valve replacement started.',now()-interval '42 minutes'),
 ('66000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000002','note','Preventive work is due and waiting for assignment.',now()-interval '10 minutes')
on conflict (id) do nothing;
