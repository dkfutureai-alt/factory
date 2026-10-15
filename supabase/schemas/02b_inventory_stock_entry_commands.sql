-- FactoryOS manual Inventory Stock Entry command.
-- Applies after 02_inventory.sql + 02a_inventory_review_fixes.sql.
--
-- Manual Stock Entry is intentionally limited to transaction_type='adjustment'.
-- Purchase, Production, Transfer, Dispatch, Return and Maintenance movements must continue
-- through their dedicated workflows. No command mutates inventory_balances directly.

create or replace function public.post_manual_stock_adjustment(
  target_warehouse_id uuid,
  target_location_id uuid,
  target_item_id uuid,
  target_batch_id uuid,
  target_serial_number_id uuid,
  target_quantity_delta numeric,
  target_unit_cost numeric,
  target_reason text,
  target_idempotency_key text
)
returns public.stock_transactions
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor_id uuid := (select auth.uid());
  target_org_id uuid;
  target_factory_id uuid;
  warehouse_status public.entity_status;
  item_org_id uuid;
  item_status public.entity_status;
  tracked_by_batch boolean;
  tracked_by_serial boolean;
  item_cost numeric(18,4);
  batch_item_id uuid;
  batch_org_id uuid;
  batch_status public.entity_status;
  serial_item_id uuid;
  serial_org_id uuid;
  serial_total numeric := 0;
  location_warehouse_id uuid;
  location_status public.entity_status;
  existing_tx public.stock_transactions;
  posted_tx public.stock_transactions;
  tx_id uuid;
  tx_number text;
  line_count bigint;
  line_matches bigint;
