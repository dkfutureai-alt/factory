-- Verify expiration within one organization only; unexpired rows and other tenants remain.
begin;
insert into public.organizations(id,name,code) values
('43100000-0000-4000-8000-000000000001','Reissue Org A','REISSUE-A'),
('43100000-0000-4000-8000-000000000002','Reissue Org B','REISSUE-B');
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('43300000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','inviter@factoryos.test',crypt('Password123!',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now());
insert into public.user_invitations(id,organization_id,email,role,invited_by,expires_at,status) values
('43400000-0000-4000-8000-000000000001','43100000-0000-4000-8000-000000000001','Worker@Example.com','viewer','43300000-0000-4000-8000-000000000001',now()-interval '1 minute','sent'),
('43400000-0000-4000-8000-000000000002','43100000-0000-4000-8000-000000000002','Worker@Example.com','viewer','43300000-0000-4000-8000-000000000001',now()-interval '1 minute','sent'),
('43400000-0000-4000-8000-000000000003','43100000-0000-4000-8000-000000000001','other@example.com','viewer','43300000-0000-4000-8000-000000000001',now()+interval '1 day','sent');
set local role service_role;
DO $$ declare n integer; begin
  select public.expire_stale_user_invitations('43100000-0000-4000-8000-000000000001','worker@EXAMPLE.COM') into n;
  if n<>1 then raise exception 'Expected one expired invitation, got %',n; end if;
  if not exists(select 1 from public.user_invitations where id='43400000-0000-4000-8000-000000000001' and status='expired') then raise exception 'Expired invitation not released'; end if;
  if not exists(select 1 from public.user_invitations where id='43400000-0000-4000-8000-000000000002' and status='sent') then raise exception 'Other organization was changed'; end if;
  if not exists(select 1 from public.user_invitations where id='43400000-0000-4000-8000-000000000003' and status='sent') then raise exception 'Unexpired invitation was changed'; end if;
end $$;
insert into public.user_invitations(organization_id,email,role,invited_by,status)
values('43100000-0000-4000-8000-000000000001','worker@example.com','viewer','43300000-0000-4000-8000-000000000001','pending');
reset role;
DO $$ begin
  if has_function_privilege('authenticated','public.expire_stale_user_invitations(uuid,text)','execute') then raise exception 'Authenticated may not expire invitations'; end if;
  if has_function_privilege('anon','public.expire_stale_user_invitations(uuid,text)','execute') then raise exception 'Anon may not expire invitations'; end if;
end $$;
rollback;
select 'invitation expiry and reissue smoke passed' as result;
