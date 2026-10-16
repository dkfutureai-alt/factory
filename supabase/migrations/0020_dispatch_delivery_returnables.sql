begin;

-- Phase 10: Dispatch, Delivery & Returnables.
-- Connects Warehouse staged handoff + Fleet trip + immutable Inventory ledger.

alter table public.inventory_items
  add column if not exists is_returnable boolean not null default false;

-- Phase 8 handoffs are organization-scoped. Dispatch also needs an immutable
-- factory-scoped composite key so a handoff can never be attached cross-factory.
create unique index if not exists warehouse_dispatch_handoffs_id_factory_unique
  on public.warehouse_dispatch_handoffs(id, factory_id);

create table public.dispatch_deliveries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  delivery_no text not null default ('DEL-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  warehouse_handoff_id uuid not null unique,
  trip_id uuid not null unique,
  sales_order_id uuid not null,
  customer_id uuid not null,
  vehicle_id uuid not null,
  driver_id uuid not null,
  staging_location_id uuid not null,
  vehicle_location_id uuid not null,
  status text not null default 'ready_to_load' check (status in ('ready_to_load','loaded','in_transit','arrived','delivered','failed','cancelled')),
  loaded_by uuid references auth.users(id) on delete set null,
  loaded_at timestamptz,
  started_at timestamptz,
  arrived_at timestamptz,
  delivered_at timestamptz,
  receiver_name text,
  receiver_phone text,
  pod_photo_ref text,
  pod_signature_ref text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, delivery_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (warehouse_handoff_id, factory_id) references public.warehouse_dispatch_handoffs(id, factory_id) on delete restrict,
  foreign key (trip_id, factory_id) references public.fleet_trips(id, factory_id) on delete restrict,
  foreign key (sales_order_id, factory_id) references public.sales_orders(id, factory_id) on delete restrict,
  foreign key (customer_id, organization_id) references public.business_partners(id, organization_id) on delete restrict,
  foreign key (vehicle_id, factory_id) references public.fleet_vehicles(id, factory_id) on delete restrict,
  foreign key (driver_id, factory_id) references public.fleet_drivers(id, factory_id) on delete restrict,
  foreign key (staging_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (vehicle_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  check (staging_location_id <> vehicle_location_id),
  check ((status in ('loaded','in_transit','arrived','delivered') and loaded_at is not null) or status not in ('loaded','in_transit','arrived','delivered')),
  check ((status in ('in_transit','arrived','delivered') and started_at is not null) or status not in ('in_transit','arrived','delivered')),
  check ((status in ('arrived','delivered') and arrived_at is not null) or status not in ('arrived','delivered')),
  check ((status='delivered' and delivered_at is not null and char_length(trim(coalesce(receiver_name,''))) >= 2) or status<>'delivered')
);
create index dispatch_deliveries_factory_status_idx on public.dispatch_deliveries(factory_id,status,created_at desc);
create index dispatch_deliveries_driver_status_idx on public.dispatch_deliveries(driver_id,status,created_at desc);

create table public.dispatch_delivery_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  delivery_id uuid not null,
  warehouse_pick_line_id uuid not null unique,
  sales_order_line_id uuid not null,
  item_id uuid not null,
  planned_quantity numeric(18,4) not null check (planned_quantity > 0),
  loaded_quantity numeric(18,4) not null default 0 check (loaded_quantity >= 0),
  delivered_quantity numeric(18,4) not null default 0 check (delivered_quantity >= 0),
  load_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  delivery_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (delivery_id, item_id),
  unique (id, organization_id),
  foreign key (delivery_id, organization_id) references public.dispatch_deliveries(id, organization_id) on delete cascade,
  foreign key (warehouse_pick_line_id, organization_id) references public.warehouse_pick_lines(id, organization_id) on delete restrict,
  foreign key (sales_order_line_id, organization_id) references public.sales_order_lines(id, organization_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  check (loaded_quantity <= planned_quantity),
  check (delivered_quantity <= loaded_quantity)
);
create index dispatch_delivery_lines_delivery_idx on public.dispatch_delivery_lines(delivery_id);

create table public.dispatch_returnable_pickups (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  delivery_id uuid not null,
  pickup_no text not null default ('RET-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  status text not null default 'open' check (status in ('open','completed','cancelled')),
  completed_at timestamptz,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (delivery_id),
  unique (organization_id, pickup_no),
  unique (id, organization_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (delivery_id, factory_id) references public.dispatch_deliveries(id, factory_id) on delete restrict,
  check ((status='completed' and completed_at is not null) or status<>'completed')
);

create table public.dispatch_returnable_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  pickup_id uuid not null,
  item_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  condition text not null default 'good' check (condition in ('good','damaged','rejected')),
  vehicle_receive_transaction_id uuid not null unique references public.inventory_transactions(id) on delete restrict,
  notes text,
  created_at timestamptz not null default now(),
  unique (pickup_id,item_id,condition),
  unique (id,organization_id),
  foreign key (pickup_id,organization_id) references public.dispatch_returnable_pickups(id,organization_id) on delete cascade,
  foreign key (item_id,organization_id) references public.inventory_items(id,organization_id) on delete restrict
);

create table public.dispatch_delivery_exceptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  delivery_id uuid not null,
  item_id uuid,
  exception_type text not null check (exception_type in ('shortage','damage','customer_rejected','address_unreachable','vehicle_issue','other')),
  quantity numeric(18,4) check (quantity is null or quantity > 0),
  details text not null check (char_length(trim(details)) between 3 and 500),
  status text not null default 'open' check (status in ('open','resolved','cancelled')),
  resolution_note text,
  resolved_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  resolved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,organization_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (delivery_id,factory_id) references public.dispatch_deliveries(id,factory_id) on delete cascade,
  foreign key (item_id,organization_id) references public.inventory_items(id,organization_id) on delete restrict,
  check ((status='resolved' and resolved_at is not null and char_length(trim(coalesce(resolution_note,''))) >= 3) or status<>'resolved')
);
create index dispatch_exceptions_factory_status_idx on public.dispatch_delivery_exceptions(factory_id,status,created_at desc);

create trigger dispatch_deliveries_set_updated_at before update on public.dispatch_deliveries for each row execute function public.set_updated_at();
create trigger dispatch_delivery_lines_set_updated_at before update on public.dispatch_delivery_lines for each row execute function public.set_updated_at();
create trigger dispatch_returnable_pickups_set_updated_at before update on public.dispatch_returnable_pickups for each row execute function public.set_updated_at();
create trigger dispatch_exceptions_set_updated_at before update on public.dispatch_delivery_exceptions for each row execute function public.set_updated_at();

create or replace function public.can_view_dispatch_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_view_inventory_factory(target_factory_id);
$$;
grant execute on function public.can_view_dispatch_factory(uuid) to authenticated;

create or replace function public.dispatch_driver_can_access_delivery(target_delivery_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.dispatch_deliveries d
    where d.id=target_delivery_id and public.fleet_driver_is_current_user(d.driver_id)
  );
$$;
grant execute on function public.dispatch_driver_can_access_delivery(uuid) to authenticated;

alter table public.dispatch_deliveries enable row level security;
alter table public.dispatch_delivery_lines enable row level security;
alter table public.dispatch_returnable_pickups enable row level security;
alter table public.dispatch_returnable_lines enable row level security;
alter table public.dispatch_delivery_exceptions enable row level security;

grant select on public.dispatch_deliveries,public.dispatch_delivery_lines,public.dispatch_returnable_pickups,public.dispatch_returnable_lines,public.dispatch_delivery_exceptions to authenticated;

create policy dispatch_deliveries_select on public.dispatch_deliveries for select to authenticated
using (public.can_view_dispatch_factory(factory_id));
create policy dispatch_lines_select on public.dispatch_delivery_lines for select to authenticated
using (exists(select 1 from public.dispatch_deliveries d where d.id=delivery_id and public.can_view_dispatch_factory(d.factory_id)));
create policy dispatch_returnable_pickups_select on public.dispatch_returnable_pickups for select to authenticated
using (public.can_view_dispatch_factory(factory_id));
create policy dispatch_returnable_lines_select on public.dispatch_returnable_lines for select to authenticated
using (exists(select 1 from public.dispatch_returnable_pickups p where p.id=pickup_id and public.can_view_dispatch_factory(p.factory_id)));
create policy dispatch_exceptions_select on public.dispatch_delivery_exceptions for select to authenticated
using (public.can_view_dispatch_factory(factory_id));

create or replace function public.dispatch_post_transfer(
  p_factory_id uuid,
  p_item_id uuid,
  p_from_location_id uuid,
  p_to_location_id uuid,
  p_quantity numeric,
  p_reference text,
  p_notes text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_available numeric; v_tx uuid;
begin
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.inventory_items where id=p_item_id and organization_id=v_org and is_active) then raise exception 'Active item not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_from_location_id and factory_id=p_factory_id and is_active) then raise exception 'Source location not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_to_location_id and factory_id=p_factory_id and is_active) then raise exception 'Destination location not found'; end if;
  if p_from_location_id=p_to_location_id then raise exception 'Source and destination must differ'; end if;
  select coalesce(sum(quantity_delta),0) into v_available from public.stock_ledger_entries where item_id=p_item_id and location_id=p_from_location_id;
  if v_available<p_quantity then raise exception 'Insufficient stock: available %, requested %',v_available,p_quantity; end if;
  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,to_location_id,external_reference,notes,created_by)
  values(v_org,p_factory_id,p_item_id,'transfer',p_quantity,p_from_location_id,p_to_location_id,nullif(trim(p_reference),''),nullif(trim(p_notes),''),auth.uid()) returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
  values(v_org,p_factory_id,v_tx,p_item_id,p_from_location_id,-p_quantity),(v_org,p_factory_id,v_tx,p_item_id,p_to_location_id,p_quantity);
  return v_tx;
