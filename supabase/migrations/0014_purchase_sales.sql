begin;

create table public.business_partners (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  partner_code text not null check (partner_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name text not null check (char_length(trim(name)) between 2 and 160),
  partner_type text not null check (partner_type in ('supplier','customer','both')),
  tax_id text,
  contact_person text,
  email text,
  phone text,
  address_line1 text,
  city text,
  state text,
  postal_code text,
  country_code text not null default 'IN' check (country_code ~ '^[A-Z]{2}$'),
  credit_days integer not null default 0 check (credit_days between 0 and 365),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, partner_code),
  unique (id, organization_id)
);

create table public.purchase_requisitions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  requisition_no text not null default ('PR-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  request_date date not null default current_date,
  required_date date,
  purpose text,
  status text not null default 'submitted' check (status in ('draft','submitted','approved','rejected','converted','cancelled')),
  requested_by_employee_id uuid,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  decision_note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, requisition_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (requested_by_employee_id, organization_id) references public.employees(id, organization_id) on delete restrict,
  check (required_date is null or required_date >= request_date),
  check ((status = 'approved' and approved_at is not null) or status <> 'approved')
);

create table public.purchase_requisition_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  requisition_id uuid not null,
  item_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  estimated_unit_cost numeric(18,4) check (estimated_unit_cost is null or estimated_unit_cost >= 0),
  notes text,
  created_at timestamptz not null default now(),
  unique (requisition_id, item_id),
  unique (id, organization_id),
  foreign key (requisition_id, organization_id) references public.purchase_requisitions(id, organization_id) on delete cascade,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict
);

create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  purchase_order_no text not null default ('PO-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  supplier_id uuid not null,
  requisition_id uuid,
  order_date date not null default current_date,
  expected_date date,
  currency_code text not null default 'INR' check (currency_code ~ '^[A-Z]{3}$'),
  status text not null default 'draft' check (status in ('draft','approved','sent','partially_received','received','cancelled')),
  notes text,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, purchase_order_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (supplier_id, organization_id) references public.business_partners(id, organization_id) on delete restrict,
  foreign key (requisition_id, factory_id) references public.purchase_requisitions(id, factory_id) on delete restrict,
  check (expected_date is null or expected_date >= order_date),
  check ((status in ('approved','sent','partially_received','received') and approved_at is not null) or status in ('draft','cancelled'))
);

