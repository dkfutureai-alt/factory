-- FactoryOS sales and customer schema
-- Depends on 01_core.sql and 02_inventory.sql.
-- Financial status is derived from payment records. Logistics state is handed off to Dispatch/Trip workflows.

create type public.sales_order_status as enum ('draft','pending_approval','confirmed','production','ready','dispatched','delivered','closed','cancelled');
create type public.customer_payment_status as enum ('received','reversed','failed');

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  gstin text,
  city text,
  state text,
  country_code text not null default 'IN',
  credit_terms_days integer not null default 30 check (credit_terms_days >= 0),
  credit_limit numeric(18,2) not null default 0 check (credit_limit >= 0),
  account_owner_user_id uuid references auth.users(id) on delete set null,
  status public.entity_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  constraint customers_name_nonempty check (length(btrim(name)) > 0)
);

create table public.customer_contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete cascade,
  label text not null default 'Primary',
  contact_name text,
  business_phone text,
  business_email text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index customer_contacts_one_primary_idx
on public.customer_contacts (customer_id)
where is_primary;

create table public.customer_delivery_addresses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete cascade,
  code text not null,
  line1 text not null,
  line2 text,
  city text not null,
  state text not null,
  postal_code text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, code)
);

create unique index customer_addresses_one_default_idx
on public.customer_delivery_addresses (customer_id)
where is_default;

create table public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null references public.factories(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  order_number text not null,
  order_date date not null default current_date,
  requested_delivery_date date,
  status public.sales_order_status not null default 'draft',
  currency_code text not null default 'INR',
  customer_po_number text,
  payment_terms text,
  delivery_method text,
  ship_to_address_id uuid references public.customer_delivery_addresses(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  confirmed_by uuid references auth.users(id) on delete set null,
  confirmed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, order_number),
  check ((status in ('confirmed','production','ready','dispatched','delivered','closed') and confirmed_at is not null) or status not in ('confirmed','production','ready','dispatched','delivered','closed'))
);

create table public.sales_order_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  sales_order_id uuid not null references public.sales_orders(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete restrict,
  ordered_quantity numeric(18,4) not null check (ordered_quantity > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  tax_rate numeric(7,4) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  note text,
  created_at timestamptz not null default now(),
  unique (sales_order_id, item_id)
);

create table public.customer_payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  sales_order_id uuid references public.sales_orders(id) on delete restrict,
  payment_reference text not null,
  received_at timestamptz not null default now(),
  amount numeric(18,2) not null check (amount > 0),
  method text not null,
  status public.customer_payment_status not null default 'received',
  external_reference text,
  created_by uuid references auth.users(id) on delete set null,
  reversed_at timestamptz,
  reversal_reason text,
  created_at timestamptz not null default now(),
  unique (organization_id, payment_reference),
  check ((status = 'reversed' and reversed_at is not null) or status <> 'reversed')
);

create view public.sales_order_financials with (security_invoker = true) as
select
  so.organization_id,
  so.id as sales_order_id,
  so.customer_id,
  coalesce(sum(sol.ordered_quantity * sol.unit_price), 0::numeric) as order_value,
  coalesce((
    select sum(cp.amount) from public.customer_payments cp
    where cp.sales_order_id = so.id and cp.status = 'received'
  ), 0::numeric) as amount_received,
  greatest(
    coalesce(sum(sol.ordered_quantity * sol.unit_price), 0::numeric) -
    coalesce((select sum(cp.amount) from public.customer_payments cp where cp.sales_order_id = so.id and cp.status = 'received'), 0::numeric),
    0::numeric
  ) as amount_outstanding
from public.sales_orders so
left join public.sales_order_lines sol on sol.sales_order_id = so.id
group by so.organization_id, so.id, so.customer_id;

create index customers_org_status_idx on public.customers (organization_id, status);
create index sales_orders_org_factory_status_idx on public.sales_orders (organization_id, factory_id, status);
create index sales_orders_customer_date_idx on public.sales_orders (customer_id, order_date desc);
create index sales_order_lines_order_idx on public.sales_order_lines (sales_order_id);
create index customer_payments_customer_date_idx on public.customer_payments (customer_id, received_at desc);
create index customer_payments_order_idx on public.customer_payments (sales_order_id) where sales_order_id is not null;

create trigger customers_set_updated_at before update on public.customers for each row execute function private.set_updated_at();
create trigger customer_contacts_set_updated_at before update on public.customer_contacts for each row execute function private.set_updated_at();
create trigger customer_delivery_addresses_set_updated_at before update on public.customer_delivery_addresses for each row execute function private.set_updated_at();
create trigger sales_orders_set_updated_at before update on public.sales_orders for each row execute function private.set_updated_at();

alter table public.customers enable row level security;
alter table public.customer_contacts enable row level security;
alter table public.customer_delivery_addresses enable row level security;
alter table public.sales_orders enable row level security;
alter table public.sales_order_lines enable row level security;
alter table public.customer_payments enable row level security;

create policy customers_select on public.customers for select to authenticated
using ((select private.has_permission(organization_id, 'sales.read', null)));
create policy customers_manage on public.customers for all to authenticated
using ((select private.has_permission(organization_id, 'sales.manage', null)))
with check ((select private.has_permission(organization_id, 'sales.manage', null)));

create policy customer_contacts_select on public.customer_contacts for select to authenticated
using ((select private.has_permission(organization_id, 'sales.read', null)));
create policy customer_contacts_manage on public.customer_contacts for all to authenticated
using ((select private.has_permission(organization_id, 'sales.manage', null)))
with check ((select private.has_permission(organization_id, 'sales.manage', null)));

