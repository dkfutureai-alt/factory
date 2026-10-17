begin;

-- Phase 15: Full QA & Performance.
-- Keep the write footprint narrow: these indexes target the date/range filters
-- used by the executive dashboard and daily trend only.
create index if not exists reports_customer_invoices_org_date_idx
  on public.customer_invoices(organization_id, invoice_date)
  include (factory_id, total_amount)
  where status <> 'cancelled';

create index if not exists reports_supplier_invoices_org_date_idx
  on public.supplier_invoices(organization_id, invoice_date)
  include (factory_id, total_amount)
  where status <> 'cancelled';

create index if not exists reports_stock_ledger_factory_item_idx
  on public.stock_ledger_entries(factory_id, item_id)
  include (quantity_delta);

create index if not exists reports_production_outputs_org_date_idx
  on public.production_outputs(organization_id, occurred_at)
  include (factory_id, good_quantity);

create index if not exists reports_production_orders_org_plan_date_idx
  on public.production_orders(organization_id, (coalesce(planned_start_at, created_at)))
  include (factory_id, planned_quantity)
  where status <> 'cancelled';

create index if not exists reports_quality_completed_org_date_idx
  on public.quality_inspections(organization_id, completed_at)
  include (factory_id, overall_result)
  where status = 'completed' and completed_at is not null;

create index if not exists reports_dispatch_delivered_org_date_idx
  on public.dispatch_deliveries(organization_id, delivered_at)
  include (factory_id)
  where status = 'delivered' and delivered_at is not null;

create index if not exists reports_maintenance_downtime_org_date_idx
  on public.maintenance_downtime_events(organization_id, started_at)
  include (factory_id, duration_minutes);

create index if not exists reports_attendance_org_date_idx
  on public.attendance_records(organization_id, work_date)
  include (factory_id, status);

