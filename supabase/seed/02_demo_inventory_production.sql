-- FactoryOS inventory + production demo seed
-- Depends on schemas 01_core.sql, 02_inventory.sql, 03_production_quality.sql and seed 01_demo_foundation.sql.
-- Uses only fictional business data. Auth-linked supervisor/inspector fields remain null until demo auth users exist.

insert into public.permissions (key, module_key, description)
values
  ('inventory.manage', 'inventory', 'Manage items, categories, units, batches and serials'),
  ('inventory.transact', 'inventory', 'Create and edit draft stock transactions'),
  ('inventory.post', 'inventory', 'Post inventory ledger transactions'),
  ('production.manage', 'production', 'Manage production lines, orders, batches and material/output links'),
  ('quality.manage', 'quality', 'Manage quality checks and parameters')
on conflict (key) do update set module_key = excluded.module_key, description = excluded.description;

-- Grant the newly introduced permissions to suitable demo roles.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id = r.organization_id and o.code = 'DKIM'
join public.permissions p on (
  r.key = 'company_owner'
  or (r.key = 'factory_manager' and p.key = any(array['inventory.transact','inventory.post','production.manage','quality.manage']))
  or (r.key = 'warehouse_manager' and p.key = any(array['inventory.manage','inventory.transact','inventory.post']))
  or (r.key = 'production_manager' and p.key = any(array['inventory.transact','inventory.post','production.manage','quality.manage']))
  or (r.key = 'supervisor' and p.key = any(array['inventory.transact','production.manage']))
)
where p.key = any(array['inventory.manage','inventory.transact','inventory.post','production.manage','quality.manage'])
on conflict do nothing;

insert into public.item_categories (organization_id, code, name, category_type)
select o.id, v.code, v.name, v.kind
from public.organizations o
cross join (values
  ('RAW','Raw Materials','raw_material'),
  ('PACK','Packaging','packaging'),
  ('CONS','Consumables','consumable'),
  ('SPARE','Spare Parts','spare_part'),
  ('FG','Finished Goods','finished_good')
) v(code,name,kind)
where o.code = 'DKIM'
on conflict (organization_id, code) do update set name = excluded.name, category_type = excluded.category_type;

insert into public.item_units (organization_id, code, name, decimal_places)
select o.id, v.code, v.name, v.dp
from public.organizations o
cross join (values
  ('PCS','Pieces',0),('KG','Kilogram',3),('LTR','Litre',3),('MTR','Metre',2),('BOX','Box',0)
) v(code,name,dp)
where o.code = 'DKIM'
on conflict (organization_id, code) do update set name = excluded.name, decimal_places = excluded.decimal_places;

insert into public.warehouse_locations (organization_id, warehouse_id, code, name, zone, aisle, rack, bin)
select o.id, w.id, v.code, v.name, v.zone, v.aisle, v.rack, v.bin
from public.organizations o
join public.warehouses w on w.organization_id = o.id
join (values
  ('RM-WH','RM-A-R03-B02','Steel Storage','RM-A','03','R03','B02'),
  ('RM-WH','RM-B-R01-B04','Pipe Storage','RM-B','01','R01','B04'),
  ('RM-WH','RM-C-R02-B02','Chemical Storage','RM-C','02','R02','B02'),
  ('FG-WH','FG-A-R01-B08','Valve Finished Goods','FG-A','01','R01','B08'),
  ('FG-WH','FG-B-R02-B03','Component Finished Goods','FG-B','02','R02','B03'),
  ('SP-WH','SP-A-R04-B03','Bearing & Belts','SP-A','04','R04','B03')
) v(warehouse_code,code,name,zone,aisle,rack,bin) on v.warehouse_code = w.code
where o.code = 'DKIM'
on conflict (warehouse_id, code) do update set name=excluded.name, zone=excluded.zone, aisle=excluded.aisle, rack=excluded.rack, bin=excluded.bin;

