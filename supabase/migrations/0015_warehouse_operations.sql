begin;

-- Phase 8 extends the existing Inventory location tree instead of introducing a second stock system.
alter table public.stock_locations drop constraint if exists stock_locations_location_type_check;
alter table public.stock_locations
  add constraint stock_locations_location_type_check
  check (location_type in ('warehouse','zone','bin','receiving','staging','production','quality','dispatch','vehicle','quarantine','other'));

alter table public.stock_locations add column if not exists capacity_quantity numeric(18,4);
alter table public.stock_locations add column if not exists aisle text;
alter table public.stock_locations add column if not exists rack text;
alter table public.stock_locations add column if not exists level_no integer;
alter table public.stock_locations add column if not exists sequence_no integer;
alter table public.stock_locations
  add constraint stock_locations_capacity_check check (capacity_quantity is null or capacity_quantity >= 0),
  add constraint stock_locations_level_check check (level_no is null or level_no >= 0),
  add constraint stock_locations_sequence_check check (sequence_no is null or sequence_no >= 0);

create table public.warehouse_putaway_tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  task_no text not null default ('PUT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  goods_receipt_id uuid,
  item_id uuid not null,
  source_location_id uuid not null,
  target_location_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  status text not null default 'pending' check (status in ('pending','in_progress','completed','cancelled')),
  assigned_employee_id uuid,
  completed_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  started_by uuid references auth.users(id) on delete set null,
  started_at timestamptz,
  completed_by uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, task_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (goods_receipt_id, factory_id) references public.goods_receipts(id, factory_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (source_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (target_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (assigned_employee_id, organization_id) references public.employees(id, organization_id) on delete restrict,
  check (source_location_id <> target_location_id),
  check ((status='completed' and completed_transaction_id is not null and completed_at is not null) or status<>'completed')
);
create index warehouse_putaway_factory_status_idx on public.warehouse_putaway_tasks(factory_id,status,created_at desc);

create table public.warehouse_pick_lists (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  pick_list_no text not null default ('PICK-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  sales_order_id uuid not null,
  staging_location_id uuid not null,
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  status text not null default 'released' check (status in ('released','in_progress','picked','staged','handed_off','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  started_by uuid references auth.users(id) on delete set null,
  started_at timestamptz,
  staged_by uuid references auth.users(id) on delete set null,
  staged_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,pick_list_no),
  unique (sales_order_id),
  unique (id,organization_id),
  unique (id,factory_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (sales_order_id,factory_id) references public.sales_orders(id,factory_id) on delete restrict,
  foreign key (staging_location_id,factory_id) references public.stock_locations(id,factory_id) on delete restrict
);
create index warehouse_pick_lists_factory_status_idx on public.warehouse_pick_lists(factory_id,status,created_at desc);

create table public.warehouse_pick_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  pick_list_id uuid not null,
  sales_allocation_id uuid not null unique,
  sales_order_line_id uuid not null,
  item_id uuid not null,
  from_location_id uuid not null,
  quantity_required numeric(18,4) not null check (quantity_required > 0),
  picked_quantity numeric(18,4) not null default 0 check (picked_quantity >= 0),
  status text not null default 'pending' check (status in ('pending','picked','cancelled')),
  transfer_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  picked_by uuid references auth.users(id) on delete set null,
  picked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,organization_id),
  foreign key (pick_list_id,organization_id) references public.warehouse_pick_lists(id,organization_id) on delete cascade,
  foreign key (sales_allocation_id) references public.sales_allocations(id) on delete restrict,
  foreign key (sales_order_line_id,organization_id) references public.sales_order_lines(id,organization_id) on delete restrict,
  foreign key (item_id,organization_id) references public.inventory_items(id,organization_id) on delete restrict,
  check (picked_quantity <= quantity_required),
  check ((status='picked' and picked_quantity=quantity_required and transfer_transaction_id is not null and picked_at is not null) or status<>'picked')
);
create index warehouse_pick_lines_pick_status_idx on public.warehouse_pick_lines(pick_list_id,status);

create table public.warehouse_dispatch_handoffs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  handoff_no text not null default ('WH-HO-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  pick_list_id uuid not null unique,
  sales_order_id uuid not null,
  staging_location_id uuid not null,
  status text not null default 'ready' check (status in ('ready','handed_off','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  handed_off_by uuid references auth.users(id) on delete set null,
  handed_off_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,handoff_no),
  unique (id,organization_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (pick_list_id,factory_id) references public.warehouse_pick_lists(id,factory_id) on delete restrict,
  foreign key (sales_order_id,factory_id) references public.sales_orders(id,factory_id) on delete restrict,
  foreign key (staging_location_id,factory_id) references public.stock_locations(id,factory_id) on delete restrict,
  check ((status='handed_off' and handed_off_at is not null) or status<>'handed_off')
);
create index warehouse_handoff_factory_status_idx on public.warehouse_dispatch_handoffs(factory_id,status,created_at desc);

create table public.warehouse_cycle_counts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  count_no text not null default ('CC-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  location_id uuid not null,
  status text not null default 'open' check (status in ('open','in_progress','submitted','approved','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  started_by uuid references auth.users(id) on delete set null,
  started_at timestamptz,
  submitted_by uuid references auth.users(id) on delete set null,
  submitted_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,count_no),
  unique (id,organization_id),
  unique (id,factory_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (location_id,factory_id) references public.stock_locations(id,factory_id) on delete restrict,
  check ((status='approved' and approved_at is not null) or status<>'approved')
);
create index warehouse_cycle_count_factory_status_idx on public.warehouse_cycle_counts(factory_id,status,created_at desc);

create table public.warehouse_cycle_count_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  cycle_count_id uuid not null,
  item_id uuid not null,
  system_quantity numeric(18,4) not null,
  counted_quantity numeric(18,4),
  variance_quantity numeric(18,4),
  adjustment_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  counted_by uuid references auth.users(id) on delete set null,
  counted_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cycle_count_id,item_id),
  unique (id,organization_id),
  foreign key (cycle_count_id,organization_id) references public.warehouse_cycle_counts(id,organization_id) on delete cascade,
  foreign key (item_id,organization_id) references public.inventory_items(id,organization_id) on delete restrict,
  check (counted_quantity is null or counted_quantity >= 0),
  check (variance_quantity is null or counted_quantity is not null)
);

create table public.warehouse_stock_adjustments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  adjustment_no text not null default ('WADJ-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  item_id uuid not null,
  location_id uuid not null,
  quantity_delta numeric(18,4) not null check (quantity_delta <> 0),
  reason text not null check (char_length(trim(reason)) between 3 and 240),
  source text not null default 'manual' check (source in ('manual','cycle_count')),
  cycle_count_id uuid,
  inventory_transaction_id uuid not null unique references public.inventory_transactions(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id,adjustment_no),
  unique (id,organization_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (item_id,organization_id) references public.inventory_items(id,organization_id) on delete restrict,
  foreign key (location_id,factory_id) references public.stock_locations(id,factory_id) on delete restrict,
  foreign key (cycle_count_id,factory_id) references public.warehouse_cycle_counts(id,factory_id) on delete restrict
);
create index warehouse_adjustments_factory_date_idx on public.warehouse_stock_adjustments(factory_id,created_at desc);

create trigger warehouse_putaway_tasks_set_updated_at before update on public.warehouse_putaway_tasks for each row execute function public.set_updated_at();
create trigger warehouse_pick_lists_set_updated_at before update on public.warehouse_pick_lists for each row execute function public.set_updated_at();
create trigger warehouse_pick_lines_set_updated_at before update on public.warehouse_pick_lines for each row execute function public.set_updated_at();
create trigger warehouse_dispatch_handoffs_set_updated_at before update on public.warehouse_dispatch_handoffs for each row execute function public.set_updated_at();
create trigger warehouse_cycle_counts_set_updated_at before update on public.warehouse_cycle_counts for each row execute function public.set_updated_at();
create trigger warehouse_cycle_count_lines_set_updated_at before update on public.warehouse_cycle_count_lines for each row execute function public.set_updated_at();

create or replace function public.can_view_warehouse_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_view_inventory_factory(target_factory_id);
$$;
grant execute on function public.can_view_warehouse_factory(uuid) to authenticated;

create or replace function public.can_operate_warehouse_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_manage_factory(target_factory_id)
    or exists (
      select 1 from public.factory_members fm
      join public.organization_members om
        on om.organization_id=fm.organization_id and om.user_id=fm.user_id and om.is_active
      where fm.factory_id=target_factory_id
        and fm.user_id=auth.uid()
        and fm.is_active
        and om.role in ('supervisor','employee')
    );
$$;
grant execute on function public.can_operate_warehouse_factory(uuid) to authenticated;

create or replace function public.can_plan_warehouse_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_manage_factory(target_factory_id)
    or exists (
      select 1 from public.factory_members fm
      join public.organization_members om
        on om.organization_id=fm.organization_id and om.user_id=fm.user_id and om.is_active
      where fm.factory_id=target_factory_id
        and fm.user_id=auth.uid()
        and fm.is_active
        and om.role='supervisor'
    );
$$;
grant execute on function public.can_plan_warehouse_factory(uuid) to authenticated;

alter table public.warehouse_putaway_tasks enable row level security;
alter table public.warehouse_pick_lists enable row level security;
alter table public.warehouse_pick_lines enable row level security;
alter table public.warehouse_dispatch_handoffs enable row level security;
alter table public.warehouse_cycle_counts enable row level security;
alter table public.warehouse_cycle_count_lines enable row level security;
alter table public.warehouse_stock_adjustments enable row level security;

grant select on public.warehouse_putaway_tasks,public.warehouse_pick_lists,public.warehouse_pick_lines,public.warehouse_dispatch_handoffs,public.warehouse_cycle_counts,public.warehouse_cycle_count_lines,public.warehouse_stock_adjustments to authenticated;

create policy warehouse_putaway_select on public.warehouse_putaway_tasks for select to authenticated using (public.can_view_warehouse_factory(factory_id));
create policy warehouse_pick_lists_select on public.warehouse_pick_lists for select to authenticated using (public.can_view_warehouse_factory(factory_id));
create policy warehouse_pick_lines_select on public.warehouse_pick_lines for select to authenticated using (exists(select 1 from public.warehouse_pick_lists p where p.id=pick_list_id and public.can_view_warehouse_factory(p.factory_id)));
create policy warehouse_handoffs_select on public.warehouse_dispatch_handoffs for select to authenticated using (public.can_view_warehouse_factory(factory_id));
create policy warehouse_cycle_counts_select on public.warehouse_cycle_counts for select to authenticated using (public.can_view_warehouse_factory(factory_id));
create policy warehouse_cycle_count_lines_select on public.warehouse_cycle_count_lines for select to authenticated using (exists(select 1 from public.warehouse_cycle_counts c where c.id=cycle_count_id and public.can_view_warehouse_factory(c.factory_id)));
create policy warehouse_adjustments_select on public.warehouse_stock_adjustments for select to authenticated using (public.can_view_warehouse_factory(factory_id));

create or replace function public.audit_warehouse_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_factory uuid; v_id text; v_meta jsonb;
begin
  v_org:=coalesce(new.organization_id,old.organization_id);
  if tg_table_name in ('warehouse_putaway_tasks','warehouse_pick_lists','warehouse_dispatch_handoffs','warehouse_cycle_counts','warehouse_stock_adjustments') then
    v_factory:=coalesce(new.factory_id,old.factory_id);
  elsif tg_table_name='warehouse_pick_lines' then
    select factory_id into v_factory from public.warehouse_pick_lists where id=coalesce(new.pick_list_id,old.pick_list_id);
  elsif tg_table_name='warehouse_cycle_count_lines' then
    select factory_id into v_factory from public.warehouse_cycle_counts where id=coalesce(new.cycle_count_id,old.cycle_count_id);
  end if;
  v_id:=coalesce(new.id,old.id)::text;
  if tg_op='INSERT' then v_meta:=jsonb_build_object('after',to_jsonb(new));
  elsif tg_op='UPDATE' then v_meta:=jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new));
  else v_meta:=jsonb_build_object('before',to_jsonb(old)); end if;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_org,v_factory,auth.uid(),lower(tg_op),tg_table_name,v_id,v_meta);
  return coalesce(new,old);
end; $$;
revoke all on function public.audit_warehouse_change() from public;

create trigger warehouse_putaway_audit after insert or update on public.warehouse_putaway_tasks for each row execute function public.audit_warehouse_change();
create trigger warehouse_pick_lists_audit after insert or update on public.warehouse_pick_lists for each row execute function public.audit_warehouse_change();
create trigger warehouse_pick_lines_audit after insert or update on public.warehouse_pick_lines for each row execute function public.audit_warehouse_change();
create trigger warehouse_handoff_audit after insert or update on public.warehouse_dispatch_handoffs for each row execute function public.audit_warehouse_change();
create trigger warehouse_cycle_counts_audit after insert or update on public.warehouse_cycle_counts for each row execute function public.audit_warehouse_change();
create trigger warehouse_cycle_count_lines_audit after insert or update on public.warehouse_cycle_count_lines for each row execute function public.audit_warehouse_change();
create trigger warehouse_adjustments_audit after insert on public.warehouse_stock_adjustments for each row execute function public.audit_warehouse_change();

create or replace function public.prevent_warehouse_adjustment_change()
returns trigger language plpgsql set search_path=public as $$ begin raise exception 'Warehouse adjustment history is immutable'; end; $$;
revoke all on function public.prevent_warehouse_adjustment_change() from public;
create trigger warehouse_adjustments_immutable before update or delete on public.warehouse_stock_adjustments for each row execute function public.prevent_warehouse_adjustment_change();

create or replace function public.warehouse_transfer_stock_internal(
  p_factory_id uuid,
  p_item_id uuid,
  p_from_location_id uuid,
  p_to_location_id uuid,
  p_quantity numeric,
  p_external_reference text,
  p_notes text
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_available numeric(18,4); v_tx uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_operate_warehouse_factory(p_factory_id) then raise exception 'Warehouse operation not allowed for this factory'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  if p_from_location_id=p_to_location_id then raise exception 'Source and destination must be different'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.inventory_items where id=p_item_id and organization_id=v_org and is_active) then raise exception 'Active item not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_from_location_id and factory_id=p_factory_id and is_active) then raise exception 'Source location not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_to_location_id and factory_id=p_factory_id and is_active) then raise exception 'Destination location not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_item_id::text||':'||p_from_location_id::text,0));
  select coalesce(sum(quantity_delta),0) into v_available from public.stock_ledger_entries where item_id=p_item_id and location_id=p_from_location_id;
  if v_available<p_quantity then raise exception 'Insufficient stock: available %, requested %',v_available,p_quantity; end if;
  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,to_location_id,external_reference,notes,created_by)
  values(v_org,p_factory_id,p_item_id,'transfer',p_quantity,p_from_location_id,p_to_location_id,nullif(trim(p_external_reference),''),nullif(trim(p_notes),''),auth.uid()) returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
  values(v_org,p_factory_id,v_tx,p_item_id,p_from_location_id,-p_quantity),(v_org,p_factory_id,v_tx,p_item_id,p_to_location_id,p_quantity);
  return v_tx;
end; $$;
revoke all on function public.warehouse_transfer_stock_internal(uuid,uuid,uuid,uuid,numeric,text,text) from public;
grant execute on function public.warehouse_transfer_stock_internal(uuid,uuid,uuid,uuid,numeric,text,text) to authenticated;

create or replace function public.warehouse_create_putaway_task(
  p_factory_id uuid,
  p_item_id uuid,
  p_source_location_id uuid,
  p_target_location_id uuid,
  p_quantity numeric,
  p_goods_receipt_id uuid default null,
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_id uuid; v_on_hand numeric; v_reserved numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_plan_warehouse_factory(p_factory_id) then raise exception 'Warehouse planning access required'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.inventory_items where id=p_item_id and organization_id=v_org and is_active) then raise exception 'Active item not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_source_location_id and factory_id=p_factory_id and is_active) then raise exception 'Source location not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_target_location_id and factory_id=p_factory_id and is_active and location_type='bin') then raise exception 'Target must be an active warehouse bin'; end if;
  if p_goods_receipt_id is not null and not exists(select 1 from public.goods_receipts where id=p_goods_receipt_id and factory_id=p_factory_id and status='released') then raise exception 'Released goods receipt not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_item_id::text||':'||p_source_location_id::text,0));
  select coalesce(sum(quantity_delta),0) into v_on_hand from public.stock_ledger_entries where item_id=p_item_id and location_id=p_source_location_id;
  select coalesce(sum(quantity),0) into v_reserved from public.warehouse_putaway_tasks where item_id=p_item_id and source_location_id=p_source_location_id and status in ('pending','in_progress');
  if v_on_hand-v_reserved<p_quantity then raise exception 'Insufficient unassigned source stock for put-away'; end if;
  insert into public.warehouse_putaway_tasks(organization_id,factory_id,goods_receipt_id,item_id,source_location_id,target_location_id,quantity,notes,created_by)
  values(v_org,p_factory_id,p_goods_receipt_id,p_item_id,p_source_location_id,p_target_location_id,p_quantity,nullif(trim(p_notes),''),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.warehouse_create_putaway_task(uuid,uuid,uuid,uuid,numeric,uuid,text) to authenticated;

create or replace function public.warehouse_start_putaway(p_task_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_task public.warehouse_putaway_tasks%rowtype;
begin
  select * into v_task from public.warehouse_putaway_tasks where id=p_task_id for update;
  if v_task.id is null then raise exception 'Put-away task not found'; end if;
  if not public.can_operate_warehouse_factory(v_task.factory_id) then raise exception 'Warehouse operation not allowed'; end if;
  if v_task.status<>'pending' then raise exception 'Put-away task cannot start from status %',v_task.status; end if;
  update public.warehouse_putaway_tasks set status='in_progress',started_by=auth.uid(),started_at=now() where id=p_task_id;
end; $$;
grant execute on function public.warehouse_start_putaway(uuid) to authenticated;

create or replace function public.warehouse_complete_putaway(p_task_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_task public.warehouse_putaway_tasks%rowtype; v_tx uuid;
begin
  select * into v_task from public.warehouse_putaway_tasks where id=p_task_id for update;
  if v_task.id is null then raise exception 'Put-away task not found'; end if;
  if not public.can_operate_warehouse_factory(v_task.factory_id) then raise exception 'Warehouse operation not allowed'; end if;
  if v_task.status not in ('pending','in_progress') then raise exception 'Put-away task cannot complete from status %',v_task.status; end if;
  select public.warehouse_transfer_stock_internal(v_task.factory_id,v_task.item_id,v_task.source_location_id,v_task.target_location_id,v_task.quantity,v_task.task_no,'Warehouse put-away') into v_tx;
  update public.warehouse_putaway_tasks set status='completed',completed_transaction_id=v_tx,completed_by=auth.uid(),completed_at=now(),started_by=coalesce(started_by,auth.uid()),started_at=coalesce(started_at,now()) where id=p_task_id;
  return v_tx;
end; $$;
grant execute on function public.warehouse_complete_putaway(uuid) to authenticated;

create or replace function public.warehouse_create_pick_list(
  p_sales_order_id uuid,
  p_staging_location_id uuid,
  p_priority text default 'normal',
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_order public.sales_orders%rowtype; v_id uuid; v_alloc public.sales_allocations%rowtype; v_count integer:=0;
begin
  select * into v_order from public.sales_orders where id=p_sales_order_id for update;
  if v_order.id is null then raise exception 'Sales order not found'; end if;
  if not public.can_plan_warehouse_factory(v_order.factory_id) then raise exception 'Warehouse planning access required'; end if;
  if v_order.status not in ('allocated','dispatch_ready') then raise exception 'Sales order is not ready for warehouse picking'; end if;
  if p_priority not in ('low','normal','high','urgent') then raise exception 'Unsupported pick priority'; end if;
  if exists(select 1 from public.warehouse_pick_lists where sales_order_id=p_sales_order_id) then raise exception 'Pick list already exists for this sales order'; end if;
  if not exists(select 1 from public.stock_locations where id=p_staging_location_id and factory_id=v_order.factory_id and is_active and location_type in ('staging','dispatch')) then raise exception 'Active staging/dispatch location not found'; end if;
  insert into public.warehouse_pick_lists(organization_id,factory_id,sales_order_id,staging_location_id,priority,notes,created_by)
  values(v_order.organization_id,v_order.factory_id,p_sales_order_id,p_staging_location_id,p_priority,nullif(trim(p_notes),''),auth.uid()) returning id into v_id;
  for v_alloc in select * from public.sales_allocations where sales_order_id=p_sales_order_id and status='allocated' order by created_at loop
    insert into public.warehouse_pick_lines(organization_id,pick_list_id,sales_allocation_id,sales_order_line_id,item_id,from_location_id,quantity_required)
    values(v_order.organization_id,v_id,v_alloc.id,v_alloc.sales_order_line_id,v_alloc.item_id,v_alloc.location_id,v_alloc.quantity);
    v_count:=v_count+1;
  end loop;
  if v_count=0 then raise exception 'Sales order has no active stock allocations'; end if;
  return v_id;
end; $$;
grant execute on function public.warehouse_create_pick_list(uuid,uuid,text,text) to authenticated;

create or replace function public.warehouse_start_pick_list(p_pick_list_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_pick public.warehouse_pick_lists%rowtype;
begin
  select * into v_pick from public.warehouse_pick_lists where id=p_pick_list_id for update;
  if v_pick.id is null then raise exception 'Pick list not found'; end if;
  if not public.can_operate_warehouse_factory(v_pick.factory_id) then raise exception 'Warehouse operation not allowed'; end if;
  if v_pick.status<>'released' then raise exception 'Pick list cannot start from status %',v_pick.status; end if;
  update public.warehouse_pick_lists set status='in_progress',started_by=auth.uid(),started_at=now() where id=p_pick_list_id;
end; $$;
grant execute on function public.warehouse_start_pick_list(uuid) to authenticated;

create or replace function public.warehouse_confirm_pick_line(p_pick_line_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_line public.warehouse_pick_lines%rowtype; v_pick public.warehouse_pick_lists%rowtype; v_tx uuid;
begin
  select * into v_line from public.warehouse_pick_lines where id=p_pick_line_id for update;
  if v_line.id is null then raise exception 'Pick line not found'; end if;
  select * into v_pick from public.warehouse_pick_lists where id=v_line.pick_list_id for update;
  if not public.can_operate_warehouse_factory(v_pick.factory_id) then raise exception 'Warehouse operation not allowed'; end if;
  if v_pick.status not in ('released','in_progress') then raise exception 'Pick list cannot be picked from status %',v_pick.status; end if;
  if v_line.status<>'pending' then raise exception 'Pick line is already completed'; end if;
  select public.warehouse_transfer_stock_internal(v_pick.factory_id,v_line.item_id,v_line.from_location_id,v_pick.staging_location_id,v_line.quantity_required,v_pick.pick_list_no,'Warehouse picking to staging') into v_tx;
  update public.sales_allocations set location_id=v_pick.staging_location_id,updated_at=now() where id=v_line.sales_allocation_id and status='allocated';
  update public.warehouse_pick_lines set picked_quantity=quantity_required,status='picked',transfer_transaction_id=v_tx,picked_by=auth.uid(),picked_at=now() where id=p_pick_line_id;
  update public.warehouse_pick_lists set status='in_progress',started_by=coalesce(started_by,auth.uid()),started_at=coalesce(started_at,now()) where id=v_pick.id and status='released';
  if not exists(select 1 from public.warehouse_pick_lines where pick_list_id=v_pick.id and status='pending') then
    update public.warehouse_pick_lists set status='picked' where id=v_pick.id;
  end if;
  return v_tx;
end; $$;
grant execute on function public.warehouse_confirm_pick_line(uuid) to authenticated;

create or replace function public.warehouse_stage_pick_list(p_pick_list_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_pick public.warehouse_pick_lists%rowtype; v_handoff uuid;
begin
  select * into v_pick from public.warehouse_pick_lists where id=p_pick_list_id for update;
  if v_pick.id is null then raise exception 'Pick list not found'; end if;
  if not public.can_operate_warehouse_factory(v_pick.factory_id) then raise exception 'Warehouse operation not allowed'; end if;
  if v_pick.status<>'picked' then raise exception 'Only fully picked lists can be staged'; end if;
  if exists(select 1 from public.warehouse_pick_lines where pick_list_id=p_pick_list_id and status<>'picked') then raise exception 'Every pick line must be completed'; end if;
  update public.warehouse_pick_lists set status='staged',staged_by=auth.uid(),staged_at=now() where id=p_pick_list_id;
  insert into public.warehouse_dispatch_handoffs(organization_id,factory_id,pick_list_id,sales_order_id,staging_location_id,created_by)
  values(v_pick.organization_id,v_pick.factory_id,v_pick.id,v_pick.sales_order_id,v_pick.staging_location_id,auth.uid())
  returning id into v_handoff;
  return v_handoff;
end; $$;
grant execute on function public.warehouse_stage_pick_list(uuid) to authenticated;

create or replace function public.warehouse_handoff_pick_list(p_pick_list_id uuid,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_pick public.warehouse_pick_lists%rowtype;
begin
  select * into v_pick from public.warehouse_pick_lists where id=p_pick_list_id for update;
  if v_pick.id is null then raise exception 'Pick list not found'; end if;
  if not public.can_plan_warehouse_factory(v_pick.factory_id) then raise exception 'Warehouse supervisor access required'; end if;
  if v_pick.status<>'staged' then raise exception 'Pick list is not staged'; end if;
  update public.warehouse_dispatch_handoffs set status='handed_off',notes=coalesce(nullif(trim(p_notes),''),notes),handed_off_by=auth.uid(),handed_off_at=now() where pick_list_id=p_pick_list_id and status='ready';
  if not found then raise exception 'Ready dispatch handoff not found'; end if;
  update public.warehouse_pick_lists set status='handed_off' where id=p_pick_list_id;
end; $$;
grant execute on function public.warehouse_handoff_pick_list(uuid,text) to authenticated;

create or replace function public.warehouse_create_cycle_count(p_factory_id uuid,p_location_id uuid,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_id uuid; v_rows integer;
begin
  if not public.can_plan_warehouse_factory(p_factory_id) then raise exception 'Warehouse planning access required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_location_id and factory_id=p_factory_id and is_active) then raise exception 'Count location not found'; end if;
  if exists(select 1 from public.warehouse_cycle_counts where location_id=p_location_id and status in ('open','in_progress','submitted')) then raise exception 'An open cycle count already exists for this location'; end if;
  insert into public.warehouse_cycle_counts(organization_id,factory_id,location_id,notes,created_by)
  values(v_org,p_factory_id,p_location_id,nullif(trim(p_notes),''),auth.uid()) returning id into v_id;
  insert into public.warehouse_cycle_count_lines(organization_id,cycle_count_id,item_id,system_quantity)
  select v_org,v_id,le.item_id,sum(le.quantity_delta)
  from public.stock_ledger_entries le
  where le.factory_id=p_factory_id and le.location_id=p_location_id
  group by le.item_id
  having sum(le.quantity_delta)<>0;
  get diagnostics v_rows=row_count;
  if v_rows=0 then raise exception 'No stock exists at the selected count location'; end if;
  return v_id;
end; $$;
grant execute on function public.warehouse_create_cycle_count(uuid,uuid,text) to authenticated;

create or replace function public.warehouse_record_cycle_count_line(p_line_id uuid,p_counted_quantity numeric,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_line public.warehouse_cycle_count_lines%rowtype; v_count public.warehouse_cycle_counts%rowtype;
begin
  if p_counted_quantity is null or p_counted_quantity<0 then raise exception 'Counted quantity cannot be negative'; end if;
  select * into v_line from public.warehouse_cycle_count_lines where id=p_line_id for update;
  if v_line.id is null then raise exception 'Cycle-count line not found'; end if;
  select * into v_count from public.warehouse_cycle_counts where id=v_line.cycle_count_id for update;
  if not public.can_operate_warehouse_factory(v_count.factory_id) then raise exception 'Warehouse operation not allowed'; end if;
  if v_count.status not in ('open','in_progress') then raise exception 'Cycle count is not open for counting'; end if;
  update public.warehouse_cycle_count_lines set counted_quantity=p_counted_quantity,variance_quantity=p_counted_quantity-system_quantity,counted_by=auth.uid(),counted_at=now(),notes=nullif(trim(p_notes),'') where id=p_line_id;
  update public.warehouse_cycle_counts set status='in_progress',started_by=coalesce(started_by,auth.uid()),started_at=coalesce(started_at,now()) where id=v_count.id and status='open';
end; $$;
grant execute on function public.warehouse_record_cycle_count_line(uuid,numeric,text) to authenticated;

create or replace function public.warehouse_submit_cycle_count(p_cycle_count_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_count public.warehouse_cycle_counts%rowtype;
begin
  select * into v_count from public.warehouse_cycle_counts where id=p_cycle_count_id for update;
  if v_count.id is null then raise exception 'Cycle count not found'; end if;
  if not public.can_operate_warehouse_factory(v_count.factory_id) then raise exception 'Warehouse operation not allowed'; end if;
  if v_count.status not in ('open','in_progress') then raise exception 'Cycle count cannot be submitted from status %',v_count.status; end if;
  if exists(select 1 from public.warehouse_cycle_count_lines where cycle_count_id=p_cycle_count_id and counted_quantity is null) then raise exception 'Every cycle-count line must be counted'; end if;
  update public.warehouse_cycle_counts set status='submitted',submitted_by=auth.uid(),submitted_at=now() where id=p_cycle_count_id;
end; $$;
grant execute on function public.warehouse_submit_cycle_count(uuid) to authenticated;

create or replace function public.warehouse_adjust_stock_internal(
  p_factory_id uuid,p_item_id uuid,p_location_id uuid,p_quantity_delta numeric,p_reason text,p_source text,p_cycle_count_id uuid default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_on_hand numeric; v_tx uuid; v_adj uuid; v_qty numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Manager access required for stock adjustment'; end if;
  if p_quantity_delta is null or p_quantity_delta=0 then raise exception 'Adjustment quantity cannot be zero'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Adjustment reason is required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.inventory_items where id=p_item_id and organization_id=v_org and is_active) then raise exception 'Active item not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_location_id and factory_id=p_factory_id and is_active) then raise exception 'Active stock location not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_item_id::text||':'||p_location_id::text,0));
  select coalesce(sum(quantity_delta),0) into v_on_hand from public.stock_ledger_entries where item_id=p_item_id and location_id=p_location_id;
  if p_quantity_delta<0 and v_on_hand<abs(p_quantity_delta) then raise exception 'Adjustment would create negative stock'; end if;
  v_qty:=abs(p_quantity_delta);
  if p_quantity_delta>0 then
    insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,to_location_id,external_reference,notes,created_by)
    values(v_org,p_factory_id,p_item_id,'receive',v_qty,p_location_id,'WAREHOUSE-ADJUSTMENT',trim(p_reason),auth.uid()) returning id into v_tx;
    insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
    values(v_org,p_factory_id,v_tx,p_item_id,p_location_id,v_qty);
  else
    insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,external_reference,notes,created_by)
    values(v_org,p_factory_id,p_item_id,'issue',v_qty,p_location_id,'WAREHOUSE-ADJUSTMENT',trim(p_reason),auth.uid()) returning id into v_tx;
    insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta)
    values(v_org,p_factory_id,v_tx,p_item_id,p_location_id,-v_qty);
  end if;
  insert into public.warehouse_stock_adjustments(organization_id,factory_id,item_id,location_id,quantity_delta,reason,source,cycle_count_id,inventory_transaction_id,created_by)
  values(v_org,p_factory_id,p_item_id,p_location_id,p_quantity_delta,trim(p_reason),p_source,p_cycle_count_id,v_tx,auth.uid()) returning id into v_adj;
  return v_adj;
end; $$;
revoke all on function public.warehouse_adjust_stock_internal(uuid,uuid,uuid,numeric,text,text,uuid) from public;
grant execute on function public.warehouse_adjust_stock_internal(uuid,uuid,uuid,numeric,text,text,uuid) to authenticated;

create or replace function public.warehouse_adjust_stock(p_factory_id uuid,p_item_id uuid,p_location_id uuid,p_quantity_delta numeric,p_reason text)
returns uuid language sql security definer set search_path=public as $$
  select public.warehouse_adjust_stock_internal(p_factory_id,p_item_id,p_location_id,p_quantity_delta,p_reason,'manual',null::uuid);
$$;
grant execute on function public.warehouse_adjust_stock(uuid,uuid,uuid,numeric,text) to authenticated;

create or replace function public.warehouse_approve_cycle_count(p_cycle_count_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_count public.warehouse_cycle_counts%rowtype; v_line public.warehouse_cycle_count_lines%rowtype; v_current numeric; v_adj uuid; v_tx uuid;
begin
  select * into v_count from public.warehouse_cycle_counts where id=p_cycle_count_id for update;
  if v_count.id is null then raise exception 'Cycle count not found'; end if;
  if not public.can_manage_factory(v_count.factory_id) then raise exception 'Manager approval required'; end if;
  if v_count.status<>'submitted' then raise exception 'Cycle count must be submitted before approval'; end if;
  for v_line in select * from public.warehouse_cycle_count_lines where cycle_count_id=p_cycle_count_id order by id for update loop
    perform pg_advisory_xact_lock(hashtextextended(v_line.item_id::text||':'||v_count.location_id::text,0));
    select coalesce(sum(quantity_delta),0) into v_current from public.stock_ledger_entries where item_id=v_line.item_id and location_id=v_count.location_id;
    if v_current<>v_line.system_quantity then raise exception 'Stock changed after cycle-count snapshot for item %; restart count',v_line.item_id; end if;
    if coalesce(v_line.variance_quantity,0)<>0 then
      select public.warehouse_adjust_stock_internal(v_count.factory_id,v_line.item_id,v_count.location_id,v_line.variance_quantity,'Cycle count '||v_count.count_no,'cycle_count',v_count.id) into v_adj;
      select inventory_transaction_id into v_tx from public.warehouse_stock_adjustments where id=v_adj;
      update public.warehouse_cycle_count_lines set adjustment_transaction_id=v_tx where id=v_line.id;
    end if;
  end loop;
  update public.warehouse_cycle_counts set status='approved',approved_by=auth.uid(),approved_at=now() where id=p_cycle_count_id;
end; $$;
grant execute on function public.warehouse_approve_cycle_count(uuid) to authenticated;

create or replace function public.warehouse_dashboard_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_warehouse_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  select jsonb_build_object(
    'warehouses',(select count(*) from public.stock_locations l where l.organization_id=p_organization_id and l.is_active and l.location_type='warehouse' and (p_factory_id is null or l.factory_id=p_factory_id) and public.can_view_warehouse_factory(l.factory_id)),
    'zones',(select count(*) from public.stock_locations l where l.organization_id=p_organization_id and l.is_active and l.location_type='zone' and (p_factory_id is null or l.factory_id=p_factory_id) and public.can_view_warehouse_factory(l.factory_id)),
    'bins',(select count(*) from public.stock_locations l where l.organization_id=p_organization_id and l.is_active and l.location_type='bin' and (p_factory_id is null or l.factory_id=p_factory_id) and public.can_view_warehouse_factory(l.factory_id)),
    'pending_putaway',(select count(*) from public.warehouse_putaway_tasks t where t.organization_id=p_organization_id and t.status in ('pending','in_progress') and (p_factory_id is null or t.factory_id=p_factory_id) and public.can_view_warehouse_factory(t.factory_id)),
    'active_picks',(select count(*) from public.warehouse_pick_lists p where p.organization_id=p_organization_id and p.status in ('released','in_progress','picked','staged') and (p_factory_id is null or p.factory_id=p_factory_id) and public.can_view_warehouse_factory(p.factory_id)),
    'open_cycle_counts',(select count(*) from public.warehouse_cycle_counts c where c.organization_id=p_organization_id and c.status in ('open','in_progress','submitted') and (p_factory_id is null or c.factory_id=p_factory_id) and public.can_view_warehouse_factory(c.factory_id)),
    'ready_handoffs',(select count(*) from public.warehouse_dispatch_handoffs h where h.organization_id=p_organization_id and h.status='ready' and (p_factory_id is null or h.factory_id=p_factory_id) and public.can_view_warehouse_factory(h.factory_id))
  ) into result;
  return result;
end; $$;
grant execute on function public.warehouse_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.warehouse_bin_stock_report(p_organization_id uuid,p_factory_id uuid default null)
returns table(factory_id uuid,location_id uuid,location_code text,location_name text,location_type text,item_id uuid,sku text,item_name text,on_hand numeric,reserved numeric,available numeric)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_warehouse_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  return query
  with ledger as (
    select le.factory_id,le.location_id,le.item_id,sum(le.quantity_delta)::numeric on_hand
    from public.stock_ledger_entries le
    where le.organization_id=p_organization_id and (p_factory_id is null or le.factory_id=p_factory_id)
    group by le.factory_id,le.location_id,le.item_id
  ), reserves as (
    select sa.factory_id,sa.location_id,sa.item_id,sum(sa.quantity)::numeric reserved
    from public.sales_allocations sa
    where sa.organization_id=p_organization_id and sa.status='allocated' and (p_factory_id is null or sa.factory_id=p_factory_id)
    group by sa.factory_id,sa.location_id,sa.item_id
  )
  select l.factory_id,l.id,l.code,l.name,l.location_type,i.id,i.sku,i.name,coalesce(g.on_hand,0),coalesce(r.reserved,0),(coalesce(g.on_hand,0)-coalesce(r.reserved,0))::numeric
  from ledger g
  join public.stock_locations l on l.id=g.location_id and l.is_active
  join public.inventory_items i on i.id=g.item_id
  left join reserves r on r.factory_id=g.factory_id and r.location_id=g.location_id and r.item_id=g.item_id
  where l.organization_id=p_organization_id and l.location_type in ('warehouse','zone','bin','receiving','staging','dispatch') and public.can_view_warehouse_factory(l.factory_id)
  order by l.code,i.sku;
end; $$;
grant execute on function public.warehouse_bin_stock_report(uuid,uuid) to authenticated;

create or replace function public.warehouse_putaway_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 200)
returns table(task_id uuid,task_no text,factory_id uuid,item_name text,source_location text,target_location text,quantity numeric,status text,created_at timestamptz,completed_at timestamptz)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  return query select t.id,t.task_no,t.factory_id,i.name,s.name,d.name,t.quantity,t.status,t.created_at,t.completed_at
  from public.warehouse_putaway_tasks t
  join public.inventory_items i on i.id=t.item_id
  join public.stock_locations s on s.id=t.source_location_id
  join public.stock_locations d on d.id=t.target_location_id
  where t.organization_id=p_organization_id and (p_factory_id is null or t.factory_id=p_factory_id) and public.can_view_warehouse_factory(t.factory_id)
  order by t.created_at desc limit greatest(1,least(coalesce(p_limit,200),1000));
end; $$;
grant execute on function public.warehouse_putaway_report(uuid,uuid,integer) to authenticated;

create or replace function public.warehouse_pick_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 200)
returns table(pick_list_id uuid,pick_list_no text,factory_id uuid,sales_order_no text,customer_name text,priority text,status text,line_count bigint,picked_lines bigint,created_at timestamptz,staged_at timestamptz)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  return query select p.id,p.pick_list_no,p.factory_id,so.sales_order_no,bp.name,p.priority,p.status,count(pl.id),count(pl.id) filter(where pl.status='picked'),p.created_at,p.staged_at
  from public.warehouse_pick_lists p
  join public.sales_orders so on so.id=p.sales_order_id
  join public.business_partners bp on bp.id=so.customer_id
  left join public.warehouse_pick_lines pl on pl.pick_list_id=p.id
  where p.organization_id=p_organization_id and (p_factory_id is null or p.factory_id=p_factory_id) and public.can_view_warehouse_factory(p.factory_id)
  group by p.id,so.sales_order_no,bp.name order by p.created_at desc limit greatest(1,least(coalesce(p_limit,200),1000));
end; $$;
grant execute on function public.warehouse_pick_report(uuid,uuid,integer) to authenticated;

create or replace function public.warehouse_cycle_count_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 200)
returns table(cycle_count_id uuid,count_no text,factory_id uuid,location_name text,status text,line_count bigint,variance_lines bigint,created_at timestamptz,approved_at timestamptz)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  return query select c.id,c.count_no,c.factory_id,l.name,c.status,count(cl.id),count(cl.id) filter(where coalesce(cl.variance_quantity,0)<>0),c.created_at,c.approved_at
  from public.warehouse_cycle_counts c join public.stock_locations l on l.id=c.location_id left join public.warehouse_cycle_count_lines cl on cl.cycle_count_id=c.id
  where c.organization_id=p_organization_id and (p_factory_id is null or c.factory_id=p_factory_id) and public.can_view_warehouse_factory(c.factory_id)
  group by c.id,l.name order by c.created_at desc limit greatest(1,least(coalesce(p_limit,200),1000));
end; $$;
grant execute on function public.warehouse_cycle_count_report(uuid,uuid,integer) to authenticated;

commit;