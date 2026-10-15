begin;

create table public.inventory_categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 100),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (id, organization_id)
);

create table public.inventory_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 60),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{0,15}$'),
  decimal_places integer not null default 2 check (decimal_places between 0 and 6),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (id, organization_id)
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category_id uuid,
  unit_id uuid not null,
  sku text not null check (sku ~ '^[A-Z0-9][A-Z0-9._/-]{1,39}$'),
  name text not null check (char_length(trim(name)) between 2 and 140),
  item_type text not null default 'raw_material' check (item_type in ('raw_material','consumable','finished_good','spare','packaging','gas','cylinder','other')),
  barcode text,
  qr_code text,
  is_batch_tracked boolean not null default false,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, sku),
  unique (id, organization_id),
  foreign key (category_id, organization_id)
    references public.inventory_categories(id, organization_id) on delete restrict,
  foreign key (unit_id, organization_id)
    references public.inventory_units(id, organization_id) on delete restrict,
  check (barcode is null or char_length(trim(barcode)) between 2 and 120),
  check (qr_code is null or char_length(trim(qr_code)) between 2 and 240)
);
create unique index inventory_items_org_barcode_unique
  on public.inventory_items(organization_id, barcode) where barcode is not null;
create unique index inventory_items_org_qr_unique
  on public.inventory_items(organization_id, qr_code) where qr_code is not null;
create index inventory_items_category_idx on public.inventory_items(category_id) where is_active;

create table public.stock_locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid not null,
  name text not null check (char_length(trim(name)) between 2 and 100),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,23}$'),
  location_type text not null default 'warehouse' check (location_type in ('warehouse','bin','production','quality','dispatch','vehicle','quarantine','other')),
  parent_location_id uuid references public.stock_locations(id) on delete restrict,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (factory_id, code),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict
);
create index stock_locations_factory_idx on public.stock_locations(factory_id, is_active);

create table public.inventory_reorder_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid not null,
  item_id uuid not null,
  reorder_level numeric(18,4) not null default 0 check (reorder_level >= 0),
  reorder_quantity numeric(18,4) not null default 0 check (reorder_quantity >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (factory_id, item_id),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete cascade,
  foreign key (item_id, organization_id)
    references public.inventory_items(id, organization_id) on delete cascade
);

create table public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  item_id uuid not null,
  transaction_no text not null default ('INV-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  transaction_type text not null check (transaction_type in ('opening','receive','issue','transfer')),
  quantity numeric(18,4) not null check (quantity > 0),
  from_location_id uuid,
  to_location_id uuid,
  unit_cost numeric(18,4) check (unit_cost is null or unit_cost >= 0),
  external_reference text,
  notes text,
  occurred_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, transaction_no),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict,
  foreign key (item_id, organization_id)
    references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (from_location_id, factory_id)
    references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (to_location_id, factory_id)
    references public.stock_locations(id, factory_id) on delete restrict,
  check (
    (transaction_type in ('opening','receive') and from_location_id is null and to_location_id is not null)
    or (transaction_type = 'issue' and from_location_id is not null and to_location_id is null)
    or (transaction_type = 'transfer' and from_location_id is not null and to_location_id is not null and from_location_id <> to_location_id)
  )
);
create index inventory_transactions_factory_date_idx on public.inventory_transactions(factory_id, occurred_at desc);
create index inventory_transactions_item_date_idx on public.inventory_transactions(item_id, occurred_at desc);

create table public.stock_ledger_entries (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  transaction_id uuid not null references public.inventory_transactions(id) on delete restrict,
  item_id uuid not null,
  location_id uuid not null,
  quantity_delta numeric(18,4) not null check (quantity_delta <> 0),
  unit_cost numeric(18,4) check (unit_cost is null or unit_cost >= 0),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict,
  foreign key (item_id, organization_id)
    references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (location_id, factory_id)
    references public.stock_locations(id, factory_id) on delete restrict
);
create index stock_ledger_item_location_idx on public.stock_ledger_entries(item_id, location_id, occurred_at);
create index stock_ledger_factory_date_idx on public.stock_ledger_entries(factory_id, occurred_at desc);

