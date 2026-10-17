-- Fictional Phase 11 maintenance demo data. No real person/company data.

insert into public.inventory_items(id,organization_id,category_id,unit_id,sku,name,item_type,barcode,qr_code,is_batch_tracked) values
 ('a1110000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000003','42000000-0000-4000-8000-000000000002','OIL-FLTR-01','Compressor Oil Filter','spare','890110000001','AAROHAN:OIL-FLTR-01',false),
 ('a1110000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000003','42000000-0000-4000-8000-000000000002','VBELT-A42','V-Belt A42','spare','890110000002','AAROHAN:VBELT-A42',false),
 ('a1110000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000003','42000000-0000-4000-8000-000000000002','BRG-6205','Bearing 6205','spare','890110000003','AAROHAN:BRG-6205',false),
 ('a1110000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000003','42000000-0000-4000-8000-000000000003','HYD-OIL-46','Hydraulic Oil ISO 46','consumable','890110000004','AAROHAN:HYD-OIL-46',false)
on conflict (id) do nothing;

insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,to_location_id,unit_cost,external_reference,notes,occurred_at) values
 ('a1200000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1110000-0000-4000-8000-000000000001','MAINT-SEED-RCV-001','receive',25,'44000000-0000-4000-8000-000000000001',180,'MAINT-SEED','Maintenance spare opening stock',now()-interval '45 days'),
 ('a1200000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1110000-0000-4000-8000-000000000002','MAINT-SEED-RCV-002','receive',8,'44000000-0000-4000-8000-000000000001',450,'MAINT-SEED','Maintenance spare opening stock',now()-interval '45 days'),
 ('a1200000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1110000-0000-4000-8000-000000000003','MAINT-SEED-RCV-003','receive',6,'44000000-0000-4000-8000-000000000001',620,'MAINT-SEED','Maintenance spare opening stock',now()-interval '45 days'),
 ('a1200000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1110000-0000-4000-8000-000000000004','MAINT-SEED-RCV-004','receive',50,'44000000-0000-4000-8000-000000000001',210,'MAINT-SEED','Maintenance consumable opening stock',now()-interval '45 days')
on conflict (id) do nothing;

insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost,occurred_at) values
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000001','a1110000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000001',25,180,now()-interval '45 days'),
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000002','a1110000-0000-4000-8000-000000000002','44000000-0000-4000-8000-000000000001',8,450,now()-interval '45 days'),
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000003','a1110000-0000-4000-8000-000000000003','44000000-0000-4000-8000-000000000001',6,620,now()-interval '45 days'),
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1200000-0000-4000-8000-000000000004','a1110000-0000-4000-8000-000000000004','44000000-0000-4000-8000-000000000001',50,210,now()-interval '45 days');

insert into public.maintenance_assets(
 id,organization_id,factory_id,asset_code,name,asset_type,work_center_id,location_id,manufacturer,model,serial_no,criticality,status,installed_on,last_service_at,next_service_at,qr_code,notes
) values
 ('a1300000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','AC-001','Air Compressor-1','machine','52000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000002','Atlas Demo','ACX-75','AC-DEMO-001','critical','running','2024-06-15',now()-interval '28 days',now()+interval '3 days','AAROHAN:ASSET:AC-001','Primary filling-line compressor'),
 ('a1300000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','GEN-001','Generator-500 KVA','utility',null,'44000000-0000-4000-8000-000000000002','Volt Demo','DG-500','DG-DEMO-001','high','maintenance','2023-01-20',now()-interval '35 days',now()+interval '8 days','AAROHAN:ASSET:GEN-001','Emergency power generator'),
 ('a1300000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PL-001','Oxygen Filling Line-1','machine','52000000-0000-4000-8000-000000000001','44000000-0000-4000-8000-000000000002','Aarohan Demo','FillLine-24','PL-DEMO-001','critical','running','2025-02-10',now()-interval '12 days',now()+interval '14 days','AAROHAN:ASSET:PL-001','Main oxygen filling manifold and controls'),
 ('a1300000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','RO-001','RO Water Plant','utility',null,'44000000-0000-4000-8000-000000000002','Pure Demo','RO-20K','RO-DEMO-001','medium','down','2024-11-01',now()-interval '60 days',now()-interval '2 days','AAROHAN:ASSET:RO-001','Utility water-treatment plant'),
 ('a1300000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PMP-002','Transfer Pump-2','equipment',null,'44000000-0000-4000-8000-000000000002','Flow Demo','TP-7.5','PMP-DEMO-002','medium','running','2025-05-05',now()-interval '20 days',now()+interval '10 days','AAROHAN:ASSET:PMP-002','Utility transfer pump')
on conflict (id) do nothing;

insert into public.maintenance_plans(
 id,organization_id,factory_id,plan_no,asset_id,name,maintenance_type,frequency_unit,frequency_value,next_due_date,last_completed_at,default_technician_employee_id,default_priority,estimated_minutes,instructions,is_active
) values
 ('a1400000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PM-AC-001','a1300000-0000-4000-8000-000000000001','Monthly compressor service','preventive','months',1,current_date+3,now()-interval '28 days','35000000-0000-4000-8000-000000000003','high',90,'Inspect filters, oil level, belt tension and leakage',true),
 ('a1400000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PM-DG-001','a1300000-0000-4000-8000-000000000002','Generator monthly inspection','inspection','months',1,current_date+8,now()-interval '35 days','35000000-0000-4000-8000-000000000003','medium',60,'Check oil, coolant, battery and no-load run',true),
 ('a1400000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PM-LINE-001','a1300000-0000-4000-8000-000000000003','Filling-line weekly safety inspection','inspection','weeks',1,current_date+5,now()-interval '2 days','35000000-0000-4000-8000-000000000003','high',45,'Inspect manifold, valves, gauges and emergency stop',true),
 ('a1400000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','PM-RO-001','a1300000-0000-4000-8000-000000000004','RO plant monthly service','preventive','months',1,current_date-2,now()-interval '60 days','35000000-0000-4000-8000-000000000003','high',120,'Inspect pumps, filters, pressure and membrane condition',true)
