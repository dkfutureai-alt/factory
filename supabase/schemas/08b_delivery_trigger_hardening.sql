-- Delivery trigger hardening discovered by PostgreSQL CI.
-- Apply after 08a_delivery_review_fixes.sql and before Delivery demo seeds.
--
-- Keep table-specific NEW fields inside table-specific branches. PostgreSQL trigger records
-- have the exact row type of the triggering table, so fields such as delivery_line_id cannot be
-- referenced while the same trigger function is executing for proof_of_deliveries.

create or replace function private.validate_delivery_child_reference()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  delivery_org uuid;
  delivery_order uuid;
  line_order uuid;
  line_item uuid;
begin
  select organization_id, sales_order_id
    into delivery_org, delivery_order
  from public.deliveries
  where id = new.delivery_id;

  if delivery_org is null or delivery_org <> new.organization_id then
    raise exception 'delivery child organization mismatch';
  end if;

  if tg_table_name = 'delivery_lines' then
    select sales_order_id, item_id
      into line_order, line_item
    from public.sales_order_lines
    where id = new.sales_order_line_id;

    if line_order is null
       or line_order <> delivery_order
       or line_item <> new.item_id then
      raise exception 'delivery line must match sales order line';
    end if;
    return new;
  end if;

  if tg_table_name = 'delivery_exceptions' then
    if new.delivery_line_id is not null and not exists(
      select 1
      from public.delivery_lines dl
      where dl.id = new.delivery_line_id
        and dl.delivery_id = new.delivery_id
        and dl.organization_id = new.organization_id
    ) then
      raise exception 'delivery exception line mismatch';
    end if;
    return new;
  end if;

  if tg_table_name = 'proof_of_deliveries' then
    return new;
  end if;

  if tg_table_name = 'delivery_events' then
    return new;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_delivery_child_reference() from public;
