-- Fictional Phase 10 Dispatch, Delivery & Returnables demo data. No real person/company data.
-- Phase 10 owns its Sales, Warehouse and Fleet demo records so previous phase fixtures remain unchanged.

-- Empty cylinders are returnable assets for the customer-return flow.
update public.inventory_items
set is_returnable=true
where id='43000000-0000-4000-8000-000000000003';

-- Dedicated Phase 10 sales order and allocation.
insert into public.sales_orders(
  id,organization_id,factory_id,sales_order_no,customer_id,order_date,requested_delivery_date,
  currency_code,status,dispatch_ready_at,notes
) values (
  '98400000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'SO-DEMO-P10-001',
  '91000000-0000-4000-8000-000000000003',
  current_date,
  current_date+1,
  'INR','dispatch_ready',now()-interval '70 minutes',
  'Dedicated fictional Phase 10 cylinder delivery order'
) on conflict (id) do nothing;

insert into public.sales_order_lines(
  id,organization_id,sales_order_id,item_id,ordered_quantity,unit_price,tax_rate,
  allocated_quantity,dispatched_quantity,notes
) values (
  '98400000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000001',
  '43000000-0000-4000-8000-000000000006',
  4,2500,5,4,0,'Dedicated Phase 10 allocation'
) on conflict (id) do nothing;

insert into public.sales_allocations(
  id,organization_id,factory_id,sales_order_id,sales_order_line_id,item_id,location_id,quantity,status
) values (
  '98400000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000002',
  '43000000-0000-4000-8000-000000000006',
  '44000000-0000-4000-8000-000000000003',
  4,'allocated'
) on conflict (id) do nothing;

-- Add stock dedicated to the Phase 10 demo so earlier Production/Quality balances are unchanged.
insert into public.inventory_transactions(
  id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,
  to_location_id,external_reference,notes,occurred_at
) values (
  '98400000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '43000000-0000-4000-8000-000000000006',
  'P10-DEMO-RECEIPT-001','receive',4,
  '44000000-0000-4000-8000-000000000003',
  'P10-DEMO-STOCK','Additional fictional stock dedicated to Phase 10 dispatch',
  now()-interval '65 minutes'
) on conflict (id) do nothing;

insert into public.stock_ledger_entries(
  organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,occurred_at
)
select
  '10000000-0000-4000-8000-000000000001'::uuid,
  '20000000-0000-4000-8000-000000000001'::uuid,
  '98400000-0000-4000-8000-000000000004'::uuid,
  '43000000-0000-4000-8000-000000000006'::uuid,
  '44000000-0000-4000-8000-000000000003'::uuid,
  4::numeric,
  now()-interval '65 minutes'
where not exists(
  select 1 from public.stock_ledger_entries
  where transaction_id='98400000-0000-4000-8000-000000000004'
);

-- Dedicated Warehouse flow: picked → staged → handed off without advancing Phase 8 demo records.
insert into public.inventory_transactions(
  id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,
  from_location_id,to_location_id,external_reference,notes,occurred_at
) values (
  '98400000-0000-4000-8000-000000000005',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '43000000-0000-4000-8000-000000000006',
  'P10-PICK-STAGE-001','transfer',4,
  '44000000-0000-4000-8000-000000000003',
  '96000000-0000-4000-8000-000000000006',
  'PICK-DEMO-P10-001','Dedicated Phase 10 Warehouse staging transfer',
  now()-interval '60 minutes'
) on conflict (id) do nothing;

insert into public.stock_ledger_entries(
  organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,occurred_at
)
select * from (values
  ('10000000-0000-4000-8000-000000000001'::uuid,'20000000-0000-4000-8000-000000000001'::uuid,'98400000-0000-4000-8000-000000000005'::uuid,'43000000-0000-4000-8000-000000000006'::uuid,'44000000-0000-4000-8000-000000000003'::uuid,-4::numeric,now()-interval '60 minutes'),
  ('10000000-0000-4000-8000-000000000001'::uuid,'20000000-0000-4000-8000-000000000001'::uuid,'98400000-0000-4000-8000-000000000005'::uuid,'43000000-0000-4000-8000-000000000006'::uuid,'96000000-0000-4000-8000-000000000006'::uuid,4::numeric,now()-interval '60 minutes')
) as x(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,occurred_at)
where not exists(
  select 1 from public.stock_ledger_entries
  where transaction_id='98400000-0000-4000-8000-000000000005'
);

insert into public.warehouse_pick_lists(
  id,organization_id,factory_id,pick_list_no,sales_order_id,staging_location_id,
  priority,status,notes,started_at,staged_at,created_at
) values (
  '98400000-0000-4000-8000-000000000006',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'PICK-DEMO-P10-001',
  '98400000-0000-4000-8000-000000000001',
  '96000000-0000-4000-8000-000000000006',
  'high','handed_off','Dedicated Phase 10 Warehouse pick',
  now()-interval '63 minutes',now()-interval '58 minutes',now()-interval '65 minutes'
) on conflict (id) do nothing;

insert into public.warehouse_pick_lines(
  id,organization_id,pick_list_id,sales_allocation_id,sales_order_line_id,item_id,
  from_location_id,quantity_required,picked_quantity,status,transfer_transaction_id,picked_at,created_at
) values (
  '98400000-0000-4000-8000-000000000007',
  '10000000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000006',
  '98400000-0000-4000-8000-000000000003',
  '98400000-0000-4000-8000-000000000002',
  '43000000-0000-4000-8000-000000000006',
  '44000000-0000-4000-8000-000000000003',
  4,4,'picked','98400000-0000-4000-8000-000000000005',
  now()-interval '60 minutes',now()-interval '65 minutes'
) on conflict (id) do nothing;

