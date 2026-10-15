begin;

DO $$
DECLARE
  required_table text;
  rls_enabled boolean;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'inventory_categories','inventory_units','inventory_items','stock_locations','inventory_reorder_rules','inventory_transactions','stock_ledger_entries'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN
      RAISE EXCEPTION 'missing inventory table: %', required_table;
    END IF;
    SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid = to_regclass('public.' || required_table);
    IF NOT rls_enabled THEN RAISE EXCEPTION 'RLS disabled on inventory table: %', required_table; END IF;
  END LOOP;
END $$;

DO $$
DECLARE
  opening_qty numeric;
BEGIN
  IF (SELECT count(*) FROM public.inventory_items WHERE organization_id='10000000-0000-4000-8000-000000000001') < 5 THEN
    RAISE EXCEPTION 'inventory item demo data incomplete';
  END IF;
  IF (SELECT count(*) FROM public.stock_locations WHERE factory_id='20000000-0000-4000-8000-000000000001') < 5 THEN
    RAISE EXCEPTION 'stock location demo data incomplete';
  END IF;
  SELECT quantity_delta INTO opening_qty
  FROM public.stock_ledger_entries
  WHERE transaction_id='46000000-0000-4000-8000-000000000001'
    AND item_id='43000000-0000-4000-8000-000000000001'
    AND location_id='44000000-0000-4000-8000-000000000001';
  IF opening_qty <> 840 THEN RAISE EXCEPTION 'unexpected seeded oxygen opening ledger entry: %', opening_qty; END IF;
END $$;

DO $$
BEGIN
  IF to_regprocedure('public.inventory_receive_stock(uuid,uuid,uuid,numeric,numeric,text,text)') IS NULL THEN RAISE EXCEPTION 'inventory_receive_stock missing'; END IF;
  IF to_regprocedure('public.inventory_issue_stock(uuid,uuid,uuid,numeric,text,text)') IS NULL THEN RAISE EXCEPTION 'inventory_issue_stock missing'; END IF;
  IF to_regprocedure('public.inventory_transfer_stock(uuid,uuid,uuid,uuid,numeric,text,text)') IS NULL THEN RAISE EXCEPTION 'inventory_transfer_stock missing'; END IF;
  IF to_regprocedure('public.inventory_lookup_scan(uuid,text)') IS NULL THEN RAISE EXCEPTION 'inventory_lookup_scan missing'; END IF;
  IF to_regprocedure('public.inventory_dashboard_summary(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'inventory_dashboard_summary missing'; END IF;
  IF to_regprocedure('public.inventory_stock_report(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'inventory_stock_report missing'; END IF;
  IF to_regprocedure('public.inventory_reorder_report(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'inventory_reorder_report missing'; END IF;
  IF to_regprocedure('public.inventory_movement_report(uuid,uuid,timestamptz,timestamptz,integer)') IS NULL THEN RAISE EXCEPTION 'inventory_movement_report missing'; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stock_locations' AND policyname='stock_locations_select') THEN
    RAISE EXCEPTION 'stock_locations RLS policy missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stock_ledger_entries' AND policyname='stock_ledger_entries_select') THEN
    RAISE EXCEPTION 'stock ledger RLS policy missing';
  END IF;
END $$;

DO $$
BEGIN
  BEGIN
    update public.stock_ledger_entries set quantity_delta=1 where transaction_id='46000000-0000-4000-8000-000000000001';
    RAISE EXCEPTION 'ledger immutability trigger did not block update';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'ledger immutability trigger did not block update' THEN RAISE; END IF;
  END;
END $$;

rollback;