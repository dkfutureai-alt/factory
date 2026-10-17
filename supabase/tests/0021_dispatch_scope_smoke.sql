begin;

DO $$
BEGIN
  IF to_regprocedure('public.can_view_dispatch_delivery(uuid)') IS NULL THEN
    RAISE EXCEPTION 'can_view_dispatch_delivery missing';
  END IF;

  IF NOT EXISTS(
    select 1 from pg_policies
    where schemaname='public'
      and tablename='dispatch_deliveries'
      and policyname='dispatch_deliveries_select'
      and qual ilike '%can_view_dispatch_delivery%'
  ) THEN RAISE EXCEPTION 'delivery select policy is not delivery-scoped'; END IF;

  IF NOT EXISTS(
    select 1 from pg_policies
    where schemaname='public'
      and tablename='dispatch_delivery_lines'
      and policyname='dispatch_lines_select'
      and qual ilike '%can_view_dispatch_delivery%'
  ) THEN RAISE EXCEPTION 'delivery line select policy is not delivery-scoped'; END IF;

  IF NOT EXISTS(
    select 1 from pg_policies
    where schemaname='public'
      and tablename='dispatch_delivery_exceptions'
      and policyname='dispatch_exceptions_select'
      and qual ilike '%can_view_dispatch_delivery%'
  ) THEN RAISE EXCEPTION 'delivery exception select policy is not delivery-scoped'; END IF;
END $$;

rollback;
select 'dispatch scope smoke checks passed' as result;
