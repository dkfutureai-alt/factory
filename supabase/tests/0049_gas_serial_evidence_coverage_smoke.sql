-- Phase 21C: rollback-only quantity-vs-attested-serial coverage and RLS.
begin;
insert into auth.users(
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '54900000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','coverage-ci@factoryos.test',
  crypt('LocalOnly12345!',gen_salt('bf')),now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into public.organization_members(organization_id,user_id,role)
values(
  '10000000-0000-4000-8000-000000000001',
  '54900000-0000-4000-8000-000000000001','org_admin'
);

insert into public.inventory_transactions(
  id,organization_id,factory_id,item_id,transaction_type,quantity,to_location_id,external_reference
) values
  ('54900000-0000-4000-8000-000000000010',
   '10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '43000000-0000-4000-8000-000000000003',
   'receive',2,'44000000-0000-4000-8000-000000000003','COVERAGE-PARTIAL'),
  ('54900000-0000-4000-8000-000000000011',
   '10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '43000000-0000-4000-8000-000000000003',
   'receive',1,'44000000-0000-4000-8000-000000000003','COVERAGE-MISSING'),
  ('54900000-0000-4000-8000-000000000012',
   '10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '43000000-0000-4000-8000-000000000003',
   'receive',1,'44000000-0000-4000-8000-000000000003','COVERAGE-COMPLETE');

insert into public.stock_ledger_entries(
  organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta
) values
  ('10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '54900000-0000-4000-8000-000000000010',
   '43000000-0000-4000-8000-000000000003',
   '44000000-0000-4000-8000-000000000003',2),
  ('10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '54900000-0000-4000-8000-000000000011',
   '43000000-0000-4000-8000-000000000003',
   '44000000-0000-4000-8000-000000000003',1),
  ('10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '54900000-0000-4000-8000-000000000012',
   '43000000-0000-4000-8000-000000000003',
   '44000000-0000-4000-8000-000000000003',1);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub','54900000-0000-4000-8000-000000000001',true
);

do $$
declare v_a uuid; v_b uuid; v_blocked boolean;
begin
  v_a:=public.gas_register_container(
    '20000000-0000-4000-8000-000000000001',
    '43000000-0000-4000-8000-000000000003',
    'COVER-CYL-A','cylinder'
  );
  v_b:=public.gas_register_container(
    '20000000-0000-4000-8000-000000000001',
    '43000000-0000-4000-8000-000000000003',
    'COVER-CYL-B','cylinder'
  );
  perform public.gas_link_container_transaction(
    v_a,'54900000-0000-4000-8000-000000000010',
    'COVER-CYL-A','54900000-0000-4000-8000-000000000020'
  );
  perform public.gas_link_container_transaction(
    v_b,'54900000-0000-4000-8000-000000000012',
    'COVER-CYL-B','54900000-0000-4000-8000-000000000021'
  );

  if not exists(
    select 1 from public.gas_serial_transaction_coverage(
      '20000000-0000-4000-8000-000000000001',200,false
    ) c where c.transaction_id='54900000-0000-4000-8000-000000000010'
      and c.posted_quantity=2 and c.linked_serial_count=1
      and c.unlinked_quantity=1 and c.coverage_status='partial'
  ) then raise exception 'Partial serial coverage misreported'; end if;
  if not exists(
    select 1 from public.gas_serial_transaction_coverage(
      '20000000-0000-4000-8000-000000000001',200,true
    ) c where c.transaction_id='54900000-0000-4000-8000-000000000011'
      and c.posted_quantity=1 and c.linked_serial_count=0
      and c.unlinked_quantity=1 and c.coverage_status='missing'
  ) then raise exception 'Missing serial coverage misreported'; end if;
  if not exists(
    select 1 from public.gas_serial_transaction_coverage(
      '20000000-0000-4000-8000-000000000001',200,false
    ) c where c.transaction_id='54900000-0000-4000-8000-000000000012'
      and c.posted_quantity=1 and c.linked_serial_count=1
      and c.unlinked_quantity=0 and c.coverage_status='complete'
  ) then raise exception 'Complete serial coverage misreported'; end if;
  if exists(
    select 1 from public.gas_serial_transaction_coverage(
      '20000000-0000-4000-8000-000000000001',200,true
    ) c where c.transaction_id='54900000-0000-4000-8000-000000000012'
  ) then raise exception 'Missing-only incorrectly includes complete movement'; end if;

  v_blocked:=false;
  begin
    perform * from public.gas_serial_transaction_coverage(
      '20000000-0000-4000-8000-000000000001',201,false);
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Unbounded serial coverage query accepted'; end if;
end $$;

select set_config(
  'request.jwt.claim.sub','54900000-0000-4000-8000-000000000099',true
);
do $$
declare v_blocked boolean:=false;
begin
  begin
    perform * from public.gas_serial_transaction_coverage(
      '20000000-0000-4000-8000-000000000001',100,false);
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then
    raise exception 'Cross-tenant serial coverage query accepted';
  end if;
end $$;

reset role;
do $$
begin
  if has_function_privilege(
    'anon','public.gas_serial_transaction_coverage(uuid,integer,boolean)','execute'
  ) or not has_function_privilege(
    'authenticated','public.gas_serial_transaction_coverage(uuid,integer,boolean)','execute'
  ) then raise exception 'Unsafe serial coverage RPC grants'; end if;
end $$;
rollback;
select 'Phase 21C serial coverage partial/missing/complete/RLS passed' as result;