insert into public.items (
  organization_id, category_id, unit_id, sku, name, barcode, qr_identifier,
  cost, selling_price, minimum_stock, maximum_stock, reorder_level, batch_tracking
)
select o.id, c.id, u.id, v.sku, v.name, v.barcode, v.qr, v.cost, v.price, v.min_stock, v.max_stock, v.reorder, v.batch_tracking
from public.organizations o
join (values
  ('RM-STEEL-001','MS Steel Sheet 2mm','RAW','KG','890100000001','QR-RM-STEEL-001',72.50,null,400,3000,600,true),
  ('RM-PIPE-001','Industrial Pipe 25mm','RAW','PCS','890100000002','QR-RM-PIPE-001',185.00,null,150,1500,200,true),
  ('RM-CHEM-001','Production Chemical A','RAW','LTR','890100000003','QR-RM-CHEM-001',96.00,null,100,800,150,true),
  ('PK-CARTON-014','Heavy Duty Carton 14in','PACK','PCS','890100000004','QR-PK-CARTON-014',22.00,null,250,2500,300,false),
  ('PK-LABEL-001','Product Label Standard','PACK','PCS','890100000005','QR-PK-LABEL-001',1.50,null,1000,10000,1500,false),
  ('CONS-GLOVE-001','Industrial Safety Gloves','CONS','BOX','890100000006','QR-CONS-GLOVE-001',420.00,null,10,100,15,false),
  ('CONS-LUBE-001','Machine Lubricant','CONS','LTR','890100000007','QR-CONS-LUBE-001',315.00,null,25,250,40,false),
  ('SP-BRG-6204','Bearing 6204 ZZ','SPARE','PCS','890100000008','QR-SP-BRG-6204',265.00,null,8,80,12,false),
  ('SP-BELT-A42','V Belt A42','SPARE','PCS','890100000009','QR-SP-BELT-A42',340.00,null,5,40,8,false),
  ('FG-VALVE-25','Valve Assembly 25mm','FG','PCS','890100000010','QR-FG-VALVE-25',390.00,610.00,100,1200,150,true),
  ('FG-COMP-X','Industrial Component X','FG','PCS','890100000011','QR-FG-COMP-X',280.00,455.00,120,1500,180,true),
  ('FG-BRKT-A','Bracket Set A','FG','PCS','890100000012','QR-FG-BRKT-A',125.00,210.00,150,1800,220,true)
) v(sku,name,category_code,unit_code,barcode,qr,cost,price,min_stock,max_stock,reorder,batch_tracking) on true
join public.item_categories c on c.organization_id=o.id and c.code=v.category_code
join public.item_units u on u.organization_id=o.id and u.code=v.unit_code
where o.code='DKIM'
on conflict (organization_id, sku) do update set
  name=excluded.name, category_id=excluded.category_id, unit_id=excluded.unit_id,
  barcode=excluded.barcode, qr_identifier=excluded.qr_identifier, cost=excluded.cost,
  selling_price=excluded.selling_price, minimum_stock=excluded.minimum_stock,
  maximum_stock=excluded.maximum_stock, reorder_level=excluded.reorder_level,
  batch_tracking=excluded.batch_tracking;

insert into public.batches (organization_id, item_id, batch_number, manufactured_at)
select o.id, i.id, v.batch_number, v.mfg
from public.organizations o
join (values
  ('RM-STEEL-001','RM-141026-03','2026-10-01 08:00+05:30'::timestamptz),
  ('RM-PIPE-001','RM-101026-02','2026-10-10 09:00+05:30'::timestamptz),
  ('RM-CHEM-001','RM-051026-01','2026-10-05 11:00+05:30'::timestamptz),
  ('FG-VALVE-25','FG-141026-04','2026-10-14 11:30+05:30'::timestamptz),
  ('FG-COMP-X','FG-131026-03','2026-10-13 16:00+05:30'::timestamptz)
) v(sku,batch_number,mfg) on true
join public.items i on i.organization_id=o.id and i.sku=v.sku
where o.code='DKIM'
on conflict (organization_id,item_id,batch_number) do update set manufactured_at=excluded.manufactured_at;

-- Opening stock ledger. Seed is privileged and may insert historical posted records directly.
insert into public.stock_transactions (
  organization_id, factory_id, transaction_number, transaction_type, status, occurred_at, posted_at, reason
)
select o.id, f.id, 'STK-OPEN-2026-001', 'opening', 'posted', '2026-10-01 08:00+05:30', '2026-10-01 08:00+05:30', 'Demo opening stock'
from public.organizations o join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
where o.code='DKIM'
on conflict (organization_id,transaction_number) do nothing;

