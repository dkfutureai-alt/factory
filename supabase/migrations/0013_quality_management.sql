begin;

create table public.quality_inspection_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  item_id uuid,
  name text not null check (char_length(trim(name)) between 2 and 140),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  version text not null default 'V1' check (char_length(trim(version)) between 1 and 40),
  inspection_type text not null check (inspection_type in ('incoming','in_process','final')),
  sampling_method text not null default 'fixed' check (sampling_method in ('full','fixed','percentage','aql')),
  default_sample_size integer check (default_sample_size is null or default_sample_size > 0),
  sample_percentage numeric(8,4) check (sample_percentage is null or (sample_percentage > 0 and sample_percentage <= 100)),
  effective_from date,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code, version),
  unique (id, organization_id),
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  check ((sampling_method = 'percentage' and sample_percentage is not null) or sampling_method <> 'percentage')
);

create table public.quality_plan_checks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_id uuid not null,
  sequence_no integer not null check (sequence_no > 0),
  parameter_name text not null check (char_length(trim(parameter_name)) between 2 and 120),
  check_type text not null default 'visual' check (check_type in ('visual','numeric','boolean','text')),
  target_numeric numeric(18,6),
  min_numeric numeric(18,6),
  max_numeric numeric(18,6),
  unit_text text,
  expected_boolean boolean,
  acceptance_text text,
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_id, sequence_no),
  unique (id, organization_id),
  foreign key (plan_id, organization_id) references public.quality_inspection_plans(id, organization_id) on delete cascade,
  check (min_numeric is null or max_numeric is null or min_numeric <= max_numeric)
);

