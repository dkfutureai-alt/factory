\set ON_ERROR_STOP on

begin;

do $$
begin
  if not exists(select 1 from public.app_modules where key='security' and is_active) then
    raise exception 'security module missing';
  end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='audit_logs' and column_name='integrity_hash') then
    raise exception 'audit integrity hash missing';
  end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='audit_logs' and column_name='previous_hash') then
    raise exception 'audit previous hash missing';
  end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='audit_logs' and column_name='severity') then
    raise exception 'audit severity missing';
  end if;
  if not exists(select 1 from pg_trigger where tgname='audit_logs_prepare_integrity_before_insert' and not tgisinternal) then
    raise exception 'audit integrity insert trigger missing';
  end if;
  if not exists(select 1 from pg_trigger where tgname='audit_logs_immutable_before_change' and not tgisinternal) then
    raise exception 'audit immutability trigger missing';
  end if;
  if not exists(select 1 from pg_proc where proname='security_admin_summary') then raise exception 'security summary RPC missing'; end if;
  if not exists(select 1 from pg_proc where proname='security_audit_feed') then raise exception 'security audit feed RPC missing'; end if;
  if not exists(select 1 from pg_proc where proname='security_access_review') then raise exception 'security access review RPC missing'; end if;
  if not exists(select 1 from pg_proc where proname='security_verify_audit_integrity') then raise exception 'security integrity RPC missing'; end if;
end $$;

do $$
declare
  v_org uuid:='91000000-0000-4000-8000-000000000001';
  v_id bigint;
  v_hash text;
  v_expected text;
begin
  insert into public.organizations(id,name,code)
  values(v_org,'Security Smoke Industries','SEC-SMOKE');

  insert into public.audit_logs(organization_id,action,entity_type,entity_id,metadata)
  values(v_org,'insert','security_smoke','row-1',jsonb_build_object('ok',true))
  returning id,integrity_hash into v_id,v_hash;

  if v_hash is null or char_length(v_hash)<>64 then
    raise exception 'audit hash was not generated';
  end if;

  select public.security_compute_audit_hash(
    a.id,a.organization_id,a.factory_id,a.actor_user_id,a.action,a.entity_type,a.entity_id,
    a.metadata,a.created_at,a.severity,a.source,a.request_id,a.previous_hash
  ) into v_expected
  from public.audit_logs a where a.id=v_id;

  if v_hash<>v_expected then
    raise exception 'audit hash recomputation mismatch';
  end if;
end $$;

do $$
begin
  if has_table_privilege('authenticated','public.audit_logs','INSERT')
     or has_table_privilege('authenticated','public.audit_logs','UPDATE')
     or has_table_privilege('authenticated','public.audit_logs','DELETE') then
    raise exception 'authenticated role must not mutate audit_logs directly';
  end if;

  if not has_function_privilege('authenticated','public.security_admin_summary(uuid,uuid)','EXECUTE') then
    raise exception 'security summary execute privilege missing';
  end if;
  if not has_function_privilege('authenticated','public.security_audit_feed(uuid,uuid,integer,text,text,uuid)','EXECUTE') then
    raise exception 'security audit feed execute privilege missing';
  end if;
  if not has_function_privilege('authenticated','public.security_access_review(uuid,uuid)','EXECUTE') then
    raise exception 'security access review execute privilege missing';
  end if;
  if not has_function_privilege('authenticated','public.security_verify_audit_integrity(uuid,uuid,integer)','EXECUTE') then
    raise exception 'security integrity execute privilege missing';
  end if;
end $$;

do $$
declare
  unsafe_count integer;
  immutable_is_definer boolean;
begin
  select count(*) into unsafe_count
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.prosecdef
    and p.proname like 'security_%'
    and not exists(
      select 1 from unnest(coalesce(p.proconfig,'{}'::text[])) config
      where config like 'search_path=%'
    );
  if unsafe_count<>0 then
    raise exception '% security definer functions lack explicit search_path',unsafe_count;
  end if;

  select p.prosecdef into immutable_is_definer
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='audit_logs_reject_mutation';
  if immutable_is_definer is distinct from false then
    raise exception 'audit immutability trigger function must run as SECURITY INVOKER';
  end if;

  if not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='security_can_view_org_user' and p.prosecdef
  ) then
    raise exception 'organization-user visibility helper must be SECURITY DEFINER';
  end if;
  if not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='security_can_view_profile' and p.prosecdef
  ) then
    raise exception 'profile visibility helper must be SECURITY DEFINER';
  end if;
end $$;

rollback;

select 'audit and security hardening smoke checks passed' as result;
