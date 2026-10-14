-- FactoryOS Warehouse + Dispatch transactional schema
-- Depends on core/RBAC, Inventory, Sales, HR, Fleet and Delivery schemas.

create type public.warehouse_transfer_status as enum ('draft','ready','in_progress','completed','blocked','cancelled');
create type public.dispatch_status as enum ('planned','ready','loading','loaded','dispatched','blocked','cancelled');

create table public.warehouse_transfers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  transfer_number text not null,
  source_warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  destination_warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  status public.warehouse_transfer_status not null default 'draft',
  reason text,
  assigned_employee_id uuid references public.employees(id) on delete set null,
  out_stock_transaction_id uuid unique references public.stock_transactions(id) on delete restrict,
  in_stock_transaction_id uuid unique references public.stock_transactions(id) on delete restrict,
  started_at timestamptz,
  completed_at timestamptz,
  blocked_reason text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, transfer_number),
  check (status <> 'blocked' or length(btrim(coalesce(blocked_reason,''))) > 0),
  check (completed_at is null or started_at is null or completed_at >= started_at)
);

create table public.warehouse_transfer_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  warehouse_transfer_id uuid not null references public.warehouse_transfers(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete restrict,
  batch_id uuid references public.batches(id) on delete restrict,
  serial_number_id uuid references public.serial_numbers(id) on delete restrict,
  source_location_id uuid references public.warehouse_locations(id) on delete restrict,
  destination_location_id uuid references public.warehouse_locations(id) on delete restrict,
  quantity numeric(18,4) not null check (quantity > 0),
  created_at timestamptz not null default now(),
  unique nulls not distinct (warehouse_transfer_id,item_id,batch_id,serial_number_id,source_location_id,destination_location_id),
  check (not (batch_id is not null and serial_number_id is not null))
);

create table public.dispatch_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  dispatch_number text not null,
  sales_order_id uuid not null references public.sales_orders(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  trip_id uuid references public.trips(id) on delete restrict,
  loading_bay text,
  package_count integer not null default 0 check (package_count >= 0),
  weight_kg numeric(12,3) not null default 0 check (weight_kg >= 0),
  status public.dispatch_status not null default 'planned',
  planned_at timestamptz,
  started_at timestamptz,
  loaded_at timestamptz,
  dispatched_at timestamptz,
  blocked_reason text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, dispatch_number),
  check (status <> 'blocked' or length(btrim(coalesce(blocked_reason,''))) > 0),
  check (loaded_at is null or started_at is null or loaded_at >= started_at),
  check (dispatched_at is null or loaded_at is null or dispatched_at >= loaded_at)
);

create table public.dispatch_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  dispatch_order_id uuid not null references public.dispatch_orders(id) on delete cascade,
  sales_order_line_id uuid not null references public.sales_order_lines(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  batch_id uuid references public.batches(id) on delete restrict,
  serial_number_id uuid references public.serial_numbers(id) on delete restrict,
  source_location_id uuid references public.warehouse_locations(id) on delete restrict,
  planned_quantity numeric(18,4) not null check (planned_quantity > 0),
  loaded_quantity numeric(18,4) not null default 0 check (loaded_quantity >= 0),
  stock_transaction_line_id uuid unique references public.stock_transaction_lines(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (dispatch_order_id, sales_order_line_id),
  check (loaded_quantity <= planned_quantity),
  check (not (batch_id is not null and serial_number_id is not null))
);

create table public.dispatch_checks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  dispatch_order_id uuid not null references public.dispatch_orders(id) on delete cascade,
  check_key text not null check (check_key in ('invoice','e_way_bill','packing_list','vehicle_weight','qc_release','other')),
  label text not null,
  is_required boolean not null default true,
  is_complete boolean not null default false,
  evidence_reference text,
  completed_by uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (dispatch_order_id, check_key),
  check (not is_complete or completed_at is not null)
);

create table public.dispatch_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  dispatch_order_id uuid not null references public.dispatch_orders(id) on delete cascade,
  event_type text not null check (event_type in ('planned','ready','loading_started','stock_posted','loaded','dispatched','blocked','cancelled')),
  event_at timestamptz not null default now(),
  actor_user_id uuid references auth.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create index warehouse_transfers_org_factory_status_idx on public.warehouse_transfers(organization_id,factory_id,status,created_at desc);
create index warehouse_transfer_lines_transfer_idx on public.warehouse_transfer_lines(warehouse_transfer_id);
create index dispatch_orders_org_factory_status_idx on public.dispatch_orders(organization_id,factory_id,status,planned_at);
create index dispatch_orders_sales_order_idx on public.dispatch_orders(sales_order_id,status);
create index dispatch_lines_dispatch_idx on public.dispatch_lines(dispatch_order_id);
create index dispatch_events_dispatch_time_idx on public.dispatch_events(dispatch_order_id,event_at);

