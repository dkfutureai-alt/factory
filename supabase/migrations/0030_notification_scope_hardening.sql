begin;

-- Phase 13 scope hardening: exact factory rule visibility and organization-bound devices.

drop policy if exists notification_rules_select on public.notification_rules;
create policy notification_rules_select on public.notification_rules
for select to authenticated
using(
  public.has_org_role(organization_id,array['org_admin']::public.app_role[])
  or (factory_id is not null and public.can_manage_factory(factory_id))
);

alter table public.notification_devices
  drop constraint if exists notification_devices_user_id_token_fingerprint_key;
create unique index if not exists notification_devices_org_user_token_unique
  on public.notification_devices(organization_id,user_id,token_fingerprint);

create or replace function public.notification_register_device(
  p_organization_id uuid,
  p_platform text,
  p_device_token text,
  p_device_name text default null
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
  v_fp text;
begin
  if not public.is_org_member(p_organization_id) then raise exception 'Organization access denied'; end if;
  if p_platform not in ('android','ios','web') then raise exception 'Unsupported platform'; end if;
  if char_length(trim(coalesce(p_device_token,'')))<12 then raise exception 'Invalid device token'; end if;
  v_fp:=encode(digest(trim(p_device_token),'sha256'),'hex');

  insert into public.notification_devices(
    organization_id,user_id,platform,device_name,device_token,token_fingerprint,is_active,last_seen_at
  ) values(
    p_organization_id,auth.uid(),p_platform,nullif(trim(coalesce(p_device_name,'')),''),trim(p_device_token),v_fp,true,now()
  )
  on conflict(organization_id,user_id,token_fingerprint) do update
    set platform=excluded.platform,
        device_name=excluded.device_name,
        device_token=excluded.device_token,
        is_active=true,
        last_seen_at=now()
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.notification_register_device(uuid,text,text,text) to authenticated;

create or replace function public.notification_admin_summary(p_organization_id uuid,p_factory_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  if p_factory_id is null then
    if not public.has_org_role(p_organization_id,array['org_admin']::public.app_role[]) then raise exception 'Organization-wide notification access denied'; end if;
  elsif not public.can_manage_factory(p_factory_id) then
    raise exception 'Factory notification access denied';
  end if;

  return jsonb_build_object(
    'notifications_24h',(select count(*) from public.notifications n where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and n.created_at>=now()-interval '24 hours'),
    'unread',(select count(*) from public.notifications n where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and n.show_in_app and n.read_at is null and n.archived_at is null),
    'actionable',(select count(*) from public.notifications n where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and n.priority in ('high','critical') and n.read_at is null),
    'push_queued',(select count(*) from public.notification_deliveries d join public.notifications n on n.id=d.notification_id where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and d.channel='push' and d.status='queued'),
    'push_failed',(select count(*) from public.notification_deliveries d join public.notifications n on n.id=d.notification_id where n.organization_id=p_organization_id and (p_factory_id is null or n.factory_id=p_factory_id) and d.channel='push' and d.status='failed'),
    'active_devices',(
      select count(*)
      from public.notification_devices d
      where d.organization_id=p_organization_id and d.is_active
        and (
          p_factory_id is null
          or exists(
            select 1
            from public.factory_members fm
            where fm.organization_id=p_organization_id
              and fm.factory_id=p_factory_id
              and fm.user_id=d.user_id
              and fm.is_active
          )
          or exists(
            select 1
            from public.organization_members om
            where om.organization_id=p_organization_id
              and om.user_id=d.user_id
              and om.is_active
              and om.role in ('platform_owner','org_admin')
          )
        )
    ),
    'active_rules',(select count(*) from public.notification_rules r where r.organization_id=p_organization_id and r.is_active and (p_factory_id is null or r.factory_id is null or r.factory_id=p_factory_id))
  );
end;
$$;
grant execute on function public.notification_admin_summary(uuid,uuid) to authenticated;

commit;