create table public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  purchase_order_id uuid not null,
  item_id uuid not null,
  ordered_quantity numeric(18,4) not null check (ordered_quantity > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  tax_rate numeric(8,4) not null default 0 check (tax_rate between 0 and 100),
  received_quantity numeric(18,4) not null default 0 check (received_quantity >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (purchase_order_id, item_id),
  unique (id, organization_id),
  foreign key (purchase_order_id, organization_id) references public.purchase_orders(id, organization_id) on delete cascade,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  check (received_quantity <= ordered_quantity)
);

create table public.goods_receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  goods_receipt_no text not null default ('GRN-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  purchase_order_id uuid not null,
  received_location_id uuid not null,
  released_location_id uuid,
  received_at timestamptz not null default now(),
  released_at timestamptz,
  status text not null default 'received' check (status in ('received','quality_pending','quality_passed','quality_hold','released','cancelled')),
  received_by uuid references auth.users(id) on delete set null,
  released_by uuid references auth.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, goods_receipt_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (purchase_order_id, factory_id) references public.purchase_orders(id, factory_id) on delete restrict,
  foreign key (received_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (released_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  check ((status = 'released' and released_location_id is not null and released_at is not null) or status <> 'released')
);

create table public.goods_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  goods_receipt_id uuid not null,
  purchase_order_line_id uuid not null,
  item_id uuid not null,
  quantity_received numeric(18,4) not null check (quantity_received > 0),
  unit_cost numeric(18,4) not null check (unit_cost >= 0),
  lot_batch_no text,
  quality_required boolean not null default false,
  inventory_receive_transaction_id uuid not null unique references public.inventory_transactions(id) on delete restrict,
  quality_inspection_id uuid unique references public.quality_inspections(id) on delete restrict,
  inventory_release_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (goods_receipt_id, purchase_order_line_id),
  unique (id, organization_id),
  foreign key (goods_receipt_id, organization_id) references public.goods_receipts(id, organization_id) on delete restrict,
  foreign key (purchase_order_line_id, organization_id) references public.purchase_order_lines(id, organization_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  check ((quality_required and quality_inspection_id is not null) or not quality_required)
);

create table public.supplier_invoices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  invoice_no text not null check (char_length(trim(invoice_no)) between 2 and 80),
  supplier_id uuid not null,
  purchase_order_id uuid not null unique,
  invoice_date date not null default current_date,
  due_date date not null,
  subtotal numeric(18,2) not null check (subtotal >= 0),
  tax_amount numeric(18,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(18,2) not null check (total_amount >= 0),
  status text not null default 'posted' check (status in ('draft','posted','partially_paid','paid','cancelled')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, supplier_id, invoice_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (supplier_id, organization_id) references public.business_partners(id, organization_id) on delete restrict,
  foreign key (purchase_order_id, factory_id) references public.purchase_orders(id, factory_id) on delete restrict,
  check (due_date >= invoice_date),
  check (total_amount = subtotal + tax_amount)
);

create table public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  supplier_invoice_id uuid not null,
  payment_no text not null default ('SPAY-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  amount numeric(18,2) not null check (amount > 0),
  payment_method text not null default 'bank_transfer' check (payment_method in ('cash','bank_transfer','upi','cheque','card','other')),
  reference_no text,
  paid_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, payment_no),
  foreign key (supplier_invoice_id, factory_id) references public.supplier_invoices(id, factory_id) on delete restrict,
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict
);

create table public.quotations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  quotation_no text not null default ('QT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  customer_id uuid not null,
  quotation_date date not null default current_date,
  valid_until date not null,
  currency_code text not null default 'INR' check (currency_code ~ '^[A-Z]{3}$'),
  status text not null default 'draft' check (status in ('draft','sent','accepted','rejected','expired','converted','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, quotation_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (customer_id, organization_id) references public.business_partners(id, organization_id) on delete restrict,
  check (valid_until >= quotation_date)
);

create table public.quotation_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  quotation_id uuid not null,
  item_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  tax_rate numeric(8,4) not null default 0 check (tax_rate between 0 and 100),
  notes text,
  created_at timestamptz not null default now(),
  unique (quotation_id, item_id),
  unique (id, organization_id),
  foreign key (quotation_id, organization_id) references public.quotations(id, organization_id) on delete cascade,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict
);

create table public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  sales_order_no text not null default ('SO-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  customer_id uuid not null,
  quotation_id uuid unique,
  order_date date not null default current_date,
  requested_delivery_date date,
  currency_code text not null default 'INR' check (currency_code ~ '^[A-Z]{3}$'),
  status text not null default 'confirmed' check (status in ('draft','confirmed','allocated','dispatch_ready','dispatched','completed','cancelled')),
  dispatch_ready_at timestamptz,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, sales_order_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (customer_id, organization_id) references public.business_partners(id, organization_id) on delete restrict,
  foreign key (quotation_id, factory_id) references public.quotations(id, factory_id) on delete restrict,
  check (requested_delivery_date is null or requested_delivery_date >= order_date),
  check ((status = 'dispatch_ready' and dispatch_ready_at is not null) or status <> 'dispatch_ready')
);

create table public.sales_order_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  sales_order_id uuid not null,
  item_id uuid not null,
  ordered_quantity numeric(18,4) not null check (ordered_quantity > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  tax_rate numeric(8,4) not null default 0 check (tax_rate between 0 and 100),
  allocated_quantity numeric(18,4) not null default 0 check (allocated_quantity >= 0),
  dispatched_quantity numeric(18,4) not null default 0 check (dispatched_quantity >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (sales_order_id, item_id),
  unique (id, organization_id),
  foreign key (sales_order_id, organization_id) references public.sales_orders(id, organization_id) on delete cascade,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  check (allocated_quantity <= ordered_quantity),
  check (dispatched_quantity <= ordered_quantity)
);

create table public.sales_allocations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  sales_order_id uuid not null,
  sales_order_line_id uuid not null,
  item_id uuid not null,
  location_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  status text not null default 'allocated' check (status in ('allocated','released','consumed')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (sales_order_line_id, location_id, status),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (sales_order_id, factory_id) references public.sales_orders(id, factory_id) on delete restrict,
  foreign key (sales_order_line_id, organization_id) references public.sales_order_lines(id, organization_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict
);

create table public.customer_invoices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  invoice_no text not null default ('CINV-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  customer_id uuid not null,
  sales_order_id uuid not null unique,
  invoice_date date not null default current_date,
  due_date date not null,
  subtotal numeric(18,2) not null check (subtotal >= 0),
  tax_amount numeric(18,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(18,2) not null check (total_amount >= 0),
  status text not null default 'posted' check (status in ('draft','posted','partially_paid','paid','cancelled')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, invoice_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (customer_id, organization_id) references public.business_partners(id, organization_id) on delete restrict,
  foreign key (sales_order_id, factory_id) references public.sales_orders(id, factory_id) on delete restrict,
  check (due_date >= invoice_date),
  check (total_amount = subtotal + tax_amount)
);

create table public.customer_payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  customer_invoice_id uuid not null,
  payment_no text not null default ('CPAY-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  amount numeric(18,2) not null check (amount > 0),
  payment_method text not null default 'bank_transfer' check (payment_method in ('cash','bank_transfer','upi','cheque','card','other')),
  reference_no text,
  paid_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, payment_no),
  foreign key (customer_invoice_id, factory_id) references public.customer_invoices(id, factory_id) on delete restrict,
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict
);

create index business_partners_org_type_idx on public.business_partners(organization_id, partner_type, is_active);
create index purchase_requisitions_factory_status_idx on public.purchase_requisitions(factory_id, status, request_date desc);
create index purchase_orders_factory_status_idx on public.purchase_orders(factory_id, status, order_date desc);
create index goods_receipts_factory_status_idx on public.goods_receipts(factory_id, status, received_at desc);
create index supplier_invoices_factory_status_idx on public.supplier_invoices(factory_id, status, due_date);
create index quotations_factory_status_idx on public.quotations(factory_id, status, quotation_date desc);
create index sales_orders_factory_status_idx on public.sales_orders(factory_id, status, order_date desc);
create index sales_allocations_item_location_idx on public.sales_allocations(item_id, location_id, status);
create index customer_invoices_factory_status_idx on public.customer_invoices(factory_id, status, due_date);

create trigger business_partners_set_updated_at before update on public.business_partners for each row execute function public.set_updated_at();
create trigger purchase_requisitions_set_updated_at before update on public.purchase_requisitions for each row execute function public.set_updated_at();
create trigger purchase_orders_set_updated_at before update on public.purchase_orders for each row execute function public.set_updated_at();
create trigger purchase_order_lines_set_updated_at before update on public.purchase_order_lines for each row execute function public.set_updated_at();
create trigger goods_receipts_set_updated_at before update on public.goods_receipts for each row execute function public.set_updated_at();
create trigger supplier_invoices_set_updated_at before update on public.supplier_invoices for each row execute function public.set_updated_at();
create trigger quotations_set_updated_at before update on public.quotations for each row execute function public.set_updated_at();
create trigger sales_orders_set_updated_at before update on public.sales_orders for each row execute function public.set_updated_at();
create trigger sales_order_lines_set_updated_at before update on public.sales_order_lines for each row execute function public.set_updated_at();
create trigger sales_allocations_set_updated_at before update on public.sales_allocations for each row execute function public.set_updated_at();
create trigger customer_invoices_set_updated_at before update on public.customer_invoices for each row execute function public.set_updated_at();

create or replace function public.can_view_commercial_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_view_inventory_factory(target_factory_id);
$$;
grant execute on function public.can_view_commercial_factory(uuid) to authenticated;

create or replace function public.can_operate_commercial_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_manage_factory(target_factory_id)
    or exists (
      select 1
      from public.factory_members fm
      join public.organization_members om on om.organization_id=fm.organization_id and om.user_id=fm.user_id and om.is_active
      where fm.factory_id=target_factory_id and fm.user_id=auth.uid() and fm.is_active and om.role='supervisor'
    );
$$;
grant execute on function public.can_operate_commercial_factory(uuid) to authenticated;

alter table public.business_partners enable row level security;
alter table public.purchase_requisitions enable row level security;
alter table public.purchase_requisition_lines enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;
alter table public.goods_receipts enable row level security;
alter table public.goods_receipt_lines enable row level security;
alter table public.supplier_invoices enable row level security;
alter table public.supplier_payments enable row level security;
alter table public.quotations enable row level security;
alter table public.quotation_lines enable row level security;
alter table public.sales_orders enable row level security;
alter table public.sales_order_lines enable row level security;
alter table public.sales_allocations enable row level security;
alter table public.customer_invoices enable row level security;
alter table public.customer_payments enable row level security;

grant select,insert,update on public.business_partners to authenticated;
grant select on public.purchase_requisitions,public.purchase_requisition_lines,public.purchase_orders,public.purchase_order_lines,public.goods_receipts,public.goods_receipt_lines,public.supplier_invoices,public.supplier_payments,public.quotations,public.quotation_lines,public.sales_orders,public.sales_order_lines,public.sales_allocations,public.customer_invoices,public.customer_payments to authenticated;

create policy business_partners_select on public.business_partners for select to authenticated using (public.is_org_member(organization_id));
create policy business_partners_manage on public.business_partners for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id,array['org_admin','factory_manager']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id,array['org_admin','factory_manager']::public.app_role[]));

create policy purchase_requisitions_select on public.purchase_requisitions for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy purchase_requisition_lines_select on public.purchase_requisition_lines for select to authenticated using (exists (select 1 from public.purchase_requisitions pr where pr.id=requisition_id and public.can_view_commercial_factory(pr.factory_id)));
create policy purchase_orders_select on public.purchase_orders for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy purchase_order_lines_select on public.purchase_order_lines for select to authenticated using (exists (select 1 from public.purchase_orders po where po.id=purchase_order_id and public.can_view_commercial_factory(po.factory_id)));
create policy goods_receipts_select on public.goods_receipts for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy goods_receipt_lines_select on public.goods_receipt_lines for select to authenticated using (exists (select 1 from public.goods_receipts gr where gr.id=goods_receipt_id and public.can_view_commercial_factory(gr.factory_id)));
create policy supplier_invoices_select on public.supplier_invoices for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy supplier_payments_select on public.supplier_payments for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy quotations_select on public.quotations for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy quotation_lines_select on public.quotation_lines for select to authenticated using (exists (select 1 from public.quotations q where q.id=quotation_id and public.can_view_commercial_factory(q.factory_id)));
create policy sales_orders_select on public.sales_orders for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy sales_order_lines_select on public.sales_order_lines for select to authenticated using (exists (select 1 from public.sales_orders so where so.id=sales_order_id and public.can_view_commercial_factory(so.factory_id)));
create policy sales_allocations_select on public.sales_allocations for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy customer_invoices_select on public.customer_invoices for select to authenticated using (public.can_view_commercial_factory(factory_id));
create policy customer_payments_select on public.customer_payments for select to authenticated using (public.can_view_commercial_factory(factory_id));

create or replace function public.prevent_commercial_payment_change()
returns trigger language plpgsql set search_path=public as $$ begin raise exception 'Commercial payment records are immutable'; end; $$;
revoke all on function public.prevent_commercial_payment_change() from public;
create trigger supplier_payments_immutable before update or delete on public.supplier_payments for each row execute function public.prevent_commercial_payment_change();
create trigger customer_payments_immutable before update or delete on public.customer_payments for each row execute function public.prevent_commercial_payment_change();

create or replace function public.audit_commercial_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_factory uuid; v_id text; v_meta jsonb;
begin
  v_org:=coalesce(new.organization_id,old.organization_id);
  if tg_table_name <> 'business_partners' then v_factory:=coalesce(new.factory_id,old.factory_id); end if;
  v_id:=coalesce(new.id,old.id)::text;
  if tg_op='INSERT' then v_meta:=jsonb_build_object('after',to_jsonb(new));
  elsif tg_op='UPDATE' then v_meta:=jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new));
  else v_meta:=jsonb_build_object('before',to_jsonb(old)); end if;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_org,v_factory,auth.uid(),lower(tg_op),tg_table_name,v_id,v_meta);
  return coalesce(new,old);
end; $$;
revoke all on function public.audit_commercial_change() from public;
create trigger business_partners_audit after insert or update on public.business_partners for each row execute function public.audit_commercial_change();
create trigger purchase_requisitions_audit after insert or update on public.purchase_requisitions for each row execute function public.audit_commercial_change();
create trigger purchase_orders_audit after insert or update on public.purchase_orders for each row execute function public.audit_commercial_change();
create trigger goods_receipts_audit after insert or update on public.goods_receipts for each row execute function public.audit_commercial_change();
create trigger supplier_invoices_audit after insert or update on public.supplier_invoices for each row execute function public.audit_commercial_change();
create trigger supplier_payments_audit after insert on public.supplier_payments for each row execute function public.audit_commercial_change();
create trigger quotations_audit after insert or update on public.quotations for each row execute function public.audit_commercial_change();
create trigger sales_orders_audit after insert or update on public.sales_orders for each row execute function public.audit_commercial_change();
create trigger sales_allocations_audit after insert or update on public.sales_allocations for each row execute function public.audit_commercial_change();
create trigger customer_invoices_audit after insert or update on public.customer_invoices for each row execute function public.audit_commercial_change();
create trigger customer_payments_audit after insert on public.customer_payments for each row execute function public.audit_commercial_change();

create or replace function public.commercial_create_requisition(
  p_factory_id uuid,
  p_required_date date,
  p_purpose text,
  p_lines jsonb
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_id uuid; v_employee uuid; v_line jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_operate_commercial_factory(p_factory_id) then raise exception 'Not allowed for this factory'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines)=0 then raise exception 'At least one requisition line is required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if p_required_date is not null and p_required_date < current_date then raise exception 'Required date cannot be in the past'; end if;
  select id into v_employee from public.employees where organization_id=v_org and user_id=auth.uid() and status='active' limit 1;
  insert into public.purchase_requisitions(organization_id,factory_id,required_date,purpose,status,requested_by_employee_id,created_by)
  values(v_org,p_factory_id,p_required_date,nullif(trim(p_purpose),''),'submitted',v_employee,auth.uid()) returning id into v_id;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    if coalesce((v_line->>'quantity')::numeric,0)<=0 then raise exception 'Requisition quantity must be greater than zero'; end if;
    if not exists(select 1 from public.inventory_items where id=(v_line->>'item_id')::uuid and organization_id=v_org and is_active) then raise exception 'Requisition item not found'; end if;
    insert into public.purchase_requisition_lines(organization_id,requisition_id,item_id,quantity,estimated_unit_cost,notes)
    values(v_org,v_id,(v_line->>'item_id')::uuid,(v_line->>'quantity')::numeric,nullif(v_line->>'estimated_unit_cost','')::numeric,nullif(trim(v_line->>'notes'),''));
  end loop;
  return v_id;
end; $$;
grant execute on function public.commercial_create_requisition(uuid,date,text,jsonb) to authenticated;

create or replace function public.commercial_decide_requisition(p_requisition_id uuid,p_status text,p_note text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_pr public.purchase_requisitions%rowtype;
begin
  if p_status not in ('approved','rejected','cancelled') then raise exception 'Unsupported requisition decision'; end if;
  select * into v_pr from public.purchase_requisitions where id=p_requisition_id for update;
  if v_pr.id is null then raise exception 'Requisition not found'; end if;
  if not public.can_manage_factory(v_pr.factory_id) then raise exception 'Manager approval required'; end if;
  if v_pr.status not in ('submitted','approved') then raise exception 'Requisition cannot be changed from status %',v_pr.status; end if;
  update public.purchase_requisitions set status=p_status,decision_note=nullif(trim(p_note),''),approved_by=case when p_status='approved' then auth.uid() else approved_by end,approved_at=case when p_status='approved' then now() else approved_at end where id=p_requisition_id;
end; $$;
grant execute on function public.commercial_decide_requisition(uuid,text,text) to authenticated;

create or replace function public.commercial_create_purchase_order(
  p_factory_id uuid,
  p_supplier_id uuid,
  p_requisition_id uuid,
  p_expected_date date,
  p_currency_code text,
  p_notes text,
  p_lines jsonb
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_id uuid; v_line jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Manager access required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.business_partners where id=p_supplier_id and organization_id=v_org and is_active and partner_type in ('supplier','both')) then raise exception 'Active supplier not found'; end if;
  if p_requisition_id is not null and not exists(select 1 from public.purchase_requisitions where id=p_requisition_id and factory_id=p_factory_id and status='approved') then raise exception 'Approved requisition not found'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines)=0 then raise exception 'At least one purchase order line is required'; end if;
  insert into public.purchase_orders(organization_id,factory_id,supplier_id,requisition_id,expected_date,currency_code,status,notes,approved_by,approved_at,created_by)
  values(v_org,p_factory_id,p_supplier_id,p_requisition_id,p_expected_date,upper(coalesce(nullif(trim(p_currency_code),''),'INR')),'approved',nullif(trim(p_notes),''),auth.uid(),now(),auth.uid()) returning id into v_id;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    if coalesce((v_line->>'quantity')::numeric,0)<=0 then raise exception 'Purchase quantity must be greater than zero'; end if;
    if coalesce((v_line->>'unit_price')::numeric,-1)<0 then raise exception 'Unit price cannot be negative'; end if;
    if not exists(select 1 from public.inventory_items where id=(v_line->>'item_id')::uuid and organization_id=v_org and is_active) then raise exception 'Purchase item not found'; end if;
    insert into public.purchase_order_lines(organization_id,purchase_order_id,item_id,ordered_quantity,unit_price,tax_rate,notes)
    values(v_org,v_id,(v_line->>'item_id')::uuid,(v_line->>'quantity')::numeric,(v_line->>'unit_price')::numeric,coalesce(nullif(v_line->>'tax_rate','')::numeric,0),nullif(trim(v_line->>'notes'),''));
  end loop;
  if p_requisition_id is not null then update public.purchase_requisitions set status='converted' where id=p_requisition_id; end if;
  return v_id;
end; $$;
grant execute on function public.commercial_create_purchase_order(uuid,uuid,uuid,date,text,text,jsonb) to authenticated;

create or replace function public.commercial_set_purchase_order_status(p_purchase_order_id uuid,p_status text)
returns void language plpgsql security definer set search_path=public as $$
declare v_po public.purchase_orders%rowtype;
begin
  if p_status not in ('sent','cancelled') then raise exception 'Unsupported purchase order status'; end if;
  select * into v_po from public.purchase_orders where id=p_purchase_order_id for update;
  if v_po.id is null then raise exception 'Purchase order not found'; end if;
  if not public.can_manage_factory(v_po.factory_id) then raise exception 'Manager access required'; end if;
  if p_status='cancelled' and v_po.status in ('partially_received','received') then raise exception 'Received purchase order cannot be cancelled'; end if;
  update public.purchase_orders set status=p_status where id=p_purchase_order_id;
end; $$;
grant execute on function public.commercial_set_purchase_order_status(uuid,text) to authenticated;

create or replace function public.commercial_receive_goods(
  p_purchase_order_id uuid,
  p_received_location_id uuid,
  p_lines jsonb,
  p_notes text default null
) returns uuid
language plpgsql security definer set search_path=public as $$
declare
  v_po public.purchase_orders%rowtype; v_grn_id uuid; v_grn_no text; v_line jsonb; v_po_line public.purchase_order_lines%rowtype;
  v_qty numeric; v_tx uuid; v_plan_id uuid; v_inspection_id uuid; v_any_quality boolean:=false; v_lot text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_po from public.purchase_orders where id=p_purchase_order_id for update;
  if v_po.id is null then raise exception 'Purchase order not found'; end if;
  if not public.can_operate_commercial_factory(v_po.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if v_po.status not in ('approved','sent','partially_received') then raise exception 'Purchase order cannot receive goods from status %',v_po.status; end if;
  if not exists(select 1 from public.stock_locations where id=p_received_location_id and factory_id=v_po.factory_id and is_active) then raise exception 'Receiving location not found'; end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines)=0 then raise exception 'At least one receipt line is required'; end if;
  insert into public.goods_receipts(organization_id,factory_id,purchase_order_id,received_location_id,status,received_by,notes)
  values(v_po.organization_id,v_po.factory_id,p_purchase_order_id,p_received_location_id,'received',auth.uid(),nullif(trim(p_notes),'')) returning id,goods_receipt_no into v_grn_id,v_grn_no;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_po_line from public.purchase_order_lines where id=(v_line->>'purchase_order_line_id')::uuid and purchase_order_id=p_purchase_order_id for update;
    if v_po_line.id is null then raise exception 'Purchase order line not found'; end if;
    v_qty:=coalesce((v_line->>'quantity')::numeric,0);
    if v_qty<=0 or v_po_line.received_quantity+v_qty>v_po_line.ordered_quantity then raise exception 'Receipt quantity exceeds remaining purchase quantity'; end if;
    v_lot:=nullif(trim(v_line->>'lot_batch_no'),'');
    insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,to_location_id,unit_cost,external_reference,notes,created_by)
    values(v_po.organization_id,v_po.factory_id,v_po_line.item_id,'receive',v_qty,p_received_location_id,v_po_line.unit_price,v_grn_no,'Purchase goods receipt',auth.uid()) returning id into v_tx;
    insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost,created_at)
    values(v_po.organization_id,v_po.factory_id,v_tx,v_po_line.item_id,p_received_location_id,v_qty,v_po_line.unit_price,now());
    v_inspection_id:=null;
    if coalesce((v_line->>'quality_required')::boolean,false) then
      select id into v_plan_id from public.quality_inspection_plans where organization_id=v_po.organization_id and item_id=v_po_line.item_id and inspection_type='incoming' and is_active order by effective_from desc nulls last,created_at desc limit 1;
      if v_plan_id is null then raise exception 'Incoming quality plan not found for receipt item'; end if;
      select public.quality_start_inspection(v_po.factory_id,v_plan_id,v_po_line.item_id,null::uuid,null::uuid,v_lot,null::integer,null::uuid,'Auto-started from '||v_grn_no) into v_inspection_id;
      v_any_quality:=true;
    end if;
    insert into public.goods_receipt_lines(organization_id,goods_receipt_id,purchase_order_line_id,item_id,quantity_received,unit_cost,lot_batch_no,quality_required,inventory_receive_transaction_id,quality_inspection_id)
    values(v_po.organization_id,v_grn_id,v_po_line.id,v_po_line.item_id,v_qty,v_po_line.unit_price,v_lot,coalesce((v_line->>'quality_required')::boolean,false),v_tx,v_inspection_id);
    update public.purchase_order_lines set received_quantity=received_quantity+v_qty where id=v_po_line.id;
  end loop;
  update public.goods_receipts set status=case when v_any_quality then 'quality_pending' else 'received' end where id=v_grn_id;
  update public.purchase_orders set status=case when not exists(select 1 from public.purchase_order_lines where purchase_order_id=p_purchase_order_id and received_quantity<ordered_quantity) then 'received' else 'partially_received' end where id=p_purchase_order_id;
  return v_grn_id;
