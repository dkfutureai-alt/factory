-- FactoryOS Purchase GRN idempotency replay fix.
-- Applies after 04a_purchase_receipt_commands.sql.
--
-- A successful full receipt can close the PO to `received`. Network retries with the same
-- idempotency key must resolve the already-posted GRN before the open-PO validation runs.

alter function public.post_purchase_goods_receipt(uuid,uuid,text,text,text,jsonb,text)
  rename to post_purchase_goods_receipt_v1;

revoke all on function public.post_purchase_goods_receipt_v1(uuid,uuid,text,text,text,jsonb,text) from public;
revoke all on function public.post_purchase_goods_receipt_v1(uuid,uuid,text,text,text,jsonb,text) from authenticated;

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
  target_org_id uuid;
  existing_tx public.stock_transactions;
  existing_grn public.goods_receipts;
begin
  if actor_id is null then
    raise exception 'authentication required';
  end if;
  if length(btrim(coalesce(target_idempotency_key, ''))) < 8 then
    raise exception 'purchase receipt idempotency key is required';
  end if;

  select organization_id into target_org_id
  from public.purchase_orders
  where id = target_purchase_order_id;
  if target_org_id is null then
    raise exception 'purchase order not found';
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
       or existing_grn.warehouse_id <> target_warehouse_id
       or existing_grn.supplier_invoice_number is distinct from nullif(btrim(coalesce(target_supplier_invoice_number,'')),'')
       or existing_grn.supplier_delivery_note is distinct from nullif(btrim(coalesce(target_supplier_delivery_note,'')),'') then
      raise exception 'purchase receipt idempotency key conflict';
    end if;

    return existing_grn;
  end if;

  return public.post_purchase_goods_receipt_v1(
    target_purchase_order_id,
    target_warehouse_id,
    target_supplier_invoice_number,
    target_supplier_delivery_note,
    target_note,
    target_lines,
    target_idempotency_key
  );
end;
$$;

revoke all on function public.post_purchase_goods_receipt(uuid,uuid,text,text,text,jsonb,text) from public;
grant execute on function public.post_purchase_goods_receipt(uuid,uuid,text,text,text,jsonb,text) to authenticated;
