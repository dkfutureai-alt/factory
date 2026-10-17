begin;

-- Phase 11: Maintenance.
-- Asset lifecycle, preventive schedules, breakdown requests, technician work orders,
-- ledger-backed spare consumption, downtime and maintenance reporting.

create table public.maintenance_assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  asset_code text not null check (asset_code ~ '^[A-Z0-9][A-Z0-9_-]{1,23}$'),
  name text not null check (char_length(trim(name)) between 2 and 140),
  category text not null default 'machine' check (category in ('machine','utility','electrical','safety','tool','building','vehicle_support','other')),
  manufacturer text,
  model text,
  serial_number text,
  area text,
  criticality text not null default 'medium' check (criticality in ('low','medium','high','critical')),
  status text not null default 'active' check (status in ('active','maintenance','down','retired','inactive')),
  commissioning_date date,
  warranty_expiry date,
  meter_type text not null default 'none' check (meter_type in ('none','hours','cycles','km')),
  current_meter numeric(18,2) not null default 0 check (current_meter >= 0),
  notes text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,asset_code),
  unique (id,organization_id),
  unique (id,factory_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict
);
create index maintenance_assets_factory_status_idx on public.maintenance_assets(factory_id,status,criticality,name);

create table public.maintenance_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  asset_id uuid not null,
  plan_code text not null check (plan_code ~ '^[A-Z0-9][A-Z0-9_-]{1,23}$'),
  title text not null check (char_length(trim(title)) between 3 and 160),
  maintenance_type text not null default 'preventive' check (maintenance_type in ('preventive','inspection','calibration','lubrication','cleaning','other')),
  frequency_days integer check (frequency_days is null or frequency_days > 0),
  meter_interval numeric(18,2) check (meter_interval is null or meter_interval > 0),
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes > 0),
  checklist jsonb not null default '[]'::jsonb check (jsonb_typeof(checklist)='array'),
  last_done_at timestamptz,
  last_meter numeric(18,2) check (last_meter is null or last_meter >= 0),
  next_due_at timestamptz,
  next_due_meter numeric(18,2) check (next_due_meter is null or next_due_meter >= 0),
  is_active boolean not null default true,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,plan_code),
  unique (id,organization_id),
  unique (id,factory_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (asset_id,factory_id) references public.maintenance_assets(id,factory_id) on delete restrict,
  check (frequency_days is not null or meter_interval is not null),
  check (next_due_at is not null or next_due_meter is not null)
);
create index maintenance_plans_factory_due_idx on public.maintenance_plans(factory_id,is_active,next_due_at,next_due_meter);

create table public.maintenance_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  asset_id uuid not null,
  request_no text not null default ('MR-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  request_type text not null default 'breakdown' check (request_type in ('breakdown','corrective','inspection','service','safety','other')),
  priority text not null default 'medium' check (priority in ('low','medium','high','critical')),
  title text not null check (char_length(trim(title)) between 3 and 160),
  description text not null check (char_length(trim(description)) between 3 and 3000),
  status text not null default 'open' check (status in ('open','triaged','in_progress','resolved','cancelled')),
  safety_stop boolean not null default false,
  reported_by uuid references auth.users(id) on delete set null,
  reported_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,request_no),
  unique (id,organization_id),
  unique (id,factory_id),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (asset_id,factory_id) references public.maintenance_assets(id,factory_id) on delete restrict,
  check ((status='resolved' and resolved_at is not null) or status<>'resolved')
);
create index maintenance_requests_factory_status_idx on public.maintenance_requests(factory_id,status,priority,reported_at desc);

create table public.maintenance_work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  asset_id uuid not null,
  request_id uuid,
  plan_id uuid,
  work_order_no text not null default ('MWO-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  work_type text not null default 'corrective' check (work_type in ('preventive','breakdown','corrective','inspection','calibration','lubrication','other')),
  priority text not null default 'medium' check (priority in ('low','medium','high','critical')),
  title text not null check (char_length(trim(title)) between 3 and 180),
  description text,
  status text not null default 'planned' check (status in ('planned','assigned','in_progress','on_hold','completed','cancelled')),
  assigned_employee_id uuid,
  scheduled_start_at timestamptz,
  scheduled_end_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  meter_at_start numeric(18,2),
  meter_at_completion numeric(18,2),
  root_cause text,
  resolution text,
  cancellation_reason text,
  actual_downtime_minutes integer not null default 0 check (actual_downtime_minutes >= 0),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  completed_by uuid references auth.users(id) on delete set null,
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
  check (scheduled_end_at is null or scheduled_start_at is null or scheduled_end_at >= scheduled_start_at),
  check (meter_at_start is null or meter_at_start >= 0),
  check (meter_at_completion is null or meter_at_completion >= coalesce(meter_at_start,0)),
  check ((status='completed' and completed_at is not null and char_length(trim(coalesce(resolution,''))) >= 3) or status<>'completed'),
  check ((status='cancelled' and char_length(trim(coalesce(cancellation_reason,''))) >= 3) or status<>'cancelled')
);
create index maintenance_work_orders_factory_status_idx on public.maintenance_work_orders(factory_id,status,priority,scheduled_start_at,created_at desc);
create index maintenance_work_orders_employee_idx on public.maintenance_work_orders(assigned_employee_id,status) where assigned_employee_id is not null;
create unique index maintenance_plan_active_work_unique on public.maintenance_work_orders(plan_id)
  where plan_id is not null and status in ('planned','assigned','in_progress','on_hold');

