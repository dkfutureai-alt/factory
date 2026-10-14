-- FactoryOS Maintenance command layer. Apply after 09a_maintenance_security.sql.
-- Commands preserve the Inventory ledger as the only source of spare consumption.

create or replace function private.validate_maintenance_status_transition()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.status is not distinct from old.status then return new; end if;

  if old.status = 'reported' and new.status in ('assigned','in_progress','cancelled') then return new; end if;
  if old.status = 'assigned' and new.status in ('in_progress','cancelled') then return new; end if;
  if old.status = 'in_progress' and new.status in ('waiting_parts','completed','cancelled') then return new; end if;
  if old.status = 'waiting_parts' and new.status in ('in_progress','completed','cancelled') then return new; end if;

  raise exception 'invalid maintenance work-order transition: % -> %', old.status, new.status;
end;
$$;

create trigger maintenance_orders_validate_transition
before update on public.maintenance_work_orders
for each row execute function private.validate_maintenance_status_transition();

revoke all on function private.validate_maintenance_status_transition() from public;

create or replace function public.create_preventive_work_order(target_plan_id uuid, target_due_on date)
returns public.maintenance_work_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  plan_row public.maintenance_plans;
  result_row public.maintenance_work_orders;
  created_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;

  select * into plan_row
  from public.maintenance_plans
  where id = target_plan_id
  for update;

  if plan_row.id is null then raise exception 'maintenance plan not found'; end if;
  if not plan_row.is_active then raise exception 'maintenance plan is inactive'; end if;
  if target_due_on <> plan_row.next_due_on then raise exception 'preventive occurrence must match plan next due date'; end if;
  if not private.has_permission(plan_row.organization_id,'maintenance.manage',plan_row.factory_id) then
    raise exception 'permission denied';
  end if;

  insert into public.maintenance_work_orders(
    organization_id,factory_id,order_number,asset_id,plan_id,occurrence_due_on,
    job_type,priority,status,problem_description,created_by
  ) values (
    plan_row.organization_id,
    plan_row.factory_id,
    'PM-' || plan_row.schedule_code || '-' || to_char(target_due_on,'YYYYMMDD'),
    plan_row.asset_id,
    plan_row.id,
    target_due_on,
    'preventive',
    'normal',
    'reported',
    plan_row.task_name,
    (select auth.uid())
  )
  on conflict (plan_id,occurrence_due_on) where plan_id is not null do nothing
  returning id into created_id;

  if created_id is null then
    select * into result_row
    from public.maintenance_work_orders
    where plan_id=target_plan_id and occurrence_due_on=target_due_on;
    return result_row;
  end if;

  insert into public.maintenance_events(organization_id,factory_id,work_order_id,event_type,details,actor_user_id)
  values(plan_row.organization_id,plan_row.factory_id,created_id,'preventive_created',jsonb_build_object('plan_id',target_plan_id,'due_on',target_due_on),(select auth.uid()));

  select * into result_row from public.maintenance_work_orders where id=created_id;
  return result_row;
end;
$$;

revoke all on function public.create_preventive_work_order(uuid,date) from public;
grant execute on function public.create_preventive_work_order(uuid,date) to authenticated;

create or replace function public.start_maintenance_work_order(target_work_order_id uuid)
returns public.maintenance_work_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  work_row public.maintenance_work_orders;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;

  select * into work_row
  from public.maintenance_work_orders
  where id=target_work_order_id
  for update;

  if work_row.id is null then raise exception 'maintenance work order not found'; end if;
  if not private.has_permission(work_row.organization_id,'maintenance.manage',work_row.factory_id) then raise exception 'permission denied'; end if;
  if work_row.status='in_progress' then return work_row; end if;
  if work_row.status not in ('reported','assigned','waiting_parts') then raise exception 'work order cannot be started from status %',work_row.status; end if;

  update public.maintenance_work_orders
  set status='in_progress', started_at=coalesce(started_at,now())
  where id=work_row.id
  returning * into work_row;

  update public.maintenance_assets
  set status='maintenance'
  where id=work_row.asset_id and status<>'inactive';

  insert into public.maintenance_events(organization_id,factory_id,work_order_id,event_type,details,actor_user_id)
  values(work_row.organization_id,work_row.factory_id,work_row.id,'started','{}'::jsonb,(select auth.uid()));

  return work_row;
