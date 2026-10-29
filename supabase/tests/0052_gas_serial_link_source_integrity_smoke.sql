-- Phase 33: rollback-only source integrity checks for serialized evidence.
-- Uses fictional local fixtures; never run against real FactoryOS production.
begin;

do $$
declare
  v_org uuid := '10000000-0000-4000-8000-000000000001';
  v_factory uuid := '20000000-0000-4000-8000-000000000001';
  v_cylinder uuid := '43000000-0000-4000-8000-000000000003';
  v_gas uuid := '43000000-0000-4000-8000-000000000001';
  v_store uuid := '44000000-0000-4000-8000-000000000003';
  v_vehicle uuid := '98400000-0000-4000-8000-000000000010';
  v_asset_a uuid := gen_random_uuid();
  v_asset_b uuid := gen_random_uuid();
  v_good_tx uuid := gen_random_uuid();
  v_bad_tx uuid;
  v_case integer;
  v_type text;
  v_item uuid;
  v_quantity numeric;
  v_from uuid;
  v_to uuid;
  v_claimed_type text;
  v_claimed_to uuid;
  v_rejected boolean;
begin
  insert into public.gas_container_assets(
    id,organization_id,factory_id,item_id,serial_number,qr_code,
    container_type,ownership
  ) values
    (v_asset_a,v_org,v_factory,v_cylinder,'SOURCE-TEST-AAA','SOURCE-QR-AAA',
      'cylinder','owned'),
    (v_asset_b,v_org,v_factory,v_cylinder,'SOURCE-TEST-BBB','SOURCE-QR-BBB',
      'cylinder','owned');

  insert into public.inventory_transactions(
    id,organization_id,factory_id,item_id,transaction_type,quantity,
    to_location_id,external_reference
  ) values(
    v_good_tx,v_org,v_factory,v_cylinder,'receive',1,v_store,
    'SOURCE-VALID-RECEIVE'
  );

  -- Valid direct insertion remains possible for a trusted backend. The
  -- independent Phase 21B manager RPC still enforces custody/ledger/POD.
  insert into public.gas_container_transaction_links(
    organization_id,factory_id,asset_id,transaction_id,request_key,
    transaction_type,from_location_id,to_location_id
  ) values(
    v_org,v_factory,v_asset_a,v_good_tx,gen_random_uuid(),
    'receive',null,v_store
  );

  -- A 1-unit Inventory transaction may never be attested by two different
  -- serials, even if a privileged backend bypasses the normal RPC.
  v_rejected:=false;
  begin
    insert into public.gas_container_transaction_links(
      organization_id,factory_id,asset_id,transaction_id,request_key,
      transaction_type,from_location_id,to_location_id
    ) values(
      v_org,v_factory,v_asset_b,v_good_tx,gen_random_uuid(),
      'receive',null,v_store
    );
  exception when others then
    if sqlerrm not like 'Serial evidence source mismatch: Inventory quantity%' then
      raise exception 'Unexpected capacity rejection: %',sqlerrm;
    end if;
    v_rejected:=true;
  end;
  if not v_rejected then
    raise exception 'Privileged direct serial insertion bypassed whole-unit capacity';
  end if;

  for v_case in 1..4 loop
    v_bad_tx:=gen_random_uuid();
    v_type:=case when v_case=1 then 'issue' else 'receive' end;
    v_item:=case when v_case=3 then v_gas else v_cylinder end;
    v_quantity:=case when v_case=4 then 1.5 else 1 end;
    v_from:=case when v_case=1 then v_store else null end;
    v_to:=case when v_case=1 then null else v_store end;

    insert into public.inventory_transactions(
      id,organization_id,factory_id,item_id,transaction_type,quantity,
      from_location_id,to_location_id,external_reference
    ) values(
      v_bad_tx,v_org,v_factory,v_item,v_type,v_quantity,
      v_from,v_to,'SOURCE-INVALID-'||v_case::text
    );

    -- Case 1: disguise a true customer ISSUE as a TRANSFER to skip 0050.
    -- Case 2: claim the wrong physical destination for a RECEIVE.
    -- Case 3: attest a cylinder against a gas item instead.
    -- Case 4: claim a fractional cylinder quantity as a serialized unit.
    v_claimed_type:=case when v_case=1 then 'transfer' else 'receive' end;
    v_claimed_to:=case when v_case in (1,2) then v_vehicle else v_store end;
    v_rejected:=false;
    begin
      insert into public.gas_container_transaction_links(
        organization_id,factory_id,asset_id,transaction_id,request_key,
        transaction_type,from_location_id,to_location_id
      ) values(
        v_org,v_factory,v_asset_b,v_bad_tx,gen_random_uuid(),
        v_claimed_type,v_from,v_claimed_to
      );
    exception when others then
      if sqlerrm not like 'Serial evidence source mismatch:%' then
        raise exception 'Unexpected source-integrity fixture % failure: %',
          v_case,sqlerrm;
      end if;
      v_rejected:=true;
    end;
    if not v_rejected then
      raise exception 'Source-integrity fixture % allowed false serialized evidence',
        v_case;
    end if;
    if exists(
      select 1 from public.gas_container_transaction_links
      where transaction_id=v_bad_tx
    ) then
      raise exception 'Rejected serialized claim left evidence for fixture %',v_case;
    end if;
  end loop;

  if (select count(*) from public.gas_container_transaction_links
      where asset_id in (v_asset_a,v_asset_b))<>1 then
    raise exception 'Unexpected number of committed serialized evidence links';
  end if;
end $$;

do $$
begin
  if has_function_privilege(
       'anon','public.gas_serial_link_source_guard()','execute'
     )
     or has_function_privilege(
       'authenticated','public.gas_serial_link_source_guard()','execute'
     )
     or not exists(
       select 1 from pg_trigger
       where tgname='gas_serial_link_source_integrity'
         and tgrelid='public.gas_container_transaction_links'::regclass
         and not tgisinternal
     ) then
    raise exception 'Serial link source integrity trigger or privileges missing';
  end if;
end $$;

rollback;
select 'Phase 33 source-of-truth issue-spoof, location, item, fractional and capacity checks passed' as result;
