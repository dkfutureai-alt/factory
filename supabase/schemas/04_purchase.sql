-- FactoryOS purchase and goods-receipt schema
-- Depends on 01_core.sql and 02_inventory.sql.
-- Goods receipts never mutate stock directly; accepted quantities must flow through a purchase_receipt stock transaction.

create type public.purchase_order_status as enum ('draft','pending_approval','approved','part_received','received','cancelled');
create type public.goods_receipt_status as enum ('draft','checked','posted','rejected','cancelled');

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  gstin text,
  contact_name text,
  phone text,
  email text,
  payment_terms_days integer not null default 30 check (payment_terms_days >= 0),
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  constraint suppliers_name_nonempty check (length(btrim(name)) > 0)
);

create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  order_number text not null,
  order_date date not null default current_date,
  expected_delivery_date date,
  status public.purchase_order_status not null default 'draft',
  currency_code text not null default 'INR',
  payment_terms text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, order_number),
  check ((status in ('approved','part_received','received') and approved_at is not null) or status not in ('approved','part_received','received'))
);

create table public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete restrict,
  ordered_quantity numeric(18,4) not null check (ordered_quantity > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  tax_rate numeric(7,4) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  note text,
  created_at timestamptz not null default now(),
  unique (purchase_order_id, item_id)
);

create table public.goods_receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  grn_number text not null,
  status public.goods_receipt_status not null default 'draft',
  received_at timestamptz not null default now(),
  supplier_invoice_number text,
  supplier_delivery_note text,
  stock_transaction_id uuid references public.stock_transactions(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  checked_by uuid references auth.users(id) on delete set null,
  checked_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, grn_number),
  unique (organization_id, stock_transaction_id),
  check ((status = 'posted' and stock_transaction_id is not null and checked_at is not null) or status <> 'posted')
);

create table public.goods_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  goods_receipt_id uuid not null references public.goods_receipts(id) on delete cascade,
  purchase_order_line_id uuid not null references public.purchase_order_lines(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  received_quantity numeric(18,4) not null check (received_quantity > 0),
  accepted_quantity numeric(18,4) not null default 0 check (accepted_quantity >= 0),
  rejected_quantity numeric(18,4) not null default 0 check (rejected_quantity >= 0),
  supplier_batch_number text,
  note text,
  created_at timestamptz not null default now(),
  unique (goods_receipt_id, purchase_order_line_id),
  check (accepted_quantity + rejected_quantity <= received_quantity)
);

create view public.purchase_order_line_progress with (security_invoker = true) as
select
  pol.organization_id,
  pol.purchase_order_id,
  pol.id as purchase_order_line_id,
  pol.item_id,
  pol.ordered_quantity,
  coalesce(sum(grl.accepted_quantity) filter (where gr.status = 'posted'), 0::numeric) as received_quantity,
  greatest(pol.ordered_quantity - coalesce(sum(grl.accepted_quantity) filter (where gr.status = 'posted'), 0::numeric), 0::numeric) as pending_quantity,
  pol.unit_price,
  pol.ordered_quantity * pol.unit_price as line_value,
  coalesce(sum(grl.accepted_quantity) filter (where gr.status = 'posted'), 0::numeric) * pol.unit_price as received_value
from public.purchase_order_lines pol
left join public.goods_receipt_lines grl on grl.purchase_order_line_id = pol.id
left join public.goods_receipts gr on gr.id = grl.goods_receipt_id
group by pol.organization_id, pol.purchase_order_id, pol.id, pol.item_id, pol.ordered_quantity, pol.unit_price;

create index suppliers_org_status_idx on public.suppliers (organization_id, status);
create index purchase_orders_org_factory_status_idx on public.purchase_orders (organization_id, factory_id, status);
create index purchase_orders_org_expected_idx on public.purchase_orders (organization_id, expected_delivery_date) where expected_delivery_date is not null;
create index purchase_order_lines_po_idx on public.purchase_order_lines (purchase_order_id);
create index goods_receipts_org_po_idx on public.goods_receipts (organization_id, purchase_order_id, received_at desc);
create index goods_receipt_lines_grn_idx on public.goods_receipt_lines (goods_receipt_id);

create trigger suppliers_set_updated_at before update on public.suppliers for each row execute function private.set_updated_at();
create trigger purchase_orders_set_updated_at before update on public.purchase_orders for each row execute function private.set_updated_at();
create trigger goods_receipts_set_updated_at before update on public.goods_receipts for each row execute function private.set_updated_at();

