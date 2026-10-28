-- Phase 20: an isolated transaction proves actual vehicle-to-warehouse ledger
-- movements, condition segregation, retry safety, RLS and role denial.
begin;

insert into auth.users(
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '54600000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','return-intake@factoryos.test',
  crypt('TestOnlyPass123!',gen_salt('bf')),now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into public.organization_members(organization_id,user_id,role)
values(
  '10000000-0000-4000-8000-000000000001',
  '54600000-0000-4000-8000-000000000001',
  'org_admin'
);

-- Use the synthetic Phase 10 delivery in a rollback-only fixture.
update public.dispatch_deliveries
set status='delivered',loaded_at=now(),started_at=now(),arrived_at=now(),
    delivered_at=now(),receiver_name='Test Receiver'
where id='98400000-0000-4000-8000-000000000015';
insert into public.stock_locations(
  id,organization_id,factory_id,name,code,location_type
) values
  ('54600000-0000-4000-8000-000000000002',
   '10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   'Return Intake Receiving','RET20-RCV','receiving'),
  ('54600000-0000-4000-8000-000000000003',
   '10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   'Return Intake Quarantine','RET20-QRT','quarantine');

insert into public.dispatch_returnable_pickups(
  id,organization_id,factory_id,delivery_id,status,completed_at
) values (
  '54600000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '98400000-0000-4000-8000-000000000015','completed',now()
);

-- The driver has already received 3 empty cylinders onto the truck;
-- one damaged return must not enter the good receiving area.
insert into public.inventory_transactions(
  id,organization_id,factory_id,item_id,transaction_type,quantity,to_location_id
) values
  ('54600000-0000-4000-8000-000000000005',
   '10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '43000000-0000-4000-8000-000000000003',
   'receive',2,'98400000-0000-4000-8000-000000000010'),
  ('54600000-0000-4000-8000-000000000006',
   '10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001',
   '43000000-0000-4000-8000-000000000003',
   'receive',1,'98400000-0000-4000-8000-000000000010');

insert into public.stock_ledger_entries(
  organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta
) values
 ('10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '54600000-0000-4000-8000-000000000005',
  '43000000-0000-4000-8000-000000000003',
  '98400000-0000-4000-8000-000000000010',2),
 ('10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '54600000-0000-4000-8000-000000000006',
  '43000000-0000-4000-8000-000000000003',
  '98400000-0000-4000-8000-000000000010',1);

insert into public.dispatch_returnable_lines(
  id,organization_id,pickup_id,item_id,quantity,condition,vehicle_receive_transaction_id
) values
 ('54600000-0000-4000-8000-000000000007',
  '10000000-0000-4000-8000-000000000001',
  '54600000-0000-4000-8000-000000000004',
  '43000000-0000-4000-8000-000000000003',
  2,'good','54600000-0000-4000-8000-000000000005'),
 ('54600000-0000-4000-8000-000000000008',
  '10000000-0000-4000-8000-000000000001',
  '54600000-0000-4000-8000-000000000004',
  '43000000-0000-4000-8000-000000000003',
  1,'damaged','54600000-0000-4000-8000-000000000006');

-- Sales must not allocate uninspected empty or damaged returned cylinders.
insert into public.sales_orders(
  id,organization_id,factory_id,customer_id,status
) values (
  '54600000-0000-4000-8000-000000000009',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000003',
  'confirmed'
);
insert into public.sales_order_lines(
  id,organization_id,sales_order_id,item_id,ordered_quantity,unit_price
) values (
  '54600000-0000-4000-8000-00000000000a',
  '10000000-0000-4000-8000-000000000001',
  '54600000-0000-4000-8000-000000000009',
  '43000000-0000-4000-8000-000000000003',
  1,100
);

-- The RPC must operate with an actual authenticated role, not postgres bypass.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub','54600000-0000-4000-8000-000000000001',true
);
do $$
declare v_intake uuid; v_again uuid; v_bad boolean := false; v_transfers int;
begin
  v_intake := public.dispatch_intake_returnables(
    '54600000-0000-4000-8000-000000000004',
    '54600000-0000-4000-8000-000000000002',
    '54600000-0000-4000-8000-000000000003',
    'Returned to plant'
  );
  if v_intake is null or (
    select count(*) from public.dispatch_returnable_intake_lines
    where intake_id=v_intake
  ) <> 2 then
    raise exception 'Missing atomic intake lines';
  end if;
  if (
    select coalesce(sum(quantity),0)
    from public.dispatch_returnable_intake_lines
    where intake_id=v_intake
      and condition='good'
      and destination_location_id='54600000-0000-4000-8000-000000000002'
  ) <> 2 or (
    select coalesce(sum(quantity),0)
    from public.dispatch_returnable_intake_lines
    where intake_id=v_intake
      and condition='damaged'
      and destination_location_id='54600000-0000-4000-8000-000000000003'
  ) <> 1 then
    raise exception 'Damaged/empty cylinder intake condition was not segregated';
  end if;
  if (
    select coalesce(sum(quantity_delta),0)
    from public.stock_ledger_entries
    where item_id='43000000-0000-4000-8000-000000000003'
      and location_id='98400000-0000-4000-8000-000000000010'
      and transaction_id in (
        select transfer_transaction_id
        from public.dispatch_returnable_intake_lines
        where intake_id=v_intake
      )
  ) <> -3 then
    raise exception 'Truck ledger was not debited exactly three units';
  end if;
  select count(*) into v_transfers
    from public.dispatch_returnable_intake_lines where intake_id=v_intake;
  v_again := public.dispatch_intake_returnables(
    '54600000-0000-4000-8000-000000000004',
    '54600000-0000-4000-8000-000000000002',
    '54600000-0000-4000-8000-000000000003',
    'Retry request'
  );
  if v_again <> v_intake or
     (select count(*) from public.dispatch_returnable_intake_lines
      where intake_id=v_intake) <> v_transfers then
    raise exception 'Retried intake created duplicate ledger movements';
  end if;
  if (
    select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries
    where item_id='43000000-0000-4000-8000-000000000003'
      and location_id='54600000-0000-4000-8000-000000000002'
      and transaction_id in (
        select transfer_transaction_id from public.dispatch_returnable_intake_lines
        where intake_id=v_intake
      )
  ) <> 2 or (
    select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries
    where item_id='43000000-0000-4000-8000-000000000003'
      and location_id='54600000-0000-4000-8000-000000000003'
      and transaction_id in (
        select transfer_transaction_id from public.dispatch_returnable_intake_lines
        where intake_id=v_intake
      )
  ) <> 1 then
    raise exception 'Receiving/quarantine ledger credits do not balance vehicle debit';
  end if;

  -- Even a commercial manager cannot allocate physical returns until a
  -- separate inspection releases them into a warehouse/bin/dispatch area.
  v_bad := false;
  begin
    perform public.commercial_allocate_sales_order(
      '54600000-0000-4000-8000-000000000009',
      '54600000-0000-4000-8000-000000000002'
    );
  exception when others then v_bad := true;
  end;
  if not v_bad then raise exception 'Uninspected empty cylinders were sellable'; end if;
  v_bad := false;
  begin
    perform public.commercial_allocate_sales_order(
      '54600000-0000-4000-8000-000000000009',
      '54600000-0000-4000-8000-000000000003'
    );
  exception when others then v_bad := true;
  end;
  if not v_bad then raise exception 'Quarantined cylinders were sellable'; end if;
  if exists(
    select 1 from public.sales_allocations
    where sales_order_id='54600000-0000-4000-8000-000000000009'
  ) then
    raise exception 'Unsafe commercial allocations were created';
  end if;


  begin
    perform public.dispatch_intake_returnables(
      '54600000-0000-4000-8000-000000000004',
      '54600000-0000-4000-8000-000000000003',
      '54600000-0000-4000-8000-000000000002'
    );
  exception when others then v_bad := true;
  end;
  if not v_bad then raise exception 'Mismatched retry was accepted'; end if;
end $$;

-- An authenticated user with no FactoryOS membership cannot read or intake
-- someone else's cylinder returns even if the UUID is known.
select set_config('request.jwt.claim.sub','54600000-0000-4000-8000-000000000099',true);
do $$
declare v_blocked boolean := false;
begin
  if (select count(*) from public.dispatch_returnable_intakes) <> 0
     or (select count(*) from public.dispatch_returnable_intake_lines) <> 0 then
    raise exception 'Cross-tenant returnable intake data leak';
  end if;
  begin
    perform public.dispatch_intake_returnables(
      '54600000-0000-4000-8000-000000000004',
      '54600000-0000-4000-8000-000000000002',
      '54600000-0000-4000-8000-000000000003'
    );
  exception when others then v_blocked := true;
  end;
  if not v_blocked then raise exception 'Cross-tenant return intake access was granted'; end if;
end $$;

reset role;
do $$
begin
  if has_table_privilege('anon','public.dispatch_returnable_intakes','select')
    or has_table_privilege('anon','public.dispatch_returnable_intake_lines','select')
    or has_table_privilege('authenticated','public.dispatch_returnable_intakes','insert')
    or has_table_privilege('authenticated','public.dispatch_returnable_intake_lines','insert')
    or not has_table_privilege('service_role','public.dispatch_returnable_intakes','insert')
  then raise exception 'Returnable intake table privileges are unsafe'; end if;
end $$;
rollback;
select 'returnable warehouse intake, condition segregation and tenant security passed' as result;
