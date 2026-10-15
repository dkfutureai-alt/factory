begin;

create table public.user_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email text not null check (position('@' in email) > 1),
  full_name text,
  phone text,
  role public.app_role not null,
  auth_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','sent','accepted','revoked','expired','failed')),
  invited_by uuid not null references auth.users(id) on delete restrict,
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  delivery_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id)
);

create unique index user_invitations_active_email_idx
  on public.user_invitations (organization_id, lower(email))
  where status in ('pending','sent');
create index user_invitations_email_idx on public.user_invitations(lower(email), status);

create table public.user_invitation_factories (
  invitation_id uuid not null,
  organization_id uuid not null,
  factory_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (invitation_id, factory_id),
  foreign key (invitation_id, organization_id)
    references public.user_invitations(id, organization_id) on delete cascade,
  foreign key (factory_id, organization_id)
    references public.factories(id, organization_id) on delete cascade
);

create trigger user_invitations_set_updated_at
before update on public.user_invitations
for each row execute function public.set_updated_at();

alter table public.user_invitations enable row level security;
alter table public.user_invitation_factories enable row level security;

grant select, insert, update, delete on public.user_invitations to authenticated;
grant select, insert, update, delete on public.user_invitation_factories to authenticated;

create or replace function public.current_user_email()
returns text
language sql
stable
set search_path = public
as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

grant execute on function public.current_user_email() to authenticated;

create policy user_invitations_select on public.user_invitations
for select to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or lower(email) = public.current_user_email()
);

create policy user_invitations_manage on public.user_invitations
for all to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
)
with check (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
);

create policy user_invitation_factories_select on public.user_invitation_factories
for select to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
  or exists (
    select 1 from public.user_invitations ui
    where ui.id = user_invitation_factories.invitation_id
      and lower(ui.email) = public.current_user_email()
  )
);

create policy user_invitation_factories_manage on public.user_invitation_factories
for all to authenticated
using (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
)
with check (
  public.is_platform_owner()
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
);

