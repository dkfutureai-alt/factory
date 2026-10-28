-- Phase 21A serialized container identity and inspection evidence.
-- Runs entirely in a rollback-only CI transaction; no live customer assets.
begin;

insert into auth.users(
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '54700000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','gas-registry-test@factoryos.test',
  crypt('TestOnly12345!',gen_salt('bf')),now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into public.organization_members(organization_id,user_id,role)
values(
  '10000000-0000-4000-8000-000000000001',
  '54700000-0000-4000-8000-000000000001','org_admin'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','54700000-0000-4000-8000-000000000001',true);

do $$
declare v_id uuid; v_qr text; v_e1 uuid; v_e2 uuid; v_count int; v_blocked boolean;
begin
  v_id:=public.gas_register_container(
    '20000000-0000-4000-8000-000000000001',
    '43000000-0000-4000-8000-000000000003',
    '  cyl-904/x  ','cylinder','owned',current_date-1,'Fixture only'
  );
  if v_id is null then raise exception 'Registration did not create an asset'; end if;
  select qr_code into v_qr from public.gas_container_assets where id=v_id;
  if v_qr !~ '^FA-[A-F0-9]{32}$'
     or (select serial_number from public.gas_container_assets where id=v_id)<>'CYL-904/X' then
    raise exception 'Serial/QR normalization failed';
  end if;
  if (select state from public.gas_container_assets where id=v_id)<>'hold'
     or (select count(*) from public.gas_container_asset_events
         where asset_id=v_id and event_type='registered')<>1 then
    raise exception 'New container must start as an unverified hold';
  end if;
  v_blocked:=false;
  begin
    perform public.gas_register_container(
      '20000000-0000-4000-8000-000000000001',
      '43000000-0000-4000-8000-000000000003',
      'CYL-904 /x','cylinder','owned'
    );
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Duplicate serial registration was accepted'; end if;

  v_e1:=public.gas_record_container_inspection(
    v_id,'good','No visible damage; certification still required'
  );
  if v_e1 is null or
    (select state from public.gas_container_assets where id=v_id)<>'inspection_recorded'
    or (select test_due_on from public.gas_container_assets where id=v_id)>=current_date then
      raise exception 'Inspection lost hold-only certification limitations';
  end if;

  v_e2:=public.gas_record_container_inspection(
    v_id,'damaged','Visible neck damage: quarantine'
  );
  if v_e2 is null or
     (select state from public.gas_container_assets where id=v_id)<>'quarantined' then
    raise exception 'Damaged cylinder did not enter quarantine state';
  end if;
  if (select count(*) from public.gas_container_asset_events where asset_id=v_id)<>3 then
    raise exception 'Immutable asset event history did not append';
  end if;

  v_blocked:=false;
  begin
    update public.gas_container_assets set state='hold' where id=v_id;
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Direct client asset state update was allowed'; end if;

  v_blocked:=false;
  begin
    delete from public.gas_container_asset_events where asset_id=v_id;
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Direct event history deletion was allowed'; end if;

  perform public.gas_retire_container(v_id,'Removed after failed inspection');
  if (select state from public.gas_container_assets where id=v_id)<>'retired'
     or (select count(*) from public.gas_container_asset_events where asset_id=v_id)<>4 then
    raise exception 'Retirement failed to record an immutable event';
  end if;
  v_blocked:=false;
  begin
    perform public.gas_record_container_inspection(v_id,'good','Cannot resurrect retired');
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Retired cylinder was re-inspected'; end if;

  -- Confirm a genuine hashed business audit entry was written by the trigger.
  if not exists (
    select 1 from public.audit_logs
    where entity_type='gas_container_assets' and entity_id=v_id::text
      and integrity_hash is not null
  ) then raise exception 'Container registration lacked tamper-evident audit'; end if;
end $$;

-- RLS: user with no assigned organization sees nothing and cannot register.
select set_config('request.jwt.claim.sub','54700000-0000-4000-8000-000000000099',true);
do $$
declare v_blocked boolean:=false;
begin
  if (select count(*) from public.gas_container_assets)>0
    or (select count(*) from public.gas_container_asset_events)>0 then
    raise exception 'Gas asset identity leaked across organization scope';
  end if;
  begin
    perform public.gas_register_container(
      '20000000-0000-4000-8000-000000000001',
      '43000000-0000-4000-8000-000000000003',
      'FAKE-UNAUTH','cylinder'
    );
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Unauthorized registration accepted'; end if;
end $$;

reset role;
do $$
begin
  if has_table_privilege('anon','public.gas_container_assets','select')
     or has_table_privilege('anon','public.gas_container_asset_events','select')
     or has_table_privilege('authenticated','public.gas_container_assets','insert')
     or has_table_privilege('authenticated','public.gas_container_assets','update')
     or has_table_privilege('authenticated','public.gas_container_asset_events','insert')
     or has_table_privilege('authenticated','public.gas_container_asset_events','delete')
     or not has_table_privilege('service_role','public.gas_container_assets','select') then
    raise exception 'Gas registry Data API grants violate least privilege';
  end if;
  if has_function_privilege('anon',
    'public.gas_register_container(uuid,uuid,text,text,text,date,text)','execute')
     or has_function_privilege('anon',
    'public.gas_record_container_inspection(uuid,text,text)','execute')
     or has_function_privilege('anon',
    'public.gas_retire_container(uuid,text)','execute') then
    raise exception 'Anonymous gas RPC access enabled';
  end if;
end $$;
rollback;
select 'Phase 21A gas serial registry, inspection, retirement, audit and RLS passed' as result;