create table public.quality_inspections (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  inspection_no text not null default ('QI-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  plan_id uuid not null,
  inspection_type text not null check (inspection_type in ('incoming','in_process','final')),
  item_id uuid not null,
  production_order_id uuid,
  production_batch_id uuid,
  lot_batch_no text,
  sample_size integer not null default 1 check (sample_size > 0),
  status text not null default 'in_progress' check (status in ('draft','in_progress','completed','cancelled')),
  overall_result text not null default 'pending' check (overall_result in ('pending','pass','fail','hold')),
  inspector_employee_id uuid,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  remarks text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, inspection_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (plan_id, organization_id) references public.quality_inspection_plans(id, organization_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (production_order_id, factory_id) references public.production_orders(id, factory_id) on delete restrict,
  foreign key (production_batch_id, factory_id) references public.production_batches(id, factory_id) on delete restrict,
  foreign key (inspector_employee_id, organization_id) references public.employees(id, organization_id) on delete restrict,
  check ((status = 'completed' and overall_result <> 'pending' and completed_at is not null) or status <> 'completed'),
  check (completed_at is null or completed_at >= started_at)
);

create table public.quality_inspection_results (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  inspection_id uuid not null,
  plan_check_id uuid not null,
  result_status text not null check (result_status in ('pass','fail','not_applicable')),
  numeric_value numeric(18,6),
  boolean_value boolean,
  text_value text,
  remarks text,
  recorded_by uuid references auth.users(id) on delete set null,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (inspection_id, plan_check_id),
  unique (id, organization_id),
  foreign key (inspection_id, factory_id) references public.quality_inspections(id, factory_id) on delete restrict,
  foreign key (plan_check_id, organization_id) references public.quality_plan_checks(id, organization_id) on delete restrict
);

create table public.quality_ncrs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  ncr_no text not null default ('NCR-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  inspection_id uuid not null,
  item_id uuid not null,
  severity text not null default 'medium' check (severity in ('low','medium','high','critical')),
  category text not null check (char_length(trim(category)) between 2 and 80),
  description text not null check (char_length(trim(description)) between 4 and 2000),
  status text not null default 'open' check (status in ('open','investigating','action_pending','closed')),
  disposition text not null default 'pending' check (disposition in ('pending','rework','scrap','use_as_is','return','sort','other')),
  assigned_employee_id uuid,
  due_date date,
  root_cause text,
  corrective_action text,
  closed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, ncr_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (inspection_id, factory_id) references public.quality_inspections(id, factory_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (assigned_employee_id, organization_id) references public.employees(id, organization_id) on delete restrict,
  check ((status = 'closed' and closed_at is not null and disposition <> 'pending') or status <> 'closed')
);

create table public.quality_quarantine_lots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  inspection_id uuid not null,
  item_id uuid not null,
  source_location_id uuid not null,
  quarantine_location_id uuid not null,
  release_location_id uuid,
  quantity numeric(18,4) not null check (quantity > 0),
  lot_batch_no text,
  status text not null default 'quarantined' check (status in ('quarantined','released','rejected')),
  disposition text not null default 'pending' check (disposition in ('pending','release','rework','use_as_is','return','scrap')),
  quarantine_transaction_id uuid not null unique references public.inventory_transactions(id) on delete restrict,
  release_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  released_by uuid references auth.users(id) on delete set null,
  quarantined_at timestamptz not null default now(),
  released_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (inspection_id, factory_id) references public.quality_inspections(id, factory_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict,
  foreign key (source_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (quarantine_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  foreign key (release_location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  check (source_location_id <> quarantine_location_id),
  check ((status = 'released' and release_location_id is not null and release_transaction_id is not null and released_at is not null) or status <> 'released')
);

create table public.quality_certificates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  inspection_id uuid not null unique,
  item_id uuid not null,
  certificate_no text not null default ('COQ-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  lot_batch_no text,
  snapshot jsonb not null default '{}'::jsonb,
  issued_by uuid references auth.users(id) on delete set null,
  issued_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (organization_id, certificate_no),
  unique (id, organization_id),
  foreign key (inspection_id, factory_id) references public.quality_inspections(id, factory_id) on delete restrict,
  foreign key (item_id, organization_id) references public.inventory_items(id, organization_id) on delete restrict
);

create index quality_plans_org_type_idx on public.quality_inspection_plans(organization_id, inspection_type, is_active);
create index quality_inspections_factory_date_idx on public.quality_inspections(factory_id, started_at desc);
create index quality_inspections_result_idx on public.quality_inspections(factory_id, overall_result, status);
create index quality_results_inspection_idx on public.quality_inspection_results(inspection_id, occurred_at);
create index quality_ncr_factory_status_idx on public.quality_ncrs(factory_id, status, created_at desc);
create index quality_quarantine_factory_status_idx on public.quality_quarantine_lots(factory_id, status, quarantined_at desc);
create index quality_certificates_factory_date_idx on public.quality_certificates(factory_id, issued_at desc);

create trigger quality_plans_set_updated_at before update on public.quality_inspection_plans for each row execute function public.set_updated_at();
create trigger quality_plan_checks_set_updated_at before update on public.quality_plan_checks for each row execute function public.set_updated_at();
create trigger quality_inspections_set_updated_at before update on public.quality_inspections for each row execute function public.set_updated_at();
create trigger quality_results_set_updated_at before update on public.quality_inspection_results for each row execute function public.set_updated_at();
create trigger quality_ncrs_set_updated_at before update on public.quality_ncrs for each row execute function public.set_updated_at();
create trigger quality_quarantine_set_updated_at before update on public.quality_quarantine_lots for each row execute function public.set_updated_at();

create or replace function public.can_view_quality_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_view_inventory_factory(target_factory_id);
$$;
grant execute on function public.can_view_quality_factory(uuid) to authenticated;

create or replace function public.can_operate_quality_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_operate_production_factory(target_factory_id);
$$;
grant execute on function public.can_operate_quality_factory(uuid) to authenticated;

create or replace function public.can_approve_quality_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_manage_factory(target_factory_id)
    or exists (
      select 1
      from public.factory_members fm
      join public.organization_members om on om.organization_id=fm.organization_id and om.user_id=fm.user_id and om.is_active
      where fm.factory_id=target_factory_id and fm.user_id=auth.uid() and fm.is_active and om.role='supervisor'
    );
$$;
grant execute on function public.can_approve_quality_factory(uuid) to authenticated;

alter table public.quality_inspection_plans enable row level security;
alter table public.quality_plan_checks enable row level security;
alter table public.quality_inspections enable row level security;
alter table public.quality_inspection_results enable row level security;
alter table public.quality_ncrs enable row level security;
alter table public.quality_quarantine_lots enable row level security;
alter table public.quality_certificates enable row level security;

grant select,insert,update on public.quality_inspection_plans to authenticated;
grant select,insert,update,delete on public.quality_plan_checks to authenticated;
grant select on public.quality_inspections,public.quality_inspection_results,public.quality_ncrs,public.quality_quarantine_lots,public.quality_certificates to authenticated;

create policy quality_plans_select on public.quality_inspection_plans for select to authenticated using (public.is_org_member(organization_id));
create policy quality_plans_manage on public.quality_inspection_plans for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id,array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id,array['org_admin']::public.app_role[]));
create policy quality_plan_checks_select on public.quality_plan_checks for select to authenticated using (public.is_org_member(organization_id));
create policy quality_plan_checks_manage on public.quality_plan_checks for all to authenticated
using (public.is_platform_owner() or public.has_org_role(organization_id,array['org_admin']::public.app_role[]))
with check (public.is_platform_owner() or public.has_org_role(organization_id,array['org_admin']::public.app_role[]));
create policy quality_inspections_select on public.quality_inspections for select to authenticated using (public.can_view_quality_factory(factory_id));
create policy quality_results_select on public.quality_inspection_results for select to authenticated using (public.can_view_quality_factory(factory_id));
create policy quality_ncrs_select on public.quality_ncrs for select to authenticated using (public.can_view_quality_factory(factory_id));
create policy quality_quarantine_select on public.quality_quarantine_lots for select to authenticated using (public.can_view_quality_factory(factory_id));
create policy quality_certificates_select on public.quality_certificates for select to authenticated using (public.can_view_quality_factory(factory_id));

create or replace function public.prevent_quality_certificate_change()
returns trigger language plpgsql set search_path=public as $$ begin raise exception 'Quality certificates are immutable'; end; $$;
revoke all on function public.prevent_quality_certificate_change() from public;
create trigger quality_certificates_immutable before update or delete on public.quality_certificates for each row execute function public.prevent_quality_certificate_change();

create or replace function public.audit_quality_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_factory uuid; v_id text; v_meta jsonb;
begin
  v_org:=coalesce(new.organization_id,old.organization_id);
  if tg_table_name in ('quality_inspections','quality_inspection_results','quality_ncrs','quality_quarantine_lots','quality_certificates') then v_factory:=coalesce(new.factory_id,old.factory_id); end if;
  v_id:=coalesce(new.id,old.id)::text;
  if tg_op='INSERT' then v_meta:=jsonb_build_object('after',to_jsonb(new)); elsif tg_op='UPDATE' then v_meta:=jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new)); else v_meta:=jsonb_build_object('before',to_jsonb(old)); end if;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_org,v_factory,auth.uid(),lower(tg_op),tg_table_name,v_id,v_meta);
  return coalesce(new,old);
end; $$;
revoke all on function public.audit_quality_change() from public;

create trigger quality_plans_audit after insert or update or delete on public.quality_inspection_plans for each row execute function public.audit_quality_change();
create trigger quality_plan_checks_audit after insert or update or delete on public.quality_plan_checks for each row execute function public.audit_quality_change();
create trigger quality_inspections_audit after insert or update on public.quality_inspections for each row execute function public.audit_quality_change();
create trigger quality_results_audit after insert or update on public.quality_inspection_results for each row execute function public.audit_quality_change();
create trigger quality_ncrs_audit after insert or update on public.quality_ncrs for each row execute function public.audit_quality_change();
create trigger quality_quarantine_audit after insert or update on public.quality_quarantine_lots for each row execute function public.audit_quality_change();
create trigger quality_certificates_audit after insert on public.quality_certificates for each row execute function public.audit_quality_change();

create or replace function public.quality_start_inspection(
  p_factory_id uuid,
  p_plan_id uuid,
  p_item_id uuid default null,
  p_production_order_id uuid default null,
  p_production_batch_id uuid default null,
  p_lot_batch_no text default null,
  p_sample_size integer default null,
  p_inspector_employee_id uuid default null,
  p_notes text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_org uuid;
  v_plan public.quality_inspection_plans%rowtype;
  v_item uuid;
  v_order uuid;
  v_order_item uuid;
  v_batch_order uuid;
  v_batch_item uuid;
  v_inspector uuid;
  v_sample integer;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_operate_quality_factory(p_factory_id) then raise exception 'Not allowed for this factory'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  select * into v_plan from public.quality_inspection_plans where id=p_plan_id and organization_id=v_org and is_active;
  if not found then raise exception 'Active inspection plan not found'; end if;

  v_item:=coalesce(p_item_id,v_plan.item_id);
  v_order:=p_production_order_id;

  if p_production_batch_id is not null then
    select pb.order_id,po.product_item_id into v_batch_order,v_batch_item
    from public.production_batches pb join public.production_orders po on po.id=pb.order_id
    where pb.id=p_production_batch_id and pb.factory_id=p_factory_id;
    if v_batch_order is null then raise exception 'Production batch not found for factory'; end if;
    if v_order is not null and v_order<>v_batch_order then raise exception 'Production order does not match batch'; end if;
    v_order:=v_batch_order;
    if v_item is null then v_item:=v_batch_item; end if;
    if v_item<>v_batch_item then raise exception 'Inspection item must match production batch product'; end if;
  elsif v_order is not null then
    select product_item_id into v_order_item from public.production_orders where id=v_order and factory_id=p_factory_id;
    if v_order_item is null then raise exception 'Production order not found for factory'; end if;
    if v_item is null then v_item:=v_order_item; end if;
    if v_item<>v_order_item then raise exception 'Inspection item must match production order product'; end if;
  end if;

  if v_plan.inspection_type='incoming' and (v_order is not null or p_production_batch_id is not null) then raise exception 'Incoming inspection cannot link to production execution'; end if;
  if v_item is null then raise exception 'Inspection item is required'; end if;
  if v_plan.item_id is not null and v_plan.item_id<>v_item then raise exception 'Inspection item does not match plan'; end if;
  if not exists(select 1 from public.inventory_items where id=v_item and organization_id=v_org and is_active) then raise exception 'Active inspection item not found'; end if;

  v_sample:=coalesce(p_sample_size,v_plan.default_sample_size,1);
  if v_sample<=0 then raise exception 'Sample size must be greater than zero'; end if;

  v_inspector:=p_inspector_employee_id;
  if v_inspector is null then
    select id into v_inspector from public.employees where user_id=auth.uid() and status='active' and primary_factory_id=p_factory_id limit 1;
  end if;
  if v_inspector is not null and not exists(select 1 from public.employees where id=v_inspector and organization_id=v_org and status='active' and primary_factory_id=p_factory_id) then raise exception 'Inspector is not active in this factory'; end if;

  insert into public.quality_inspections(organization_id,factory_id,plan_id,inspection_type,item_id,production_order_id,production_batch_id,lot_batch_no,sample_size,status,overall_result,inspector_employee_id,started_at,remarks,created_by)
  values(v_org,p_factory_id,v_plan.id,v_plan.inspection_type,v_item,v_order,p_production_batch_id,nullif(trim(p_lot_batch_no),''),v_sample,'in_progress','pending',v_inspector,now(),nullif(trim(p_notes),''),auth.uid())
  returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.quality_start_inspection(uuid,uuid,uuid,uuid,uuid,text,integer,uuid,text) to authenticated;

create or replace function public.quality_record_result(
  p_inspection_id uuid,
  p_plan_check_id uuid,
  p_result_status text default null,
  p_numeric_value numeric default null,
  p_boolean_value boolean default null,
  p_text_value text default null,
  p_remarks text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_ins public.quality_inspections%rowtype;
  v_check public.quality_plan_checks%rowtype;
  v_status text;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_ins from public.quality_inspections where id=p_inspection_id for update;
  if not found or v_ins.status<>'in_progress' then raise exception 'Active inspection not found'; end if;
  if not public.can_operate_quality_factory(v_ins.factory_id) then raise exception 'Not allowed for this factory'; end if;
  select * into v_check from public.quality_plan_checks where id=p_plan_check_id and plan_id=v_ins.plan_id;
  if not found then raise exception 'Checklist parameter does not belong to inspection plan'; end if;

  if p_result_status='not_applicable' then
    if v_check.is_required then raise exception 'Required checklist parameter cannot be not applicable'; end if;
    v_status:='not_applicable';
  elsif v_check.check_type='numeric' then
    if p_numeric_value is null then raise exception 'Numeric result is required'; end if;
    v_status:=case when (v_check.min_numeric is not null and p_numeric_value<v_check.min_numeric) or (v_check.max_numeric is not null and p_numeric_value>v_check.max_numeric) then 'fail' else 'pass' end;
  elsif v_check.check_type='boolean' and v_check.expected_boolean is not null then
    if p_boolean_value is null then raise exception 'Boolean result is required'; end if;
    v_status:=case when p_boolean_value=v_check.expected_boolean then 'pass' else 'fail' end;
  else
    if p_result_status not in ('pass','fail') then raise exception 'Pass or fail result is required'; end if;
    v_status:=p_result_status;
  end if;

  insert into public.quality_inspection_results(organization_id,factory_id,inspection_id,plan_check_id,result_status,numeric_value,boolean_value,text_value,remarks,recorded_by,occurred_at)
  values(v_ins.organization_id,v_ins.factory_id,v_ins.id,v_check.id,v_status,p_numeric_value,p_boolean_value,nullif(trim(p_text_value),''),nullif(trim(p_remarks),''),auth.uid(),now())
  on conflict (inspection_id,plan_check_id) do update set result_status=excluded.result_status,numeric_value=excluded.numeric_value,boolean_value=excluded.boolean_value,text_value=excluded.text_value,remarks=excluded.remarks,recorded_by=excluded.recorded_by,occurred_at=excluded.occurred_at
  returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.quality_record_result(uuid,uuid,text,numeric,boolean,text,text) to authenticated;

create or replace function public.quality_complete_inspection(p_inspection_id uuid,p_hold boolean default false,p_remarks text default null)
returns text language plpgsql security definer set search_path=public as $$
declare
  v_ins public.quality_inspections%rowtype;
  v_missing integer;
  v_fail integer;
  v_result text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_ins from public.quality_inspections where id=p_inspection_id for update;
  if not found or v_ins.status<>'in_progress' then raise exception 'Active inspection not found'; end if;
  if not public.can_operate_quality_factory(v_ins.factory_id) then raise exception 'Not allowed for this factory'; end if;

  select count(*) into v_missing
  from public.quality_plan_checks c
  where c.plan_id=v_ins.plan_id and c.is_required
    and not exists(select 1 from public.quality_inspection_results r where r.inspection_id=v_ins.id and r.plan_check_id=c.id and r.result_status<>'not_applicable');
  if v_missing>0 then raise exception 'Complete all required checklist parameters first'; end if;

  select count(*) into v_fail from public.quality_inspection_results where inspection_id=v_ins.id and result_status='fail';
  v_result:=case when p_hold then 'hold' when v_fail>0 then 'fail' else 'pass' end;
  update public.quality_inspections set status='completed',overall_result=v_result,completed_at=now(),remarks=coalesce(nullif(trim(p_remarks),''),remarks) where id=v_ins.id;
  return v_result;
end; $$;
grant execute on function public.quality_complete_inspection(uuid,boolean,text) to authenticated;

create or replace function public.quality_create_ncr(
  p_inspection_id uuid,
  p_severity text,
  p_category text,
  p_description text,
  p_assigned_employee_id uuid default null,
  p_due_date date default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_ins public.quality_inspections%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_ins from public.quality_inspections where id=p_inspection_id;
  if not found then raise exception 'Inspection not found'; end if;
  if not public.can_operate_quality_factory(v_ins.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if v_ins.status<>'completed' or v_ins.overall_result not in ('fail','hold') then raise exception 'NCR requires a completed failed or held inspection'; end if;
  if p_severity not in ('low','medium','high','critical') then raise exception 'Invalid severity'; end if;
  if char_length(trim(coalesce(p_category,'')))<2 or char_length(trim(coalesce(p_description,'')))<4 then raise exception 'NCR category and description are required'; end if;
  if p_assigned_employee_id is not null and not exists(select 1 from public.employees where id=p_assigned_employee_id and organization_id=v_ins.organization_id and status='active' and primary_factory_id=v_ins.factory_id) then raise exception 'Assigned employee is not active in this factory'; end if;
  insert into public.quality_ncrs(organization_id,factory_id,inspection_id,item_id,severity,category,description,assigned_employee_id,due_date,created_by)
  values(v_ins.organization_id,v_ins.factory_id,v_ins.id,v_ins.item_id,p_severity,trim(p_category),trim(p_description),p_assigned_employee_id,p_due_date,auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.quality_create_ncr(uuid,text,text,text,uuid,date) to authenticated;

create or replace function public.quality_update_ncr(
  p_ncr_id uuid,
  p_status text,
  p_disposition text default 'pending',
  p_root_cause text default null,
  p_corrective_action text default null
)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_ncr public.quality_ncrs%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_ncr from public.quality_ncrs where id=p_ncr_id for update;
  if not found then raise exception 'NCR not found'; end if;
  if not public.can_approve_quality_factory(v_ncr.factory_id) then raise exception 'Quality approval access denied'; end if;
  if p_status not in ('open','investigating','action_pending','closed') then raise exception 'Invalid NCR status'; end if;
  if p_disposition not in ('pending','rework','scrap','use_as_is','return','sort','other') then raise exception 'Invalid NCR disposition'; end if;
  if p_status='closed' and p_disposition='pending' then raise exception 'Closed NCR requires a disposition'; end if;
  update public.quality_ncrs set status=p_status,disposition=p_disposition,root_cause=nullif(trim(p_root_cause),''),corrective_action=nullif(trim(p_corrective_action),''),closed_at=case when p_status='closed' then coalesce(closed_at,now()) else null end where id=v_ncr.id;
  return jsonb_build_object('id',v_ncr.id,'status',p_status,'disposition',p_disposition);
end; $$;
grant execute on function public.quality_update_ncr(uuid,text,text,text,text) to authenticated;

create or replace function public.quality_quarantine_stock(
  p_inspection_id uuid,
  p_from_location_id uuid,
  p_quarantine_location_id uuid,
  p_quantity numeric,
  p_lot_batch_no text default null,
  p_notes text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_ins public.quality_inspections%rowtype;
  v_available numeric(18,4);
  v_tx uuid;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  select * into v_ins from public.quality_inspections where id=p_inspection_id;
  if not found or v_ins.status<>'completed' or v_ins.overall_result not in ('fail','hold') then raise exception 'Quarantine requires a completed failed or held inspection'; end if;
  if not public.can_operate_quality_factory(v_ins.factory_id) then raise exception 'Not allowed for this factory'; end if;
  if p_from_location_id=p_quarantine_location_id then raise exception 'Source and quarantine locations must be different'; end if;
  if not exists(select 1 from public.stock_locations where id=p_from_location_id and factory_id=v_ins.factory_id and is_active) then raise exception 'Source location not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_quarantine_location_id and factory_id=v_ins.factory_id and is_active and location_type='quarantine') then raise exception 'Active quarantine location not found'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_ins.item_id::text||':'||p_from_location_id::text,0));
  select coalesce(sum(quantity_delta),0) into v_available from public.stock_ledger_entries where item_id=v_ins.item_id and location_id=p_from_location_id;
  if v_available<p_quantity then raise exception 'Insufficient stock: available %, requested %',v_available,p_quantity; end if;
  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,to_location_id,external_reference,notes,created_by)
  values(v_ins.organization_id,v_ins.factory_id,v_ins.item_id,'transfer',p_quantity,p_from_location_id,p_quarantine_location_id,v_ins.inspection_no,coalesce(nullif(trim(p_notes),''),'Quality quarantine'),auth.uid()) returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta) values
    (v_ins.organization_id,v_ins.factory_id,v_tx,v_ins.item_id,p_from_location_id,-p_quantity),
    (v_ins.organization_id,v_ins.factory_id,v_tx,v_ins.item_id,p_quarantine_location_id,p_quantity);
  insert into public.quality_quarantine_lots(organization_id,factory_id,inspection_id,item_id,source_location_id,quarantine_location_id,quantity,lot_batch_no,quarantine_transaction_id,notes,created_by)
  values(v_ins.organization_id,v_ins.factory_id,v_ins.id,v_ins.item_id,p_from_location_id,p_quarantine_location_id,p_quantity,coalesce(nullif(trim(p_lot_batch_no),''),v_ins.lot_batch_no),v_tx,nullif(trim(p_notes),''),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.quality_quarantine_stock(uuid,uuid,uuid,numeric,text,text) to authenticated;

create or replace function public.quality_release_quarantine(
  p_quarantine_id uuid,
  p_to_location_id uuid,
  p_disposition text default 'release',
  p_notes text default null
)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_q public.quality_quarantine_lots%rowtype;
  v_available numeric(18,4);
  v_tx uuid;
  v_open_ncr integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_q from public.quality_quarantine_lots where id=p_quarantine_id for update;
  if not found or v_q.status<>'quarantined' then raise exception 'Active quarantine lot not found'; end if;
  if not public.can_approve_quality_factory(v_q.factory_id) then raise exception 'Quality approval access denied'; end if;
  if p_disposition not in ('release','rework','use_as_is') then raise exception 'Release disposition must be release, rework or use_as_is'; end if;
  if not exists(select 1 from public.stock_locations where id=p_to_location_id and factory_id=v_q.factory_id and is_active and id<>v_q.quarantine_location_id) then raise exception 'Release destination not found'; end if;
  select count(*) into v_open_ncr from public.quality_ncrs where inspection_id=v_q.inspection_id and status<>'closed';
  if v_open_ncr>0 then raise exception 'Close linked NCRs before releasing quarantine'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_q.item_id::text||':'||v_q.quarantine_location_id::text,0));
  select coalesce(sum(quantity_delta),0) into v_available from public.stock_ledger_entries where item_id=v_q.item_id and location_id=v_q.quarantine_location_id;
  if v_available<v_q.quantity then raise exception 'Quarantine stock is no longer available'; end if;
  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,to_location_id,external_reference,notes,created_by)
  values(v_q.organization_id,v_q.factory_id,v_q.item_id,'transfer',v_q.quantity,v_q.quarantine_location_id,p_to_location_id,'QUALITY-RELEASE',coalesce(nullif(trim(p_notes),''),'Quality release'),auth.uid()) returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta) values
    (v_q.organization_id,v_q.factory_id,v_tx,v_q.item_id,v_q.quarantine_location_id,-v_q.quantity),
    (v_q.organization_id,v_q.factory_id,v_tx,v_q.item_id,p_to_location_id,v_q.quantity);
  update public.quality_quarantine_lots set status='released',disposition=p_disposition,release_location_id=p_to_location_id,release_transaction_id=v_tx,released_by=auth.uid(),released_at=now(),notes=coalesce(nullif(trim(p_notes),''),notes) where id=v_q.id;
  return jsonb_build_object('id',v_q.id,'status','released','inventory_transaction_id',v_tx);
end; $$;
grant execute on function public.quality_release_quarantine(uuid,uuid,text,text) to authenticated;

create or replace function public.quality_issue_certificate(p_inspection_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_ins public.quality_inspections%rowtype;
  v_existing uuid;
  v_id uuid;
  v_snapshot jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_ins from public.quality_inspections where id=p_inspection_id;
  if not found or v_ins.status<>'completed' or v_ins.overall_result<>'pass' then raise exception 'Certificate requires a completed passed inspection'; end if;
  if not public.can_approve_quality_factory(v_ins.factory_id) then raise exception 'Quality approval access denied'; end if;
  select id into v_existing from public.quality_certificates where inspection_id=v_ins.id;
  if v_existing is not null then return v_existing; end if;
  select jsonb_build_object(
    'inspection_no',v_ins.inspection_no,
    'inspection_type',v_ins.inspection_type,
    'lot_batch_no',v_ins.lot_batch_no,
    'sample_size',v_ins.sample_size,
    'completed_at',v_ins.completed_at,
    'item',(select jsonb_build_object('id',i.id,'sku',i.sku,'name',i.name) from public.inventory_items i where i.id=v_ins.item_id),
    'plan',(select jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'version',p.version) from public.quality_inspection_plans p where p.id=v_ins.plan_id),
    'results',coalesce((select jsonb_agg(jsonb_build_object('parameter',c.parameter_name,'result',r.result_status,'numeric_value',r.numeric_value,'boolean_value',r.boolean_value,'text_value',r.text_value,'unit',c.unit_text,'remarks',r.remarks) order by c.sequence_no) from public.quality_inspection_results r join public.quality_plan_checks c on c.id=r.plan_check_id where r.inspection_id=v_ins.id),'[]'::jsonb)
  ) into v_snapshot;
  insert into public.quality_certificates(organization_id,factory_id,inspection_id,item_id,lot_batch_no,snapshot,issued_by)
  values(v_ins.organization_id,v_ins.factory_id,v_ins.id,v_ins.item_id,v_ins.lot_batch_no,v_snapshot,auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.quality_issue_certificate(uuid) to authenticated;

create or replace function public.quality_dashboard_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_quality_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  select jsonb_build_object(
    'today_inspections',(select count(*) from public.quality_inspections q where q.organization_id=p_organization_id and q.started_at>=date_trunc('day',now()) and (p_factory_id is null or q.factory_id=p_factory_id) and public.can_view_quality_factory(q.factory_id)),
    'today_passed',(select count(*) from public.quality_inspections q where q.organization_id=p_organization_id and q.completed_at>=date_trunc('day',now()) and q.overall_result='pass' and (p_factory_id is null or q.factory_id=p_factory_id) and public.can_view_quality_factory(q.factory_id)),
    'today_failed',(select count(*) from public.quality_inspections q where q.organization_id=p_organization_id and q.completed_at>=date_trunc('day',now()) and q.overall_result='fail' and (p_factory_id is null or q.factory_id=p_factory_id) and public.can_view_quality_factory(q.factory_id)),
    'today_hold',(select count(*) from public.quality_inspections q where q.organization_id=p_organization_id and q.completed_at>=date_trunc('day',now()) and q.overall_result='hold' and (p_factory_id is null or q.factory_id=p_factory_id) and public.can_view_quality_factory(q.factory_id)),
    'open_ncr',(select count(*) from public.quality_ncrs n where n.organization_id=p_organization_id and n.status<>'closed' and (p_factory_id is null or n.factory_id=p_factory_id) and public.can_view_quality_factory(n.factory_id)),
    'quarantine_quantity',coalesce((select sum(q.quantity) from public.quality_quarantine_lots q where q.organization_id=p_organization_id and q.status='quarantined' and (p_factory_id is null or q.factory_id=p_factory_id) and public.can_view_quality_factory(q.factory_id)),0)
  ) into result;
  return result;
end; $$;
grant execute on function public.quality_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.quality_inspection_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 200)
returns table(inspection_id uuid,inspection_no text,factory_id uuid,item_id uuid,item_name text,inspection_type text,plan_name text,plan_version text,lot_batch_no text,sample_size integer,status text,overall_result text,started_at timestamptz,completed_at timestamptz,inspector_name text)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_quality_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  return query
  select q.id,q.inspection_no,q.factory_id,q.item_id,i.name,q.inspection_type,p.name,p.version,q.lot_batch_no,q.sample_size,q.status,q.overall_result,q.started_at,q.completed_at,e.full_name
  from public.quality_inspections q
  join public.inventory_items i on i.id=q.item_id
  join public.quality_inspection_plans p on p.id=q.plan_id
  left join public.employees e on e.id=q.inspector_employee_id
  where q.organization_id=p_organization_id and (p_factory_id is null or q.factory_id=p_factory_id) and public.can_view_quality_factory(q.factory_id)
  order by q.started_at desc limit greatest(1,least(coalesce(p_limit,200),1000));
end; $$;
grant execute on function public.quality_inspection_report(uuid,uuid,integer) to authenticated;

create or replace function public.quality_ncr_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 200)
returns table(ncr_id uuid,ncr_no text,factory_id uuid,inspection_no text,item_name text,severity text,category text,status text,disposition text,due_date date,created_at timestamptz,closed_at timestamptz)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_factory_id is not null and not public.can_view_quality_factory(p_factory_id) then raise exception 'Factory access denied'; end if;
  return query
  select n.id,n.ncr_no,n.factory_id,q.inspection_no,i.name,n.severity,n.category,n.status,n.disposition,n.due_date,n.created_at,n.closed_at
  from public.quality_ncrs n
  join public.quality_inspections q on q.id=n.inspection_id
  join public.inventory_items i on i.id=n.item_id
  where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and public.can_view_quality_factory(n.factory_id)
  order by n.created_at desc limit greatest(1,least(coalesce(p_limit,200),1000));
end; $$;
grant execute on function public.quality_ncr_report(uuid,uuid,integer) to authenticated;

commit;