create table public.maintenance_part_usages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  work_order_id uuid not null,
  item_id uuid not null,
  from_location_id uuid not null,
  quantity numeric(18,4) not null check (quantity > 0),
  unit_cost numeric(18,4) check (unit_cost is null or unit_cost >= 0),
  inventory_transaction_id uuid not null unique references public.inventory_transactions(id) on delete restrict,
  notes text,
  used_by uuid references auth.users(id) on delete set null,
  used_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (work_order_id,factory_id) references public.maintenance_work_orders(id,factory_id) on delete restrict,
  foreign key (item_id,organization_id) references public.inventory_items(id,organization_id) on delete restrict,
  foreign key (from_location_id,factory_id) references public.stock_locations(id,factory_id) on delete restrict
);
create index maintenance_parts_work_order_idx on public.maintenance_part_usages(work_order_id,used_at desc);

create table public.maintenance_downtime_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  asset_id uuid not null,
  work_order_id uuid not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_minutes integer check (duration_minutes is null or duration_minutes >= 0),
  reason text,
  created_at timestamptz not null default now(),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (asset_id,factory_id) references public.maintenance_assets(id,factory_id) on delete restrict,
  foreign key (work_order_id,factory_id) references public.maintenance_work_orders(id,factory_id) on delete restrict,
  check (ended_at is null or ended_at >= started_at)
);
create unique index maintenance_downtime_open_work_unique on public.maintenance_downtime_events(work_order_id) where ended_at is null;
create index maintenance_downtime_factory_date_idx on public.maintenance_downtime_events(factory_id,started_at desc);

create table public.maintenance_work_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  factory_id uuid not null,
  work_order_id uuid not null,
  log_type text not null default 'note' check (log_type in ('note','start','hold','resume','part','complete','meter','assignment')),
  message text not null check (char_length(trim(message)) between 2 and 2000),
  logged_by uuid references auth.users(id) on delete set null,
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  foreign key (factory_id,organization_id) references public.factories(id,organization_id) on delete restrict,
  foreign key (work_order_id,factory_id) references public.maintenance_work_orders(id,factory_id) on delete cascade
);
create index maintenance_work_logs_order_date_idx on public.maintenance_work_logs(work_order_id,logged_at desc);

create trigger maintenance_assets_set_updated_at before update on public.maintenance_assets for each row execute function public.set_updated_at();
create trigger maintenance_plans_set_updated_at before update on public.maintenance_plans for each row execute function public.set_updated_at();
create trigger maintenance_requests_set_updated_at before update on public.maintenance_requests for each row execute function public.set_updated_at();
create trigger maintenance_work_orders_set_updated_at before update on public.maintenance_work_orders for each row execute function public.set_updated_at();

create or replace function public.maintenance_current_employee(target_factory_id uuid)
returns uuid language sql stable security definer set search_path=public as $$
  select e.id
  from public.employees e
  join public.organization_members om on om.organization_id=e.organization_id and om.user_id=e.user_id and om.is_active
  join public.factory_members fm on fm.organization_id=e.organization_id and fm.user_id=e.user_id and fm.factory_id=target_factory_id and fm.is_active
  where e.user_id=auth.uid() and e.status='active'
  order by case when e.primary_factory_id=target_factory_id then 0 else 1 end, e.created_at
  limit 1;
$$;
grant execute on function public.maintenance_current_employee(uuid) to authenticated;

