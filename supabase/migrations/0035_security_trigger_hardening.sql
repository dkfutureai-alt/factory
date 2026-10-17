begin;

create or replace function public.audit_security_config_change()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_org uuid;
  v_id text;
  v_metadata jsonb;
begin
  if tg_op='INSERT' then
    v_org:=new.organization_id;
    v_id:=new.module_key;
    v_metadata:=jsonb_build_object(
      'module_key',new.module_key,
      'enabled_before',null,
      'enabled_after',new.is_enabled
    );
  elsif tg_op='UPDATE' then
    v_org:=new.organization_id;
    v_id:=new.module_key;
    v_metadata:=jsonb_build_object(
      'module_key',new.module_key,
      'enabled_before',old.is_enabled,
      'enabled_after',new.is_enabled
    );
  else
    v_org:=old.organization_id;
    v_id:=old.module_key;
    v_metadata:=jsonb_build_object(
      'module_key',old.module_key,
      'enabled_before',old.is_enabled,
      'enabled_after',null
    );
  end if;

  insert into public.audit_logs(
    organization_id,actor_user_id,action,entity_type,entity_id,metadata
  ) values(
    v_org,auth.uid(),lower(tg_op),tg_table_name,v_id,v_metadata
  );
  return case when tg_op='DELETE' then old else new end;
end;
$$;
revoke all on function public.audit_security_config_change() from public;

commit;
