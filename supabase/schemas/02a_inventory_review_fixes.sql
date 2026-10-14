-- Inventory review fixes found before first deployment.
-- Applies after 02_inventory.sql.

-- Optional identifiers must be unique only when present. NULL values are intentionally reusable.
alter table public.items drop constraint if exists items_organization_id_barcode_key;
alter table public.items drop constraint if exists items_organization_id_qr_identifier_key;
alter table public.stock_transactions drop constraint if exists stock_transactions_organization_id_idempotency_key_key;

drop index if exists public.items_org_barcode_idx;
drop index if exists public.items_org_qr_idx;

create unique index if not exists items_org_barcode_unique_idx
  on public.items (organization_id, barcode)
  where barcode is not null;
create unique index if not exists items_org_qr_unique_idx
  on public.items (organization_id, qr_identifier)
  where qr_identifier is not null;
create unique index if not exists stock_transactions_org_idempotency_unique_idx
  on public.stock_transactions (organization_id, idempotency_key)
  where idempotency_key is not null;

-- DELETE triggers must return OLD. Returning NEW during DELETE silently cancels a valid draft delete.
create or replace function private.guard_stock_transaction_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status in ('posted','reversed','cancelled') then
    raise exception 'finalized stock transaction is immutable';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- Enforce tenant and tracking consistency for every ledger line before it reaches posting.
create or replace function private.validate_stock_line_references()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  tx_org uuid;
  item_org uuid;
  tracked_by_batch boolean;
  tracked_by_serial boolean;
  batch_item uuid;
  batch_org uuid;
  serial_item uuid;
  serial_org uuid;
  warehouse_org uuid;
  location_warehouse uuid;
begin
  select organization_id into tx_org from public.stock_transactions where id = new.stock_transaction_id;
  select organization_id, batch_tracking, serial_tracking
    into item_org, tracked_by_batch, tracked_by_serial
  from public.items where id = new.item_id;
  select organization_id into warehouse_org from public.warehouses where id = new.warehouse_id;

  if tx_org is null or item_org is null or warehouse_org is null then
    raise exception 'invalid stock line reference';
  end if;
  if new.organization_id <> tx_org or new.organization_id <> item_org or new.organization_id <> warehouse_org then
    raise exception 'stock line organization mismatch';
  end if;

  if new.location_id is not null then
    select warehouse_id into location_warehouse from public.warehouse_locations where id = new.location_id;
    if location_warehouse is distinct from new.warehouse_id then
      raise exception 'stock location does not belong to selected warehouse';
    end if;
  end if;

  if tracked_by_batch and new.batch_id is null then
    raise exception 'batch-tracked item requires batch';
  end if;
  if tracked_by_serial and new.serial_number_id is null then
    raise exception 'serial-tracked item requires serial number';
  end if;
  if tracked_by_serial and abs(new.quantity_delta) <> 1 then
    raise exception 'serial-tracked stock movement quantity must be exactly one unit';
  end if;

  if new.batch_id is not null then
    select item_id, organization_id into batch_item, batch_org from public.batches where id = new.batch_id;
    if batch_item is distinct from new.item_id or batch_org is distinct from new.organization_id then
      raise exception 'batch does not belong to selected item/organization';
    end if;
  end if;

  if new.serial_number_id is not null then
    select item_id, organization_id into serial_item, serial_org from public.serial_numbers where id = new.serial_number_id;
    if serial_item is distinct from new.item_id or serial_org is distinct from new.organization_id then
      raise exception 'serial number does not belong to selected item/organization';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists stock_transaction_lines_validate_refs on public.stock_transaction_lines;
create trigger stock_transaction_lines_validate_refs
before insert or update on public.stock_transaction_lines
for each row execute function private.validate_stock_line_references();
