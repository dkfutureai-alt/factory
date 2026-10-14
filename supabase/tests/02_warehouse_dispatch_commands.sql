\set ON_ERROR_STOP on

-- 1) Warehouse-scoped manager can complete a same-warehouse/location transfer without factory-wide escalation.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
select public.complete_warehouse_transfer((select id from public.warehouse_transfers where transfer_number='TRF-2026-00218'));
reset role;

select (status='completed' and out_stock_transaction_id is not null and in_stock_transaction_id is not null) as ok
from public.warehouse_transfers where transfer_number='TRF-2026-00218' \gset warehouse_transfer_
\if :warehouse_transfer_ok
\else
  \echo 'WAREHOUSE TEST FAILED: transfer did not complete with ledger links'
  select 1/0;
\endif

select (count(*)=2 and bool_and(status='posted')) as ok
from public.stock_transactions
where reference_type='warehouse_transfer'
  and reference_id=(select id from public.warehouse_transfers where transfer_number='TRF-2026-00218') \gset warehouse_ledger_pair_
\if :warehouse_ledger_pair_ok
\else
  \echo 'WAREHOUSE TEST FAILED: transfer ledger pair missing or unposted'
  select 1/0;
\endif

select (
  coalesce((select sum(quantity_delta) from public.stock_transaction_lines l join public.stock_transactions t on t.id=l.stock_transaction_id where t.reference_type='warehouse_transfer' and t.reference_id=(select id from public.warehouse_transfers where transfer_number='TRF-2026-00218')),0)=0
) as ok \gset warehouse_net_zero_
\if :warehouse_net_zero_ok
\else
  \echo 'WAREHOUSE TEST FAILED: transfer pair is not quantity-neutral'
  select 1/0;
\endif

-- Idempotent replay must not create extra stock transactions.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
select public.complete_warehouse_transfer((select id from public.warehouse_transfers where transfer_number='TRF-2026-00218'));
reset role;
select (count(*)=2) as ok from public.stock_transactions where reference_type='warehouse_transfer' and reference_id=(select id from public.warehouse_transfers where transfer_number='TRF-2026-00218') \gset warehouse_idempotent_
\if :warehouse_idempotent_ok
\else
  \echo 'WAREHOUSE TEST FAILED: idempotent replay duplicated ledger transactions'
  select 1/0;
\endif

-- 2) Build a deterministic dispatch fixture that is not present in the product demo.
-- Sales lines must be created before confirmation because confirmed orders are immutable.
insert into public.sales_orders(
  organization_id,factory_id,customer_id,order_number,order_date,requested_delivery_date,status,currency_code,delivery_method,ship_to_address_id,confirmed_at,notes
)
select o.id,f.id,c.id,'SO-CI-DSP-001',date '2026-10-14',date '2026-10-18','draft','INR','Company vehicle',a.id,null,'CI dispatch command fixture'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.customers c on c.organization_id=o.id and c.code='CUST-0042'
left join public.customer_delivery_addresses a on a.customer_id=c.id and a.is_default
where o.code='DKIM'
on conflict (organization_id,order_number) do update set status='draft',confirmed_at=null;

insert into public.sales_order_lines(organization_id,sales_order_id,item_id,ordered_quantity,unit_price,tax_rate)
select so.organization_id,so.id,i.id,10,455,0
from public.sales_orders so
join public.items i on i.organization_id=so.organization_id and i.sku='FG-COMP-X'
where so.order_number='SO-CI-DSP-001'
on conflict (sales_order_id,item_id) do update set ordered_quantity=10,unit_price=455;

update public.sales_orders
set status='ready',confirmed_at=now()
where order_number='SO-CI-DSP-001';

update public.trips t
set sales_order_id=so.id,status='assigned',actual_start_at=null,completed_at=null,block_reason=null
from public.sales_orders so
where t.trip_number='TRIP-2026-00818' and so.order_number='SO-CI-DSP-001' and t.organization_id=so.organization_id;

insert into public.dispatch_orders(
  organization_id,factory_id,dispatch_number,sales_order_id,warehouse_id,trip_id,loading_bay,package_count,weight_kg,status,planned_at,notes
)
select so.organization_id,so.factory_id,'DSP-CI-001',so.id,w.id,t.id,'Bay CI',1,85,'ready',now(),'CI dispatch fixture'
from public.sales_orders so
join public.warehouses w on w.organization_id=so.organization_id and w.code='FG-WH'
join public.trips t on t.organization_id=so.organization_id and t.trip_number='TRIP-2026-00818'
where so.order_number='SO-CI-DSP-001'
on conflict (organization_id,dispatch_number) do update set status='ready',trip_id=excluded.trip_id,started_at=null,loaded_at=null,dispatched_at=null;

