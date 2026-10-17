begin;

-- Phase 13: Notifications — tenant-safe in-app inbox plus push-delivery outbox.

insert into public.app_modules(key,name,description,sort_order,is_active)
values('notifications','Notifications','In-app alerts, delivery rules and push notification preferences',130,true)
on conflict(key) do update set name=excluded.name,description=excluded.description,sort_order=excluded.sort_order,is_active=true;

create table public.notification_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  template_key text not null check(template_key ~ '^[a-z][a-z0-9_.-]{2,79}$'),
  name text not null check(char_length(trim(name)) between 2 and 120),
  category text not null check(category in ('inventory','production','quality','purchase','sales','warehouse','fleet','dispatch','maintenance','hr','system')),
  title_template text not null check(char_length(trim(title_template)) between 2 and 180),
  body_template text not null check(char_length(trim(body_template)) between 2 and 1000),
  default_priority text not null default 'normal' check(default_priority in ('low','normal','high','critical')),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,template_key),
  unique(id,organization_id)
);

create table public.notification_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid,
  event_key text not null check(event_key ~ '^[a-z][a-z0-9_.-]{2,99}$'),
  template_id uuid not null,
  audience_roles public.app_role[] not null default '{}'::public.app_role[],
  channels text[] not null default array['in_app']::text[],
  priority_override text check(priority_override is null or priority_override in ('low','normal','high','critical')),
  include_actor boolean not null default false,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key(factory_id,organization_id) references public.factories(id,organization_id) on delete cascade,
  foreign key(template_id,organization_id) references public.notification_templates(id,organization_id) on delete cascade,
  check(channels <@ array['in_app','push']::text[] and cardinality(channels)>0),
  unique(id,organization_id)
);
create unique index notification_rules_scope_event_template_unique
  on public.notification_rules(organization_id,coalesce(factory_id,'00000000-0000-0000-0000-000000000000'::uuid),event_key,template_id);
create index notification_rules_event_idx on public.notification_rules(organization_id,event_key,is_active);

create table public.notification_preferences (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  in_app_enabled boolean not null default true,
  push_enabled boolean not null default true,
  quiet_hours_start time,
  quiet_hours_end time,
  allow_critical_during_quiet boolean not null default true,
  muted_categories text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(organization_id,user_id),
  check((quiet_hours_start is null and quiet_hours_end is null) or (quiet_hours_start is not null and quiet_hours_end is not null))
);

create table public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check(platform in ('android','ios','web')),
  device_name text,
  device_token text not null check(char_length(device_token) between 12 and 4096),
  token_fingerprint text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id,token_fingerprint)
);
create index notification_devices_user_active_idx on public.notification_devices(user_id,is_active,last_seen_at desc);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  factory_id uuid,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  source_event_key text not null,
  category text not null,
  priority text not null default 'normal' check(priority in ('low','normal','high','critical')),
  title text not null check(char_length(trim(title)) between 2 and 180),
  body text not null check(char_length(trim(body)) between 2 and 1200),
  action_route text,
  action_entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  show_in_app boolean not null default true,
  dedupe_key text,
  read_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key(factory_id,organization_id) references public.factories(id,organization_id) on delete cascade,
  unique(recipient_user_id,dedupe_key)
);
create index notifications_recipient_created_idx on public.notifications(recipient_user_id,created_at desc);
create index notifications_recipient_unread_idx on public.notifications(recipient_user_id,created_at desc) where read_at is null and archived_at is null and show_in_app;
create index notifications_admin_scope_idx on public.notifications(organization_id,factory_id,created_at desc);

create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  channel text not null check(channel in ('in_app','push')),
  status text not null check(status in ('queued','sent','failed','skipped')),
  attempts integer not null default 0 check(attempts between 0 and 100),
  provider_message_id text,
  error_message text,
  last_attempt_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(notification_id,channel)
);
create index notification_deliveries_queue_idx on public.notification_deliveries(channel,status,created_at) where status='queued';

create trigger notification_templates_set_updated_at before update on public.notification_templates for each row execute function public.set_updated_at();
create trigger notification_rules_set_updated_at before update on public.notification_rules for each row execute function public.set_updated_at();
create trigger notification_preferences_set_updated_at before update on public.notification_preferences for each row execute function public.set_updated_at();
create trigger notification_devices_set_updated_at before update on public.notification_devices for each row execute function public.set_updated_at();
create trigger notification_deliveries_set_updated_at before update on public.notification_deliveries for each row execute function public.set_updated_at();

