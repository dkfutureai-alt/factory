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

create unique index if not exists delivery_exception_active_line_unique
on public.delivery_exceptions(delivery_line_id)
where delivery_line_id is not null and status not in ('resolved','cancelled');

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
       or new.captured_at is distinct from old.captured_at
       or new.verification_status is distinct from old.verification_status then
      raise exception 'verified POD evidence and status are immutable';
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

create or replace function private.guard_delivery_final_state()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if tg_op='DELETE' and old.status in ('delivered','exception') then raise exception 'completed delivery cannot be deleted'; end if;
  if tg_op='UPDATE' and old.status in ('loaded','in_transit','arrived','delivered','exception') then
    if new.sales_order_id is distinct from old.sales_order_id
       or new.trip_id is distinct from old.trip_id
       or new.customer_id is distinct from old.customer_id
       or new.ship_to_address_id is distinct from old.ship_to_address_id
       or new.driver_employee_id is distinct from old.driver_employee_id
       or new.vehicle_id is distinct from old.vehicle_id then
      raise exception 'delivery routing references are immutable after loading';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create trigger deliveries_guard_final_state
before update or delete on public.deliveries
for each row execute function private.guard_delivery_final_state();

create or replace function public.driver_complete_delivery(
  target_delivery_id uuid,
  receiver text,
  evidence_ref text,
  line_results jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  d public.deliveries%rowtype;
  employee_id uuid;
  r jsonb;
  line_id uuid;
  accepted numeric;
  rejected numeric;
  reason text;
  planned numeric;
  has_rejection boolean := false;
  supplied_count integer;
  distinct_count integer;
  required_count integer;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if length(btrim(coalesce(receiver,'')))=0 or length(btrim(coalesce(evidence_ref,'')))=0 then raise exception 'receiver and POD evidence are required'; end if;
  if jsonb_typeof(line_results) <> 'array' then raise exception 'line_results must be an array'; end if;

  select * into d from public.deliveries where id=target_delivery_id for update;
  if d.id is null then raise exception 'delivery not found'; end if;
  employee_id := private.current_employee_id(d.organization_id);
  if employee_id is null or employee_id <> d.driver_employee_id then raise exception 'delivery is not assigned to current driver'; end if;
  if not private.has_permission(d.organization_id,'delivery.assigned_update',d.factory_id) then raise exception 'permission denied'; end if;
  if d.status not in ('arrived','in_transit') then raise exception 'delivery cannot be completed from current status'; end if;

  select jsonb_array_length(line_results), count(distinct (value->>'delivery_line_id'))
  into supplied_count, distinct_count
  from jsonb_array_elements(line_results);
  select count(*) into required_count from public.delivery_lines where delivery_id=d.id;
  if supplied_count <> required_count or distinct_count <> required_count then raise exception 'exactly one result is required for every delivery line'; end if;

  for r in select value from jsonb_array_elements(line_results)
  loop
    line_id := (r->>'delivery_line_id')::uuid;
    accepted := coalesce((r->>'accepted_quantity')::numeric,0);
    rejected := coalesce((r->>'rejected_quantity')::numeric,0);
    reason := nullif(btrim(coalesce(r->>'rejection_reason','')),'');
    select planned_quantity into planned from public.delivery_lines where id=line_id and delivery_id=d.id for update;
    if planned is null then raise exception 'delivery line not found'; end if;
    if accepted < 0 or rejected < 0 or accepted + rejected <> planned then raise exception 'delivery line quantities must exactly reconcile planned quantity'; end if;
    if rejected > 0 and reason is null then raise exception 'rejection reason required'; end if;
    update public.delivery_lines set accepted_quantity=accepted,rejected_quantity=rejected,rejection_reason=reason where id=line_id;
    if rejected > 0 then
      has_rejection := true;
      insert into public.delivery_exceptions(organization_id,delivery_id,delivery_line_id,exception_type,quantity,reason,evidence_reference,status)
      values(d.organization_id,d.id,line_id,'rejected_quantity',rejected,reason,evidence_ref,'open')
      on conflict (delivery_line_id) where delivery_line_id is not null and status not in ('resolved','cancelled')
      do update set quantity=excluded.quantity,reason=excluded.reason,evidence_reference=excluded.evidence_reference,updated_at=now();
    end if;
  end loop;

  insert into public.proof_of_deliveries(organization_id,delivery_id,receiver_name,evidence_reference,verification_status,created_by)
  values(d.organization_id,d.id,btrim(receiver),btrim(evidence_ref),'captured',auth.uid())
  on conflict (delivery_id) do update set receiver_name=excluded.receiver_name,evidence_reference=excluded.evidence_reference,captured_at=now(),verification_status='captured',created_by=auth.uid();

  update public.deliveries set status=case when has_rejection then 'exception'::public.delivery_status else 'delivered'::public.delivery_status end,
    arrived_at=coalesce(arrived_at,now()), delivered_at=now(), updated_by=auth.uid() where id=d.id;
  insert into public.delivery_events(organization_id,delivery_id,event_type,actor_user_id,note)
  values(d.organization_id,d.id,case when has_rejection then 'exception' else 'delivered' end,auth.uid(),case when has_rejection then 'Delivery completed with rejected quantity' else 'Delivery completed with POD' end);
end;
$$;

revoke all on function public.driver_complete_delivery(uuid,text,text,jsonb) from public;
grant execute on function public.driver_complete_delivery(uuid,text,text,jsonb) to authenticated;
