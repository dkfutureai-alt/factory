begin;

create or replace function public.security_can_view_org_user(
  p_organization_id uuid,
  p_target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select p_target_user_id=auth.uid()
    or public.is_platform_owner()
    or public.has_org_role(p_organization_id,array['org_admin']::public.app_role[])
    or exists(
      select 1
      from public.organization_members manager
      join public.factory_members mine
        on mine.organization_id=manager.organization_id
       and mine.user_id=manager.user_id
       and mine.is_active
      join public.factory_members target
        on target.organization_id=mine.organization_id
       and target.factory_id=mine.factory_id
       and target.user_id=p_target_user_id
       and target.is_active
      where manager.organization_id=p_organization_id
        and manager.user_id=auth.uid()
        and manager.is_active
        and manager.role='factory_manager'
    );
$$;
revoke all on function public.security_can_view_org_user(uuid,uuid) from public;
grant execute on function public.security_can_view_org_user(uuid,uuid) to authenticated;

create or replace function public.security_can_view_profile(p_target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select p_target_user_id=auth.uid()
    or public.is_platform_owner()
    or exists(
      select 1
      from public.organization_members mine
      join public.organization_members target
        on target.organization_id=mine.organization_id
       and target.user_id=p_target_user_id
       and target.is_active
      where mine.user_id=auth.uid()
        and mine.is_active
        and mine.role='org_admin'
    )
    or exists(
      select 1
      from public.factory_members mine
      join public.factory_members target
        on target.organization_id=mine.organization_id
       and target.factory_id=mine.factory_id
       and target.user_id=p_target_user_id
       and target.is_active
      join public.organization_members mine_org
        on mine_org.organization_id=mine.organization_id
       and mine_org.user_id=mine.user_id
       and mine_org.is_active
      join public.organization_members target_org
        on target_org.organization_id=target.organization_id
       and target_org.user_id=target.user_id
       and target_org.is_active
      where mine.user_id=auth.uid()
        and mine.is_active
    );
$$;
revoke all on function public.security_can_view_profile(uuid) from public;
grant execute on function public.security_can_view_profile(uuid) to authenticated;

drop policy if exists organization_members_select on public.organization_members;
create policy organization_members_select on public.organization_members
for select to authenticated
using(public.security_can_view_org_user(organization_id,user_id));

drop policy if exists profiles_select_self_or_factory_coworker on public.profiles;
create policy profiles_select_self_or_factory_coworker on public.profiles
for select to authenticated
using(public.security_can_view_profile(id));

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
    and (p_factory_id is null or exists(
      select 1 from public.factory_members fm
      where fm.organization_id=om.organization_id
        and fm.user_id=om.user_id
        and fm.factory_id=p_factory_id
        and fm.is_active
    ))
    and (
      coalesce(p.is_active,false)=false
      or (om.role in ('factory_manager','supervisor','employee','driver') and not exists(
        select 1 from public.factory_members fm
        join public.factories f on f.id=fm.factory_id and f.is_active
        where fm.organization_id=om.organization_id
          and fm.user_id=om.user_id
          and fm.is_active
      ))
      or exists(
        select 1 from public.factory_members fm
        join public.factories f on f.id=fm.factory_id
        where fm.organization_id=om.organization_id
          and fm.user_id=om.user_id
          and fm.is_active
          and not f.is_active
      )
    );

  v_integrity:=public.security_audit_integrity_stats(p_organization_id,1000);

  return jsonb_build_object(
    'audit_events_24h',(select count(*) from public.audit_logs a where a.organization_id=p_organization_id and a.created_at>=now()-interval '24 hours' and (p_factory_id is null or a.factory_id=p_factory_id)),
    'high_risk_changes_7d',(select count(*) from public.audit_logs a where a.organization_id=p_organization_id and a.created_at>=now()-interval '7 days' and a.severity in ('high','critical') and (p_factory_id is null or a.factory_id=p_factory_id)),
    'access_anomalies',v_anomalies,
    'privileged_members',(
      select count(distinct om.user_id)
      from public.organization_members om
      where om.organization_id=p_organization_id
        and om.is_active
        and om.role in ('platform_owner','org_admin','factory_manager')
        and (
          p_factory_id is null
          or exists(
            select 1 from public.factory_members fm
            where fm.organization_id=om.organization_id
              and fm.user_id=om.user_id
              and fm.factory_id=p_factory_id
              and fm.is_active
          )
        )
    ),
    'stale_devices',(
      select count(*)
      from public.notification_devices d
      where d.organization_id=p_organization_id
        and d.is_active
        and d.last_seen_at<now()-interval '90 days'
        and (
          p_factory_id is null
          or exists(
            select 1 from public.factory_members fm
            where fm.organization_id=d.organization_id
              and fm.user_id=d.user_id
              and fm.factory_id=p_factory_id
              and fm.is_active
          )
        )
    ),
    'integrity_status',v_integrity->>'status',
    'integrity_broken_hashes',(v_integrity->>'broken_hashes')::integer,
    'integrity_broken_links',(v_integrity->>'broken_chain_links')::integer,
    'latest_audit_at',v_integrity->>'latest_audit_at'
  );
end;
$$;
grant execute on function public.security_admin_summary(uuid,uuid) to authenticated;

commit;
