begin;

-- Phase 14: Audit & Security Hardening.
-- Tightens factory-scoped reads, makes the business audit log tamper-evident,
-- and exposes guarded security review RPCs for Admin/Manager use.

insert into public.app_modules(key,name,description,sort_order,is_active)
values('security','Audit & Security','Audit explorer, access review and security integrity',140,true)
on conflict(key) do update set name=excluded.name,description=excluded.description,sort_order=excluded.sort_order,is_active=true;

insert into public.organization_modules(organization_id,module_key,is_enabled)
select id,'security',true from public.organizations
on conflict(organization_id,module_key) do update set is_enabled=true;

create or replace function public.security_enable_for_new_org()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  insert into public.organization_modules(organization_id,module_key,is_enabled)
  values(new.id,'security',true)
  on conflict(organization_id,module_key) do update set is_enabled=true;
  return new;
end;
$$;
revoke all on function public.security_enable_for_new_org() from public;
drop trigger if exists organizations_enable_security_after_insert on public.organizations;
create trigger organizations_enable_security_after_insert
after insert on public.organizations
for each row execute function public.security_enable_for_new_org();

-- Factory Manager access is assignment-scoped. The Phase 1 helper granted every
-- Factory Manager membership in every factory of their organization.
create or replace function public.is_factory_member(target_factory_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select public.is_platform_owner()
    or exists(
      select 1
      from public.factories f
      join public.organization_members om
        on om.organization_id=f.organization_id
       and om.user_id=auth.uid()
       and om.is_active
      where f.id=target_factory_id
        and f.is_active
        and om.role='org_admin'
    )
    or exists(
      select 1
      from public.factory_members fm
      join public.organization_members om
        on om.organization_id=fm.organization_id
       and om.user_id=fm.user_id
       and om.is_active
      join public.factories f on f.id=fm.factory_id and f.is_active
      where fm.factory_id=target_factory_id
        and fm.user_id=auth.uid()
        and fm.is_active
    );
$$;
grant execute on function public.is_factory_member(uuid) to authenticated;

-- Data-minimization hardening for member/profile reads.
drop policy if exists organization_members_select on public.organization_members;
create policy organization_members_select on public.organization_members
for select to authenticated
using(
  user_id=auth.uid()
  or public.is_platform_owner()
  or public.has_org_role(organization_id,array['org_admin']::public.app_role[])
  or exists(
    select 1
    from public.factory_members target
    join public.factory_members mine
      on mine.organization_id=target.organization_id
     and mine.factory_id=target.factory_id
     and mine.user_id=auth.uid()
     and mine.is_active
    join public.organization_members manager
      on manager.organization_id=mine.organization_id
     and manager.user_id=mine.user_id
     and manager.is_active
     and manager.role='factory_manager'
    where target.organization_id=organization_members.organization_id
      and target.user_id=organization_members.user_id
      and target.is_active
  )
);

drop policy if exists factory_members_select on public.factory_members;
create policy factory_members_select on public.factory_members
for select to authenticated
using(
  user_id=auth.uid()
  or public.is_platform_owner()
  or public.has_org_role(organization_id,array['org_admin']::public.app_role[])
  or public.can_manage_factory(factory_id)
);

drop policy if exists profiles_select_self_or_coworker on public.profiles;
create policy profiles_select_self_or_factory_coworker on public.profiles
for select to authenticated
using(
  id=auth.uid()
  or public.is_platform_owner()
  or exists(
    select 1
    from public.organization_members mine
    join public.organization_members theirs
      on theirs.organization_id=mine.organization_id
     and theirs.user_id=profiles.id
     and theirs.is_active
    where mine.user_id=auth.uid()
      and mine.is_active
      and mine.role='org_admin'
  )
  or exists(
    select 1
    from public.factory_members mine
    join public.factory_members theirs
      on theirs.organization_id=mine.organization_id
     and theirs.factory_id=mine.factory_id
     and theirs.user_id=profiles.id
     and theirs.is_active
    where mine.user_id=auth.uid()
      and mine.is_active
  )
);

-- Audit metadata used by the integrity chain and security UI.
alter table public.audit_logs add column if not exists severity text;
alter table public.audit_logs add column if not exists source text;
alter table public.audit_logs add column if not exists request_id text;
alter table public.audit_logs add column if not exists previous_hash text;
alter table public.audit_logs add column if not exists integrity_hash text;

create or replace function public.security_audit_severity(
  p_entity_type text,
  p_action text,
  p_metadata jsonb
)
returns text
language sql
immutable
set search_path=public
as $$
  select case
    when p_entity_type in ('organization_members','factory_members','organization_modules','notification_rules','user_invitations') then 'high'
    when p_entity_type in ('organizations','factories') then 'high'
    when p_action in ('delete','revoke','deactivate') then 'high'
    when p_entity_type in ('quality_nonconformances','maintenance_work_orders','dispatch_delivery_exceptions') then 'medium'
    else 'low'
  end;
$$;

create or replace function public.security_compute_audit_hash(
  p_id bigint,
  p_organization_id uuid,
  p_factory_id uuid,
  p_actor_user_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id text,
  p_metadata jsonb,
  p_created_at timestamptz,
  p_severity text,
  p_source text,
  p_request_id text,
  p_previous_hash text
)
returns text
language sql
immutable
set search_path=public
as $$
  select encode(
    extensions.digest(
      convert_to(
        jsonb_build_object(
          'id',p_id,
          'organization_id',p_organization_id,
          'factory_id',p_factory_id,
          'actor_user_id',p_actor_user_id,
          'action',p_action,
          'entity_type',p_entity_type,
          'entity_id',p_entity_id,
          'metadata',coalesce(p_metadata,'{}'::jsonb),
          'created_at',p_created_at,
          'severity',p_severity,
          'source',p_source,
          'request_id',p_request_id,
          'previous_hash',p_previous_hash
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
$$;

create or replace function public.security_request_id()
returns text
language plpgsql
stable
set search_path=public
as $$
declare
  v_headers_text text;
  v_headers jsonb;
begin
  v_headers_text:=current_setting('request.headers',true);
  if v_headers_text is null or trim(v_headers_text)='' then return null; end if;
  begin
    v_headers:=v_headers_text::jsonb;
    return nullif(coalesce(v_headers->>'x-request-id',v_headers->>'cf-ray'),'');
  exception when others then
    return null;
  end;
end;
$$;
revoke all on function public.security_request_id() from public;

-- Backfill the existing audit history into one chain per organization.
do $$
declare
  org_row record;
  r record;
  v_prev text;
  v_severity text;
  v_hash text;
begin
  for org_row in
    select organization_id from public.audit_logs group by organization_id order by organization_id nulls first
  loop
    v_prev:=null;
    for r in
      select * from public.audit_logs
      where organization_id is not distinct from org_row.organization_id
      order by id
    loop
      v_severity:=public.security_audit_severity(r.entity_type,r.action,r.metadata);
      v_hash:=public.security_compute_audit_hash(
        r.id,r.organization_id,r.factory_id,r.actor_user_id,r.action,r.entity_type,r.entity_id,
        r.metadata,r.created_at,v_severity,'business',r.request_id,v_prev
      );
      update public.audit_logs
      set severity=v_severity,source='business',previous_hash=v_prev,integrity_hash=v_hash
      where id=r.id;
      v_prev:=v_hash;
    end loop;
  end loop;
end $$;

alter table public.audit_logs alter column severity set default 'low';
alter table public.audit_logs alter column severity set not null;
alter table public.audit_logs alter column source set default 'business';
alter table public.audit_logs alter column source set not null;
alter table public.audit_logs
  add constraint audit_logs_severity_check check(severity in ('low','medium','high','critical'));
alter table public.audit_logs
  add constraint audit_logs_integrity_hash_check check(integrity_hash is null or integrity_hash ~ '^[0-9a-f]{64}$');
alter table public.audit_logs
  add constraint audit_logs_previous_hash_check check(previous_hash is null or previous_hash ~ '^[0-9a-f]{64}$');

create index if not exists audit_logs_org_severity_created_idx
  on public.audit_logs(organization_id,severity,created_at desc);
create index if not exists audit_logs_actor_created_idx
  on public.audit_logs(actor_user_id,created_at desc);
create index if not exists audit_logs_entity_created_idx
  on public.audit_logs(entity_type,created_at desc);

create or replace function public.audit_logs_prepare_integrity()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_prev text;
begin
  perform pg_advisory_xact_lock(hashtext(coalesce(new.organization_id::text,'__platform_audit__'))::bigint);

  select a.integrity_hash into v_prev
  from public.audit_logs a
  where a.organization_id is not distinct from new.organization_id
  order by a.id desc
  limit 1;

  new.severity:=public.security_audit_severity(new.entity_type,new.action,new.metadata);
  new.source:=coalesce(nullif(trim(new.source),''),'business');
  new.request_id:=coalesce(new.request_id,public.security_request_id());
  new.previous_hash:=v_prev;
  new.integrity_hash:=public.security_compute_audit_hash(
    new.id,new.organization_id,new.factory_id,new.actor_user_id,new.action,new.entity_type,
    new.entity_id,new.metadata,new.created_at,new.severity,new.source,new.request_id,new.previous_hash
  );
  return new;
end;
$$;
revoke all on function public.audit_logs_prepare_integrity() from public;
drop trigger if exists audit_logs_prepare_integrity_before_insert on public.audit_logs;
create trigger audit_logs_prepare_integrity_before_insert
before insert on public.audit_logs
for each row execute function public.audit_logs_prepare_integrity();

create or replace function public.audit_logs_reject_mutation()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if current_user not in ('postgres','supabase_admin') then
    raise exception 'Audit logs are immutable';
  end if;
  return coalesce(new,old);
end;
$$;
revoke all on function public.audit_logs_reject_mutation() from public;
drop trigger if exists audit_logs_immutable_before_change on public.audit_logs;
create trigger audit_logs_immutable_before_change
before update or delete on public.audit_logs
for each row execute function public.audit_logs_reject_mutation();

-- Sensitive tenant configuration must also be represented in the canonical audit log.
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
  v_org:=coalesce(new.organization_id,old.organization_id);
  v_id:=coalesce(new.module_key,old.module_key);
  v_metadata:=jsonb_build_object(
    'module_key',v_id,
    'enabled_before',case when tg_op<>'INSERT' then old.is_enabled else null end,
    'enabled_after',case when tg_op<>'DELETE' then new.is_enabled else null end
  );
  insert into public.audit_logs(organization_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_org,auth.uid(),lower(tg_op),tg_table_name,v_id,v_metadata);
  return coalesce(new,old);
end;
$$;
revoke all on function public.audit_security_config_change() from public;
drop trigger if exists organization_modules_audit_security_change on public.organization_modules;
create trigger organization_modules_audit_security_change
after insert or update or delete on public.organization_modules
for each row execute function public.audit_security_config_change();

-- Factory Managers may read audit data only for factories they actually manage.
drop policy if exists audit_logs_read on public.audit_logs;
create policy audit_logs_read on public.audit_logs
for select to authenticated
using(
  public.is_platform_owner()
  or (organization_id is not null and public.has_org_role(organization_id,array['org_admin']::public.app_role[]))
  or (factory_id is not null and public.can_manage_factory(factory_id))
);
revoke insert,update,delete on public.audit_logs from authenticated;

create or replace function public.security_can_view_scope(p_organization_id uuid,p_factory_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select case
    when auth.uid() is null then false
    when p_factory_id is null then
      public.is_platform_owner()
      or public.has_org_role(p_organization_id,array['org_admin']::public.app_role[])
    else
      exists(select 1 from public.factories f where f.id=p_factory_id and f.organization_id=p_organization_id)
      and (
        public.is_platform_owner()
        or public.has_org_role(p_organization_id,array['org_admin']::public.app_role[])
        or public.can_manage_factory(p_factory_id)
      )
  end;
$$;
revoke all on function public.security_can_view_scope(uuid,uuid) from public;

create or replace function public.security_audit_integrity_stats(p_organization_id uuid,p_limit integer default 1000)
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  with recent as (
    select *
    from public.audit_logs
    where organization_id=p_organization_id
    order by id desc
    limit greatest(1,least(coalesce(p_limit,1000),5000))
  ), ordered as (
    select r.*,
      lag(r.integrity_hash) over(order by r.id) as expected_previous_hash,
      row_number() over(order by r.id) as rn
    from recent r
  ), checked as (
    select o.*,
      public.security_compute_audit_hash(
        o.id,o.organization_id,o.factory_id,o.actor_user_id,o.action,o.entity_type,o.entity_id,
        o.metadata,o.created_at,o.severity,o.source,o.request_id,o.previous_hash
      ) as recomputed_hash
    from ordered o
  )
  select jsonb_build_object(
    'checked_rows',count(*),
    'broken_hashes',count(*) filter(where integrity_hash is null or integrity_hash<>recomputed_hash),
    'broken_chain_links',count(*) filter(where rn>1 and previous_hash is distinct from expected_previous_hash),
    'status',case when count(*) filter(where integrity_hash is null or integrity_hash<>recomputed_hash or (rn>1 and previous_hash is distinct from expected_previous_hash))=0 then 'verified' else 'failed' end,
    'latest_audit_at',max(created_at)
  )
  from checked;
$$;
revoke all on function public.security_audit_integrity_stats(uuid,integer) from public;

create or replace function public.security_verify_audit_integrity(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_limit integer default 1000
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v jsonb;
begin
  if not public.security_can_view_scope(p_organization_id,p_factory_id) then
    raise exception 'Security scope access denied';
  end if;
  v:=public.security_audit_integrity_stats(p_organization_id,p_limit);
  return v || jsonb_build_object('scope',case when p_factory_id is null then 'organization' else 'factory-visible' end);
end;
$$;
grant execute on function public.security_verify_audit_integrity(uuid,uuid,integer) to authenticated;

create or replace function public.security_admin_summary(
  p_organization_id uuid,
  p_factory_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_anomalies integer;
  v_integrity jsonb;
begin
  if not public.security_can_view_scope(p_organization_id,p_factory_id) then
    raise exception 'Security scope access denied';
  end if;

  select count(distinct om.user_id)::integer into v_anomalies
  from public.organization_members om
  left join public.profiles p on p.id=om.user_id
  where om.organization_id=p_organization_id
    and om.is_active
    and (p_factory_id is null or om.role in ('org_admin','platform_owner') or exists(
      select 1 from public.factory_members fm where fm.organization_id=om.organization_id and fm.user_id=om.user_id and fm.factory_id=p_factory_id and fm.is_active
    ))
    and (
      coalesce(p.is_active,false)=false
      or (om.role in ('factory_manager','supervisor','employee','driver') and not exists(
        select 1 from public.factory_members fm join public.factories f on f.id=fm.factory_id and f.is_active
        where fm.organization_id=om.organization_id and fm.user_id=om.user_id and fm.is_active
      ))
      or exists(
        select 1 from public.factory_members fm join public.factories f on f.id=fm.factory_id
        where fm.organization_id=om.organization_id and fm.user_id=om.user_id and fm.is_active and not f.is_active
      )
    );

  v_integrity:=public.security_audit_integrity_stats(p_organization_id,1000);

  return jsonb_build_object(
    'audit_events_24h',(select count(*) from public.audit_logs a where a.organization_id=p_organization_id and a.created_at>=now()-interval '24 hours' and (p_factory_id is null or a.factory_id=p_factory_id)),
    'high_risk_changes_7d',(select count(*) from public.audit_logs a where a.organization_id=p_organization_id and a.created_at>=now()-interval '7 days' and a.severity in ('high','critical') and (p_factory_id is null or a.factory_id=p_factory_id)),
    'access_anomalies',v_anomalies,
    'privileged_members',(select count(distinct om.user_id) from public.organization_members om where om.organization_id=p_organization_id and om.is_active and om.role in ('platform_owner','org_admin','factory_manager') and (p_factory_id is null or om.role in ('platform_owner','org_admin') or exists(select 1 from public.factory_members fm where fm.organization_id=om.organization_id and fm.user_id=om.user_id and fm.factory_id=p_factory_id and fm.is_active))),
    'stale_devices',(select count(*) from public.notification_devices d where d.organization_id=p_organization_id and d.is_active and d.last_seen_at<now()-interval '90 days'),
    'integrity_status',v_integrity->>'status',
    'integrity_broken_hashes',(v_integrity->>'broken_hashes')::integer,
    'integrity_broken_links',(v_integrity->>'broken_chain_links')::integer,
    'latest_audit_at',v_integrity->>'latest_audit_at'
  );
end;
$$;
grant execute on function public.security_admin_summary(uuid,uuid) to authenticated;

create or replace function public.security_audit_feed(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_limit integer default 100,
  p_severity text default null,
  p_entity_type text default null,
  p_actor_user_id uuid default null
)
returns table(
  audit_id bigint,
  created_at timestamptz,
  actor_user_id uuid,
  actor_name text,
  severity text,
  action text,
  entity_type text,
  entity_id text,
  factory_id uuid,
  metadata jsonb,
  request_id text,
  integrity_hash text
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.security_can_view_scope(p_organization_id,p_factory_id) then
    raise exception 'Security scope access denied';
  end if;
  return query
  select a.id,a.created_at,a.actor_user_id,coalesce(p.full_name,'System')::text,a.severity,a.action,a.entity_type,a.entity_id,a.factory_id,a.metadata,a.request_id,a.integrity_hash
  from public.audit_logs a
  left join public.profiles p on p.id=a.actor_user_id
  where a.organization_id=p_organization_id
    and (p_factory_id is null or a.factory_id=p_factory_id)
    and (p_severity is null or a.severity=p_severity)
    and (p_entity_type is null or a.entity_type=p_entity_type)
    and (p_actor_user_id is null or a.actor_user_id=p_actor_user_id)
  order by a.created_at desc,a.id desc
  limit greatest(1,least(coalesce(p_limit,100),500));
end;
$$;
grant execute on function public.security_audit_feed(uuid,uuid,integer,text,text,uuid) to authenticated;

create or replace function public.security_access_review(
  p_organization_id uuid,
  p_factory_id uuid default null
)
returns table(
  user_id uuid,
  full_name text,
  role text,
  is_active boolean,
  profile_active boolean,
  factory_ids uuid[],
  factory_names text[],
  issues text[]
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.security_can_view_scope(p_organization_id,p_factory_id) then
    raise exception 'Security scope access denied';
  end if;

  return query
  with members as (
    select om.user_id,coalesce(p.full_name,'Unnamed user')::text as full_name,om.role::text as role,om.role as role_enum,
      om.is_active,coalesce(p.is_active,false) as profile_active,
      coalesce(array_agg(fm.factory_id order by f.name) filter(where fm.is_active),'{}'::uuid[]) as factory_ids,
      coalesce(array_agg(f.name order by f.name) filter(where fm.is_active),'{}'::text[]) as factory_names,
      count(fm.factory_id) filter(where fm.is_active and f.is_active) as active_factory_count,
      count(fm.factory_id) filter(where fm.is_active and not f.is_active) as inactive_factory_count
    from public.organization_members om
    left join public.profiles p on p.id=om.user_id
    left join public.factory_members fm on fm.organization_id=om.organization_id and fm.user_id=om.user_id
    left join public.factories f on f.id=fm.factory_id
    where om.organization_id=p_organization_id
      and (
        p_factory_id is null
        or om.user_id=auth.uid()
        or exists(select 1 from public.factory_members visible where visible.organization_id=om.organization_id and visible.user_id=om.user_id and visible.factory_id=p_factory_id and visible.is_active)
      )
    group by om.user_id,p.full_name,om.role,om.is_active,p.is_active
  )
  select m.user_id,m.full_name,m.role,m.is_active,m.profile_active,m.factory_ids,m.factory_names,
    array_remove(array[
      case when m.is_active and not m.profile_active then 'Inactive profile with active access' end,
      case when m.is_active and m.role_enum in ('factory_manager','supervisor','employee','driver') and m.active_factory_count=0 then 'Required factory assignment missing' end,
      case when m.inactive_factory_count>0 then 'Active assignment points to inactive factory' end
    ]::text[],null) as issues
  from members m
  order by cardinality(array_remove(array[
      case when m.is_active and not m.profile_active then 'Inactive profile with active access' end,
      case when m.is_active and m.role_enum in ('factory_manager','supervisor','employee','driver') and m.active_factory_count=0 then 'Required factory assignment missing' end,
      case when m.inactive_factory_count>0 then 'Active assignment points to inactive factory' end
    ]::text[],null)) desc,m.full_name;
end;
$$;
grant execute on function public.security_access_review(uuid,uuid) to authenticated;

commit;