end;
$$;

revoke all on function public.start_maintenance_work_order(uuid) from public;
grant execute on function public.start_maintenance_work_order(uuid) to authenticated;

create or replace function public.set_maintenance_safety_clearance(target_work_order_id uuid, cleared boolean)
returns public.maintenance_work_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  work_row public.maintenance_work_orders;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  select * into work_row from public.maintenance_work_orders where id=target_work_order_id for update;
  if work_row.id is null then raise exception 'maintenance work order not found'; end if;
  if not private.has_permission(work_row.organization_id,'maintenance.manage',work_row.factory_id) then raise exception 'permission denied'; end if;
  if work_row.status not in ('in_progress','waiting_parts') then raise exception 'safety clearance can change only on active work orders'; end if;

  update public.maintenance_work_orders set safety_cleared=cleared where id=work_row.id returning * into work_row;
  insert into public.maintenance_events(organization_id,factory_id,work_order_id,event_type,details,actor_user_id)
  values(work_row.organization_id,work_row.factory_id,work_row.id,'safety_clearance',jsonb_build_object('cleared',cleared),(select auth.uid()));
  return work_row;
end;
$$;

revoke all on function public.set_maintenance_safety_clearance(uuid,boolean) from public;
grant execute on function public.set_maintenance_safety_clearance(uuid,boolean) to authenticated;

create or replace function public.complete_maintenance_work_order(target_work_order_id uuid, target_root_cause text, target_resolution text)
returns public.maintenance_work_orders
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  work_row public.maintenance_work_orders;
  plan_row public.maintenance_plans;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  if length(btrim(coalesce(target_root_cause,'')))=0 then raise exception 'root cause required'; end if;
  if length(btrim(coalesce(target_resolution,'')))=0 then raise exception 'resolution required'; end if;

  select * into work_row
  from public.maintenance_work_orders
  where id=target_work_order_id
  for update;

  if work_row.id is null then raise exception 'maintenance work order not found'; end if;
  if not private.has_permission(work_row.organization_id,'maintenance.manage',work_row.factory_id) then raise exception 'permission denied'; end if;
  if work_row.status='completed' then return work_row; end if;
  if work_row.status not in ('in_progress','waiting_parts') then raise exception 'work order must be active before completion'; end if;
  if not work_row.safety_cleared then raise exception 'safety clearance required'; end if;
  if exists(select 1 from public.maintenance_spare_requirements s where s.work_order_id=work_row.id and s.stock_transaction_line_id is null) then
    raise exception 'all required spare issues must be posted before completion';
  end if;

  update public.maintenance_work_orders
  set status='completed', completed_at=now(), root_cause=btrim(target_root_cause), resolution=btrim(target_resolution)
  where id=work_row.id
  returning * into work_row;

  if not exists(
    select 1 from public.maintenance_work_orders other
    where other.asset_id=work_row.asset_id and other.id<>work_row.id and other.status not in ('completed','cancelled')
  ) then
    update public.maintenance_assets set status='operational' where id=work_row.asset_id and status<>'inactive';
  end if;

  if work_row.plan_id is not null then
    select * into plan_row from public.maintenance_plans where id=work_row.plan_id for update;
    update public.maintenance_plans
    set last_completed_on=current_date,
        next_due_on=greatest(current_date,coalesce(work_row.occurrence_due_on,current_date)) + plan_row.interval_days
    where id=plan_row.id;
  end if;

  insert into public.maintenance_events(organization_id,factory_id,work_order_id,event_type,details,actor_user_id)
  values(work_row.organization_id,work_row.factory_id,work_row.id,'completed',jsonb_build_object('root_cause',work_row.root_cause,'resolution',work_row.resolution),(select auth.uid()));

  return work_row;
end;
$$;

revoke all on function public.complete_maintenance_work_order(uuid,text,text) from public;
grant execute on function public.complete_maintenance_work_order(uuid,text,text) to authenticated;
