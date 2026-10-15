-- FactoryOS Purchase GRN / Goods Receipt command.
-- Applies after 04_purchase.sql and the Inventory ledger schemas.
--
-- Accepted Purchase quantities enter stock only through the immutable purchase_receipt ledger.
-- Rejected quantities never create stock. The full GRN + ledger post is one transaction.

create or replace function public.post_purchase_goods_receipt(
  target_purchase_order_id uuid,
  target_warehouse_id uuid,
  target_supplier_invoice_number text,
  target_supplier_delivery_note text,
  target_note text,
  target_lines jsonb,
  target_idempotency_key text
)
returns public.goods_receipts
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor_id uuid := (select auth.uid());
  po public.purchase_orders;
  target_org_id uuid;
  target_factory_id uuid;
  target_supplier_id uuid;
  warehouse_org_id uuid;
  warehouse_factory_id uuid;
  warehouse_status public.entity_status;
  existing_tx public.stock_transactions;
  existing_grn public.goods_receipts;
  posted_tx public.stock_transactions;
  grn_id uuid;
  grn_number text;
  tx_id uuid;
  tx_number text;
  line_json jsonb;
  allocation_json jsonb;
  line_id uuid;
  pol public.purchase_order_lines;
  item public.items;
  received_qty numeric;
  accepted_qty numeric;
  rejected_qty numeric;
  prior_accepted numeric;
  total_accepted numeric := 0;
  allocation_total numeric;
  allocation_qty numeric;
  location_id uuid;
  location_warehouse_id uuid;
  location_status public.entity_status;
  batch_id uuid;
  allocation_batch_number text;
  batch_item_id uuid;
  batch_org_id uuid;
  batch_status public.entity_status;
  serial_id uuid;
  allocation_serial_number text;
  serial_item_id uuid;
  serial_org_id uuid;
  serial_current_warehouse_id uuid;
  serial_balance numeric;
  duplicate_serial_count bigint;
  incomplete_count bigint;
  payload_po_line_count bigint;
