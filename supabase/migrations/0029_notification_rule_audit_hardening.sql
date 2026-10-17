begin;

-- Phase 13 hardening: make rule audit safe for INSERT / UPDATE / DELETE records.
create or replace function public.notification_rule_audit_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_org uuid;
  v_factory uuid;
  v_id uuid;
  v_event_key text;
begin
  if tg_op='DELETE' then
    v_org:=old.organization_id;
    v_factory:=old.factory_id;
    v_id:=old.id;
    v_event_key:=old.event_key;
  else
    v_org:=new.organization_id;
    v_factory:=new.factory_id;
    v_id:=new.id;
    v_event_key:=new.event_key;
  end if;

  insert into public.audit_logs(
    organization_id,factory_id,actor_user_id,action,entity_type,entity_id,metadata
  ) values(
    v_org,v_factory,auth.uid(),lower(tg_op),'notification_rule',v_id::text,
    jsonb_build_object('event_key',v_event_key)
  );

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

commit;
