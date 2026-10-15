-- FactoryOS Warehouse + Dispatch trusted command layer.
-- Keeps the golden rule: all stock changes are posted Inventory ledger transactions.

-- Warehouse-scoped staff may post a transaction only when every ledger line is in an
-- authorized warehouse. Factory/org-scoped behavior remains supported.
create or replace function public.post_stock_transaction(target_transaction_id uuid)
returns public.stock_transactions
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  tx public.stock_transactions;
  invalid_count bigint;
  warehouse_scope_allowed boolean;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;

  select * into tx from public.stock_transactions where id=target_transaction_id for update;
  if tx.id is null then raise exception 'stock transaction not found'; end if;
  if tx.status <> 'draft' then raise exception 'only draft stock transactions can be posted'; end if;
  if not exists(select 1 from public.stock_transaction_lines where stock_transaction_id=tx.id) then raise exception 'stock transaction has no lines'; end if;

  select not exists(
    select 1 from public.stock_transaction_lines l
    where l.stock_transaction_id=tx.id
      and not private.has_warehouse_permission(tx.organization_id,'inventory.post',l.warehouse_id)
  ) into warehouse_scope_allowed;

  if not (
    (tx.factory_id is not null and private.has_factory_permission(tx.organization_id,'inventory.post',tx.factory_id))
    or warehouse_scope_allowed
  ) then raise exception 'permission denied'; end if;

  select count(*) into invalid_count
  from public.stock_transaction_lines l
  join public.items i on i.id=l.item_id
  where l.stock_transaction_id=tx.id
    and (
      l.organization_id<>tx.organization_id
      or i.organization_id<>tx.organization_id
      or (i.batch_tracking and l.batch_id is null)
      or (i.serial_tracking and l.serial_number_id is null)
      or (i.serial_tracking and abs(l.quantity_delta)<>1)
    );
  if invalid_count>0 then raise exception 'stock transaction contains invalid tracking or organization data'; end if;

  select count(*) into invalid_count
  from (
    select l.organization_id,l.warehouse_id,l.location_id,l.item_id,l.batch_id,l.serial_number_id,
           coalesce(b.quantity_on_hand,0)+sum(l.quantity_delta) as projected
    from public.stock_transaction_lines l
    left join public.inventory_balances b
      on b.organization_id=l.organization_id
     and b.warehouse_id=l.warehouse_id
     and b.location_id is not distinct from l.location_id
     and b.item_id=l.item_id
     and b.batch_id is not distinct from l.batch_id
     and b.serial_number_id is not distinct from l.serial_number_id
    where l.stock_transaction_id=tx.id
    group by l.organization_id,l.warehouse_id,l.location_id,l.item_id,l.batch_id,l.serial_number_id,b.quantity_on_hand
    having coalesce(b.quantity_on_hand,0)+sum(l.quantity_delta)<0
  ) q;
  if invalid_count>0 then raise exception 'insufficient inventory'; end if;

  update public.stock_transactions
  set status='posted',posted_by=(select auth.uid()),posted_at=now()
  where id=tx.id returning * into tx;
  return tx;
end;
$$;

revoke all on function public.post_stock_transaction(uuid) from public;
grant execute on function public.post_stock_transaction(uuid) to authenticated;

create or replace function private.guard_dispatch_line_after_post()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.stock_transaction_line_id is not null then
    if tg_op='DELETE' then raise exception 'posted dispatch line is immutable'; end if;
    if new.sales_order_line_id is distinct from old.sales_order_line_id
       or new.item_id is distinct from old.item_id
       or new.batch_id is distinct from old.batch_id
       or new.serial_number_id is distinct from old.serial_number_id
       or new.source_location_id is distinct from old.source_location_id
       or new.planned_quantity is distinct from old.planned_quantity
       or new.loaded_quantity is distinct from old.loaded_quantity
       or new.stock_transaction_line_id is distinct from old.stock_transaction_line_id then
      raise exception 'posted dispatch line is immutable';
    end if;
  end if;
  return coalesce(new,old);
end;
$$;

drop trigger if exists dispatch_lines_guard_posted on public.dispatch_lines;
create trigger dispatch_lines_guard_posted before update or delete on public.dispatch_lines for each row execute function private.guard_dispatch_line_after_post();
revoke all on function private.guard_dispatch_line_after_post() from public;

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
  on conflict (organization_id,idempotency_key) do update set reason=excluded.reason
  returning id into out_tx;

  insert into public.stock_transactions(organization_id,factory_id,transaction_number,transaction_type,status,reference_type,reference_id,occurred_at,reason,idempotency_key,created_by)
  values(wt.organization_id,wt.factory_id,wt.transfer_number||'-IN','transfer_in','draft','warehouse_transfer',wt.id,now(),coalesce(wt.reason,'Warehouse transfer'),wt.id::text||':in',(select auth.uid()))
  on conflict (organization_id,idempotency_key) do update set reason=excluded.reason
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
  on conflict (organization_id,idempotency_key) do update set reason=excluded.reason
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