begin
  if actor_id is null then
    raise exception 'authentication required';
  end if;
  if length(btrim(coalesce(target_idempotency_key, ''))) < 8 then
    raise exception 'purchase receipt idempotency key is required';
  end if;
  if target_lines is null or jsonb_typeof(target_lines) <> 'array' or jsonb_array_length(target_lines) = 0 then
    raise exception 'purchase receipt requires at least one line';
  end if;

  select * into po
  from public.purchase_orders
  where id = target_purchase_order_id
  for update;

  if po.id is null then raise exception 'purchase order not found'; end if;
  if po.status not in ('approved','part_received') then
    raise exception 'purchase order must be approved and open for receiving';
  end if;

  target_org_id := po.organization_id;
  target_factory_id := po.factory_id;
  target_supplier_id := po.supplier_id;

  select w.organization_id, w.factory_id, w.status
    into warehouse_org_id, warehouse_factory_id, warehouse_status
  from public.warehouses w
  where w.id = target_warehouse_id;

  if warehouse_org_id is null or warehouse_status <> 'active' then
    raise exception 'purchase receipt warehouse is invalid or inactive';
  end if;
  if warehouse_org_id <> target_org_id or warehouse_factory_id is distinct from target_factory_id then
    raise exception 'purchase receipt warehouse does not belong to purchase order factory';
  end if;

  if not private.has_warehouse_permission(target_org_id, 'inventory.receive', target_warehouse_id) then
    raise exception 'purchase receipt permission denied';
  end if;
  if not private.has_warehouse_permission(target_org_id, 'inventory.post', target_warehouse_id) then
    raise exception 'inventory posting permission denied';
  end if;

  select * into existing_tx
  from public.stock_transactions st
  where st.organization_id = target_org_id
    and st.idempotency_key = btrim(target_idempotency_key)
  for update;

  if existing_tx.id is not null then
    select * into existing_grn
    from public.goods_receipts gr
    where gr.stock_transaction_id = existing_tx.id;

    if existing_tx.transaction_type <> 'purchase_receipt'
       or existing_tx.reference_type is distinct from 'goods_receipt'
       or existing_tx.status <> 'posted'
       or existing_grn.id is null
       or existing_grn.purchase_order_id <> target_purchase_order_id
       or existing_grn.warehouse_id <> target_warehouse_id then
      raise exception 'purchase receipt idempotency key conflict';
    end if;
    return existing_grn;
  end if;

  select count(*), count(distinct nullif(value->>'purchase_order_line_id',''))
    into payload_po_line_count, incomplete_count
  from jsonb_array_elements(target_lines);
  if payload_po_line_count <> incomplete_count then
    raise exception 'purchase receipt contains duplicate purchase order lines';
  end if;

  grn_number := 'GRN-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.goods_receipts(
    organization_id, factory_id, purchase_order_id, supplier_id, warehouse_id,
    grn_number, status, received_at, supplier_invoice_number, supplier_delivery_note,
    created_by, notes
  ) values (
    target_org_id, target_factory_id, target_purchase_order_id, target_supplier_id, target_warehouse_id,
    grn_number, 'draft', now(), nullif(btrim(coalesce(target_supplier_invoice_number,'')),''),
    nullif(btrim(coalesce(target_supplier_delivery_note,'')),''), actor_id,
    nullif(btrim(coalesce(target_note,'')),'')
  ) returning id into grn_id;

  tx_number := 'STK-PR-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  insert into public.stock_transactions(
    organization_id, factory_id, transaction_number, transaction_type, status,
    reference_type, reference_id, occurred_at, reason, idempotency_key, created_by
  ) values (
    target_org_id, target_factory_id, tx_number, 'purchase_receipt', 'draft',
    'goods_receipt', grn_id, now(), 'Purchase goods receipt ' || grn_number,
    btrim(target_idempotency_key), actor_id
  ) returning id into tx_id;

  for line_json in select value from jsonb_array_elements(target_lines)
  loop
    if nullif(line_json->>'purchase_order_line_id','') is null then
      raise exception 'purchase receipt line requires purchase_order_line_id';
    end if;

    select * into pol
    from public.purchase_order_lines
    where id = (line_json->>'purchase_order_line_id')::uuid
      and purchase_order_id = target_purchase_order_id;
    if pol.id is null then
      raise exception 'purchase receipt line is outside selected purchase order';
    end if;

    select * into item from public.items where id = pol.item_id;
    if item.id is null or item.organization_id <> target_org_id or item.status <> 'active' then
      raise exception 'purchase receipt item is invalid or inactive';
    end if;
    if item.batch_tracking and item.serial_tracking then
      raise exception 'purchase receipt item cannot require both batch and serial tracking';
    end if;

    received_qty := coalesce((line_json->>'received_quantity')::numeric, 0);
    accepted_qty := coalesce((line_json->>'accepted_quantity')::numeric, 0);
    rejected_qty := coalesce((line_json->>'rejected_quantity')::numeric, 0);

    if received_qty <= 0 then raise exception 'received quantity must be greater than zero'; end if;
    if accepted_qty < 0 or rejected_qty < 0 then raise exception 'accepted/rejected quantities cannot be negative'; end if;
    if accepted_qty + rejected_qty <> received_qty then
      raise exception 'accepted plus rejected quantity must equal received quantity';
    end if;

    select coalesce(sum(grl.accepted_quantity),0) into prior_accepted
    from public.goods_receipt_lines grl
    join public.goods_receipts gr on gr.id = grl.goods_receipt_id
    where grl.purchase_order_line_id = pol.id
      and gr.status = 'posted';

    if prior_accepted + accepted_qty > pol.ordered_quantity then
      raise exception 'purchase receipt accepted quantity exceeds purchase order pending quantity';
    end if;

    insert into public.goods_receipt_lines(
      organization_id, goods_receipt_id, purchase_order_line_id, item_id,
      received_quantity, accepted_quantity, rejected_quantity, supplier_batch_number, note
    ) values (
      target_org_id, grn_id, pol.id, pol.item_id,
      received_qty, accepted_qty, rejected_qty,
      nullif(btrim(coalesce(line_json->>'supplier_batch_number','')),''),
      nullif(btrim(coalesce(line_json->>'note','')),'')
    ) returning id into line_id;

    total_accepted := total_accepted + accepted_qty;

    if accepted_qty > 0 then
      if line_json->'allocations' is null
         or jsonb_typeof(line_json->'allocations') <> 'array'
         or jsonb_array_length(line_json->'allocations') = 0 then
        raise exception 'accepted purchase receipt quantity requires inventory allocations';
      end if;

      allocation_total := 0;
      for allocation_json in select value from jsonb_array_elements(line_json->'allocations')
      loop
        allocation_qty := coalesce((allocation_json->>'quantity')::numeric, 0);
        if allocation_qty <= 0 then raise exception 'purchase receipt allocation quantity must be positive'; end if;
        allocation_total := allocation_total + allocation_qty;

        location_id := nullif(allocation_json->>'location_id','')::uuid;
        if location_id is null then raise exception 'purchase receipt allocation requires warehouse location'; end if;
        select wl.warehouse_id, wl.status into location_warehouse_id, location_status
        from public.warehouse_locations wl where wl.id = location_id;
        if location_warehouse_id is distinct from target_warehouse_id or location_status <> 'active' then
          raise exception 'purchase receipt location does not belong to selected warehouse or is inactive';
        end if;

        batch_id := nullif(allocation_json->>'batch_id','')::uuid;
        allocation_batch_number := nullif(btrim(coalesce(allocation_json->>'batch_number','')),'');
        serial_id := nullif(allocation_json->>'serial_number_id','')::uuid;
        allocation_serial_number := nullif(btrim(coalesce(allocation_json->>'serial_number','')),'');

        if item.batch_tracking then
          if serial_id is not null or allocation_serial_number is not null then
            raise exception 'batch-tracked purchase item cannot use serial allocation';
          end if;
          if batch_id is null then
            if allocation_batch_number is null then raise exception 'batch-tracked purchase item requires batch'; end if;
            insert into public.batches(organization_id,item_id,batch_number,supplier_batch_number,status)
            values(target_org_id,item.id,allocation_batch_number,
                   nullif(btrim(coalesce(line_json->>'supplier_batch_number','')),''),'active')
            on conflict (organization_id,item_id,batch_number) do update
              set supplier_batch_number = coalesce(excluded.supplier_batch_number, public.batches.supplier_batch_number)
            returning id into batch_id;
          end if;
          select b.item_id,b.organization_id,b.status into batch_item_id,batch_org_id,batch_status
          from public.batches b where b.id=batch_id;
          if batch_item_id is distinct from item.id or batch_org_id is distinct from target_org_id or batch_status <> 'active' then
            raise exception 'purchase receipt batch does not belong to selected item/organization or is inactive';
          end if;
        elsif item.serial_tracking then
          if batch_id is not null or allocation_batch_number is not null then
            raise exception 'serial-tracked purchase item cannot use batch allocation';
          end if;
          if allocation_qty <> 1 then raise exception 'serial purchase allocation quantity must be exactly one'; end if;
          if serial_id is null then
            if allocation_serial_number is null then raise exception 'serial-tracked purchase item requires serial number'; end if;
            insert into public.serial_numbers(organization_id,item_id,serial_number,status)
            values(target_org_id,item.id,allocation_serial_number,'available')
            on conflict (organization_id,item_id,serial_number) do update set serial_number=excluded.serial_number
            returning id into serial_id;
          end if;
          select s.item_id,s.organization_id,s.current_warehouse_id
            into serial_item_id,serial_org_id,serial_current_warehouse_id
          from public.serial_numbers s where s.id=serial_id for update;
          if serial_item_id is distinct from item.id or serial_org_id is distinct from target_org_id then
            raise exception 'purchase receipt serial does not belong to selected item/organization';
          end if;
          select coalesce(sum(b.quantity_on_hand),0) into serial_balance
          from public.inventory_balances b
          where b.organization_id=target_org_id and b.item_id=item.id and b.serial_number_id=serial_id;
          if serial_current_warehouse_id is not null or serial_balance > 0 then
            raise exception 'purchase receipt serial is already in stock';
          end if;
        else
          if batch_id is not null or allocation_batch_number is not null or serial_id is not null or allocation_serial_number is not null then
            raise exception 'non-tracked purchase item cannot use batch or serial allocation';
          end if;
        end if;

        insert into public.stock_transaction_lines(
          organization_id, stock_transaction_id, item_id, batch_id, serial_number_id,
          warehouse_id, location_id, quantity_delta, unit_cost, note
        ) values (
          target_org_id, tx_id, item.id, batch_id, serial_id,
          target_warehouse_id, location_id, allocation_qty, pol.unit_price,
          grn_number || ' accepted purchase quantity'
        );
      end loop;

      if allocation_total <> accepted_qty then
        raise exception 'purchase receipt allocation total must equal accepted quantity';
      end if;
    end if;
  end loop;

  if total_accepted <= 0 then
    raise exception 'purchase receipt must contain accepted quantity to post inventory';
  end if;

  select count(*) into duplicate_serial_count
  from (
    select serial_number_id
    from public.stock_transaction_lines
    where stock_transaction_id=tx_id and serial_number_id is not null
    group by serial_number_id
    having count(*) > 1
  ) s;
  if duplicate_serial_count > 0 then
    raise exception 'purchase receipt contains duplicate serial number';
  end if;

  update public.goods_receipts
  set status='checked', checked_by=actor_id, checked_at=now()
  where id=grn_id;

  select * into posted_tx from public.post_stock_transaction(tx_id);

  update public.serial_numbers s
  set current_warehouse_id=l.warehouse_id,
      current_location_id=l.location_id,
      status='available'
  from public.stock_transaction_lines l
  where l.stock_transaction_id=tx_id
    and l.serial_number_id=s.id;

  update public.goods_receipts
  set status='posted', stock_transaction_id=posted_tx.id, checked_by=actor_id,
      checked_at=coalesce(checked_at,now())
  where id=grn_id
  returning * into existing_grn;

  select count(*) into incomplete_count
  from public.purchase_order_line_progress p
  where p.purchase_order_id=target_purchase_order_id
    and p.pending_quantity > 0;

  update public.purchase_orders
  set status = case when incomplete_count = 0 then 'received'::public.purchase_order_status
                    else 'part_received'::public.purchase_order_status end
  where id=target_purchase_order_id;

  insert into public.audit_logs(
    organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata
  ) values (
    target_org_id,target_factory_id,actor_id,'create','goods_receipt',grn_id::text,
    jsonb_build_object(
      'source','purchase_grn',
      'purchase_order_id',target_purchase_order_id,
      'warehouse_id',target_warehouse_id,
      'stock_transaction_id',posted_tx.id,
      'accepted_quantity',total_accepted,
      'idempotency_key',btrim(target_idempotency_key)
    )
  );

  return existing_grn;
end;
$$;

revoke all on function public.post_purchase_goods_receipt(uuid,uuid,text,text,text,jsonb,text) from public;
grant execute on function public.post_purchase_goods_receipt(uuid,uuid,text,text,text,jsonb,text) to authenticated;
