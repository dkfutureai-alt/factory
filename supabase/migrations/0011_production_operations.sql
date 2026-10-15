begin;

create table public.production_recipes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  product_item_id uuid not null,
  name text not null check (char_length(trim(name)) between 2 and 140),
  version text not null check (char_length(trim(version)) between 1 and 40),
  output_quantity numeric(18,4) not null default 1 check (output_quantity > 0),
  effective_from date,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, product_item_id, version),
  unique (id, organization_id),
  foreign key (product_item_id, organization_id)
    references public.inventory_items(id, organization_id) on delete restrict
);

create table public.production_recipe_components (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recipe_id uuid not null,
  item_id uuid not null,
  quantity_required numeric(18,4) not null check (quantity_required > 0),
  scrap_allowance_pct numeric(8,4) not null default 0 check (scrap_allowance_pct between 0 and 100),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (recipe_id, item_id),
  foreign key (recipe_id, organization_id)
    references public.production_recipes(id, organization_id) on delete cascade,
  foreign key (item_id, organization_id)
    references public.inventory_items(id, organization_id) on delete restrict
);

create table public.work_centers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid not null,
  name text not null check (char_length(trim(name)) between 2 and 120),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,23}$'),
  center_type text not null default 'line' check (center_type in ('machine','line','station','area','other')),
  capacity_per_hour numeric(18,4) check (capacity_per_hour is null or capacity_per_hour > 0),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (factory_id, code),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete cascade
);

create table public.production_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  order_no text not null default ('PO-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  recipe_id uuid not null,
  product_item_id uuid not null,
  work_center_id uuid not null,
  planned_quantity numeric(18,4) not null check (planned_quantity > 0),
  status text not null default 'planned' check (status in ('planned','in_progress','paused','on_hold','completed','cancelled')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  planned_start_at timestamptz,
  planned_end_at timestamptz,
  actual_start_at timestamptz,
  actual_end_at timestamptz,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, order_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete restrict,
  foreign key (recipe_id, organization_id)
    references public.production_recipes(id, organization_id) on delete restrict,
  foreign key (product_item_id, organization_id)
    references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (work_center_id, factory_id)
    references public.work_centers(id, factory_id) on delete restrict,
  check (planned_end_at is null or planned_start_at is null or planned_end_at >= planned_start_at),
  check (actual_end_at is null or actual_start_at is null or actual_end_at >= actual_start_at)
);

create table public.production_batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  order_id uuid not null,
  batch_no text not null check (char_length(trim(batch_no)) between 1 and 60),
  work_center_id uuid not null,
  shift_id uuid,
  operator_employee_id uuid,
  planned_quantity numeric(18,4) not null check (planned_quantity > 0),
  status text not null default 'planned' check (status in ('planned','in_progress','paused','completed','cancelled')),
  actual_start_at timestamptz,
  actual_end_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, batch_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (order_id, factory_id)
    references public.production_orders(id, factory_id) on delete restrict,
  foreign key (work_center_id, factory_id)
    references public.work_centers(id, factory_id) on delete restrict,
  foreign key (shift_id, factory_id)
    references public.shifts(id, factory_id) on delete restrict,
  foreign key (operator_employee_id, organization_id)
    references public.employees(id, organization_id) on delete restrict,
  check (actual_end_at is null or actual_start_at is null or actual_end_at >= actual_start_at)
);