on conflict (id) do nothing;

insert into public.maintenance_plan_tasks(id,organization_id,plan_id,sequence_no,instruction,is_required) values
 ('a1410000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','a1400000-0000-4000-8000-000000000001',1,'Check compressor oil level',true),
 ('a1410000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','a1400000-0000-4000-8000-000000000001',2,'Clean or replace air filter',true),
 ('a1410000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','a1400000-0000-4000-8000-000000000001',3,'Check belt tension and wear',true),
 ('a1410000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','a1400000-0000-4000-8000-000000000001',4,'Inspect for air/oil leakage',true),
 ('a1410000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','a1400000-0000-4000-8000-000000000004',1,'Check feed-pump pressure',true),
 ('a1410000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','a1400000-0000-4000-8000-000000000004',2,'Inspect cartridge filters',true)
on conflict (id) do nothing;

insert into public.maintenance_requests(id,organization_id,factory_id,request_no,asset_id,requested_by_employee_id,issue_type,priority,description,status,created_at) values
 ('a1500000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','MR-DEMO-001','a1300000-0000-4000-8000-000000000005','35000000-0000-4000-8000-000000000001','noise','medium','Abnormal bearing noise from Transfer Pump-2','open',now()-interval '2 hours'),
 ('a1500000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','MR-DEMO-002','a1300000-0000-4000-8000-000000000002','35000000-0000-4000-8000-000000000005','mechanical','high','Generator vibration increased during test run','converted',now()-interval '1 day')
on conflict (id) do nothing;

insert into public.maintenance_work_orders(
 id,organization_id,factory_id,work_order_no,asset_id,request_id,plan_id,maintenance_type,priority,status,assigned_employee_id,scheduled_at,due_at,started_at,completed_at,problem_description,resolution_notes,labor_minutes,external_cost,created_at
) values
 ('a1600000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','MWO-DEMO-001','a1300000-0000-4000-8000-000000000001',null,'a1400000-0000-4000-8000-000000000001','preventive','high','assigned','35000000-0000-4000-8000-000000000003',now()+interval '1 day',now()+interval '2 days',null,null,'Monthly preventive service due',null,0,0,now()-interval '1 hour'),
 ('a1600000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','MWO-DEMO-002','a1300000-0000-4000-8000-000000000002','a1500000-0000-4000-8000-000000000002',null,'corrective','high','in_progress','35000000-0000-4000-8000-000000000003',now()-interval '5 hours',now()+interval '3 hours',now()-interval '4 hours',null,'Investigate generator vibration and mounting condition',null,0,0,now()-interval '1 day'),
 ('a1600000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','MWO-DEMO-003','a1300000-0000-4000-8000-000000000003',null,null,'corrective','medium','completed','35000000-0000-4000-8000-000000000003',now()-interval '12 days',now()-interval '11 days',now()-interval '12 days',now()-interval '11 days 22 hours','Minor belt slip at filling line','Adjusted drive alignment and replaced worn belt',95,0,now()-interval '12 days')
on conflict (id) do nothing;

insert into public.maintenance_work_order_tasks(id,organization_id,work_order_id,sequence_no,instruction,is_required) values
 ('a1610000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000001',1,'Check compressor oil level',true),
 ('a1610000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000001',2,'Clean or replace air filter',true),
 ('a1610000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000001',3,'Check belt tension and wear',true),
 ('a1610000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000001',4,'Inspect for air/oil leakage',true)
on conflict (id) do nothing;

insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,from_location_id,unit_cost,external_reference,notes,occurred_at) values
 ('a1620000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1110000-0000-4000-8000-000000000002','MAINT-SEED-ISS-001','issue',1,'44000000-0000-4000-8000-000000000001',450,'MWO-DEMO-003','Historical maintenance spare usage',now()-interval '11 days 23 hours')
on conflict (id) do nothing;

insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost,occurred_at)
values('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1620000-0000-4000-8000-000000000001','a1110000-0000-4000-8000-000000000002','44000000-0000-4000-8000-000000000001',-1,450,now()-interval '11 days 23 hours');

insert into public.maintenance_spare_usage(id,organization_id,factory_id,work_order_id,item_id,source_location_id,quantity,unit_cost,line_cost,inventory_transaction_id,created_at) values
 ('a1630000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000003','a1110000-0000-4000-8000-000000000002','44000000-0000-4000-8000-000000000001',1,450,450,'a1620000-0000-4000-8000-000000000001',now()-interval '11 days 23 hours')
on conflict (id) do nothing;

insert into public.maintenance_downtime_events(id,organization_id,factory_id,work_order_id,asset_id,reason,started_at,ended_at,duration_minutes,created_at) values
 ('a1640000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000003','a1300000-0000-4000-8000-000000000003','Belt alignment repair',now()-interval '12 days',now()-interval '11 days 23 hours 15 minutes',45,now()-interval '12 days')
on conflict (id) do nothing;

insert into public.maintenance_work_updates(id,organization_id,factory_id,work_order_id,status_snapshot,note,photo_ref,created_at) values
 ('a1650000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000002','in_progress','Checked mounts; vibration appears higher on drive-side bearing',null,now()-interval '3 hours'),
 ('a1650000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','a1600000-0000-4000-8000-000000000003','completed','Drive alignment corrected and worn V-belt replaced',null,now()-interval '11 days 22 hours')
on conflict (id) do nothing;
