-- FactoryOS Maintenance foundation. Apply after 08a_delivery_review_fixes.sql.
-- Inventory is the only source of spare-parts stock movements.
create type public.maintenance_asset_status as enum ('operational','service_due','maintenance','inactive');
create type public.maintenance_job_status as enum ('reported','assigned','in_progress','waiting_parts','completed','cancelled');
create type public.maintenance_job_type as enum ('preventive','corrective','breakdown');
create type public.maintenance_priority as enum ('low','normal','high','critical');

create table public.maintenance_assets (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 factory_id uuid not null references public.factories(id) on delete restrict,
 asset_code text not null check (length(btrim(asset_code))>0),
 name text not null check (length(btrim(name))>0),
 asset_category text not null,
 serial_number text,
 location_label text not null,
 status public.maintenance_asset_status not null default 'operational',
 operating_hours numeric(18,2) not null default 0 check (operating_hours>=0),
 commissioned_on date,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (organization_id,asset_code)
);
create index maintenance_assets_factory_idx on public.maintenance_assets(organization_id,factory_id,status);

create table public.maintenance_plans (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 factory_id uuid not null references public.factories(id) on delete restrict,
 asset_id uuid not null references public.maintenance_assets(id) on delete restrict,
 schedule_code text not null,
 task_name text not null,
 interval_days integer not null check (interval_days between 1 and 3650),
 next_due_on date not null,
 last_completed_on date,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (organization_id,schedule_code),
 check (last_completed_on is null or next_due_on>last_completed_on)
);
create index maintenance_plans_due_idx on public.maintenance_plans(organization_id,factory_id,next_due_on) where is_active;

create table public.maintenance_work_orders (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 factory_id uuid not null references public.factories(id) on delete restrict,
 order_number text not null,
 asset_id uuid not null references public.maintenance_assets(id) on delete restrict,
 plan_id uuid references public.maintenance_plans(id) on delete restrict,
 occurrence_due_on date,
 job_type public.maintenance_job_type not null,
 priority public.maintenance_priority not null default 'normal',
 status public.maintenance_job_status not null default 'reported',
 problem_description text not null,
 assigned_employee_id uuid references public.employees(id) on delete restrict,
 reported_at timestamptz not null default now(),
 started_at timestamptz,
 completed_at timestamptz,
 root_cause text,
 resolution text,
 safety_cleared boolean not null default false,
 labor_cost numeric(18,2) not null default 0 check (labor_cost>=0),
 created_by uuid references auth.users(id) on delete set null,
 updated_at timestamptz not null default now(),
 unique (organization_id,order_number),
 check ((plan_id is null and occurrence_due_on is null) or (plan_id is not null and occurrence_due_on is not null and job_type='preventive')),
 check (started_at is null or started_at>=reported_at),
 check (completed_at is null or (started_at is not null and completed_at>=started_at)),
 check (status<>'completed' or (completed_at is not null and safety_cleared and length(btrim(coalesce(root_cause,'')))>0 and length(btrim(coalesce(resolution,'')))>0))
);
create unique index maintenance_pm_occurrence_idx on public.maintenance_work_orders(plan_id,occurrence_due_on) where plan_id is not null;
create index maintenance_work_orders_queue_idx on public.maintenance_work_orders(organization_id,factory_id,status,priority,reported_at desc);

create table public.maintenance_spare_requirements (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 factory_id uuid not null references public.factories(id) on delete restrict,
 work_order_id uuid not null references public.maintenance_work_orders(id) on delete restrict,
 item_id uuid not null references public.items(id) on delete restrict,
 requested_quantity numeric(18,4) not null check (requested_quantity>0),
 stock_transaction_line_id uuid unique references public.stock_transaction_lines(id) on delete restrict,
 created_at timestamptz not null default now(),
 unique (work_order_id,item_id)
);
create index maintenance_spares_work_order_idx on public.maintenance_spare_requirements(work_order_id);

create table public.maintenance_events (
 id bigint generated always as identity primary key,
 organization_id uuid not null references public.organizations(id) on delete restrict,
 factory_id uuid not null references public.factories(id) on delete restrict,
 work_order_id uuid not null references public.maintenance_work_orders(id) on delete restrict,
 event_type text not null check (length(btrim(event_type))>0),
 details jsonb not null default '{}'::jsonb,
 actor_user_id uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now()
);
create index maintenance_events_work_order_idx on public.maintenance_events(work_order_id,created_at);

create trigger maintenance_assets_updated before update on public.maintenance_assets for each row execute function private.set_updated_at();
create trigger maintenance_plans_updated before update on public.maintenance_plans for each row execute function private.set_updated_at();
create trigger maintenance_work_orders_updated before update on public.maintenance_work_orders for each row execute function private.set_updated_at();