insert into public.dispatch_lines(
  organization_id,dispatch_order_id,sales_order_line_id,item_id,batch_id,source_location_id,planned_quantity,loaded_quantity
)
select d.organization_id,d.id,sol.id,sol.item_id,b.id,wl.id,10,10
from public.dispatch_orders d
join public.sales_order_lines sol on sol.sales_order_id=d.sales_order_id
join public.items i on i.id=sol.item_id and i.sku='FG-COMP-X'
join public.batches b on b.organization_id=d.organization_id and b.item_id=i.id and b.batch_number='FG-131026-03'
join public.warehouse_locations wl on wl.warehouse_id=d.warehouse_id and wl.code='FG-B-R02-B03'
where d.dispatch_number='DSP-CI-001'
on conflict (dispatch_order_id,sales_order_line_id) do update set batch_id=excluded.batch_id,source_location_id=excluded.source_location_id,planned_quantity=10,loaded_quantity=10,stock_transaction_line_id=null;

insert into public.dispatch_checks(organization_id,dispatch_order_id,check_key,label,is_required,is_complete,evidence_reference,completed_at)
select d.organization_id,d.id,x.check_key,x.label,true,x.complete,case when x.complete then 'CI-EVIDENCE' else null end,case when x.complete then now() else null end
from public.dispatch_orders d
cross join (values
  ('invoice','Invoice generated',true),
  ('packing_list','Packing list complete',true),
  ('vehicle_weight','Vehicle weight captured',false)
) x(check_key,label,complete)
where d.dispatch_number='DSP-CI-001'
on conflict (dispatch_order_id,check_key) do update set is_required=true,is_complete=excluded.is_complete,evidence_reference=excluded.evidence_reference,completed_at=excluded.completed_at;

-- Owner posts dispatch inventory. The ledger link must be negative and immutable.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
select public.post_dispatch_stock((select id from public.dispatch_orders where dispatch_number='DSP-CI-001'));
reset role;

select (d.status='loaded' and dl.stock_transaction_line_id is not null and st.status='posted' and st.transaction_type='sales_dispatch' and stl.quantity_delta=-10) as ok
from public.dispatch_orders d
join public.dispatch_lines dl on dl.dispatch_order_id=d.id
join public.stock_transaction_lines stl on stl.id=dl.stock_transaction_line_id
join public.stock_transactions st on st.id=stl.stock_transaction_id
where d.dispatch_number='DSP-CI-001' \gset dispatch_stock_
\if :dispatch_stock_ok
\else
  \echo 'DISPATCH TEST FAILED: stock posting/reconciliation is incorrect'
  select 1/0;
\endif

-- Required check blocks finalization.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
do $$
declare failed_as_expected boolean:=false;
begin
  begin
    perform public.finalize_dispatch((select id from public.dispatch_orders where dispatch_number='DSP-CI-001'));
  exception when others then
    failed_as_expected:=position('required dispatch checks are incomplete' in sqlerrm)>0;
  end;
  if not failed_as_expected then raise exception 'DISPATCH TEST: incomplete required check did not block finalization'; end if;
end
$$;

update public.dispatch_checks set is_complete=true,evidence_reference='CI-WEIGHT',completed_at=now()
where dispatch_order_id=(select id from public.dispatch_orders where dispatch_number='DSP-CI-001') and check_key='vehicle_weight';

select public.finalize_dispatch((select id from public.dispatch_orders where dispatch_number='DSP-CI-001'));
reset role;

select (status='dispatched' and dispatched_at is not null) as ok from public.dispatch_orders where dispatch_number='DSP-CI-001' \gset dispatch_final_
\if :dispatch_final_ok
\else
  \echo 'DISPATCH TEST FAILED: dispatch did not finalize'
  select 1/0;
\endif

select (d.status='loaded' and dl.planned_quantity=10 and t.status='ready' and so.status='dispatched') as ok
from public.deliveries d
join public.delivery_lines dl on dl.delivery_id=d.id
join public.trips t on t.id=d.trip_id
join public.sales_orders so on so.id=d.sales_order_id
where so.order_number='SO-CI-DSP-001' \gset dispatch_handoff_
\if :dispatch_handoff_ok
\else
  \echo 'DISPATCH TEST FAILED: Delivery/Trip/Sales handoff is inconsistent'
  select 1/0;
\endif

-- Replaying both commands must not duplicate ledger or delivery rows.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
select public.post_dispatch_stock((select id from public.dispatch_orders where dispatch_number='DSP-CI-001'));
select public.finalize_dispatch((select id from public.dispatch_orders where dispatch_number='DSP-CI-001'));
reset role;
select (
  (select count(*) from public.stock_transactions where reference_type='dispatch_order' and reference_id=(select id from public.dispatch_orders where dispatch_number='DSP-CI-001'))=1
  and
  (select count(*) from public.deliveries where sales_order_id=(select id from public.sales_orders where order_number='SO-CI-DSP-001'))=1
) as ok \gset dispatch_idempotent_
\if :dispatch_idempotent_ok
\else
  \echo 'DISPATCH TEST FAILED: replay duplicated ledger or delivery records'
  select 1/0;
\endif

select set_config('request.jwt.claim.sub','',false);
\echo 'Warehouse/Dispatch command assertions passed.'
