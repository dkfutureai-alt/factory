begin;

-- Phase 11: Maintenance — assets, requests, PM plans, work orders, downtime and ledger-backed spare usage.

create table public.maintenance_assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  asset_code text not null check (asset_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name text not null check (char_length(trim(name)) between 2 and 140),
  asset_type text not null default 'equipment' check (asset_type in ('machine','equipment','utility','tool','other')),
  work_center_id uuid,
  location_id uuid,
  manufacturer text,
  model text,
  serial_no text,
  criticality text not null default 'medium' check (criticality in ('low','medium','high','critical')),
  status text not null default 'running' check (status in ('running','idle','maintenance','down','retired')),
  installed_on date,
  warranty_until date,
  last_service_at timestamptz,
  next_service_at timestamptz,
  qr_code text,
  notes text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (factory_id, asset_code),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (work_center_id, factory_id) references public.work_centers(id, factory_id) on delete restrict,
  foreign key (location_id, factory_id) references public.stock_locations(id, factory_id) on delete restrict,
  check (warranty_until is null or installed_on is null or warranty_until >= installed_on)
);
create unique index maintenance_assets_org_qr_unique on public.maintenance_assets(organization_id, qr_code) where qr_code is not null;
create index maintenance_assets_factory_status_idx on public.maintenance_assets(factory_id, status, criticality);

create table public.maintenance_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  request_no text not null default ('MR-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  asset_id uuid not null,
  requested_by_employee_id uuid,
  issue_type text not null default 'other' check (issue_type in ('mechanical','electrical','safety','performance','leak','noise','other')),
  priority text not null default 'medium' check (priority in ('low','medium','high','critical')),
  description text not null check (char_length(trim(description)) between 3 and 1000),
  status text not null default 'open' check (status in ('open','approved','rejected','converted','cancelled')),
  decision_note text,
  decided_by uuid references auth.users(id) on delete set null,
  decided_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, request_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (asset_id, factory_id) references public.maintenance_assets(id, factory_id) on delete restrict,
  foreign key (requested_by_employee_id, organization_id) references public.employees(id, organization_id) on delete restrict,
  check ((status in ('approved','rejected','cancelled') and decided_at is not null) or status not in ('approved','rejected','cancelled'))
);
create index maintenance_requests_factory_status_idx on public.maintenance_requests(factory_id,status,created_at desc);

create table public.maintenance_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  plan_no text not null default ('PM-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  asset_id uuid not null,
  name text not null check (char_length(trim(name)) between 2 and 160),
  maintenance_type text not null default 'preventive' check (maintenance_type in ('preventive','inspection','calibration')),
  frequency_unit text not null check (frequency_unit in ('days','weeks','months')),
  frequency_value integer not null check (frequency_value between 1 and 365),
  next_due_date date not null,
  last_completed_at timestamptz,
  default_technician_employee_id uuid,
  default_priority text not null default 'medium' check (default_priority in ('low','medium','high','critical')),
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes between 1 and 10080),
  instructions text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, plan_no),
  unique (id, organization_id),
  unique (id, factory_id),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete restrict,
  foreign key (asset_id, factory_id) references public.maintenance_assets(id, factory_id) on delete restrict,
  foreign key (default_technician_employee_id, organization_id) references public.employees(id, organization_id) on delete restrict
);
create index maintenance_plans_factory_due_idx on public.maintenance_plans(factory_id,next_due_date) where is_active;

create table public.maintenance_plan_tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  plan_id uuid not null,
  sequence_no integer not null check (sequence_no between 1 and 999),
  instruction text not null check (char_length(trim(instruction)) between 2 and 500),
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  unique (plan_id,sequence_no),
  unique (id,organization_id),
  foreign key (plan_id,organization_id) references public.maintenance_plans(id,organization_id) on delete cascade
);

create table public.maintenance_work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  work_order_no text not null default ('MWO-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  asset_id uuid not null,
  request_id uuid unique,
  plan_id uuid,
  maintenance_type text not null check (maintenance_type in ('corrective','preventive','inspection','calibration')),
  priority text not null default 'medium' check (priority in ('low','medium','high','critical')),
  status text not null default 'open' check (status in ('open','assigned','in_progress','on_hold','completed','cancelled')),
  assigned_employee_id uuid,
  scheduled_at timestamptz,
  due_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  problem_description text not null check (char_length(trim(problem_description)) between 3 and 1000),
  resolution_notes text,
  failure_code text,
  labor_minutes integer not null default 0 check (labor_minutes between 0 and 100000),
  external_cost numeric(18,2) not null default 0 check (external_cost >= 0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,work_order_no),
  unique (id,organization_id),
  unique (id,factory_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (asset_id,factory_id) references public.maintenance_assets(id,factory_id) on delete restrict,
  foreign key (request_id,factory_id) references public.maintenance_requests(id,factory_id) on delete restrict,
  foreign key (plan_id,factory_id) references public.maintenance_plans(id,factory_id) on delete restrict,
  foreign key (assigned_employee_id,organization_id) references public.employees(id,organization_id) on delete restrict,
  check (due_at is null or scheduled_at is null or due_at >= scheduled_at),
  check ((status='completed' and completed_at is not null and char_length(trim(coalesce(resolution_notes,''))) >= 3) or status<>'completed')
);
create index maintenance_work_orders_factory_status_idx on public.maintenance_work_orders(factory_id,status,due_at);
create index maintenance_work_orders_assignee_idx on public.maintenance_work_orders(assigned_employee_id,status) where assigned_employee_id is not null;

create table public.maintenance_work_order_tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  work_order_id uuid not null,
  sequence_no integer not null check (sequence_no between 1 and 999),
  instruction text not null check (char_length(trim(instruction)) between 2 and 500),
  is_required boolean not null default true,
  completed_at timestamptz,
  completed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (work_order_id,sequence_no),
  unique (id,organization_id),
  foreign key (work_order_id,organization_id) references public.maintenance_work_orders(id,organization_id) on delete cascade
);