create table public.production_material_issues (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  order_id uuid not null,
  batch_id uuid not null,
  item_id uuid not null,
  source_location_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  inventory_transaction_id uuid not null unique references public.inventory_transactions(id) on delete restrict,
  notes text,
  issued_by uuid references auth.users(id) on delete set null,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  foreign key (order_id, factory_id) references public.production_orders(id, factory_id) on delete restrict,
  foreign key (batch_id, factory_id) references public.production_batches(id, factory_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (source_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict
);

create table public.production_outputs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  order_id uuid not null,
  batch_id uuid not null,
  product_item_id uuid not null,
  destination_location_id uuid,
  good_quantity numeric(18,4) not null default 0 check (good_quantity >= 0),
  scrap_quantity numeric(18,4) not null default 0 check (scrap_quantity >= 0),
  lot_batch_no text,
  inventory_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  notes text,
  recorded_by uuid references auth.users(id) on delete set null,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  foreign key (order_id, factory_id) references public.production_orders(id, factory_id) on delete restrict,
  foreign key (batch_id, factory_id) references public.production_batches(id, factory_id) on delete restrict,
  foreign key (product_item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (destination_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  check (good_quantity + scrap_quantity > 0),
  check ((good_quantity = 0 and destination_location_id is null and inventory_transaction_id is null)
      or (good_quantity > 0 and destination_location_id is not null and inventory_transaction_id is not null))
);

create table public.production_scrap_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  order_id uuid not null,
  batch_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  reason_code text not null check (char_length(trim(reason_code)) between 2 and 40),
  reason_text text,
  recorded_by uuid references auth.users(id) on delete set null,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  foreign key (order_id, factory_id) references public.production_orders(id, factory_id) on delete restrict,
  foreign key (batch_id, factory_id) references public.production_batches(id, factory_id) on delete restrict
);

create table public.production_downtime_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  order_id uuid not null,
  batch_id uuid not null,
  work_center_id uuid not null,
  reason_code text not null check (char_length(trim(reason_code)) between 2 and 40),
  reason_text text,
  duration_minutes integer not null check (duration_minutes > 0 and duration_minutes <= 10080),
  started_at timestamptz not null default now(),
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (order_id, factory_id) references public.production_orders(id, factory_id) on delete restrict,
  foreign key (batch_id, factory_id) references public.production_batches(id, factory_id) on delete restrict,
  foreign key (work_center_id, factory_id) references public.work_centers(id, factory_id) on delete restrict
);

create index production_orders_factory_status_idx on public.production_orders(factory_id, status, planned_start_at);
create index production_batches_order_status_idx on public.production_batches(order_id, status);
create index production_material_issues_batch_idx on public.production_material_issues(batch_id, occurred_at desc);
create index production_outputs_batch_idx on public.production_outputs(batch_id, occurred_at desc);
create index production_downtime_factory_date_idx on public.production_downtime_events(factory_id, started_at desc);
create index production_scrap_factory_date_idx on public.production_scrap_events(factory_id, occurred_at desc);

create trigger production_recipes_set_updated_at before update on public.production_recipes for each row execute function public.set_updated_at();
create trigger production_recipe_components_set_updated_at before update on public.production_recipe_components for each row execute function public.set_updated_at();
create trigger work_centers_set_updated_at before update on public.work_centers for each row execute function public.set_updated_at();
create trigger production_orders_set_updated_at before update on public.production_orders for each row execute function public.set_updated_at();
create trigger production_batches_set_updated_at before update on public.production_batches for each row execute function public.set_updated_at();

create or replace function public.can_view_production_factory(target_factory_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_view_inventory_factory(target_factory_id);
$$;
grant execute on function public.can_view_production_factory(uuid) to authenticated;

create or replace function public.can_operate_production_factory(target_factory_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_factory(target_factory_id)
    or exists (
      select 1
      from public.factory_members fm
      join public.organization_members om
        on om.organization_id = fm.organization_id
       and om.user_id = fm.user_id
       and om.is_active
      where fm.factory_id = target_factory_id
        and fm.user_id = auth.uid()
        and fm.is_active
        and om.role in ('supervisor','employee')
    );
$$;
grant execute on function public.can_operate_production_factory(uuid) to authenticated;

alter table public.production_recipes enable row level security;
alter table public.production_recipe_components enable row level security;
alter table public.work_centers enable row level security;
alter table public.production_orders enable row level security;
alter table public.production_batches enable row level security;
alter table public.production_material_issues enable row level security;
alter table public.production_outputs enable row level security;
alter table public.production_scrap_events enable row level security;
alter table public.production_downtime_events enable row level security;

grant select, insert, update on public.production_recipes to authenticated;
grant select, insert, update, delete on public.production_recipe_components to authenticated;
grant select, insert, update on public.work_centers to authenticated;
grant select on public.production_orders to authenticated;
grant select on public.production_batches to authenticated;
grant select on public.production_material_issues to authenticated;
grant select on public.production_outputs to authenticated;
grant select on public.production_scrap_events to authenticated;
grant select on public.production_downtime_events to authenticated;

create policy production_recipes_select on public.production_recipes for select to authenticated
using (public.is_org_member(organization_id));
create policy production_recipes_manage on public.production_recipes for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy production_recipe_components_select on public.production_recipe_components for select to authenticated
using (public.is_org_member(organization_id));
create policy production_recipe_components_manage on public.production_recipe_components for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id, array['org_admin']::public.app_role[]));

create policy work_centers_select on public.work_centers for select to authenticated
using (public.can_view_production_factory(factory_id));
create policy work_centers_manage on public.work_centers for all to authenticated
using (public.can_manage_factory(factory_id))
with check (public.can_manage_factory(factory_id));

create policy production_orders_select on public.production_orders for select to authenticated
using (public.can_view_production_factory(factory_id));
create policy production_batches_select on public.production_batches for select to authenticated
using (public.can_view_production_factory(factory_id));
create policy production_material_issues_select on public.production_material_issues for select to authenticated
using (public.can_view_production_factory(factory_id));
create policy production_outputs_select on public.production_outputs for select to authenticated
using (public.can_view_production_factory(factory_id));
create policy production_scrap_events_select on public.production_scrap_events for select to authenticated
using (public.can_view_production_factory(factory_id));
create policy production_downtime_events_select on public.production_downtime_events for select to authenticated
using (public.can_view_production_factory(factory_id));

create or replace function public.prevent_production_history_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception '% records are immutable', tg_table_name;
end;
$$;
revoke all on function public.prevent_production_history_change() from public;
create trigger production_material_issues_immutable before update or delete on public.production_material_issues for each row execute function public.prevent_production_history_change();
create trigger production_outputs_immutable before update or delete on public.production_outputs for each row execute function public.prevent_production_history_change();
create trigger production_scrap_events_immutable before update or delete on public.production_scrap_events for each row execute function public.prevent_production_history_change();
create trigger production_downtime_events_immutable before update or delete on public.production_downtime_events for each row execute function public.prevent_production_history_change();

create or replace function public.validate_production_master_integrity()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  product_id uuid;
  recipe_org uuid;
begin
  if tg_table_name = 'production_recipe_components' then
    if new.item_id = (select product_item_id from public.production_recipes where id = new.recipe_id) then
      raise exception 'A recipe cannot consume its own output item';
    end if;
  elsif tg_table_name = 'production_orders' then
    select organization_id, product_item_id into recipe_org, product_id
    from public.production_recipes where id = new.recipe_id and is_active;
    if recipe_org is null or recipe_org <> new.organization_id then raise exception 'Active recipe not found'; end if;
    if product_id <> new.product_item_id then raise exception 'Order product must match recipe output item'; end if;
    if not exists (select 1 from public.work_centers where id=new.work_center_id and factory_id=new.factory_id and is_active) then
      raise exception 'Active work center not found for factory';
    end if;
  elsif tg_table_name = 'production_batches' then
    if new.operator_employee_id is not null and not exists (
      select 1 from public.employees e
      where e.id=new.operator_employee_id and e.organization_id=new.organization_id
        and e.status='active' and e.primary_factory_id=new.factory_id
    ) then raise exception 'Operator must be an active employee in the same factory'; end if;
  end if;
  return new;
end;
$$;
revoke all on function public.validate_production_master_integrity() from public;
create trigger production_recipe_components_integrity before insert or update on public.production_recipe_components for each row execute function public.validate_production_master_integrity();
create trigger production_orders_integrity before insert or update of recipe_id,product_item_id,work_center_id,factory_id on public.production_orders for each row execute function public.validate_production_master_integrity();
create trigger production_batches_integrity before insert or update of operator_employee_id,factory_id on public.production_batches for each row execute function public.validate_production_master_integrity();

create or replace function public.audit_production_change()
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
  if tg_table_name in ('work_centers','production_orders','production_batches','production_material_issues','production_outputs','production_scrap_events','production_downtime_events') then
    target_factory := coalesce(new.factory_id, old.factory_id);
  else
    target_factory := null;
  end if;
  target_id := coalesce(new.id, old.id)::text;
  if tg_op='INSERT' then payload:=jsonb_build_object('after',to_jsonb(new));
  elsif tg_op='UPDATE' then payload:=jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new));
  else payload:=jsonb_build_object('before',to_jsonb(old)); end if;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(target_org,target_factory,auth.uid(),lower(tg_op),tg_table_name,target_id,payload);
  return coalesce(new,old);
