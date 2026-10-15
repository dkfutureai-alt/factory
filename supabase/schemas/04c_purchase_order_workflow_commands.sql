-- FactoryOS Purchase Order authoring + approval workflow.
-- Applies after 04b_purchase_receipt_idempotency_fix.sql.
--
-- Client writes for PO headers/lines are RPC-only after this migration. Draft authors require
-- purchase.manage at the exact factory. Approval/rejection requires approval.act at that factory.

alter table public.purchase_orders
  add column revision integer not null default 1 check (revision > 0),
  add column submitted_by uuid references auth.users(id) on delete set null,
  add column submitted_at timestamptz,
  add column rejected_by uuid references auth.users(id) on delete set null,
  add column rejected_at timestamptz,
  add column rejection_reason text,
  add column approval_comment text;

create table public.purchase_order_command_receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  command_type text not null check (command_type in ('create_draft','update_draft','submit','approve','reject')),
  idempotency_key text not null,
  request_hash text not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);

create index purchase_order_command_receipts_po_idx
  on public.purchase_order_command_receipts (purchase_order_id, created_at desc);

alter table public.purchase_order_command_receipts enable row level security;
revoke all on public.purchase_order_command_receipts from public, authenticated;

-- Submission freezes commercial lines. A rejected order returns to draft and becomes editable again.
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
  if po_status <> 'draft' then
    raise exception 'purchase order lines may change only while order is draft';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function private.purchase_command_replay(
  target_organization_id uuid,
  target_idempotency_key text,
  target_command_type text,
  target_request_hash text,
  target_purchase_order_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  receipt public.purchase_order_command_receipts;
begin
  select * into receipt
  from public.purchase_order_command_receipts r
  where r.organization_id=target_organization_id
    and r.idempotency_key=btrim(target_idempotency_key);
  if receipt.id is null then return null; end if;
  if receipt.command_type <> target_command_type
     or receipt.request_hash <> target_request_hash
     or (target_purchase_order_id is not null and receipt.purchase_order_id <> target_purchase_order_id) then
    raise exception 'purchase order idempotency key conflict';
  end if;
  return receipt.purchase_order_id;
end;
$$;
revoke all on function private.purchase_command_replay(uuid,text,text,text,uuid) from public, authenticated;

create or replace function private.record_purchase_command(
  target_organization_id uuid,
  target_purchase_order_id uuid,
  target_command_type text,
  target_idempotency_key text,
  target_request_hash text,
  actor_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.purchase_order_command_receipts(
    organization_id,purchase_order_id,command_type,idempotency_key,request_hash,actor_user_id
  ) values (
    target_organization_id,target_purchase_order_id,target_command_type,btrim(target_idempotency_key),target_request_hash,actor_id
  );
end;
$$;
revoke all on function private.record_purchase_command(uuid,uuid,text,text,text,uuid) from public, authenticated;

create or replace function public.create_purchase_order_draft(
  target_factory_id uuid,
  target_supplier_id uuid,
  target_expected_delivery_date date,
  target_payment_terms text,
  target_notes text,
  target_lines jsonb,
  target_idempotency_key text
)
returns public.purchase_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor_id uuid := (select auth.uid());
  target_org_id uuid;
  factory_status public.entity_status;
  supplier_org_id uuid;
  supplier_status public.entity_status;
  supplier_terms integer;
  currency text;
  request_hash text;
  replay_po_id uuid;
  po public.purchase_orders;
  line_json jsonb;
  item_org_id uuid;
  item_status public.entity_status;
  item_id uuid;
  qty numeric;
  price numeric;
  tax numeric;
  order_number text;
  total_count bigint;
  distinct_count bigint;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if length(btrim(coalesce(target_idempotency_key,''))) < 8 then raise exception 'purchase order idempotency key is required'; end if;
  if target_lines is null or jsonb_typeof(target_lines) <> 'array' then raise exception 'purchase order lines must be an array'; end if;

  select organization_id,status into target_org_id,factory_status
  from public.factories where id=target_factory_id;
  if target_org_id is null or factory_status <> 'active' then raise exception 'purchase order factory is invalid or inactive'; end if;
  if not private.has_factory_permission(target_org_id,'purchase.manage',target_factory_id) then raise exception 'purchase order management permission denied'; end if;

  select organization_id,status,payment_terms_days into supplier_org_id,supplier_status,supplier_terms
  from public.suppliers where id=target_supplier_id;
  if supplier_org_id is distinct from target_org_id or supplier_status <> 'active' then raise exception 'purchase order supplier is invalid or inactive'; end if;
  if target_expected_delivery_date is not null and target_expected_delivery_date < current_date then
    raise exception 'expected delivery date cannot be before order date';
  end if;

  request_hash := md5(jsonb_build_object(
    'factory_id',target_factory_id,'supplier_id',target_supplier_id,'expected_delivery_date',target_expected_delivery_date,
    'payment_terms',coalesce(btrim(target_payment_terms),''),'notes',coalesce(btrim(target_notes),''),'lines',target_lines
  )::text);
  perform pg_advisory_xact_lock(hashtextextended(target_org_id::text || ':' || btrim(target_idempotency_key),0));
  replay_po_id := private.purchase_command_replay(target_org_id,target_idempotency_key,'create_draft',request_hash,null);
  if replay_po_id is not null then select * into po from public.purchase_orders where id=replay_po_id; return po; end if;

  select count(*),count(distinct nullif(value->>'item_id','')) into total_count,distinct_count
  from jsonb_array_elements(target_lines);
  if total_count <> distinct_count then raise exception 'purchase order contains duplicate items'; end if;

  select coalesce(os.currency_code,'INR') into currency from public.organization_settings os where os.organization_id=target_org_id;
  currency := coalesce(currency,'INR');
  order_number := 'PO-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,5));

  insert into public.purchase_orders(
    organization_id,factory_id,supplier_id,order_number,order_date,expected_delivery_date,status,
    currency_code,payment_terms,notes,created_by,revision
  ) values (
    target_org_id,target_factory_id,target_supplier_id,order_number,current_date,target_expected_delivery_date,'draft',
    currency,coalesce(nullif(btrim(coalesce(target_payment_terms,'')),''),supplier_terms::text || ' days from accepted GRN'),
    nullif(btrim(coalesce(target_notes,'')),''),actor_id,1
  ) returning * into po;

  for line_json in select value from jsonb_array_elements(target_lines)
  loop
    item_id := nullif(line_json->>'item_id','')::uuid;
    qty := coalesce((line_json->>'ordered_quantity')::numeric,0);
    price := coalesce((line_json->>'unit_price')::numeric,-1);
    tax := coalesce((line_json->>'tax_rate')::numeric,0);
    select organization_id,status into item_org_id,item_status from public.items where id=item_id;
    if item_org_id is distinct from target_org_id or item_status <> 'active' then raise exception 'purchase order item is invalid or inactive'; end if;
    if qty <= 0 then raise exception 'purchase order quantity must be greater than zero'; end if;
    if price < 0 then raise exception 'purchase order unit price cannot be negative'; end if;
    if tax < 0 or tax > 100 then raise exception 'purchase order tax rate must be between 0 and 100'; end if;
    insert into public.purchase_order_lines(organization_id,purchase_order_id,item_id,ordered_quantity,unit_price,tax_rate,note)
    values(target_org_id,po.id,item_id,qty,price,tax,nullif(btrim(coalesce(line_json->>'note','')),''));
  end loop;

  perform private.record_purchase_command(target_org_id,po.id,'create_draft',target_idempotency_key,request_hash,actor_id);
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(target_org_id,target_factory_id,actor_id,'create','purchase_order',po.id::text,
    jsonb_build_object('source','purchase_order_workflow','command','create_draft','order_number',po.order_number,'revision',po.revision));
  return po;
end;
$$;

create or replace function public.update_purchase_order_draft(
  target_purchase_order_id uuid,
  target_expected_revision integer,
  target_supplier_id uuid,
  target_expected_delivery_date date,
  target_payment_terms text,
  target_notes text,
  target_lines jsonb,
  target_idempotency_key text
)
returns public.purchase_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor_id uuid := (select auth.uid());
  po public.purchase_orders;
  supplier_org_id uuid;
  supplier_status public.entity_status;
  request_hash text;
  replay_po_id uuid;
  line_json jsonb;
  item_id uuid;
  item_org_id uuid;
  item_status public.entity_status;
  qty numeric;
  price numeric;
  tax numeric;
  total_count bigint;
  distinct_count bigint;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if length(btrim(coalesce(target_idempotency_key,''))) < 8 then raise exception 'purchase order idempotency key is required'; end if;
  if target_lines is null or jsonb_typeof(target_lines) <> 'array' then raise exception 'purchase order lines must be an array'; end if;
  select * into po from public.purchase_orders where id=target_purchase_order_id for update;
  if po.id is null then raise exception 'purchase order not found'; end if;
  if not private.has_factory_permission(po.organization_id,'purchase.manage',po.factory_id) then raise exception 'purchase order management permission denied'; end if;

  request_hash := md5(jsonb_build_object(
    'purchase_order_id',target_purchase_order_id,'expected_revision',target_expected_revision,'supplier_id',target_supplier_id,
    'expected_delivery_date',target_expected_delivery_date,'payment_terms',coalesce(btrim(target_payment_terms),''),
    'notes',coalesce(btrim(target_notes),''),'lines',target_lines
  )::text);
  perform pg_advisory_xact_lock(hashtextextended(po.organization_id::text || ':' || btrim(target_idempotency_key),0));
  replay_po_id := private.purchase_command_replay(po.organization_id,target_idempotency_key,'update_draft',request_hash,po.id);
  if replay_po_id is not null then select * into po from public.purchase_orders where id=replay_po_id; return po; end if;

  if po.status <> 'draft' then raise exception 'only draft purchase orders can be edited'; end if;
  if po.revision <> target_expected_revision then raise exception 'purchase order revision conflict'; end if;
  select organization_id,status into supplier_org_id,supplier_status from public.suppliers where id=target_supplier_id;
  if supplier_org_id is distinct from po.organization_id or supplier_status <> 'active' then raise exception 'purchase order supplier is invalid or inactive'; end if;
  if target_expected_delivery_date is not null and target_expected_delivery_date < po.order_date then raise exception 'expected delivery date cannot be before order date'; end if;

  select count(*),count(distinct nullif(value->>'item_id','')) into total_count,distinct_count from jsonb_array_elements(target_lines);
  if total_count <> distinct_count then raise exception 'purchase order contains duplicate items'; end if;
  delete from public.purchase_order_lines where purchase_order_id=po.id;
  for line_json in select value from jsonb_array_elements(target_lines)
  loop
    item_id := nullif(line_json->>'item_id','')::uuid;
    qty := coalesce((line_json->>'ordered_quantity')::numeric,0);
    price := coalesce((line_json->>'unit_price')::numeric,-1);
    tax := coalesce((line_json->>'tax_rate')::numeric,0);
    select organization_id,status into item_org_id,item_status from public.items where id=item_id;
    if item_org_id is distinct from po.organization_id or item_status <> 'active' then raise exception 'purchase order item is invalid or inactive'; end if;
    if qty <= 0 then raise exception 'purchase order quantity must be greater than zero'; end if;
    if price < 0 then raise exception 'purchase order unit price cannot be negative'; end if;
    if tax < 0 or tax > 100 then raise exception 'purchase order tax rate must be between 0 and 100'; end if;
    insert into public.purchase_order_lines(organization_id,purchase_order_id,item_id,ordered_quantity,unit_price,tax_rate,note)
    values(po.organization_id,po.id,item_id,qty,price,tax,nullif(btrim(coalesce(line_json->>'note','')),''));
  end loop;
  update public.purchase_orders
  set supplier_id=target_supplier_id,expected_delivery_date=target_expected_delivery_date,
      payment_terms=nullif(btrim(coalesce(target_payment_terms,'')),''),notes=nullif(btrim(coalesce(target_notes,'')),''),revision=revision+1
  where id=po.id returning * into po;
  perform private.record_purchase_command(po.organization_id,po.id,'update_draft',target_idempotency_key,request_hash,actor_id);
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(po.organization_id,po.factory_id,actor_id,'update','purchase_order',po.id::text,
    jsonb_build_object('source','purchase_order_workflow','command','update_draft','order_number',po.order_number,'revision',po.revision));
  return po;
end;
$$;

create or replace function public.submit_purchase_order(
  target_purchase_order_id uuid,
  target_expected_revision integer,
  target_idempotency_key text
)
returns public.purchase_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor_id uuid := (select auth.uid());
  po public.purchase_orders;
  request_hash text;
  replay_po_id uuid;
  line_count bigint;
  invalid_count bigint;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if length(btrim(coalesce(target_idempotency_key,''))) < 8 then raise exception 'purchase order idempotency key is required'; end if;
  select * into po from public.purchase_orders where id=target_purchase_order_id for update;
  if po.id is null then raise exception 'purchase order not found'; end if;
  if not private.has_factory_permission(po.organization_id,'purchase.manage',po.factory_id) then raise exception 'purchase order management permission denied'; end if;
  request_hash := md5(jsonb_build_object('purchase_order_id',po.id,'expected_revision',target_expected_revision)::text);
  perform pg_advisory_xact_lock(hashtextextended(po.organization_id::text || ':' || btrim(target_idempotency_key),0));
  replay_po_id := private.purchase_command_replay(po.organization_id,target_idempotency_key,'submit',request_hash,po.id);
  if replay_po_id is not null then select * into po from public.purchase_orders where id=replay_po_id; return po; end if;
  if po.status <> 'draft' then raise exception 'only draft purchase orders can be submitted'; end if;
  if po.revision <> target_expected_revision then raise exception 'purchase order revision conflict'; end if;
  select count(*) into line_count from public.purchase_order_lines where purchase_order_id=po.id;
  if line_count=0 then raise exception 'purchase order requires at least one line before submission'; end if;
  select count(*) into invalid_count
  from public.purchase_order_lines pol join public.items i on i.id=pol.item_id
  where pol.purchase_order_id=po.id and (i.organization_id<>po.organization_id or i.status<>'active');
  if invalid_count>0 then raise exception 'purchase order contains inactive or cross-tenant items'; end if;
  if not exists(select 1 from public.suppliers s where s.id=po.supplier_id and s.organization_id=po.organization_id and s.status='active') then
    raise exception 'purchase order supplier is inactive or invalid';
  end if;
  update public.purchase_orders
  set status='pending_approval',submitted_by=actor_id,submitted_at=now(),approved_by=null,approved_at=null,
      rejected_by=null,rejected_at=null,rejection_reason=null,approval_comment=null,revision=revision+1
  where id=po.id returning * into po;
  perform private.record_purchase_command(po.organization_id,po.id,'submit',target_idempotency_key,request_hash,actor_id);
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(po.organization_id,po.factory_id,actor_id,'submit','purchase_order',po.id::text,
    jsonb_build_object('source','purchase_order_workflow','command','submit','order_number',po.order_number,'revision',po.revision));
  return po;
end;
$$;

create or replace function public.decide_purchase_order(
  target_purchase_order_id uuid,
  target_decision text,
  target_comment text,
  target_idempotency_key text
)
returns public.purchase_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor_id uuid := (select auth.uid());
  po public.purchase_orders;
  decision text := lower(btrim(coalesce(target_decision,'')));
  request_hash text;
  replay_po_id uuid;
  command_type text;
begin
  if actor_id is null then raise exception 'authentication required'; end if;
  if decision not in ('approve','reject') then raise exception 'purchase order decision must be approve or reject'; end if;
  if decision='reject' and length(btrim(coalesce(target_comment,''))) < 3 then raise exception 'purchase order rejection reason is required'; end if;
  if length(btrim(coalesce(target_idempotency_key,''))) < 8 then raise exception 'purchase order idempotency key is required'; end if;
  select * into po from public.purchase_orders where id=target_purchase_order_id for update;
  if po.id is null then raise exception 'purchase order not found'; end if;
  if not private.has_factory_permission(po.organization_id,'approval.act',po.factory_id) then raise exception 'purchase order approval permission denied'; end if;
  command_type := case when decision='approve' then 'approve' else 'reject' end;
  request_hash := md5(jsonb_build_object('purchase_order_id',po.id,'decision',decision,'comment',coalesce(btrim(target_comment),''))::text);
  perform pg_advisory_xact_lock(hashtextextended(po.organization_id::text || ':' || btrim(target_idempotency_key),0));
  replay_po_id := private.purchase_command_replay(po.organization_id,target_idempotency_key,command_type,request_hash,po.id);
  if replay_po_id is not null then select * into po from public.purchase_orders where id=replay_po_id; return po; end if;
  if po.status <> 'pending_approval' then raise exception 'purchase order is not pending approval'; end if;
  if decision='approve' then
    update public.purchase_orders
    set status='approved',approved_by=actor_id,approved_at=now(),approval_comment=nullif(btrim(coalesce(target_comment,'')),''),
        rejected_by=null,rejected_at=null,rejection_reason=null,revision=revision+1
    where id=po.id returning * into po;
  else
    update public.purchase_orders
    set status='draft',rejected_by=actor_id,rejected_at=now(),rejection_reason=btrim(target_comment),approval_comment=null,
        approved_by=null,approved_at=null,revision=revision+1
    where id=po.id returning * into po;
  end if;
  perform private.record_purchase_command(po.organization_id,po.id,command_type,target_idempotency_key,request_hash,actor_id);
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(po.organization_id,po.factory_id,actor_id,decision,'purchase_order',po.id::text,
    jsonb_build_object('source','purchase_order_workflow','command',command_type,'order_number',po.order_number,'revision',po.revision,'comment',nullif(btrim(coalesce(target_comment,'')),'')));
  return po;
end;
$$;

-- Authenticated clients cannot bypass workflow commands with raw header/line mutations.
revoke insert,update,delete on public.purchase_orders,public.purchase_order_lines from authenticated;
revoke all on function public.create_purchase_order_draft(uuid,uuid,date,text,text,jsonb,text) from public;
revoke all on function public.update_purchase_order_draft(uuid,integer,uuid,date,text,text,jsonb,text) from public;
revoke all on function public.submit_purchase_order(uuid,integer,text) from public;
revoke all on function public.decide_purchase_order(uuid,text,text,text) from public;
grant execute on function public.create_purchase_order_draft(uuid,uuid,date,text,text,jsonb,text) to authenticated;
grant execute on function public.update_purchase_order_draft(uuid,integer,uuid,date,text,text,jsonb,text) to authenticated;
grant execute on function public.submit_purchase_order(uuid,integer,text) to authenticated;
grant execute on function public.decide_purchase_order(uuid,text,text,text) to authenticated;