create trigger warehouse_transfers_set_updated_at before update on public.warehouse_transfers for each row execute function private.set_updated_at();
create trigger dispatch_orders_set_updated_at before update on public.dispatch_orders for each row execute function private.set_updated_at();
create trigger dispatch_lines_set_updated_at before update on public.dispatch_lines for each row execute function private.set_updated_at();
create trigger dispatch_checks_set_updated_at before update on public.dispatch_checks for each row execute function private.set_updated_at();

create or replace function private.validate_warehouse_transfer_refs()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  source_org uuid; source_factory uuid; destination_org uuid; destination_factory uuid; employee_org uuid;
begin
  select organization_id,factory_id into source_org,source_factory from public.warehouses where id=new.source_warehouse_id;
  select organization_id,factory_id into destination_org,destination_factory from public.warehouses where id=new.destination_warehouse_id;
  if source_org is null or destination_org is null then raise exception 'invalid warehouse transfer warehouse'; end if;
  if source_org <> new.organization_id or destination_org <> new.organization_id then raise exception 'warehouse transfer organization mismatch'; end if;
  if source_factory is distinct from new.factory_id or destination_factory is distinct from new.factory_id then raise exception 'warehouse transfer factory mismatch'; end if;
  if new.assigned_employee_id is not null then
    select organization_id into employee_org from public.employees where id=new.assigned_employee_id;
    if employee_org is distinct from new.organization_id then raise exception 'warehouse transfer employee organization mismatch'; end if;
  end if;
  return new;
end;
$$;

create or replace function private.validate_warehouse_transfer_line_refs()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  transfer_org uuid; source_wh uuid; destination_wh uuid; item_org uuid; batch_item uuid; serial_item uuid; source_location_wh uuid; destination_location_wh uuid;
begin
  select organization_id,source_warehouse_id,destination_warehouse_id into transfer_org,source_wh,destination_wh from public.warehouse_transfers where id=new.warehouse_transfer_id;
  if transfer_org is null or transfer_org <> new.organization_id then raise exception 'warehouse transfer line organization mismatch'; end if;
  select organization_id into item_org from public.items where id=new.item_id;
  if item_org is distinct from new.organization_id then raise exception 'warehouse transfer line item organization mismatch'; end if;
  if new.batch_id is not null then
    select item_id into batch_item from public.batches where id=new.batch_id and organization_id=new.organization_id;
    if batch_item is distinct from new.item_id then raise exception 'warehouse transfer batch/item mismatch'; end if;
  end if;
  if new.serial_number_id is not null then
    select item_id into serial_item from public.serial_numbers where id=new.serial_number_id and organization_id=new.organization_id;
    if serial_item is distinct from new.item_id then raise exception 'warehouse transfer serial/item mismatch'; end if;
  end if;
  if new.source_location_id is not null then
    select warehouse_id into source_location_wh from public.warehouse_locations where id=new.source_location_id and organization_id=new.organization_id;
    if source_location_wh is distinct from source_wh then raise exception 'warehouse transfer source location mismatch'; end if;
  end if;
  if new.destination_location_id is not null then
    select warehouse_id into destination_location_wh from public.warehouse_locations where id=new.destination_location_id and organization_id=new.organization_id;
    if destination_location_wh is distinct from destination_wh then raise exception 'warehouse transfer destination location mismatch'; end if;
  end if;
  if source_wh = destination_wh and new.source_location_id is not distinct from new.destination_location_id then
    raise exception 'warehouse transfer source and destination cannot be identical';
  end if;
  return new;
end;
$$;

create trigger warehouse_transfers_validate_refs before insert or update on public.warehouse_transfers for each row execute function private.validate_warehouse_transfer_refs();
create trigger warehouse_transfer_lines_validate_refs before insert or update on public.warehouse_transfer_lines for each row execute function private.validate_warehouse_transfer_line_refs();

