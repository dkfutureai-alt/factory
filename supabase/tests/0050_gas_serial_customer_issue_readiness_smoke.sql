-- Phase 31 rollback-only safety regression. These are artificial DB rows,
-- never customer operations or proof of an actual dispatch/POD.
begin;

do $$
declare
  v_asset uuid;
  v_tx uuid;
  v_key uuid;
  v_state text;
  v_condition text;
  v_due date;
  v_inspected timestamptz;
  v_expected boolean;
  v_rejected boolean;
  v_case integer;
  v_type text;
begin
  for v_case in 1..8 loop
    v_asset:=gen_random_uuid();
    v_tx:=gen_random_uuid();
    v_key:=gen_random_uuid();
    v_state:=case when v_case=1 then 'hold'
                  when v_case in (2,8) then 'quarantined'
                  else 'inspection_recorded' end;
    v_condition:=case when v_case=1 then 'unverified'
                     when v_case in (2,8) then 'damaged' else 'good' end;
    v_due:=case when v_case in (1,3) then null
                when v_case=4 then current_date - 1
                when v_case=7 then current_date
                else current_date + 14 end;
    v_inspected:=case when v_case in (1,5) then null
                      when v_case=6 then now()+interval '1 day'
                      else now() end;
    v_expected:=v_case in (7,8);
    v_type:=case when v_case=8 then 'transfer' else 'issue' end;

    insert into public.gas_container_assets(
      id,organization_id,factory_id,item_id,serial_number,qr_code,
      container_type,ownership,state,condition,test_due_on,last_inspection_at
    ) values(
      v_asset,
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',
      '43000000-0000-4000-8000-000000000003',
      'READINESS-'||v_case::text,
      'READINESS-QR-'||v_case::text,
      'cylinder','owned',v_state,v_condition,v_due,v_inspected
    );

    insert into public.inventory_transactions(
      id,organization_id,factory_id,item_id,transaction_type,quantity,
      from_location_id,to_location_id,external_reference
    ) values(
      v_tx,
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',
      '43000000-0000-4000-8000-000000000003',
      v_type,1,
      '44000000-0000-4000-8000-000000000003',
      case when v_type='transfer'
        then '98400000-0000-4000-8000-000000000010'::uuid
        else null end,
      'READINESS-LEDGER-TEST-'||v_case::text
    );

    v_rejected:=false;
    begin
      insert into public.gas_container_transaction_links(
        organization_id,factory_id,asset_id,transaction_id,request_key,
        transaction_type,from_location_id,to_location_id
      ) values(
        '10000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000001',
        v_asset,v_tx,v_key,v_type,
        '44000000-0000-4000-8000-000000000003',
        case when v_type='transfer'
          then '98400000-0000-4000-8000-000000000010'::uuid
          else null end
      );
    exception when others then
      if sqlerrm not like 'Customer issue serial attestation blocked:%' then
        raise exception 'Unexpected readiness test failure in fixture %: %',v_case,sqlerrm;
      end if;
      v_rejected:=true;
    end;

    if v_rejected = v_expected then
      raise exception 'Unexpected serialized customer issue readiness outcome for fixture %: rejected=%',v_case,v_rejected;
    end if;
    if (select count(*) from public.gas_container_transaction_links
        where transaction_id=v_tx) <> (case when v_expected then 1 else 0 end) then
      raise exception 'Serial issue readiness left an incorrect evidence row for fixture %',v_case;
    end if;
  end loop;
end $$;

do $$
begin
  if has_function_privilege('anon',
      'public.gas_serial_issue_readiness_guard()','execute')
     or has_function_privilege('authenticated',
      'public.gas_serial_issue_readiness_guard()','execute')
     or not exists(
       select 1 from pg_trigger t
       where t.tgname='gas_serial_issue_readiness'
       and t.tgrelid='public.gas_container_transaction_links'::regclass
       and not t.tgisinternal
     ) then
    raise exception 'Serialized issue safety guard privilege/trigger regression';
  end if;
end $$;

rollback;
select 'Phase 31 customer issue serial readiness (hold/quarantine/overdue/unverified/transfer/positive) passed' as result;