insert into public.stock_transaction_lines (
  organization_id, stock_transaction_id, item_id, batch_id, warehouse_id, location_id, quantity_delta, unit_cost, note
)
select o.id, st.id, i.id, b.id, w.id, wl.id, v.qty, i.cost, 'Demo opening balance'
from public.organizations o
join public.stock_transactions st on st.organization_id=o.id and st.transaction_number='STK-OPEN-2026-001'
join (values
  ('RM-STEEL-001','RM-141026-03','RM-WH','RM-A-R03-B02',1600::numeric),
  ('RM-PIPE-001','RM-101026-02','RM-WH','RM-B-R01-B04',420::numeric),
  ('RM-CHEM-001','RM-051026-01','RM-WH','RM-C-R02-B02',360::numeric),
  ('FG-VALVE-25','FG-141026-04','FG-WH','FG-A-R01-B08',120::numeric),
  ('FG-COMP-X','FG-131026-03','FG-WH','FG-B-R02-B03',300::numeric)
) v(sku,batch_number,warehouse_code,location_code,qty) on true
join public.items i on i.organization_id=o.id and i.sku=v.sku
join public.batches b on b.organization_id=o.id and b.item_id=i.id and b.batch_number=v.batch_number
join public.warehouses w on w.organization_id=o.id and w.code=v.warehouse_code
join public.warehouse_locations wl on wl.warehouse_id=w.id and wl.code=v.location_code
where o.code='DKIM'
  and not exists (
    select 1 from public.stock_transaction_lines x
    where x.stock_transaction_id=st.id and x.item_id=i.id and x.batch_id=b.id and x.warehouse_id=w.id
  );

-- Non-batch stock in the same opening transaction.
insert into public.stock_transaction_lines (organization_id,stock_transaction_id,item_id,warehouse_id,location_id,quantity_delta,unit_cost,note)
select o.id, st.id, i.id, w.id, wl.id, v.qty, i.cost, 'Demo opening balance'
from public.organizations o
join public.stock_transactions st on st.organization_id=o.id and st.transaction_number='STK-OPEN-2026-001'
join (values
  ('PK-CARTON-014','RM-WH','RM-A-R03-B02',860::numeric),
  ('PK-LABEL-001','RM-WH','RM-A-R03-B02',4200::numeric),
  ('CONS-GLOVE-001','SP-WH','SP-A-R04-B03',48::numeric),
  ('CONS-LUBE-001','SP-WH','SP-A-R04-B03',120::numeric),
  ('SP-BRG-6204','SP-WH','SP-A-R04-B03',9::numeric),
  ('SP-BELT-A42','SP-WH','SP-A-R04-B03',18::numeric)
) v(sku,warehouse_code,location_code,qty) on true
join public.items i on i.organization_id=o.id and i.sku=v.sku
join public.warehouses w on w.organization_id=o.id and w.code=v.warehouse_code
join public.warehouse_locations wl on wl.warehouse_id=w.id and wl.code=v.location_code
where o.code='DKIM'
  and not exists (select 1 from public.stock_transaction_lines x where x.stock_transaction_id=st.id and x.item_id=i.id);

insert into public.production_lines (organization_id,factory_id,code,name)
select o.id,f.id,v.code,v.name
from public.organizations o join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
cross join (values ('LINE-01','Assembly Line 01'),('LINE-02','Fabrication Line 02'),('LINE-03','Component Line 03')) v(code,name)
where o.code='DKIM'
on conflict (organization_id,factory_id,code) do update set name=excluded.name;

insert into public.production_orders (
  organization_id,factory_id,order_number,item_id,planned_quantity,completed_quantity,rejected_quantity,status,production_line_id,
  planned_start_at,planned_end_at,actual_start_at,priority,notes
)
select o.id,f.id,v.order_number,i.id,v.planned,v.completed,v.rejected,v.status::public.production_order_status,pl.id,v.start_at,v.end_at,v.actual_start,v.priority,v.notes
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join (values
 ('PRD-2026-01038','FG-COMP-X',500::numeric,420::numeric,8::numeric,'in_production','LINE-02','2026-10-14 09:00+05:30'::timestamptz,'2026-10-14 17:00+05:30'::timestamptz,'2026-10-14 09:08+05:30'::timestamptz,2,'72 units pending'),
 ('PRD-2026-01039','FG-VALVE-25',300::numeric,300::numeric,5::numeric,'qc_pending','LINE-01','2026-10-14 07:30+05:30'::timestamptz,'2026-10-14 13:00+05:30'::timestamptz,'2026-10-14 07:42+05:30'::timestamptz,1,'Awaiting final QC release'),
 ('PRD-2026-01040','FG-BRKT-A',700::numeric,0::numeric,0::numeric,'material_pending','LINE-03','2026-10-14 13:30+05:30'::timestamptz,'2026-10-14 21:30+05:30'::timestamptz,null::timestamptz,3,'Material request pending')
) v(order_number,sku,planned,completed,rejected,status,line_code,start_at,end_at,actual_start,priority,notes) on true
join public.items i on i.organization_id=o.id and i.sku=v.sku
join public.production_lines pl on pl.organization_id=o.id and pl.factory_id=f.id and pl.code=v.line_code
where o.code='DKIM'
on conflict (organization_id,order_number) do update set status=excluded.status, completed_quantity=excluded.completed_quantity, rejected_quantity=excluded.rejected_quantity, notes=excluded.notes;

