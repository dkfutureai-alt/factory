-- FactoryOS production + quality schema
-- Depends on 01_core.sql and 02_inventory.sql

create type public.production_order_status as enum ('draft','planned','material_pending','ready','in_production','qc_pending','completed','cancelled');
create type public.production_batch_status as enum ('planned','in_production','qc_pending','completed','cancelled');
create type public.quality_result as enum ('pending','pass','fail','hold');

create table public.production_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  code text not null,
  name text not null,
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, factory_id, code)
);

create table public.production_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  order_number text not null,
  item_id uuid not null references public.items(id) on delete restrict,
  planned_quantity numeric(18,4) not null check (planned_quantity > 0),
  completed_quantity numeric(18,4) not null default 0 check (completed_quantity >= 0),
  rejected_quantity numeric(18,4) not null default 0 check (rejected_quantity >= 0),
  status public.production_order_status not null default 'draft',
  production_line_id uuid references public.production_lines(id) on delete restrict,
  planned_start_at timestamptz,
  planned_end_at timestamptz,
  actual_start_at timestamptz,
  actual_end_at timestamptz,
  supervisor_user_id uuid references auth.users(id) on delete set null,
  priority smallint not null default 3 check (priority between 1 and 5),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, order_number),
  check (planned_end_at is null or planned_start_at is null or planned_end_at > planned_start_at),
  check (actual_end_at is null or actual_start_at is null or actual_end_at >= actual_start_at),
  check (completed_quantity + rejected_quantity <= planned_quantity * 1.25)
);

create table public.production_material_requirements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  production_order_id uuid not null references public.production_orders(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete restrict,
  planned_quantity numeric(18,4) not null check (planned_quantity > 0),
  issued_quantity numeric(18,4) not null default 0 check (issued_quantity >= 0),
  returned_quantity numeric(18,4) not null default 0 check (returned_quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (production_order_id, item_id),
  check (returned_quantity <= issued_quantity)
);

create table public.production_batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  production_order_id uuid not null references public.production_orders(id) on delete restrict,
  batch_number text not null,
  status public.production_batch_status not null default 'planned',
  planned_quantity numeric(18,4) not null check (planned_quantity > 0),
  good_quantity numeric(18,4) not null default 0 check (good_quantity >= 0),
  rejected_quantity numeric(18,4) not null default 0 check (rejected_quantity >= 0),
  waste_quantity numeric(18,4) not null default 0 check (waste_quantity >= 0),
  production_line_id uuid references public.production_lines(id) on delete restrict,
  started_at timestamptz,
  completed_at timestamptz,
  supervisor_user_id uuid references auth.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, batch_number),
  check (completed_at is null or started_at is null or completed_at >= started_at),
  check (good_quantity + rejected_quantity + waste_quantity <= planned_quantity * 1.25)
);

