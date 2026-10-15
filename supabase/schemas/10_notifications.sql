-- FactoryOS Notifications / FCM foundation
-- Repository-only. Must be reviewed and executed only in a dedicated FactoryOS Supabase project.

create type public.notification_priority as enum ('normal', 'high', 'critical');
create type public.notification_push_status as enum ('not_requested', 'queued', 'sent', 'failed', 'skipped');

create table public.notification_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  template_key text not null,
  title_template text not null check (char_length(title_template) between 1 and 120),
  body_template text not null check (char_length(body_template) between 1 and 500),
  route_template text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, template_key)
);

create table public.notification_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid references public.factories(id) on delete cascade,
  trigger_key text not null,
  template_id uuid not null references public.notification_templates(id) on delete restrict,
  audience_role_key text,
  priority public.notification_priority not null default 'normal',
  in_app_enabled boolean not null default true,
  push_enabled boolean not null default true,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (organization_id, factory_id, trigger_key, audience_role_key)
);

create table public.notification_device_tokens (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  device_label text,
  fcm_token text not null check (char_length(fcm_token) between 20 and 4096),
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id, fcm_token)
);

create table public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  category_key text not null,
  in_app_enabled boolean not null default true,
  push_enabled boolean not null default true,
  quiet_hours_enabled boolean not null default false,
  quiet_start time,
  quiet_end time,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id, category_key),
  check ((not quiet_hours_enabled) or (quiet_start is not null and quiet_end is not null))
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid references public.factories(id) on delete set null,
  trigger_key text not null,
  source_module text not null,
  source_type text,
  source_id text,
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 500),
  route text,
  priority public.notification_priority not null default 'normal',
  requires_action boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.notification_recipients (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz,
  push_status public.notification_push_status not null default 'not_requested',
  push_queued_at timestamptz,
  push_sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique (notification_id, user_id)
);

-- Service-side diagnostic table. Authenticated clients receive no policies on this table.
create table public.notification_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.notification_recipients(id) on delete cascade,
  device_token_id uuid references public.notification_device_tokens(id) on delete set null,
  attempt_number integer not null check (attempt_number > 0),
  status public.notification_push_status not null,
  provider_message_id text,
  error_code text,
  attempted_at timestamptz not null default now(),
  unique (recipient_id, device_token_id, attempt_number)
);

create index notifications_org_factory_created_idx on public.notifications (organization_id, factory_id, created_at desc);
create index notification_recipients_user_created_idx on public.notification_recipients (user_id, created_at desc);
create index notification_recipients_unread_idx on public.notification_recipients (user_id, created_at desc) where read_at is null;
create index notification_device_tokens_active_idx on public.notification_device_tokens (organization_id, user_id) where is_active;

create or replace function private.validate_notification_factory_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.factory_id is not null and not exists (
    select 1 from public.factories f
    where f.id = new.factory_id and f.organization_id = new.organization_id
  ) then
    raise exception 'Notification factory must belong to organization';
  end if;
  return new;
end;
$$;

create trigger notification_rules_factory_scope
before insert or update on public.notification_rules
for each row execute function private.validate_notification_factory_scope();

create trigger notifications_factory_scope
before insert or update on public.notifications
for each row execute function private.validate_notification_factory_scope();

create or replace function private.validate_notification_template_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1 from public.notification_templates t
    where t.id = new.template_id and t.organization_id = new.organization_id
  ) then
    raise exception 'Notification rule template must belong to organization';
  end if;
  return new;
end;
$$;

create trigger notification_rules_template_scope
before insert or update on public.notification_rules
for each row execute function private.validate_notification_template_scope();

create or replace function private.validate_notification_recipient_scope()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1 from public.notifications n
    where n.id = new.notification_id and n.organization_id = new.organization_id
  ) then
    raise exception 'Notification recipient must match notification organization';
  end if;
  if not exists (
    select 1 from public.organization_memberships m
    where m.organization_id = new.organization_id
      and m.user_id = new.user_id
      and m.status = 'active'
  ) then
    raise exception 'Notification recipient must be an active organization member';
  end if;
  return new;
end;
$$;

create trigger notification_recipients_scope
before insert or update on public.notification_recipients
for each row execute function private.validate_notification_recipient_scope();

create or replace function private.enforce_critical_notification_preference()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.category_key = 'critical' then
    new.in_app_enabled := true;
    new.push_enabled := true;
  end if;
  return new;
end;
$$;

create trigger notification_preferences_critical_guard
before insert or update on public.notification_preferences
for each row execute function private.enforce_critical_notification_preference();

create or replace function public.mark_notification_read(target_recipient_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.notification_recipients r
     set read_at = coalesce(r.read_at, now())
   where r.id = target_recipient_id
     and r.user_id = (select auth.uid());
  if not found then
    raise exception 'Notification recipient not found or not owned by current user';
  end if;
end;
$$;

revoke all on function public.mark_notification_read(uuid) from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;

alter table public.notification_templates enable row level security;
alter table public.notification_rules enable row level security;
alter table public.notification_device_tokens enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_recipients enable row level security;
alter table public.notification_delivery_attempts enable row level security;

create policy notification_templates_read_member on public.notification_templates
for select to authenticated
using ((select private.is_org_member(organization_id)));

create policy notification_templates_manage on public.notification_templates
for all to authenticated
using ((select private.has_permission(organization_id, 'notification.manage', null)))
with check ((select private.has_permission(organization_id, 'notification.manage', null)));

create policy notification_rules_read_authorized on public.notification_rules
for select to authenticated
using ((select private.has_permission(organization_id, 'notification.read', factory_id)));

create policy notification_rules_manage_authorized on public.notification_rules
for all to authenticated
using ((select private.has_permission(organization_id, 'notification.manage', factory_id)))
with check ((select private.has_permission(organization_id, 'notification.manage', factory_id)));

create policy notification_device_tokens_self_select on public.notification_device_tokens
for select to authenticated
using (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)));

create policy notification_device_tokens_self_insert on public.notification_device_tokens
for insert to authenticated
with check (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)));

create policy notification_device_tokens_self_update on public.notification_device_tokens
for update to authenticated
using (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)))
with check (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)));

create policy notification_device_tokens_self_delete on public.notification_device_tokens
for delete to authenticated
using (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)));

create policy notification_preferences_self_select on public.notification_preferences
for select to authenticated
using (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)));

create policy notification_preferences_self_manage on public.notification_preferences
for all to authenticated
using (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)))
with check (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)));

create policy notifications_select_recipient_or_manager on public.notifications
for select to authenticated
using (
  exists (
    select 1 from public.notification_recipients r
    where r.notification_id = notifications.id
      and r.user_id = (select auth.uid())
  )
  or (select private.has_permission(organization_id, 'notification.read', factory_id))
);

create policy notification_recipients_select_self on public.notification_recipients
for select to authenticated
using (user_id = (select auth.uid()) and (select private.is_org_member(organization_id)));

-- No authenticated INSERT/UPDATE/DELETE policies for notifications, recipients or delivery attempts.
-- Trusted server-side notification dispatch is responsible for creating notification records,
-- resolving authorized recipients, reading active device tokens and recording FCM delivery attempts.

grant select on public.notification_templates, public.notification_rules, public.notifications to authenticated;
grant select, insert, update, delete on public.notification_device_tokens, public.notification_preferences to authenticated;
grant select on public.notification_recipients to authenticated;
