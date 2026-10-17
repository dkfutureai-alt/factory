begin;

do $$
declare v_count integer;
begin
  select count(*) into v_count
  from pg_indexes
  where schemaname='public'
    and tablename='maintenance_work_orders'
    and indexname='maintenance_one_active_work_order_per_plan';
  if v_count<>1 then
    raise exception 'maintenance active-plan work-order uniqueness index missing';
  end if;
end $$;

do $$
begin
  begin
    insert into public.maintenance_work_orders(
      organization_id,factory_id,asset_id,plan_id,maintenance_type,priority,status,
      problem_description
    ) values(
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',
      'a1300000-0000-4000-8000-000000000001',
      'a1400000-0000-4000-8000-000000000001',
      'preventive','high','open','Duplicate preventive work-order guard test'
    );
    raise exception 'duplicate active work order for preventive plan was accepted';
  exception
    when unique_violation then null;
  end;
end $$;

rollback;
