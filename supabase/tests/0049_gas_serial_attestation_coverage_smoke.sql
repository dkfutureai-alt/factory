-- Phase 21C: isolated honest serial evidence coverage, never production seed.
begin;
insert into auth.users(
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '54900000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','gas-coverage-ci@factoryos.test',
  crypt('LocalOnly12345!',gen_salt('bf')),now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into public.organization_members(organization_id,user_id,role)
values(
  '10000000-0000-4000-8000-000000000001',
  '54900000-0000-4000-8000-000000000001','org_admin'
);
insert into public.inventory_transactions(
  id,organization_id,factory_id,item_id,transaction_type,quantity,
  to_location_id,occurred_at,external_reference
) values(
  '54900000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '43000000-0000-4000-8000-000000000003',
  'receive',2,'44000000-0000-4000-8000-000000000003',
  now()+interval '1 day','COVERAGE-TEST-RECEIPT'
);
insert into public.stock_ledger_entries(
  organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta
) values(
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '54900000-0000-4000-8000-000000000002',
  '43000000-0000-4000-8000-000000000003',
  '44000000-0000-4000-8000-000000000003',2
);

set local role authenticated;
select set_config('request.jwt.claim.sub','54900000-0000-4000-8000-000000000001',true);
do $$
declare
  v_asset uuid; v_r record; v_link uuid; v_blocked boolean := false;
begin
  select * into v_r from public.gas_serial_attestation_coverage(
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',200
  ) where transaction_id='54900000-0000-4000-8000-000000000002';
  if v_r.transaction_id is null or v_r.quantity<>2 or
     v_r.linked_serial_count<>0 or v_r.unattested_quantity<>2 or
     v_r.coverage_status<>'not_attested' then
    raise exception 'Unattested cylinder receipt not reported honestly';
  end if;

  v_asset:=public.gas_register_container(
    '20000000-0000-4000-8000-000000000001',
    '43000000-0000-4000-8000-000000000003',
    'COVERAGE-CYL-01','cylinder'
  );
  v_link:=public.gas_link_container_transaction(
    v_asset,'54900000-0000-4000-8000-000000000002',
    'COVERAGE-CYL-01','54900000-0000-4000-8000-000000000003'
  );
  if v_link is null then raise exception 'Serial attestation link missing'; end if;

  select * into v_r from public.gas_serial_attestation_coverage(
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',200
  ) where transaction_id='54900000-0000-4000-8000-000000000002';
  if v_r.linked_serial_count<>1 or v_r.unattested_quantity<>1
    or v_r.coverage_status<>'partially_attested' then
    raise exception 'Partial serial evidence was falsely reported as complete';
  end if;

  begin
    perform * from public.gas_serial_attestation_coverage(
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',501
    );
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Unbounded report limit accepted'; end if;
  v_blocked:=false;
  begin
    perform * from public.gas_serial_attestation_coverage(
      '10000000-0000-4000-8000-000000000001',
      '54900000-0000-4000-8000-000000000099',200
    );
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Unauthorized factory report accepted'; end if;
end $$;

select set_config('request.jwt.claim.sub','54900000-0000-4000-8000-000000000099',true);
do $$
declare blocked boolean:=false;
begin
  begin
    perform * from public.gas_serial_attestation_coverage(
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',200
    );
  exception when others then blocked:=true;
  end;
  if not blocked then raise exception 'Unassigned user can query gas serial coverage'; end if;
end $$;

reset role;
do $$
begin
  if has_function_privilege('anon',
    'public.gas_serial_attestation_coverage(uuid,uuid,integer)','execute') then
    raise exception 'Anonymous caller can request gas serial coverage';
  end if;
  if not has_function_privilege('authenticated',
    'public.gas_serial_attestation_coverage(uuid,uuid,integer)','execute') then
    raise exception 'Authenticated caller lost scoped coverage API';
  end if;
end $$;
rollback;
select 'Phase 21C quantity-vs-serial coverage, partial counts and RLS passed' as result;