end; $$;
grant execute on function public.commercial_receive_goods(uuid,uuid,jsonb,text) to authenticated;

create or replace function public.commercial_sync_goods_receipt_quality()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_grn uuid; v_status text;
begin
  if tg_op='UPDATE' and new.status='completed' and (old.status,new.overall_result) is distinct from (new.status,old.overall_result) then
    for v_grn in select distinct goods_receipt_id from public.goods_receipt_lines where quality_inspection_id=new.id loop
      if exists(select 1 from public.goods_receipt_lines gl join public.quality_inspections qi on qi.id=gl.quality_inspection_id where gl.goods_receipt_id=v_grn and gl.quality_required and qi.status<>'completed') then v_status:='quality_pending';
      elsif exists(select 1 from public.goods_receipt_lines gl join public.quality_inspections qi on qi.id=gl.quality_inspection_id where gl.goods_receipt_id=v_grn and gl.quality_required and qi.overall_result in ('fail','hold')) then v_status:='quality_hold';
      else v_status:='quality_passed'; end if;
      update public.goods_receipts set status=v_status where id=v_grn and status<>'released';
    end loop;
  end if;
  return new;
end; $$;
revoke all on function public.commercial_sync_goods_receipt_quality() from public;
create trigger quality_inspection_sync_grn after update on public.quality_inspections for each row execute function public.commercial_sync_goods_receipt_quality();

