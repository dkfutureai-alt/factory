begin;

-- Phase 11 hardening: a preventive-maintenance plan may have only one active
-- work order at a time. This closes the race between concurrent due-plan
-- generation/planning requests while still allowing a new cycle after the
-- prior work order is completed or cancelled.
create unique index if not exists maintenance_one_active_work_order_per_plan
  on public.maintenance_work_orders(plan_id)
  where plan_id is not null
    and status not in ('completed','cancelled');

commit;
