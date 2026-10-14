-- FactoryOS inventory and stock ledger schema
-- Depends on 01_core.sql

create type public.stock_transaction_status as enum ('draft', 'posted', 'reversed', 'cancelled');
create type public.stock_transaction_type as enum (
  'opening', 'purchase_receipt', 'production_issue', 'production_return',
  'transfer_out', 'transfer_in', 'adjustment', 'finished_goods_receipt',
  'sales_dispatch', 'customer_return', 'damaged', 'maintenance_issue', 'maintenance_return'
);

create table public.item_categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  category_type text not null check (category_type in ('raw_material','packaging','consumable','spare_part','finished_good','other')),
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.item_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  decimal_places smallint not null default 0 check (decimal_places between 0 and 6),
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  category_id uuid not null references public.item_categories(id) on delete restrict,
  unit_id uuid not null references public.item_units(id) on delete restrict,
  sku text not null,
  name text not null,
  description text,
  barcode text,
  qr_identifier text,
  cost numeric(18,4) not null default 0 check (cost >= 0),
  selling_price numeric(18,4) check (selling_price is null or selling_price >= 0),
  minimum_stock numeric(18,4) not null default 0 check (minimum_stock >= 0),
  maximum_stock numeric(18,4) check (maximum_stock is null or maximum_stock >= minimum_stock),
  reorder_level numeric(18,4) not null default 0 check (reorder_level >= 0),
  batch_tracking boolean not null default false,
  serial_tracking boolean not null default false,
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, sku),
  unique nulls not distinct (organization_id, barcode),
  unique nulls not distinct (organization_id, qr_identifier),
  constraint items_name_nonempty check (length(btrim(name)) > 0),
  constraint items_tracking_compatible check (not (batch_tracking and serial_tracking))
);

create table public.batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  batch_number text not null,
  manufactured_at timestamptz,
  expires_at timestamptz,
  supplier_batch_number text,
  status public.entity_status not null default 'active',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, item_id, batch_number),
  check (expires_at is null or manufactured_at is null or expires_at > manufactured_at)
);

create table public.serial_numbers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  serial_number text not null,
  current_warehouse_id uuid references public.warehouses(id) on delete restrict,
  current_location_id uuid references public.warehouse_locations(id) on delete restrict,
  status text not null default 'available' check (status in ('available','reserved','issued','dispatched','returned','damaged','scrapped')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, item_id, serial_number)
);

create table public.stock_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid references public.factories(id) on delete restrict,
  transaction_number text not null,
  transaction_type public.stock_transaction_type not null,
  status public.stock_transaction_status not null default 'draft',
  reference_type text,
  reference_id uuid,
  occurred_at timestamptz not null default now(),
  reason text,
  idempotency_key text,
  created_by uuid references auth.users(id) on delete set null,
  posted_by uuid references auth.users(id) on delete set null,
  posted_at timestamptz,
  reversed_transaction_id uuid references public.stock_transactions(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, transaction_number),
  unique nulls not distinct (organization_id, idempotency_key),
  check ((status = 'posted' and posted_at is not null) or status <> 'posted')
);