create or replace function private.validate_maintenance_scope()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
declare parent_org uuid; parent_factory uuid; parent_asset uuid;
begin
 if tg_table_name='maintenance_assets' then
   select organization_id into parent_org from public.factories where id=new.factory_id;
 elsif tg_table_name='maintenance_plans' then
   select organization_id,factory_id into parent_org,parent_factory from public.maintenance_assets where id=new.asset_id;
 elsif tg_table_name='maintenance_work_orders' then
   select organization_id,factory_id into parent_org,parent_factory from public.maintenance_assets where id=new.asset_id;
   if new.plan_id is not null then
     select asset_id into parent_asset from public.maintenance_plans
       where id=new.plan_id and organization_id=new.organization_id and factory_id=new.factory_id;
     if parent_asset is distinct from new.asset_id then raise exception 'maintenance plan must match asset'; end if;
   end if;
   if new.assigned_employee_id is not null and not exists (
     select 1 from public.employees where id=new.assigned_employee_id and organization_id=new.organization_id and factory_id=new.factory_id
   ) then raise exception 'maintenance assignee must belong to factory'; end if;
 elsif tg_table_name in ('maintenance_spare_requirements','maintenance_events') then
   select organization_id,factory_id into parent_org,parent_factory from public.maintenance_work_orders where id=new.work_order_id;
 end if;
 if parent_org is distinct from new.organization_id or
   (parent_factory is not null and parent_factory is distinct from new.factory_id)
 then raise exception 'maintenance organization/factory mismatch'; end if;
 if tg_table_name='maintenance_spare_requirements' then
   if not exists (select 1 from public.items where id=new.item_id and organization_id=new.organization_id)
   then raise exception 'spare item must belong to organization'; end if;
   if new.stock_transaction_line_id is not null and not exists (
     select 1 from public.stock_transaction_lines l
     join public.stock_transactions t on t.id=l.stock_transaction_id
     where l.id=new.stock_transaction_line_id
       and l.organization_id=new.organization_id and l.item_id=new.item_id
       and l.quantity_delta=-new.requested_quantity
       and t.organization_id=new.organization_id and t.factory_id=new.factory_id
       and t.transaction_type='maintenance_issue' and t.status='posted'
       and t.reference_type='maintenance_work_order' and t.reference_id=new.work_order_id
   ) then raise exception 'spare issue requires matching posted maintenance ledger line'; end if;
 end if;
 return new;
end;
$$;
create trigger maintenance_assets_scope before insert or update on public.maintenance_assets for each row execute function private.validate_maintenance_scope();
create trigger maintenance_plans_scope before insert or update on public.maintenance_plans for each row execute function private.validate_maintenance_scope();
create trigger maintenance_orders_scope before insert or update on public.maintenance_work_orders for each row execute function private.validate_maintenance_scope();
create trigger maintenance_spares_scope before insert or update on public.maintenance_spare_requirements for each row execute function private.validate_maintenance_scope();
create trigger maintenance_events_scope before insert on public.maintenance_events for each row execute function private.validate_maintenance_scope();
revoke all on function private.validate_maintenance_scope() from public;

create or replace function private.guard_maintenance_finality()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 if tg_table_name='maintenance_work_orders' then
   if tg_op='DELETE' then raise exception 'work orders cannot be deleted'; end if;
   if old.status in ('completed','cancelled') then raise exception 'final work order is immutable'; end if;
   if new.status='completed' and exists (
     select 1 from public.maintenance_spare_requirements s
     where s.work_order_id=new.id and s.stock_transaction_line_id is null
   ) then raise exception 'cannot close with unposted spare requirements'; end if;
   if new.status='completed' and new.status is distinct from old.status and old.status not in ('in_progress','waiting_parts')
   then raise exception 'work order must be in progress before completion'; end if;
   return new;
 end if;
 if tg_op='DELETE' then
   if exists(select 1 from public.maintenance_work_orders w where w.id=old.work_order_id and w.status in ('completed','cancelled'))
   then raise exception 'final work order parts cannot change'; end if;
   return old;
 end if;
 if exists(select 1 from public.maintenance_work_orders w where w.id=new.work_order_id and w.status in ('completed','cancelled'))
 then raise exception 'final work order parts cannot change'; end if;
 return new;
end;
$$;
create trigger maintenance_orders_guard before update or delete on public.maintenance_work_orders for each row execute function private.guard_maintenance_finality();
create trigger maintenance_spares_guard before insert or update or delete on public.maintenance_spare_requirements for each row execute function private.guard_maintenance_finality();
revoke all on function private.guard_maintenance_finality() from public;
