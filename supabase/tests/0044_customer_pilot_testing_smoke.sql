-- Phase 17: real member consent and strict cross-tenant feedback isolation.
begin;

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('55100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','pilot-a@factoryos.test',crypt('Password123!',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('55100000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','pilot-b@factoryos.test',crypt('Password123!',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now());

insert into public.organizations(id,name,code) values
('55200000-0000-4000-8000-000000000001','Pilot Tenant A','PILOT-TENANT-A'),
('55200000-0000-4000-8000-000000000002','Pilot Tenant B','PILOT-TENANT-B');
insert into public.organization_members(organization_id,user_id,role) values
('55200000-0000-4000-8000-000000000001','55100000-0000-4000-8000-000000000001','employee'),
('55200000-0000-4000-8000-000000000002','55100000-0000-4000-8000-000000000002','employee');

set local role authenticated;
select set_config('request.jwt.claim.sub','55100000-0000-4000-8000-000000000001',true);
insert into public.pilot_participants(organization_id,user_id,consented_at)
values('55200000-0000-4000-8000-000000000001','55100000-0000-4000-8000-000000000001','2000-01-01'::timestamptz);
DO $$
begin
  if not exists (select 1 from public.pilot_participants
    where organization_id='55200000-0000-4000-8000-000000000001'
      and consented_at > '2026-01-01'::timestamptz)
  then raise exception 'Consent timestamp was not server-stamped'; end if;
end $$;

insert into public.pilot_feedback(organization_id,user_id,scenario,result,notes)
values('55200000-0000-4000-8000-000000000001','55100000-0000-4000-8000-000000000001','inventory','passed','Scan completed');
DO $$
begin
  if (select count(*) from public.pilot_feedback) <> 1 then
    raise exception 'Expected only self feedback to be visible';
  end if;
  begin
    insert into public.pilot_participants(organization_id,user_id)
    values('55200000-0000-4000-8000-000000000002','55100000-0000-4000-8000-000000000001');
    raise exception 'Cross-tenant opt-in unexpectedly succeeded';
  exception when insufficient_privilege or foreign_key_violation then null;
  end;
  begin
    insert into public.pilot_feedback(organization_id,user_id,scenario,result)
    values('55200000-0000-4000-8000-000000000002','55100000-0000-4000-8000-000000000001','inventory','passed');
    raise exception 'Cross-tenant forged feedback unexpectedly succeeded';
  exception when insufficient_privilege or foreign_key_violation then null;
  end;
end $$;

select set_config('request.jwt.claim.sub','55100000-0000-4000-8000-000000000002',true);
insert into public.pilot_participants(organization_id,user_id)
values('55200000-0000-4000-8000-000000000002','55100000-0000-4000-8000-000000000002');
insert into public.pilot_feedback(organization_id,user_id,scenario,result)
values('55200000-0000-4000-8000-000000000002','55100000-0000-4000-8000-000000000002','hr','blocked');
DO $$
begin
  if (select count(*) from public.pilot_feedback) <> 1 then
    raise exception 'Pilot feedback leaked across tenants'; end if;
  if (select count(*) from public.pilot_participants) <> 1 then
    raise exception 'Pilot participation leaked across tenants'; end if;
end $$;
-- Users can withdraw. All of their reports are then removed.
delete from public.pilot_participants
where organization_id='55200000-0000-4000-8000-000000000002'
  and user_id='55100000-0000-4000-8000-000000000002';
DO $$
begin
  if exists(select 1 from public.pilot_feedback where organization_id='55200000-0000-4000-8000-000000000002')
  then raise exception 'Withdrawal failed to delete customer feedback'; end if;
end $$;
reset role;
DO $$
begin
  if has_table_privilege('anon','public.pilot_participants','select')
    or has_table_privilege('anon','public.pilot_feedback','insert')
  then raise exception 'Anonymous pilot data access is not allowed'; end if;
end $$;
rollback;
select 'pilot participation and cross-tenant RLS passed' as result;