create trigger inventory_categories_set_updated_at before update on public.inventory_categories for each row execute function public.set_updated_at();
create trigger inventory_units_set_updated_at before update on public.inventory_units for each row execute function public.set_updated_at();
create trigger inventory_items_set_updated_at before update on public.inventory_items for each row execute function public.set_updated_at();
create trigger stock_locations_set_updated_at before update on public.stock_locations for each row execute function public.set_updated_at();
create trigger inventory_reorder_rules_set_updated_at before update on public.inventory_reorder_rules for each row execute function public.set_updated_at();

create or replace function public.can_view_inventory_factory(target_factory_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
    or exists (
      select 1
      from public.factories f
      join public.organization_members om
        on om.organization_id = f.organization_id
       and om.user_id = auth.uid()
       and om.is_active
      left join public.factory_members fm
        on fm.organization_id = f.organization_id
       and fm.factory_id = f.id
       and fm.user_id = auth.uid()
       and fm.is_active
      where f.id = target_factory_id
        and f.is_active
        and (om.role = 'org_admin' or fm.id is not null)
    );
$$;
grant execute on function public.can_view_inventory_factory(uuid) to authenticated;

alter table public.inventory_categories enable row level security;
alter table public.inventory_units enable row level security;
alter table public.inventory_items enable row level security;
alter table public.stock_locations enable row level security;
alter table public.inventory_reorder_rules enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.stock_ledger_entries enable row level security;

grant select, insert, update on public.inventory_categories to authenticated;
grant select, insert, update on public.inventory_units to authenticated;
grant select, insert, update on public.inventory_items to authenticated;
grant select, insert, update on public.stock_locations to authenticated;
grant select, insert, update on public.inventory_reorder_rules to authenticated;
grant select on public.inventory_transactions to authenticated;
grant select on public.stock_ledger_entries to authenticated;

create policy inventory_categories_select on public.inventory_categories for select to authenticated
using (public.is_org_member(organization_id));
create policy inventory_categories_manage on public.inventory_categories for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy inventory_units_select on public.inventory_units for select to authenticated
using (public.is_org_member(organization_id));
create policy inventory_units_manage on public.inventory_units for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy inventory_items_select on public.inventory_items for select to authenticated
using (public.is_org_member(organization_id));
create policy inventory_items_manage on public.inventory_items for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy stock_locations_select on public.stock_locations for select to authenticated
using (public.can_view_inventory_factory(factory_id));
create policy stock_locations_manage on public.stock_locations for all to authenticated
using (public.can_manage_factory(factory_id))
with check (public.can_manage_factory(factory_id));

create policy inventory_reorder_rules_select on public.inventory_reorder_rules for select to authenticated
using (public.can_view_inventory_factory(factory_id));
create policy inventory_reorder_rules_manage on public.inventory_reorder_rules for all to authenticated
using (public.can_manage_factory(factory_id))
with check (public.can_manage_factory(factory_id));

create policy inventory_transactions_select on public.inventory_transactions for select to authenticated
using (public.can_view_inventory_factory(factory_id));
create policy stock_ledger_entries_select on public.stock_ledger_entries for select to authenticated
using (public.can_view_inventory_factory(factory_id));

create or replace function public.prevent_inventory_immutable_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception '% records are immutable', tg_table_name;
end;
$$;
revoke all on function public.prevent_inventory_immutable_change() from public;
create trigger inventory_transactions_immutable before update or delete on public.inventory_transactions for each row execute function public.prevent_inventory_immutable_change();
create trigger stock_ledger_entries_immutable before update or delete on public.stock_ledger_entries for each row execute function public.prevent_inventory_immutable_change();

create or replace function public.audit_inventory_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_org uuid;
  target_factory uuid;
  target_id text;
  payload jsonb;
begin
  target_org := coalesce(new.organization_id, old.organization_id);
  if tg_table_name in ('stock_locations','inventory_reorder_rules','inventory_transactions') then
    target_factory := coalesce(new.factory_id, old.factory_id);
  else
    target_factory := null;
  end if;
  target_id := coalesce(new.id, old.id)::text;
  if tg_op = 'INSERT' then
    payload := jsonb_build_object('after', to_jsonb(new));
  elsif tg_op = 'UPDATE' then
    payload := jsonb_build_object('before', to_jsonb(old), 'after', to_jsonb(new));
  else
    payload := jsonb_build_object('before', to_jsonb(old));
  end if;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(target_org,target_factory,auth.uid(),lower(tg_op),tg_table_name,target_id,payload);
  return coalesce(new, old);
end;
$$;
revoke all on function public.audit_inventory_change() from public;

create trigger inventory_categories_audit after insert or update or delete on public.inventory_categories for each row execute function public.audit_inventory_change();
create trigger inventory_units_audit after insert or update or delete on public.inventory_units for each row execute function public.audit_inventory_change();
create trigger inventory_items_audit after insert or update or delete on public.inventory_items for each row execute function public.audit_inventory_change();
create trigger stock_locations_audit after insert or update or delete on public.stock_locations for each row execute function public.audit_inventory_change();
create trigger inventory_reorder_rules_audit after insert or update or delete on public.inventory_reorder_rules for each row execute function public.audit_inventory_change();
create trigger inventory_transactions_audit after insert on public.inventory_transactions for each row execute function public.audit_inventory_change();

create or replace function public.inventory_receive_stock(
  p_factory_id uuid,
  p_item_id uuid,
  p_to_location_id uuid,
  p_quantity numeric,
  p_unit_cost numeric default null,
  p_external_reference text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_tx uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;
  if p_unit_cost is not null and p_unit_cost < 0 then raise exception 'Unit cost cannot be negative'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Not allowed for this factory'; end if;

  select organization_id into v_org from public.factories where id = p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists (select 1 from public.inventory_items where id = p_item_id and organization_id = v_org and is_active) then raise exception 'Active item not found'; end if;
  if not exists (select 1 from public.stock_locations where id = p_to_location_id and factory_id = p_factory_id and organization_id = v_org and is_active) then raise exception 'Destination location not found'; end if;

  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,to_location_id,unit_cost,external_reference,notes,created_by)
  values(v_org,p_factory_id,p_item_id,'receive',p_quantity,p_to_location_id,p_unit_cost,nullif(trim(p_external_reference),''),nullif(trim(p_notes),''),auth.uid())
  returning id into v_tx;

  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost)
  values(v_org,p_factory_id,v_tx,p_item_id,p_to_location_id,p_quantity,p_unit_cost);
  return v_tx;