insert into public.production_batches (
  organization_id,factory_id,production_order_id,batch_number,status,planned_quantity,good_quantity,rejected_quantity,waste_quantity,production_line_id,started_at,notes
)
select o.id,f.id,po.id,v.batch_number,v.status::public.production_batch_status,v.planned,v.good,v.rejected,v.waste,pl.id,v.started_at,v.notes
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join (values
 ('PRD-2026-01038','PB-141026-A06','in_production',500::numeric,420::numeric,8::numeric,2::numeric,'LINE-02','2026-10-14 09:08+05:30'::timestamptz,'Demo active batch'),
 ('PRD-2026-01039','PB-141026-A04','qc_pending',300::numeric,300::numeric,5::numeric,1::numeric,'LINE-01','2026-10-14 07:42+05:30'::timestamptz,'Demo QC pending batch')
) v(order_number,batch_number,status,planned,good,rejected,waste,line_code,started_at,notes) on true
join public.production_orders po on po.organization_id=o.id and po.order_number=v.order_number
join public.production_lines pl on pl.organization_id=o.id and pl.factory_id=f.id and pl.code=v.line_code
where o.code='DKIM'
on conflict (organization_id,batch_number) do update set status=excluded.status, good_quantity=excluded.good_quantity, rejected_quantity=excluded.rejected_quantity, waste_quantity=excluded.waste_quantity;

insert into public.quality_checks (
  organization_id,factory_id,check_number,production_batch_id,inspected_at,result,inspected_quantity,rejected_quantity,rejection_reason,corrective_action
)
select o.id,f.id,v.check_number,pb.id,v.inspected_at,v.result::public.quality_result,v.inspected,v.rejected,v.reason,v.action
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join (values
 ('QC-2026-00418','PB-141026-A06','2026-10-14 11:10+05:30'::timestamptz,'hold',428::numeric,8::numeric,'Dimensional tolerance on 8 units','Segregate and rework before final release'),
 ('QC-2026-00419','PB-141026-A04','2026-10-14 12:20+05:30'::timestamptz,'pending',305::numeric,5::numeric,'Surface finish review pending','Awaiting final inspector decision')
) v(check_number,batch_number,inspected_at,result,inspected,rejected,reason,action) on true
join public.production_batches pb on pb.organization_id=o.id and pb.batch_number=v.batch_number
where o.code='DKIM'
on conflict (organization_id,check_number) do update set result=excluded.result, inspected_quantity=excluded.inspected_quantity, rejected_quantity=excluded.rejected_quantity, rejection_reason=excluded.rejection_reason, corrective_action=excluded.corrective_action;

insert into public.quality_check_parameters (organization_id,quality_check_id,parameter_name,expected_result,actual_result,result,sort_order)
select o.id,q.id,v.parameter,v.expected,v.actual,v.result::public.quality_result,v.sort_order
from public.organizations o
join public.quality_checks q on q.organization_id=o.id and q.check_number='QC-2026-00418'
cross join (values
 ('Dimensions','Within drawing tolerance','8 units out of tolerance','hold',1),
 ('Surface finish','No visible burrs','Pass','pass',2),
 ('Functional fit','Assembly moves freely','Pass','pass',3)
) v(parameter,expected,actual,result,sort_order)
where o.code='DKIM'
  and not exists (select 1 from public.quality_check_parameters x where x.quality_check_id=q.id and x.parameter_name=v.parameter);