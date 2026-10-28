begin;

-- Phase 21A: serialized cylinder/Dura asset identity and inspection evidence.
-- This is deliberately separate from quantity-based Inventory/Dispatch: no
-- registration or inspection action may create stock or certify equipment.
create table public.gas_container_assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  item_id uuid not null,
  serial_number text not null check (
    serial_number ~ '^[A-Z0-9][A-Z0-9._/-]{2,79}$'
  ),
  qr_code text not null,
  container_type text not null check (container_type in ('cylinder','dura')),
  ownership text not null check (ownership in ('owned','customer','leased')),
  state text not null default 'hold'
    check (state in ('hold','inspection_recorded','quarantined','retired')),
  condition text not null default 'unverified'
    check (condition in ('unverified','good','damaged','rejected')),
  test_due_on date,
  last_inspection_at timestamptz,
  notes text check (notes is null or char_length(notes) <= 500),
  registered_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id),
  unique (organization_id, serial_number),
  unique (organization_id, qr_code),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict,
  foreign key (item_id, organization_id)
    references public.inventory_items(id, organization_id) on delete restrict
);

create index gas_assets_org_fk_idx on public.gas_container_assets(organization_id);
create index gas_assets_factory_org_fk_idx on public.gas_container_assets(factory_id,organization_id);
create index gas_assets_item_org_fk_idx on public.gas_container_assets(item_id,organization_id);
create index gas_assets_registered_by_idx on public.gas_container_assets(registered_by);
create index gas_assets_factory_state_idx on public.gas_container_assets(factory_id,state,created_at desc);

create table public.gas_container_asset_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  asset_id uuid not null,
  event_type text not null check(event_type in ('registered','inspection','retired')),
  condition_after text not null check(condition_after in ('unverified','good','damaged','rejected')),
  state_after text not null check(state_after in ('hold','inspection_recorded','quarantined','retired')),
  notes text check(notes is null or char_length(notes) <= 500),
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (organization_id)
    references public.organizations(id) on delete restrict,
  foreign key (asset_id, organization_id)
    references public.gas_container_assets(id, organization_id) on delete restrict
);
create index gas_asset_events_org_fk_idx on public.gas_container_asset_events(organization_id);
create index gas_asset_events_asset_org_fk_idx
  on public.gas_container_asset_events(asset_id,organization_id);
create index gas_asset_events_actor_fk_idx
  on public.gas_container_asset_events(actor_user_id);
create index gas_asset_events_asset_recent_idx
  on public.gas_container_asset_events(asset_id,created_at desc);

create trigger gas_container_assets_set_updated_at
before update on public.gas_container_assets
for each row execute function public.set_updated_at();

alter table public.gas_container_assets enable row level security;
alter table public.gas_container_asset_events enable row level security;

-- New Supabase projects require explicit API grants. There is no anonymous
-- API access, and authenticated clients can neither forge registry values
-- nor rewrite inspection history directly.
revoke all on public.gas_container_assets,public.gas_container_asset_events
  from public,anon,authenticated;
grant select on public.gas_container_assets,public.gas_container_asset_events
  to authenticated;
grant select,insert,update,delete on
  public.gas_container_assets,public.gas_container_asset_events
  to service_role;

create policy gas_container_assets_read on public.gas_container_assets
  for select to authenticated
  using (public.can_view_inventory_factory(factory_id));

create policy gas_container_asset_events_read on public.gas_container_asset_events
  for select to authenticated
  using (exists(
    select 1 from public.gas_container_assets a
    where a.id=asset_id and a.organization_id=gas_container_asset_events.organization_id
      and public.can_view_inventory_factory(a.factory_id)
  ));

-- Events are immutable. Direct inserts are disabled for authenticated roles;
-- an explicit RPC is the only client mutation path.
create function public.gas_asset_events_reject_change()
returns trigger language plpgsql set search_path=public as $$
begin
  raise exception 'Gas asset event history is immutable';
end; $$;
revoke all on function public.gas_asset_events_reject_change() from public,anon,authenticated;
create trigger gas_asset_events_immutable
before update or delete on public.gas_container_asset_events
for each row execute function public.gas_asset_events_reject_change();

-- Existing tamper-evident business audit chain covers each registry mutation.
create function public.gas_asset_audit_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_action text;
begin
  v_action := case when tg_op='INSERT' then 'insert' else 'update' end;
  insert into public.audit_logs(
    organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata
  ) values (
    new.organization_id,new.factory_id,auth.uid(),v_action,
    'gas_container_assets',new.id::text,
    case when tg_op='INSERT' then jsonb_build_object(
      'serial',new.serial_number,'state',new.state,'container_type',new.container_type)
    else jsonb_build_object('state',new.state,'condition',new.condition) end
  );
  return new;
end; $$;
revoke all on function public.gas_asset_audit_change() from public,anon,authenticated;
create trigger gas_assets_audit
after insert or update on public.gas_container_assets
for each row execute function public.gas_asset_audit_change();

