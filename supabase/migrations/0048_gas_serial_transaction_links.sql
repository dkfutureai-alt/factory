begin;

-- Phase 21B: auditable links between physical container serials and already
-- committed immutable Inventory transactions. This DOES NOT move inventory,
-- prove unscanned custody or bypass existing warehouse/dispatch controls.
create table public.gas_container_transaction_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  asset_id uuid not null,
  transaction_id uuid not null references public.inventory_transactions(id) on delete restrict,
  request_key uuid not null,
  transaction_type text not null check (transaction_type in ('opening','receive','transfer','issue')),
  from_location_id uuid,
  to_location_id uuid,
  customer_id uuid,
  recorded_by uuid references auth.users(id) on delete set null,
  recorded_at timestamptz not null default now(),
  notes text,
  unique(organization_id,request_key),
  unique(asset_id,transaction_id),
  unique(id,organization_id),
  foreign key(factory_id,organization_id)
    references public.factories(id,organization_id) on delete restrict,
  foreign key(asset_id,organization_id)
    references public.gas_container_assets(id,organization_id) on delete restrict,
  foreign key(from_location_id,factory_id)
    references public.stock_locations(id,factory_id) on delete restrict,
  foreign key(to_location_id,factory_id)
    references public.stock_locations(id,factory_id) on delete restrict,
  foreign key(customer_id,organization_id)
    references public.business_partners(id,organization_id) on delete restrict,
  check (from_location_id is distinct from to_location_id),
  check (
    (transaction_type in ('opening','receive') and from_location_id is null and to_location_id is not null)
    or (transaction_type='issue' and from_location_id is not null and to_location_id is null)
    or (transaction_type='transfer' and from_location_id is not null and to_location_id is not null)
  )
);

create index gas_tx_links_org_fk_idx on public.gas_container_transaction_links(organization_id);
create index gas_tx_links_factory_org_fk_idx on public.gas_container_transaction_links(factory_id,organization_id);
create index gas_tx_links_asset_org_fk_idx on public.gas_container_transaction_links(asset_id,organization_id);
create index gas_tx_links_tx_fk_idx on public.gas_container_transaction_links(transaction_id);
create index gas_tx_links_from_factory_idx on public.gas_container_transaction_links(from_location_id,factory_id);
create index gas_tx_links_to_factory_idx on public.gas_container_transaction_links(to_location_id,factory_id);
create index gas_tx_links_customer_org_idx on public.gas_container_transaction_links(customer_id,organization_id);
create index gas_tx_links_recorded_by_idx on public.gas_container_transaction_links(recorded_by);
create index gas_tx_links_asset_recent_idx on public.gas_container_transaction_links(asset_id,recorded_at desc);

alter table public.gas_container_transaction_links enable row level security;
revoke all on public.gas_container_transaction_links from public,anon,authenticated;
grant select on public.gas_container_transaction_links to authenticated;
grant select,insert,update,delete on public.gas_container_transaction_links to service_role;

create policy gas_container_tx_links_read on public.gas_container_transaction_links
for select to authenticated
using (public.can_view_inventory_factory(factory_id));

-- History is append-only even for privileged callers.
create function public.gas_tx_links_reject_change()
returns trigger language plpgsql set search_path=public as $$
begin
  raise exception 'Serialized Inventory transaction links are immutable';
end; $$;
revoke all on function public.gas_tx_links_reject_change() from public,anon,authenticated;
create trigger gas_tx_links_immutable
before update or delete on public.gas_container_transaction_links
for each row execute function public.gas_tx_links_reject_change();

create function public.gas_tx_links_audit()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.audit_logs(
    organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata
  ) values (
    new.organization_id,new.factory_id,auth.uid(),'insert',
    'gas_container_transaction_links',new.id::text,
    jsonb_build_object('asset_id',new.asset_id,'transaction_id',new.transaction_id,
      'transaction_type',new.transaction_type)
  );
  return new;
end; $$;
revoke all on function public.gas_tx_links_audit() from public,anon,authenticated;
create trigger gas_tx_links_audit
after insert on public.gas_container_transaction_links
for each row execute function public.gas_tx_links_audit();

