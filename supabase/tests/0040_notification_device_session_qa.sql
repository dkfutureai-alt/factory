begin;

do $$
declare
  v_register_config text;
  v_disable_config text;
begin
  if to_regclass('public.notification_devices_org_user_token_unique') is null then
    raise exception 'Tenant-aware notification device uniqueness index is missing';
  end if;

  select coalesce(array_to_string(p.proconfig, ','), '')
  into v_register_config
  from pg_proc p
  where p.oid='public.notification_register_device(uuid,text,text,text)'::regprocedure;

  select coalesce(array_to_string(p.proconfig, ','), '')
  into v_disable_config
  from pg_proc p
  where p.oid='public.notification_disable_current_device(text)'::regprocedure;

  if v_register_config not like '%search_path=""%' then
    raise exception 'notification_register_device search_path is not pinned: %', v_register_config;
  end if;
  if v_disable_config not like '%search_path=""%' then
    raise exception 'notification_disable_current_device search_path is not pinned: %', v_disable_config;
  end if;

  if has_function_privilege('anon','public.notification_register_device(uuid,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.notification_disable_current_device(text)','EXECUTE') then
    raise exception 'Anonymous role can execute notification device session RPCs';
  end if;

  if not has_function_privilege('authenticated','public.notification_register_device(uuid,text,text,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.notification_disable_current_device(text)','EXECUTE') then
    raise exception 'Authenticated role lost notification device session RPC access';
  end if;
end;
$$;

rollback;