create or replace function public.commercial_release_goods_receipt(p_goods_receipt_id uuid,p_to_location_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_grn public.goods_receipts%rowtype; v_line public.goods_receipt_lines%rowtype; v_tx uuid; v_balance numeric;
begin
  select * into v_grn from public.goods_receipts where id=p_goods_receipt_id for update;
  if v_grn.id is null then raise exception 'Goods receipt not found'; end if;
  if not public.can_operate_commercial_factory(v_grn.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if v_grn.status not in ('received','quality_passed') then raise exception 'Goods receipt is not releasable from status %',v_grn.status; end if;
  if not exists(select 1 from public.stock_locations where id=p_to_location_id and factory_id=v_grn.factory_id and is_active and id<>v_grn.received_location_id) then raise exception 'Release location not found'; end if;
  for v_line in select * from public.goods_receipt_lines where goods_receipt_id=p_goods_receipt_id order by id for update loop
    perform pg_advisory_xact_lock(hashtext(v_line.item_id::text||':'||v_grn.received_location_id::text));
    select coalesce(sum(quantity_delta),0) into v_balance from public.stock_ledger_entries where item_id=v_line.item_id and location_id=v_grn.received_location_id;
    if v_balance<v_line.quantity_received then raise exception 'Insufficient receipt stock to release item %',v_line.item_id; end if;
    insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,to_location_id,unit_cost,external_reference,notes,created_by)
    values(v_grn.organization_id,v_grn.factory_id,v_line.item_id,'transfer',v_line.quantity_received,v_grn.received_location_id,p_to_location_id,v_line.unit_cost,v_grn.goods_receipt_no,'Goods receipt release',auth.uid()) returning id into v_tx;
    insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost) values
    (v_grn.organization_id,v_grn.factory_id,v_tx,v_line.item_id,v_grn.received_location_id,-v_line.quantity_received,v_line.unit_cost),
    (v_grn.organization_id,v_grn.factory_id,v_tx,v_line.item_id,p_to_location_id,v_line.quantity_received,v_line.unit_cost);
    update public.goods_receipt_lines set inventory_release_transaction_id=v_tx where id=v_line.id;
  end loop;
  update public.goods_receipts set status='released',released_location_id=p_to_location_id,released_at=now(),released_by=auth.uid() where id=p_goods_receipt_id;