create function public.gas_link_container_transaction(
  p_asset_id uuid,
  p_transaction_id uuid,
  p_scanned_code text,
  p_request_key uuid
)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_asset public.gas_container_assets%rowtype;
  v_tx public.inventory_transactions%rowtype;
  v_prev public.gas_container_transaction_links%rowtype;
  v_existing public.gas_container_transaction_links%rowtype;
  v_previous_tx_time timestamptz;
  v_ledger_count integer;
  v_ledger_from numeric;
  v_ledger_to numeric;
  v_link_count integer;
  v_customer uuid;
  v_return_customer uuid;
  v_link_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_asset_id is null or p_transaction_id is null or p_request_key is null
      or char_length(trim(coalesce(p_scanned_code,'')))<3 then
    raise exception 'Asset, transaction, scanned serial/QR and request ID are required';
  end if;

  -- Lock the physical asset before its underlying immutable transaction.
  -- This serializes concurrent claims about the same physical container.
  select * into v_asset from public.gas_container_assets
  where id=p_asset_id for update;
  if v_asset.id is null or not public.can_manage_factory(v_asset.factory_id) then
    raise exception 'Asset is not accessible to this factory manager';
  end if;
  if v_asset.state='retired' then raise exception 'Retired asset cannot be linked'; end if;
  if upper(trim(p_scanned_code))<>v_asset.serial_number
     and trim(p_scanned_code)<>v_asset.qr_code then
    raise exception 'Scanned label does not match the registered container';
  end if;

  select * into v_existing from public.gas_container_transaction_links
  where organization_id=v_asset.organization_id and request_key=p_request_key;
  if v_existing.id is not null then
    if v_existing.asset_id<>v_asset.id or v_existing.transaction_id<>p_transaction_id then
      raise exception 'Request ID has already been used for a different container transaction';
    end if;
    return v_existing.id;
  end if;

  select * into v_tx from public.inventory_transactions
  where id=p_transaction_id for update;
  if v_tx.id is null or v_tx.organization_id<>v_asset.organization_id
     or v_tx.factory_id<>v_asset.factory_id or v_tx.item_id<>v_asset.item_id then
    raise exception 'Inventory transaction does not match the container, item and factory';
  end if;
  if v_tx.quantity<1 or v_tx.quantity<>trunc(v_tx.quantity) then
    raise exception 'Serialized container transactions require whole-unit stock quantities';
  end if;

  -- Check the inventory-ledger posting exists before linking a serial to it.
  select count(*),
         coalesce(sum(case when le.location_id=v_tx.from_location_id then le.quantity_delta else 0 end),0),
         coalesce(sum(case when le.location_id=v_tx.to_location_id then le.quantity_delta else 0 end),0)
    into v_ledger_count,v_ledger_from,v_ledger_to
  from public.stock_ledger_entries le
  where le.transaction_id=v_tx.id and le.organization_id=v_tx.organization_id
    and le.factory_id=v_tx.factory_id and le.item_id=v_tx.item_id;
  if (v_tx.transaction_type='transfer' and
       (v_ledger_count<>2 or v_ledger_from<>-v_tx.quantity or v_ledger_to<>v_tx.quantity))
      or (v_tx.transaction_type='issue' and
       (v_ledger_count<>1 or v_ledger_from<>-v_tx.quantity))
      or (v_tx.transaction_type in ('opening','receive') and
       (v_ledger_count<>1 or v_ledger_to<>v_tx.quantity)) then
    raise exception 'Inventory transaction ledger does not reconcile';
  end if;

  select count(*) into v_link_count from public.gas_container_transaction_links
  where transaction_id=v_tx.id;
  if v_link_count>=v_tx.quantity then
    raise exception 'Inventory transaction has no remaining serial-assignment capacity';
  end if;
  if exists(
    select 1 from public.gas_container_transaction_links
    where asset_id=v_asset.id and transaction_id=v_tx.id
  ) then
    raise exception 'Container is already linked to this Inventory transaction';
  end if;

  select l.* into v_prev from public.gas_container_transaction_links l
  where l.asset_id=v_asset.id
  order by l.recorded_at desc,l.id desc limit 1;
  if v_prev.id is null then
    if v_tx.transaction_type not in ('opening','receive') then
      raise exception 'First serial assignment must begin with a recorded stock receipt/opening';
    end if;
  else
    select occurred_at into v_previous_tx_time
    from public.inventory_transactions where id=v_prev.transaction_id;
    if v_tx.occurred_at<v_previous_tx_time then
      raise exception 'Older Inventory transaction cannot follow a later serial event';
    end if;
    if v_tx.transaction_type in ('transfer','issue') and
       v_prev.to_location_id is distinct from v_tx.from_location_id then
      raise exception 'Container movement source does not match its last verified location';
    end if;
    if v_tx.transaction_type in ('opening','receive') and
       v_prev.to_location_id is not null then
      raise exception 'Cannot receive an asset already recorded at an internal location';
    end if;
  end if;

  -- A customer handover must come from completed Dispatch/POD, not an
  -- arbitrary Inventory issue. Do not invent customer custody.
  if v_tx.transaction_type='issue' then
    select d.customer_id into v_customer
    from public.dispatch_delivery_lines line
    join public.dispatch_deliveries d on d.id=line.delivery_id
    where line.delivery_transaction_id=v_tx.id
      and d.factory_id=v_tx.factory_id and d.status='delivered';
    if v_customer is null then
      raise exception 'Customer issue requires an existing delivered Dispatch/POD transaction';
    end if;
  end if;

  -- When an earlier verified serial event issued to a customer, the next
  -- receipt must match a driver-recorded pickup for that same customer.
  if v_prev.id is not null and v_prev.transaction_type='issue' then
    if v_tx.transaction_type<>'receive' then
      raise exception 'Customer-held container must have a documented return receipt';
    end if;
    select d.customer_id into v_return_customer
    from public.dispatch_returnable_lines line
    join public.dispatch_returnable_pickups pickup on pickup.id=line.pickup_id
    join public.dispatch_deliveries d on d.id=pickup.delivery_id
    where line.vehicle_receive_transaction_id=v_tx.id
      and d.factory_id=v_tx.factory_id;
    if v_return_customer is null or v_return_customer<>v_prev.customer_id then
      raise exception 'Return receipt must reference the same customer as the prior handover';
    end if;
  end if;

  insert into public.gas_container_transaction_links(
    organization_id,factory_id,asset_id,transaction_id,request_key,
    transaction_type,from_location_id,to_location_id,customer_id,recorded_by
  ) values(
    v_asset.organization_id,v_asset.factory_id,v_asset.id,v_tx.id,p_request_key,
    v_tx.transaction_type,v_tx.from_location_id,v_tx.to_location_id,v_customer,auth.uid()
  ) returning id into v_link_id;
  return v_link_id;
end; $$;
revoke all on function public.gas_link_container_transaction(uuid,uuid,text,uuid)
  from public,anon;
grant execute on function public.gas_link_container_transaction(uuid,uuid,text,uuid)
  to authenticated;

commit;