create or replace function public.maintenance_can_supervise_factory(target_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_manage_factory(target_factory_id) or exists(
    select 1
    from public.factories f
    join public.organization_members om on om.organization_id=f.organization_id and om.user_id=auth.uid() and om.is_active and om.role='supervisor'
    join public.factory_members fm on fm.organization_id=f.organization_id and fm.factory_id=f.id and fm.user_id=auth.uid() and fm.is_active
    where f.id=target_factory_id and f.is_active
  );
$$;
grant execute on function public.maintenance_can_supervise_factory(uuid) to authenticated;

create or replace function public.maintenance_can_operate_work_order(target_work_order_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.maintenance_work_orders w
    where w.id=target_work_order_id
      and (
        public.maintenance_can_supervise_factory(w.factory_id)
        or (w.assigned_employee_id is not null and w.assigned_employee_id=public.maintenance_current_employee(w.factory_id))
      )
  );
$$;
grant execute on function public.maintenance_can_operate_work_order(uuid) to authenticated;

alter table public.maintenance_assets enable row level security;
alter table public.maintenance_plans enable row level security;
alter table public.maintenance_requests enable row level security;
alter table public.maintenance_work_orders enable row level security;
alter table public.maintenance_part_usages enable row level security;
alter table public.maintenance_downtime_events enable row level security;
alter table public.maintenance_work_logs enable row level security;

grant select,insert,update on public.maintenance_assets,public.maintenance_plans to authenticated;
grant select on public.maintenance_requests,public.maintenance_work_orders,public.maintenance_part_usages,public.maintenance_downtime_events,public.maintenance_work_logs to authenticated;

create policy maintenance_assets_select on public.maintenance_assets for select to authenticated using (public.can_view_inventory_factory(factory_id));
create policy maintenance_assets_manage on public.maintenance_assets for all to authenticated using (public.can_manage_factory(factory_id)) with check (public.can_manage_factory(factory_id));
create policy maintenance_plans_select on public.maintenance_plans for select to authenticated using (public.can_view_inventory_factory(factory_id));
create policy maintenance_plans_manage on public.maintenance_plans for all to authenticated using (public.can_manage_factory(factory_id)) with check (public.can_manage_factory(factory_id));
create policy maintenance_requests_select on public.maintenance_requests for select to authenticated using (public.can_view_inventory_factory(factory_id));
create policy maintenance_work_orders_select on public.maintenance_work_orders for select to authenticated using (public.can_view_inventory_factory(factory_id));
create policy maintenance_parts_select on public.maintenance_part_usages for select to authenticated using (public.can_view_inventory_factory(factory_id));
create policy maintenance_downtime_select on public.maintenance_downtime_events for select to authenticated using (public.can_view_inventory_factory(factory_id));
create policy maintenance_logs_select on public.maintenance_work_logs for select to authenticated using (public.can_view_inventory_factory(factory_id));

create or replace function public.maintenance_prevent_scope_change()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.organization_id<>old.organization_id or new.factory_id<>old.factory_id then
    raise exception 'Maintenance organization/factory scope is immutable';
  end if;
  if tg_table_name='maintenance_plans' and new.asset_id<>old.asset_id then
    raise exception 'Maintenance plan asset is immutable';
  end if;
  return new;
end;
$$;
revoke all on function public.maintenance_prevent_scope_change() from public;
create trigger maintenance_assets_scope_immutable before update on public.maintenance_assets for each row execute function public.maintenance_prevent_scope_change();
create trigger maintenance_plans_scope_immutable before update on public.maintenance_plans for each row execute function public.maintenance_prevent_scope_change();
create trigger maintenance_parts_immutable before update or delete on public.maintenance_part_usages for each row execute function public.prevent_inventory_immutable_change();

create or replace function public.audit_maintenance_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare target_org uuid; target_factory uuid; target_id text; payload jsonb;
begin
  target_org:=coalesce(new.organization_id,old.organization_id);
  target_factory:=coalesce(new.factory_id,old.factory_id);
  target_id:=coalesce(new.id,old.id)::text;
  if tg_op='INSERT' then payload:=jsonb_build_object('after',to_jsonb(new));
  elsif tg_op='UPDATE' then payload:=jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new));
  else payload:=jsonb_build_object('before',to_jsonb(old)); end if;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(target_org,target_factory,auth.uid(),lower(tg_op),tg_table_name,target_id,payload);
  return coalesce(new,old);
end;
$$;
revoke all on function public.audit_maintenance_change() from public;
create trigger maintenance_assets_audit after insert or update on public.maintenance_assets for each row execute function public.audit_maintenance_change();
create trigger maintenance_plans_audit after insert or update on public.maintenance_plans for each row execute function public.audit_maintenance_change();
create trigger maintenance_requests_audit after insert or update on public.maintenance_requests for each row execute function public.audit_maintenance_change();
create trigger maintenance_work_orders_audit after insert or update on public.maintenance_work_orders for each row execute function public.audit_maintenance_change();
create trigger maintenance_parts_audit after insert on public.maintenance_part_usages for each row execute function public.audit_maintenance_change();
create trigger maintenance_downtime_audit after insert or update on public.maintenance_downtime_events for each row execute function public.audit_maintenance_change();

