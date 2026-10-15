-- FactoryOS Warehouse + Dispatch review fix.
-- Inventory review migration 02a replaces the nullable idempotency constraint with a
-- partial unique index, so command upserts must repeat the index predicate.

create or replace function public.complete_warehouse_transfer(target_transfer_id uuid)
returns public.warehouse_transfers
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  wt public.warehouse_transfers;
  out_tx uuid;
  in_tx uuid;
  line_count bigint;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  select * into wt from public.warehouse_transfers where id=target_transfer_id for update;
  if wt.id is null then raise exception 'warehouse transfer not found'; end if;
  if wt.status='completed' then return wt; end if;
  if wt.status not in ('ready','in_progress') then raise exception 'warehouse transfer is not ready for completion'; end if;
  if not private.has_warehouse_permission(wt.organization_id,'warehouse.manage',wt.source_warehouse_id)
     or not private.has_warehouse_permission(wt.organization_id,'warehouse.manage',wt.destination_warehouse_id) then
    raise exception 'warehouse transfer permission denied';
  end if;
  if not private.has_warehouse_permission(wt.organization_id,'inventory.post',wt.source_warehouse_id)
     or not private.has_warehouse_permission(wt.organization_id,'inventory.post',wt.destination_warehouse_id) then
    raise exception 'inventory posting permission denied';
  end if;

  select count(*) into line_count from public.warehouse_transfer_lines where warehouse_transfer_id=wt.id;
  if line_count=0 then raise exception 'warehouse transfer has no lines'; end if;

  insert into public.stock_transactions(organization_id,factory_id,transaction_number,transaction_type,status,reference_type,reference_id,occurred_at,reason,idempotency_key,created_by)
  values(wt.organization_id,wt.factory_id,wt.transfer_number||'-OUT','transfer_out','draft','warehouse_transfer',wt.id,now(),coalesce(wt.reason,'Warehouse transfer'),wt.id::text||':out',(select auth.uid()))
  on conflict (organization_id,idempotency_key) where idempotency_key is not null
  do update set reason=excluded.reason
  returning id into out_tx;

  insert into public.stock_transactions(organization_id,factory_id,transaction_number,transaction_type,status,reference_type,reference_id,occurred_at,reason,idempotency_key,created_by)
  values(wt.organization_id,wt.factory_id,wt.transfer_number||'-IN','transfer_in','draft','warehouse_transfer',wt.id,now(),coalesce(wt.reason,'Warehouse transfer'),wt.id::text||':in',(select auth.uid()))
  on conflict (organization_id,idempotency_key) where idempotency_key is not null
  do update set reason=excluded.reason
  returning id into in_tx;

  insert into public.stock_transaction_lines(organization_id,stock_transaction_id,item_id,batch_id,serial_number_id,warehouse_id,location_id,quantity_delta,unit_cost,note)
  select l.organization_id,out_tx,l.item_id,l.batch_id,l.serial_number_id,wt.source_warehouse_id,l.source_location_id,-l.quantity,i.cost,'Warehouse transfer out'
  from public.warehouse_transfer_lines l join public.items i on i.id=l.item_id
  where l.warehouse_transfer_id=wt.id
    and not exists(select 1 from public.stock_transaction_lines x where x.stock_transaction_id=out_tx and x.item_id=l.item_id and x.batch_id is not distinct from l.batch_id and x.serial_number_id is not distinct from l.serial_number_id and x.location_id is not distinct from l.source_location_id);

  insert into public.stock_transaction_lines(organization_id,stock_transaction_id,item_id,batch_id,serial_number_id,warehouse_id,location_id,quantity_delta,unit_cost,note)
  select l.organization_id,in_tx,l.item_id,l.batch_id,l.serial_number_id,wt.destination_warehouse_id,l.destination_location_id,l.quantity,i.cost,'Warehouse transfer in'
  from public.warehouse_transfer_lines l join public.items i on i.id=l.item_id
  where l.warehouse_transfer_id=wt.id
    and not exists(select 1 from public.stock_transaction_lines x where x.stock_transaction_id=in_tx and x.item_id=l.item_id and x.batch_id is not distinct from l.batch_id and x.serial_number_id is not distinct from l.serial_number_id and x.location_id is not distinct from l.destination_location_id);

  perform public.post_stock_transaction(out_tx);
  perform public.post_stock_transaction(in_tx);

  update public.warehouse_transfers
  set status='completed',started_at=coalesce(started_at,now()),completed_at=now(),out_stock_transaction_id=out_tx,in_stock_transaction_id=in_tx,updated_by=(select auth.uid())
  where id=wt.id returning * into wt;
  return wt;