-- Timestamp predicates are written as half-open ranges instead of casting the
-- indexed timestamp column to date. This keeps the semantics of an inclusive
-- date range while allowing Postgres to use the timestamp indexes above.
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
set search_path=''
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
    'production_output',coalesce((select sum(po.good_quantity) from public.production_outputs po where po.organization_id=p_organization_id and (p_factory_id is null or po.factory_id=p_factory_id) and po.occurred_at>=p_from::timestamptz and po.occurred_at<(p_to+1)::timestamptz),0),
    'previous_production_output',coalesce((select sum(po.good_quantity) from public.production_outputs po where po.organization_id=p_organization_id and (p_factory_id is null or po.factory_id=p_factory_id) and po.occurred_at>=v_prev_from::timestamptz and po.occurred_at<(v_prev_to+1)::timestamptz),0),
    'production_planned',coalesce((select sum(o.planned_quantity) from public.production_orders o where o.organization_id=p_organization_id and (p_factory_id is null or o.factory_id=p_factory_id) and coalesce(o.planned_start_at,o.created_at)>=p_from::timestamptz and coalesce(o.planned_start_at,o.created_at)<(p_to+1)::timestamptz and o.status<>'cancelled'),0),
    'quality_completed',(
      select count(*) from public.quality_inspections q where q.organization_id=p_organization_id and (p_factory_id is null or q.factory_id=p_factory_id) and q.status='completed' and q.completed_at>=p_from::timestamptz and q.completed_at<(p_to+1)::timestamptz
    ),
    'quality_pass_rate',coalesce((
      select round(100.0*count(*) filter(where q.overall_result='pass')/nullif(count(*),0),2)
      from public.quality_inspections q
      where q.organization_id=p_organization_id and (p_factory_id is null or q.factory_id=p_factory_id) and q.status='completed' and q.completed_at>=p_from::timestamptz and q.completed_at<(p_to+1)::timestamptz
    ),0),
    'open_ncrs',(select count(*) from public.quality_ncrs n where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and n.status<>'closed'),
    'open_sales_orders',(select count(*) from public.sales_orders so where so.organization_id=p_organization_id and (p_factory_id is null or so.factory_id=p_factory_id) and so.status in ('confirmed','allocated','dispatch_ready','dispatched')),
    'customer_due',coalesce((select sum(ci.total_amount-coalesce((select sum(cp.amount) from public.customer_payments cp where cp.customer_invoice_id=ci.id),0)) from public.customer_invoices ci where ci.organization_id=p_organization_id and (p_factory_id is null or ci.factory_id=p_factory_id) and ci.status not in ('paid','cancelled')),0),
    'supplier_due',coalesce((select sum(si.total_amount-coalesce((select sum(sp.amount) from public.supplier_payments sp where sp.supplier_invoice_id=si.id),0)) from public.supplier_invoices si where si.organization_id=p_organization_id and (p_factory_id is null or si.factory_id=p_factory_id) and si.status not in ('paid','cancelled')),0),
    'warehouse_open_picks',(select count(*) from public.warehouse_pick_lists p where p.organization_id=p_organization_id and (p_factory_id is null or p.factory_id=p_factory_id) and p.status in ('released','in_progress','picked','staged')),
    'active_trips',(select count(*) from public.fleet_trips t where t.organization_id=p_organization_id and (p_factory_id is null or t.factory_id=p_factory_id) and t.status in ('planned','assigned','started','arrived')),
    'deliveries_completed',(select count(*) from public.dispatch_deliveries d where d.organization_id=p_organization_id and (p_factory_id is null or d.factory_id=p_factory_id) and d.status='delivered' and d.delivered_at>=p_from::timestamptz and d.delivered_at<(p_to+1)::timestamptz),
    'dispatch_open_exceptions',(select count(*) from public.dispatch_delivery_exceptions e where e.organization_id=p_organization_id and (p_factory_id is null or e.factory_id=p_factory_id) and e.status='open'),
    'maintenance_open_work',(select count(*) from public.maintenance_work_orders w where w.organization_id=p_organization_id and (p_factory_id is null or w.factory_id=p_factory_id) and w.status in ('open','assigned','in_progress','on_hold')),
    'maintenance_assets_down',(select count(*) from public.maintenance_assets a where a.organization_id=p_organization_id and (p_factory_id is null or a.factory_id=p_factory_id) and a.is_active and a.status='down'),
    'maintenance_downtime_minutes',coalesce((select sum(d.duration_minutes) from public.maintenance_downtime_events d where d.organization_id=p_organization_id and (p_factory_id is null or d.factory_id=p_factory_id) and d.started_at>=p_from::timestamptz and d.started_at<(p_to+1)::timestamptz),0),
    'active_employees',(select count(*) from public.employees e where e.organization_id=p_organization_id and e.status='active' and (p_factory_id is null or e.primary_factory_id=p_factory_id)),
    'present_today',(select count(*) from public.attendance_records ar where ar.organization_id=p_organization_id and (p_factory_id is null or ar.factory_id=p_factory_id) and ar.work_date=current_date and ar.status in ('present','half_day'))
  ) into v_result;

  return v_result;
end;
$$;

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
set search_path=''
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
    select coalesce(o.planned_start_at,o.created_at)::date as day,sum(o.planned_quantity)::numeric as quantity
    from public.production_orders o
    where o.organization_id=p_organization_id and (p_factory_id is null or o.factory_id=p_factory_id) and o.status<>'cancelled' and coalesce(o.planned_start_at,o.created_at)>=p_from::timestamptz and coalesce(o.planned_start_at,o.created_at)<(p_to+1)::timestamptz
    group by coalesce(o.planned_start_at,o.created_at)::date
  ), output as (
    select po.occurred_at::date as day,sum(po.good_quantity)::numeric as quantity
    from public.production_outputs po
    where po.organization_id=p_organization_id and (p_factory_id is null or po.factory_id=p_factory_id) and po.occurred_at>=p_from::timestamptz and po.occurred_at<(p_to+1)::timestamptz
    group by po.occurred_at::date
  ), deliveries as (
    select d.delivered_at::date as day,count(*)::bigint as count
    from public.dispatch_deliveries d
    where d.organization_id=p_organization_id and (p_factory_id is null or d.factory_id=p_factory_id) and d.status='delivered' and d.delivered_at>=p_from::timestamptz and d.delivered_at<(p_to+1)::timestamptz
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

-- SECURITY DEFINER RPCs should not inherit PostgreSQL's default PUBLIC execute.
revoke all on function public.reports_executive_dashboard(uuid,uuid,date,date) from public, anon;
revoke all on function public.reports_daily_trend(uuid,uuid,date,date) from public, anon;
grant execute on function public.reports_executive_dashboard(uuid,uuid,date,date) to authenticated;
grant execute on function public.reports_daily_trend(uuid,uuid,date,date) to authenticated;

commit;
