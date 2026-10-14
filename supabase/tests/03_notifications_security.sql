\set ON_ERROR_STOP on
-- Run after schema, seeds and RBAC fixtures. Assertions use real authenticated RLS.
insert into public.notifications (organization_id, factory_id, trigger_key, source_module, title, body, priority)
select o.id, f.id, 'security.test', 'notifications', 'CI notification', 'CI only', 'critical'
from public.organizations o join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
where o.code='DKIM';

insert into public.notification_recipients (notification_id,organization_id,user_id)
select n.id,n.organization_id,'10000000-0000-0000-0000-000000000001'::uuid
from public.notifications n where n.trigger_key='security.test' and n.title='CI notification';

-- Self-owned recipient is visible; unrelated user cannot enumerate it.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
select (count(*)=1) as ok from public.notification_recipients r join public.notifications n on n.id=r.notification_id where n.trigger_key='security.test' \gset owner_
\if :owner_ok
\else
  \echo 'NOTIFICATION SECURITY: owner cannot read recipient'
  select 1/0;
\endif
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
set role authenticated;
select (count(*)=0) as ok from public.notification_recipients r join public.notifications n on n.id=r.notification_id where n.trigger_key='security.test' \gset other_
\if :other_ok
\else
  \echo 'NOTIFICATION SECURITY: recipient leaked to another user'
  select 1/0;
\endif
reset role;

-- The SECURITY DEFINER RPC must reject non-owners and suspended members.
do $$
declare rid uuid; denied boolean;
begin
 select r.id into rid from public.notification_recipients r join public.notifications n on n.id=r.notification_id where n.trigger_key='security.test';
 perform set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
 denied:=false;
 begin perform public.mark_notification_read(rid); exception when others then denied:=true; end;
 if not denied then raise exception 'NOTIFICATION SECURITY: foreign read-state mutation allowed'; end if;
 perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
 perform public.mark_notification_read(rid);
 if not exists(select 1 from public.notification_recipients where id=rid and read_at is not null) then
   raise exception 'NOTIFICATION SECURITY: valid owner read-state mutation failed';
 end if;
 update public.organization_memberships set status='suspended' where organization_id=(select id from public.organizations where code='DKIM') and user_id='10000000-0000-0000-0000-000000000001';
 denied:=false;
 begin perform public.mark_notification_read(rid); exception when others then denied:=true; end;
 if not denied then raise exception 'NOTIFICATION SECURITY: suspended member used RPC'; end if;
end $$;
