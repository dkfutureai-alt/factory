-- Production review fixes found before first deployment.
-- Applies after 03_production_quality.sql.

create or replace function private.guard_completed_production_batch()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status in ('completed','cancelled') then
    raise exception 'finalized production batch is immutable';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- Cross-table integrity: production material consumption must reference a posted/valid
-- stock issue line for the same tenant, item and production batch context.
create or replace function private.validate_production_consumption()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  batch_org uuid;
  line_org uuid;
  line_item uuid;
  line_qty numeric;
  tx_type public.stock_transaction_type;
  tx_status public.stock_transaction_status;
begin
  select organization_id into batch_org
  from public.production_batches where id = new.production_batch_id;

  select l.organization_id, l.item_id, l.quantity_delta, t.transaction_type, t.status
    into line_org, line_item, line_qty, tx_type, tx_status
  from public.stock_transaction_lines l
  join public.stock_transactions t on t.id = l.stock_transaction_id
  where l.id = new.stock_transaction_line_id;

  if batch_org is null or line_org is null then
    raise exception 'invalid production consumption reference';
  end if;
  if new.organization_id <> batch_org or new.organization_id <> line_org then
    raise exception 'production consumption organization mismatch';
  end if;
  if new.item_id <> line_item then
    raise exception 'production consumption item mismatch';
  end if;
  if line_qty >= 0 or abs(line_qty) <> new.quantity then
    raise exception 'production consumption must match a negative stock issue quantity';
  end if;
  if tx_type <> 'production_issue' or tx_status <> 'posted' then
    raise exception 'production consumption requires a posted production_issue transaction';
  end if;
  return new;
end;
$$;

drop trigger if exists production_consumption_validate on public.production_material_consumption;
create trigger production_consumption_validate
before insert or update on public.production_material_consumption
for each row execute function private.validate_production_consumption();

create or replace function private.validate_production_output()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  batch_org uuid;
  line_org uuid;
  line_item uuid;
  line_qty numeric;
  tx_type public.stock_transaction_type;
  tx_status public.stock_transaction_status;
begin
  select organization_id into batch_org
  from public.production_batches where id = new.production_batch_id;

  if new.organization_id <> batch_org then
    raise exception 'production output organization mismatch';
  end if;

  if new.output_type = 'good' then
    if new.stock_transaction_line_id is null then
      raise exception 'good production output requires finished-goods stock receipt';
    end if;

    select l.organization_id, l.item_id, l.quantity_delta, t.transaction_type, t.status
      into line_org, line_item, line_qty, tx_type, tx_status
    from public.stock_transaction_lines l
    join public.stock_transactions t on t.id = l.stock_transaction_id
    where l.id = new.stock_transaction_line_id;

    if line_org is distinct from new.organization_id or line_item is distinct from new.item_id then
      raise exception 'production output stock line mismatch';
    end if;
    if line_qty <= 0 or line_qty <> new.quantity then
      raise exception 'good production output must match positive stock receipt quantity';
    end if;
    if tx_type <> 'finished_goods_receipt' or tx_status <> 'posted' then
      raise exception 'good production output requires posted finished_goods_receipt transaction';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists production_output_validate on public.production_outputs;
create trigger production_output_validate
before insert or update on public.production_outputs
for each row execute function private.validate_production_output();