create table public.maintenance_work_updates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  work_order_id uuid not null,
  status_snapshot text not null check (status_snapshot in ('open','assigned','in_progress','on_hold','completed','cancelled')),
  note text not null check (char_length(trim(note)) between 2 and 1000),
  photo_ref text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (work_order_id,factory_id) references public.maintenance_work_orders(id,factory_id) on delete cascade
);
create index maintenance_updates_work_order_idx on public.maintenance_work_updates(work_order_id,created_at desc);

create table public.maintenance_spare_usage (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  work_order_id uuid not null,
  item_id uuid not null,
  source_location_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  unit_cost numeric(18,2) check (unit_cost is null or unit_cost >= 0),
  line_cost numeric(18,2) not null default 0 check (line_cost >= 0),
  inventory_transaction_id uuid not null unique references public.inventory_transactions(id) on delete restrict,
  used_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (work_order_id,factory_id) references public.maintenance_work_orders(id,factory_id) on delete restrict,
  foreign key (item_id,organization_id) references public.inventory_items(id,organization_id) on delete restrict,
  foreign key (source_location_id,factory_id) references public.stock_locations(id,factory_id) on delete restrict
);
create index maintenance_spares_work_order_idx on public.maintenance_spare_usage(work_order_id,created_at desc);

create table public.maintenance_downtime_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  work_order_id uuid not null,
  asset_id uuid not null,
  reason text not null check (char_length(trim(reason)) between 2 and 500),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  created_by uuid references auth.users(id) on delete set null,
  closed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (id,organization_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (work_order_id,factory_id) references public.maintenance_work_orders(id,factory_id) on delete restrict,
  foreign key (asset_id,factory_id) references public.maintenance_assets(id,factory_id) on delete restrict,
  check ((ended_at is null and duration_minutes is null) or (ended_at is not null and ended_at >= started_at and duration_minutes is not null))
);
create unique index maintenance_one_open_downtime_per_work_order on public.maintenance_downtime_events(work_order_id) where ended_at is null;
create index maintenance_downtime_factory_date_idx on public.maintenance_downtime_events(factory_id,started_at desc);

create trigger maintenance_assets_set_updated_at before update on public.maintenance_assets for each row execute function public.set_updated_at();
create trigger maintenance_requests_set_updated_at before update on public.maintenance_requests for each row execute function public.set_updated_at();
create trigger maintenance_plans_set_updated_at before update on public.maintenance_plans for each row execute function public.set_updated_at();
create trigger maintenance_work_orders_set_updated_at before update on public.maintenance_work_orders for each row execute function public.set_updated_at();

create or replace function public.maintenance_current_employee_id(p_factory_id uuid)
returns uuid language sql stable security definer set search_path=public as $$
  select e.id
  from public.employees e
  where e.user_id=auth.uid()
    and e.primary_factory_id=p_factory_id
    and e.status='active'
  limit 1;
$$;
grant execute on function public.maintenance_current_employee_id(uuid) to authenticated;