create policy customer_addresses_select on public.customer_delivery_addresses for select to authenticated
using ((select private.has_permission(organization_id, 'sales.read', null)));
create policy customer_addresses_manage on public.customer_delivery_addresses for all to authenticated
using ((select private.has_permission(organization_id, 'sales.manage', null)))
with check ((select private.has_permission(organization_id, 'sales.manage', null)));

create policy sales_orders_select on public.sales_orders for select to authenticated
using ((select private.has_permission(organization_id, 'sales.read', factory_id)));
create policy sales_orders_manage on public.sales_orders for all to authenticated
using ((select private.has_permission(organization_id, 'sales.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'sales.manage', factory_id)));

create policy sales_order_lines_select on public.sales_order_lines for select to authenticated
using ((select private.has_permission(organization_id, 'sales.read', null)));
create policy sales_order_lines_manage on public.sales_order_lines for all to authenticated
using ((select private.has_permission(organization_id, 'sales.manage', null)))
with check ((select private.has_permission(organization_id, 'sales.manage', null)));

create policy customer_payments_select on public.customer_payments for select to authenticated
using ((select private.has_permission(organization_id, 'sales.read', null)));
create policy customer_payments_manage on public.customer_payments for all to authenticated
using ((select private.has_permission(organization_id, 'sales.manage', null)))
with check ((select private.has_permission(organization_id, 'sales.manage', null)));

grant select on public.customers, public.customer_contacts, public.customer_delivery_addresses, public.sales_orders, public.sales_order_lines, public.customer_payments, public.sales_order_financials to authenticated;
grant insert, update, delete on public.customers, public.customer_contacts, public.customer_delivery_addresses, public.sales_orders, public.sales_order_lines, public.customer_payments to authenticated;

create or replace function private.validate_customer_child_reference()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  customer_org uuid;
begin
  select organization_id into customer_org from public.customers where id=new.customer_id;
  if customer_org is null then raise exception 'invalid customer reference'; end if;
  if new.organization_id <> customer_org then raise exception 'customer child organization mismatch'; end if;
  return new;
end;
$$;

create trigger customer_contacts_validate_refs before insert or update on public.customer_contacts
for each row execute function private.validate_customer_child_reference();
create trigger customer_addresses_validate_refs before insert or update on public.customer_delivery_addresses
for each row execute function private.validate_customer_child_reference();

create or replace function private.validate_sales_order_references()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  factory_org uuid;
  customer_org uuid;
  address_org uuid;
  address_customer uuid;
begin
  select organization_id into factory_org from public.factories where id=new.factory_id;
  select organization_id into customer_org from public.customers where id=new.customer_id;
  if factory_org is null or customer_org is null then raise exception 'invalid sales order reference'; end if;
  if new.organization_id <> factory_org or new.organization_id <> customer_org then raise exception 'sales order organization mismatch'; end if;
  if new.ship_to_address_id is not null then
    select organization_id, customer_id into address_org, address_customer from public.customer_delivery_addresses where id=new.ship_to_address_id;
    if address_org is distinct from new.organization_id or address_customer is distinct from new.customer_id then
      raise exception 'sales order ship-to address mismatch';
    end if;
  end if;
  return new;
end;
$$;

create trigger sales_orders_validate_refs before insert or update on public.sales_orders
for each row execute function private.validate_sales_order_references();

create or replace function private.validate_sales_order_line_reference()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  order_org uuid;
  order_status public.sales_order_status;
  item_org uuid;
begin
  select organization_id, status into order_org, order_status from public.sales_orders where id=new.sales_order_id;
  select organization_id into item_org from public.items where id=new.item_id;
  if order_org is null or item_org is null then raise exception 'invalid sales order line reference'; end if;
  if new.organization_id <> order_org or new.organization_id <> item_org then raise exception 'sales order line organization mismatch'; end if;
  if order_status not in ('draft','pending_approval') then raise exception 'sales order lines may change only before confirmation'; end if;
  return new;
end;
$$;

create trigger sales_order_lines_validate_refs before insert or update on public.sales_order_lines
for each row execute function private.validate_sales_order_line_reference();

create or replace function private.guard_sales_order_line_delete()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  order_status public.sales_order_status;
begin
  select status into order_status from public.sales_orders where id=old.sales_order_id;
  if order_status not in ('draft','pending_approval') then raise exception 'sales order lines may change only before confirmation'; end if;
  return old;
end;
$$;

create trigger sales_order_lines_guard_delete before delete on public.sales_order_lines
for each row execute function private.guard_sales_order_line_delete();

create or replace function private.validate_customer_payment_reference()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  customer_org uuid;
  order_org uuid;
  order_customer uuid;
begin
  select organization_id into customer_org from public.customers where id=new.customer_id;
  if customer_org is null or customer_org <> new.organization_id then raise exception 'payment customer organization mismatch'; end if;
  if new.sales_order_id is not null then
    select organization_id, customer_id into order_org, order_customer from public.sales_orders where id=new.sales_order_id;
    if order_org is distinct from new.organization_id or order_customer is distinct from new.customer_id then
      raise exception 'payment sales order/customer mismatch';
    end if;
  end if;
  return new;
end;
$$;

create trigger customer_payments_validate_refs before insert or update on public.customer_payments
for each row execute function private.validate_customer_payment_reference();

create or replace function private.guard_received_payment_delete()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if old.status = 'received' then raise exception 'received payment cannot be deleted; reverse it instead'; end if;
  return old;
end;
$$;

create trigger customer_payments_guard_delete before delete on public.customer_payments
for each row execute function private.guard_received_payment_delete();
