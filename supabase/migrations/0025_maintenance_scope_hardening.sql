begin;

-- Phase 11 hardening: technicians may execute and review only work assigned to
-- their employee record. Managers/supervisors retain factory-wide visibility.

DROP POLICY IF EXISTS maintenance_requests_select ON public.maintenance_requests;
CREATE POLICY maintenance_requests_select ON public.maintenance_requests
FOR SELECT TO authenticated
USING (
  public.maintenance_can_supervise_factory(factory_id)
  OR reported_by = auth.uid()
);

DROP POLICY IF EXISTS maintenance_work_orders_select ON public.maintenance_work_orders;
CREATE POLICY maintenance_work_orders_select ON public.maintenance_work_orders
FOR SELECT TO authenticated
USING (
  public.maintenance_can_supervise_factory(factory_id)
  OR (
    assigned_employee_id IS NOT NULL
    AND assigned_employee_id = public.maintenance_current_employee(factory_id)
  )
);

DROP POLICY IF EXISTS maintenance_parts_select ON public.maintenance_part_usages;
CREATE POLICY maintenance_parts_select ON public.maintenance_part_usages
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.maintenance_work_orders w
    WHERE w.id = maintenance_part_usages.work_order_id
      AND w.factory_id = maintenance_part_usages.factory_id
      AND public.maintenance_can_operate_work_order(w.id)
  )
);

DROP POLICY IF EXISTS maintenance_downtime_select ON public.maintenance_downtime_events;
CREATE POLICY maintenance_downtime_select ON public.maintenance_downtime_events
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.maintenance_work_orders w
    WHERE w.id = maintenance_downtime_events.work_order_id
      AND w.factory_id = maintenance_downtime_events.factory_id
      AND public.maintenance_can_operate_work_order(w.id)
  )
);

DROP POLICY IF EXISTS maintenance_logs_select ON public.maintenance_work_logs;
CREATE POLICY maintenance_logs_select ON public.maintenance_work_logs
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.maintenance_work_orders w
    WHERE w.id = maintenance_work_logs.work_order_id
      AND w.factory_id = maintenance_work_logs.factory_id
      AND public.maintenance_can_operate_work_order(w.id)
  )
);

CREATE OR REPLACE FUNCTION public.maintenance_work_order_report(
  p_organization_id uuid,
  p_factory_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 100
)
RETURNS TABLE(
  work_order_id uuid,
  work_order_no text,
  asset_code text,
  asset_name text,
  work_type text,
  priority text,
  status text,
  assigned_employee text,
  scheduled_start_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  downtime_minutes integer,
  parts_quantity numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_factory_id IS NULL THEN
    IF NOT (
      public.is_platform_owner()
      OR public.has_org_role(
        p_organization_id,
        ARRAY['org_admin']::public.app_role[]
      )
    ) THEN
      RAISE EXCEPTION 'Not authorized for organization maintenance report';
    END IF;
  ELSE
    IF NOT (
      public.maintenance_can_supervise_factory(p_factory_id)
      AND EXISTS (
        SELECT 1
        FROM public.factories f
        WHERE f.id = p_factory_id
          AND f.organization_id = p_organization_id
      )
    ) THEN
      RAISE EXCEPTION 'Not authorized for factory maintenance report';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    w.id,
    w.work_order_no,
    a.asset_code,
    a.name,
    w.work_type,
    w.priority,
    w.status,
    COALESCE(e.full_name, ''),
    w.scheduled_start_at,
    w.started_at,
    w.completed_at,
    w.actual_downtime_minutes,
    COALESCE(SUM(pu.quantity), 0)
  FROM public.maintenance_work_orders w
  JOIN public.maintenance_assets a ON a.id = w.asset_id
  LEFT JOIN public.employees e ON e.id = w.assigned_employee_id
  LEFT JOIN public.maintenance_part_usages pu ON pu.work_order_id = w.id
  WHERE w.organization_id = p_organization_id
    AND (p_factory_id IS NULL OR w.factory_id = p_factory_id)
  GROUP BY w.id, a.asset_code, a.name, e.full_name
  ORDER BY w.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
END;
$$;

GRANT EXECUTE ON FUNCTION public.maintenance_work_order_report(uuid,uuid,integer)
TO authenticated;

commit;