create or replace function public.maintenance_can_plan_factory(p_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_manage_factory(p_factory_id)
    or exists(
      select 1
      from public.factory_members fm
      join public.organization_members om on om.organization_id=fm.organization_id and om.user_id=fm.user_id and om.is_active
      where fm.factory_id=p_factory_id and fm.user_id=auth.uid() and fm.is_active and om.role='supervisor'
    );
$$;
grant execute on function public.maintenance_can_plan_factory(uuid) to authenticated;

create or replace function public.maintenance_can_view_request(p_request_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.maintenance_requests r
    where r.id=p_request_id
      and (
        public.maintenance_can_plan_factory(r.factory_id)
        or r.requested_by_employee_id=public.maintenance_current_employee_id(r.factory_id)
      )
  );
$$;
grant execute on function public.maintenance_can_view_request(uuid) to authenticated;

create or replace function public.maintenance_can_execute_work_order(p_work_order_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.maintenance_work_orders w
    where w.id=p_work_order_id
      and (
        public.maintenance_can_plan_factory(w.factory_id)
        or w.assigned_employee_id=public.maintenance_current_employee_id(w.factory_id)
      )
  );
$$;
grant execute on function public.maintenance_can_execute_work_order(uuid) to authenticated;

create or replace function public.maintenance_can_view_work_order(p_work_order_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.maintenance_can_execute_work_order(p_work_order_id);
$$;
grant execute on function public.maintenance_can_view_work_order(uuid) to authenticated;

alter table public.maintenance_assets enable row level security;
alter table public.maintenance_requests enable row level security;
alter table public.maintenance_plans enable row level security;
alter table public.maintenance_plan_tasks enable row level security;
alter table public.maintenance_work_orders enable row level security;
alter table public.maintenance_work_order_tasks enable row level security;
alter table public.maintenance_work_updates enable row level security;
alter table public.maintenance_spare_usage enable row level security;
alter table public.maintenance_downtime_events enable row level security;

grant select on public.maintenance_assets,public.maintenance_requests,public.maintenance_plans,public.maintenance_plan_tasks,public.maintenance_work_orders,public.maintenance_work_order_tasks,public.maintenance_work_updates,public.maintenance_spare_usage,public.maintenance_downtime_events to authenticated;

create policy maintenance_assets_select on public.maintenance_assets for select to authenticated using (public.can_view_inventory_factory(factory_id));
create policy maintenance_requests_select on public.maintenance_requests for select to authenticated using (public.maintenance_can_view_request(id));
create policy maintenance_plans_select on public.maintenance_plans for select to authenticated using (public.can_view_inventory_factory(factory_id));
create policy maintenance_plan_tasks_select on public.maintenance_plan_tasks for select to authenticated using (exists(select 1 from public.maintenance_plans p where p.id=plan_id and public.can_view_inventory_factory(p.factory_id)));
create policy maintenance_work_orders_select on public.maintenance_work_orders for select to authenticated using (public.maintenance_can_view_work_order(id));
create policy maintenance_work_order_tasks_select on public.maintenance_work_order_tasks for select to authenticated using (public.maintenance_can_view_work_order(work_order_id));
create policy maintenance_work_updates_select on public.maintenance_work_updates for select to authenticated using (public.maintenance_can_view_work_order(work_order_id));
create policy maintenance_spare_usage_select on public.maintenance_spare_usage for select to authenticated using (public.maintenance_can_view_work_order(work_order_id));
create policy maintenance_downtime_select on public.maintenance_downtime_events for select to authenticated using (public.maintenance_can_view_work_order(work_order_id));

create or replace function public.audit_maintenance_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_factory uuid; v_id text; v_payload jsonb;
begin
  v_org:=coalesce(new.organization_id,old.organization_id);
  v_factory:=coalesce(new.factory_id,old.factory_id);
  v_id:=coalesce(new.id,old.id)::text;
  if tg_op='INSERT' then v_payload:=jsonb_build_object('after',to_jsonb(new));
  elsif tg_op='UPDATE' then v_payload:=jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new));
  else v_payload:=jsonb_build_object('before',to_jsonb(old)); end if;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_org,v_factory,auth.uid(),lower(tg_op),tg_table_name,v_id,v_payload);
  return coalesce(new,old);
end; $$;
revoke all on function public.audit_maintenance_change() from public;
create trigger maintenance_assets_audit after insert or update on public.maintenance_assets for each row execute function public.audit_maintenance_change();
create trigger maintenance_requests_audit after insert or update on public.maintenance_requests for each row execute function public.audit_maintenance_change();
create trigger maintenance_plans_audit after insert or update on public.maintenance_plans for each row execute function public.audit_maintenance_change();
create trigger maintenance_work_orders_audit after insert or update on public.maintenance_work_orders for each row execute function public.audit_maintenance_change();

