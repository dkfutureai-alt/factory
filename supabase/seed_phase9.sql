-- Fictional Phase 9 Vehicles, Drivers, Trips & Fuel demo data. No real person/company data.

insert into public.departments(id,organization_id,name,code) values
 ('31000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','Logistics & Fleet','FLEET')
on conflict (id) do nothing;

insert into public.designations(id,organization_id,department_id,name,code) values
 ('32000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000005','Heavy Vehicle Driver','DRIVER')
on conflict (id) do nothing;

insert into public.employees(
 id,organization_id,employee_code,full_name,email,phone,primary_factory_id,department_id,designation_id,shift_id,join_date,employment_type,status
) values
 ('35000000-0000-4000-8000-000000000009','10000000-0000-4000-8000-000000000001','EMP009','Arjun Shinde','arjun.fleet.demo@example.com','+91 90000 10009','20000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000005','32000000-0000-4000-8000-000000000006','33000000-0000-4000-8000-000000000001','2026-02-01','full_time','active'),
 ('35000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000001','EMP010','Meera Joshi','meera.fleet.demo@example.com','+91 90000 10010','20000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000005','32000000-0000-4000-8000-000000000006','33000000-0000-4000-8000-000000000002','2026-03-15','full_time','active')
on conflict (id) do nothing;

insert into public.stock_locations(
 id,organization_id,factory_id,name,code,location_type,is_active
) values
 ('97000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Vehicle TRK01','VEH-TRK01','vehicle',true),
 ('97000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Vehicle TNK01','VEH-TNK01','vehicle',true)
on conflict (id) do nothing;

insert into public.fleet_vehicles(
 id,organization_id,factory_id,stock_location_id,vehicle_code,registration_no,vehicle_type,make,model,model_year,fuel_type,
 capacity_quantity,capacity_unit,current_odometer_km,insurance_expiry,fitness_expiry,permit_expiry,puc_expiry,status,notes
) values
 ('97100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000001','TRK01','DEMO-MH13-TRK01','truck','Aarohan Demo Motors','Cargo 6T',2024,'diesel',120,'cylinders',18450,current_date+90,current_date+150,current_date+120,current_date+25,'active','Fictional cylinder delivery truck'),
 ('97100000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000002','TNK01','DEMO-MH13-TNK01','tanker','Aarohan Demo Motors','Cryo 12K',2023,'diesel',12000,'litres',42780,current_date+45,current_date+75,current_date+60,current_date+15,'active','Fictional bulk gas tanker')
on conflict (id) do nothing;

insert into public.fleet_drivers(
 id,organization_id,factory_id,employee_id,license_no,license_type,license_expiry,emergency_phone,status,notes
) values
 ('97200000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','35000000-0000-4000-8000-000000000009','DEMO-LIC-HMV-001','HMV',current_date+400,'+91 90000 19901','active','Primary truck driver'),
 ('97200000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','35000000-0000-4000-8000-000000000010','DEMO-LIC-HMV-002','HMV + Hazmat',current_date+320,'+91 90000 19902','active','Tanker driver')
on conflict (id) do nothing;

insert into public.fleet_vehicle_driver_assignments(
 id,organization_id,factory_id,vehicle_id,driver_id,effective_from,notes
) values
 ('97300000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000001','97200000-0000-4000-8000-000000000001',now()-interval '30 days','Current demo truck assignment'),
 ('97300000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000002','97200000-0000-4000-8000-000000000002',now()-interval '45 days','Current demo tanker assignment')
on conflict (id) do nothing;

insert into public.fleet_trips(
 id,organization_id,factory_id,trip_no,vehicle_id,driver_id,origin,destination,status,planned_start_at,planned_end_at,notes,created_at
) values
 ('97400000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','TRIP-DEMO-P9-001','97100000-0000-4000-8000-000000000001','97200000-0000-4000-8000-000000000001','Aarohan Solapur Plant','Demo City Hospital','assigned',now()+interval '2 hours',now()+interval '6 hours','Planned cylinder delivery route',now()-interval '1 hour'),
 ('97400000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','TRIP-DEMO-P9-000','97100000-0000-4000-8000-000000000002','97200000-0000-4000-8000-000000000002','Aarohan Solapur Plant','Demo Industrial Estate','completed',now()-interval '3 days',now()-interval '3 days'+interval '5 hours',now()-interval '3 days',now()-interval '3 days'+interval '4 hours 35 minutes',now()-interval '3 days'+interval '4 hours 40 minutes',42620,42750,42780,'Historical demo tanker trip',now()-interval '4 days')
on conflict (id) do nothing;

insert into public.fleet_odometer_logs(
 id,organization_id,factory_id,vehicle_id,trip_id,reading_km,source,recorded_at,notes
) values
 ('97500000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000002','97400000-0000-4000-8000-000000000002',42620,'trip_start',now()-interval '3 days','Historical start reading'),
 ('97500000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000002','97400000-0000-4000-8000-000000000002',42750,'trip_arrival',now()-interval '3 days'+interval '4 hours 35 minutes','Historical arrival reading'),
 ('97500000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000002','97400000-0000-4000-8000-000000000002',42780,'trip_complete',now()-interval '3 days'+interval '4 hours 40 minutes','Historical completion reading')
on conflict (id) do nothing;

insert into public.fleet_fuel_entries(
 id,organization_id,factory_id,vehicle_id,driver_id,trip_id,fuel_type,quantity_liters,price_per_liter,odometer_km,filled_at,vendor,receipt_reference,notes
) values
 ('97600000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000002','97200000-0000-4000-8000-000000000002','97400000-0000-4000-8000-000000000002','diesel',38.5,94.75,42710,now()-interval '3 days'+interval '2 hours','Demo Highway Fuel Point','DEMO-RCPT-9001','Historical trip fuel entry')
on conflict (id) do nothing;

insert into public.fleet_service_reminders(
 id,organization_id,factory_id,vehicle_id,reminder_type,title,due_date,due_odometer_km,status,notes
) values
 ('97700000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000001','puc','Renew PUC certificate',current_date+25,null,'open','Demo compliance reminder'),
 ('97700000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','97100000-0000-4000-8000-000000000002','service','Tanker preventive service',null,43500,'open','Service due by odometer')
on conflict (id) do nothing;
