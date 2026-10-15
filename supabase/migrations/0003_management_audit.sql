begin;

-- Platform owners may create new client organizations. Existing organization admins
-- continue to manage only organizations they belong to through the update policy.
create policy organizations_insert_platform_owner on public.organizations
for insert to authenticated
with check (public.is_platform_owner());

-- Keep business audit writes server-side. The trigger runs as its owner and records
-- the authenticated user without granting direct audit-log insert permission.
create or replace function public.audit_management_change()
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
  if tg_table_name = 'organizations' then
    target_org := coalesce(new.id, old.id);
    target_factory := null;
    target_id := target_org::text;
  elsif tg_table_name = 'factories' then
    target_org := coalesce(new.organization_id, old.organization_id);
    target_factory := coalesce(new.id, old.id);
    target_id := target_factory::text;
  else
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    payload := jsonb_build_object('after', to_jsonb(new));
  elsif tg_op = 'UPDATE' then
    payload := jsonb_build_object('before', to_jsonb(old), 'after', to_jsonb(new));
  else
    payload := jsonb_build_object('before', to_jsonb(old));
  end if;

  insert into public.audit_logs (
    organization_id,
    factory_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  ) values (
    target_org,
    target_factory,
    auth.uid(),
    lower(tg_op),
    tg_table_name,
    target_id,
    payload
  );

  return coalesce(new, old);
end;
$$;

revoke all on function public.audit_management_change() from public;

create trigger organizations_audit_change
after insert or update or delete on public.organizations
for each row execute function public.audit_management_change();

create trigger factories_audit_change
after insert or update or delete on public.factories
for each row execute function public.audit_management_change();

commit;