end;
$$;
revoke all on function public.audit_production_change() from public;
create trigger production_recipes_audit after insert or update or delete on public.production_recipes for each row execute function public.audit_production_change();
create trigger production_recipe_components_audit after insert or update or delete on public.production_recipe_components for each row execute function public.audit_production_change();
create trigger work_centers_audit after insert or update or delete on public.work_centers for each row execute function public.audit_production_change();
create trigger production_orders_audit after insert or update on public.production_orders for each row execute function public.audit_production_change();
create trigger production_batches_audit after insert or update on public.production_batches for each row execute function public.audit_production_change();
create trigger production_material_issues_audit after insert on public.production_material_issues for each row execute function public.audit_production_change();
create trigger production_outputs_audit after insert on public.production_outputs for each row execute function public.audit_production_change();
create trigger production_scrap_events_audit after insert on public.production_scrap_events for each row execute function public.audit_production_change();
create trigger production_downtime_events_audit after insert on public.production_downtime_events for each row execute function public.audit_production_change();

create or replace function public.production_create_order(
  p_factory_id uuid,
  p_recipe_id uuid,
  p_work_center_id uuid,
  p_planned_quantity numeric,
  p_planned_start_at timestamptz default null,
  p_planned_end_at timestamptz default null,
  p_priority text default 'normal',
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_product uuid;
  v_order uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_planned_quantity is null or p_planned_quantity <= 0 then raise exception 'Planned quantity must be greater than zero'; end if;
  if p_priority not in ('low','normal','high','urgent') then raise exception 'Invalid priority'; end if;
  if p_planned_start_at is not null and p_planned_end_at is not null and p_planned_end_at < p_planned_start_at then raise exception 'Planned end cannot precede planned start'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Not allowed for this factory'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  select product_item_id into v_product from public.production_recipes where id=p_recipe_id and organization_id=v_org and is_active;
  if v_product is null then raise exception 'Active recipe not found'; end if;
  if not exists (select 1 from public.work_centers where id=p_work_center_id and factory_id=p_factory_id and is_active) then raise exception 'Active work center not found'; end if;

  insert into public.production_orders(organization_id,factory_id,recipe_id,product_item_id,work_center_id,planned_quantity,priority,planned_start_at,planned_end_at,notes,created_by)
  values(v_org,p_factory_id,p_recipe_id,v_product,p_work_center_id,p_planned_quantity,p_priority,p_planned_start_at,p_planned_end_at,nullif(trim(p_notes),''),auth.uid())
  returning id into v_order;
  return v_order;
end;
$$;
grant execute on function public.production_create_order(uuid,uuid,uuid,numeric,timestamptz,timestamptz,text,text) to authenticated;

create or replace function public.production_start_batch(
  p_order_id uuid,
  p_batch_no text,
  p_planned_quantity numeric,
  p_shift_id uuid default null,
  p_operator_employee_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  ord public.production_orders%rowtype;
  v_batch uuid;
  v_operator uuid;
  v_planned numeric(18,4);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(trim(coalesce(p_batch_no,''))) < 1 then raise exception 'Batch number is required'; end if;
  if p_planned_quantity is null or p_planned_quantity <= 0 then raise exception 'Batch planned quantity must be greater than zero'; end if;
  select * into ord from public.production_orders where id=p_order_id for update;
  if not found then raise exception 'Production order not found'; end if;
  if not public.can_operate_production_factory(ord.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if ord.status in ('completed','cancelled','on_hold') then raise exception 'Order cannot start a batch in status %', ord.status; end if;
  if p_shift_id is not null and not exists (select 1 from public.shifts where id=p_shift_id and factory_id=ord.factory_id and is_active) then raise exception 'Active shift not found'; end if;

  v_operator := p_operator_employee_id;
  if v_operator is null then
    select id into v_operator from public.employees where user_id=auth.uid() and status='active' and primary_factory_id=ord.factory_id limit 1;
  end if;
  if v_operator is not null and not exists (select 1 from public.employees where id=v_operator and organization_id=ord.organization_id and status='active' and primary_factory_id=ord.factory_id) then raise exception 'Operator is not active in this factory'; end if;

  select coalesce(sum(planned_quantity),0) into v_planned from public.production_batches where order_id=ord.id and status <> 'cancelled';
  if v_planned + p_planned_quantity > ord.planned_quantity then raise exception 'Batch plan exceeds remaining order quantity'; end if;

  insert into public.production_batches(organization_id,factory_id,order_id,batch_no,work_center_id,shift_id,operator_employee_id,planned_quantity,status,actual_start_at,created_by)
  values(ord.organization_id,ord.factory_id,ord.id,trim(p_batch_no),ord.work_center_id,p_shift_id,v_operator,p_planned_quantity,'in_progress',now(),auth.uid())
  returning id into v_batch;

  update public.production_orders
  set status='in_progress', actual_start_at=coalesce(actual_start_at,now())
  where id=ord.id;
  return v_batch;
end;
$$;
grant execute on function public.production_start_batch(uuid,text,numeric,uuid,uuid) to authenticated;

create or replace function public.production_issue_material(
  p_batch_id uuid,
  p_item_id uuid,
  p_from_location_id uuid,
  p_quantity numeric,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  bat public.production_batches%rowtype;
  ord public.production_orders%rowtype;
  v_available numeric(18,4);
  v_tx uuid;
  v_issue uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;
  select * into bat from public.production_batches where id=p_batch_id;
  if not found then raise exception 'Production batch not found'; end if;
  if bat.status not in ('in_progress','paused') then raise exception 'Batch must be active to issue material'; end if;
  if not public.can_operate_production_factory(bat.factory_id) then raise exception 'Not allowed for this factory'; end if;
  select * into ord from public.production_orders where id=bat.order_id;
  if not exists (select 1 from public.production_recipe_components where recipe_id=ord.recipe_id and item_id=p_item_id) then raise exception 'Item is not part of the active recipe'; end if;
  if not exists (select 1 from public.stock_locations where id=p_from_location_id and factory_id=bat.factory_id and is_active) then raise exception 'Source stock location not found'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_item_id::text || ':' || p_from_location_id::text,0));
  select coalesce(sum(quantity_delta),0) into v_available from public.stock_ledger_entries where item_id=p_item_id and location_id=p_from_location_id;
  if v_available < p_quantity then raise exception 'Insufficient stock: available %, requested %',v_available,p_quantity; end if;

  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,external_reference,notes,created_by)
  values(bat.organization_id,bat.factory_id,p_item_id,'issue',p_quantity,p_from_location_id,ord.order_no || '/' || bat.batch_no,coalesce(nullif(trim(p_notes),''),'Production material issue'),auth.uid())
  returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
  values(bat.organization_id,bat.factory_id,v_tx,p_item_id,p_from_location_id,-p_quantity);
  insert into public.production_material_issues(organization_id,factory_id,order_id,batch_id,item_id,source_location_id,quantity,inventory_transaction_id,notes,issued_by)
  values(bat.organization_id,bat.factory_id,bat.order_id,bat.id,p_item_id,p_from_location_id,p_quantity,v_tx,nullif(trim(p_notes),''),auth.uid())
  returning id into v_issue;
  return v_issue;
end;
$$;
grant execute on function public.production_issue_material(uuid,uuid,uuid,numeric,text) to authenticated;

create or replace function public.production_record_output(
  p_batch_id uuid,
  p_good_quantity numeric,
  p_scrap_quantity numeric default 0,
  p_to_location_id uuid default null,
  p_lot_batch_no text default null,
  p_scrap_reason text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  bat public.production_batches%rowtype;
  ord public.production_orders%rowtype;
  v_tx uuid;
  v_output uuid;
  v_total numeric(18,4);
  v_recorded numeric(18,4);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if coalesce(p_good_quantity,0) < 0 or coalesce(p_scrap_quantity,0) < 0 or coalesce(p_good_quantity,0)+coalesce(p_scrap_quantity,0) <= 0 then raise exception 'Output quantity must be greater than zero'; end if;
  select * into bat from public.production_batches where id=p_batch_id for update;
  if not found then raise exception 'Production batch not found'; end if;
  if bat.status not in ('in_progress','paused') then raise exception 'Batch must be active to record output'; end if;
  if not public.can_operate_production_factory(bat.factory_id) then raise exception 'Not allowed for this factory'; end if;
  select * into ord from public.production_orders where id=bat.order_id;

  v_total := coalesce(p_good_quantity,0)+coalesce(p_scrap_quantity,0);
  select coalesce(sum(good_quantity+scrap_quantity),0) into v_recorded from public.production_outputs where batch_id=bat.id;
  if v_recorded + v_total > bat.planned_quantity then raise exception 'Recorded output exceeds batch planned quantity'; end if;

  if coalesce(p_good_quantity,0) > 0 then
    if p_to_location_id is null or not exists (select 1 from public.stock_locations where id=p_to_location_id and factory_id=bat.factory_id and is_active) then raise exception 'Finished-goods destination location not found'; end if;
    insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,to_location_id,external_reference,notes,created_by)
    values(bat.organization_id,bat.factory_id,ord.product_item_id,'receive',p_good_quantity,p_to_location_id,ord.order_no || '/' || bat.batch_no,coalesce(nullif(trim(p_notes),''),'Production finished-goods receipt'),auth.uid())
    returning id into v_tx;
    insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
    values(bat.organization_id,bat.factory_id,v_tx,ord.product_item_id,p_to_location_id,p_good_quantity);
  end if;

  insert into public.production_outputs(organization_id,factory_id,order_id,batch_id,product_item_id,destination_location_id,good_quantity,scrap_quantity,lot_batch_no,inventory_transaction_id,notes,recorded_by)
  values(bat.organization_id,bat.factory_id,bat.order_id,bat.id,ord.product_item_id,case when coalesce(p_good_quantity,0)>0 then p_to_location_id end,coalesce(p_good_quantity,0),coalesce(p_scrap_quantity,0),nullif(trim(p_lot_batch_no),''),v_tx,nullif(trim(p_notes),''),auth.uid())
  returning id into v_output;

  if coalesce(p_scrap_quantity,0) > 0 then
    insert into public.production_scrap_events(organization_id,factory_id,order_id,batch_id,quantity,reason_code,reason_text,recorded_by)
    values(bat.organization_id,bat.factory_id,bat.order_id,bat.id,p_scrap_quantity,'OUTPUT_SCRAP',nullif(trim(p_scrap_reason),''),auth.uid());
  end if;
  return v_output;
end;
$$;
grant execute on function public.production_record_output(uuid,numeric,numeric,uuid,text,text,text) to authenticated;

create or replace function public.production_log_downtime(
  p_batch_id uuid,
  p_reason_code text,
  p_duration_minutes integer,
  p_reason_text text default null,
  p_started_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  bat public.production_batches%rowtype;
  v_event uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(trim(coalesce(p_reason_code,''))) < 2 then raise exception 'Reason code is required'; end if;
  if p_duration_minutes is null or p_duration_minutes <= 0 or p_duration_minutes > 10080 then raise exception 'Invalid downtime duration'; end if;
  select * into bat from public.production_batches where id=p_batch_id;
  if not found then raise exception 'Production batch not found'; end if;
  if bat.status not in ('in_progress','paused') then raise exception 'Batch must be active to log downtime'; end if;
  if not public.can_operate_production_factory(bat.factory_id) then raise exception 'Not allowed for this factory'; end if;
  insert into public.production_downtime_events(organization_id,factory_id,order_id,batch_id,work_center_id,reason_code,reason_text,duration_minutes,started_at,recorded_by)
  values(bat.organization_id,bat.factory_id,bat.order_id,bat.id,bat.work_center_id,upper(trim(p_reason_code)),nullif(trim(p_reason_text),''),p_duration_minutes,coalesce(p_started_at,now()),auth.uid())
  returning id into v_event;
  return v_event;
end;
$$;
grant execute on function public.production_log_downtime(uuid,text,integer,text,timestamptz) to authenticated;

create or replace function public.production_set_batch_status(p_batch_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  bat public.production_batches%rowtype;
  v_good numeric(18,4);
  v_scrap numeric(18,4);
  v_active integer;
  v_order_good numeric(18,4);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_status not in ('in_progress','paused','completed','cancelled') then raise exception 'Invalid batch status'; end if;
  select * into bat from public.production_batches where id=p_batch_id for update;
  if not found then raise exception 'Production batch not found'; end if;
  if not public.can_operate_production_factory(bat.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if bat.status='completed' or bat.status='cancelled' then raise exception 'Closed batch status cannot change'; end if;
  select coalesce(sum(good_quantity),0),coalesce(sum(scrap_quantity),0) into v_good,v_scrap from public.production_outputs where batch_id=bat.id;
  if p_status='completed' and v_good+v_scrap <= 0 then raise exception 'Record output before completing the batch'; end if;
  update public.production_batches set status=p_status,actual_start_at=case when p_status='in_progress' then coalesce(actual_start_at,now()) else actual_start_at end,actual_end_at=case when p_status in ('completed','cancelled') then now() else null end where id=bat.id;

  if p_status='completed' then
    select count(*) into v_active from public.production_batches where order_id=bat.order_id and status in ('planned','in_progress','paused');
    select coalesce(sum(o.good_quantity),0) into v_order_good from public.production_outputs o join public.production_batches b on b.id=o.batch_id where b.order_id=bat.order_id;
    if v_active=0 and v_order_good >= (select planned_quantity from public.production_orders where id=bat.order_id) then
      update public.production_orders set status='completed',actual_end_at=now() where id=bat.order_id;
    end if;
  end if;
  return jsonb_build_object('batch_id',bat.id,'status',p_status,'good_quantity',v_good,'scrap_quantity',v_scrap);
end;
$$;
grant execute on function public.production_set_batch_status(uuid,text) to authenticated;

create or replace function public.production_dashboard_summary(p_organization_id uuid, p_factory_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_production_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  select jsonb_build_object(
    'active_orders',(select count(*) from public.production_orders o where o.organization_id=p_organization_id and o.status in ('planned','in_progress','paused','on_hold') and (p_factory_id is null or o.factory_id=p_factory_id) and public.can_view_production_factory(o.factory_id)),
    'today_good_output',coalesce((select sum(po.good_quantity) from public.production_outputs po where po.organization_id=p_organization_id and po.occurred_at>=date_trunc('day',now()) and (p_factory_id is null or po.factory_id=p_factory_id) and public.can_view_production_factory(po.factory_id)),0),
    'wip_quantity',coalesce((select sum(greatest(o.planned_quantity-coalesce(x.good_qty,0)-coalesce(x.scrap_qty,0),0)) from public.production_orders o left join lateral (select sum(out.good_quantity) good_qty,sum(out.scrap_quantity) scrap_qty from public.production_outputs out where out.order_id=o.id) x on true where o.organization_id=p_organization_id and o.status in ('planned','in_progress','paused','on_hold') and (p_factory_id is null or o.factory_id=p_factory_id) and public.can_view_production_factory(o.factory_id)),0),
    'today_scrap',coalesce((select sum(s.quantity) from public.production_scrap_events s where s.organization_id=p_organization_id and s.occurred_at>=date_trunc('day',now()) and (p_factory_id is null or s.factory_id=p_factory_id) and public.can_view_production_factory(s.factory_id)),0),
    'today_downtime_minutes',coalesce((select sum(d.duration_minutes) from public.production_downtime_events d where d.organization_id=p_organization_id and d.started_at>=date_trunc('day',now()) and (p_factory_id is null or d.factory_id=p_factory_id) and public.can_view_production_factory(d.factory_id)),0)
  ) into result;
  return result;
end;
$$;
grant execute on function public.production_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.production_order_report(p_organization_id uuid, p_factory_id uuid default null, p_limit integer default 200)
returns table(order_id uuid,order_no text,product_name text,product_sku text,work_center_name text,planned_quantity numeric,good_quantity numeric,scrap_quantity numeric,wip_quantity numeric,status text,priority text,planned_start_at timestamptz,actual_start_at timestamptz,actual_end_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_production_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  return query
  select o.id,o.order_no,i.name,i.sku,w.name,o.planned_quantity,
    coalesce(sum(out.good_quantity),0)::numeric,coalesce(sum(out.scrap_quantity),0)::numeric,
    greatest(o.planned_quantity-coalesce(sum(out.good_quantity),0)-coalesce(sum(out.scrap_quantity),0),0)::numeric,
    o.status,o.priority,o.planned_start_at,o.actual_start_at,o.actual_end_at
  from public.production_orders o
  join public.inventory_items i on i.id=o.product_item_id
  join public.work_centers w on w.id=o.work_center_id
  left join public.production_outputs out on out.order_id=o.id
  where o.organization_id=p_organization_id and (p_factory_id is null or o.factory_id=p_factory_id) and public.can_view_production_factory(o.factory_id)
  group by o.id,i.name,i.sku,w.name
  order by coalesce(o.actual_start_at,o.planned_start_at,o.created_at) desc
  limit greatest(1,least(coalesce(p_limit,200),1000));
end;
$$;
grant execute on function public.production_order_report(uuid,uuid,integer) to authenticated;

create or replace function public.production_bom_requirements(p_order_id uuid)
returns table(item_id uuid,sku text,item_name text,required_quantity numeric,issued_quantity numeric,remaining_quantity numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
declare ord public.production_orders%rowtype;
begin
  select * into ord from public.production_orders where id=p_order_id;
  if not found then raise exception 'Production order not found'; end if;
  if not public.can_view_production_factory(ord.factory_id) then raise exception 'Factory access denied'; end if;
  return query
  select c.item_id,i.sku,i.name,
    ((c.quantity_required/r.output_quantity)*ord.planned_quantity*(1+c.scrap_allowance_pct/100))::numeric as required_quantity,
    coalesce(sum(mi.quantity),0)::numeric as issued_quantity,
    greatest(((c.quantity_required/r.output_quantity)*ord.planned_quantity*(1+c.scrap_allowance_pct/100))-coalesce(sum(mi.quantity),0),0)::numeric as remaining_quantity
  from public.production_recipe_components c
  join public.production_recipes r on r.id=c.recipe_id
  join public.inventory_items i on i.id=c.item_id
  left join public.production_material_issues mi on mi.order_id=ord.id and mi.item_id=c.item_id
  where c.recipe_id=ord.recipe_id
  group by c.item_id,i.sku,i.name,c.quantity_required,c.scrap_allowance_pct,r.output_quantity;
end;
$$;
grant execute on function public.production_bom_requirements(uuid) to authenticated;

commit;