-- Production stock movements are not independent counters: each record must point to a stock ledger line.
create table public.production_material_consumption (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  production_batch_id uuid not null references public.production_batches(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete restrict,
  batch_id uuid references public.batches(id) on delete restrict,
  quantity numeric(18,4) not null check (quantity > 0),
  stock_transaction_line_id uuid not null unique references public.stock_transaction_lines(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.production_outputs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  production_batch_id uuid not null references public.production_batches(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete restrict,
  finished_batch_id uuid references public.batches(id) on delete restrict,
  quantity numeric(18,4) not null check (quantity > 0),
  output_type text not null check (output_type in ('good','rejected','waste')),
  stock_transaction_line_id uuid references public.stock_transaction_lines(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint production_good_output_requires_stock check (output_type <> 'good' or stock_transaction_line_id is not null)
);

create table public.quality_checks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  check_number text not null,
  production_batch_id uuid not null references public.production_batches(id) on delete restrict,
  inspector_user_id uuid references auth.users(id) on delete set null,
  inspected_at timestamptz,
  result public.quality_result not null default 'pending',
  inspected_quantity numeric(18,4) not null default 0 check (inspected_quantity >= 0),
  rejected_quantity numeric(18,4) not null default 0 check (rejected_quantity >= 0),
  rejection_reason text,
  corrective_action text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, check_number),
  check (rejected_quantity <= inspected_quantity)
);

create table public.quality_check_parameters (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  quality_check_id uuid not null references public.quality_checks(id) on delete cascade,
  parameter_name text not null,
  expected_result text not null,
  actual_result text,
  result public.quality_result not null default 'pending',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index production_lines_org_factory_idx on public.production_lines (organization_id, factory_id, status);
create index production_orders_org_status_idx on public.production_orders (organization_id, factory_id, status, planned_start_at);
create index production_orders_item_idx on public.production_orders (organization_id, item_id, status);
create index production_batches_order_idx on public.production_batches (production_order_id, status);
create index production_batches_org_date_idx on public.production_batches (organization_id, started_at desc);
create index production_consumption_batch_idx on public.production_material_consumption (production_batch_id, item_id);
create index production_outputs_batch_idx on public.production_outputs (production_batch_id, output_type);
create index quality_checks_batch_idx on public.quality_checks (production_batch_id, result);
create index quality_checks_org_date_idx on public.quality_checks (organization_id, inspected_at desc);

create trigger production_lines_set_updated_at before update on public.production_lines
for each row execute function private.set_updated_at();
create trigger production_orders_set_updated_at before update on public.production_orders
for each row execute function private.set_updated_at();
create trigger production_material_requirements_set_updated_at before update on public.production_material_requirements
for each row execute function private.set_updated_at();
create trigger production_batches_set_updated_at before update on public.production_batches
for each row execute function private.set_updated_at();
create trigger quality_checks_set_updated_at before update on public.quality_checks
for each row execute function private.set_updated_at();

-- Completed batches are immutable; correction must be a traceable adjustment/reversal workflow.
create or replace function private.guard_completed_production_batch()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status in ('completed','cancelled') then
    raise exception 'finalized production batch is immutable';
  end if;
  return new;
end;
$$;
create trigger production_batches_guard_finalized
before update or delete on public.production_batches
for each row execute function private.guard_completed_production_batch();

-- Completion only succeeds when QC passed and the linked material/output ledger transactions are posted.
create or replace function public.complete_production_batch(target_batch_id uuid)
returns public.production_batches
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  pb public.production_batches;
  po public.production_orders;
  missing_count bigint;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;

  select * into pb from public.production_batches where id = target_batch_id for update;
  if pb.id is null then raise exception 'production batch not found'; end if;
  if pb.status not in ('in_production','qc_pending') then raise exception 'batch is not ready for completion'; end if;
  if not private.has_permission(pb.organization_id, 'production.complete', pb.factory_id) then raise exception 'permission denied'; end if;

  if not exists (
    select 1 from public.quality_checks q
    where q.production_batch_id = pb.id and q.result = 'pass'
  ) then raise exception 'passed quality check required'; end if;

  select count(*) into missing_count
  from public.production_material_consumption c
  join public.stock_transaction_lines l on l.id = c.stock_transaction_line_id
  join public.stock_transactions t on t.id = l.stock_transaction_id
  where c.production_batch_id = pb.id and t.status <> 'posted';
  if missing_count > 0 then raise exception 'all material consumption must be posted to inventory'; end if;

  if pb.good_quantity > 0 and not exists (
    select 1
    from public.production_outputs o
    join public.stock_transaction_lines l on l.id = o.stock_transaction_line_id
    join public.stock_transactions t on t.id = l.stock_transaction_id
    where o.production_batch_id = pb.id and o.output_type = 'good' and t.status = 'posted'
  ) then raise exception 'finished goods receipt must be posted to inventory'; end if;

  update public.production_batches
  set status = 'completed', completed_at = coalesce(completed_at, now())
  where id = pb.id returning * into pb;

  select * into po from public.production_orders where id = pb.production_order_id for update;
  update public.production_orders
  set completed_quantity = (
        select coalesce(sum(good_quantity),0) from public.production_batches where production_order_id = po.id and status = 'completed'
      ),
      rejected_quantity = (
        select coalesce(sum(rejected_quantity),0) from public.production_batches where production_order_id = po.id and status = 'completed'
      ),
      status = case
        when (select coalesce(sum(good_quantity),0) from public.production_batches where production_order_id = po.id and status = 'completed') >= po.planned_quantity
          then 'completed'::public.production_order_status
        else 'in_production'::public.production_order_status
      end,
      actual_end_at = case
        when (select coalesce(sum(good_quantity),0) from public.production_batches where production_order_id = po.id and status = 'completed') >= po.planned_quantity
          then now() else actual_end_at end
  where id = po.id;

  return pb;
end;
$$;
revoke all on function public.complete_production_batch(uuid) from public;
grant execute on function public.complete_production_batch(uuid) to authenticated;

alter table public.production_lines enable row level security;
alter table public.production_orders enable row level security;
alter table public.production_material_requirements enable row level security;
alter table public.production_batches enable row level security;
alter table public.production_material_consumption enable row level security;
alter table public.production_outputs enable row level security;
alter table public.quality_checks enable row level security;
alter table public.quality_check_parameters enable row level security;

create policy production_lines_select on public.production_lines for select to authenticated
using ((select private.has_permission(organization_id, 'production.read', factory_id)));
create policy production_lines_manage on public.production_lines for all to authenticated
using ((select private.has_permission(organization_id, 'production.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'production.manage', factory_id)));

create policy production_orders_select on public.production_orders for select to authenticated
using ((select private.has_permission(organization_id, 'production.read', factory_id)));
create policy production_orders_manage on public.production_orders for all to authenticated
using ((select private.has_permission(organization_id, 'production.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'production.manage', factory_id)));

create policy production_requirements_select on public.production_material_requirements for select to authenticated
using ((select private.has_permission(organization_id, 'production.read', null)));
create policy production_requirements_manage on public.production_material_requirements for all to authenticated
using ((select private.has_permission(organization_id, 'production.manage', null)))
with check ((select private.has_permission(organization_id, 'production.manage', null)));

create policy production_batches_select on public.production_batches for select to authenticated
using ((select private.has_permission(organization_id, 'production.read', factory_id)));
create policy production_batches_manage on public.production_batches for all to authenticated
using ((select private.has_permission(organization_id, 'production.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'production.manage', factory_id)));

create policy production_consumption_select on public.production_material_consumption for select to authenticated
using ((select private.has_permission(organization_id, 'production.read', null)));
create policy production_consumption_manage on public.production_material_consumption for all to authenticated
using ((select private.has_permission(organization_id, 'production.manage', null)))
with check ((select private.has_permission(organization_id, 'production.manage', null)));

create policy production_outputs_select on public.production_outputs for select to authenticated
using ((select private.has_permission(organization_id, 'production.read', null)));
create policy production_outputs_manage on public.production_outputs for all to authenticated
using ((select private.has_permission(organization_id, 'production.manage', null)))
with check ((select private.has_permission(organization_id, 'production.manage', null)));

create policy quality_checks_select on public.quality_checks for select to authenticated
using ((select private.has_permission(organization_id, 'quality.read', factory_id)));
create policy quality_checks_manage on public.quality_checks for all to authenticated
using ((select private.has_permission(organization_id, 'quality.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'quality.manage', factory_id)));

create policy quality_parameters_select on public.quality_check_parameters for select to authenticated
using ((select private.has_permission(organization_id, 'quality.read', null)));
create policy quality_parameters_manage on public.quality_check_parameters for all to authenticated
using ((select private.has_permission(organization_id, 'quality.manage', null)))
with check ((select private.has_permission(organization_id, 'quality.manage', null)));

-- Explicit Data API grants; RLS remains authoritative.
grant select, insert, update, delete on public.production_lines to authenticated;
grant select, insert, update, delete on public.production_orders to authenticated;
grant select, insert, update, delete on public.production_material_requirements to authenticated;
grant select, insert, update, delete on public.production_batches to authenticated;
grant select, insert, update, delete on public.production_material_consumption to authenticated;
grant select, insert, update, delete on public.production_outputs to authenticated;
grant select, insert, update, delete on public.quality_checks to authenticated;
grant select, insert, update, delete on public.quality_check_parameters to authenticated;