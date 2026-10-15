\set ON_ERROR_STOP on

-- CI-only fixture proving dispatch stock cannot post before every planned unit is loaded.
insert into public.sales_orders(
  organization_id,factory_id,customer_id,order_number,order_date,requested_delivery_date,status,currency_code,delivery_method,notes
)
select o.id,f.id,c.id,'SO-CI-DSP-PARTIAL',date '2026-10-15',date '2026-10-19','draft','INR','Company vehicle','CI partial-load guard fixture'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.customers c on c.organization_id=o.id and c.code='CUST-0042'
where o.code='DKIM'
on conflict (organization_id,order_number) do update set status='draft',confirmed_at=null;

insert into public.sales_order_lines(organization_id,sales_order_id,item_id,ordered_quantity,unit_price,tax_rate)
select so.organization_id,so.id,i.id,10,455,0
from public.sales_orders so
join public.items i on i.organization_id=so.organization_id and i.sku='FG-COMP-X'
where so.order_number='SO-CI-DSP-PARTIAL'
on conflict (sales_order_id,item_id) do update set ordered_quantity=10,unit_price=455;

update public.sales_orders
set status='ready',confirmed_at=now()
where order_number='SO-CI-DSP-PARTIAL';

update public.trips t
set sales_order_id=so.id,status='assigned',actual_start_at=null,completed_at=null,block_reason=null
from public.sales_orders so
where t.trip_number='TRIP-2026-00820'
  and so.order_number='SO-CI-DSP-PARTIAL'
  and t.organization_id=so.organization_id;

insert into public.dispatch_orders(
  organization_id,factory_id,dispatch_number,sales_order_id,warehouse_id,trip_id,
  loading_bay,package_count,weight_kg,status,planned_at,notes
)
select so.organization_id,so.factory_id,'DSP-CI-PARTIAL',so.id,w.id,t.id,
       'Bay Partial',1,85,'ready',now(),'CI partial-load guard fixture'
from public.sales_orders so
join public.warehouses w on w.organization_id=so.organization_id and w.code='FG-WH'
join public.trips t on t.organization_id=so.organization_id and t.trip_number='TRIP-2026-00820'
where so.order_number='SO-CI-DSP-PARTIAL'
on conflict (organization_id,dispatch_number) do update
set status='ready',trip_id=excluded.trip_id,started_at=null,loaded_at=null,dispatched_at=null;

insert into public.dispatch_lines(
  organization_id,dispatch_order_id,sales_order_line_id,item_id,batch_id,source_location_id,
  planned_quantity,loaded_quantity
)
select d.organization_id,d.id,sol.id,sol.item_id,b.id,wl.id,10,5
from public.dispatch_orders d
join public.sales_order_lines sol on sol.sales_order_id=d.sales_order_id
join public.items i on i.id=sol.item_id and i.sku='FG-COMP-X'
join public.batches b on b.organization_id=d.organization_id and b.item_id=i.id and b.batch_number='FG-131026-03'
join public.warehouse_locations wl on wl.warehouse_id=d.warehouse_id and wl.code='FG-B-R02-B03'
where d.dispatch_number='DSP-CI-PARTIAL'
on conflict (dispatch_order_id,sales_order_line_id) do update
set batch_id=excluded.batch_id,source_location_id=excluded.source_location_id,
    planned_quantity=10,loaded_quantity=5,stock_transaction_line_id=null;

-- Resolve the target outside authenticated RLS. The command itself still executes as the
-- authenticated company owner and remains responsible for its own permission checks.
select set_config(
  'factoryos.test.partial_dispatch_id',
  (select id::text from public.dispatch_orders where dispatch_number='DSP-CI-PARTIAL'),
  false
);

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
do $$
declare failed_as_expected boolean:=false;
begin
  begin
    perform public.post_dispatch_stock(current_setting('factoryos.test.partial_dispatch_id')::uuid);
  exception when others then
    failed_as_expected:=position('fully loaded' in sqlerrm)>0;
  end;
  if not failed_as_expected then
    raise exception 'DISPATCH PARTIAL TEST: partial load was allowed to post stock';
  end if;
end
$$;
reset role;

select (
  d.status='ready'
  and dl.stock_transaction_line_id is null
  and not exists(
    select 1 from public.stock_transactions st
    where st.reference_type='dispatch_order' and st.reference_id=d.id
  )
) as ok
from public.dispatch_orders d
join public.dispatch_lines dl on dl.dispatch_order_id=d.id
where d.dispatch_number='DSP-CI-PARTIAL' \gset partial_guard_
\if :partial_guard_ok
\else
  \echo 'DISPATCH PARTIAL TEST FAILED: guard left posted or mutated state'
  select 1/0;
\endif

select set_config('request.jwt.claim.sub','',false);
select set_config('factoryos.test.partial_dispatch_id','',false);
\echo 'Dispatch partial-load guard assertions passed.'
