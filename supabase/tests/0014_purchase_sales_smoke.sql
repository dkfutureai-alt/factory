begin;

DO $$
DECLARE required_table text; rls_enabled boolean;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'business_partners','purchase_requisitions','purchase_requisition_lines','purchase_orders','purchase_order_lines',
    'goods_receipts','goods_receipt_lines','supplier_invoices','supplier_payments','quotations','quotation_lines',
    'sales_orders','sales_order_lines','sales_allocations','customer_invoices','customer_payments'
  ] LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN RAISE EXCEPTION 'missing Phase 7 table: %',required_table; END IF;
    SELECT relrowsecurity INTO rls_enabled FROM pg_class WHERE oid=to_regclass('public.' || required_table);
    IF NOT rls_enabled THEN RAISE EXCEPTION 'RLS disabled on Phase 7 table: %',required_table; END IF;
  END LOOP;
END $$;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.business_partners WHERE organization_id='10000000-0000-4000-8000-000000000001') < 4 THEN RAISE EXCEPTION 'business partner demo data incomplete'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.purchase_requisitions WHERE requisition_no='PR-DEMO-001' AND status='converted') THEN RAISE EXCEPTION 'demo requisition missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.purchase_orders WHERE purchase_order_no='PO-DEMO-P7-001' AND status='received') THEN RAISE EXCEPTION 'demo purchase order missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.goods_receipts WHERE goods_receipt_no='GRN-DEMO-P7-001' AND status='released' AND released_location_id='44000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'released demo goods receipt missing'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.goods_receipt_lines gl JOIN public.quality_inspections qi ON qi.id=gl.quality_inspection_id
    WHERE gl.goods_receipt_id='94500000-0000-4000-8000-000000000001' AND gl.quality_required AND qi.overall_result='pass'
  ) THEN RAISE EXCEPTION 'goods receipt incoming-quality link missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.supplier_invoices WHERE invoice_no='SUPINV-DEMO-P7-001' AND status='partially_paid' AND total_amount=708) THEN RAISE EXCEPTION 'supplier invoice/payment demo missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sales_orders WHERE sales_order_no='SO-DEMO-P7-001' AND status='dispatch_ready') THEN RAISE EXCEPTION 'dispatch-ready sales order demo missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sales_allocations WHERE sales_order_id='95200000-0000-4000-8000-000000000001' AND quantity=4 AND status='allocated') THEN RAISE EXCEPTION 'sales allocation demo missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.customer_invoices WHERE invoice_no='CINV-DEMO-P7-001' AND status='paid' AND total_amount=10500) THEN RAISE EXCEPTION 'customer invoice/payment demo missing'; END IF;
END $$;

DO $$
DECLARE receive_sum numeric; release_source numeric; release_dest numeric;
BEGIN
  SELECT coalesce(sum(quantity_delta),0) INTO receive_sum FROM public.stock_ledger_entries WHERE transaction_id='94200000-0000-4000-8000-000000000001';
  SELECT coalesce(sum(quantity_delta),0) INTO release_source FROM public.stock_ledger_entries WHERE transaction_id='94600000-0000-4000-8000-000000000001' AND location_id='44000000-0000-4000-8000-000000000006';
  SELECT coalesce(sum(quantity_delta),0) INTO release_dest FROM public.stock_ledger_entries WHERE transaction_id='94600000-0000-4000-8000-000000000001' AND location_id='44000000-0000-4000-8000-000000000001';
  IF receive_sum<>50 THEN RAISE EXCEPTION 'goods receipt inventory receive not ledger backed: %',receive_sum; END IF;
  IF release_source<>-50 OR release_dest<>50 THEN RAISE EXCEPTION 'goods receipt release ledger transfer invalid: source %, dest %',release_source,release_dest; END IF;
END $$;

DO $$
BEGIN
  IF to_regprocedure('public.commercial_create_requisition(uuid,date,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'commercial_create_requisition missing'; END IF;
  IF to_regprocedure('public.commercial_decide_requisition(uuid,text,text)') IS NULL THEN RAISE EXCEPTION 'commercial_decide_requisition missing'; END IF;
  IF to_regprocedure('public.commercial_create_purchase_order(uuid,uuid,uuid,date,text,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'commercial_create_purchase_order missing'; END IF;
  IF to_regprocedure('public.commercial_receive_goods(uuid,uuid,jsonb,text)') IS NULL THEN RAISE EXCEPTION 'commercial_receive_goods missing'; END IF;
  IF to_regprocedure('public.commercial_release_goods_receipt(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'commercial_release_goods_receipt missing'; END IF;
  IF to_regprocedure('public.commercial_create_supplier_invoice(uuid,text,date,date)') IS NULL THEN RAISE EXCEPTION 'supplier invoice RPC missing'; END IF;
  IF to_regprocedure('public.commercial_record_supplier_payment(uuid,numeric,text,text)') IS NULL THEN RAISE EXCEPTION 'supplier payment RPC missing'; END IF;
  IF to_regprocedure('public.commercial_create_quotation(uuid,uuid,date,text,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'quotation RPC missing'; END IF;
  IF to_regprocedure('public.commercial_convert_quotation(uuid,date)') IS NULL THEN RAISE EXCEPTION 'quotation conversion RPC missing'; END IF;
  IF to_regprocedure('public.commercial_allocate_sales_order(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'sales allocation RPC missing'; END IF;
  IF to_regprocedure('public.commercial_mark_dispatch_ready(uuid)') IS NULL THEN RAISE EXCEPTION 'dispatch readiness RPC missing'; END IF;
  IF to_regprocedure('public.commercial_create_customer_invoice(uuid,date,date)') IS NULL THEN RAISE EXCEPTION 'customer invoice RPC missing'; END IF;
  IF to_regprocedure('public.commercial_record_customer_payment(uuid,numeric,text,text)') IS NULL THEN RAISE EXCEPTION 'customer payment RPC missing'; END IF;
  IF to_regprocedure('public.commercial_dashboard_summary(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'commercial dashboard missing'; END IF;
  IF to_regprocedure('public.purchase_order_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'purchase report missing'; END IF;
  IF to_regprocedure('public.sales_order_report(uuid,uuid,integer)') IS NULL THEN RAISE EXCEPTION 'sales report missing'; END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='purchase_orders' AND policyname='purchase_orders_select') THEN RAISE EXCEPTION 'purchase order RLS policy missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='sales_orders' AND policyname='sales_orders_select') THEN RAISE EXCEPTION 'sales order RLS policy missing'; END IF;
END $$;

DO $$
BEGIN
  BEGIN
    update public.supplier_payments set amount=1 where id='94900000-0000-4000-8000-000000000001';
    RAISE EXCEPTION 'supplier payment immutability trigger did not block update';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='supplier payment immutability trigger did not block update' THEN RAISE; END IF;
  END;
  BEGIN
    delete from public.customer_payments where id='95600000-0000-4000-8000-000000000001';
    RAISE EXCEPTION 'customer payment immutability trigger did not block delete';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='customer payment immutability trigger did not block delete' THEN RAISE; END IF;
  END;
END $$;

rollback;
select 'purchase and sales smoke checks passed' as result;
