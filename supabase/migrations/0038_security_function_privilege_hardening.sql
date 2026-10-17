begin;

-- Supabase/Postgres functions are executable by PUBLIC by default. Phase 14
-- exposes only the four guarded Admin RPCs to authenticated users and keeps
-- internal SECURITY DEFINER helpers non-public.
revoke all on function public.security_verify_audit_integrity(uuid,uuid,integer) from public, anon;
revoke all on function public.security_admin_summary(uuid,uuid) from public, anon;
revoke all on function public.security_audit_feed(uuid,uuid,integer,text,text,uuid) from public, anon;
revoke all on function public.security_access_review(uuid,uuid) from public, anon;

grant execute on function public.security_verify_audit_integrity(uuid,uuid,integer) to authenticated;
grant execute on function public.security_admin_summary(uuid,uuid) to authenticated;
grant execute on function public.security_audit_feed(uuid,uuid,integer,text,text,uuid) to authenticated;
grant execute on function public.security_access_review(uuid,uuid) to authenticated;

-- Internal policy helpers remain callable only by authenticated policies/users
-- as explicitly granted in 0036. All other internal security helpers are private
-- from PUBLIC and anon.
revoke all on function public.security_enable_for_new_org() from public, anon;
revoke all on function public.audit_logs_prepare_integrity() from public, anon;
revoke all on function public.audit_security_config_change() from public, anon;
revoke all on function public.security_can_view_scope(uuid,uuid) from public, anon;
revoke all on function public.security_audit_integrity_stats(uuid,integer) from public, anon;
revoke all on function public.security_can_view_org_user(uuid,uuid) from public, anon;
revoke all on function public.security_can_view_profile(uuid) from public, anon;

grant execute on function public.security_can_view_org_user(uuid,uuid) to authenticated;
grant execute on function public.security_can_view_profile(uuid) to authenticated;

-- Pin all Phase 14 SECURITY DEFINER functions to an empty search_path. Every
-- project object they access is schema-qualified, while pg_catalog built-ins
-- remain safely resolvable by PostgreSQL.
alter function public.security_enable_for_new_org() set search_path = '';
alter function public.audit_logs_prepare_integrity() set search_path = '';
alter function public.audit_security_config_change() set search_path = '';
alter function public.security_can_view_scope(uuid,uuid) set search_path = '';
alter function public.security_audit_integrity_stats(uuid,integer) set search_path = '';
alter function public.security_verify_audit_integrity(uuid,uuid,integer) set search_path = '';
alter function public.security_admin_summary(uuid,uuid) set search_path = '';
alter function public.security_audit_feed(uuid,uuid,integer,text,text,uuid) set search_path = '';
alter function public.security_access_review(uuid,uuid) set search_path = '';
alter function public.security_can_view_org_user(uuid,uuid) set search_path = '';
alter function public.security_can_view_profile(uuid) set search_path = '';

commit;