create or replace function public.notification_can_manage_rule(p_organization_id uuid,p_factory_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select case
    when p_factory_id is null then public.has_org_role(p_organization_id,array['org_admin']::public.app_role[])
    else public.can_manage_factory(p_factory_id)
  end;
$$;
grant execute on function public.notification_can_manage_rule(uuid,uuid) to authenticated;

alter table public.notification_templates enable row level security;
alter table public.notification_rules enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_devices enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_deliveries enable row level security;

grant select on public.notification_templates,public.notification_rules,public.notification_preferences,public.notification_devices,public.notifications,public.notification_deliveries to authenticated;
grant insert,update,delete on public.notification_templates,public.notification_rules to authenticated;

create policy notification_templates_select on public.notification_templates for select to authenticated
using(public.is_org_member(organization_id));
create policy notification_templates_manage on public.notification_templates for all to authenticated
using(public.has_org_role(organization_id,array['org_admin']::public.app_role[]))
with check(public.has_org_role(organization_id,array['org_admin']::public.app_role[]));

create policy notification_rules_select on public.notification_rules for select to authenticated
using(
  public.has_org_role(organization_id,array['org_admin','factory_manager']::public.app_role[])
  or (factory_id is not null and public.can_manage_factory(factory_id))
);
create policy notification_rules_manage on public.notification_rules for all to authenticated
using(public.notification_can_manage_rule(organization_id,factory_id))
with check(public.notification_can_manage_rule(organization_id,factory_id));

create policy notification_preferences_self_select on public.notification_preferences for select to authenticated
using(user_id=auth.uid() and public.is_org_member(organization_id));
create policy notification_devices_self_select on public.notification_devices for select to authenticated
using(user_id=auth.uid() and public.is_org_member(organization_id));
create policy notifications_self_select on public.notifications for select to authenticated
using(recipient_user_id=auth.uid() and public.is_org_member(organization_id));
create policy notification_deliveries_self_select on public.notification_deliveries for select to authenticated
using(exists(select 1 from public.notifications n where n.id=notification_id and n.recipient_user_id=auth.uid()));

revoke insert,update,delete on public.notification_preferences,public.notification_devices,public.notifications,public.notification_deliveries from authenticated;

create or replace function public.notification_seed_defaults_for_org(p_organization_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare
  v_maintenance uuid; v_dispatch_exception uuid; v_leave uuid; v_delivery uuid;
begin
  if not exists(select 1 from public.organizations where id=p_organization_id) then return; end if;
  insert into public.organization_modules(organization_id,module_key,is_enabled)
  values(p_organization_id,'notifications',true)
  on conflict(organization_id,module_key) do nothing;

  insert into public.notification_templates(organization_id,template_key,name,category,title_template,body_template,default_priority)
  values
    (p_organization_id,'maintenance.work_order_assigned','Maintenance work order assigned','maintenance','Maintenance work order assigned','A maintenance work order has been assigned.','high'),
    (p_organization_id,'dispatch.exception_reported','Delivery exception reported','dispatch','Delivery exception reported','A delivery exception requires review.','high'),
    (p_organization_id,'hr.leave_decided','Leave decision','hr','Leave request updated','Your leave request status changed.','normal'),
    (p_organization_id,'dispatch.delivery_completed','Delivery completed','dispatch','Delivery completed','A customer delivery has been completed.','normal')
  on conflict(organization_id,template_key) do update set name=excluded.name,category=excluded.category,title_template=excluded.title_template,body_template=excluded.body_template,default_priority=excluded.default_priority,is_active=true;

  select id into v_maintenance from public.notification_templates where organization_id=p_organization_id and template_key='maintenance.work_order_assigned';
  select id into v_dispatch_exception from public.notification_templates where organization_id=p_organization_id and template_key='dispatch.exception_reported';
  select id into v_leave from public.notification_templates where organization_id=p_organization_id and template_key='hr.leave_decided';
  select id into v_delivery from public.notification_templates where organization_id=p_organization_id and template_key='dispatch.delivery_completed';

  insert into public.notification_rules(organization_id,event_key,template_id,audience_roles,channels,priority_override,is_active)
  values
    (p_organization_id,'maintenance.work_order_assigned',v_maintenance,array['factory_manager','supervisor']::public.app_role[],array['in_app','push'],null,true),
    (p_organization_id,'dispatch.exception_reported',v_dispatch_exception,array['factory_manager','supervisor']::public.app_role[],array['in_app','push'],'high',true),
    (p_organization_id,'hr.leave_decided',v_leave,'{}'::public.app_role[],array['in_app','push'],null,true),
    (p_organization_id,'dispatch.delivery_completed',v_delivery,array['factory_manager','supervisor']::public.app_role[],array['in_app','push'],null,true)
  on conflict do nothing;
end;
$$;
revoke all on function public.notification_seed_defaults_for_org(uuid) from public;

create or replace function public.notification_install_defaults_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform public.notification_seed_defaults_for_org(new.id);
  return new;
end;
$$;
drop trigger if exists notifications_organization_defaults_after_insert on public.organizations;
create trigger notifications_organization_defaults_after_insert after insert on public.organizations for each row execute function public.notification_install_defaults_trigger();

select public.notification_seed_defaults_for_org(id) from public.organizations;

create or replace function public.notification_create_for_user_internal(
  p_organization_id uuid,
  p_factory_id uuid,
  p_recipient_user_id uuid,
  p_event_key text,
  p_category text,
  p_priority text,
  p_title text,
  p_body text,
  p_channels text[],
  p_action_route text,
  p_action_entity_id text,
  p_metadata jsonb,
  p_dedupe_key text
)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_in_app boolean:=true; v_push boolean:=true; v_muted text[]:='{}';
  v_quiet_start time; v_quiet_end time; v_allow_critical boolean:=true; v_timezone text:='UTC';
  v_local time; v_quiet boolean:=false; v_has_device boolean:=false; v_notification uuid;
begin
  if not exists(select 1 from public.organization_members om where om.organization_id=p_organization_id and om.user_id=p_recipient_user_id and om.is_active) then return null; end if;
  if p_factory_id is not null and not exists(
    select 1 from public.organization_members om
    where om.organization_id=p_organization_id and om.user_id=p_recipient_user_id and om.is_active
      and (om.role in ('platform_owner','org_admin') or exists(select 1 from public.factory_members fm where fm.factory_id=p_factory_id and fm.user_id=p_recipient_user_id and fm.is_active))
  ) then return null; end if;

  select coalesce(np.in_app_enabled,true),coalesce(np.push_enabled,true),coalesce(np.muted_categories,'{}'::text[]),np.quiet_hours_start,np.quiet_hours_end,coalesce(np.allow_critical_during_quiet,true)
    into v_in_app,v_push,v_muted,v_quiet_start,v_quiet_end,v_allow_critical
  from public.notification_preferences np where np.organization_id=p_organization_id and np.user_id=p_recipient_user_id;
  if not found then v_in_app:=true; v_push:=true; v_muted:='{}'; v_quiet_start:=null; v_quiet_end:=null; v_allow_critical:=true; end if;
  if p_category=any(v_muted) then return null; end if;
  if not v_in_app and not v_push then return null; end if;

  select timezone into v_timezone from public.organizations where id=p_organization_id;
  v_local := (now() at time zone coalesce(v_timezone,'UTC'))::time;
  if v_quiet_start is not null and v_quiet_end is not null then
    if v_quiet_start<v_quiet_end then v_quiet := v_local>=v_quiet_start and v_local<v_quiet_end;
    else v_quiet := v_local>=v_quiet_start or v_local<v_quiet_end; end if;
  end if;
  if p_priority='critical' and v_allow_critical then v_quiet:=false; end if;
  select exists(select 1 from public.notification_devices d where d.organization_id=p_organization_id and d.user_id=p_recipient_user_id and d.is_active) into v_has_device;

  insert into public.notifications(organization_id,factory_id,recipient_user_id,source_event_key,category,priority,title,body,action_route,action_entity_id,metadata,show_in_app,dedupe_key)
  values(p_organization_id,p_factory_id,p_recipient_user_id,p_event_key,p_category,coalesce(p_priority,'normal'),trim(p_title),trim(p_body),nullif(trim(coalesce(p_action_route,'')),''),nullif(trim(coalesce(p_action_entity_id,'')),''),coalesce(p_metadata,'{}'::jsonb),v_in_app,nullif(trim(coalesce(p_dedupe_key,'')),''))
  on conflict(recipient_user_id,dedupe_key) do update set title=excluded.title,body=excluded.body,priority=excluded.priority,metadata=excluded.metadata
  returning id into v_notification;

  insert into public.notification_deliveries(notification_id,channel,status,error_message,last_attempt_at)
  values(v_notification,'in_app',case when v_in_app then 'sent' else 'skipped' end,case when v_in_app then null else 'In-app notifications disabled' end,case when v_in_app then now() else null end)
  on conflict(notification_id,channel) do nothing;

  if 'push'=any(p_channels) then
    insert into public.notification_deliveries(notification_id,channel,status,error_message)
    values(v_notification,'push',case when not v_push then 'skipped' when v_quiet then 'skipped' when not v_has_device then 'skipped' else 'queued' end,
      case when not v_push then 'Push notifications disabled' when v_quiet then 'Quiet hours' when not v_has_device then 'No active device' else null end)
    on conflict(notification_id,channel) do nothing;
  end if;
  return v_notification;
end;
$$;
revoke all on function public.notification_create_for_user_internal(uuid,uuid,uuid,text,text,text,text,text,text[],text,text,jsonb,text) from public;

create or replace function public.notification_emit_event_internal(
  p_organization_id uuid,
  p_factory_id uuid,
  p_event_key text,
  p_title text,
  p_body text,
  p_category text,
  p_priority text,
  p_action_route text default null,
  p_action_entity_id text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_recipient_user_ids uuid[] default null,
  p_dedupe_key text default null
)
returns integer language plpgsql security definer set search_path=public as $$
declare r record; u record; v_count integer:=0; v_priority text;
begin
  for r in
    select nr.*,nt.default_priority
    from public.notification_rules nr join public.notification_templates nt on nt.id=nr.template_id
    where nr.organization_id=p_organization_id and nr.event_key=p_event_key and nr.is_active and nt.is_active
      and (nr.factory_id is null or nr.factory_id=p_factory_id)
  loop
    v_priority:=coalesce(r.priority_override,p_priority,r.default_priority,'normal');
    for u in
      select distinct om.user_id
      from public.organization_members om
      where om.organization_id=p_organization_id and om.is_active
        and (
          om.role=any(r.audience_roles)
          or (p_recipient_user_ids is not null and om.user_id=any(p_recipient_user_ids))
        )
        and (r.include_actor or auth.uid() is null or om.user_id<>auth.uid())
        and (p_factory_id is null or om.role in ('platform_owner','org_admin') or exists(select 1 from public.factory_members fm where fm.factory_id=p_factory_id and fm.user_id=om.user_id and fm.is_active))
    loop
      if public.notification_create_for_user_internal(p_organization_id,p_factory_id,u.user_id,p_event_key,p_category,v_priority,p_title,p_body,r.channels,p_action_route,p_action_entity_id,p_metadata,coalesce(p_dedupe_key,p_event_key||':'||coalesce(p_action_entity_id,gen_random_uuid()::text))) is not null then v_count:=v_count+1; end if;
    end loop;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.notification_emit_event_internal(uuid,uuid,text,text,text,text,text,text,text,jsonb,uuid[],text) from public;

create or replace function public.notification_inbox(p_limit integer default 50,p_unread_only boolean default false)
returns table(notification_id uuid,organization_id uuid,factory_id uuid,source_event_key text,category text,priority text,title text,body text,action_route text,action_entity_id text,metadata jsonb,created_at timestamptz,read_at timestamptz)
language sql stable security definer set search_path=public as $$
  select n.id,n.organization_id,n.factory_id,n.source_event_key,n.category,n.priority,n.title,n.body,n.action_route,n.action_entity_id,n.metadata,n.created_at,n.read_at
  from public.notifications n
  where n.recipient_user_id=auth.uid() and n.show_in_app and n.archived_at is null and (not p_unread_only or n.read_at is null)
  order by n.created_at desc
  limit greatest(1,least(coalesce(p_limit,50),200));
$$;
grant execute on function public.notification_inbox(integer,boolean) to authenticated;

create or replace function public.notification_unread_count()
returns integer language sql stable security definer set search_path=public as $$
  select count(*)::integer from public.notifications n where n.recipient_user_id=auth.uid() and n.show_in_app and n.archived_at is null and n.read_at is null;
$$;
grant execute on function public.notification_unread_count() to authenticated;

create or replace function public.notification_mark_read(p_notification_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  update public.notifications set read_at=coalesce(read_at,now()) where id=p_notification_id and recipient_user_id=auth.uid() and show_in_app;
  return found;
end;
$$;
grant execute on function public.notification_mark_read(uuid) to authenticated;

create or replace function public.notification_mark_all_read()
returns integer language plpgsql security definer set search_path=public as $$
declare v_count integer;
begin
  update public.notifications set read_at=now() where recipient_user_id=auth.uid() and show_in_app and archived_at is null and read_at is null;
  get diagnostics v_count=row_count;
  return v_count;
end;
$$;
grant execute on function public.notification_mark_all_read() to authenticated;

create or replace function public.notification_my_preferences(p_organization_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v jsonb;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  select jsonb_build_object('in_app_enabled',coalesce(np.in_app_enabled,true),'push_enabled',coalesce(np.push_enabled,true),'quiet_hours_start',np.quiet_hours_start,'quiet_hours_end',np.quiet_hours_end,'allow_critical_during_quiet',coalesce(np.allow_critical_during_quiet,true),'muted_categories',coalesce(np.muted_categories,'{}'::text[]),'active_devices',(select count(*) from public.notification_devices d where d.organization_id=p_organization_id and d.user_id=auth.uid() and d.is_active)) into v
  from (select 1) x left join public.notification_preferences np on np.organization_id=p_organization_id and np.user_id=auth.uid();
  return v;
end;
$$;
grant execute on function public.notification_my_preferences(uuid) to authenticated;

create or replace function public.notification_update_preferences(
  p_organization_id uuid,p_in_app_enabled boolean,p_push_enabled boolean,p_quiet_hours_start time default null,p_quiet_hours_end time default null,p_allow_critical_during_quiet boolean default true,p_muted_categories text[] default '{}'::text[]
)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if (p_quiet_hours_start is null)<>(p_quiet_hours_end is null) then raise exception 'Quiet hours require both start and end'; end if;
  insert into public.notification_preferences(organization_id,user_id,in_app_enabled,push_enabled,quiet_hours_start,quiet_hours_end,allow_critical_during_quiet,muted_categories)
  values(p_organization_id,auth.uid(),coalesce(p_in_app_enabled,true),coalesce(p_push_enabled,true),p_quiet_hours_start,p_quiet_hours_end,coalesce(p_allow_critical_during_quiet,true),coalesce(p_muted_categories,'{}'::text[]))
  on conflict(organization_id,user_id) do update set in_app_enabled=excluded.in_app_enabled,push_enabled=excluded.push_enabled,quiet_hours_start=excluded.quiet_hours_start,quiet_hours_end=excluded.quiet_hours_end,allow_critical_during_quiet=excluded.allow_critical_during_quiet,muted_categories=excluded.muted_categories;
  return public.notification_my_preferences(p_organization_id);
end;
$$;
grant execute on function public.notification_update_preferences(uuid,boolean,boolean,time,time,boolean,text[]) to authenticated;

create or replace function public.notification_register_device(p_organization_id uuid,p_platform text,p_device_token text,p_device_name text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_fp text;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_platform not in ('android','ios','web') then raise exception 'Unsupported platform'; end if;
  if char_length(trim(coalesce(p_device_token,'')))<12 then raise exception 'Invalid device token'; end if;
  v_fp:=encode(digest(trim(p_device_token),'sha256'),'hex');
  insert into public.notification_devices(organization_id,user_id,platform,device_name,device_token,token_fingerprint,is_active,last_seen_at)
  values(p_organization_id,auth.uid(),p_platform,nullif(trim(coalesce(p_device_name,'')),''),trim(p_device_token),v_fp,true,now())
  on conflict(user_id,token_fingerprint) do update set organization_id=excluded.organization_id,platform=excluded.platform,device_name=excluded.device_name,device_token=excluded.device_token,is_active=true,last_seen_at=now()
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.notification_register_device(uuid,text,text,text) to authenticated;

create or replace function public.notification_disable_device(p_device_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  update public.notification_devices set is_active=false where id=p_device_id and user_id=auth.uid();
  return found;
end;
$$;
grant execute on function public.notification_disable_device(uuid) to authenticated;

create or replace function public.notification_admin_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  if p_factory_id is null then
    if not public.has_org_role(p_organization_id,array['org_admin']::public.app_role[]) then raise exception 'Organization-wide notification access denied'; end if;
  elsif not public.can_manage_factory(p_factory_id) then raise exception 'Factory notification access denied'; end if;
  return jsonb_build_object(
    'notifications_24h',(select count(*) from public.notifications n where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and n.created_at>=now()-interval '24 hours'),
    'unread',(select count(*) from public.notifications n where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and n.show_in_app and n.read_at is null and n.archived_at is null),
    'actionable',(select count(*) from public.notifications n where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and n.priority in ('high','critical') and n.read_at is null),
    'push_queued',(select count(*) from public.notification_deliveries d join public.notifications n on n.id=d.notification_id where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and d.channel='push' and d.status='queued'),
    'push_failed',(select count(*) from public.notification_deliveries d join public.notifications n on n.id=d.notification_id where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and d.channel='push' and d.status='failed'),
    'active_devices',(select count(*) from public.notification_devices d where d.organization_id=p_organization_id and d.is_active),
    'active_rules',(select count(*) from public.notification_rules r where r.organization_id=p_organization_id and r.is_active and (p_factory_id is null or r.factory_id is null or r.factory_id=p_factory_id))
  );
end;
$$;
grant execute on function public.notification_admin_summary(uuid,uuid) to authenticated;

create or replace function public.notification_admin_recent(p_organization_id uuid,p_factory_id uuid default null,p_limit integer default 25)
returns table(notification_id uuid,title text,category text,priority text,recipient_name text,created_at timestamptz,in_app_status text,push_status text)
language plpgsql stable security definer set search_path=public as $$
begin
  if p_factory_id is null then
    if not public.has_org_role(p_organization_id,array['org_admin']::public.app_role[]) then raise exception 'Organization-wide notification access denied'; end if;
  elsif not public.can_manage_factory(p_factory_id) then raise exception 'Factory notification access denied'; end if;
  return query
    select n.id,n.title,n.category,n.priority,coalesce(p.full_name,split_part(u.email,'@',1),n.recipient_user_id::text),n.created_at,
      coalesce(max(d.status) filter(where d.channel='in_app'),'skipped'),coalesce(max(d.status) filter(where d.channel='push'),'skipped')
    from public.notifications n
    left join public.profiles p on p.id=n.recipient_user_id
    left join auth.users u on u.id=n.recipient_user_id
    left join public.notification_deliveries d on d.notification_id=n.id
    where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id)
    group by n.id,p.full_name,u.email
    order by n.created_at desc
    limit greatest(1,least(coalesce(p_limit,25),100));
end;
$$;
grant execute on function public.notification_admin_recent(uuid,uuid,integer) to authenticated;

create or replace function public.notification_broadcast(
  p_organization_id uuid,p_factory_id uuid,p_title text,p_body text,p_priority text default 'normal',p_category text default 'system',p_roles public.app_role[] default array['factory_manager','supervisor','employee','driver']::public.app_role[],p_channels text[] default array['in_app','push']::text[]
)
returns integer language plpgsql security definer set search_path=public as $$
declare u record; v_count integer:=0; v_key text:='system.broadcast:'||gen_random_uuid()::text;
begin
  if p_factory_id is null then
    if not public.has_org_role(p_organization_id,array['org_admin']::public.app_role[]) then raise exception 'Organization-wide broadcast denied'; end if;
  elsif not public.can_manage_factory(p_factory_id) then raise exception 'Factory broadcast denied'; end if;
  if p_priority not in ('low','normal','high','critical') then raise exception 'Invalid priority'; end if;
  if not (p_channels <@ array['in_app','push']::text[]) then raise exception 'Invalid channels'; end if;
  for u in select om.user_id from public.organization_members om where om.organization_id=p_organization_id and om.is_active and om.role=any(p_roles)
    and (p_factory_id is null or om.role in ('platform_owner','org_admin') or exists(select 1 from public.factory_members fm where fm.factory_id=p_factory_id and fm.user_id=om.user_id and fm.is_active))
  loop
    if public.notification_create_for_user_internal(p_organization_id,p_factory_id,u.user_id,v_key,p_category,p_priority,p_title,p_body,p_channels,null,null,jsonb_build_object('broadcast',true),v_key||':'||u.user_id::text) is not null then v_count:=v_count+1; end if;
  end loop;
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(p_organization_id,p_factory_id,auth.uid(),'broadcast','notification',v_key,jsonb_build_object('recipient_count',v_count,'priority',p_priority,'category',p_category));
  return v_count;
end;
$$;
grant execute on function public.notification_broadcast(uuid,uuid,text,text,text,text,public.app_role[],text[]) to authenticated;

create or replace function public.notification_rule_audit_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_org uuid:=coalesce(new.organization_id,old.organization_id); v_factory uuid:=coalesce(new.factory_id,old.factory_id); v_id uuid:=coalesce(new.id,old.id);
begin
  insert into public.audit_logs(organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_org,v_factory,auth.uid(),lower(tg_op),'notification_rule',v_id::text,jsonb_build_object('event_key',coalesce(new.event_key,old.event_key)));
  return coalesce(new,old);
end;
$$;
create trigger notification_rules_audit after insert or update or delete on public.notification_rules for each row execute function public.notification_rule_audit_trigger();

create or replace function public.notification_on_maintenance_work_order()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_user uuid;
begin
  if new.assigned_employee_id is null then return new; end if;
  if tg_op='UPDATE' and old.assigned_employee_id is not distinct from new.assigned_employee_id then return new; end if;
  select user_id into v_user from public.employees where id=new.assigned_employee_id;
  perform public.notification_emit_event_internal(new.organization_id,new.factory_id,'maintenance.work_order_assigned','Maintenance work order assigned',new.work_order_no||' · '||new.problem_description,'maintenance',new.priority,'/maintenance/work-orders/'||new.id,new.id::text,jsonb_build_object('work_order_no',new.work_order_no,'asset_id',new.asset_id),case when v_user is null then null else array[v_user] end,'maintenance.work_order_assigned:'||new.id||':'||coalesce(v_user::text,'none'));
  return new;
end;
$$;
create trigger notification_maintenance_work_order after insert or update of assigned_employee_id on public.maintenance_work_orders for each row execute function public.notification_on_maintenance_work_order();

create or replace function public.notification_on_dispatch_exception()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform public.notification_emit_event_internal(new.organization_id,new.factory_id,'dispatch.exception_reported','Delivery exception reported',replace(new.exception_type,'_',' ')||' · '||new.details,'dispatch','high','/dispatch/deliveries/'||new.delivery_id,new.id::text,jsonb_build_object('delivery_id',new.delivery_id,'exception_type',new.exception_type),null,'dispatch.exception_reported:'||new.id);
  return new;
end;
$$;
create trigger notification_dispatch_exception after insert on public.dispatch_delivery_exceptions for each row execute function public.notification_on_dispatch_exception();

create or replace function public.notification_on_dispatch_delivery()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if old.status is distinct from new.status and new.status='delivered' then
    perform public.notification_emit_event_internal(new.organization_id,new.factory_id,'dispatch.delivery_completed','Delivery completed',new.delivery_no||' was delivered to '||coalesce(new.receiver_name,'customer'),'dispatch','normal','/dispatch/deliveries/'||new.id,new.id::text,jsonb_build_object('delivery_no',new.delivery_no,'customer_id',new.customer_id),null,'dispatch.delivery_completed:'||new.id);
  end if;
  return new;
end;
$$;
create trigger notification_dispatch_delivery after update of status on public.dispatch_deliveries for each row execute function public.notification_on_dispatch_delivery();

create or replace function public.notification_on_leave_decision()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_user uuid; v_factory uuid;
begin
  if old.status is not distinct from new.status or new.status not in ('approved','rejected') then return new; end if;
  select user_id,primary_factory_id into v_user,v_factory from public.employees where id=new.employee_id;
  if v_user is null then return new; end if;
  perform public.notification_emit_event_internal(new.organization_id,v_factory,'hr.leave_decided','Leave request '||new.status,'Your leave request for '||new.start_date||' to '||new.end_date||' was '||new.status||'.','hr','normal','/hr/leave',new.id::text,jsonb_build_object('leave_request_id',new.id,'status',new.status),array[v_user],'hr.leave_decided:'||new.id||':'||new.status);
  return new;
end;
$$;
create trigger notification_leave_decision after update of status on public.leave_requests for each row execute function public.notification_on_leave_decision();

commit;