end; $$;
grant execute on function public.commercial_release_goods_receipt(uuid,uuid) to authenticated;

create or replace function public.commercial_create_supplier_invoice(p_purchase_order_id uuid,p_invoice_no text,p_invoice_date date,p_due_date date)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_po public.purchase_orders%rowtype; v_sub numeric(18,2); v_tax numeric(18,2); v_id uuid;
begin
  select * into v_po from public.purchase_orders where id=p_purchase_order_id;
  if v_po.id is null then raise exception 'Purchase order not found'; end if;
  if not public.can_manage_factory(v_po.factory_id) then raise exception 'Manager access required'; end if;
  if v_po.status not in ('partially_received','received') then raise exception 'Supplier invoice requires received goods'; end if;
  select round(coalesce(sum(ordered_quantity*unit_price),0),2),round(coalesce(sum(ordered_quantity*unit_price*tax_rate/100),0),2) into v_sub,v_tax from public.purchase_order_lines where purchase_order_id=p_purchase_order_id;
  insert into public.supplier_invoices(organization_id,factory_id,invoice_no,supplier_id,purchase_order_id,invoice_date,due_date,subtotal,tax_amount,total_amount,status,created_by)
  values(v_po.organization_id,v_po.factory_id,trim(p_invoice_no),v_po.supplier_id,p_purchase_order_id,coalesce(p_invoice_date,current_date),p_due_date,v_sub,v_tax,v_sub+v_tax,'posted',auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.commercial_create_supplier_invoice(uuid,text,date,date) to authenticated;

create or replace function public.commercial_record_supplier_payment(p_supplier_invoice_id uuid,p_amount numeric,p_payment_method text,p_reference_no text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_inv public.supplier_invoices%rowtype; v_paid numeric; v_id uuid;
begin
  select * into v_inv from public.supplier_invoices where id=p_supplier_invoice_id for update;
  if v_inv.id is null then raise exception 'Supplier invoice not found'; end if;
  if not public.can_manage_factory(v_inv.factory_id) then raise exception 'Manager access required'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Payment must be greater than zero'; end if;
  select coalesce(sum(amount),0) into v_paid from public.supplier_payments where supplier_invoice_id=p_supplier_invoice_id;
  if v_paid+p_amount>v_inv.total_amount then raise exception 'Payment exceeds supplier invoice due amount'; end if;
  insert into public.supplier_payments(organization_id,factory_id,supplier_invoice_id,amount,payment_method,reference_no,created_by)
  values(v_inv.organization_id,v_inv.factory_id,p_supplier_invoice_id,p_amount,p_payment_method,nullif(trim(p_reference_no),''),auth.uid()) returning id into v_id;
  update public.supplier_invoices set status=case when v_paid+p_amount=v_inv.total_amount then 'paid' else 'partially_paid' end where id=p_supplier_invoice_id;
  return v_id;
end; $$;
grant execute on function public.commercial_record_supplier_payment(uuid,numeric,text,text) to authenticated;

create or replace function public.commercial_create_quotation(p_factory_id uuid,p_customer_id uuid,p_valid_until date,p_currency_code text,p_notes text,p_lines jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_id uuid; v_line jsonb;
begin
  if not public.can_manage_factory(p_factory_id) then raise exception 'Manager access required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if not exists(select 1 from public.business_partners where id=p_customer_id and organization_id=v_org and is_active and partner_type in ('customer','both')) then raise exception 'Active customer not found'; end if;
  if p_valid_until<current_date then raise exception 'Quotation validity cannot be in the past'; end if;
  if jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines)=0 then raise exception 'At least one quotation line is required'; end if;
  insert into public.quotations(organization_id,factory_id,customer_id,valid_until,currency_code,status,notes,created_by)
  values(v_org,p_factory_id,p_customer_id,p_valid_until,upper(coalesce(nullif(trim(p_currency_code),''),'INR')),'draft',nullif(trim(p_notes),''),auth.uid()) returning id into v_id;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    if coalesce((v_line->>'quantity')::numeric,0)<=0 then raise exception 'Quotation quantity must be greater than zero'; end if;
    if coalesce((v_line->>'unit_price')::numeric,-1)<0 then raise exception 'Quotation price cannot be negative'; end if;
    if not exists(select 1 from public.inventory_items where id=(v_line->>'item_id')::uuid and organization_id=v_org and is_active) then raise exception 'Quotation item not found'; end if;
    insert into public.quotation_lines(organization_id,quotation_id,item_id,quantity,unit_price,tax_rate,notes)
    values(v_org,v_id,(v_line->>'item_id')::uuid,(v_line->>'quantity')::numeric,(v_line->>'unit_price')::numeric,coalesce(nullif(v_line->>'tax_rate','')::numeric,0),nullif(trim(v_line->>'notes'),''));
  end loop;
  return v_id;
end; $$;
grant execute on function public.commercial_create_quotation(uuid,uuid,date,text,text,jsonb) to authenticated;

create or replace function public.commercial_set_quotation_status(p_quotation_id uuid,p_status text)
returns void language plpgsql security definer set search_path=public as $$
declare v_q public.quotations%rowtype;
begin
  if p_status not in ('sent','accepted','rejected','cancelled') then raise exception 'Unsupported quotation status'; end if;
  select * into v_q from public.quotations where id=p_quotation_id for update;
  if v_q.id is null then raise exception 'Quotation not found'; end if;
  if not public.can_manage_factory(v_q.factory_id) then raise exception 'Manager access required'; end if;
  if v_q.status='converted' then raise exception 'Converted quotation cannot be changed'; end if;
  update public.quotations set status=p_status where id=p_quotation_id;
end; $$;
grant execute on function public.commercial_set_quotation_status(uuid,text) to authenticated;

create or replace function public.commercial_convert_quotation(p_quotation_id uuid,p_requested_delivery_date date default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_q public.quotations%rowtype; v_id uuid; v_line public.quotation_lines%rowtype;
begin
  select * into v_q from public.quotations where id=p_quotation_id for update;
  if v_q.id is null then raise exception 'Quotation not found'; end if;
  if not public.can_manage_factory(v_q.factory_id) then raise exception 'Manager access required'; end if;
  if v_q.status not in ('sent','accepted') then raise exception 'Quotation must be sent or accepted before conversion'; end if;
  insert into public.sales_orders(organization_id,factory_id,customer_id,quotation_id,requested_delivery_date,currency_code,status,notes,created_by)
  values(v_q.organization_id,v_q.factory_id,v_q.customer_id,v_q.id,p_requested_delivery_date,v_q.currency_code,'confirmed',v_q.notes,auth.uid()) returning id into v_id;
  for v_line in select * from public.quotation_lines where quotation_id=p_quotation_id order by id loop
    insert into public.sales_order_lines(organization_id,sales_order_id,item_id,ordered_quantity,unit_price,tax_rate,notes)
    values(v_q.organization_id,v_id,v_line.item_id,v_line.quantity,v_line.unit_price,v_line.tax_rate,v_line.notes);
  end loop;
  update public.quotations set status='converted' where id=p_quotation_id;
  return v_id;
end; $$;
grant execute on function public.commercial_convert_quotation(uuid,date) to authenticated;

create or replace function public.commercial_available_stock(p_item_id uuid,p_location_id uuid)
returns numeric language sql stable security definer set search_path=public as $$
  select coalesce((select sum(quantity_delta) from public.stock_ledger_entries where item_id=p_item_id and location_id=p_location_id),0)
       - coalesce((select sum(quantity) from public.sales_allocations where item_id=p_item_id and location_id=p_location_id and status='allocated'),0);
$$;
grant execute on function public.commercial_available_stock(uuid,uuid) to authenticated;

create or replace function public.commercial_allocate_sales_order(p_sales_order_id uuid,p_location_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_so public.sales_orders%rowtype; v_line public.sales_order_lines%rowtype; v_need numeric; v_available numeric;
begin
  select * into v_so from public.sales_orders where id=p_sales_order_id for update;
  if v_so.id is null then raise exception 'Sales order not found'; end if;
  if not public.can_operate_commercial_factory(v_so.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if v_so.status not in ('confirmed','allocated') then raise exception 'Sales order cannot be allocated from status %',v_so.status; end if;
  if not exists(select 1 from public.stock_locations where id=p_location_id and factory_id=v_so.factory_id and is_active) then raise exception 'Allocation location not found'; end if;
  for v_line in select * from public.sales_order_lines where sales_order_id=p_sales_order_id order by id for update loop
    v_need:=v_line.ordered_quantity-v_line.allocated_quantity;
    if v_need>0 then
      perform pg_advisory_xact_lock(hashtext(v_line.item_id::text||':'||p_location_id::text));
      select public.commercial_available_stock(v_line.item_id,p_location_id) into v_available;
      if v_available<v_need then raise exception 'Insufficient available stock for item %: need %, available %',v_line.item_id,v_need,v_available; end if;
      insert into public.sales_allocations(organization_id,factory_id,sales_order_id,sales_order_line_id,item_id,location_id,quantity,status,created_by)
      values(v_so.organization_id,v_so.factory_id,v_so.id,v_line.id,v_line.item_id,p_location_id,v_need,'allocated',auth.uid());
      update public.sales_order_lines set allocated_quantity=allocated_quantity+v_need where id=v_line.id;
    end if;
  end loop;
  update public.sales_orders set status='allocated',dispatch_ready_at=null where id=p_sales_order_id;
end; $$;
grant execute on function public.commercial_allocate_sales_order(uuid,uuid) to authenticated;

create or replace function public.commercial_mark_dispatch_ready(p_sales_order_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_so public.sales_orders%rowtype;
begin
  select * into v_so from public.sales_orders where id=p_sales_order_id for update;
  if v_so.id is null then raise exception 'Sales order not found'; end if;
  if not public.can_operate_commercial_factory(v_so.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if v_so.status<>'allocated' then raise exception 'Sales order must be allocated first'; end if;
  if exists(select 1 from public.sales_order_lines where sales_order_id=p_sales_order_id and allocated_quantity<ordered_quantity) then raise exception 'All sales order lines must be fully allocated'; end if;
  update public.sales_orders set status='dispatch_ready',dispatch_ready_at=now() where id=p_sales_order_id;
end; $$;
grant execute on function public.commercial_mark_dispatch_ready(uuid) to authenticated;

create or replace function public.commercial_cancel_sales_order(p_sales_order_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_so public.sales_orders%rowtype;
begin
  select * into v_so from public.sales_orders where id=p_sales_order_id for update;
  if v_so.id is null then raise exception 'Sales order not found'; end if;
  if not public.can_manage_factory(v_so.factory_id) then raise exception 'Manager access required'; end if;
  if v_so.status in ('dispatched','completed') then raise exception 'Dispatched/completed order cannot be cancelled'; end if;
  update public.sales_allocations set status='released' where sales_order_id=p_sales_order_id and status='allocated';
  update public.sales_order_lines set allocated_quantity=0 where sales_order_id=p_sales_order_id;
  update public.sales_orders set status='cancelled',dispatch_ready_at=null where id=p_sales_order_id;
end; $$;
grant execute on function public.commercial_cancel_sales_order(uuid) to authenticated;

create or replace function public.commercial_create_customer_invoice(p_sales_order_id uuid,p_invoice_date date,p_due_date date)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_so public.sales_orders%rowtype; v_sub numeric(18,2); v_tax numeric(18,2); v_id uuid;
begin
  select * into v_so from public.sales_orders where id=p_sales_order_id;
  if v_so.id is null then raise exception 'Sales order not found'; end if;
  if not public.can_manage_factory(v_so.factory_id) then raise exception 'Manager access required'; end if;
  if v_so.status not in ('dispatch_ready','dispatched','completed') then raise exception 'Customer invoice requires dispatch-ready sales order'; end if;
  select round(coalesce(sum(ordered_quantity*unit_price),0),2),round(coalesce(sum(ordered_quantity*unit_price*tax_rate/100),0),2) into v_sub,v_tax from public.sales_order_lines where sales_order_id=p_sales_order_id;
  insert into public.customer_invoices(organization_id,factory_id,customer_id,sales_order_id,invoice_date,due_date,subtotal,tax_amount,total_amount,status,created_by)
  values(v_so.organization_id,v_so.factory_id,v_so.customer_id,p_sales_order_id,coalesce(p_invoice_date,current_date),p_due_date,v_sub,v_tax,v_sub+v_tax,'posted',auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.commercial_create_customer_invoice(uuid,date,date) to authenticated;

create or replace function public.commercial_record_customer_payment(p_customer_invoice_id uuid,p_amount numeric,p_payment_method text,p_reference_no text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_inv public.customer_invoices%rowtype; v_paid numeric; v_id uuid;
begin
  select * into v_inv from public.customer_invoices where id=p_customer_invoice_id for update;
  if v_inv.id is null then raise exception 'Customer invoice not found'; end if;
  if not public.can_manage_factory(v_inv.factory_id) then raise exception 'Manager access required'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Payment must be greater than zero'; end if;
  select coalesce(sum(amount),0) into v_paid from public.customer_payments where customer_invoice_id=p_customer_invoice_id;
  if v_paid+p_amount>v_inv.total_amount then raise exception 'Payment exceeds customer invoice due amount'; end if;
  insert into public.customer_payments(organization_id,factory_id,customer_invoice_id,amount,payment_method,reference_no,created_by)
  values(v_inv.organization_id,v_inv.factory_id,p_customer_invoice_id,p_amount,p_payment_method,nullif(trim(p_reference_no),''),auth.uid()) returning id into v_id;
  update public.customer_invoices set status=case when v_paid+p_amount=v_inv.total_amount then 'paid' else 'partially_paid' end where id=p_customer_invoice_id;
  return v_id;
end; $$;
grant execute on function public.commercial_record_customer_payment(uuid,numeric,text,text) to authenticated;

create or replace function public.commercial_dashboard_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language sql stable security definer set search_path=public as $$
  select jsonb_build_object(
    'suppliers',(select count(*) from public.business_partners where organization_id=p_organization_id and is_active and partner_type in ('supplier','both')),
    'customers',(select count(*) from public.business_partners where organization_id=p_organization_id and is_active and partner_type in ('customer','both')),
    'open_requisitions',(select count(*) from public.purchase_requisitions where organization_id=p_organization_id and (p_factory_id is null or factory_id=p_factory_id) and status in ('submitted','approved')),
    'open_purchase_orders',(select count(*) from public.purchase_orders where organization_id=p_organization_id and (p_factory_id is null or factory_id=p_factory_id) and status in ('approved','sent','partially_received')),
    'quality_pending_grn',(select count(*) from public.goods_receipts where organization_id=p_organization_id and (p_factory_id is null or factory_id=p_factory_id) and status in ('quality_pending','quality_hold')),
    'supplier_due',(select coalesce(sum(si.total_amount-coalesce((select sum(sp.amount) from public.supplier_payments sp where sp.supplier_invoice_id=si.id),0)),0) from public.supplier_invoices si where si.organization_id=p_organization_id and (p_factory_id is null or si.factory_id=p_factory_id) and si.status not in ('paid','cancelled')),
    'open_quotations',(select count(*) from public.quotations where organization_id=p_organization_id and (p_factory_id is null or factory_id=p_factory_id) and status in ('draft','sent','accepted')),
    'open_sales_orders',(select count(*) from public.sales_orders where organization_id=p_organization_id and (p_factory_id is null or factory_id=p_factory_id) and status in ('confirmed','allocated','dispatch_ready')),
    'dispatch_ready',(select count(*) from public.sales_orders where organization_id=p_organization_id and (p_factory_id is null or factory_id=p_factory_id) and status='dispatch_ready'),
    'customer_due',(select coalesce(sum(ci.total_amount-coalesce((select sum(cp.amount) from public.customer_payments cp where cp.customer_invoice_id=ci.id),0)),0) from public.customer_invoices ci where ci.organization_id=p_organization_id and (p_factory_id is null or ci.factory_id=p_factory_id) and ci.status not in ('paid','cancelled'))
  ) where public.is_org_member(p_organization_id);
$$;
grant execute on function public.commercial_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.purchase_order_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 200)
returns table(purchase_order_id uuid,purchase_order_no text,supplier_name text,status text,order_date date,expected_date date,total_amount numeric,received_percent numeric)
language sql stable security definer set search_path=public as $$
  select po.id,po.purchase_order_no,bp.name,po.status,po.order_date,po.expected_date,
    round(sum(pol.ordered_quantity*pol.unit_price*(1+pol.tax_rate/100)),2),
    round(case when sum(pol.ordered_quantity)=0 then 0 else sum(pol.received_quantity)/sum(pol.ordered_quantity)*100 end,2)
  from public.purchase_orders po join public.business_partners bp on bp.id=po.supplier_id join public.purchase_order_lines pol on pol.purchase_order_id=po.id
  where po.organization_id=p_organization_id and (p_factory_id is null or po.factory_id=p_factory_id) and public.can_view_commercial_factory(po.factory_id)
  group by po.id,bp.name order by po.order_date desc,po.created_at desc limit greatest(1,least(coalesce(p_limit,200),1000));
$$;
grant execute on function public.purchase_order_report(uuid,uuid,integer) to authenticated;

create or replace function public.sales_order_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 200)
returns table(sales_order_id uuid,sales_order_no text,customer_name text,status text,order_date date,requested_delivery_date date,total_amount numeric,allocated_percent numeric)
language sql stable security definer set search_path=public as $$
  select so.id,so.sales_order_no,bp.name,so.status,so.order_date,so.requested_delivery_date,
    round(sum(sol.ordered_quantity*sol.unit_price*(1+sol.tax_rate/100)),2),
    round(case when sum(sol.ordered_quantity)=0 then 0 else sum(sol.allocated_quantity)/sum(sol.ordered_quantity)*100 end,2)
  from public.sales_orders so join public.business_partners bp on bp.id=so.customer_id join public.sales_order_lines sol on sol.sales_order_id=so.id
  where so.organization_id=p_organization_id and (p_factory_id is null or so.factory_id=p_factory_id) and public.can_view_commercial_factory(so.factory_id)
  group by so.id,bp.name order by so.order_date desc,so.created_at desc limit greatest(1,least(coalesce(p_limit,200),1000));
$$;
grant execute on function public.sales_order_report(uuid,uuid,integer) to authenticated;

create or replace function public.commercial_partner_ledger(p_organization_id uuid,p_partner_id uuid)
returns table(entry_type text,reference_no text,entry_date date,debit numeric,credit numeric,balance numeric)
language sql stable security definer set search_path=public as $$
  with entries as (
    select 'supplier_invoice'::text entry_type,si.invoice_no reference_no,si.invoice_date entry_date,si.total_amount debit,0::numeric credit from public.supplier_invoices si where si.organization_id=p_organization_id and si.supplier_id=p_partner_id and si.status<>'cancelled'
    union all
    select 'supplier_payment',sp.payment_no,sp.paid_at::date,0::numeric,sp.amount from public.supplier_payments sp join public.supplier_invoices si on si.id=sp.supplier_invoice_id where sp.organization_id=p_organization_id and si.supplier_id=p_partner_id
    union all
    select 'customer_invoice',ci.invoice_no,ci.invoice_date,0::numeric,ci.total_amount from public.customer_invoices ci where ci.organization_id=p_organization_id and ci.customer_id=p_partner_id and ci.status<>'cancelled'
    union all
    select 'customer_payment',cp.payment_no,cp.paid_at::date,cp.amount,0::numeric from public.customer_payments cp join public.customer_invoices ci on ci.id=cp.customer_invoice_id where cp.organization_id=p_organization_id and ci.customer_id=p_partner_id
  )
  select e.entry_type,e.reference_no,e.entry_date,e.debit,e.credit,sum(e.debit-e.credit) over(order by e.entry_date,e.reference_no rows unbounded preceding)
  from entries e where public.is_org_member(p_organization_id) order by e.entry_date,e.reference_no;
$$;
grant execute on function public.commercial_partner_ledger(uuid,uuid) to authenticated;

commit;