alter table public.suppliers enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;
alter table public.goods_receipts enable row level security;
alter table public.goods_receipt_lines enable row level security;

create policy suppliers_select on public.suppliers for select to authenticated
using ((select private.has_permission(organization_id, 'purchase.read', null)));
create policy suppliers_manage on public.suppliers for all to authenticated
using ((select private.has_permission(organization_id, 'purchase.manage', null)))
with check ((select private.has_permission(organization_id, 'purchase.manage', null)));

create policy purchase_orders_select on public.purchase_orders for select to authenticated
using ((select private.has_permission(organization_id, 'purchase.read', factory_id)));
create policy purchase_orders_manage on public.purchase_orders for all to authenticated
using ((select private.has_permission(organization_id, 'purchase.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'purchase.manage', factory_id)));

create policy purchase_order_lines_select on public.purchase_order_lines for select to authenticated
using ((select private.has_permission(organization_id, 'purchase.read', null)));
create policy purchase_order_lines_manage on public.purchase_order_lines for all to authenticated
using ((select private.has_permission(organization_id, 'purchase.manage', null)))
with check ((select private.has_permission(organization_id, 'purchase.manage', null)));

create policy goods_receipts_select on public.goods_receipts for select to authenticated
using ((select private.has_permission(organization_id, 'purchase.read', factory_id)) or (select private.has_permission(organization_id, 'inventory.read', factory_id)));
create policy goods_receipts_manage on public.goods_receipts for all to authenticated
using ((select private.has_permission(organization_id, 'purchase.manage', factory_id)) or (select private.has_permission(organization_id, 'inventory.receive', factory_id)))
with check ((select private.has_permission(organization_id, 'purchase.manage', factory_id)) or (select private.has_permission(organization_id, 'inventory.receive', factory_id)));

create policy goods_receipt_lines_select on public.goods_receipt_lines for select to authenticated
using ((select private.has_permission(organization_id, 'purchase.read', null)) or (select private.has_permission(organization_id, 'inventory.read', null)));
create policy goods_receipt_lines_manage on public.goods_receipt_lines for all to authenticated
using ((select private.has_permission(organization_id, 'purchase.manage', null)) or (select private.has_permission(organization_id, 'inventory.receive', null)))
with check ((select private.has_permission(organization_id, 'purchase.manage', null)) or (select private.has_permission(organization_id, 'inventory.receive', null)));

grant select on public.suppliers, public.purchase_orders, public.purchase_order_lines, public.goods_receipts, public.goods_receipt_lines, public.purchase_order_line_progress to authenticated;
grant insert, update, delete on public.suppliers, public.purchase_orders, public.purchase_order_lines, public.goods_receipts, public.goods_receipt_lines to authenticated;

-- Cross-tenant/reference integrity is enforced before writes, not trusted to UI filtering.
create or replace function private.validate_purchase_order_references()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  factory_org uuid;
  supplier_org uuid;
begin
  select organization_id into factory_org from public.factories where id=new.factory_id;
  select organization_id into supplier_org from public.suppliers where id=new.supplier_id;
  if factory_org is null or supplier_org is null then raise exception 'invalid purchase order reference'; end if;
  if new.organization_id <> factory_org or new.organization_id <> supplier_org then
    raise exception 'purchase order organization mismatch';
  end if;
  return new;
end;
$$;

create trigger purchase_orders_validate_refs
before insert or update on public.purchase_orders
for each row execute function private.validate_purchase_order_references();

create or replace function private.validate_purchase_order_line_references()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  po_org uuid;
  item_org uuid;
begin
  select organization_id into po_org from public.purchase_orders where id=new.purchase_order_id;
  select organization_id into item_org from public.items where id=new.item_id;
  if po_org is null or item_org is null then raise exception 'invalid purchase order line reference'; end if;
  if new.organization_id <> po_org or new.organization_id <> item_org then
    raise exception 'purchase order line organization mismatch';
  end if;
  return new;
end;
$$;

create trigger purchase_order_lines_validate_refs
before insert or update on public.purchase_order_lines
for each row execute function private.validate_purchase_order_line_references();

create or replace function private.validate_goods_receipt_references()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  po_org uuid;
  po_supplier uuid;
  supplier_org uuid;
  factory_org uuid;
  warehouse_org uuid;
  warehouse_factory uuid;
  tx_org uuid;
  tx_type public.stock_transaction_type;
begin
  select organization_id, supplier_id into po_org, po_supplier from public.purchase_orders where id=new.purchase_order_id;
  select organization_id into supplier_org from public.suppliers where id=new.supplier_id;
  select organization_id into factory_org from public.factories where id=new.factory_id;
  select organization_id, factory_id into warehouse_org, warehouse_factory from public.warehouses where id=new.warehouse_id;
  if po_org is null or supplier_org is null or factory_org is null or warehouse_org is null then
    raise exception 'invalid goods receipt reference';
  end if;
  if new.organization_id <> po_org or new.organization_id <> supplier_org or new.organization_id <> factory_org or new.organization_id <> warehouse_org then
    raise exception 'goods receipt organization mismatch';
  end if;
  if new.supplier_id <> po_supplier then raise exception 'goods receipt supplier does not match purchase order'; end if;
  if warehouse_factory is not null and warehouse_factory <> new.factory_id then raise exception 'goods receipt warehouse belongs to another factory'; end if;
  if new.stock_transaction_id is not null then
    select organization_id, transaction_type into tx_org, tx_type from public.stock_transactions where id=new.stock_transaction_id;
    if tx_org is distinct from new.organization_id or tx_type is distinct from 'purchase_receipt'::public.stock_transaction_type then
      raise exception 'goods receipt stock transaction must be same-tenant purchase receipt';
    end if;
  end if;
  return new;
end;
$$;

create trigger goods_receipts_validate_refs
before insert or update on public.goods_receipts
for each row execute function private.validate_goods_receipt_references();

create or replace function private.validate_goods_receipt_line_references()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  gr_org uuid;
  gr_po uuid;
  gr_status public.goods_receipt_status;
  pol_org uuid;
  pol_po uuid;
  pol_item uuid;
  item_org uuid;
begin
  select organization_id, purchase_order_id, status into gr_org, gr_po, gr_status from public.goods_receipts where id=new.goods_receipt_id;
  select organization_id, purchase_order_id, item_id into pol_org, pol_po, pol_item from public.purchase_order_lines where id=new.purchase_order_line_id;
  select organization_id into item_org from public.items where id=new.item_id;
  if gr_org is null or pol_org is null or item_org is null then raise exception 'invalid goods receipt line reference'; end if;
  if gr_status <> 'draft' then raise exception 'goods receipt lines may change only while receipt is draft'; end if;
  if new.organization_id <> gr_org or new.organization_id <> pol_org or new.organization_id <> item_org then
    raise exception 'goods receipt line organization mismatch';
  end if;
  if pol_po <> gr_po then raise exception 'goods receipt line purchase order mismatch'; end if;
  if pol_item <> new.item_id then raise exception 'goods receipt line item mismatch'; end if;
  return new;
end;
$$;

create trigger goods_receipt_lines_validate_refs
before insert or update on public.goods_receipt_lines
for each row execute function private.validate_goods_receipt_line_references();

create or replace function private.guard_goods_receipt_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status in ('posted','cancelled') then raise exception 'finalized goods receipt is immutable'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create trigger goods_receipts_guard_finalized
before update or delete on public.goods_receipts
for each row execute function private.guard_goods_receipt_mutation();

create or replace function private.guard_purchase_order_line_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  po_status public.purchase_order_status;
  target_po uuid;
begin
  target_po := case when tg_op='DELETE' then old.purchase_order_id else new.purchase_order_id end;
  select status into po_status from public.purchase_orders where id=target_po;
  if po_status not in ('draft','pending_approval') then
    raise exception 'purchase order lines may change only before approval';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create trigger purchase_order_lines_guard_status
before insert or update or delete on public.purchase_order_lines
for each row execute function private.guard_purchase_order_line_mutation();

create or replace function private.guard_goods_receipt_line_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  receipt_status public.goods_receipt_status;
  target_receipt uuid;
begin
  target_receipt := case when tg_op='DELETE' then old.goods_receipt_id else new.goods_receipt_id end;
  select status into receipt_status from public.goods_receipts where id=target_receipt;
  if receipt_status <> 'draft' then raise exception 'goods receipt lines may change only while receipt is draft'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create trigger goods_receipt_lines_guard_status
before insert or update or delete on public.goods_receipt_lines
for each row execute function private.guard_goods_receipt_line_mutation();