create function public.gas_register_container(
  p_factory_id uuid,
  p_item_id uuid,
  p_serial_number text,
  p_container_type text,
  p_ownership text default 'owned',
  p_test_due_on date default null,
  p_notes text default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_asset_id uuid:=gen_random_uuid(); v_serial text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_factory(p_factory_id) then
    raise exception 'Factory manager access required';
  end if;
  v_serial := upper(trim(coalesce(p_serial_number,'')));
  if v_serial !~ '^[A-Z0-9][A-Z0-9._/-]{2,79}$' then
    raise exception 'Serial must have 3-80 letters, digits or ._/-';
  end if;
  if p_container_type not in ('cylinder','dura') then
    raise exception 'Container type must be cylinder or dura';
  end if;
  if p_ownership not in ('owned','customer','leased') then
    raise exception 'Invalid container ownership';
  end if;
  if char_length(coalesce(p_notes,''))>500 then
    raise exception 'Registration notes exceed 500 characters';
  end if;
  select organization_id into v_org from public.factories
    where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Active factory not found'; end if;
  if not exists(
    select 1 from public.inventory_items
    where id=p_item_id and organization_id=v_org and is_active
      and (item_type='cylinder' or is_returnable)
  ) then raise exception 'Container must reference an active returnable/cylinder Inventory item'; end if;
  insert into public.gas_container_assets(
    id,organization_id,factory_id,item_id,serial_number,qr_code,
    container_type,ownership,test_due_on,notes,registered_by
  ) values (
    v_asset_id,v_org,p_factory_id,p_item_id,v_serial,
    'FA-'||upper(replace(v_asset_id::text,'-','')),
    p_container_type,p_ownership,p_test_due_on,
    nullif(trim(coalesce(p_notes,'')),''),auth.uid()
  );
  insert into public.gas_container_asset_events(
    organization_id,asset_id,event_type,condition_after,state_after,notes,actor_user_id
  ) values(v_org,v_asset_id,'registered','unverified','hold',
    'Identity registered; physical safety and custody not yet verified',auth.uid());
  return v_asset_id;
end; $$;
revoke all on function public.gas_register_container(uuid,uuid,text,text,text,date,text)
  from public,anon;
grant execute on function public.gas_register_container(uuid,uuid,text,text,text,date,text)
  to authenticated;

create function public.gas_record_container_inspection(
  p_asset_id uuid,
  p_condition text,
  p_notes text
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_asset public.gas_container_assets%rowtype; v_event_id uuid; v_state text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_condition not in ('good','damaged','rejected')
    or char_length(trim(coalesce(p_notes,'')))<3
    or char_length(p_notes)>500 then
    raise exception 'Inspection requires a valid condition and 3-500 character observations';
  end if;
  select * into v_asset from public.gas_container_assets
    where id=p_asset_id for update;
  if v_asset.id is null or not public.can_manage_factory(v_asset.factory_id) then
    raise exception 'Asset not found or inspection access denied';
  end if;
  if v_asset.state='retired' then raise exception 'Retired assets cannot be re-inspected'; end if;
  v_state:=case when p_condition='good' then 'inspection_recorded' else 'quarantined' end;
  -- A recorded visual inspection is NOT pressure certification, gas fill
  -- release or stock-ledger movement. Overdue tests must be reviewed manually.
  update public.gas_container_assets
  set condition=p_condition,state=v_state,last_inspection_at=now()
  where id=v_asset.id;
  insert into public.gas_container_asset_events(
    organization_id,asset_id,event_type,condition_after,state_after,notes,actor_user_id
  ) values (
    v_asset.organization_id,v_asset.id,'inspection',p_condition,v_state,trim(p_notes),auth.uid()
  ) returning id into v_event_id;
  return v_event_id;
end; $$;
revoke all on function public.gas_record_container_inspection(uuid,text,text)
  from public,anon;
grant execute on function public.gas_record_container_inspection(uuid,text,text)
  to authenticated;

create function public.gas_retire_container(p_asset_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_asset public.gas_container_assets%rowtype; v_event_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(trim(coalesce(p_reason,'')))<5
     or char_length(p_reason)>500 then
    raise exception 'Retirement requires a 5-500 character reason';
  end if;
  select * into v_asset from public.gas_container_assets
    where id=p_asset_id for update;
  if v_asset.id is null or not public.can_manage_factory(v_asset.factory_id) then
    raise exception 'Asset not found or retirement access denied';
  end if;
  if v_asset.state='retired' then raise exception 'Asset already retired'; end if;
  update public.gas_container_assets set state='retired' where id=v_asset.id;
  insert into public.gas_container_asset_events(
    organization_id,asset_id,event_type,condition_after,state_after,notes,actor_user_id
  ) values(
    v_asset.organization_id,v_asset.id,'retired',v_asset.condition,'retired',
    trim(p_reason),auth.uid()
  ) returning id into v_event_id;
  return v_event_id;
end; $$;
revoke all on function public.gas_retire_container(uuid,text) from public,anon;
grant execute on function public.gas_retire_container(uuid,text) to authenticated;

commit;
