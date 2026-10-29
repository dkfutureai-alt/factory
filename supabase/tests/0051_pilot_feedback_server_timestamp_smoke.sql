-- Phase 32: rollback-only SQL smoke. Dedicated fictional Auth identity and
-- existing local fictional organization; never production pilot data.
begin;

insert into auth.users(
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '55110000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','pilot-clock-ci@factoryos.test',
  crypt('LocalOnlyForCI123!',gen_salt('bf')),now(),
  '{"provider":"email","providers":["email"]}','{}',now(),now()
);
insert into public.organization_members(organization_id,user_id,role)
values(
  '10000000-0000-4000-8000-000000000001',
  '55110000-0000-4000-8000-000000000001','employee'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','55110000-0000-4000-8000-000000000001',true);

-- Pilot consent must be genuinely recorded first; no forged participation.
insert into public.pilot_participants(organization_id,user_id)
values(
  '10000000-0000-4000-8000-000000000001',
  '55110000-0000-4000-8000-000000000001'
);

-- Prior implementation accepted these client-controlled dates. The new
-- BEFORE INSERT trigger must unconditionally replace them with DB now().
insert into public.pilot_feedback(
  organization_id,user_id,scenario,result,created_at,notes
) values
(
  '10000000-0000-4000-8000-000000000001',
  '55110000-0000-4000-8000-000000000001',
  'inventory','passed','2099-01-01T00:00:00Z',
  'CI synthetic future timestamp must be overwritten'
),
(
  '10000000-0000-4000-8000-000000000001',
  '55110000-0000-4000-8000-000000000001',
  'quality','failed','2000-01-01T00:00:00Z',
  'CI synthetic historical timestamp must be overwritten'
),
(
  '10000000-0000-4000-8000-000000000001',
  '55110000-0000-4000-8000-000000000001',
  'hr','blocked',default,
  'CI default timestamp must also be server-owned'
);

do $$
declare
  n integer;
begin
  select count(*) into n
  from public.pilot_feedback
  where organization_id='10000000-0000-4000-8000-000000000001'
    and user_id='55110000-0000-4000-8000-000000000001'
    and created_at between transaction_timestamp() - interval '5 seconds'
                       and transaction_timestamp() + interval '5 seconds';
  if n<>3 then
    raise exception 'Pilot timestamps must be stamped by database, not client (% of 3)',n;
  end if;
  if exists(
    select 1 from public.pilot_feedback
    where organization_id='10000000-0000-4000-8000-000000000001'
      and user_id='55110000-0000-4000-8000-000000000001'
      and (created_at > now() + interval '5 seconds'
        or created_at < now() - interval '5 seconds')
  ) then
    raise exception 'Client-supplied pilot feedback timestamp persisted';
  end if;
  if (select count(*) from public.pilot_feedback
    where organization_id='10000000-0000-4000-8000-000000000001'
      and user_id='55110000-0000-4000-8000-000000000001'
      and result in ('passed','failed','blocked'))<>3 then
    raise exception 'Timestamp guard damaged pilot result values';
  end if;
end $$;

reset role;

do $$
begin
  if not exists(
    select 1 from pg_trigger t
    where t.tgname='pilot_feedback_stamp_created_at'
      and t.tgrelid='public.pilot_feedback'::regclass
      and not t.tgisinternal
  ) then
    raise exception 'Pilot feedback timestamp trigger is missing';
  end if;
  if has_function_privilege('anon',
      'public.stamp_pilot_feedback_created_at()','execute')
    or has_function_privilege('authenticated',
      'public.stamp_pilot_feedback_created_at()','execute') then
    raise exception 'Pilot feedback timestamp trigger helper exposed to clients';
  end if;
  if has_table_privilege('anon','public.pilot_feedback','insert')
     or has_table_privilege('authenticated','public.pilot_feedback','update')
     or has_table_privilege('authenticated','public.pilot_feedback','delete') then
    raise exception 'Pilot feedback write privileges unexpectedly broadened';
  end if;
end $$;

rollback;
select 'Phase 32 server-owned customer pilot feedback timestamp and RLS privilege smoke passed' as result;
