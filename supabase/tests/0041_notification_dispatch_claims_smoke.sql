\set ON_ERROR_STOP on

begin;

-- A disposable, fictional recipient. All changes roll back after the smoke test.
do $$
declare
  v_user uuid := 'e1000000-0000-4000-8000-000000000001';
  v_notification uuid := 'e2000000-0000-4000-8000-000000000001';
  v_delivery uuid := 'e3000000-0000-4000-8000-000000000001';
  v_claim record;
  v_first_token uuid;
  v_count integer;
begin
  if has_function_privilege('anon','public.notification_claim_push_deliveries(integer)','EXECUTE')
    or has_function_privilege('authenticated','public.notification_claim_push_deliveries(integer)','EXECUTE') then
    raise exception 'Push work-claim RPC must not be callable by users or anon';
  end if;
  if not has_function_privilege('service_role','public.notification_claim_push_deliveries(integer)','EXECUTE') then
    raise exception 'Service role must be able to claim push work';
  end if;
  if (select prosecdef from pg_proc where oid='public.notification_claim_push_deliveries(integer)'::regprocedure) then
    raise exception 'Push claim RPC must be SECURITY INVOKER';
  end if;

  insert into auth.users(
    id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
    raw_app_meta_data,raw_user_meta_data,created_at,updated_at
  ) values (
    v_user,'00000000-0000-0000-0000-000000000000',
    'authenticated','authenticated','push-qa@factoryos.test',
    crypt('DummyPassword123!',gen_salt('bf')),now(),
    '{"provider":"email","providers":["email"]}','{}',now(),now()
  );

  insert into public.notifications(
    id,organization_id,recipient_user_id,source_event_key,
    category,title,body,created_at
  ) values (
    v_notification,'10000000-0000-4000-8000-000000000001',
    v_user,'qa.push.claim','system','Push claim test','Fictional notification only',
    '2020-01-01 00:00:00+00'
  );

  insert into public.notification_deliveries(
    id,notification_id,channel,status,created_at
  ) values (
    v_delivery,v_notification,'push','queued','2020-01-01 00:00:00+00'
  );

  select * into v_claim from public.notification_claim_push_deliveries(1);
  if v_claim.id is distinct from v_delivery or v_claim.attempts <> 1 or v_claim.claim_token is null then
    raise exception 'Initial claim must atomically lease the queued delivery';
  end if;
  v_first_token := v_claim.claim_token;
  if not exists (
    select 1 from public.notification_deliveries d
    where d.id=v_delivery and d.status='processing'
      and d.attempts=1 and d.claim_token=v_first_token and d.claimed_at is not null
  ) then
    raise exception 'Claim state, attempt and fencing token not persisted';
  end if;

  select count(*) into v_count from public.notification_claim_push_deliveries(1);
  if v_count <> 0 then
    raise exception 'An active claim must never be claimed a second time';
  end if;

  -- Simulate a worker crash, then verify lease recovery and new fencing token.
  update public.notification_deliveries
    set claimed_at=now()-interval '16 minutes'
    where id=v_delivery;
  select * into v_claim from public.notification_claim_push_deliveries(1);
  if v_claim.id is distinct from v_delivery
     or v_claim.attempts <> 2 or v_claim.claim_token=v_first_token then
    raise exception 'Stale claim must be recovered with a fresh fencing token';
  end if;

  update public.notification_deliveries
    set status='sent'
    where id=v_delivery and claim_token=v_first_token and status='processing';
  if found then
    raise exception 'An old worker must never finalize a reclaimed job';
  end if;

  update public.notification_deliveries
    set status='sent',claimed_at=null,claim_token=null
    where id=v_delivery and claim_token=v_claim.claim_token and status='processing';
  if not found then
    raise exception 'Current worker must be able to finalize the claimed job';
  end if;

  select count(*) into v_count from public.notification_claim_push_deliveries(1);
  if v_count <> 0 then
    raise exception 'Sent notifications must never be dispatched again';
  end if;

  update public.notification_deliveries
    set status='queued',attempts=100
    where id=v_delivery;
  select count(*) into v_count from public.notification_claim_push_deliveries(1);
  if v_count <> 0 then
    raise exception 'Exhausted attempt limit must prevent claiming';
  end if;
end $$;

rollback;

select 'Phase 15 push dispatch claim, recovery and fencing tests passed' as result;