create or replace function public.maintenance_create_asset(
  p_factory_id uuid,p_asset_code text,p_name text,p_asset_type text default 'equipment',p_work_center_id uuid default null,p_location_id uuid default null,
  p_manufacturer text default null,p_model text default null,p_serial_no text default null,p_criticality text default 'medium',p_qr_code text default null,p_notes text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_factory(p_factory_id) then raise exception 'Maintenance asset management access required'; end if;
  select organization_id into v_org from public.factories where id=p_factory_id and is_active;
  if v_org is null then raise exception 'Factory not found'; end if;
  if p_work_center_id is not null and not exists(select 1 from public.work_centers where id=p_work_center_id and factory_id=p_factory_id and is_active) then raise exception 'Work center not found'; end if;
  if p_location_id is not null and not exists(select 1 from public.stock_locations where id=p_location_id and factory_id=p_factory_id and is_active) then raise exception 'Location not found'; end if;
  insert into public.maintenance_assets(organization_id,factory_id,asset_code,name,asset_type,work_center_id,location_id,manufacturer,model,serial_no,criticality,qr_code,notes,created_by)
  values(v_org,p_factory_id,upper(trim(p_asset_code)),trim(p_name),p_asset_type,p_work_center_id,p_location_id,nullif(trim(coalesce(p_manufacturer,'')),''),nullif(trim(coalesce(p_model,'')),''),nullif(trim(coalesce(p_serial_no,'')),''),p_criticality,nullif(trim(coalesce(p_qr_code,'')),''),nullif(trim(coalesce(p_notes,'')),''),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.maintenance_create_asset(uuid,text,text,text,uuid,uuid,text,text,text,text,text,text) to authenticated;

create or replace function public.maintenance_update_asset(
  p_asset_id uuid,p_name text,p_asset_type text,p_work_center_id uuid,p_location_id uuid,p_manufacturer text,p_model text,p_serial_no text,p_criticality text,p_qr_code text,p_notes text,p_is_active boolean
)
returns void language plpgsql security definer set search_path=public as $$
declare v_asset public.maintenance_assets%rowtype;
begin
  select * into v_asset from public.maintenance_assets where id=p_asset_id for update;
  if v_asset.id is null then raise exception 'Asset not found'; end if;
  if not public.can_manage_factory(v_asset.factory_id) then raise exception 'Maintenance asset management access required'; end if;
  if p_work_center_id is not null and not exists(select 1 from public.work_centers where id=p_work_center_id and factory_id=v_asset.factory_id and is_active) then raise exception 'Work center not found'; end if;
  if p_location_id is not null and not exists(select 1 from public.stock_locations where id=p_location_id and factory_id=v_asset.factory_id and is_active) then raise exception 'Location not found'; end if;
  update public.maintenance_assets set name=trim(p_name),asset_type=p_asset_type,work_center_id=p_work_center_id,location_id=p_location_id,manufacturer=nullif(trim(coalesce(p_manufacturer,'')),''),model=nullif(trim(coalesce(p_model,'')),''),serial_no=nullif(trim(coalesce(p_serial_no,'')),''),criticality=p_criticality,qr_code=nullif(trim(coalesce(p_qr_code,'')),''),notes=nullif(trim(coalesce(p_notes,'')),''),is_active=p_is_active where id=p_asset_id;
end; $$;
grant execute on function public.maintenance_update_asset(uuid,text,text,uuid,uuid,text,text,text,text,text,text,boolean) to authenticated;

create or replace function public.maintenance_create_request(p_asset_id uuid,p_issue_type text,p_priority text,p_description text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_asset public.maintenance_assets%rowtype; v_employee uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_asset from public.maintenance_assets where id=p_asset_id and is_active;
  if v_asset.id is null then raise exception 'Active asset not found'; end if;
  if not public.can_view_inventory_factory(v_asset.factory_id) then raise exception 'Factory access denied'; end if;
  v_employee:=public.maintenance_current_employee_id(v_asset.factory_id);
  if v_employee is null and not public.maintenance_can_plan_factory(v_asset.factory_id) then raise exception 'Active employee record required'; end if;
  insert into public.maintenance_requests(organization_id,factory_id,asset_id,requested_by_employee_id,issue_type,priority,description,created_by)
  values(v_asset.organization_id,v_asset.factory_id,v_asset.id,v_employee,p_issue_type,p_priority,trim(p_description),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.maintenance_create_request(uuid,text,text,text) to authenticated;

create or replace function public.maintenance_decide_request(p_request_id uuid,p_decision text,p_note text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_r public.maintenance_requests%rowtype;
begin
  select * into v_r from public.maintenance_requests where id=p_request_id for update;
  if v_r.id is null then raise exception 'Maintenance request not found'; end if;
  if not public.maintenance_can_plan_factory(v_r.factory_id) then raise exception 'Maintenance planning access required'; end if;
  if v_r.status<>'open' then raise exception 'Only open requests can be decided'; end if;
  if p_decision not in ('approved','rejected','cancelled') then raise exception 'Invalid request decision'; end if;
  update public.maintenance_requests set status=p_decision,decision_note=nullif(trim(coalesce(p_note,'')),''),decided_by=auth.uid(),decided_at=now() where id=v_r.id;
end; $$;
grant execute on function public.maintenance_decide_request(uuid,text,text) to authenticated;

create or replace function public.maintenance_create_plan(
  p_asset_id uuid,p_name text,p_maintenance_type text,p_frequency_unit text,p_frequency_value integer,p_next_due_date date,p_default_technician_employee_id uuid default null,
  p_default_priority text default 'medium',p_estimated_minutes integer default null,p_instructions text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_asset public.maintenance_assets%rowtype; v_id uuid;
begin
  select * into v_asset from public.maintenance_assets where id=p_asset_id and is_active;
  if v_asset.id is null then raise exception 'Active asset not found'; end if;
  if not public.maintenance_can_plan_factory(v_asset.factory_id) then raise exception 'Maintenance planning access required'; end if;
  if p_default_technician_employee_id is not null and not exists(select 1 from public.employees where id=p_default_technician_employee_id and organization_id=v_asset.organization_id and primary_factory_id=v_asset.factory_id and status='active') then raise exception 'Technician not found in factory'; end if;
  insert into public.maintenance_plans(organization_id,factory_id,asset_id,name,maintenance_type,frequency_unit,frequency_value,next_due_date,default_technician_employee_id,default_priority,estimated_minutes,instructions,created_by)
  values(v_asset.organization_id,v_asset.factory_id,v_asset.id,trim(p_name),p_maintenance_type,p_frequency_unit,p_frequency_value,p_next_due_date,p_default_technician_employee_id,p_default_priority,p_estimated_minutes,nullif(trim(coalesce(p_instructions,'')),''),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.maintenance_create_plan(uuid,text,text,text,integer,date,uuid,text,integer,text) to authenticated;

create or replace function public.maintenance_add_plan_task(p_plan_id uuid,p_instruction text,p_is_required boolean default true)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_plan public.maintenance_plans%rowtype; v_id uuid; v_seq integer;
begin
  select * into v_plan from public.maintenance_plans where id=p_plan_id;
  if v_plan.id is null then raise exception 'Maintenance plan not found'; end if;
  if not public.maintenance_can_plan_factory(v_plan.factory_id) then raise exception 'Maintenance planning access required'; end if;
  select coalesce(max(sequence_no),0)+1 into v_seq from public.maintenance_plan_tasks where plan_id=v_plan.id;
  insert into public.maintenance_plan_tasks(organization_id,plan_id,sequence_no,instruction,is_required) values(v_plan.organization_id,v_plan.id,v_seq,trim(p_instruction),p_is_required) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.maintenance_add_plan_task(uuid,text,boolean) to authenticated;

create or replace function public.maintenance_create_work_order(
  p_asset_id uuid,p_maintenance_type text,p_priority text,p_problem_description text,p_assigned_employee_id uuid default null,p_request_id uuid default null,p_plan_id uuid default null,p_scheduled_at timestamptz default null,p_due_at timestamptz default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_asset public.maintenance_assets%rowtype; v_req public.maintenance_requests%rowtype; v_plan public.maintenance_plans%rowtype; v_id uuid; v_status text;
begin
  select * into v_asset from public.maintenance_assets where id=p_asset_id and is_active;
  if v_asset.id is null then raise exception 'Active asset not found'; end if;
  if not public.maintenance_can_plan_factory(v_asset.factory_id) then raise exception 'Maintenance planning access required'; end if;
  if p_assigned_employee_id is not null and not exists(select 1 from public.employees where id=p_assigned_employee_id and organization_id=v_asset.organization_id and primary_factory_id=v_asset.factory_id and status='active') then raise exception 'Assigned technician not found in factory'; end if;
  if p_request_id is not null then
    select * into v_req from public.maintenance_requests where id=p_request_id and factory_id=v_asset.factory_id for update;
    if v_req.id is null or v_req.asset_id<>v_asset.id then raise exception 'Maintenance request does not match asset'; end if;
    if v_req.status not in ('open','approved') then raise exception 'Maintenance request is not convertible'; end if;
  end if;
  if p_plan_id is not null then
    select * into v_plan from public.maintenance_plans where id=p_plan_id and factory_id=v_asset.factory_id and is_active;
    if v_plan.id is null or v_plan.asset_id<>v_asset.id then raise exception 'Maintenance plan does not match asset'; end if;
  end if;
  v_status:=case when p_assigned_employee_id is null then 'open' else 'assigned' end;
  insert into public.maintenance_work_orders(organization_id,factory_id,asset_id,request_id,plan_id,maintenance_type,priority,status,assigned_employee_id,scheduled_at,due_at,problem_description,created_by)
  values(v_asset.organization_id,v_asset.factory_id,v_asset.id,p_request_id,p_plan_id,p_maintenance_type,p_priority,v_status,p_assigned_employee_id,p_scheduled_at,p_due_at,trim(p_problem_description),auth.uid()) returning id into v_id;
  if p_plan_id is not null then
    insert into public.maintenance_work_order_tasks(organization_id,work_order_id,sequence_no,instruction,is_required)
    select v_asset.organization_id,v_id,sequence_no,instruction,is_required from public.maintenance_plan_tasks where plan_id=p_plan_id order by sequence_no;
  end if;
  if p_request_id is not null then update public.maintenance_requests set status='converted',decided_by=auth.uid(),decided_at=now() where id=p_request_id; end if;
  return v_id;
end; $$;
grant execute on function public.maintenance_create_work_order(uuid,text,text,text,uuid,uuid,uuid,timestamptz,timestamptz) to authenticated;

create or replace function public.maintenance_assign_work_order(p_work_order_id uuid,p_employee_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_w public.maintenance_work_orders%rowtype;
begin
  select * into v_w from public.maintenance_work_orders where id=p_work_order_id for update;
  if v_w.id is null then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_plan_factory(v_w.factory_id) then raise exception 'Maintenance planning access required'; end if;
  if v_w.status in ('completed','cancelled') then raise exception 'Closed work order cannot be assigned'; end if;
  if not exists(select 1 from public.employees where id=p_employee_id and organization_id=v_w.organization_id and primary_factory_id=v_w.factory_id and status='active') then raise exception 'Technician not found in factory'; end if;
  update public.maintenance_work_orders set assigned_employee_id=p_employee_id,status=case when status='open' then 'assigned' else status end where id=v_w.id;
end; $$;
grant execute on function public.maintenance_assign_work_order(uuid,uuid) to authenticated;

create or replace function public.maintenance_start_work_order(p_work_order_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_w public.maintenance_work_orders%rowtype;
begin
  select * into v_w from public.maintenance_work_orders where id=p_work_order_id for update;
  if v_w.id is null then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_execute_work_order(v_w.id) then raise exception 'Work order execution access denied'; end if;
  if v_w.status not in ('open','assigned','on_hold') then raise exception 'Work order cannot be started'; end if;
  update public.maintenance_work_orders set status='in_progress',started_at=coalesce(started_at,now()) where id=v_w.id;
  update public.maintenance_assets set status='maintenance' where id=v_w.asset_id and status<>'retired';
  insert into public.maintenance_work_updates(organization_id,factory_id,work_order_id,status_snapshot,note,created_by) values(v_w.organization_id,v_w.factory_id,v_w.id,'in_progress','Work order started',auth.uid());
end; $$;
grant execute on function public.maintenance_start_work_order(uuid) to authenticated;

create or replace function public.maintenance_hold_work_order(p_work_order_id uuid,p_note text)
returns void language plpgsql security definer set search_path=public as $$
declare v_w public.maintenance_work_orders%rowtype;
begin
  select * into v_w from public.maintenance_work_orders where id=p_work_order_id for update;
  if v_w.id is null then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_execute_work_order(v_w.id) then raise exception 'Work order execution access denied'; end if;
  if v_w.status<>'in_progress' then raise exception 'Only in-progress work orders can be held'; end if;
  update public.maintenance_work_orders set status='on_hold' where id=v_w.id;
  insert into public.maintenance_work_updates(organization_id,factory_id,work_order_id,status_snapshot,note,created_by) values(v_w.organization_id,v_w.factory_id,v_w.id,'on_hold',trim(p_note),auth.uid());
end; $$;
grant execute on function public.maintenance_hold_work_order(uuid,text) to authenticated;

create or replace function public.maintenance_set_task(p_task_id uuid,p_completed boolean)
returns void language plpgsql security definer set search_path=public as $$
declare v_t public.maintenance_work_order_tasks%rowtype;
begin
  select * into v_t from public.maintenance_work_order_tasks where id=p_task_id for update;
  if v_t.id is null then raise exception 'Work-order task not found'; end if;
  if not public.maintenance_can_execute_work_order(v_t.work_order_id) then raise exception 'Work order execution access denied'; end if;
  update public.maintenance_work_order_tasks set completed_at=case when p_completed then now() else null end,completed_by=case when p_completed then auth.uid() else null end where id=v_t.id;
end; $$;
grant execute on function public.maintenance_set_task(uuid,boolean) to authenticated;

create or replace function public.maintenance_add_update(p_work_order_id uuid,p_note text,p_photo_ref text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_w public.maintenance_work_orders%rowtype; v_id uuid;
begin
  select * into v_w from public.maintenance_work_orders where id=p_work_order_id;
  if v_w.id is null then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_execute_work_order(v_w.id) then raise exception 'Work order execution access denied'; end if;
  if v_w.status in ('completed','cancelled') then raise exception 'Closed work order cannot receive updates'; end if;
  insert into public.maintenance_work_updates(organization_id,factory_id,work_order_id,status_snapshot,note,photo_ref,created_by)
  values(v_w.organization_id,v_w.factory_id,v_w.id,v_w.status,trim(p_note),nullif(trim(coalesce(p_photo_ref,'')),''),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.maintenance_add_update(uuid,text,text) to authenticated;

create or replace function public.maintenance_use_spare(
  p_work_order_id uuid,p_item_id uuid,p_source_location_id uuid,p_quantity numeric,p_unit_cost numeric default null,p_note text default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_w public.maintenance_work_orders%rowtype; v_available numeric; v_tx uuid; v_usage uuid; v_line_cost numeric;
begin
  select * into v_w from public.maintenance_work_orders where id=p_work_order_id for update;
  if v_w.id is null then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_execute_work_order(v_w.id) then raise exception 'Work order execution access denied'; end if;
  if v_w.status not in ('in_progress','on_hold') then raise exception 'Spare parts can be used only on active work orders'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  if p_unit_cost is not null and p_unit_cost<0 then raise exception 'Unit cost cannot be negative'; end if;
  if not exists(select 1 from public.inventory_items where id=p_item_id and organization_id=v_w.organization_id and is_active and item_type in ('spare','consumable')) then raise exception 'Active spare or consumable item not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_source_location_id and factory_id=v_w.factory_id and is_active) then raise exception 'Source location not found'; end if;
  select coalesce(sum(quantity_delta),0) into v_available from public.stock_ledger_entries where item_id=p_item_id and location_id=p_source_location_id;
  if v_available<p_quantity then raise exception 'Insufficient spare stock: available %, requested %',v_available,p_quantity; end if;
  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,unit_cost,external_reference,notes,created_by)
  values(v_w.organization_id,v_w.factory_id,p_item_id,'issue',p_quantity,p_source_location_id,p_unit_cost,v_w.work_order_no,coalesce(nullif(trim(coalesce(p_note,'')),''),'Maintenance spare usage'),auth.uid()) returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost)
  values(v_w.organization_id,v_w.factory_id,v_tx,p_item_id,p_source_location_id,-p_quantity,p_unit_cost);
  v_line_cost:=round(p_quantity*coalesce(p_unit_cost,0),2);
  insert into public.maintenance_spare_usage(organization_id,factory_id,work_order_id,item_id,source_location_id,quantity,unit_cost,line_cost,inventory_transaction_id,used_by)
  values(v_w.organization_id,v_w.factory_id,v_w.id,p_item_id,p_source_location_id,p_quantity,p_unit_cost,v_line_cost,v_tx,auth.uid()) returning id into v_usage;
  return v_usage;
end; $$;
grant execute on function public.maintenance_use_spare(uuid,uuid,uuid,numeric,numeric,text) to authenticated;

create or replace function public.maintenance_start_downtime(p_work_order_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_w public.maintenance_work_orders%rowtype; v_id uuid;
begin
  select * into v_w from public.maintenance_work_orders where id=p_work_order_id for update;
  if v_w.id is null then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_execute_work_order(v_w.id) then raise exception 'Work order execution access denied'; end if;
  if v_w.status not in ('in_progress','on_hold') then raise exception 'Downtime requires an active work order'; end if;
  insert into public.maintenance_downtime_events(organization_id,factory_id,work_order_id,asset_id,reason,created_by)
  values(v_w.organization_id,v_w.factory_id,v_w.id,v_w.asset_id,trim(p_reason),auth.uid()) returning id into v_id;
  update public.maintenance_assets set status='down' where id=v_w.asset_id and status<>'retired';
  return v_id;
end; $$;
grant execute on function public.maintenance_start_downtime(uuid,text) to authenticated;

create or replace function public.maintenance_end_downtime(p_downtime_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_d public.maintenance_downtime_events%rowtype; v_minutes integer;
begin
  select * into v_d from public.maintenance_downtime_events where id=p_downtime_id for update;
  if v_d.id is null then raise exception 'Downtime event not found'; end if;
  if not public.maintenance_can_execute_work_order(v_d.work_order_id) then raise exception 'Work order execution access denied'; end if;
  if v_d.ended_at is not null then raise exception 'Downtime event is already closed'; end if;
  v_minutes:=greatest(1,ceil(extract(epoch from (now()-v_d.started_at))/60.0)::integer);
  update public.maintenance_downtime_events set ended_at=now(),duration_minutes=v_minutes,closed_by=auth.uid() where id=v_d.id;
  update public.maintenance_assets set status='maintenance' where id=v_d.asset_id and status<>'retired';
end; $$;
grant execute on function public.maintenance_end_downtime(uuid) to authenticated;

create or replace function public.maintenance_complete_work_order(p_work_order_id uuid,p_resolution_notes text,p_labor_minutes integer default 0,p_external_cost numeric default 0)
returns void language plpgsql security definer set search_path=public as $$
declare v_w public.maintenance_work_orders%rowtype; v_plan public.maintenance_plans%rowtype; v_next date;
begin
  select * into v_w from public.maintenance_work_orders where id=p_work_order_id for update;
  if v_w.id is null then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_execute_work_order(v_w.id) then raise exception 'Work order execution access denied'; end if;
  if v_w.status not in ('in_progress','on_hold') then raise exception 'Work order must be active before completion'; end if;
  if char_length(trim(coalesce(p_resolution_notes,'')))<3 then raise exception 'Resolution notes are required'; end if;
  if p_labor_minutes<0 or p_external_cost<0 then raise exception 'Costs and labor cannot be negative'; end if;
  if exists(select 1 from public.maintenance_downtime_events where work_order_id=v_w.id and ended_at is null) then raise exception 'Close active downtime before completing work order'; end if;
  if exists(select 1 from public.maintenance_work_order_tasks where work_order_id=v_w.id and is_required and completed_at is null) then raise exception 'Complete all required maintenance tasks first'; end if;
  update public.maintenance_work_orders set status='completed',completed_at=now(),resolution_notes=trim(p_resolution_notes),labor_minutes=p_labor_minutes,external_cost=p_external_cost where id=v_w.id;
  update public.maintenance_assets set status='running',last_service_at=now() where id=v_w.asset_id and status<>'retired';
  if v_w.plan_id is not null then
    select * into v_plan from public.maintenance_plans where id=v_w.plan_id for update;
    if v_plan.id is not null then
      v_next:=case v_plan.frequency_unit when 'days' then current_date+v_plan.frequency_value when 'weeks' then current_date+(v_plan.frequency_value*7) else (current_date+make_interval(months=>v_plan.frequency_value))::date end;
      update public.maintenance_plans set last_completed_at=now(),next_due_date=v_next where id=v_plan.id;
      update public.maintenance_assets set next_service_at=v_next::timestamptz where id=v_w.asset_id;
    end if;
  end if;
  insert into public.maintenance_work_updates(organization_id,factory_id,work_order_id,status_snapshot,note,created_by) values(v_w.organization_id,v_w.factory_id,v_w.id,'completed',trim(p_resolution_notes),auth.uid());
end; $$;
grant execute on function public.maintenance_complete_work_order(uuid,text,integer,numeric) to authenticated;

create or replace function public.maintenance_cancel_work_order(p_work_order_id uuid,p_note text)
returns void language plpgsql security definer set search_path=public as $$
declare v_w public.maintenance_work_orders%rowtype;
begin
  select * into v_w from public.maintenance_work_orders where id=p_work_order_id for update;
  if v_w.id is null then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_plan_factory(v_w.factory_id) then raise exception 'Maintenance planning access required'; end if;
  if v_w.status='completed' then raise exception 'Completed work order cannot be cancelled'; end if;
  if exists(select 1 from public.maintenance_downtime_events where work_order_id=v_w.id and ended_at is null) then raise exception 'Close active downtime before cancelling work order'; end if;
  update public.maintenance_work_orders set status='cancelled',resolution_notes=nullif(trim(coalesce(p_note,'')),'') where id=v_w.id;
  update public.maintenance_assets set status='running' where id=v_w.asset_id and status in ('maintenance','down');
end; $$;
grant execute on function public.maintenance_cancel_work_order(uuid,text) to authenticated;

create or replace function public.maintenance_generate_due_work_orders(p_factory_id uuid,p_horizon_days integer default 7)
returns integer language plpgsql security definer set search_path=public as $$
declare v_plan public.maintenance_plans%rowtype; v_count integer:=0; v_wo uuid;
begin
  if not public.maintenance_can_plan_factory(p_factory_id) then raise exception 'Maintenance planning access required'; end if;
  if p_horizon_days<0 or p_horizon_days>90 then raise exception 'Horizon must be between 0 and 90 days'; end if;
  for v_plan in select * from public.maintenance_plans p where p.factory_id=p_factory_id and p.is_active and p.next_due_date<=current_date+p_horizon_days and not exists(select 1 from public.maintenance_work_orders w where w.plan_id=p.id and w.status not in ('completed','cancelled')) order by p.next_due_date for update loop
    insert into public.maintenance_work_orders(organization_id,factory_id,asset_id,plan_id,maintenance_type,priority,status,assigned_employee_id,scheduled_at,due_at,problem_description,created_by)
    values(v_plan.organization_id,v_plan.factory_id,v_plan.asset_id,v_plan.id,v_plan.maintenance_type,v_plan.default_priority,case when v_plan.default_technician_employee_id is null then 'open' else 'assigned' end,v_plan.default_technician_employee_id,v_plan.next_due_date::timestamptz,(v_plan.next_due_date+1)::timestamptz,coalesce(v_plan.instructions,v_plan.name),auth.uid()) returning id into v_wo;
    insert into public.maintenance_work_order_tasks(organization_id,work_order_id,sequence_no,instruction,is_required)
    select v_plan.organization_id,v_wo,sequence_no,instruction,is_required from public.maintenance_plan_tasks where plan_id=v_plan.id order by sequence_no;
    v_count:=v_count+1;
  end loop;
  return v_count;
end; $$;
grant execute on function public.maintenance_generate_due_work_orders(uuid,integer) to authenticated;

create or replace function public.maintenance_dashboard_summary(p_organization_id uuid,p_factory_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_result jsonb;
begin
  if not exists(select 1 from public.factories where id=p_factory_id and organization_id=p_organization_id and is_active) then raise exception 'Factory not found in organization'; end if;
  if not public.maintenance_can_plan_factory(p_factory_id) then raise exception 'Maintenance dashboard requires planning access'; end if;
  select jsonb_build_object(
    'assets_total',(select count(*) from public.maintenance_assets where factory_id=p_factory_id and is_active),
    'assets_down',(select count(*) from public.maintenance_assets where factory_id=p_factory_id and is_active and status='down'),
    'open_work_orders',(select count(*) from public.maintenance_work_orders where factory_id=p_factory_id and status in ('open','assigned')),
    'in_progress',(select count(*) from public.maintenance_work_orders where factory_id=p_factory_id and status in ('in_progress','on_hold')),
    'overdue',(select count(*) from public.maintenance_work_orders where factory_id=p_factory_id and status not in ('completed','cancelled') and due_at is not null and due_at<now()),
    'completed_month',(select count(*) from public.maintenance_work_orders where factory_id=p_factory_id and status='completed' and completed_at>=date_trunc('month',now())),
    'due_pm',(select count(*) from public.maintenance_plans where factory_id=p_factory_id and is_active and next_due_date<=current_date+7),
    'open_requests',(select count(*) from public.maintenance_requests where factory_id=p_factory_id and status='open'),
    'downtime_minutes_month',(select coalesce(sum(duration_minutes),0) from public.maintenance_downtime_events where factory_id=p_factory_id and started_at>=date_trunc('month',now())),
    'spare_cost_month',(select coalesce(sum(line_cost),0) from public.maintenance_spare_usage where factory_id=p_factory_id and created_at>=date_trunc('month',now()))
  ) into v_result;
  return v_result;
end; $$;
grant execute on function public.maintenance_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.maintenance_work_order_report(p_factory_id uuid,p_from date default null,p_to date default null)
returns table(work_order_id uuid,work_order_no text,asset_name text,maintenance_type text,priority text,status text,assigned_to text,due_at timestamptz,completed_at timestamptz,spare_cost numeric,external_cost numeric,downtime_minutes bigint)
language plpgsql stable security definer set search_path=public as $$
begin
  if not public.maintenance_can_plan_factory(p_factory_id) then raise exception 'Maintenance report access required'; end if;
  return query
  select w.id,w.work_order_no,a.name,w.maintenance_type,w.priority,w.status,e.full_name,w.due_at,w.completed_at,
    coalesce((select sum(s.line_cost) from public.maintenance_spare_usage s where s.work_order_id=w.id),0)::numeric,
    w.external_cost,
    coalesce((select sum(d.duration_minutes) from public.maintenance_downtime_events d where d.work_order_id=w.id),0)::bigint
  from public.maintenance_work_orders w
  join public.maintenance_assets a on a.id=w.asset_id
  left join public.employees e on e.id=w.assigned_employee_id
  where w.factory_id=p_factory_id and (p_from is null or w.created_at::date>=p_from) and (p_to is null or w.created_at::date<=p_to)
  order by w.created_at desc;
end; $$;
grant execute on function public.maintenance_work_order_report(uuid,date,date) to authenticated;

commit;
