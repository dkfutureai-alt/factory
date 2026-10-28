begin;

-- Phase 20: close the physical reverse logistics loop.
-- Driver pickup already posts stock to the vehicle in Phase 10. This step
-- moves it to a segregated receiving/quarantine location through the existing
-- immutable Inventory ledger, never through an untracked quantity update.
create table public.dispatch_returnable_intakes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  pickup_id uuid not null unique,
  vehicle_location_id uuid not null,
  receiving_location_id uuid not null,
  quarantine_location_id uuid not null,
  received_by uuid references auth.users(id) on delete set null,
  received_at timestamptz not null default now(),
  notes text check (notes is null or char_length(notes) <= 500),
  unique (id, organization_id),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict,
  foreign key (pickup_id, organization_id)
    references public.dispatch_returnable_pickups(id, organization_id) on delete restrict,
  foreign key (vehicle_location_id, factory_id)
    references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (receiving_location_id, factory_id)
    references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (quarantine_location_id, factory_id)
    references public.stock_locations(id, factory_id) on delete restrict,
  check (receiving_location_id <> quarantine_location_id),
  check (vehicle_location_id <> receiving_location_id),
  check (vehicle_location_id <> quarantine_location_id)
);
create index dispatch_returnable_intakes_factory_recent_idx
  on public.dispatch_returnable_intakes(factory_id, received_at desc);
create index dispatch_returnable_intakes_received_by_idx
  on public.dispatch_returnable_intakes(received_by);
-- The existing structural QA requires indexes leading with *every* FK key.
create index dispatch_returnable_intakes_org_fk_idx
  on public.dispatch_returnable_intakes(organization_id);
create index dispatch_returnable_intakes_factory_org_fk_idx
  on public.dispatch_returnable_intakes(factory_id, organization_id);
create index dispatch_returnable_intakes_pickup_org_fk_idx
  on public.dispatch_returnable_intakes(pickup_id, organization_id);
create index dispatch_returnable_intakes_vehicle_factory_fk_idx
  on public.dispatch_returnable_intakes(vehicle_location_id, factory_id);
create index dispatch_returnable_intakes_receiving_factory_fk_idx
  on public.dispatch_returnable_intakes(receiving_location_id, factory_id);
create index dispatch_returnable_intakes_quarantine_factory_fk_idx
  on public.dispatch_returnable_intakes(quarantine_location_id, factory_id);

create table public.dispatch_returnable_intake_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  intake_id uuid not null,
  returnable_line_id uuid not null unique,
  item_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  condition text not null check (condition in ('good','damaged','rejected')),
  destination_location_id uuid not null,
  transfer_transaction_id uuid not null unique
    references public.inventory_transactions(id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (intake_id, organization_id)
    references public.dispatch_returnable_intakes(id, organization_id) on delete restrict,
  foreign key (returnable_line_id, organization_id)
    references public.dispatch_returnable_lines(id, organization_id) on delete restrict,
  foreign key (item_id, organization_id)
    references public.inventory_items(id, organization_id) on delete restrict
);
create index dispatch_returnable_intake_lines_intake_idx
  on public.dispatch_returnable_intake_lines(intake_id);
create index dispatch_returnable_intake_lines_intake_org_fk_idx
  on public.dispatch_returnable_intake_lines(intake_id, organization_id);
create index dispatch_returnable_intake_lines_line_org_fk_idx
  on public.dispatch_returnable_intake_lines(returnable_line_id, organization_id);
create index dispatch_returnable_intake_lines_item_org_fk_idx
  on public.dispatch_returnable_intake_lines(item_id, organization_id);

alter table public.dispatch_returnable_intakes enable row level security;
alter table public.dispatch_returnable_intake_lines enable row level security;

-- Authenticated clients may only read authorized intake records. Only the
-- guarded RPC can write them; service_role is for trusted backend operations.
revoke all on public.dispatch_returnable_intakes,
              public.dispatch_returnable_intake_lines from anon, authenticated;
grant select on public.dispatch_returnable_intakes,
                public.dispatch_returnable_intake_lines to authenticated;
grant select, insert, update, delete on public.dispatch_returnable_intakes,
                                       public.dispatch_returnable_intake_lines to service_role;

create policy dispatch_returnable_intakes_read
on public.dispatch_returnable_intakes for select to authenticated
using (public.can_view_dispatch_factory(factory_id));