insert into public.warehouse_dispatch_handoffs(
  id,organization_id,factory_id,handoff_no,pick_list_id,sales_order_id,staging_location_id,
  status,notes,handed_off_at,created_at
) values (
  '98400000-0000-4000-8000-000000000008',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'WH-HO-DEMO-P10-001',
  '98400000-0000-4000-8000-000000000006',
  '98400000-0000-4000-8000-000000000001',
  '96000000-0000-4000-8000-000000000006',
  'handed_off','Dedicated Phase 10 Warehouse-to-Dispatch handoff',
  now()-interval '55 minutes',now()-interval '58 minutes'
) on conflict (id) do nothing;

-- Dedicated Phase 10 truck and driver keep the Phase 9 Fleet demo trip untouched.
insert into public.employees(
  id,organization_id,employee_code,full_name,email,phone,primary_factory_id,
  department_id,designation_id,shift_id,join_date,employment_type,status
) values (
  '98400000-0000-4000-8000-000000000009',
  '10000000-0000-4000-8000-000000000001',
  'EMP-P10-D01','Ravi Patil','ravi.dispatch.demo@example.com','+91 90000 13010',
  '20000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000005',
  '32000000-0000-4000-8000-000000000006',
  '33000000-0000-4000-8000-000000000001',
  '2026-04-01','full_time','active'
) on conflict (id) do nothing;

insert into public.stock_locations(
  id,organization_id,factory_id,name,code,location_type,is_active
) values (
  '98400000-0000-4000-8000-000000000010',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'Vehicle DSP10','VEH-DSP10','vehicle',true
) on conflict (id) do nothing;

insert into public.fleet_vehicles(
  id,organization_id,factory_id,stock_location_id,vehicle_code,registration_no,vehicle_type,
  make,model,model_year,fuel_type,capacity_quantity,capacity_unit,current_odometer_km,
  insurance_expiry,fitness_expiry,permit_expiry,puc_expiry,status,notes
) values (
  '98400000-0000-4000-8000-000000000011',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000010',
  'DSP10','DEMO-MH13-DSP10','truck','Aarohan Demo Motors','Cargo 4T',2025,'diesel',
  80,'cylinders',12100,current_date+180,current_date+210,current_date+190,current_date+45,
  'active','Dedicated fictional Phase 10 delivery truck'
) on conflict (id) do nothing;

insert into public.fleet_drivers(
  id,organization_id,factory_id,employee_id,license_no,license_type,license_expiry,
  emergency_phone,status,notes
) values (
  '98400000-0000-4000-8000-000000000012',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000009',
  'DEMO-LIC-P10-001','HMV',current_date+500,'+91 90000 13999','active',
  'Dedicated fictional Phase 10 driver'
) on conflict (id) do nothing;

insert into public.fleet_vehicle_driver_assignments(
  id,organization_id,factory_id,vehicle_id,driver_id,effective_from,notes
) values (
  '98400000-0000-4000-8000-000000000013',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000011',
  '98400000-0000-4000-8000-000000000012',
  now()-interval '15 days','Dedicated Phase 10 vehicle-driver assignment'
) on conflict (id) do nothing;

insert into public.fleet_trips(
  id,organization_id,factory_id,trip_no,vehicle_id,driver_id,sales_order_id,warehouse_handoff_id,
  origin,destination,status,planned_start_at,planned_end_at,notes,created_at
) values (
  '98400000-0000-4000-8000-000000000014',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'TRIP-DEMO-P10-001',
  '98400000-0000-4000-8000-000000000011',
  '98400000-0000-4000-8000-000000000012',
  '98400000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000008',
  'Aarohan Solapur Plant','Sunrise Care Hospital','assigned',
  now()+interval '1 hour',now()+interval '5 hours',
  'Dedicated fictional Phase 10 delivery trip',now()-interval '50 minutes'
) on conflict (id) do nothing;

-- Ready-to-load Dispatch record uses only Phase 10-owned mutable fixtures.
insert into public.dispatch_deliveries(
  id,organization_id,factory_id,delivery_no,warehouse_handoff_id,trip_id,sales_order_id,
  customer_id,vehicle_id,driver_id,staging_location_id,vehicle_location_id,status,notes,created_at
) values (
  '98400000-0000-4000-8000-000000000015',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'DEL-DEMO-P10-001',
  '98400000-0000-4000-8000-000000000008',
  '98400000-0000-4000-8000-000000000014',
  '98400000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000003',
  '98400000-0000-4000-8000-000000000011',
  '98400000-0000-4000-8000-000000000012',
  '96000000-0000-4000-8000-000000000006',
  '98400000-0000-4000-8000-000000000010',
  'ready_to_load','Fictional Phase 10 delivery ready for Admin load confirmation',
  now()-interval '45 minutes'
) on conflict (id) do nothing;

insert into public.dispatch_delivery_lines(
  id,organization_id,delivery_id,warehouse_pick_line_id,sales_order_line_id,item_id,planned_quantity
) values (
  '98400000-0000-4000-8000-000000000016',
  '10000000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000015',
  '98400000-0000-4000-8000-000000000007',
  '98400000-0000-4000-8000-000000000002',
  '43000000-0000-4000-8000-000000000006',4
) on conflict (id) do nothing;
