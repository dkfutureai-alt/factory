begin;

-- Phase 13 channel hardening: delivery must respect both the rule/broadcast
-- channel selection and the recipient's preferences.
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
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_in_app_pref boolean:=true;
  v_push_pref boolean:=true;
  v_in_app_selected boolean:=false;
  v_push_selected boolean:=false;
  v_muted text[]:='{}';
  v_quiet_start time;
  v_quiet_end time;
  v_allow_critical boolean:=true;
  v_timezone text:='UTC';
  v_local time;
  v_quiet boolean:=false;
  v_has_device boolean:=false;
  v_notification uuid;
begin
  if not exists(
    select 1
    from public.organization_members om
    where om.organization_id=p_organization_id
      and om.user_id=p_recipient_user_id
      and om.is_active
  ) then
    return null;
  end if;

  if p_factory_id is not null and not exists(
    select 1
    from public.organization_members om
    where om.organization_id=p_organization_id
      and om.user_id=p_recipient_user_id
      and om.is_active
      and (
        om.role in ('platform_owner','org_admin')
        or exists(
          select 1
          from public.factory_members fm
          where fm.factory_id=p_factory_id
            and fm.user_id=p_recipient_user_id
            and fm.is_active
        )
      )
  ) then
    return null;
  end if;

  v_in_app_selected := 'in_app'=any(coalesce(p_channels,'{}'::text[]));
  v_push_selected := 'push'=any(coalesce(p_channels,'{}'::text[]));
  if not v_in_app_selected and not v_push_selected then return null; end if;

  select
    coalesce(np.in_app_enabled,true),
    coalesce(np.push_enabled,true),
    coalesce(np.muted_categories,'{}'::text[]),
    np.quiet_hours_start,
    np.quiet_hours_end,
    coalesce(np.allow_critical_during_quiet,true)
  into
    v_in_app_pref,
    v_push_pref,
    v_muted,
    v_quiet_start,
    v_quiet_end,
    v_allow_critical
  from public.notification_preferences np
  where np.organization_id=p_organization_id
    and np.user_id=p_recipient_user_id;

  if not found then
    v_in_app_pref:=true;
    v_push_pref:=true;
    v_muted:='{}';
    v_quiet_start:=null;
    v_quiet_end:=null;
    v_allow_critical:=true;
  end if;

  if p_category=any(v_muted) then return null; end if;

  select timezone into v_timezone
  from public.organizations
  where id=p_organization_id;

  v_local := (now() at time zone coalesce(v_timezone,'UTC'))::time;
  if v_quiet_start is not null and v_quiet_end is not null then
    if v_quiet_start<v_quiet_end then
      v_quiet := v_local>=v_quiet_start and v_local<v_quiet_end;
    else
      v_quiet := v_local>=v_quiet_start or v_local<v_quiet_end;
    end if;
  end if;
  if p_priority='critical' and v_allow_critical then v_quiet:=false; end if;

  select exists(
    select 1
    from public.notification_devices d
    where d.organization_id=p_organization_id
      and d.user_id=p_recipient_user_id
      and d.is_active
  ) into v_has_device;

  insert into public.notifications(
    organization_id,factory_id,recipient_user_id,source_event_key,category,
    priority,title,body,action_route,action_entity_id,metadata,show_in_app,dedupe_key
  ) values(
    p_organization_id,p_factory_id,p_recipient_user_id,p_event_key,p_category,
    coalesce(p_priority,'normal'),trim(p_title),trim(p_body),
    nullif(trim(coalesce(p_action_route,'')),''),
    nullif(trim(coalesce(p_action_entity_id,'')),''),
    coalesce(p_metadata,'{}'::jsonb),
    v_in_app_selected and v_in_app_pref,
    nullif(trim(coalesce(p_dedupe_key,'')),'')
  )
  on conflict(recipient_user_id,dedupe_key) do update
    set title=excluded.title,
        body=excluded.body,
        priority=excluded.priority,
        metadata=excluded.metadata,
        show_in_app=excluded.show_in_app
  returning id into v_notification;

  if v_in_app_selected then
    insert into public.notification_deliveries(
      notification_id,channel,status,error_message,last_attempt_at
    ) values(
      v_notification,
      'in_app',
      case when v_in_app_pref then 'sent' else 'skipped' end,
      case when v_in_app_pref then null else 'In-app notifications disabled' end,
      case when v_in_app_pref then now() else null end
    )
    on conflict(notification_id,channel) do update
      set status=excluded.status,
          error_message=excluded.error_message,
          last_attempt_at=excluded.last_attempt_at;
  else
    delete from public.notification_deliveries
    where notification_id=v_notification and channel='in_app';
  end if;

  if v_push_selected then
    insert into public.notification_deliveries(
      notification_id,channel,status,error_message
    ) values(
      v_notification,
      'push',
      case
        when not v_push_pref then 'skipped'
        when v_quiet then 'skipped'
        when not v_has_device then 'skipped'
        else 'queued'
      end,
      case
        when not v_push_pref then 'Push notifications disabled'
        when v_quiet then 'Quiet hours'
        when not v_has_device then 'No active device'
        else null
      end
    )
    on conflict(notification_id,channel) do update
      set status=excluded.status,
          error_message=excluded.error_message;
  else
    delete from public.notification_deliveries
    where notification_id=v_notification and channel='push';
  end if;

  return v_notification;
end;
$$;

revoke all on function public.notification_create_for_user_internal(uuid,uuid,uuid,text,text,text,text,text,text[],text,text,jsonb,text) from public;

commit;
