-- FactoryOS fictional Warehouse + Dispatch demo seed
-- Depends on all operational schemas through 11a_warehouse_dispatch_commands.sql.

insert into public.permissions(key,module_key,description)
values
  ('warehouse.read','warehouse','Read warehouse transfers and operational tasks'),
  ('warehouse.manage','warehouse','Manage warehouse transfers and operational tasks')
on conflict (key) do update set module_key=excluded.module_key,description=excluded.description;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r
join public.organizations o on o.id=r.organization_id and o.code='DKIM'
join public.permissions p on p.key in ('warehouse.read','warehouse.manage')
where r.key='company_owner'
   or r.key='factory_manager'
   or r.key='warehouse_manager'
   or (r.key='production_manager' and p.key='warehouse.read')
on conflict do nothing;

insert into public.warehouse_locations(organization_id,warehouse_id,code,name,zone,aisle,rack,bin)
select o.id,w.id,x.code,x.name,x.zone,x.aisle,x.rack,x.bin
from public.organizations o
join (values
  ('RM-WH','RM-STAGE-01','Production staging','RM-STAGE','S1','STAGE','01'),
  ('FG-WH','FG-STAGE-01','Dispatch staging','FG-STAGE','S1','STAGE','01')
) x(warehouse_code,code,name,zone,aisle,rack,bin) on true
join public.warehouses w on w.organization_id=o.id and w.code=x.warehouse_code
where o.code='DKIM'
on conflict (warehouse_id,code) do update set name=excluded.name,zone=excluded.zone,aisle=excluded.aisle,rack=excluded.rack,bin=excluded.bin;

insert into public.warehouse_transfers(
  organization_id,factory_id,transfer_number,source_warehouse_id,destination_warehouse_id,status,reason
)
select o.id,f.id,'TRF-2026-00218',w.id,w.id,'ready'::public.warehouse_transfer_status,'Production material staging'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.warehouses w on w.organization_id=o.id and w.code='RM-WH'
where o.code='DKIM'
on conflict (organization_id,transfer_number) do update set status=excluded.status,reason=excluded.reason;

insert into public.warehouse_transfer_lines(
  organization_id,warehouse_transfer_id,item_id,batch_id,source_location_id,destination_location_id,quantity
)
select wt.organization_id,wt.id,i.id,b.id,src.id,dst.id,x.qty
from public.warehouse_transfers wt
join public.organizations o on o.id=wt.organization_id and o.code='DKIM'
join (values
  ('RM-STEEL-001','RM-141026-03','RM-A-R03-B02',320::numeric),
  ('RM-PIPE-001','RM-101026-02','RM-B-R01-B04',160::numeric),
  ('RM-CHEM-001','RM-051026-01','RM-C-R02-B02',100::numeric)
) x(sku,batch_number,source_location,qty) on true
join public.items i on i.organization_id=o.id and i.sku=x.sku
join public.batches b on b.organization_id=o.id and b.item_id=i.id and b.batch_number=x.batch_number
join public.warehouse_locations src on src.warehouse_id=wt.source_warehouse_id and src.code=x.source_location
join public.warehouse_locations dst on dst.warehouse_id=wt.destination_warehouse_id and dst.code='RM-STAGE-01'
where wt.transfer_number='TRF-2026-00218'
on conflict (warehouse_transfer_id,item_id,batch_id,serial_number_id,source_location_id,destination_location_id)
do update set quantity=excluded.quantity;

-- Historical dispatch aligned with the existing in-transit delivery for SO-2026-01842.
insert into public.dispatch_orders(
  organization_id,factory_id,dispatch_number,sales_order_id,warehouse_id,trip_id,loading_bay,package_count,weight_kg,status,planned_at,started_at,loaded_at,dispatched_at,notes
)
select so.organization_id,so.factory_id,'DSP-2026-00417',so.id,w.id,t.id,'Bay 01',24,1280,'loaded'::public.dispatch_status,
       timestamptz '2026-10-14 09:45:00+05:30',timestamptz '2026-10-14 09:52:00+05:30',timestamptz '2026-10-14 10:24:00+05:30',null,
       'Fictional dispatch linked to existing delivery demo'
from public.sales_orders so
join public.organizations o on o.id=so.organization_id and o.code='DKIM'
join public.warehouses w on w.organization_id=o.id and w.code='FG-WH'
join public.trips t on t.organization_id=o.id and t.trip_number='TRIP-2026-00814'
where so.order_number='SO-2026-01842'
on conflict (organization_id,dispatch_number) do update set sales_order_id=excluded.sales_order_id,warehouse_id=excluded.warehouse_id,trip_id=excluded.trip_id,loading_bay=excluded.loading_bay,package_count=excluded.package_count,weight_kg=excluded.weight_kg,status='loaded'::public.dispatch_status,planned_at=excluded.planned_at,started_at=excluded.started_at,loaded_at=excluded.loaded_at,dispatched_at=null,notes=excluded.notes;

