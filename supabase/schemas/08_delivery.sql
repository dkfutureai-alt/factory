-- FactoryOS Delivery / POD / rejection-return schema
-- Depends on 01_core.sql, 02_inventory.sql, 05_hr.sql, 06_sales.sql and 07_fleet.sql.

create type public.delivery_status as enum ('planned','loaded','in_transit','arrived','delivered','exception','failed','cancelled');
create type public.pod_verification_status as enum ('captured','verified','rejected');
create type public.delivery_exception_status as enum ('open','return_planned','returned','resolved','cancelled');

create table public.deliveries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  delivery_number text not null,
  sales_order_id uuid not null references public.sales_orders(id) on delete restrict,
  trip_id uuid not null references public.trips(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  ship_to_address_id uuid references public.customer_delivery_addresses(id) on delete restrict,
  driver_employee_id uuid not null references public.employees(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  planned_delivery_at timestamptz,
  arrived_at timestamptz,
  delivered_at timestamptz,
  status public.delivery_status not null default 'planned',
  receiver_note text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, delivery_number),
  unique (organization_id, trip_id, sales_order_id),
  check (delivered_at is null or arrived_at is null or delivered_at >= arrived_at),
  check (status <> 'arrived' or arrived_at is not null),
  check (status not in ('delivered','exception') or delivered_at is not null)
);

create table public.delivery_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  delivery_id uuid not null references public.deliveries(id) on delete cascade,
  sales_order_line_id uuid not null references public.sales_order_lines(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  planned_quantity numeric(18,4) not null check (planned_quantity > 0),
  accepted_quantity numeric(18,4) not null default 0 check (accepted_quantity >= 0),
  rejected_quantity numeric(18,4) not null default 0 check (rejected_quantity >= 0),
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (delivery_id, sales_order_line_id),
  check (accepted_quantity + rejected_quantity <= planned_quantity),
  check (rejected_quantity = 0 or length(btrim(coalesce(rejection_reason,''))) > 0)
);

create table public.proof_of_deliveries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  delivery_id uuid not null references public.deliveries(id) on delete restrict,
  receiver_name text not null,
  captured_at timestamptz not null default now(),
  evidence_reference text not null,
  verification_status public.pod_verification_status not null default 'captured',
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  rejection_reason text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (delivery_id),
  check (length(btrim(receiver_name)) > 0),
  check (length(btrim(evidence_reference)) > 0),
  check (verification_status <> 'verified' or verified_at is not null),
  check (verification_status <> 'rejected' or length(btrim(coalesce(rejection_reason,''))) > 0)
);

create table public.delivery_exceptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  delivery_id uuid not null references public.deliveries(id) on delete restrict,
  delivery_line_id uuid references public.delivery_lines(id) on delete restrict,
  exception_type text not null check (exception_type in ('short_delivery','rejected_quantity','damaged','customer_unavailable','address_issue','other')),
  quantity numeric(18,4) not null default 0 check (quantity >= 0),
  reason text not null,
  evidence_reference text,
  return_trip_id uuid references public.trips(id) on delete set null,
  return_stock_transaction_id uuid references public.stock_transactions(id) on delete restrict,
  status public.delivery_exception_status not null default 'open',
  resolved_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(btrim(reason)) > 0),
  check (status not in ('returned','resolved') or resolved_at is not null)
);

create table public.delivery_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  delivery_id uuid not null references public.deliveries(id) on delete cascade,
  event_type text not null check (event_type in ('planned','loaded','departed','arrived','pod_captured','exception','delivered','failed','return_planned','return_received')),
  event_at timestamptz not null default now(),
  actor_user_id uuid references auth.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create index deliveries_org_factory_status_idx on public.deliveries(organization_id, factory_id, status, planned_delivery_at);
create index deliveries_driver_status_idx on public.deliveries(driver_employee_id, status, planned_delivery_at);
create index delivery_lines_delivery_idx on public.delivery_lines(delivery_id);
create index delivery_exceptions_delivery_status_idx on public.delivery_exceptions(delivery_id, status);
create index delivery_events_delivery_time_idx on public.delivery_events(delivery_id, event_at);

create trigger deliveries_set_updated_at before update on public.deliveries for each row execute function private.set_updated_at();
create trigger delivery_lines_set_updated_at before update on public.delivery_lines for each row execute function private.set_updated_at();
create trigger delivery_exceptions_set_updated_at before update on public.delivery_exceptions for each row execute function private.set_updated_at();