create policy dispatch_returnable_intake_lines_read
on public.dispatch_returnable_intake_lines for select to authenticated
using (exists(
  select 1 from public.dispatch_returnable_intakes i
  where i.id = intake_id
    and i.organization_id = dispatch_returnable_intake_lines.organization_id
    and public.can_view_dispatch_factory(i.factory_id)
));

-- Atomic and retry-safe intake: lock pickup first, then transfer all pickup
-- lines via the warehouse ledger function (which locks each item/source).
-- An existing successful intake returns its ID only for matching destinations.
-- Failed transfers roll back both the intake and its ledger movements.
create function public.dispatch_intake_returnables(
  p_pickup_id uuid,
  p_receiving_location_id uuid,
  p_quarantine_location_id uuid,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_p public.dispatch_returnable_pickups%rowtype;
  v_d public.dispatch_deliveries%rowtype;
  v_existing public.dispatch_returnable_intakes%rowtype;
  v_intake uuid;
  v_line public.dispatch_returnable_lines%rowtype;
  v_destination uuid;
  v_tx uuid;
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_pickup_id is null or p_receiving_location_id is null
     or p_quarantine_location_id is null
     or p_receiving_location_id = p_quarantine_location_id then
    raise exception 'Distinct receiving and quarantine locations are required';
  end if;
  if char_length(coalesce(p_notes, '')) > 500 then
    raise exception 'Intake notes exceed 500 characters';
  end if;

  select * into v_p from public.dispatch_returnable_pickups
  where id = p_pickup_id for update;
  if v_p.id is null or not public.can_operate_warehouse_factory(v_p.factory_id) then
    raise exception 'Returnable intake not available or access denied';
  end if;
  if v_p.status <> 'completed' then
    raise exception 'Customer returnable pickup must be closed before intake';
  end if;
  select * into v_d from public.dispatch_deliveries where id = v_p.delivery_id;
  if v_d.id is null or v_d.organization_id <> v_p.organization_id
     or v_d.factory_id <> v_p.factory_id
     or v_d.status not in ('delivered','failed') then
    raise exception 'Delivery must finish before returnable warehouse intake';
  end if;

  select * into v_existing from public.dispatch_returnable_intakes
  where pickup_id = v_p.id;
  if v_existing.id is not null then
    if v_existing.receiving_location_id <> p_receiving_location_id
       or v_existing.quarantine_location_id <> p_quarantine_location_id then
      raise exception 'Intake already completed with different destinations';
    end if;
    return v_existing.id;
  end if;

  if not exists(
    select 1 from public.stock_locations
    where id = v_d.vehicle_location_id and factory_id = v_p.factory_id
      and organization_id = v_p.organization_id and is_active
      and location_type = 'vehicle'
  ) then
    raise exception 'Active dispatch vehicle stock location not found';
  end if;
  if not exists(
    select 1 from public.stock_locations
    where id = p_receiving_location_id and factory_id = v_p.factory_id
      and organization_id = v_p.organization_id and is_active
      and location_type = 'receiving'
  ) then
    raise exception 'Select an active receiving location in this factory';
  end if;
  if not exists(
    select 1 from public.stock_locations
    where id = p_quarantine_location_id and factory_id = v_p.factory_id
      and organization_id = v_p.organization_id and is_active
      and location_type = 'quarantine'
  ) then
    raise exception 'Select an active quarantine location in this factory';
  end if;

  insert into public.dispatch_returnable_intakes(
    organization_id, factory_id, pickup_id, vehicle_location_id,
    receiving_location_id, quarantine_location_id, received_by, notes
  ) values (
    v_p.organization_id, v_p.factory_id, v_p.id, v_d.vehicle_location_id,
    p_receiving_location_id, p_quarantine_location_id, auth.uid(),
    nullif(trim(coalesce(p_notes, '')), '')
  ) returning id into v_intake;

  for v_line in
    select * from public.dispatch_returnable_lines
    where pickup_id = v_p.id
    order by item_id, condition
    for update
  loop
    -- Trace every pickup quantity to its exact vehicle receipt. No fabricated
    -- returns or amount mismatches may become a warehouse intake.
    if not exists (
      select 1 from public.inventory_transactions tx
      where tx.id = v_line.vehicle_receive_transaction_id
        and tx.organization_id = v_p.organization_id
        and tx.factory_id = v_p.factory_id
        and tx.item_id = v_line.item_id
        and tx.transaction_type = 'receive'
        and tx.to_location_id = v_d.vehicle_location_id
        and tx.quantity = v_line.quantity
    ) then
      raise exception 'Returnable line has an invalid vehicle receipt';
    end if;
    v_destination := case when v_line.condition = 'good'
      then p_receiving_location_id else p_quarantine_location_id end;
    v_tx := public.warehouse_transfer_stock_internal(
      v_p.factory_id, v_line.item_id, v_d.vehicle_location_id,
      v_destination, v_line.quantity, v_p.pickup_no,
      'Returnable warehouse intake: ' || v_line.condition
    );
    insert into public.dispatch_returnable_intake_lines(
      organization_id, intake_id, returnable_line_id, item_id, quantity,
      condition, destination_location_id, transfer_transaction_id
    ) values (
      v_p.organization_id, v_intake, v_line.id, v_line.item_id,
      v_line.quantity, v_line.condition, v_destination, v_tx
    );
    v_count := v_count + 1;
  end loop;
  if v_count = 0 then
    raise exception 'No customer returnable lines to receive';
  end if;
  return v_intake;
end;
$$;

revoke all on function public.dispatch_intake_returnables(uuid,uuid,uuid,text)
from public, anon;
grant execute on function public.dispatch_intake_returnables(uuid,uuid,uuid,text)
to authenticated;

-- Existing dispatch audit pipeline hashes the inserted intake header.
-- Every stock movement also has its own Inventory transaction/ledger trail.
create trigger dispatch_returnable_intakes_audit
after insert on public.dispatch_returnable_intakes
for each row execute function public.audit_dispatch_change();

-- A returned cylinder in receiving/quarantine must NEVER be sold before
-- an independent inspection/refill release. Existing commercial allocation
-- accepted any active location, so pin sale allocation to approved warehouse,
-- bin or dispatch locations. This is enforced at the database boundary.
create or replace function public.commercial_allocate_sales_order(
  p_sales_order_id uuid, p_location_id uuid
)
returns void language plpgsql security definer set search_path=public as $
declare
  v_so public.sales_orders%rowtype;
  v_line public.sales_order_lines%rowtype;
  v_need numeric;
  v_available numeric;
begin
  select * into v_so from public.sales_orders where id=p_sales_order_id for update;
  if v_so.id is null then raise exception 'Sales order not found'; end if;
  if not public.can_operate_commercial_factory(v_so.factory_id) then
    raise exception 'Not allowed for this factory';
  end if;
  if v_so.status not in ('confirmed','allocated') then
    raise exception 'Sales order cannot be allocated from status %',v_so.status;
  end if;
  if not exists(
    select 1 from public.stock_locations
    where id=p_location_id and factory_id=v_so.factory_id and is_active
      and location_type in ('warehouse','bin','dispatch')
  ) then
    raise exception 'Sales allocation requires active warehouse, bin or dispatch stock; receiving and quarantine are blocked';
  end if;
  for v_line in
    select * from public.sales_order_lines
    where sales_order_id=p_sales_order_id order by id for update
  loop
    v_need:=v_line.ordered_quantity-v_line.allocated_quantity;
    if v_need>0 then
      perform pg_advisory_xact_lock(hashtext(v_line.item_id::text||':'||p_location_id::text));
      select public.commercial_available_stock(v_line.item_id,p_location_id) into v_available;
      if v_available<v_need then
        raise exception 'Insufficient available stock for item %: need %, available %',
          v_line.item_id,v_need,v_available;
      end if;
      insert into public.sales_allocations(
        organization_id,factory_id,sales_order_id,sales_order_line_id,
        item_id,location_id,quantity,status,created_by
      ) values (
        v_so.organization_id,v_so.factory_id,v_so.id,v_line.id,
        v_line.item_id,p_location_id,v_need,'allocated',auth.uid()
      );
      update public.sales_order_lines
      set allocated_quantity=allocated_quantity+v_need where id=v_line.id;
    end if;
  end loop;
  update public.sales_orders set status='allocated',dispatch_ready_at=null
  where id=p_sales_order_id;
end; $;
revoke all on function public.commercial_allocate_sales_order(uuid,uuid) from public, anon;
grant execute on function public.commercial_allocate_sales_order(uuid,uuid) to authenticated;

commit;