create or replace function private.validate_dispatch_order_refs()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  order_org uuid; order_factory uuid; warehouse_org uuid; warehouse_factory uuid; trip_org uuid; trip_factory uuid; trip_order uuid;
begin
  select organization_id,factory_id into order_org,order_factory from public.sales_orders where id=new.sales_order_id;
  select organization_id,factory_id into warehouse_org,warehouse_factory from public.warehouses where id=new.warehouse_id;
  if order_org is null or warehouse_org is null then raise exception 'invalid dispatch order reference'; end if;
  if order_org <> new.organization_id or warehouse_org <> new.organization_id then raise exception 'dispatch organization mismatch'; end if;
  if order_factory <> new.factory_id or warehouse_factory is distinct from new.factory_id then raise exception 'dispatch factory mismatch'; end if;
  if new.trip_id is not null then
    select organization_id,factory_id,sales_order_id into trip_org,trip_factory,trip_order from public.trips where id=new.trip_id;
    if trip_org is distinct from new.organization_id or trip_factory is distinct from new.factory_id then raise exception 'dispatch trip scope mismatch'; end if;
    if trip_order is not null and trip_order <> new.sales_order_id then raise exception 'dispatch trip sales order mismatch'; end if;
  end if;
  return new;
end;
$$;

create or replace function private.validate_dispatch_line_refs()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  dispatch_org uuid; dispatch_order uuid; dispatch_warehouse uuid; line_order uuid; line_item uuid; batch_item uuid; serial_item uuid; location_wh uuid; ordered_qty numeric; already_planned numeric;
begin
  select organization_id,sales_order_id,warehouse_id into dispatch_org,dispatch_order,dispatch_warehouse from public.dispatch_orders where id=new.dispatch_order_id;
  if dispatch_org is null or dispatch_org <> new.organization_id then raise exception 'dispatch line organization mismatch'; end if;
  select sales_order_id,item_id,ordered_quantity into line_order,line_item,ordered_qty from public.sales_order_lines where id=new.sales_order_line_id;
  if line_order is null or line_order <> dispatch_order or line_item <> new.item_id then raise exception 'dispatch line must match sales order line'; end if;
  if new.batch_id is not null then
    select item_id into batch_item from public.batches where id=new.batch_id and organization_id=new.organization_id;
    if batch_item is distinct from new.item_id then raise exception 'dispatch batch/item mismatch'; end if;
  end if;
  if new.serial_number_id is not null then
    select item_id into serial_item from public.serial_numbers where id=new.serial_number_id and organization_id=new.organization_id;
    if serial_item is distinct from new.item_id then raise exception 'dispatch serial/item mismatch'; end if;
  end if;
  if new.source_location_id is not null then
    select warehouse_id into location_wh from public.warehouse_locations where id=new.source_location_id and organization_id=new.organization_id;
    if location_wh is distinct from dispatch_warehouse then raise exception 'dispatch source location mismatch'; end if;
  end if;
  select coalesce(sum(dl.planned_quantity),0) into already_planned
  from public.dispatch_lines dl join public.dispatch_orders d on d.id=dl.dispatch_order_id
  where dl.sales_order_line_id=new.sales_order_line_id
    and dl.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
    and d.status<>'cancelled';
  if already_planned + new.planned_quantity > ordered_qty then raise exception 'dispatch quantity exceeds sales order line'; end if;
  return new;
end;
$$;

create or replace function private.validate_dispatch_child_org()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare dispatch_org uuid;
begin
  select organization_id into dispatch_org from public.dispatch_orders where id=new.dispatch_order_id;
  if dispatch_org is null or dispatch_org <> new.organization_id then raise exception 'dispatch child organization mismatch'; end if;
  return new;
end;
$$;

create trigger dispatch_orders_validate_refs before insert or update on public.dispatch_orders for each row execute function private.validate_dispatch_order_refs();
create trigger dispatch_lines_validate_refs before insert or update on public.dispatch_lines for each row execute function private.validate_dispatch_line_refs();
create trigger dispatch_checks_validate_refs before insert or update on public.dispatch_checks for each row execute function private.validate_dispatch_child_org();
create trigger dispatch_events_validate_refs before insert or update on public.dispatch_events for each row execute function private.validate_dispatch_child_org();

alter table public.warehouse_transfers enable row level security;
alter table public.warehouse_transfer_lines enable row level security;
alter table public.dispatch_orders enable row level security;
alter table public.dispatch_lines enable row level security;
alter table public.dispatch_checks enable row level security;
alter table public.dispatch_events enable row level security;