create or replace function public.can_manage_factory(target_factory_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
    or exists (
      select 1
      from public.factories f
      join public.organization_members om
        on om.organization_id = f.organization_id
       and om.user_id = auth.uid()
       and om.is_active
      where f.id = target_factory_id
        and f.is_active
        and om.role = 'org_admin'
    )
    or exists (
      select 1
      from public.factory_members mine
      join public.organization_members om
        on om.organization_id = mine.organization_id
       and om.user_id = mine.user_id
       and om.is_active
      where mine.factory_id = target_factory_id
        and mine.user_id = auth.uid()
        and mine.is_active
        and om.role = 'factory_manager'
    );
$$;

grant execute on function public.can_manage_factory(uuid) to authenticated;

drop policy if exists factory_members_manage on public.factory_members;
create policy factory_members_manage on public.factory_members
for all to authenticated
using (public.can_manage_factory(factory_id))
with check (public.can_manage_factory(factory_id));

create or replace function public.prevent_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role = 'platform_owner' and not public.is_platform_owner() then
    raise exception 'Only a platform owner can assign the platform_owner role';
  end if;
  if tg_op = 'UPDATE'
     and old.user_id = auth.uid()
     and old.role = 'org_admin'
     and new.role <> 'org_admin'
     and not public.is_platform_owner() then
    raise exception 'Organization admins cannot remove their own admin role';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_role_escalation() from public;

create trigger organization_members_prevent_role_escalation
before insert or update of role on public.organization_members
for each row execute function public.prevent_role_escalation();

create or replace function public.pending_invitation_for_current_user()
returns table (
  invitation_id uuid,
  organization_id uuid,
  organization_name text,
  invited_role text,
  full_name text,
  phone text,
  expires_at timestamptz,
  factory_ids uuid[],
  factory_names text[]
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.current_user_email() = '' then
    return;
  end if;

  return query
  select
    ui.id,
    ui.organization_id,
    o.name,
    ui.role::text,
    ui.full_name,
    ui.phone,
    ui.expires_at,
    coalesce(array_agg(uif.factory_id) filter (where uif.factory_id is not null), '{}'::uuid[]),
    coalesce(array_agg(f.name order by f.name) filter (where f.id is not null), '{}'::text[])
  from public.user_invitations ui
  join public.organizations o on o.id = ui.organization_id
  left join public.user_invitation_factories uif on uif.invitation_id = ui.id
  left join public.factories f on f.id = uif.factory_id
  where lower(ui.email) = public.current_user_email()
    and ui.status in ('pending','sent')
    and ui.expires_at > now()
    and (ui.auth_user_id is null or ui.auth_user_id = auth.uid())
  group by ui.id, o.name
  order by ui.created_at desc
  limit 1;
end;
$$;

grant execute on function public.pending_invitation_for_current_user() to authenticated;

create or replace function public.complete_invitation(
  p_invitation_id uuid,
  p_full_name text,
  p_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  invite public.user_invitations%rowtype;
  assigned_factories uuid[];
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if char_length(trim(coalesce(p_full_name, ''))) < 2 then
    raise exception 'Full name is required';
  end if;

  select * into invite
  from public.user_invitations
  where id = p_invitation_id
  for update;

  if not found then
    raise exception 'Invitation not found';
  end if;
  if invite.status not in ('pending','sent') then
    raise exception 'Invitation is no longer active';
  end if;
  if invite.expires_at <= now() then
    update public.user_invitations set status = 'expired' where id = invite.id;
    raise exception 'Invitation has expired';
  end if;
  if lower(invite.email) <> public.current_user_email() then
    raise exception 'Invitation email does not match the signed-in account';
  end if;
  if invite.auth_user_id is not null and invite.auth_user_id <> auth.uid() then
    raise exception 'Invitation belongs to a different account';
  end if;
  if invite.role = 'platform_owner' and not public.is_platform_owner() then
    raise exception 'Platform-owner invitations require platform-owner approval';
  end if;

  select coalesce(array_agg(factory_id), '{}'::uuid[])
    into assigned_factories
  from public.user_invitation_factories
  where invitation_id = invite.id;

  if invite.role in ('factory_manager','supervisor','employee','driver')
     and cardinality(assigned_factories) = 0 then
    raise exception 'This role requires at least one factory assignment';
  end if;

  insert into public.profiles (id, full_name, phone)
  values (auth.uid(), trim(p_full_name), nullif(trim(coalesce(p_phone, '')), ''))
  on conflict (id) do update set
    full_name = excluded.full_name,
    phone = excluded.phone,
    is_active = true;

  insert into public.organization_members (organization_id, user_id, role, is_active)
  values (invite.organization_id, auth.uid(), invite.role, true)
  on conflict (organization_id, user_id) do update set
    role = excluded.role,
    is_active = true;

  delete from public.factory_members
  where organization_id = invite.organization_id
    and user_id = auth.uid();

  insert into public.factory_members (organization_id, factory_id, user_id, is_active)
  select invite.organization_id, uif.factory_id, auth.uid(), true
  from public.user_invitation_factories uif
  join public.factories f
    on f.id = uif.factory_id
   and f.organization_id = invite.organization_id
   and f.is_active
  where uif.invitation_id = invite.id
  on conflict (factory_id, user_id) do update set is_active = true;

  update public.user_invitations
  set status = 'accepted',
      accepted_at = now(),
      auth_user_id = auth.uid(),
      full_name = trim(p_full_name),
      phone = nullif(trim(coalesce(p_phone, '')), '')
  where id = invite.id;

  return jsonb_build_object(
    'organization_id', invite.organization_id,
    'role', invite.role::text,
    'factory_ids', assigned_factories
  );
end;
$$;

grant execute on function public.complete_invitation(uuid, text, text) to authenticated;

create or replace function public.list_organization_members(p_organization_id uuid)
returns table (
  user_id uuid,
  email text,
  full_name text,
  phone text,
  role text,
  is_active boolean,
  factory_ids uuid[]
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if not (
    public.is_platform_owner()
    or public.has_org_role(p_organization_id, array['org_admin']::public.app_role[])
  ) then
    raise exception 'Not authorized to view organization access';
  end if;

  return query
  select
    om.user_id,
    coalesce(u.email, '')::text,
    coalesce(p.full_name, '')::text,
    coalesce(p.phone, '')::text,
    om.role::text,
    om.is_active,
    coalesce(array_agg(fm.factory_id) filter (where fm.is_active), '{}'::uuid[])
  from public.organization_members om
  join auth.users u on u.id = om.user_id
  left join public.profiles p on p.id = om.user_id
  left join public.factory_members fm
    on fm.organization_id = om.organization_id
   and fm.user_id = om.user_id
  where om.organization_id = p_organization_id
  group by om.user_id, u.email, p.full_name, p.phone, om.role, om.is_active
  order by coalesce(p.full_name, u.email);
end;
$$;

grant execute on function public.list_organization_members(uuid) to authenticated;

create or replace function public.update_member_access(
  p_organization_id uuid,
  p_user_id uuid,
  p_role public.app_role,
  p_factory_ids uuid[] default '{}'::uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_count integer;
  valid_count integer;
begin
  if not (
    public.is_platform_owner()
    or public.has_org_role(p_organization_id, array['org_admin']::public.app_role[])
  ) then
    raise exception 'Not authorized to manage organization access';
  end if;
  if p_role = 'platform_owner' and not public.is_platform_owner() then
    raise exception 'Only a platform owner can assign the platform_owner role';
  end if;
  if p_user_id = auth.uid()
     and p_role <> 'org_admin'
     and public.has_org_role(p_organization_id, array['org_admin']::public.app_role[])
     and not public.is_platform_owner() then
    raise exception 'Organization admins cannot remove their own admin role';
  end if;
  if not exists (
    select 1 from public.organization_members
    where organization_id = p_organization_id and user_id = p_user_id
  ) then
    raise exception 'Organization member not found';
  end if;

  requested_count := cardinality(coalesce(p_factory_ids, '{}'::uuid[]));
  select count(*) into valid_count
  from public.factories
  where organization_id = p_organization_id
    and id = any(coalesce(p_factory_ids, '{}'::uuid[]))
    and is_active;

  if requested_count <> valid_count then
    raise exception 'One or more factory assignments are invalid';
  end if;
  if p_role in ('factory_manager','supervisor','employee','driver') and requested_count = 0 then
    raise exception 'This role requires at least one factory assignment';
  end if;

  update public.organization_members
  set role = p_role, is_active = true
  where organization_id = p_organization_id and user_id = p_user_id;

  delete from public.factory_members
  where organization_id = p_organization_id and user_id = p_user_id;

  insert into public.factory_members (organization_id, factory_id, user_id, is_active)
  select p_organization_id, unnest(coalesce(p_factory_ids, '{}'::uuid[])), p_user_id, true
  on conflict (factory_id, user_id) do update set is_active = true;
end;
$$;

grant execute on function public.update_member_access(uuid, uuid, public.app_role, uuid[]) to authenticated;

create or replace function public.deactivate_organization_member(
  p_organization_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (
    public.is_platform_owner()
    or public.has_org_role(p_organization_id, array['org_admin']::public.app_role[])
  ) then
    raise exception 'Not authorized to manage organization access';
  end if;
  if p_user_id = auth.uid() and not public.is_platform_owner() then
    raise exception 'You cannot deactivate your own organization access';
  end if;

  update public.organization_members
  set is_active = false
  where organization_id = p_organization_id and user_id = p_user_id;

  update public.factory_members
  set is_active = false
  where organization_id = p_organization_id and user_id = p_user_id;
end;
$$;

grant execute on function public.deactivate_organization_member(uuid, uuid) to authenticated;

create or replace function public.audit_access_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_org uuid;
  target_factory uuid;
  target_id text;
  payload jsonb;
begin
  if tg_table_name = 'user_invitations' then
    target_org := coalesce(new.organization_id, old.organization_id);
    target_factory := null;
    target_id := coalesce(new.id, old.id)::text;
    payload := jsonb_build_object(
      'role', coalesce(new.role, old.role)::text,
      'status_before', case when tg_op <> 'INSERT' then old.status else null end,
      'status_after', case when tg_op <> 'DELETE' then new.status else null end
    );
  elsif tg_table_name = 'organization_members' then
    target_org := coalesce(new.organization_id, old.organization_id);
    target_factory := null;
    target_id := coalesce(new.user_id, old.user_id)::text;
    payload := jsonb_build_object(
      'role_before', case when tg_op <> 'INSERT' then old.role::text else null end,
      'role_after', case when tg_op <> 'DELETE' then new.role::text else null end,
      'active_after', case when tg_op <> 'DELETE' then new.is_active else null end
    );
  elsif tg_table_name = 'factory_members' then
    target_org := coalesce(new.organization_id, old.organization_id);
    target_factory := coalesce(new.factory_id, old.factory_id);
    target_id := coalesce(new.user_id, old.user_id)::text;
    payload := jsonb_build_object(
      'factory_id', target_factory,
      'active_after', case when tg_op <> 'DELETE' then new.is_active else null end
    );
  else
    return coalesce(new, old);
  end if;

  insert into public.audit_logs (
    organization_id, factory_id, actor_user_id, action, entity_type, entity_id, metadata
  ) values (
    target_org, target_factory, auth.uid(), lower(tg_op), tg_table_name, target_id, payload
  );

  return coalesce(new, old);
end;
$$;

revoke all on function public.audit_access_change() from public;

create trigger user_invitations_audit_change
after insert or update or delete on public.user_invitations
for each row execute function public.audit_access_change();

create trigger organization_members_audit_change
after insert or update or delete on public.organization_members
for each row execute function public.audit_access_change();

create trigger factory_members_audit_change
after insert or update or delete on public.factory_members
for each row execute function public.audit_access_change();

commit;