create or replace function private.validate_delivery_references()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  factory_org uuid;
  order_org uuid;
  order_customer uuid;
  trip_org uuid;
  trip_vehicle uuid;
  trip_driver uuid;
  trip_order uuid;
  customer_org uuid;
  address_org uuid;
  address_customer uuid;
begin
  select organization_id into factory_org from public.factories where id=new.factory_id;
  select organization_id, customer_id into order_org, order_customer from public.sales_orders where id=new.sales_order_id;
  select organization_id, vehicle_id, driver_employee_id, sales_order_id into trip_org, trip_vehicle, trip_driver, trip_order from public.trips where id=new.trip_id;
  select organization_id into customer_org from public.customers where id=new.customer_id;
  if factory_org is null or order_org is null or trip_org is null or customer_org is null then raise exception 'invalid delivery reference'; end if;
  if new.organization_id <> factory_org or new.organization_id <> order_org or new.organization_id <> trip_org or new.organization_id <> customer_org then raise exception 'delivery organization mismatch'; end if;
  if order_customer <> new.customer_id then raise exception 'delivery customer does not match sales order'; end if;
  if trip_vehicle <> new.vehicle_id or trip_driver <> new.driver_employee_id then raise exception 'delivery vehicle/driver must match trip'; end if;
  if trip_order is not null and trip_order <> new.sales_order_id then raise exception 'delivery sales order must match trip sales order'; end if;
  if new.ship_to_address_id is not null then
    select organization_id, customer_id into address_org, address_customer from public.customer_delivery_addresses where id=new.ship_to_address_id;
    if address_org is distinct from new.organization_id or address_customer is distinct from new.customer_id then raise exception 'delivery address mismatch'; end if;
  end if;
  return new;
end;
$$;

create trigger deliveries_validate_refs before insert or update on public.deliveries for each row execute function private.validate_delivery_references();

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
  select organization_id, sales_order_id into delivery_org, delivery_order from public.deliveries where id=new.delivery_id;
  if delivery_org is null or delivery_org <> new.organization_id then raise exception 'delivery child organization mismatch'; end if;
  if tg_table_name='delivery_lines' then
    select sales_order_id, item_id into line_order, line_item from public.sales_order_lines where id=new.sales_order_line_id;
    if line_order is null or line_order <> delivery_order or line_item <> new.item_id then raise exception 'delivery line must match sales order line'; end if;
  elsif tg_table_name='delivery_exceptions' and new.delivery_line_id is not null then
    if not exists(select 1 from public.delivery_lines dl where dl.id=new.delivery_line_id and dl.delivery_id=new.delivery_id and dl.organization_id=new.organization_id) then raise exception 'delivery exception line mismatch'; end if;
  elsif tg_table_name='proof_of_deliveries' then
    null;
  elsif tg_table_name='delivery_events' then
    null;
  end if;
  return new;
end;
$$;

create trigger delivery_lines_validate_refs before insert or update on public.delivery_lines for each row execute function private.validate_delivery_child_reference();
create trigger pod_validate_refs before insert or update on public.proof_of_deliveries for each row execute function private.validate_delivery_child_reference();
create trigger delivery_exceptions_validate_refs before insert or update on public.delivery_exceptions for each row execute function private.validate_delivery_child_reference();
create trigger delivery_events_validate_refs before insert or update on public.delivery_events for each row execute function private.validate_delivery_child_reference();

create or replace function private.validate_delivery_return_link()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  tx_org uuid;
  tx_status public.stock_transaction_status;
  tx_type public.stock_transaction_type;
  trip_org uuid;
begin
  if new.return_trip_id is not null then
    select organization_id into trip_org from public.trips where id=new.return_trip_id;
    if trip_org is null or trip_org <> new.organization_id then raise exception 'return trip organization mismatch'; end if;
  end if;
  if new.return_stock_transaction_id is not null then
    select organization_id, status, transaction_type into tx_org, tx_status, tx_type from public.stock_transactions where id=new.return_stock_transaction_id;
    if tx_org is null or tx_org <> new.organization_id then raise exception 'return stock transaction organization mismatch'; end if;
    if tx_type <> 'customer_return' or tx_status <> 'posted' then raise exception 'return stock link must reference posted customer_return transaction'; end if;
  end if;
  if new.status='returned' and new.return_stock_transaction_id is null then raise exception 'returned exception requires posted warehouse return transaction'; end if;
  return new;
end;
$$;

create trigger delivery_exceptions_validate_return before insert or update on public.delivery_exceptions for each row execute function private.validate_delivery_return_link();

