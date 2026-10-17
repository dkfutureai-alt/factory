begin;

-- Phase 12: Reports & Dashboards.
-- Reporting composes existing module truth; it never maintains a second operational balance.

create table public.report_saved_views (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  report_key text not null check (report_key in ('executive','operations','commercial','people','exceptions')),
  filters jsonb not null default '{}'::jsonb check (jsonb_typeof(filters)='object'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, report_key, name),
  foreign key (factory_id, organization_id) references public.factories(id, organization_id) on delete cascade
);
create unique index report_saved_views_default_unique
  on public.report_saved_views(user_id, report_key)
  where is_default;
create index report_saved_views_user_idx on public.report_saved_views(user_id, report_key, updated_at desc);
create trigger report_saved_views_set_updated_at before update on public.report_saved_views
for each row execute function public.set_updated_at();

create or replace function public.reports_can_view_factory(p_factory_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select public.can_manage_factory(p_factory_id)
    or exists(
      select 1
      from public.factory_members fm
      join public.organization_members om
        on om.organization_id=fm.organization_id
       and om.user_id=fm.user_id
       and om.is_active
      where fm.factory_id=p_factory_id
        and fm.user_id=auth.uid()
        and fm.is_active
        and om.role='supervisor'
    );
$$;
grant execute on function public.reports_can_view_factory(uuid) to authenticated;

create or replace function public.reports_scope_allowed(
  p_organization_id uuid,
  p_factory_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select case
    when auth.uid() is null then false
    when p_factory_id is null then
      public.is_platform_owner()
      or public.has_org_role(p_organization_id,array['org_admin']::public.app_role[])
    else
      exists(
        select 1 from public.factories f
        where f.id=p_factory_id
          and f.organization_id=p_organization_id
          and f.is_active
      )
      and public.reports_can_view_factory(p_factory_id)
  end;
$$;
grant execute on function public.reports_scope_allowed(uuid,uuid) to authenticated;

alter table public.report_saved_views enable row level security;
grant select,insert,update,delete on public.report_saved_views to authenticated;

create policy report_saved_views_select on public.report_saved_views
for select to authenticated
using (
  user_id=auth.uid()
  and public.reports_scope_allowed(organization_id,factory_id)
);
create policy report_saved_views_insert on public.report_saved_views
for insert to authenticated
with check (
  user_id=auth.uid()
  and public.reports_scope_allowed(organization_id,factory_id)
);
create policy report_saved_views_update on public.report_saved_views
for update to authenticated
using (user_id=auth.uid() and public.reports_scope_allowed(organization_id,factory_id))
with check (user_id=auth.uid() and public.reports_scope_allowed(organization_id,factory_id));
create policy report_saved_views_delete on public.report_saved_views
for delete to authenticated
using (user_id=auth.uid() and public.reports_scope_allowed(organization_id,factory_id));

create or replace function public.reports_validate_range(p_from date,p_to date,p_max_days integer default 366)
returns void
language plpgsql
immutable
set search_path=public
as $$
begin
  if p_from is null or p_to is null then raise exception 'Report dates are required'; end if;
  if p_to<p_from then raise exception 'Report end date cannot be before start date'; end if;
  if p_to-p_from>p_max_days then raise exception 'Report range cannot exceed % days',p_max_days; end if;
end;
$$;
revoke all on function public.reports_validate_range(date,date,integer) from public;

create or replace function public.reports_executive_dashboard(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_from date default (current_date-29),
  p_to date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_result jsonb;
  v_days integer;
  v_prev_from date;
  v_prev_to date;
begin
  perform public.reports_validate_range(p_from,p_to,366);
  if not public.reports_scope_allowed(p_organization_id,p_factory_id) then
    raise exception 'Not authorized for this report scope';
  end if;
  v_days:=p_to-p_from+1;
  v_prev_to:=p_from-1;
  v_prev_from:=v_prev_to-v_days+1;

  select jsonb_build_object(
    'period_from',p_from,
    'period_to',p_to,
    'sales_billed',coalesce((select sum(ci.total_amount) from public.customer_invoices ci where ci.organization_id=p_organization_id and (p_factory_id is null or ci.factory_id=p_factory_id) and ci.status<>'cancelled' and ci.invoice_date between p_from and p_to),0),
    'previous_sales_billed',coalesce((select sum(ci.total_amount) from public.customer_invoices ci where ci.organization_id=p_organization_id and (p_factory_id is null or ci.factory_id=p_factory_id) and ci.status<>'cancelled' and ci.invoice_date between v_prev_from and v_prev_to),0),
    'purchase_billed',coalesce((select sum(si.total_amount) from public.supplier_invoices si where si.organization_id=p_organization_id and (p_factory_id is null or si.factory_id=p_factory_id) and si.status<>'cancelled' and si.invoice_date between p_from and p_to),0),
    'previous_purchase_billed',coalesce((select sum(si.total_amount) from public.supplier_invoices si where si.organization_id=p_organization_id and (p_factory_id is null or si.factory_id=p_factory_id) and si.status<>'cancelled' and si.invoice_date between v_prev_from and v_prev_to),0),
    'inventory_quantity',coalesce((select sum(le.quantity_delta) from public.stock_ledger_entries le where le.organization_id=p_organization_id and (p_factory_id is null or le.factory_id=p_factory_id)),0),
    'low_stock_items',(
      select count(*) from (
        select rr.factory_id,rr.item_id
        from public.inventory_reorder_rules rr
        left join public.stock_ledger_entries le on le.factory_id=rr.factory_id and le.item_id=rr.item_id
        where rr.organization_id=p_organization_id and rr.is_active and (p_factory_id is null or rr.factory_id=p_factory_id)
        group by rr.factory_id,rr.item_id,rr.reorder_level
        having coalesce(sum(le.quantity_delta),0)<=rr.reorder_level
      ) s
    ),
    'production_output',coalesce((select sum(po.good_quantity) from public.production_outputs po where po.organization_id=p_organization_id and (p_factory_id is null or po.factory_id=p_factory_id) and po.occurred_at::date between p_from and p_to),0),
    'previous_production_output',coalesce((select sum(po.good_quantity) from public.production_outputs po where po.organization_id=p_organization_id and (p_factory_id is null or po.factory_id=p_factory_id) and po.occurred_at::date between v_prev_from and v_prev_to),0),
    'production_planned',coalesce((select sum(o.planned_quantity) from public.production_orders o where o.organization_id=p_organization_id and (p_factory_id is null or o.factory_id=p_factory_id) and coalesce(o.planned_start_at::date,o.created_at::date) between p_from and p_to and o.status<>'cancelled'),0),
    'quality_completed',(
      select count(*) from public.quality_inspections q where q.organization_id=p_organization_id and (p_factory_id is null or q.factory_id=p_factory_id) and q.status='completed' and q.completed_at::date between p_from and p_to
    ),
    'quality_pass_rate',coalesce((
      select round(100.0*count(*) filter(where q.overall_result='pass')/nullif(count(*),0),2)
      from public.quality_inspections q
      where q.organization_id=p_organization_id and (p_factory_id is null or q.factory_id=p_factory_id) and q.status='completed' and q.completed_at::date between p_from and p_to
    ),0),
    'open_ncrs',(select count(*) from public.quality_ncrs n where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and n.status<>'closed'),
    'open_sales_orders',(select count(*) from public.sales_orders so where so.organization_id=p_organization_id and (p_factory_id is null or so.factory_id=p_factory_id) and so.status in ('confirmed','allocated','dispatch_ready','dispatched')),
    'customer_due',coalesce((select sum(ci.total_amount-coalesce((select sum(cp.amount) from public.customer_payments cp where cp.customer_invoice_id=ci.id),0)) from public.customer_invoices ci where ci.organization_id=p_organization_id and (p_factory_id is null or ci.factory_id=p_factory_id) and ci.status not in ('paid','cancelled')),0),
    'supplier_due',coalesce((select sum(si.total_amount-coalesce((select sum(sp.amount) from public.supplier_payments sp where sp.supplier_invoice_id=si.id),0)) from public.supplier_invoices si where si.organization_id=p_organization_id and (p_factory_id is null or si.factory_id=p_factory_id) and si.status not in ('paid','cancelled')),0),
    'warehouse_open_picks',(select count(*) from public.warehouse_pick_lists p where p.organization_id=p_organization_id and (p_factory_id is null or p.factory_id=p_factory_id) and p.status in ('released','in_progress','picked','staged')),
    'active_trips',(select count(*) from public.fleet_trips t where t.organization_id=p_organization_id and (p_factory_id is null or t.factory_id=p_factory_id) and t.status in ('planned','assigned','started','arrived')),
    'deliveries_completed',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and (p_factory_id is null or d.factory_id=p_factory_id) and d.status='delivered' and d.delivered_at::date between p_from and p_to),
    'dispatch_open_exceptions',(select count(*) from public.dispatch_delivery_exceptions e where e.organization_id=p_organization_id and (p_factory_id is null or e.factory_id=p_factory_id) and e.status='open'),
    'maintenance_open_work',(select count(*) from public.maintenance_work_orders w where w.organization_id=p_organization_id and (p_factory_id is null or w.factory_id=p_factory_id) and w.status in ('open','assigned','in_progress','on_hold')),
    'maintenance_assets_down',(select count(*) from public.maintenance_assets a where a.organization_id=p_organization_id and (p_factory_id is null or a.factory_id=p_factory_id) and a.is_active and a.status='down'),
    'maintenance_downtime_minutes',coalesce((select sum(d.duration_minutes) from public.maintenance_downtime_events d where d.organization_id=p_organization_id and (p_factory_id is null or d.factory_id=p_factory_id) and d.started_at::date between p_from and p_to),0),
    'active_employees',(select count(*) from public.employees e where e.organization_id=p_organization_id and e.status='active' and (p_factory_id is null or e.primary_factory_id=p_factory_id)),
    'present_today',(select count(*) from public.attendance_records ar where ar.organization_id=p_organization_id and (p_factory_id is null or ar.factory_id=p_factory_id) and ar.work_date=current_date and ar.status in ('present','half_day'))
  ) into v_result;

  return v_result;
end;
$$;
grant execute on function public.reports_executive_dashboard(uuid,uuid,date,date) to authenticated;

create or replace function public.reports_daily_trend(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_from date default (current_date-29),
  p_to date default current_date
)
returns table(
  day date,
  sales_billed numeric,
  purchase_billed numeric,
  production_planned numeric,
  production_output numeric,
  deliveries_completed bigint
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  perform public.reports_validate_range(p_from,p_to,120);
  if not public.reports_scope_allowed(p_organization_id,p_factory_id) then
    raise exception 'Not authorized for this report scope';
  end if;
  return query
  with days as (
    select gs::date as day from generate_series(p_from::timestamp,p_to::timestamp,interval '1 day') gs
  ), sales as (
    select ci.invoice_date as day,sum(ci.total_amount)::numeric as amount
    from public.customer_invoices ci
    where ci.organization_id=p_organization_id and (p_factory_id is null or ci.factory_id=p_factory_id) and ci.status<>'cancelled' and ci.invoice_date between p_from and p_to
    group by ci.invoice_date
  ), purchases as (
    select si.invoice_date as day,sum(si.total_amount)::numeric as amount
    from public.supplier_invoices si
    where si.organization_id=p_organization_id and (p_factory_id is null or si.factory_id=p_factory_id) and si.status<>'cancelled' and si.invoice_date between p_from and p_to
    group by si.invoice_date
  ), planned as (
    select coalesce(o.planned_start_at::date,o.created_at::date) as day,sum(o.planned_quantity)::numeric as quantity
    from public.production_orders o
    where o.organization_id=p_organization_id and (p_factory_id is null or o.factory_id=p_factory_id) and o.status<>'cancelled' and coalesce(o.planned_start_at::date,o.created_at::date) between p_from and p_to
    group by coalesce(o.planned_start_at::date,o.created_at::date)
  ), output as (
    select po.occurred_at::date as day,sum(po.good_quantity)::numeric as quantity
    from public.production_outputs po
    where po.organization_id=p_organization_id and (p_factory_id is null or po.factory_id=p_factory_id) and po.occurred_at::date between p_from and p_to
    group by po.occurred_at::date
  ), deliveries as (
    select d.delivered_at::date as day,count(*)::bigint as count
    from public.dispatch_deliveries d
    where d.organization_id=p_organization_id and (p_factory_id is null or d.factory_id=p_factory_id) and d.status='delivered' and d.delivered_at::date between p_from and p_to
    group by d.delivered_at::date
  )
  select days.day,coalesce(sales.amount,0),coalesce(purchases.amount,0),coalesce(planned.quantity,0),coalesce(output.quantity,0),coalesce(deliveries.count,0)
  from days
  left join sales using(day)
  left join purchases using(day)
  left join planned using(day)
  left join output using(day)
  left join deliveries using(day)
  order by days.day;
end;
$$;
grant execute on function public.reports_daily_trend(uuid,uuid,date,date) to authenticated;

create or replace function public.reports_operational_exceptions(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_limit integer default 40
)
returns table(
  module text,
  severity text,
  title text,
  detail text,
  entity_type text,
  entity_id text,
  occurred_at timestamptz
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.reports_scope_allowed(p_organization_id,p_factory_id) then
    raise exception 'Not authorized for this report scope';
  end if;
  return query
  with exceptions as (
    select 'inventory'::text as module,
      case when coalesce(sum(le.quantity_delta),0)<=0 then 'high' else 'medium' end::text as severity,
      ('Low stock · '||i.name)::text as title,
      ('On hand '||coalesce(sum(le.quantity_delta),0)::text||' · reorder at '||rr.reorder_level::text)::text as detail,
      'inventory_item'::text as entity_type, i.id::text as entity_id, now() as occurred_at
    from public.inventory_reorder_rules rr
    join public.inventory_items i on i.id=rr.item_id
    left join public.stock_ledger_entries le on le.factory_id=rr.factory_id and le.item_id=rr.item_id
    where rr.organization_id=p_organization_id and rr.is_active and (p_factory_id is null or rr.factory_id=p_factory_id)
    group by i.id,i.name,rr.reorder_level
    having coalesce(sum(le.quantity_delta),0)<=rr.reorder_level

    union all
    select 'quality',case n.severity when 'critical' then 'critical' when 'high' then 'high' else 'medium' end,
      ('Open NCR · '||n.ncr_no),
      (i.name||' · '||n.category||case when n.due_date is not null and n.due_date<current_date then ' · overdue' else '' end),
      'quality_ncr',n.id::text,n.created_at
    from public.quality_ncrs n join public.inventory_items i on i.id=n.item_id
    where n.organization_id=p_organization_id and n.status<>'closed' and (p_factory_id is null or n.factory_id=p_factory_id)

    union all
    select 'sales',case when so.requested_delivery_date<current_date then 'high' else 'medium' end,
      ('Sales order · '||so.sales_order_no),
      ('Status '||so.status||coalesce(' · due '||so.requested_delivery_date::text,'')),
      'sales_order',so.id::text,so.created_at
    from public.sales_orders so
    where so.organization_id=p_organization_id and (p_factory_id is null or so.factory_id=p_factory_id)
      and so.status in ('confirmed','allocated','dispatch_ready','dispatched')
      and so.requested_delivery_date is not null and so.requested_delivery_date<=current_date

    union all
    select 'purchase',case when po.expected_date<current_date then 'high' else 'medium' end,
      ('Purchase order · '||po.purchase_order_no),
      ('Status '||po.status||coalesce(' · expected '||po.expected_date::text,'')),
      'purchase_order',po.id::text,po.created_at
    from public.purchase_orders po
    where po.organization_id=p_organization_id and (p_factory_id is null or po.factory_id=p_factory_id)
      and po.status in ('approved','sent','partially_received')
      and po.expected_date is not null and po.expected_date<=current_date

    union all
    select 'dispatch','high',('Delivery exception · '||d.delivery_no),
      (replace(e.exception_type,'_',' ')||' · '||e.details),
      'dispatch_exception',e.id::text,e.created_at
    from public.dispatch_delivery_exceptions e join public.dispatch_deliveries d on d.id=e.delivery_id
    where e.organization_id=p_organization_id and e.status='open' and (p_factory_id is null or e.factory_id=p_factory_id)

    union all
    select 'maintenance',case a.criticality when 'critical' then 'critical' else 'high' end,
      ('Asset down · '||a.asset_code),
      (a.name||' · '||a.criticality||' criticality'),
      'maintenance_asset',a.id::text,a.updated_at
    from public.maintenance_assets a
    where a.organization_id=p_organization_id and a.is_active and a.status='down' and (p_factory_id is null or a.factory_id=p_factory_id)

    union all
    select 'maintenance','high',('Overdue work · '||w.work_order_no),
      (a.name||' · '||w.priority||' priority'),
      'maintenance_work_order',w.id::text,coalesce(w.due_at,w.created_at)
    from public.maintenance_work_orders w join public.maintenance_assets a on a.id=w.asset_id
    where w.organization_id=p_organization_id and (p_factory_id is null or w.factory_id=p_factory_id)
      and w.status in ('open','assigned','in_progress','on_hold') and w.due_at is not null and w.due_at<now()
  )
  select e.module,e.severity,e.title,e.detail,e.entity_type,e.entity_id,e.occurred_at
  from exceptions e
  order by case e.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end,e.occurred_at desc
  limit greatest(1,least(coalesce(p_limit,40),200));
end;
$$;
grant execute on function public.reports_operational_exceptions(uuid,uuid,integer) to authenticated;

create or replace function public.reports_recent_activity(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_limit integer default 30
)
returns table(
  audit_id bigint,
  action text,
  entity_type text,
  entity_id text,
  actor_name text,
  occurred_at timestamptz
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.reports_scope_allowed(p_organization_id,p_factory_id) then
    raise exception 'Not authorized for this report scope';
  end if;
  return query
  select a.id,a.action,a.entity_type,a.entity_id,coalesce(p.full_name,'System'),a.created_at
  from public.audit_logs a
  left join public.profiles p on p.id=a.actor_user_id
  where a.organization_id=p_organization_id
    and (p_factory_id is null or a.factory_id=p_factory_id)
  order by a.created_at desc
  limit greatest(1,least(coalesce(p_limit,30),200));
end;
$$;
grant execute on function public.reports_recent_activity(uuid,uuid,integer) to authenticated;

create or replace function public.audit_report_saved_view_change()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_row public.report_saved_views%rowtype;
begin
  v_row:=case when tg_op='DELETE' then old else new end;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_row.organization_id,v_row.factory_id,auth.uid(),lower(tg_op),'report_saved_views',v_row.id::text,
    case when tg_op='DELETE' then jsonb_build_object('before',to_jsonb(old)) else jsonb_build_object('after',to_jsonb(new)) end);
  return coalesce(new,old);
end;
$$;
revoke all on function public.audit_report_saved_view_change() from public;
create trigger report_saved_views_audit after insert or update or delete on public.report_saved_views
for each row execute function public.audit_report_saved_view_change();

commit;