insert into public.dispatch_lines(
  organization_id,dispatch_order_id,sales_order_line_id,item_id,batch_id,source_location_id,planned_quantity,loaded_quantity
)
select d.organization_id,d.id,sol.id,sol.item_id,b.id,wl.id,x.qty,x.qty
from public.dispatch_orders d
join public.organizations o on o.id=d.organization_id and o.code='DKIM'
join (values
  ('FG-COMP-X','FG-131026-03','FG-B-R02-B03',80::numeric),
  ('FG-VALVE-25','FG-141026-04','FG-A-R01-B08',40::numeric)
) x(sku,batch_number,location_code,qty) on true
join public.sales_order_lines sol on sol.sales_order_id=d.sales_order_id
join public.items i on i.id=sol.item_id and i.sku=x.sku
join public.batches b on b.organization_id=o.id and b.item_id=i.id and b.batch_number=x.batch_number
join public.warehouse_locations wl on wl.warehouse_id=d.warehouse_id and wl.code=x.location_code
where d.dispatch_number='DSP-2026-00417'
on conflict (dispatch_order_id,sales_order_line_id) do update set batch_id=excluded.batch_id,source_location_id=excluded.source_location_id,planned_quantity=excluded.planned_quantity,loaded_quantity=excluded.loaded_quantity;

insert into public.dispatch_checks(organization_id,dispatch_order_id,check_key,label,is_required,is_complete,evidence_reference,completed_at)
select d.organization_id,d.id,x.check_key,x.label,true,true,x.evidence,timestamptz '2026-10-14 10:20:00+05:30'
from public.dispatch_orders d
join public.organizations o on o.id=d.organization_id and o.code='DKIM'
cross join (values
  ('invoice','Invoice generated','DEMO-INV-00417'),
  ('e_way_bill','E-way bill validated','DEMO-EWB-00417'),
  ('packing_list','Packing list complete','DEMO-PL-00417'),
  ('vehicle_weight','Vehicle weight captured','DEMO-WT-00417')
) x(check_key,label,evidence)
where d.dispatch_number='DSP-2026-00417'
on conflict (dispatch_order_id,check_key) do update set label=excluded.label,is_required=excluded.is_required,is_complete=excluded.is_complete,evidence_reference=excluded.evidence_reference,completed_at=excluded.completed_at;

insert into public.stock_transactions(
  organization_id,factory_id,transaction_number,transaction_type,status,reference_type,reference_id,occurred_at,reason,idempotency_key,posted_at
)
select d.organization_id,d.factory_id,d.dispatch_number||'-STK','sales_dispatch','posted','dispatch_order',d.id,
       timestamptz '2026-10-14 10:24:00+05:30','Fictional dispatch stock issue',d.id::text||':sales_dispatch',timestamptz '2026-10-14 10:24:00+05:30'
from public.dispatch_orders d
join public.organizations o on o.id=d.organization_id and o.code='DKIM'
where d.dispatch_number='DSP-2026-00417'
on conflict (organization_id,idempotency_key) do update set status='posted'::public.stock_transaction_status,posted_at=excluded.posted_at;

insert into public.stock_transaction_lines(
  organization_id,stock_transaction_id,item_id,batch_id,warehouse_id,location_id,quantity_delta,unit_cost,note
)
select dl.organization_id,st.id,dl.item_id,dl.batch_id,d.warehouse_id,dl.source_location_id,-dl.loaded_quantity,i.cost,'Historical dispatch issue'
from public.dispatch_lines dl
join public.dispatch_orders d on d.id=dl.dispatch_order_id and d.dispatch_number='DSP-2026-00417'
join public.stock_transactions st on st.organization_id=d.organization_id and st.idempotency_key=d.id::text||':sales_dispatch'
join public.items i on i.id=dl.item_id
where not exists(select 1 from public.stock_transaction_lines x where x.stock_transaction_id=st.id and x.item_id=dl.item_id and x.batch_id is not distinct from dl.batch_id and x.location_id is not distinct from dl.source_location_id);

update public.dispatch_lines dl
set stock_transaction_line_id=stl.id
from public.dispatch_orders d,public.stock_transactions st,public.stock_transaction_lines stl
where d.id=dl.dispatch_order_id and d.dispatch_number='DSP-2026-00417'
  and st.organization_id=d.organization_id and st.idempotency_key=d.id::text||':sales_dispatch'
  and stl.stock_transaction_id=st.id and stl.item_id=dl.item_id
  and stl.batch_id is not distinct from dl.batch_id and stl.location_id is not distinct from dl.source_location_id
  and dl.stock_transaction_line_id is null;

update public.dispatch_orders d
set status='dispatched',dispatched_at=timestamptz '2026-10-14 10:30:00+05:30'
from public.organizations o
where d.organization_id=o.id and o.code='DKIM' and d.dispatch_number='DSP-2026-00417';

insert into public.dispatch_events(organization_id,dispatch_order_id,event_type,event_at,note)
select d.organization_id,d.id,x.event_type,x.event_at,x.note
from public.dispatch_orders d
join public.organizations o on o.id=d.organization_id and o.code='DKIM'
cross join (values
  ('stock_posted',timestamptz '2026-10-14 10:24:00+05:30','Posted sales dispatch ledger'),
  ('loaded',timestamptz '2026-10-14 10:24:00+05:30','Load completed'),
  ('dispatched',timestamptz '2026-10-14 10:30:00+05:30','Handed to trip and delivery')
) x(event_type,event_at,note)
where d.dispatch_number='DSP-2026-00417'
  and not exists(select 1 from public.dispatch_events e where e.dispatch_order_id=d.id and e.event_type=x.event_type and e.event_at=x.event_at);

update public.sales_orders so
set status='dispatched'::public.sales_order_status
from public.organizations o
where so.organization_id=o.id and o.code='DKIM' and so.order_number='SO-2026-01842' and so.status not in ('delivered','closed','cancelled');
