-- Authentication, onboarding, role assignment and factory-access smoke tests.
-- Runs after migrations and seed in the disposable local Supabase database.

begin;

insert into public.organizations (id, name, code)
values ('31000000-0000-4000-8000-000000000001', 'Access Test Industries', 'ACCESS-TEST');

insert into public.factories (id, organization_id, name, code, city, state)
values
  ('32000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000001', 'Plant Alpha', 'ALPHA', 'Pune', 'Maharashtra'),
  ('32000000-0000-4000-8000-000000000002', '31000000-0000-4000-8000-000000000001', 'Plant Beta', 'BETA', 'Nashik', 'Maharashtra');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('33000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@factoryos.test', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'worker@factoryos.test', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'manager@factoryos.test', crypt('Password123!', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organization_members (organization_id, user_id, role)
values
  ('31000000-0000-4000-8000-000000000001', '33000000-0000-4000-8000-000000000001', 'org_admin'),
  ('31000000-0000-4000-8000-000000000001', '33000000-0000-4000-8000-000000000003', 'factory_manager');

insert into public.factory_members (organization_id, factory_id, user_id)
values ('31000000-0000-4000-8000-000000000001', '32000000-0000-4000-8000-000000000001', '33000000-0000-4000-8000-000000000003');

insert into public.user_invitations (
  id, organization_id, email, full_name, role, auth_user_id, status, invited_by
) values (
  '34000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  'worker@factoryos.test',
  'Test Worker',
  'employee',
  '33000000-0000-4000-8000-000000000002',
  'sent',
  '33000000-0000-4000-8000-000000000001'
);

insert into public.user_invitation_factories (invitation_id, organization_id, factory_id)
values (
  '34000000-0000-4000-8000-000000000001',
  '31000000-0000-4000-8000-000000000001',
  '32000000-0000-4000-8000-000000000002'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"33000000-0000-4000-8000-000000000002","email":"worker@factoryos.test","role":"authenticated"}',
  true
);

DO $$
declare
  pending_count integer;
begin
  select count(*) into pending_count from public.pending_invitation_for_current_user();
  if pending_count <> 1 then
    raise exception 'Expected one pending invitation for invited worker, got %', pending_count;
  end if;
end $$;

select public.complete_invitation(
  '34000000-0000-4000-8000-000000000001',
  'Test Worker',
  '+91 9000000000'
);

DO $$
begin
  if not exists (
    select 1 from public.organization_members
    where organization_id = '31000000-0000-4000-8000-000000000001'
      and user_id = '33000000-0000-4000-8000-000000000002'
      and role = 'employee'
      and is_active
  ) then
    raise exception 'Invitation acceptance did not create employee membership';
  end if;
  if not exists (
    select 1 from public.factory_members
    where factory_id = '32000000-0000-4000-8000-000000000002'
      and user_id = '33000000-0000-4000-8000-000000000002'
      and is_active
  ) then
    raise exception 'Invitation acceptance did not assign factory';
  end if;
  if not exists (
    select 1 from public.user_invitations
    where id = '34000000-0000-4000-8000-000000000001' and status = 'accepted'
  ) then
    raise exception 'Invitation was not marked accepted';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  '{"sub":"33000000-0000-4000-8000-000000000001","email":"admin@factoryos.test","role":"authenticated"}',
  true
);

select public.update_member_access(
  '31000000-0000-4000-8000-000000000001',
  '33000000-0000-4000-8000-000000000002',
  'supervisor',
  array['32000000-0000-4000-8000-000000000001'::uuid]
);

DO $$
begin
  if not exists (
    select 1 from public.organization_members
    where organization_id = '31000000-0000-4000-8000-000000000001'
      and user_id = '33000000-0000-4000-8000-000000000002'
      and role = 'supervisor'
  ) then
    raise exception 'Role update failed';
  end if;
  if not exists (
    select 1 from public.factory_members
    where factory_id = '32000000-0000-4000-8000-000000000001'
      and user_id = '33000000-0000-4000-8000-000000000002'
      and is_active
  ) then
    raise exception 'Factory reassignment failed';
  end if;
end $$;

DO $$
begin
  begin
    insert into public.organization_members (organization_id, user_id, role)
    values (
      '31000000-0000-4000-8000-000000000001',
      gen_random_uuid(),
      'platform_owner'
    );
    raise exception 'Expected platform-owner escalation to be blocked';
  exception when others then
    if position('Only a platform owner' in sqlerrm) = 0
       and position('violates foreign key' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end $$;

select set_config(
  'request.jwt.claims',
  '{"sub":"33000000-0000-4000-8000-000000000003","email":"manager@factoryos.test","role":"authenticated"}',
  true
);

DO $$
begin
  if not public.can_manage_factory('32000000-0000-4000-8000-000000000001') then
    raise exception 'Assigned factory manager should manage Plant Alpha membership';
  end if;
  if public.can_manage_factory('32000000-0000-4000-8000-000000000002') then
    raise exception 'Factory manager must not manage an unassigned factory';
  end if;

  begin
    perform public.update_member_access(
      '31000000-0000-4000-8000-000000000001',
      '33000000-0000-4000-8000-000000000002',
      'employee',
      array['32000000-0000-4000-8000-000000000001'::uuid]
    );
    raise exception 'Expected factory manager role-management denial';
  exception when others then
    if position('Not authorized' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end $$;

reset role;
rollback;

select 'user access auth smoke checks passed' as result;