begin
  if actor_id is null then
    raise exception 'authentication required';
  end if;
  if target_quantity_delta is null or target_quantity_delta = 0 then
    raise exception 'stock adjustment quantity must be non-zero';
  end if;
  if target_unit_cost is not null and target_unit_cost < 0 then
    raise exception 'stock adjustment unit cost cannot be negative';
  end if;
  if length(btrim(coalesce(target_reason, ''))) < 5 then
    raise exception 'stock adjustment reason is required';
  end if;
  if length(btrim(coalesce(target_idempotency_key, ''))) < 8 then
    raise exception 'stock adjustment idempotency key is required';
  end if;

  select w.organization_id, w.factory_id, w.status
    into target_org_id, target_factory_id, warehouse_status
  from public.warehouses w
  where w.id = target_warehouse_id;
  if target_org_id is null or warehouse_status <> 'active' then
    raise exception 'stock adjustment warehouse is invalid or inactive';
  end if;

  select i.organization_id, i.status, i.batch_tracking, i.serial_tracking, i.cost
    into item_org_id, item_status, tracked_by_batch, tracked_by_serial, item_cost
  from public.items i
  where i.id = target_item_id;
  if item_org_id is null or item_org_id <> target_org_id or item_status <> 'active' then
    raise exception 'stock adjustment item is invalid, inactive or outside warehouse organization';
  end if;

  if not private.has_warehouse_permission(target_org_id, 'inventory.adjust', target_warehouse_id) then
    raise exception 'stock adjustment permission denied';
  end if;
  if not private.has_warehouse_permission(target_org_id, 'inventory.post', target_warehouse_id) then
    raise exception 'inventory posting permission denied';
  end if;

  if target_location_id is not null then
    select wl.warehouse_id, wl.status into location_warehouse_id, location_status
    from public.warehouse_locations wl where wl.id = target_location_id;
    if location_warehouse_id is distinct from target_warehouse_id or location_status <> 'active' then
      raise exception 'stock adjustment location does not belong to selected warehouse or is inactive';
    end if;
  end if;

  if tracked_by_batch and target_batch_id is null then
    raise exception 'batch-tracked item requires batch';
  end if;
  if not tracked_by_batch and target_batch_id is not null then
    raise exception 'non-batch item cannot use a batch';
  end if;
  if tracked_by_serial and target_serial_number_id is null then
    raise exception 'serial-tracked item requires serial number';
  end if;
  if not tracked_by_serial and target_serial_number_id is not null then
    raise exception 'non-serial item cannot use a serial number';
  end if;
  if tracked_by_serial and abs(target_quantity_delta) <> 1 then
    raise exception 'serial-tracked stock adjustment quantity must be exactly one unit';
  end if;

  if target_batch_id is not null then
    select b.item_id, b.organization_id, b.status into batch_item_id, batch_org_id, batch_status
    from public.batches b where b.id = target_batch_id;
    if batch_item_id is distinct from target_item_id
       or batch_org_id is distinct from target_org_id
       or batch_status <> 'active' then
      raise exception 'stock adjustment batch does not belong to selected item/organization or is inactive';
    end if;
  end if;

  if target_serial_number_id is not null then
    select s.item_id, s.organization_id into serial_item_id, serial_org_id
    from public.serial_numbers s where s.id = target_serial_number_id for update;
    if serial_item_id is distinct from target_item_id or serial_org_id is distinct from target_org_id then
      raise exception 'stock adjustment serial does not belong to selected item/organization';
    end if;

    select coalesce(sum(b.quantity_on_hand), 0) into serial_total
    from public.inventory_balances b
    where b.organization_id = target_org_id
      and b.item_id = target_item_id
      and b.serial_number_id = target_serial_number_id;
    if target_quantity_delta > 0 and serial_total > 0 then
      raise exception 'serial number is already in stock';
    end if;
  end if;

  select * into existing_tx
  from public.stock_transactions st
  where st.organization_id = target_org_id
    and st.idempotency_key = btrim(target_idempotency_key)
  for update;

  if existing_tx.id is not null then
    select count(*), count(*) filter (
      where l.item_id = target_item_id
        and l.batch_id is not distinct from target_batch_id
        and l.serial_number_id is not distinct from target_serial_number_id
        and l.warehouse_id = target_warehouse_id
        and l.location_id is not distinct from target_location_id
        and l.quantity_delta = target_quantity_delta
    )
    into line_count, line_matches
    from public.stock_transaction_lines l
    where l.stock_transaction_id = existing_tx.id;

    if existing_tx.transaction_type <> 'adjustment'
       or existing_tx.reference_type is distinct from 'manual_stock_adjustment'
       or existing_tx.status <> 'posted'
       or line_count <> 1
       or line_matches <> 1 then
      raise exception 'stock adjustment idempotency key conflict';
    end if;
    return existing_tx;
  end if;

  tx_number := 'ADJ-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.stock_transactions(
    organization_id, factory_id, transaction_number, transaction_type, status,
    reference_type, occurred_at, reason, idempotency_key, created_by
  ) values (
    target_org_id, target_factory_id, tx_number, 'adjustment', 'draft',
    'manual_stock_adjustment', now(), btrim(target_reason), btrim(target_idempotency_key), actor_id
  ) returning id into tx_id;

  insert into public.stock_transaction_lines(
    organization_id, stock_transaction_id, item_id, batch_id, serial_number_id,
    warehouse_id, location_id, quantity_delta, unit_cost, note
  ) values (
    target_org_id, tx_id, target_item_id, target_batch_id, target_serial_number_id,
    target_warehouse_id, target_location_id, target_quantity_delta,
    coalesce(target_unit_cost, item_cost), btrim(target_reason)
  );

  select * into posted_tx from public.post_stock_transaction(tx_id);

  if target_serial_number_id is not null then
    if target_quantity_delta > 0 then
      update public.serial_numbers
      set current_warehouse_id = target_warehouse_id,
          current_location_id = target_location_id,
          status = 'available'
      where id = target_serial_number_id;
    else
      update public.serial_numbers
      set current_warehouse_id = null,
          current_location_id = null,
          status = 'issued'
      where id = target_serial_number_id;
    end if;
  end if;

  insert into public.audit_logs(
    organization_id, factory_id, actor_user_id, action, entity_type, entity_id, metadata
  ) values (
    target_org_id, target_factory_id, actor_id, 'create', 'stock_transaction', tx_id::text,
    jsonb_build_object(
      'source', 'manual_stock_entry',
      'warehouse_id', target_warehouse_id,
      'location_id', target_location_id,
      'item_id', target_item_id,
      'quantity_delta', target_quantity_delta,
      'idempotency_key', btrim(target_idempotency_key)
    )
  );

  return posted_tx;
end;
$$;

revoke all on function public.post_manual_stock_adjustment(uuid,uuid,uuid,uuid,uuid,numeric,numeric,text,text) from public;
grant execute on function public.post_manual_stock_adjustment(uuid,uuid,uuid,uuid,uuid,numeric,numeric,text,text) to authenticated;