end; $$;
revoke all on function public.dispatch_post_transfer(uuid,uuid,uuid,uuid,numeric,text,text) from public;

create or replace function public.dispatch_post_issue(
  p_factory_id uuid,
  p_item_id uuid,
  p_from_location_id uuid,
  p_quantity numeric,
  p_reference text,
  p_notes text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_available numeric; v_tx uuid;
begin
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  select coalesce(sum(quantity_delta),0) into v_available from public.stock_ledger_entries where item_id=p_item_id and location_id=p_from_location_id;
  if v_available<p_quantity then raise exception 'Insufficient stock: available %, requested %',v_available,p_quantity; end if;
  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,external_reference,notes,created_by)
  values(v_org,p_factory_id,p_item_id,'issue',p_quantity,p_from_location_id,nullif(trim(p_reference),''),nullif(trim(p_notes),''),auth.uid()) returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
  values(v_org,p_factory_id,v_tx,p_item_id,p_from_location_id,-p_quantity);
  return v_tx;
end; $$;
revoke all on function public.dispatch_post_issue(uuid,uuid,uuid,numeric,text,text) from public;

create or replace function public.dispatch_post_receive(
  p_factory_id uuid,
  p_item_id uuid,
  p_to_location_id uuid,
  p_quantity numeric,
  p_reference text,
  p_notes text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_tx uuid;
begin
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.inventory_items where id=p_item_id and organization_id=v_org and is_active) then raise exception 'Active item not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_to_location_id and factory_id=p_factory_id and is_active) then raise exception 'Destination location not found'; end if;
  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,to_location_id,external_reference,notes,created_by)
  values(v_org,p_factory_id,p_item_id,'receive',p_quantity,p_to_location_id,nullif(trim(p_reference),''),nullif(trim(p_notes),''),auth.uid()) returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
  values(v_org,p_factory_id,v_tx,p_item_id,p_to_location_id,p_quantity);
  return v_tx;