create table public.stock_transaction_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  stock_transaction_id uuid not null references public.stock_transactions(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete restrict,
  batch_id uuid references public.batches(id) on delete restrict,
  serial_number_id uuid references public.serial_numbers(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  location_id uuid references public.warehouse_locations(id) on delete restrict,
  quantity_delta numeric(18,4) not null check (quantity_delta <> 0),
  unit_cost numeric(18,4) check (unit_cost is null or unit_cost >= 0),
  note text,
  created_at timestamptz not null default now(),
  constraint stock_line_tracking_exclusive check (not (batch_id is not null and serial_number_id is not null))
);

-- Current stock is derived from immutable posted ledger lines. This prevents direct quantity mutation.
create view public.inventory_balances
with (security_invoker = true)
as
select
  l.organization_id,
  l.warehouse_id,
  l.location_id,
  l.item_id,
  l.batch_id,
  l.serial_number_id,
  coalesce(sum(l.quantity_delta), 0::numeric) as quantity_on_hand,
  max(t.posted_at) as last_movement_at
from public.stock_transaction_lines l
join public.stock_transactions t on t.id = l.stock_transaction_id
where t.status = 'posted'
group by l.organization_id, l.warehouse_id, l.location_id, l.item_id, l.batch_id, l.serial_number_id;

create index item_categories_org_status_idx on public.item_categories (organization_id, status);
create index items_org_category_status_idx on public.items (organization_id, category_id, status);
create index items_org_sku_idx on public.items (organization_id, sku);
create index items_org_barcode_idx on public.items (organization_id, barcode) where barcode is not null;
create index items_org_qr_idx on public.items (organization_id, qr_identifier) where qr_identifier is not null;
create index batches_org_item_idx on public.batches (organization_id, item_id, batch_number);
create index serial_numbers_org_item_status_idx on public.serial_numbers (organization_id, item_id, status);
create index stock_transactions_org_date_idx on public.stock_transactions (organization_id, occurred_at desc);
create index stock_transactions_org_status_idx on public.stock_transactions (organization_id, status, transaction_type);
create index stock_transaction_lines_tx_idx on public.stock_transaction_lines (stock_transaction_id);
create index stock_transaction_lines_lookup_idx on public.stock_transaction_lines (organization_id, item_id, warehouse_id, location_id);
create index stock_transaction_lines_batch_idx on public.stock_transaction_lines (batch_id) where batch_id is not null;

create trigger item_categories_set_updated_at before update on public.item_categories
for each row execute function private.set_updated_at();
create trigger item_units_set_updated_at before update on public.item_units
for each row execute function private.set_updated_at();
create trigger items_set_updated_at before update on public.items
for each row execute function private.set_updated_at();
create trigger batches_set_updated_at before update on public.batches
for each row execute function private.set_updated_at();
create trigger serial_numbers_set_updated_at before update on public.serial_numbers
for each row execute function private.set_updated_at();
create trigger stock_transactions_set_updated_at before update on public.stock_transactions
for each row execute function private.set_updated_at();

-- Posted/cancelled/reversed transactions and their lines are immutable to normal authenticated CRUD.
create or replace function private.guard_stock_transaction_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status in ('posted','reversed','cancelled') then
    raise exception 'finalized stock transaction is immutable';
  end if;
  return new;
end;
$$;

create trigger stock_transactions_guard_finalized
before update or delete on public.stock_transactions
for each row execute function private.guard_stock_transaction_mutation();

create or replace function private.guard_stock_line_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  tx_status public.stock_transaction_status;
begin
  select status into tx_status
  from public.stock_transactions
  where id = coalesce(old.stock_transaction_id, new.stock_transaction_id);
  if tx_status <> 'draft' then
    raise exception 'stock lines may only change while transaction is draft';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger stock_transaction_lines_guard
before update or delete on public.stock_transaction_lines
for each row execute function private.guard_stock_line_mutation();

-- Atomic posting validates the organization, permission, non-empty lines, tracking rules and no negative resulting stock.
create or replace function public.post_stock_transaction(target_transaction_id uuid)
returns public.stock_transactions
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  tx public.stock_transactions;
  invalid_count bigint;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required';
  end if;

  select * into tx
  from public.stock_transactions
  where id = target_transaction_id
  for update;

  if tx.id is null then raise exception 'stock transaction not found'; end if;
  if tx.status <> 'draft' then raise exception 'only draft stock transactions can be posted'; end if;
  if not private.has_permission(tx.organization_id, 'inventory.post', tx.factory_id) then
    raise exception 'permission denied';
  end if;
  if not exists (select 1 from public.stock_transaction_lines where stock_transaction_id = tx.id) then
    raise exception 'stock transaction has no lines';
  end if;

  select count(*) into invalid_count
  from public.stock_transaction_lines l
  join public.items i on i.id = l.item_id
  where l.stock_transaction_id = tx.id
    and (
      l.organization_id <> tx.organization_id
      or i.organization_id <> tx.organization_id
      or (i.batch_tracking and l.batch_id is null)
      or (i.serial_tracking and l.serial_number_id is null)
      or (i.serial_tracking and abs(l.quantity_delta) <> 1)
    );
  if invalid_count > 0 then raise exception 'stock transaction contains invalid tracking or organization data'; end if;

  select count(*) into invalid_count
  from (
    select l.organization_id, l.warehouse_id, l.location_id, l.item_id, l.batch_id, l.serial_number_id,
           coalesce(b.quantity_on_hand, 0) + sum(l.quantity_delta) as projected
    from public.stock_transaction_lines l
    left join public.inventory_balances b
      on b.organization_id = l.organization_id
     and b.warehouse_id = l.warehouse_id
     and b.location_id is not distinct from l.location_id
     and b.item_id = l.item_id
     and b.batch_id is not distinct from l.batch_id
     and b.serial_number_id is not distinct from l.serial_number_id
    where l.stock_transaction_id = tx.id
    group by l.organization_id, l.warehouse_id, l.location_id, l.item_id, l.batch_id, l.serial_number_id, b.quantity_on_hand
    having coalesce(b.quantity_on_hand, 0) + sum(l.quantity_delta) < 0
  ) q;
  if invalid_count > 0 then raise exception 'insufficient inventory'; end if;

  update public.stock_transactions
  set status = 'posted', posted_by = (select auth.uid()), posted_at = now()
  where id = tx.id
  returning * into tx;

  return tx;
end;
$$;

revoke all on function public.post_stock_transaction(uuid) from public;
grant execute on function public.post_stock_transaction(uuid) to authenticated;

alter table public.item_categories enable row level security;
alter table public.item_units enable row level security;
alter table public.items enable row level security;
alter table public.batches enable row level security;
alter table public.serial_numbers enable row level security;
alter table public.stock_transactions enable row level security;
alter table public.stock_transaction_lines enable row level security;

create policy item_categories_select on public.item_categories for select to authenticated
using ((select private.is_org_member(organization_id)));
create policy item_categories_manage on public.item_categories for all to authenticated
using ((select private.has_permission(organization_id, 'inventory.manage', null)))
with check ((select private.has_permission(organization_id, 'inventory.manage', null)));

create policy item_units_select on public.item_units for select to authenticated
using ((select private.is_org_member(organization_id)));
create policy item_units_manage on public.item_units for all to authenticated
using ((select private.has_permission(organization_id, 'inventory.manage', null)))
with check ((select private.has_permission(organization_id, 'inventory.manage', null)));

create policy items_select on public.items for select to authenticated
using ((select private.is_org_member(organization_id)));
create policy items_manage on public.items for all to authenticated
using ((select private.has_permission(organization_id, 'inventory.manage', null)))
with check ((select private.has_permission(organization_id, 'inventory.manage', null)));

create policy batches_select on public.batches for select to authenticated
using ((select private.is_org_member(organization_id)));
create policy batches_manage on public.batches for all to authenticated
using ((select private.has_permission(organization_id, 'inventory.manage', null)))
with check ((select private.has_permission(organization_id, 'inventory.manage', null)));

create policy serial_numbers_select on public.serial_numbers for select to authenticated
using ((select private.is_org_member(organization_id)));
create policy serial_numbers_manage on public.serial_numbers for all to authenticated
using ((select private.has_permission(organization_id, 'inventory.manage', null)))
with check ((select private.has_permission(organization_id, 'inventory.manage', null)));

create policy stock_transactions_select on public.stock_transactions for select to authenticated
using ((select private.has_permission(organization_id, 'inventory.read', factory_id)));
create policy stock_transactions_insert on public.stock_transactions for insert to authenticated
with check (
  (select private.has_permission(organization_id, 'inventory.transact', factory_id))
  and status = 'draft'
  and created_by = (select auth.uid())
);
create policy stock_transactions_update_draft on public.stock_transactions for update to authenticated
using (status = 'draft' and (select private.has_permission(organization_id, 'inventory.transact', factory_id)))
with check (status = 'draft' and (select private.has_permission(organization_id, 'inventory.transact', factory_id)));

create policy stock_lines_select on public.stock_transaction_lines for select to authenticated
using ((select private.has_permission(organization_id, 'inventory.read', null)));
create policy stock_lines_insert on public.stock_transaction_lines for insert to authenticated
with check (
  (select private.has_permission(organization_id, 'inventory.transact', null))
  and exists (
    select 1 from public.stock_transactions t
    where t.id = stock_transaction_id and t.organization_id = organization_id and t.status = 'draft'
  )
);
create policy stock_lines_update_draft on public.stock_transaction_lines for update to authenticated
using (
  (select private.has_permission(organization_id, 'inventory.transact', null))
  and exists (select 1 from public.stock_transactions t where t.id = stock_transaction_id and t.status = 'draft')
)
with check (
  (select private.has_permission(organization_id, 'inventory.transact', null))
  and exists (select 1 from public.stock_transactions t where t.id = stock_transaction_id and t.status = 'draft')
);
create policy stock_lines_delete_draft on public.stock_transaction_lines for delete to authenticated
using (
  (select private.has_permission(organization_id, 'inventory.transact', null))
  and exists (select 1 from public.stock_transactions t where t.id = stock_transaction_id and t.status = 'draft')
);

-- Explicit Data API grants; RLS remains authoritative.
grant select, insert, update, delete on public.item_categories to authenticated;
grant select, insert, update, delete on public.item_units to authenticated;
grant select, insert, update, delete on public.items to authenticated;
grant select, insert, update, delete on public.batches to authenticated;
grant select, insert, update, delete on public.serial_numbers to authenticated;
grant select, insert, update on public.stock_transactions to authenticated;
grant select, insert, update, delete on public.stock_transaction_lines to authenticated;
grant select on public.inventory_balances to authenticated;