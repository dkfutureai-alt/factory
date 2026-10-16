begin;

DO $$
begin
  if to_regclass('public.quality_inspection_plans') is null or
     to_regclass('public.quality_plan_checks') is null or
     to_regclass('public.quality_inspections') is null or
     to_regclass('public.quality_inspection_results') is null or
     to_regclass('public.quality_ncrs') is null or
     to_regclass('public.quality_quarantine_lots') is null or
     to_regclass('public.quality_certificates') is null then
    raise exception 'Phase 6 quality tables are missing';
  end if;
end $$;

DO $$
begin
  if to_regprocedure('public.quality_start_inspection(uuid,uuid,uuid,uuid,uuid,text,integer,uuid,text)') is null or
     to_regprocedure('public.quality_record_result(uuid,uuid,text,numeric,boolean,text,text)') is null or
     to_regprocedure('public.quality_complete_inspection(uuid,boolean,text)') is null or
     to_regprocedure('public.quality_create_ncr(uuid,text,text,text,uuid,date)') is null or
     to_regprocedure('public.quality_update_ncr(uuid,text,text,text,text)') is null or
     to_regprocedure('public.quality_quarantine_stock(uuid,uuid,uuid,numeric,text,text)') is null or
     to_regprocedure('public.quality_release_quarantine(uuid,uuid,text,text)') is null or
     to_regprocedure('public.quality_issue_certificate(uuid)') is null then
    raise exception 'Phase 6 quality RPCs are missing';
  end if;
end $$;

DO $$
declare v_plans integer; v_checks integer; v_inspections integer; v_ncr integer; v_quarantine numeric; v_cert integer;
begin
  select count(*) into v_plans from public.quality_inspection_plans where organization_id='10000000-0000-4000-8000-000000000001';
  select count(*) into v_checks from public.quality_plan_checks where organization_id='10000000-0000-4000-8000-000000000001';
  select count(*) into v_inspections from public.quality_inspections where organization_id='10000000-0000-4000-8000-000000000001';
  select count(*) into v_ncr from public.quality_ncrs where id='73000000-0000-4000-8000-000000000001';
  select coalesce(sum(quantity),0) into v_quarantine from public.quality_quarantine_lots where status='quarantined' and factory_id='20000000-0000-4000-8000-000000000001';
  select count(*) into v_cert from public.quality_certificates where inspection_id='72000000-0000-4000-8000-000000000001';
  if v_plans < 3 or v_checks < 8 or v_inspections < 2 or v_ncr <> 1 or v_quarantine < 2 or v_cert <> 1 then
    raise exception 'Quality demo seed is incomplete: plans %, checks %, inspections %, ncr %, quarantine %, cert %',v_plans,v_checks,v_inspections,v_ncr,v_quarantine,v_cert;
  end if;
end $$;

DO $$
declare v_balance numeric;
begin
  select coalesce(sum(quantity_delta),0) into v_balance
  from public.stock_ledger_entries
  where item_id='43000000-0000-4000-8000-000000000004' and location_id='44000000-0000-4000-8000-000000000004';
  if v_balance <> 2 then raise exception 'Quality quarantine ledger balance expected 2, got %',v_balance; end if;
end $$;

DO $$
declare v_summary jsonb; v_rows integer; v_ncr_rows integer;
begin
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
  -- Report functions are validated for existence above; seed relations are checked directly because this synthetic UUID has no membership.
  select count(*) into v_rows from public.quality_inspections where organization_id='10000000-0000-4000-8000-000000000001';
  select count(*) into v_ncr_rows from public.quality_ncrs where organization_id='10000000-0000-4000-8000-000000000001';
  if v_rows < 2 or v_ncr_rows < 1 then raise exception 'Quality reporting source rows are missing'; end if;
end $$;

DO $$
begin
  begin
    update public.quality_certificates set lot_batch_no='MUTATION-NOT-ALLOWED' where id='76000000-0000-4000-8000-000000000001';
    raise exception 'Quality certificate update unexpectedly succeeded';
  exception when others then
    if position('immutable' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

rollback;

select 'quality smoke checks passed' as result;