end;
$$;

grant execute on function public.inventory_receive_stock(uuid,uuid,uuid,numeric,numeric,text,text) to authenticated;

create or replace function public.inventory_issue_stock(
  p_factory_id uuid,
  p_item_id uuid,
  p_from_location_id uuid,
  p_quantity numeric,
  p_external_reference text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_available numeric(18,4);
  v_tx uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Not allowed for this factory'; end if;

  select organization_id into v_org from public.factories where id = p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists (select 1 from public.inventory_items where id = p_item_id and organization_id = v_org and is_active) then raise exception 'Active item not found'; end if;
  if not exists (select 1 from public.stock_locations where id = p_from_location_id and factory_id = p_factory_id and organization_id = v_org and is_active) then raise exception 'Source location not found'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_item_id::text || ':' || p_from_location_id::text, 0));
  select coalesce(sum(quantity_delta),0) into v_available
  from public.stock_ledger_entries where item_id = p_item_id and location_id = p_from_location_id;
  if v_available < p_quantity then raise exception 'Insufficient stock: available %, requested %', v_available, p_quantity; end if;

  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,external_reference,notes,created_by)
  values(v_org,p_factory_id,p_item_id,'issue',p_quantity,p_from_location_id,nullif(trim(p_external_reference),''),nullif(trim(p_notes),''),auth.uid())
  returning id into v_tx;

  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
  values(v_org,p_factory_id,v_tx,p_item_id,p_from_location_id,-p_quantity);
  return v_tx;
end;
$$;

grant execute on function public.inventory_issue_stock(uuid,uuid,uuid,numeric,text,text) to authenticated;