create or replace function public.finalize_dispatch(target_dispatch_id uuid)
returns public.dispatch_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  d public.dispatch_orders;
  trip_row public.trips;
  so public.sales_orders;
  delivery_id uuid;
  delivery_number text;
  invalid_count bigint;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  select * into d from public.dispatch_orders where id=target_dispatch_id for update;
  if d.id is null then raise exception 'dispatch order not found'; end if;
  if d.status='dispatched' then return d; end if;
  if d.status<>'loaded' then raise exception 'dispatch stock must be loaded before finalization'; end if;
  if not (private.has_factory_permission(d.organization_id,'dispatch.manage',d.factory_id)
          or private.has_warehouse_permission(d.organization_id,'dispatch.manage',d.warehouse_id)) then
    raise exception 'dispatch permission denied';
  end if;
  if d.trip_id is null then raise exception 'dispatch requires a trip'; end if;

  select * into trip_row from public.trips where id=d.trip_id for update;
  if trip_row.id is null or trip_row.organization_id<>d.organization_id or trip_row.factory_id is distinct from d.factory_id then raise exception 'dispatch trip scope mismatch'; end if;
  if trip_row.sales_order_id is distinct from d.sales_order_id then raise exception 'dispatch trip must reference the same sales order'; end if;
  if trip_row.status not in ('planned','assigned','ready') then raise exception 'dispatch trip is not ready'; end if;

  if exists(select 1 from public.dispatch_checks where dispatch_order_id=d.id and is_required and not is_complete) then raise exception 'required dispatch checks are incomplete'; end if;
  if not exists(select 1 from public.dispatch_lines where dispatch_order_id=d.id) then raise exception 'dispatch has no lines'; end if;
  if exists(select 1 from public.dispatch_lines where dispatch_order_id=d.id and loaded_quantity<>planned_quantity) then raise exception 'dispatch line quantities are not fully loaded'; end if;

  select count(*) into invalid_count
  from public.dispatch_lines dl
  left join public.stock_transaction_lines stl on stl.id=dl.stock_transaction_line_id
  left join public.stock_transactions st on st.id=stl.stock_transaction_id
  where dl.dispatch_order_id=d.id and (
    stl.id is null or st.status<>'posted' or st.transaction_type<>'sales_dispatch'
    or st.reference_type<>'dispatch_order' or st.reference_id<>d.id
    or stl.organization_id<>d.organization_id or stl.warehouse_id<>d.warehouse_id
    or stl.item_id<>dl.item_id or stl.batch_id is distinct from dl.batch_id
    or stl.serial_number_id is distinct from dl.serial_number_id
    or stl.location_id is distinct from dl.source_location_id
    or stl.quantity_delta<>-dl.loaded_quantity
  );
  if invalid_count>0 then raise exception 'dispatch ledger reconciliation failed'; end if;

  select * into so from public.sales_orders where id=d.sales_order_id;
  delivery_number:=regexp_replace(d.dispatch_number,'^DSP-','DEL-');
  select id into delivery_id from public.deliveries where organization_id=d.organization_id and trip_id=d.trip_id and sales_order_id=d.sales_order_id;

  if delivery_id is null then
    insert into public.deliveries(organization_id,factory_id,delivery_number,sales_order_id,trip_id,customer_id,ship_to_address_id,driver_employee_id,vehicle_id,planned_delivery_at,status,created_by,updated_by)
    values(d.organization_id,d.factory_id,delivery_number,d.sales_order_id,d.trip_id,so.customer_id,so.ship_to_address_id,trip_row.driver_employee_id,trip_row.vehicle_id,
           case when so.requested_delivery_date is null then null else so.requested_delivery_date::timestamptz+interval '10 hours' end,
           'loaded',(select auth.uid()),(select auth.uid()))
    returning id into delivery_id;
  elsif exists(select 1 from public.deliveries where id=delivery_id and status not in ('planned','loaded')) then
    raise exception 'existing delivery has already progressed beyond loading';
  end if;

  insert into public.delivery_lines(organization_id,delivery_id,sales_order_line_id,item_id,planned_quantity)
  select dl.organization_id,delivery_id,dl.sales_order_line_id,dl.item_id,dl.loaded_quantity
  from public.dispatch_lines dl where dl.dispatch_order_id=d.id
  on conflict (delivery_id,sales_order_line_id) do update set planned_quantity=excluded.planned_quantity;

  if not exists(select 1 from public.delivery_events where delivery_id=delivery_id and event_type='loaded') then
    insert into public.delivery_events(organization_id,delivery_id,event_type,actor_user_id,note) values(d.organization_id,delivery_id,'loaded',(select auth.uid()),'Created from finalized dispatch');
  end if;

  update public.dispatch_orders set status='dispatched',dispatched_at=now(),updated_by=(select auth.uid()) where id=d.id returning * into d;
  insert into public.dispatch_events(organization_id,dispatch_order_id,event_type,actor_user_id,note) values(d.organization_id,d.id,'dispatched',(select auth.uid()),'Dispatch finalized and handed to Delivery');

  if not exists(
    select 1 from public.sales_order_lines sol
    where sol.sales_order_id=d.sales_order_id
      and coalesce((select sum(dl.planned_quantity) from public.dispatch_lines dl join public.dispatch_orders dx on dx.id=dl.dispatch_order_id where dl.sales_order_line_id=sol.id and dx.status='dispatched'),0) < sol.ordered_quantity
  ) then
    update public.sales_orders set status='dispatched' where id=d.sales_order_id and status not in ('delivered','closed','cancelled');
  end if;

  update public.trips set status='ready',updated_by=(select auth.uid()) where id=d.trip_id and status in ('planned','assigned');
  return d;
end;
$$;

revoke all on function public.finalize_dispatch(uuid) from public;
grant execute on function public.finalize_dispatch(uuid) to authenticated;
