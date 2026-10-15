\set ON_ERROR_STOP on

-- CI-only fixture for the production completion RPC. This does not modify demo truth;
-- it creates an isolated order/batch with a posted finished-goods receipt and passed QC.
insert into public.production_orders (
  organization_id, factory_id, order_number, item_id, planned_quantity,
  completed_quantity, rejected_quantity, status, production_line_id,
  planned_start_at, planned_end_at, actual_start_at, priority, notes
)
select o.id, f.id, 'PRD-CI-COMPLETE-001', i.id, 5,
       0, 0, 'in_production', pl.id,
       now() - interval '1 hour', now() + interval '1 hour', now() - interval '45 minutes', 2,
       'CI-only production completion fixture'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.items i on i.organization_id=o.id and i.sku='FG-COMP-X'
join public.production_lines pl on pl.organization_id=o.id and pl.factory_id=f.id and pl.code='LINE-02'
where o.code='DKIM'
on conflict (organization_id, order_number) do update set
  status='in_production', completed_quantity=0, rejected_quantity=0, actual_end_at=null;

insert into public.production_batches (
  organization_id, factory_id, production_order_id, batch_number, status,
  planned_quantity, good_quantity, rejected_quantity, waste_quantity,
  production_line_id, started_at, completed_at, notes
)
select po.organization_id, po.factory_id, po.id, 'PB-CI-COMPLETE-001', 'in_production',
       5, 5, 0, 0, po.production_line_id, now() - interval '45 minutes', null,
       'CI-only completion batch'
from public.production_orders po
where po.order_number='PRD-CI-COMPLETE-001'
on conflict (organization_id, batch_number) do update set
  status='in_production', good_quantity=5, rejected_quantity=0, waste_quantity=0, completed_at=null;

insert into public.quality_checks (
  organization_id, factory_id, check_number, production_batch_id,
  inspected_at, result, inspected_quantity, rejected_quantity, notes
)
select pb.organization_id, pb.factory_id, 'QC-CI-COMPLETE-001', pb.id,
       now(), 'pass', 5, 0, 'CI-only passed quality check'
from public.production_batches pb
where pb.batch_number='PB-CI-COMPLETE-001'
on conflict (organization_id, check_number) do update set
  result='pass', inspected_quantity=5, rejected_quantity=0, inspected_at=excluded.inspected_at;

insert into public.stock_transactions (
  organization_id, factory_id, transaction_number, transaction_type, status,
  reference_type, reference_id, occurred_at, reason, idempotency_key, posted_at
)
select pb.organization_id, pb.factory_id, 'STK-CI-FG-RECEIPT-001', 'finished_goods_receipt', 'posted',
       'production_batch', pb.id, now(), 'CI-only finished goods receipt',
       'ci:production:complete:PB-CI-COMPLETE-001', now()
from public.production_batches pb
where pb.batch_number='PB-CI-COMPLETE-001'
on conflict (organization_id, transaction_number) do update set
  status='posted', posted_at=coalesce(stock_transactions.posted_at, excluded.posted_at);

insert into public.stock_transaction_lines (
  organization_id, stock_transaction_id, item_id, warehouse_id, location_id,
  quantity_delta, unit_cost, note
)
select st.organization_id, st.id, po.item_id, w.id, wl.id,
       5, i.cost, 'CI-only completed production output'
from public.stock_transactions st
join public.production_batches pb on pb.id=st.reference_id and st.reference_type='production_batch'
join public.production_orders po on po.id=pb.production_order_id
join public.items i on i.id=po.item_id
join public.warehouses w on w.organization_id=st.organization_id and w.code='FG-WH'
join public.warehouse_locations wl on wl.warehouse_id=w.id and wl.code='FG-B-R02-B03'
where st.transaction_number='STK-CI-FG-RECEIPT-001'
  and not exists (
    select 1 from public.stock_transaction_lines l
    where l.stock_transaction_id=st.id and l.item_id=po.item_id and l.quantity_delta=5
  );

insert into public.production_outputs (
  organization_id, production_batch_id, item_id, quantity, output_type, stock_transaction_line_id
)
select pb.organization_id, pb.id, po.item_id, 5, 'good', l.id
from public.production_batches pb
join public.production_orders po on po.id=pb.production_order_id
join public.stock_transactions st on st.reference_type='production_batch' and st.reference_id=pb.id
  and st.transaction_number='STK-CI-FG-RECEIPT-001'
join public.stock_transaction_lines l on l.stock_transaction_id=st.id and l.item_id=po.item_id and l.quantity_delta=5
where pb.batch_number='PB-CI-COMPLETE-001'
  and not exists (
    select 1 from public.production_outputs x
    where x.production_batch_id=pb.id and x.output_type='good' and x.stock_transaction_line_id=l.id
  );

select id as target_batch_id from public.production_batches where batch_number='PB-CI-COMPLETE-001' \gset
select set_config('factoryos.test.target_batch_id', :'target_batch_id', false);

-- A warehouse-scoped manager has no production.complete permission and must be denied.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
do $$
declare
  target uuid := current_setting('factoryos.test.target_batch_id')::uuid;
  denied boolean := false;
begin
  begin
    perform public.complete_production_batch(target);
  exception when others then
    denied := position('permission denied' in sqlerrm) > 0;
  end;
  if not denied then
    raise exception 'PRODUCTION COMMAND TEST: unauthorized warehouse role completed production batch';
  end if;
end
$$;
reset role;

-- Existing QC-hold demo batch must remain blocked even for an authorized factory manager.
select id as hold_batch_id from public.production_batches where batch_number='PB-141026-A06' \gset
select set_config('factoryos.test.hold_batch_id', :'hold_batch_id', false);
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
set role authenticated;
do $$
declare
  target uuid := current_setting('factoryos.test.hold_batch_id')::uuid;
  denied boolean := false;
begin
  begin
    perform public.complete_production_batch(target);
  exception when others then
    denied := position('passed quality check required' in sqlerrm) > 0;
  end;
  if not denied then
    raise exception 'PRODUCTION COMMAND TEST: QC-hold batch bypassed quality gate';
  end if;
end
$$;
reset role;

-- Factory-scoped manager is authorized and the verified fixture should complete.
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
set role authenticated;
select public.complete_production_batch(current_setting('factoryos.test.target_batch_id')::uuid);
reset role;

select (
  pb.status='completed'
  and pb.completed_at is not null
  and po.status='completed'
  and po.completed_quantity=5
  and po.rejected_quantity=0
  and po.actual_end_at is not null
) as ok
from public.production_batches pb
join public.production_orders po on po.id=pb.production_order_id
where pb.id=current_setting('factoryos.test.target_batch_id')::uuid
\gset production_complete_
\if :production_complete_ok
\else
  \echo 'PRODUCTION COMMAND TEST FAILED: completion did not reconcile batch/order state'
  select 1/0;
\endif