end; $$;
revoke all on function public.dispatch_post_receive(uuid,uuid,uuid,numeric,text,text) from public;

create or replace function public.dispatch_create_delivery(p_handoff_id uuid,p_trip_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_h public.warehouse_dispatch_handoffs%rowtype; v_t public.fleet_trips%rowtype; v_so public.sales_orders%rowtype; v_vehicle public.fleet_vehicles%rowtype; v_delivery uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_h from public.warehouse_dispatch_handoffs where id=p_handoff_id for update;
  if v_h.id is null then raise exception 'Warehouse handoff not found'; end if;
  if not public.can_manage_factory(v_h.factory_id) and not public.can_plan_warehouse_factory(v_h.factory_id) then raise exception 'Dispatch planning access required'; end if;
  if v_h.status<>'handed_off' then raise exception 'Warehouse handoff must be handed off first'; end if;
  select * into v_t from public.fleet_trips where id=p_trip_id and factory_id=v_h.factory_id for update;
  if v_t.id is null then raise exception 'Fleet trip not found for this factory'; end if;
  if v_t.status not in ('planned','assigned') then raise exception 'Fleet trip must be planned or assigned'; end if;
  if v_t.warehouse_handoff_id is not null and v_t.warehouse_handoff_id<>v_h.id then raise exception 'Trip is linked to another warehouse handoff'; end if;
  if v_t.sales_order_id is not null and v_t.sales_order_id<>v_h.sales_order_id then raise exception 'Trip sales order does not match handoff'; end if;
  select * into v_so from public.sales_orders where id=v_h.sales_order_id and factory_id=v_h.factory_id;
  if v_so.id is null then raise exception 'Sales order not found'; end if;
  select * into v_vehicle from public.fleet_vehicles where id=v_t.vehicle_id and factory_id=v_h.factory_id and status='active';
  if v_vehicle.id is null then raise exception 'Active trip vehicle not found'; end if;
  insert into public.dispatch_deliveries(organization_id,factory_id,warehouse_handoff_id,trip_id,sales_order_id,customer_id,vehicle_id,driver_id,staging_location_id,vehicle_location_id,created_by)
  values(v_h.organization_id,v_h.factory_id,v_h.id,v_t.id,v_h.sales_order_id,v_so.customer_id,v_t.vehicle_id,v_t.driver_id,v_h.staging_location_id,v_vehicle.stock_location_id,auth.uid()) returning id into v_delivery;
  insert into public.dispatch_delivery_lines(organization_id,delivery_id,warehouse_pick_line_id,sales_order_line_id,item_id,planned_quantity)
  select v_h.organization_id,v_delivery,l.id,l.sales_order_line_id,l.item_id,l.picked_quantity
  from public.warehouse_pick_lines l where l.pick_list_id=v_h.pick_list_id and l.status='picked';
  if not found then raise exception 'No picked warehouse lines found'; end if;
  update public.fleet_trips set warehouse_handoff_id=v_h.id,sales_order_id=v_h.sales_order_id where id=v_t.id;
  return v_delivery;
end; $$;
grant execute on function public.dispatch_create_delivery(uuid,uuid) to authenticated;

create or replace function public.dispatch_confirm_vehicle_load(p_delivery_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_d public.dispatch_deliveries%rowtype; v_line public.dispatch_delivery_lines%rowtype; v_tx uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_d from public.dispatch_deliveries where id=p_delivery_id for update;
  if v_d.id is null then raise exception 'Delivery not found'; end if;
  if not public.can_manage_factory(v_d.factory_id) and not public.can_plan_warehouse_factory(v_d.factory_id) then raise exception 'Dispatch load access required'; end if;
  if v_d.status<>'ready_to_load' then raise exception 'Delivery is not ready to load'; end if;
  for v_line in select * from public.dispatch_delivery_lines where delivery_id=v_d.id order by id for update loop
    v_tx:=public.dispatch_post_transfer(v_d.factory_id,v_line.item_id,v_d.staging_location_id,v_d.vehicle_location_id,v_line.planned_quantity,v_d.delivery_no,'Dispatch vehicle load');
    update public.dispatch_delivery_lines set loaded_quantity=planned_quantity,load_transaction_id=v_tx where id=v_line.id;
    update public.sales_order_lines set dispatched_quantity=least(ordered_quantity,dispatched_quantity+v_line.planned_quantity) where id=v_line.sales_order_line_id;
  end loop;
  update public.dispatch_deliveries set status='loaded',loaded_by=auth.uid(),loaded_at=now() where id=v_d.id;
  update public.sales_orders set status='dispatched' where id=v_d.sales_order_id and status in ('dispatch_ready','allocated','confirmed');
end; $$;
grant execute on function public.dispatch_confirm_vehicle_load(uuid) to authenticated;

create or replace function public.dispatch_begin_delivery(p_delivery_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_d public.dispatch_deliveries%rowtype; v_trip public.fleet_trips%rowtype;
begin
  select * into v_d from public.dispatch_deliveries where id=p_delivery_id for update;
  if v_d.id is null then raise exception 'Delivery not found'; end if;
  if not public.can_manage_factory(v_d.factory_id) and not public.dispatch_driver_can_access_delivery(v_d.id) then raise exception 'Delivery access denied'; end if;
  if v_d.status<>'loaded' then raise exception 'Delivery must be loaded first'; end if;
  select * into v_trip from public.fleet_trips where id=v_d.trip_id;
  if v_trip.status<>'started' then raise exception 'Fleet trip must be started first'; end if;
  update public.dispatch_deliveries set status='in_transit',started_at=coalesce(v_trip.started_at,now()) where id=v_d.id;
end; $$;
grant execute on function public.dispatch_begin_delivery(uuid) to authenticated;

create or replace function public.dispatch_mark_arrived(p_delivery_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_d public.dispatch_deliveries%rowtype; v_trip public.fleet_trips%rowtype;
begin
  select * into v_d from public.dispatch_deliveries where id=p_delivery_id for update;
  if v_d.id is null then raise exception 'Delivery not found'; end if;
  if not public.can_manage_factory(v_d.factory_id) and not public.dispatch_driver_can_access_delivery(v_d.id) then raise exception 'Delivery access denied'; end if;
  if v_d.status<>'in_transit' then raise exception 'Delivery is not in transit'; end if;
  select * into v_trip from public.fleet_trips where id=v_d.trip_id;
  if v_trip.status not in ('arrived','completed') then raise exception 'Fleet trip must be marked arrived first'; end if;
  update public.dispatch_deliveries set status='arrived',arrived_at=coalesce(v_trip.arrived_at,now()) where id=v_d.id;
end; $$;
grant execute on function public.dispatch_mark_arrived(uuid) to authenticated;

create or replace function public.dispatch_complete_delivery(
  p_delivery_id uuid,
  p_receiver_name text,
  p_receiver_phone text default null,
  p_pod_photo_ref text default null,
  p_pod_signature_ref text default null,
  p_notes text default null
)
returns void language plpgsql security definer set search_path=public as $$
declare v_d public.dispatch_deliveries%rowtype; v_line public.dispatch_delivery_lines%rowtype; v_tx uuid;
begin
  select * into v_d from public.dispatch_deliveries where id=p_delivery_id for update;
  if v_d.id is null then raise exception 'Delivery not found'; end if;
  if not public.can_manage_factory(v_d.factory_id) and not public.dispatch_driver_can_access_delivery(v_d.id) then raise exception 'Delivery access denied'; end if;
  if v_d.status<>'arrived' then raise exception 'Delivery must be arrived before completion'; end if;
  if char_length(trim(coalesce(p_receiver_name,'')))<2 then raise exception 'Receiver name is required'; end if;
  if nullif(trim(coalesce(p_pod_photo_ref,'')),'') is null and nullif(trim(coalesce(p_pod_signature_ref,'')),'') is null then raise exception 'Photo or signature proof is required'; end if;
  for v_line in select * from public.dispatch_delivery_lines where delivery_id=v_d.id order by id for update loop
    if v_line.loaded_quantity<=0 then raise exception 'Loaded quantity missing'; end if;
    v_tx:=public.dispatch_post_issue(v_d.factory_id,v_line.item_id,v_d.vehicle_location_id,v_line.loaded_quantity,v_d.delivery_no,'Customer delivery');
    update public.dispatch_delivery_lines set delivered_quantity=loaded_quantity,delivery_transaction_id=v_tx where id=v_line.id;
  end loop;
  update public.dispatch_deliveries set status='delivered',delivered_at=now(),receiver_name=trim(p_receiver_name),receiver_phone=nullif(trim(coalesce(p_receiver_phone,'')),''),pod_photo_ref=nullif(trim(coalesce(p_pod_photo_ref,'')),''),pod_signature_ref=nullif(trim(coalesce(p_pod_signature_ref,'')),''),notes=coalesce(nullif(trim(coalesce(p_notes,'')),''),notes) where id=v_d.id;
  update public.sales_orders set status='completed' where id=v_d.sales_order_id;
end; $$;
grant execute on function public.dispatch_complete_delivery(uuid,text,text,text,text,text) to authenticated;

create or replace function public.dispatch_record_returnable(
  p_delivery_id uuid,
  p_item_id uuid,
  p_quantity numeric,
  p_condition text default 'good',
  p_notes text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_d public.dispatch_deliveries%rowtype; v_pickup uuid; v_tx uuid; v_line uuid;
begin
  select * into v_d from public.dispatch_deliveries where id=p_delivery_id for update;
  if v_d.id is null then raise exception 'Delivery not found'; end if;
  if not public.can_manage_factory(v_d.factory_id) and not public.dispatch_driver_can_access_delivery(v_d.id) then raise exception 'Delivery access denied'; end if;
  if v_d.status not in ('arrived','delivered') then raise exception 'Returnables can be recorded only at customer'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  if p_condition not in ('good','damaged','rejected') then raise exception 'Invalid returnable condition'; end if;
  if not exists(select 1 from public.inventory_items where id=p_item_id and organization_id=v_d.organization_id and is_active and (is_returnable or item_type='cylinder')) then raise exception 'Item is not configured as returnable'; end if;
  select id into v_pickup from public.dispatch_returnable_pickups where delivery_id=v_d.id;
  if v_pickup is null then
    insert into public.dispatch_returnable_pickups(organization_id,factory_id,delivery_id,created_by) values(v_d.organization_id,v_d.factory_id,v_d.id,auth.uid()) returning id into v_pickup;
  end if;
  v_tx:=public.dispatch_post_receive(v_d.factory_id,p_item_id,v_d.vehicle_location_id,p_quantity,v_d.delivery_no,'Customer returnable pickup');
  insert into public.dispatch_returnable_lines(organization_id,pickup_id,item_id,quantity,condition,vehicle_receive_transaction_id,notes)
  values(v_d.organization_id,v_pickup,p_item_id,p_quantity,p_condition,v_tx,nullif(trim(coalesce(p_notes,'')),'')) returning id into v_line;
  return v_line;
end; $$;
grant execute on function public.dispatch_record_returnable(uuid,uuid,numeric,text,text) to authenticated;

create or replace function public.dispatch_complete_returnables(p_delivery_id uuid,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_d public.dispatch_deliveries%rowtype; v_pickup public.dispatch_returnable_pickups%rowtype;
begin
  select * into v_d from public.dispatch_deliveries where id=p_delivery_id;
  if v_d.id is null then raise exception 'Delivery not found'; end if;
  if not public.can_manage_factory(v_d.factory_id) and not public.dispatch_driver_can_access_delivery(v_d.id) then raise exception 'Delivery access denied'; end if;
  select * into v_pickup from public.dispatch_returnable_pickups where delivery_id=v_d.id for update;
  if v_pickup.id is null then raise exception 'Returnable pickup not found'; end if;
  if v_pickup.status<>'open' then raise exception 'Returnable pickup is not open'; end if;
  update public.dispatch_returnable_pickups set status='completed',completed_at=now(),notes=coalesce(nullif(trim(coalesce(p_notes,'')),''),notes) where id=v_pickup.id;
end; $$;
grant execute on function public.dispatch_complete_returnables(uuid,text) to authenticated;

create or replace function public.dispatch_report_exception(
  p_delivery_id uuid,
  p_exception_type text,
  p_details text,
  p_item_id uuid default null,
  p_quantity numeric default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_d public.dispatch_deliveries%rowtype; v_id uuid;
begin
  select * into v_d from public.dispatch_deliveries where id=p_delivery_id;
  if v_d.id is null then raise exception 'Delivery not found'; end if;
  if not public.can_manage_factory(v_d.factory_id) and not public.dispatch_driver_can_access_delivery(v_d.id) then raise exception 'Delivery access denied'; end if;
  if p_exception_type not in ('shortage','damage','customer_rejected','address_unreachable','vehicle_issue','other') then raise exception 'Invalid exception type'; end if;
  if char_length(trim(coalesce(p_details,'')))<3 then raise exception 'Exception details are required'; end if;
  insert into public.dispatch_delivery_exceptions(organization_id,factory_id,delivery_id,item_id,exception_type,quantity,details,created_by)
  values(v_d.organization_id,v_d.factory_id,v_d.id,p_item_id,p_exception_type,p_quantity,trim(p_details),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.dispatch_report_exception(uuid,text,text,uuid,numeric) to authenticated;

create or replace function public.dispatch_resolve_exception(p_exception_id uuid,p_resolution_note text)
returns void language plpgsql security definer set search_path=public as $$
declare v_e public.dispatch_delivery_exceptions%rowtype;
begin
  select * into v_e from public.dispatch_delivery_exceptions where id=p_exception_id for update;
  if v_e.id is null then raise exception 'Delivery exception not found'; end if;
  if not public.can_manage_factory(v_e.factory_id) then raise exception 'Factory manager access required'; end if;
  if v_e.status<>'open' then raise exception 'Exception is not open'; end if;
  if char_length(trim(coalesce(p_resolution_note,'')))<3 then raise exception 'Resolution note is required'; end if;
  update public.dispatch_delivery_exceptions set status='resolved',resolution_note=trim(p_resolution_note),resolved_by=auth.uid(),resolved_at=now() where id=v_e.id;
end; $$;
grant execute on function public.dispatch_resolve_exception(uuid,text) to authenticated;

create or replace function public.dispatch_dashboard_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
  if not public.is_org_member(p_organization_id) and not public.is_platform_owner() then raise exception 'Organization access denied'; end if;
  select jsonb_build_object(
    'ready_to_load',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and d.status='ready_to_load' and (p_factory_id is null or d.factory_id=p_factory_id) and public.can_view_dispatch_factory(d.factory_id)),
    'loaded',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and d.status='loaded' and (p_factory_id is null or d.factory_id=p_factory_id) and public.can_view_dispatch_factory(d.factory_id)),
    'in_transit',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and d.status in ('in_transit','arrived') and (p_factory_id is null or d.factory_id=p_factory_id) and public.can_view_dispatch_factory(d.factory_id)),
    'delivered_today',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and d.status='delivered' and d.delivered_at::date=current_date and (p_factory_id is null or d.factory_id=p_factory_id) and public.can_view_dispatch_factory(d.factory_id)),
    'open_exceptions',(select count(*) from public.dispatch_delivery_exceptions e where e.organization_id=p_organization_id and e.status='open' and (p_factory_id is null or e.factory_id=p_factory_id) and public.can_view_dispatch_factory(e.factory_id)),
    'open_returnables',(select count(*) from public.dispatch_returnable_pickups p where p.organization_id=p_organization_id and p.status='open' and (p_factory_id is null or p.factory_id=p_factory_id) and public.can_view_dispatch_factory(p.factory_id))
  ) into result;
  return result;
end; $$;
grant execute on function public.dispatch_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.audit_dispatch_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_factory uuid; v_entity uuid; v_payload jsonb;
begin
  v_org:=coalesce(new.organization_id,old.organization_id);
  if tg_table_name='dispatch_delivery_lines' then
    select factory_id into v_factory from public.dispatch_deliveries where id=coalesce(new.delivery_id,old.delivery_id);
  elsif tg_table_name='dispatch_returnable_lines' then
    select p.factory_id into v_factory from public.dispatch_returnable_pickups p where p.id=coalesce(new.pickup_id,old.pickup_id);
  else
    v_factory:=coalesce(new.factory_id,old.factory_id);
  end if;
  v_entity:=coalesce(new.id,old.id);
  v_payload:=case when tg_op='INSERT' then jsonb_build_object('after',to_jsonb(new)) when tg_op='UPDATE' then jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new)) else jsonb_build_object('before',to_jsonb(old)) end;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_org,v_factory,auth.uid(),lower(tg_op),tg_table_name,v_entity::text,v_payload);
  return coalesce(new,old);
end; $$;
revoke all on function public.audit_dispatch_change() from public;

create trigger dispatch_deliveries_audit after insert or update on public.dispatch_deliveries for each row execute function public.audit_dispatch_change();
create trigger dispatch_delivery_lines_audit after insert or update on public.dispatch_delivery_lines for each row execute function public.audit_dispatch_change();
create trigger dispatch_returnable_pickups_audit after insert or update on public.dispatch_returnable_pickups for each row execute function public.audit_dispatch_change();
create trigger dispatch_returnable_lines_audit after insert on public.dispatch_returnable_lines for each row execute function public.audit_dispatch_change();
create trigger dispatch_exceptions_audit after insert or update on public.dispatch_delivery_exceptions for each row execute function public.audit_dispatch_change();

commit;
