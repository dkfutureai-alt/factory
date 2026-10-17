begin;

-- Phase 16: a physical push target must follow the currently signed-in user.
-- The original two-column uniqueness prevented the same user/device from being
-- registered in multiple organizations even though notification delivery is
-- organization-scoped. Replace it with the intended tenant-aware key.
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
set search_path=''
as $$
declare
  v_id uuid;
  v_fp text;
begin
  if not public.is_org_member(p_organization_id) then
    raise exception 'Organization access denied';
  end if;
  if p_platform not in ('android','ios','web') then
    raise exception 'Unsupported platform';
  end if;
  if char_length(trim(coalesce(p_device_token,'')))<12 then
    raise exception 'Invalid device token';
  end if;

  v_fp:=pg_catalog.encode(
    extensions.digest(trim(p_device_token),'sha256'),
    'hex'
  );

  -- A shared factory handset can change users. Once this token is claimed by
  -- the current user, deactivate any stale active row owned by another user so
  -- notifications do not leak across sessions.
  update public.notification_devices
  set is_active=false,
      updated_at=now()
  where token_fingerprint=v_fp
    and user_id<>auth.uid()
    and is_active;

  insert into public.notification_devices(
    organization_id,user_id,platform,device_name,device_token,
    token_fingerprint,is_active,last_seen_at
  ) values(
    p_organization_id,
    auth.uid(),
    p_platform,
    nullif(trim(coalesce(p_device_name,'')),''),
    trim(p_device_token),
    v_fp,
    true,
    now()
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

create or replace function public.notification_disable_current_device(
  p_device_token text
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_fp text;
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if char_length(trim(coalesce(p_device_token,'')))<12 then
    raise exception 'Invalid device token';
  end if;

  v_fp:=pg_catalog.encode(
    extensions.digest(trim(p_device_token),'sha256'),
    'hex'
  );

  update public.notification_devices
  set is_active=false,
      updated_at=now()
  where user_id=auth.uid()
    and token_fingerprint=v_fp
    and is_active;

  get diagnostics v_count = row_count;
  return v_count>0;
end;
$$;

revoke all on function public.notification_register_device(uuid,text,text,text) from public, anon;
revoke all on function public.notification_disable_current_device(text) from public, anon;
grant execute on function public.notification_register_device(uuid,text,text,text) to authenticated;
grant execute on function public.notification_disable_current_device(text) to authenticated;

commit;