create or replace function public.maintenance_report_request(
  p_asset_id uuid,
  p_request_type text,
  p_priority text,
  p_title text,
  p_description text,
  p_safety_stop boolean default false
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_asset public.maintenance_assets%rowtype; v_id uuid; v_employee uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_asset from public.maintenance_assets where id=p_asset_id and is_active;
  if not found then raise exception 'Active asset not found'; end if;
  if not public.can_view_inventory_factory(v_asset.factory_id) then raise exception 'Not allowed for this factory'; end if;
  v_employee:=public.maintenance_current_employee(v_asset.factory_id);
  if v_employee is null and not public.can_manage_factory(v_asset.factory_id) then raise exception 'Only factory staff may report maintenance requests'; end if;
  if p_request_type not in ('breakdown','corrective','inspection','service','safety','other') then raise exception 'Invalid request type'; end if;
  if p_priority not in ('low','medium','high','critical') then raise exception 'Invalid priority'; end if;
  if char_length(trim(coalesce(p_title,'')))<3 or char_length(trim(coalesce(p_description,'')))<3 then raise exception 'Title and description are required'; end if;
  insert into public.maintenance_requests(organization_id,factory_id,asset_id,request_type,priority,title,description,safety_stop,reported_by)
  values(v_asset.organization_id,v_asset.factory_id,v_asset.id,p_request_type,p_priority,trim(p_title),trim(p_description),coalesce(p_safety_stop,false),auth.uid()) returning id into v_id;
  if p_request_type='breakdown' or p_safety_stop then
    update public.maintenance_assets set status='down' where id=v_asset.id and status not in ('retired','inactive');
  end if;
  return v_id;
end;
$$;
grant execute on function public.maintenance_report_request(uuid,text,text,text,text,boolean) to authenticated;

create or replace function public.maintenance_create_work_order(
  p_asset_id uuid,
  p_work_type text,
  p_priority text,
  p_title text,
  p_description text default null,
  p_request_id uuid default null,
  p_plan_id uuid default null,
  p_assigned_employee_id uuid default null,
  p_scheduled_start_at timestamptz default null,
  p_scheduled_end_at timestamptz default null,
  p_notes text default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_asset public.maintenance_assets%rowtype; v_id uuid; v_status text;
begin
  select * into v_asset from public.maintenance_assets where id=p_asset_id and is_active;
  if not found then raise exception 'Active asset not found'; end if;
  if not public.maintenance_can_supervise_factory(v_asset.factory_id) then raise exception 'Not allowed to create maintenance work for this factory'; end if;
  if p_work_type not in ('preventive','breakdown','corrective','inspection','calibration','lubrication','other') then raise exception 'Invalid work type'; end if;
  if p_priority not in ('low','medium','high','critical') then raise exception 'Invalid priority'; end if;
  if char_length(trim(coalesce(p_title,'')))<3 then raise exception 'Work order title is required'; end if;
  if p_scheduled_end_at is not null and p_scheduled_start_at is not null and p_scheduled_end_at<p_scheduled_start_at then raise exception 'Scheduled end cannot be before start'; end if;
  if p_request_id is not null and not exists(select 1 from public.maintenance_requests r where r.id=p_request_id and r.factory_id=v_asset.factory_id and r.asset_id=v_asset.id and r.status not in ('resolved','cancelled')) then raise exception 'Open request not found for this asset'; end if;
  if p_plan_id is not null and not exists(select 1 from public.maintenance_plans p where p.id=p_plan_id and p.factory_id=v_asset.factory_id and p.asset_id=v_asset.id and p.is_active) then raise exception 'Active maintenance plan not found for this asset'; end if;
  if p_assigned_employee_id is not null and not exists(select 1 from public.employees e where e.id=p_assigned_employee_id and e.organization_id=v_asset.organization_id and e.status='active' and (e.primary_factory_id=v_asset.factory_id or exists(select 1 from public.factory_members fm where fm.organization_id=e.organization_id and fm.factory_id=v_asset.factory_id and fm.user_id=e.user_id and fm.is_active))) then raise exception 'Assigned employee is not active in this factory'; end if;
  v_status:=case when p_assigned_employee_id is not null then 'assigned' else 'planned' end;
  insert into public.maintenance_work_orders(organization_id,factory_id,asset_id,request_id,plan_id,work_type,priority,title,description,status,assigned_employee_id,scheduled_start_at,scheduled_end_at,notes,created_by)
  values(v_asset.organization_id,v_asset.factory_id,v_asset.id,p_request_id,p_plan_id,p_work_type,p_priority,trim(p_title),nullif(trim(coalesce(p_description,'')),''),v_status,p_assigned_employee_id,p_scheduled_start_at,p_scheduled_end_at,nullif(trim(coalesce(p_notes,'')),''),auth.uid()) returning id into v_id;
  if p_request_id is not null then update public.maintenance_requests set status='triaged' where id=p_request_id; end if;
  if p_assigned_employee_id is not null then
    insert into public.maintenance_work_logs(organization_id,factory_id,work_order_id,log_type,message,logged_by)
    values(v_asset.organization_id,v_asset.factory_id,v_id,'assignment','Work order assigned',auth.uid());
  end if;
  return v_id;
end;
$$;
grant execute on function public.maintenance_create_work_order(uuid,text,text,text,text,uuid,uuid,uuid,timestamptz,timestamptz,text) to authenticated;

create or replace function public.maintenance_assign_work_order(
  p_work_order_id uuid,
  p_employee_id uuid,
  p_scheduled_start_at timestamptz default null,
  p_scheduled_end_at timestamptz default null
) returns void language plpgsql security definer set search_path=public as $$
declare v_wo public.maintenance_work_orders%rowtype;
begin
  select * into v_wo from public.maintenance_work_orders where id=p_work_order_id for update;
  if not found then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_supervise_factory(v_wo.factory_id) then raise exception 'Not allowed to assign this work order'; end if;
  if v_wo.status in ('completed','cancelled') then raise exception 'Closed work order cannot be assigned'; end if;
  if p_scheduled_end_at is not null and p_scheduled_start_at is not null and p_scheduled_end_at<p_scheduled_start_at then raise exception 'Scheduled end cannot be before start'; end if;
  if not exists(select 1 from public.employees e where e.id=p_employee_id and e.organization_id=v_wo.organization_id and e.status='active' and (e.primary_factory_id=v_wo.factory_id or exists(select 1 from public.factory_members fm where fm.organization_id=e.organization_id and fm.factory_id=v_wo.factory_id and fm.user_id=e.user_id and fm.is_active))) then raise exception 'Employee is not active in this factory'; end if;
  update public.maintenance_work_orders set assigned_employee_id=p_employee_id,status=case when status='planned' then 'assigned' else status end,scheduled_start_at=coalesce(p_scheduled_start_at,scheduled_start_at),scheduled_end_at=coalesce(p_scheduled_end_at,scheduled_end_at) where id=v_wo.id;
  insert into public.maintenance_work_logs(organization_id,factory_id,work_order_id,log_type,message,logged_by)
  values(v_wo.organization_id,v_wo.factory_id,v_wo.id,'assignment','Work order assigned/reassigned',auth.uid());
end;
$$;
grant execute on function public.maintenance_assign_work_order(uuid,uuid,timestamptz,timestamptz) to authenticated;

create or replace function public.maintenance_start_work_order(
  p_work_order_id uuid,
  p_meter_reading numeric default null,
  p_notes text default null
) returns void language plpgsql security definer set search_path=public as $$
declare v_wo public.maintenance_work_orders%rowtype; v_asset public.maintenance_assets%rowtype; v_now timestamptz:=now();
begin
  select * into v_wo from public.maintenance_work_orders where id=p_work_order_id for update;
  if not found then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_operate_work_order(v_wo.id) then raise exception 'Not assigned or authorized for this work order'; end if;
  if v_wo.status not in ('planned','assigned','on_hold') then raise exception 'Work order cannot be started from current status'; end if;
  select * into v_asset from public.maintenance_assets where id=v_wo.asset_id for update;
  if p_meter_reading is not null then
    if p_meter_reading<v_asset.current_meter then raise exception 'Meter reading cannot go backwards'; end if;
    update public.maintenance_assets set current_meter=p_meter_reading where id=v_asset.id;
  end if;
  update public.maintenance_work_orders set status='in_progress',started_at=coalesce(started_at,v_now),meter_at_start=coalesce(meter_at_start,p_meter_reading) where id=v_wo.id;
  update public.maintenance_assets set status='maintenance' where id=v_asset.id and status not in ('retired','inactive');
  if v_wo.request_id is not null then update public.maintenance_requests set status='in_progress' where id=v_wo.request_id and status not in ('resolved','cancelled'); end if;
  if v_wo.work_type in ('breakdown','corrective') and not exists(select 1 from public.maintenance_downtime_events where work_order_id=v_wo.id and ended_at is null) then
    insert into public.maintenance_downtime_events(organization_id,factory_id,asset_id,work_order_id,started_at,reason)
    values(v_wo.organization_id,v_wo.factory_id,v_wo.asset_id,v_wo.id,coalesce(v_wo.started_at,v_now),v_wo.work_type);
  end if;
  insert into public.maintenance_work_logs(organization_id,factory_id,work_order_id,log_type,message,logged_by)
  values(v_wo.organization_id,v_wo.factory_id,v_wo.id,'start',coalesce(nullif(trim(coalesce(p_notes,'')),''),'Work started'),auth.uid());
end;
$$;
grant execute on function public.maintenance_start_work_order(uuid,numeric,text) to authenticated;

create or replace function public.maintenance_hold_work_order(p_work_order_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
declare v_wo public.maintenance_work_orders%rowtype;
begin
  select * into v_wo from public.maintenance_work_orders where id=p_work_order_id for update;
  if not found then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_operate_work_order(v_wo.id) then raise exception 'Not assigned or authorized for this work order'; end if;
  if v_wo.status<>'in_progress' then raise exception 'Only in-progress work can be put on hold'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Hold reason is required'; end if;
  update public.maintenance_work_orders set status='on_hold' where id=v_wo.id;
  insert into public.maintenance_work_logs(organization_id,factory_id,work_order_id,log_type,message,logged_by)
  values(v_wo.organization_id,v_wo.factory_id,v_wo.id,'hold',trim(p_reason),auth.uid());
end;
$$;
grant execute on function public.maintenance_hold_work_order(uuid,text) to authenticated;

create or replace function public.maintenance_resume_work_order(p_work_order_id uuid,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_wo public.maintenance_work_orders%rowtype;
begin
  select * into v_wo from public.maintenance_work_orders where id=p_work_order_id for update;
  if not found then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_operate_work_order(v_wo.id) then raise exception 'Not assigned or authorized for this work order'; end if;
  if v_wo.status<>'on_hold' then raise exception 'Only on-hold work can be resumed'; end if;
  update public.maintenance_work_orders set status='in_progress' where id=v_wo.id;
  insert into public.maintenance_work_logs(organization_id,factory_id,work_order_id,log_type,message,logged_by)
  values(v_wo.organization_id,v_wo.factory_id,v_wo.id,'resume',coalesce(nullif(trim(coalesce(p_notes,'')),''),'Work resumed'),auth.uid());
end;
$$;
grant execute on function public.maintenance_resume_work_order(uuid,text) to authenticated;

create or replace function public.maintenance_add_work_log(p_work_order_id uuid,p_message text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_wo public.maintenance_work_orders%rowtype; v_id uuid;
begin
  select * into v_wo from public.maintenance_work_orders where id=p_work_order_id;
  if not found then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_operate_work_order(v_wo.id) then raise exception 'Not assigned or authorized for this work order'; end if;
  if v_wo.status in ('completed','cancelled') then raise exception 'Closed work order cannot receive execution notes'; end if;
  if char_length(trim(coalesce(p_message,'')))<2 then raise exception 'Log message is required'; end if;
  insert into public.maintenance_work_logs(organization_id,factory_id,work_order_id,log_type,message,logged_by)
  values(v_wo.organization_id,v_wo.factory_id,v_wo.id,'note',trim(p_message),auth.uid()) returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.maintenance_add_work_log(uuid,text) to authenticated;

create or replace function public.maintenance_issue_part(
  p_work_order_id uuid,
  p_item_id uuid,
  p_from_location_id uuid,
  p_quantity numeric,
  p_unit_cost numeric default null,
  p_notes text default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_wo public.maintenance_work_orders%rowtype; v_balance numeric; v_tx uuid; v_usage uuid;
begin
  select * into v_wo from public.maintenance_work_orders where id=p_work_order_id for update;
  if not found then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_operate_work_order(v_wo.id) then raise exception 'Not assigned or authorized for this work order'; end if;
  if v_wo.status<>'in_progress' then raise exception 'Parts can only be issued to in-progress work'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
  if p_unit_cost is not null and p_unit_cost<0 then raise exception 'Unit cost cannot be negative'; end if;
  if not exists(select 1 from public.inventory_items where id=p_item_id and organization_id=v_wo.organization_id and is_active and item_type in ('spare','consumable','other')) then raise exception 'Active spare/consumable item not found'; end if;
  if not exists(select 1 from public.stock_locations where id=p_from_location_id and factory_id=v_wo.factory_id and organization_id=v_wo.organization_id and is_active) then raise exception 'Source stock location not found'; end if;
  select coalesce(sum(quantity_delta),0) into v_balance from public.stock_ledger_entries where factory_id=v_wo.factory_id and item_id=p_item_id and location_id=p_from_location_id;
  if v_balance<p_quantity then raise exception 'Insufficient stock at source location'; end if;
  insert into public.inventory_transactions(organization_id,factory_id,item_id,transaction_type,quantity,from_location_id,unit_cost,external_reference,notes,created_by)
  values(v_wo.organization_id,v_wo.factory_id,p_item_id,'issue',p_quantity,p_from_location_id,p_unit_cost,v_wo.work_order_no,concat('Maintenance: ',coalesce(nullif(trim(coalesce(p_notes,'')),''),v_wo.title)),auth.uid()) returning id into v_tx;
  insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost)
  values(v_wo.organization_id,v_wo.factory_id,v_tx,p_item_id,p_from_location_id,-p_quantity,p_unit_cost);
  insert into public.maintenance_part_usages(organization_id,factory_id,work_order_id,item_id,from_location_id,quantity,unit_cost,inventory_transaction_id,notes,used_by)
  values(v_wo.organization_id,v_wo.factory_id,v_wo.id,p_item_id,p_from_location_id,p_quantity,p_unit_cost,v_tx,nullif(trim(coalesce(p_notes,'')),''),auth.uid()) returning id into v_usage;
  insert into public.maintenance_work_logs(organization_id,factory_id,work_order_id,log_type,message,logged_by)
  values(v_wo.organization_id,v_wo.factory_id,v_wo.id,'part',format('Issued %s of inventory item %s',p_quantity,p_item_id),auth.uid());
  return v_usage;
end;
$$;
grant execute on function public.maintenance_issue_part(uuid,uuid,uuid,numeric,numeric,text) to authenticated;

create or replace function public.maintenance_complete_work_order(
  p_work_order_id uuid,
  p_resolution text,
  p_root_cause text default null,
  p_meter_reading numeric default null,
  p_notes text default null
) returns void language plpgsql security definer set search_path=public as $$
declare v_wo public.maintenance_work_orders%rowtype; v_asset public.maintenance_assets%rowtype; v_now timestamptz:=now(); v_minutes integer:=0;
begin
  select * into v_wo from public.maintenance_work_orders where id=p_work_order_id for update;
  if not found then raise exception 'Work order not found'; end if;
  if not public.maintenance_can_operate_work_order(v_wo.id) then raise exception 'Not assigned or authorized for this work order'; end if;
  if v_wo.status not in ('in_progress','on_hold') then raise exception 'Only active work can be completed'; end if;
  if char_length(trim(coalesce(p_resolution,'')))<3 then raise exception 'Resolution is required'; end if;
  select * into v_asset from public.maintenance_assets where id=v_wo.asset_id for update;
  if p_meter_reading is not null and p_meter_reading<v_asset.current_meter then raise exception 'Meter reading cannot go backwards'; end if;
  if p_meter_reading is not null then update public.maintenance_assets set current_meter=p_meter_reading where id=v_asset.id; end if;
  update public.maintenance_downtime_events
  set ended_at=v_now,duration_minutes=greatest(0,floor(extract(epoch from (v_now-started_at))/60)::integer)
  where work_order_id=v_wo.id and ended_at is null;
  select coalesce(sum(duration_minutes),0)::integer into v_minutes from public.maintenance_downtime_events where work_order_id=v_wo.id;
  update public.maintenance_work_orders set status='completed',completed_at=v_now,completed_by=auth.uid(),meter_at_completion=p_meter_reading,root_cause=nullif(trim(coalesce(p_root_cause,'')),''),resolution=trim(p_resolution),actual_downtime_minutes=v_minutes,notes=coalesce(nullif(trim(coalesce(p_notes,'')),''),notes) where id=v_wo.id;
  update public.maintenance_assets set status='active' where id=v_asset.id and status not in ('retired','inactive');
  if v_wo.request_id is not null then update public.maintenance_requests set status='resolved',resolved_at=v_now,resolution_note=trim(p_resolution) where id=v_wo.request_id and status<>'cancelled'; end if;
  if v_wo.plan_id is not null then
    update public.maintenance_plans p
    set last_done_at=v_now,
        last_meter=coalesce(p_meter_reading,v_asset.current_meter),
        next_due_at=case when p.frequency_days is not null then v_now + make_interval(days=>p.frequency_days) else p.next_due_at end,
        next_due_meter=case when p.meter_interval is not null then coalesce(p_meter_reading,v_asset.current_meter)+p.meter_interval else p.next_due_meter end
    where p.id=v_wo.plan_id;
  end if;
  insert into public.maintenance_work_logs(organization_id,factory_id,work_order_id,log_type,message,logged_by)
  values(v_wo.organization_id,v_wo.factory_id,v_wo.id,'complete',trim(p_resolution),auth.uid());
end;
$$;
grant execute on function public.maintenance_complete_work_order(uuid,text,text,numeric,text) to authenticated;

create or replace function public.maintenance_record_asset_meter(p_asset_id uuid,p_meter_reading numeric,p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_asset public.maintenance_assets%rowtype;
begin
  select * into v_asset from public.maintenance_assets where id=p_asset_id for update;
  if not found then raise exception 'Asset not found'; end if;
  if not public.maintenance_can_supervise_factory(v_asset.factory_id) then raise exception 'Not allowed to record asset meter'; end if;
  if v_asset.meter_type='none' then raise exception 'Asset does not use a meter'; end if;
  if p_meter_reading is null or p_meter_reading<v_asset.current_meter then raise exception 'Meter reading cannot go backwards'; end if;
  update public.maintenance_assets set current_meter=p_meter_reading where id=v_asset.id;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_asset.organization_id,v_asset.factory_id,auth.uid(),'meter','maintenance_assets',v_asset.id::text,jsonb_build_object('from',v_asset.current_meter,'to',p_meter_reading,'notes',nullif(trim(coalesce(p_notes,'')),'')));
end;
$$;
grant execute on function public.maintenance_record_asset_meter(uuid,numeric,text) to authenticated;

create or replace function public.maintenance_generate_due_work_orders(p_factory_id uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare v_count integer:=0;
begin
  if not public.maintenance_can_supervise_factory(p_factory_id) then raise exception 'Not allowed to generate maintenance work'; end if;
  insert into public.maintenance_work_orders(organization_id,factory_id,asset_id,plan_id,work_type,priority,title,description,status,scheduled_start_at,created_by)
  select p.organization_id,p.factory_id,p.asset_id,p.id,
    case p.maintenance_type when 'preventive' then 'preventive' when 'inspection' then 'inspection' when 'calibration' then 'calibration' when 'lubrication' then 'lubrication' else 'preventive' end,
    case a.criticality when 'critical' then 'critical' when 'high' then 'high' else 'medium' end,
    p.title,concat('Generated from maintenance plan ',p.plan_code),'planned',coalesce(p.next_due_at,now()),auth.uid()
  from public.maintenance_plans p
  join public.maintenance_assets a on a.id=p.asset_id and a.factory_id=p.factory_id
  where p.factory_id=p_factory_id and p.is_active and a.is_active and a.status not in ('retired','inactive')
    and ((p.next_due_at is not null and p.next_due_at<=now()) or (p.next_due_meter is not null and a.current_meter>=p.next_due_meter))
    and not exists(select 1 from public.maintenance_work_orders w where w.plan_id=p.id and w.status in ('planned','assigned','in_progress','on_hold'));
  get diagnostics v_count=row_count;
  return v_count;
end;
$$;
grant execute on function public.maintenance_generate_due_work_orders(uuid) to authenticated;

create or replace function public.maintenance_dashboard_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_scope_ok boolean; v_result jsonb;
begin
  if p_factory_id is null then
    v_scope_ok:=public.is_platform_owner() or public.has_org_role(p_organization_id,array['org_admin']::public.app_role[]);
  else
    v_scope_ok:=public.can_view_inventory_factory(p_factory_id) and exists(select 1 from public.factories where id=p_factory_id and organization_id=p_organization_id);
  end if;
  if not v_scope_ok then raise exception 'Not authorized for maintenance dashboard'; end if;
  select jsonb_build_object(
    'assets',count(*) filter(where a.is_active),
    'assets_down',count(*) filter(where a.is_active and a.status='down'),
    'assets_in_maintenance',count(*) filter(where a.is_active and a.status='maintenance'),
    'critical_assets',count(*) filter(where a.is_active and a.criticality='critical')
  ) into v_result
  from public.maintenance_assets a where a.organization_id=p_organization_id and (p_factory_id is null or a.factory_id=p_factory_id);
  v_result:=v_result || (select jsonb_build_object(
    'open_requests',count(*) filter(where r.status in ('open','triaged','in_progress')),
    'critical_requests',count(*) filter(where r.status in ('open','triaged','in_progress') and r.priority='critical')
  ) from public.maintenance_requests r where r.organization_id=p_organization_id and (p_factory_id is null or r.factory_id=p_factory_id));
  v_result:=v_result || (select jsonb_build_object(
    'open_work_orders',count(*) filter(where w.status in ('planned','assigned','in_progress','on_hold')),
    'in_progress_work_orders',count(*) filter(where w.status='in_progress'),
    'completed_last_30_days',count(*) filter(where w.status='completed' and w.completed_at>=now()-interval '30 days'),
    'downtime_minutes_last_30_days',coalesce(sum(w.actual_downtime_minutes) filter(where w.status='completed' and w.completed_at>=now()-interval '30 days'),0)
  ) from public.maintenance_work_orders w where w.organization_id=p_organization_id and (p_factory_id is null or w.factory_id=p_factory_id));
  v_result:=v_result || (select jsonb_build_object(
    'due_plans',count(*) filter(where p.is_active and ((p.next_due_at is not null and p.next_due_at<=now()) or (p.next_due_meter is not null and a.current_meter>=p.next_due_meter)))
  ) from public.maintenance_plans p join public.maintenance_assets a on a.id=p.asset_id where p.organization_id=p_organization_id and (p_factory_id is null or p.factory_id=p_factory_id));
  return v_result;
end;
$$;
grant execute on function public.maintenance_dashboard_summary(uuid,uuid) to authenticated;

create or replace function public.maintenance_work_order_report(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 100)
returns table(work_order_id uuid,work_order_no text,asset_code text,asset_name text,work_type text,priority text,status text,assigned_employee text,scheduled_start_at timestamptz,started_at timestamptz,completed_at timestamptz,downtime_minutes integer,parts_quantity numeric)
language plpgsql stable security definer set search_path=public as $$
begin
  if p_factory_id is null then
    if not (public.is_platform_owner() or public.has_org_role(p_organization_id,array['org_admin']::public.app_role[])) then raise exception 'Not authorized for organization maintenance report'; end if;
  elsif not (public.can_view_inventory_factory(p_factory_id) and exists(select 1 from public.factories where id=p_factory_id and organization_id=p_organization_id)) then raise exception 'Not authorized for factory maintenance report';
  end if;
  return query
  select w.id,w.work_order_no,a.asset_code,a.name,w.work_type,w.priority,w.status,coalesce(e.full_name,''),w.scheduled_start_at,w.started_at,w.completed_at,w.actual_downtime_minutes,coalesce(sum(pu.quantity),0)
  from public.maintenance_work_orders w
  join public.maintenance_assets a on a.id=w.asset_id
  left join public.employees e on e.id=w.assigned_employee_id
  left join public.maintenance_part_usages pu on pu.work_order_id=w.id
  where w.organization_id=p_organization_id and (p_factory_id is null or w.factory_id=p_factory_id)
  group by w.id,a.asset_code,a.name,e.full_name
  order by w.created_at desc
  limit greatest(1,least(coalesce(p_limit,100),500));
end;
$$;
grant execute on function public.maintenance_work_order_report(uuid,uuid,integer) to authenticated;

commit;