create policy warehouse_transfers_select on public.warehouse_transfers for select to authenticated using (
  private.has_warehouse_permission(organization_id,'warehouse.read',source_warehouse_id)
  or private.has_warehouse_permission(organization_id,'warehouse.read',destination_warehouse_id)
);
create policy warehouse_transfers_manage on public.warehouse_transfers for all to authenticated using (
  private.has_warehouse_permission(organization_id,'warehouse.manage',source_warehouse_id)
  and private.has_warehouse_permission(organization_id,'warehouse.manage',destination_warehouse_id)
) with check (
  private.has_warehouse_permission(organization_id,'warehouse.manage',source_warehouse_id)
  and private.has_warehouse_permission(organization_id,'warehouse.manage',destination_warehouse_id)
);
create policy warehouse_transfer_lines_select on public.warehouse_transfer_lines for select to authenticated using (
  exists(select 1 from public.warehouse_transfers wt where wt.id=warehouse_transfer_id and (
    private.has_warehouse_permission(wt.organization_id,'warehouse.read',wt.source_warehouse_id)
    or private.has_warehouse_permission(wt.organization_id,'warehouse.read',wt.destination_warehouse_id)))
);
create policy warehouse_transfer_lines_manage on public.warehouse_transfer_lines for all to authenticated using (
  exists(select 1 from public.warehouse_transfers wt where wt.id=warehouse_transfer_id
    and private.has_warehouse_permission(wt.organization_id,'warehouse.manage',wt.source_warehouse_id)
    and private.has_warehouse_permission(wt.organization_id,'warehouse.manage',wt.destination_warehouse_id))
) with check (
  exists(select 1 from public.warehouse_transfers wt where wt.id=warehouse_transfer_id
    and private.has_warehouse_permission(wt.organization_id,'warehouse.manage',wt.source_warehouse_id)
    and private.has_warehouse_permission(wt.organization_id,'warehouse.manage',wt.destination_warehouse_id))
);

create policy dispatch_orders_select on public.dispatch_orders for select to authenticated using (
  private.has_factory_permission(organization_id,'dispatch.read',factory_id)
  or private.has_warehouse_permission(organization_id,'dispatch.read',warehouse_id)
);
create policy dispatch_orders_manage on public.dispatch_orders for all to authenticated using (
  private.has_factory_permission(organization_id,'dispatch.manage',factory_id)
  or private.has_warehouse_permission(organization_id,'dispatch.manage',warehouse_id)
) with check (
  private.has_factory_permission(organization_id,'dispatch.manage',factory_id)
  or private.has_warehouse_permission(organization_id,'dispatch.manage',warehouse_id)
);
create policy dispatch_lines_select on public.dispatch_lines for select to authenticated using (
  exists(select 1 from public.dispatch_orders d where d.id=dispatch_order_id and (
    private.has_factory_permission(d.organization_id,'dispatch.read',d.factory_id)
    or private.has_warehouse_permission(d.organization_id,'dispatch.read',d.warehouse_id)))
);
create policy dispatch_lines_manage on public.dispatch_lines for all to authenticated using (
  exists(select 1 from public.dispatch_orders d where d.id=dispatch_order_id and (
    private.has_factory_permission(d.organization_id,'dispatch.manage',d.factory_id)
    or private.has_warehouse_permission(d.organization_id,'dispatch.manage',d.warehouse_id)))
) with check (
  exists(select 1 from public.dispatch_orders d where d.id=dispatch_order_id and (
    private.has_factory_permission(d.organization_id,'dispatch.manage',d.factory_id)
    or private.has_warehouse_permission(d.organization_id,'dispatch.manage',d.warehouse_id)))
);
create policy dispatch_checks_select on public.dispatch_checks for select to authenticated using (
  exists(select 1 from public.dispatch_orders d where d.id=dispatch_order_id and (
    private.has_factory_permission(d.organization_id,'dispatch.read',d.factory_id)
    or private.has_warehouse_permission(d.organization_id,'dispatch.read',d.warehouse_id)))
);
create policy dispatch_checks_manage on public.dispatch_checks for all to authenticated using (
  exists(select 1 from public.dispatch_orders d where d.id=dispatch_order_id and (
    private.has_factory_permission(d.organization_id,'dispatch.manage',d.factory_id)
    or private.has_warehouse_permission(d.organization_id,'dispatch.manage',d.warehouse_id)))
) with check (
  exists(select 1 from public.dispatch_orders d where d.id=dispatch_order_id and (
    private.has_factory_permission(d.organization_id,'dispatch.manage',d.factory_id)
    or private.has_warehouse_permission(d.organization_id,'dispatch.manage',d.warehouse_id)))
);
create policy dispatch_events_select on public.dispatch_events for select to authenticated using (
  exists(select 1 from public.dispatch_orders d where d.id=dispatch_order_id and (
    private.has_factory_permission(d.organization_id,'dispatch.read',d.factory_id)
    or private.has_warehouse_permission(d.organization_id,'dispatch.read',d.warehouse_id)))
);

-- Events are written by trusted command functions, not directly by clients.
grant select,insert,update,delete on public.warehouse_transfers,public.warehouse_transfer_lines to authenticated;
grant select,insert,update,delete on public.dispatch_orders,public.dispatch_lines,public.dispatch_checks to authenticated;
grant select on public.dispatch_events to authenticated;
