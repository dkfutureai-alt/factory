-- FactoryOS Delivery review fixes.
-- Apply after 08_delivery.sql.

create or replace function private.validate_delivery_line_allocation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  ordered_qty numeric;
  allocated_qty numeric;
  delivery_status_value public.delivery_status;
begin
  select sol.ordered_quantity into ordered_qty
  from public.sales_order_lines sol
  where sol.id=new.sales_order_line_id;
  if ordered_qty is null then raise exception 'sales order line not found'; end if;

  select d.status into delivery_status_value from public.deliveries d where d.id=new.delivery_id;
  if delivery_status_value is null then raise exception 'delivery not found'; end if;

  if tg_op='UPDATE' and delivery_status_value in ('delivered','exception','failed','cancelled') then
    if new.planned_quantity is distinct from old.planned_quantity
       or new.sales_order_line_id is distinct from old.sales_order_line_id
       or new.item_id is distinct from old.item_id then
      raise exception 'finalized delivery allocation is immutable';
    end if;
  end if;

  select coalesce(sum(dl.planned_quantity),0) into allocated_qty
  from public.delivery_lines dl
  join public.deliveries d on d.id=dl.delivery_id
  where dl.sales_order_line_id=new.sales_order_line_id
    and dl.id <> coalesce(new.id,gen_random_uuid())
    and d.status <> 'cancelled';

  if allocated_qty + new.planned_quantity > ordered_qty then
    raise exception 'delivery allocation exceeds sales order quantity';
  end if;
  return new;
end;
$$;

create trigger delivery_lines_validate_allocation
before insert or update on public.delivery_lines
for each row execute function private.validate_delivery_line_allocation();

create or replace function private.guard_verified_pod()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if tg_op='DELETE' and old.verification_status='verified' then raise exception 'verified POD cannot be deleted'; end if;
  if tg_op='UPDATE' and old.verification_status='verified' then
    if new.receiver_name is distinct from old.receiver_name
       or new.evidence_reference is distinct from old.evidence_reference
       or new.captured_at is distinct from old.captured_at then
      raise exception 'verified POD evidence is immutable';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create trigger pod_guard_verified
before update or delete on public.proof_of_deliveries
for each row execute function private.guard_verified_pod();

create or replace function private.guard_resolved_delivery_exception()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if tg_op='DELETE' and old.status in ('returned','resolved') then raise exception 'resolved/returned delivery exception cannot be deleted'; end if;
  if tg_op='UPDATE' and old.status in ('returned','resolved') and new.status is distinct from old.status then raise exception 'resolved/returned delivery exception status is final'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create trigger delivery_exceptions_guard_resolved
before update or delete on public.delivery_exceptions
for each row execute function private.guard_resolved_delivery_exception();
