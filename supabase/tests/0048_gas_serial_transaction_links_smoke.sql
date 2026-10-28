-- Phase 21B: rollback-only serial-to-Inventory link runtime tests.
begin;

insert into auth.users(
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values(
  '54800000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','gas-links-ci@factoryos.test',
  crypt('LocalOnly12345!',gen_salt('bf')),now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into public.organization_members(organization_id,user_id,role)
values(
  '10000000-0000-4000-8000-000000000001',
  '54800000-0000-4000-8000-000000000001','org_admin'
);

-- The linked stock postings already exist before a serial attestation.
-- This stage never changes their Inventory balances.
insert into public.inventory_transactions(
  id,organization_id,factory_id,item_id,transaction_type,quantity,to_location_id,external_reference
) values (
  '54800000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '43000000-0000-4000-8000-000000000003',
  'receive',1,'44000000-0000-4000-8000-000000000003','SERIAL-LINK-RECEIVE'
);

insert into public.stock_ledger_entries(
  organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta
) values(
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '54800000-0000-4000-8000-000000000002',
  '43000000-0000-4000-8000-000000000003',
  '44000000-0000-4000-8000-000000000003',1
);

insert into public.inventory_transactions(
  id,organization_id,factory_id,item_id,transaction_type,quantity,
  from_location_id,to_location_id,external_reference
) values (
  '54800000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '43000000-0000-4000-8000-000000000003',
  'transfer',1,
  '44000000-0000-4000-8000-000000000003',
  '98400000-0000-4000-8000-000000000010',
  'SERIAL-LINK-TRANSFER'
);
insert into public.stock_ledger_entries(
  organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta
) values
(
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '54800000-0000-4000-8000-000000000003',
  '43000000-0000-4000-8000-000000000003',
  '44000000-0000-4000-8000-000000000003',-1
),(
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '54800000-0000-4000-8000-000000000003',
  '43000000-0000-4000-8000-000000000003',
  '98400000-0000-4000-8000-000000000010',1
);

-- A forged issue is backed by a ledger entry but has no signed Dispatch POD.
insert into public.inventory_transactions(
  id,organization_id,factory_id,item_id,transaction_type,quantity,
  from_location_id,external_reference
) values(
  '54800000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '43000000-0000-4000-8000-000000000003',
  'issue',1,'98400000-0000-4000-8000-000000000010','NO-POD-ISSUE'
);
insert into public.stock_ledger_entries(
  organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta
) values (
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '54800000-0000-4000-8000-000000000004',
  '43000000-0000-4000-8000-000000000003',
  '98400000-0000-4000-8000-000000000010',-1
);

set local role authenticated;
select set_config('request.jwt.claim.sub','54800000-0000-4000-8000-000000000001',true);

do $$
declare
  v_asset uuid; v_asset2 uuid; v_receipt uuid; v_repeat uuid; v_move uuid;
  v_rejected boolean;
begin
  v_asset:=public.gas_register_container(
    '20000000-0000-4000-8000-000000000001',
    '43000000-0000-4000-8000-000000000003',
    'CUSTODY-CYL-001','cylinder'
  );

  v_rejected:=false;
  begin
    perform public.gas_link_container_transaction(
      v_asset,'54800000-0000-4000-8000-000000000003',
      'CUSTODY-CYL-001','54800000-0000-4000-8000-000000000021'
    );
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then
    raise exception 'Transfer was linked before initial receipt';
  end if;

  v_receipt:=public.gas_link_container_transaction(
    v_asset,'54800000-0000-4000-8000-000000000002',
    'CUSTODY-CYL-001','54800000-0000-4000-8000-000000000022'
  );
  v_repeat:=public.gas_link_container_transaction(
    v_asset,'54800000-0000-4000-8000-000000000002',
    'CUSTODY-CYL-001','54800000-0000-4000-8000-000000000022'
  );
  if v_receipt is null or v_receipt<>v_repeat then
    raise exception 'Identical request ID produced duplicate serial evidence';
  end if;

  v_asset2:=public.gas_register_container(
    '20000000-0000-4000-8000-000000000001',
    '43000000-0000-4000-8000-000000000003',
    'CUSTODY-CYL-002','cylinder'
  );
  v_rejected:=false;
  begin
    perform public.gas_link_container_transaction(
      v_asset2,'54800000-0000-4000-8000-000000000002',
      'CUSTODY-CYL-002','54800000-0000-4000-8000-000000000023'
    );
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then
    raise exception 'One-unit Inventory receipt linked two physical serials';
  end if;

  v_rejected:=false;
  begin
    perform public.gas_link_container_transaction(
      v_asset,'54800000-0000-4000-8000-000000000003',
      'WRONG-SERIAL','54800000-0000-4000-8000-000000000024'
    );
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Wrong scanned label was accepted'; end if;

  v_move:=public.gas_link_container_transaction(
    v_asset,'54800000-0000-4000-8000-000000000003',
    'CUSTODY-CYL-001','54800000-0000-4000-8000-000000000025'
  );
  if v_move is null or (
    select to_location_id from public.gas_container_transaction_links where id=v_move
  )<>'98400000-0000-4000-8000-000000000010'::uuid then
    raise exception 'Serial did not follow verified warehouse to vehicle transfer';
  end if;

  v_rejected:=false;
  begin
    perform public.gas_link_container_transaction(
      v_asset,'54800000-0000-4000-8000-000000000004',
      'CUSTODY-CYL-001','54800000-0000-4000-8000-000000000026'
    );
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then
    raise exception 'Customer issue without completed POD was accepted';
  end if;

  if (select count(*) from public.gas_container_transaction_links
      where asset_id=v_asset)<>2 then
    raise exception 'Unexpected duplicate serial-to-ledger mappings';
  end if;
  if not exists(
    select 1 from public.audit_logs
    where entity_type='gas_container_transaction_links'
      and integrity_hash is not null and metadata->>'asset_id'=v_asset::text
  ) then raise exception 'Serial evidence lacked tamper-evident audit'; end if;

  v_rejected:=false;
  begin
    update public.gas_container_transaction_links
    set customer_id=null where id=v_move;
  exception when others then v_rejected:=true;
  end;
  if not v_rejected then raise exception 'Authenticated client rewrote custody history'; end if;
end $$;

select set_config('request.jwt.claim.sub','54800000-0000-4000-8000-000000000099',true);
do $$
begin
  if (select count(*) from public.gas_container_transaction_links)>0 then
    raise exception 'Unassigned user read serialized custody history';
  end if;
end $$;

reset role;
do $$
begin
  if has_table_privilege('anon','public.gas_container_transaction_links','select')
     or has_table_privilege('authenticated','public.gas_container_transaction_links','insert')
     or has_table_privilege('authenticated','public.gas_container_transaction_links','update')
     or has_table_privilege('authenticated','public.gas_container_transaction_links','delete')
     or has_function_privilege('anon',
         'public.gas_link_container_transaction(uuid,uuid,text,uuid)','execute') then
     raise exception 'Unsafe serialized custody API grants';
  end if;
end $$;
rollback;
select 'Phase 21B serial evidence, capacity, POD and permission checks passed' as result;