alter table public.deliveries enable row level security;
alter table public.delivery_lines enable row level security;
alter table public.proof_of_deliveries enable row level security;
alter table public.delivery_exceptions enable row level security;
alter table public.delivery_events enable row level security;

create policy deliveries_select on public.deliveries for select to authenticated using (
  (select private.has_permission(organization_id,'delivery.read',factory_id))
  or driver_employee_id=(select private.current_employee_id(organization_id))
);
create policy deliveries_manage on public.deliveries for all to authenticated using ((select private.has_permission(organization_id,'delivery.manage',factory_id))) with check ((select private.has_permission(organization_id,'delivery.manage',factory_id)));

create policy delivery_lines_select on public.delivery_lines for select to authenticated using (
  (select private.has_permission(organization_id,'delivery.read',null))
  or exists(select 1 from public.deliveries d where d.id=delivery_id and d.driver_employee_id=(select private.current_employee_id(organization_id)))
);
create policy delivery_lines_manage on public.delivery_lines for all to authenticated using ((select private.has_permission(organization_id,'delivery.manage',null))) with check ((select private.has_permission(organization_id,'delivery.manage',null)));

create policy pod_select on public.proof_of_deliveries for select to authenticated using (
  (select private.has_permission(organization_id,'delivery.read',null))
  or exists(select 1 from public.deliveries d where d.id=delivery_id and d.driver_employee_id=(select private.current_employee_id(organization_id)))
);
create policy pod_manage on public.proof_of_deliveries for all to authenticated using ((select private.has_permission(organization_id,'delivery.manage',null))) with check ((select private.has_permission(organization_id,'delivery.manage',null)));

create policy delivery_exceptions_select on public.delivery_exceptions for select to authenticated using (
  (select private.has_permission(organization_id,'delivery.read',null))
  or exists(select 1 from public.deliveries d where d.id=delivery_id and d.driver_employee_id=(select private.current_employee_id(organization_id)))
);
create policy delivery_exceptions_manage on public.delivery_exceptions for all to authenticated using ((select private.has_permission(organization_id,'delivery.manage',null))) with check ((select private.has_permission(organization_id,'delivery.manage',null)));

create policy delivery_events_select on public.delivery_events for select to authenticated using (
  (select private.has_permission(organization_id,'delivery.read',null))
  or exists(select 1 from public.deliveries d where d.id=delivery_id and d.driver_employee_id=(select private.current_employee_id(organization_id)))
);
create policy delivery_events_manage on public.delivery_events for all to authenticated using ((select private.has_permission(organization_id,'delivery.manage',null))) with check ((select private.has_permission(organization_id,'delivery.manage',null)));

grant select on public.deliveries, public.delivery_lines, public.proof_of_deliveries, public.delivery_exceptions, public.delivery_events to authenticated;
grant insert, update, delete on public.deliveries, public.delivery_lines, public.proof_of_deliveries, public.delivery_exceptions, public.delivery_events to authenticated;

create or replace function public.driver_mark_delivery_arrived(target_delivery_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  d public.deliveries%rowtype;
  employee_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into d from public.deliveries where id=target_delivery_id for update;
  if d.id is null then raise exception 'delivery not found'; end if;
  employee_id := private.current_employee_id(d.organization_id);
  if employee_id is null or employee_id <> d.driver_employee_id then raise exception 'delivery is not assigned to current driver'; end if;
  if not private.has_permission(d.organization_id,'delivery.assigned_update',d.factory_id) then raise exception 'permission denied'; end if;
  if d.status not in ('loaded','in_transit') then raise exception 'delivery cannot be marked arrived from current status'; end if;
  update public.deliveries set status='arrived', arrived_at=coalesce(arrived_at,now()), updated_by=auth.uid() where id=d.id;
  insert into public.delivery_events(organization_id,delivery_id,event_type,actor_user_id,note) values(d.organization_id,d.id,'arrived',auth.uid(),'Driver marked arrival');
end;
$$;

revoke all on function public.driver_mark_delivery_arrived(uuid) from public;
grant execute on function public.driver_mark_delivery_arrived(uuid) to authenticated;

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
      values(d.organization_id,d.id,line_id,'rejected_quantity',rejected,reason,evidence_ref,'open');
    end if;
  end loop;

  if exists(select 1 from public.delivery_lines where delivery_id=d.id and accepted_quantity + rejected_quantity <> planned_quantity) then raise exception 'all delivery lines must be reconciled'; end if;

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