end;
$$;

revoke all on function public.complete_warehouse_transfer(uuid) from public;
grant execute on function public.complete_warehouse_transfer(uuid) to authenticated;

create or replace function public.post_dispatch_stock(target_dispatch_id uuid)
returns public.dispatch_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  d public.dispatch_orders;
  tx_id uuid;
  invalid_count bigint;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  select * into d from public.dispatch_orders where id=target_dispatch_id for update;
  if d.id is null then raise exception 'dispatch order not found'; end if;
  if d.status in ('loaded','dispatched') then return d; end if;
  if d.status not in ('ready','loading') then raise exception 'dispatch is not ready for stock posting'; end if;
  if not (private.has_factory_permission(d.organization_id,'dispatch.manage',d.factory_id)
          or private.has_warehouse_permission(d.organization_id,'dispatch.manage',d.warehouse_id)) then
    raise exception 'dispatch permission denied';
  end if;
  if not private.has_warehouse_permission(d.organization_id,'inventory.post',d.warehouse_id) then
    raise exception 'inventory posting permission denied';
  end if;

  select count(*) into invalid_count from public.dispatch_lines l
  where l.dispatch_order_id=d.id and (l.loaded_quantity<=0 or l.source_location_id is null or l.stock_transaction_line_id is not null);
  if invalid_count>0 or not exists(select 1 from public.dispatch_lines where dispatch_order_id=d.id) then
    raise exception 'dispatch lines are not ready for posting';
  end if;

  insert into public.stock_transactions(organization_id,factory_id,transaction_number,transaction_type,status,reference_type,reference_id,occurred_at,reason,idempotency_key,created_by)
  values(d.organization_id,d.factory_id,d.dispatch_number||'-STK','sales_dispatch','draft','dispatch_order',d.id,now(),'Dispatch stock issue',d.id::text||':sales_dispatch',(select auth.uid()))
  on conflict (organization_id,idempotency_key) where idempotency_key is not null
  do update set reason=excluded.reason
  returning id into tx_id;

  insert into public.stock_transaction_lines(organization_id,stock_transaction_id,item_id,batch_id,serial_number_id,warehouse_id,location_id,quantity_delta,unit_cost,note)
  select l.organization_id,tx_id,l.item_id,l.batch_id,l.serial_number_id,d.warehouse_id,l.source_location_id,-l.loaded_quantity,i.cost,'Sales dispatch issue'
  from public.dispatch_lines l join public.items i on i.id=l.item_id
  where l.dispatch_order_id=d.id
    and not exists(select 1 from public.stock_transaction_lines x where x.stock_transaction_id=tx_id and x.item_id=l.item_id and x.batch_id is not distinct from l.batch_id and x.serial_number_id is not distinct from l.serial_number_id and x.location_id is not distinct from l.source_location_id);

  perform public.post_stock_transaction(tx_id);

  update public.dispatch_lines l
  set stock_transaction_line_id=x.id
  from public.stock_transaction_lines x
  where l.dispatch_order_id=d.id and x.stock_transaction_id=tx_id
    and x.item_id=l.item_id
    and x.batch_id is not distinct from l.batch_id
    and x.serial_number_id is not distinct from l.serial_number_id
    and x.location_id is not distinct from l.source_location_id;

  update public.dispatch_orders set status='loaded',started_at=coalesce(started_at,now()),loaded_at=now(),updated_by=(select auth.uid()) where id=d.id returning * into d;
  insert into public.dispatch_events(organization_id,dispatch_order_id,event_type,actor_user_id,note) values(d.organization_id,d.id,'stock_posted',(select auth.uid()),'Posted sales_dispatch ledger transaction');
  insert into public.dispatch_events(organization_id,dispatch_order_id,event_type,actor_user_id,note) values(d.organization_id,d.id,'loaded',(select auth.uid()),'All dispatch lines loaded and ledger-linked');
  return d;
end;
$$;

revoke all on function public.post_dispatch_stock(uuid) from public;
grant execute on function public.post_dispatch_stock(uuid) to authenticated;
