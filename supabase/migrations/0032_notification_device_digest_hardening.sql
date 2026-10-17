begin;

-- Phase 13 device registration hardening: pgcrypto lives in Supabase's
-- extensions schema, while this SECURITY DEFINER function intentionally keeps
-- a restricted search_path. Qualify digest explicitly instead of widening it.
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

  v_fp:=encode(extensions.digest(trim(p_device_token),'sha256'),'hex');

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

commit;