create or replace function public.inventory_transfer_stock(
  p_factory_id uuid,
  p_item_id uuid,
  p_from_location_id uuid,
  p_to_location_id uuid,
  p_quantity numeric,
  p_external_reference text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_available numeric(18,4);
  v_tx uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;
  if p_from_location_id = p_to_location_id then raise exception 'Source and destination must be different'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Not allowed for this factory'; end if;

  select organization_id into v_org from public.factories where id = p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists (select 1 from public.inventory_items where id = p_item_id and organization_id = v_org and is_active) then raise exception 'Active item not found'; end if;
  if not exists (select 1 from public.stock_locations where id = p_from_location_id and factory_id = p_factory_id and organization_id = v_org and is_active) then raise exception 'Source location not found'; end if;
  if not exists (select 1 from public.stock_locations where id = p_to_location_id and factory_id = p_factory_id and organization_id = v_org and is_active) then raise exception 'Destination location not found'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_item_id::text || ':' || p_from_location_id::text, 0));
  select coalesce(sum(quantity_delta),0) into v_available
  from public.stock_ledger_entries where item_id = p_item_id and location_id = p_from_location_id;
  if v_available < p_quantity then raise exception 'Insufficient stock: available %, requested %', v_available, p_quantity; end if;

  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,to_location_id,external_reference,notes,created_by)
  values(v_org,p_factory_id,p_item_id,'transfer',p_quantity,p_from_location_id,p_to_location_id,nullif(trim(p_external_reference),''),nullif(trim(p_notes),''),auth.uid())
  returning id into v_tx;

  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
  values
    (v_org,p_factory_id,v_tx,p_item_id,p_from_location_id,-p_quantity),
    (v_org,p_factory_id,v_tx,p_item_id,p_to_location_id,p_quantity);
  return v_tx;
end;
$$;

grant execute on function public.inventory_transfer_stock(uuid,uuid,uuid,uuid,numeric,text,text) to authenticated;

create or replace function public.inventory_dashboard_summary(p_organization_id uuid, p_factory_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_inventory_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  select jsonb_build_object(
    'active_items', (select count(*) from public.inventory_items i where i.organization_id=p_organization_id and i.is_active),
    'total_quantity', coalesce((select sum(le.quantity_delta) from public.stock_ledger_entries le where le.organization_id=p_organization_id and (p_factory_id is null or le.factory_id=p_factory_id)),0),
    'low_stock_items', (
      select count(*) from (
        select rr.item_id
        from public.inventory_reorder_rules rr
        left join public.stock_ledger_entries le on le.item_id=rr.item_id and le.factory_id=rr.factory_id
        where rr.organization_id=p_organization_id and rr.is_active and (p_factory_id is null or rr.factory_id=p_factory_id)
        group by rr.id, rr.item_id, rr.reorder_level
        having coalesce(sum(le.quantity_delta),0) <= rr.reorder_level
      ) s
    ),
    'today_movements', (select count(*) from public.inventory_transactions t where t.organization_id=p_organization_id and (p_factory_id is null or t.factory_id=p_factory_id) and t.occurred_at >= date_trunc('day', now()))
  ) into result;
  return result;
end;
$$;
grant execute on function public.inventory_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.inventory_stock_report(p_organization_id uuid, p_factory_id uuid default null)
returns table(item_id uuid,sku text,item_name text,unit_code text,factory_id uuid,factory_name text,location_id uuid,location_name text,quantity numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_inventory_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  return query
  select i.id,i.sku,i.name,u.code,f.id,f.name,l.id,l.name,coalesce(sum(le.quantity_delta),0)::numeric
  from public.stock_locations l
  join public.factories f on f.id=l.factory_id
  cross join public.inventory_items i
  join public.inventory_units u on u.id=i.unit_id
  left join public.stock_ledger_entries le on le.location_id=l.id and le.item_id=i.id
  where l.organization_id=p_organization_id and i.organization_id=p_organization_id
    and l.is_active and i.is_active and (p_factory_id is null or l.factory_id=p_factory_id)
    and public.can_view_inventory_factory(l.factory_id)
  group by i.id,i.sku,i.name,u.code,f.id,f.name,l.id,l.name
  having coalesce(sum(le.quantity_delta),0) <> 0
  order by i.name,l.name;
end;
$$;
grant execute on function public.inventory_stock_report(uuid,uuid) to authenticated;

create or replace function public.inventory_reorder_report(p_organization_id uuid, p_factory_id uuid default null)
returns table(item_id uuid,sku text,item_name text,factory_id uuid,factory_name text,current_quantity numeric,reorder_level numeric,reorder_quantity numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_inventory_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  return query
  select i.id,i.sku,i.name,f.id,f.name,coalesce(sum(le.quantity_delta),0)::numeric,rr.reorder_level,rr.reorder_quantity
  from public.inventory_reorder_rules rr
  join public.inventory_items i on i.id=rr.item_id
  join public.factories f on f.id=rr.factory_id
  left join public.stock_ledger_entries le on le.item_id=rr.item_id and le.factory_id=rr.factory_id
  where rr.organization_id=p_organization_id and rr.is_active and i.is_active
    and (p_factory_id is null or rr.factory_id=p_factory_id)
    and public.can_view_inventory_factory(rr.factory_id)
  group by i.id,i.sku,i.name,f.id,f.name,rr.reorder_level,rr.reorder_quantity
  having coalesce(sum(le.quantity_delta),0) <= rr.reorder_level
  order by (rr.reorder_level-coalesce(sum(le.quantity_delta),0)) desc,i.name;
end;
$$;
grant execute on function public.inventory_reorder_report(uuid,uuid) to authenticated;

create or replace function public.inventory_movement_report(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit integer default 200
)
returns table(transaction_id uuid,transaction_no text,transaction_type text,item_id uuid,sku text,item_name text,quantity numeric,from_location text,to_location text,external_reference text,occurred_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_inventory_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  return query
  select t.id,t.transaction_no,t.transaction_type,t.item_id,i.sku,i.name,t.quantity,fl.name,tl.name,t.external_reference,t.occurred_at
  from public.inventory_transactions t
  join public.inventory_items i on i.id=t.item_id
  left join public.stock_locations fl on fl.id=t.from_location_id
  left join public.stock_locations tl on tl.id=t.to_location_id
  where t.organization_id=p_organization_id
    and (p_factory_id is null or t.factory_id=p_factory_id)
    and public.can_view_inventory_factory(t.factory_id)
    and (p_from is null or t.occurred_at>=p_from)
    and (p_to is null or t.occurred_at<=p_to)
  order by t.occurred_at desc
  limit greatest(1,least(coalesce(p_limit,200),1000));
end;
$$;
grant execute on function public.inventory_movement_report(uuid,uuid,timestamptz,timestamptz,integer) to authenticated;

create or replace function public.inventory_lookup_scan(p_code text)
returns table(item_id uuid,sku text,item_name text,item_type text,barcode text,qr_code text,unit_code text,factory_id uuid,factory_name text,location_id uuid,location_name text,quantity numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if char_length(trim(coalesce(p_code,''))) < 2 then raise exception 'Scan code is required'; end if;
  return query
  with matched as (
    select i.* from public.inventory_items i
    where i.is_active and public.is_org_member(i.organization_id)
      and (upper(i.sku)=upper(trim(p_code)) or i.barcode=trim(p_code) or i.qr_code=trim(p_code))
    limit 1
  )
  select m.id,m.sku,m.name,m.item_type,m.barcode,m.qr_code,u.code,f.id,f.name,l.id,l.name,coalesce(sum(le.quantity_delta),0)::numeric
  from matched m
  join public.inventory_units u on u.id=m.unit_id
  join public.stock_locations l on l.organization_id=m.organization_id and l.is_active and public.can_view_inventory_factory(l.factory_id)
  join public.factories f on f.id=l.factory_id
  left join public.stock_ledger_entries le on le.item_id=m.id and le.location_id=l.id
  group by m.id,m.sku,m.name,m.item_type,m.barcode,m.qr_code,u.code,f.id,f.name,l.id,l.name
  order by f.name,l.name;
end;
$$;
grant execute on function public.inventory_lookup_scan(text) to authenticated;

commit;
