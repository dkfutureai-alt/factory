begin;
-- Expired pending/sent invitations still occupy the partial unique active-email index.
-- Service role only; scoped by organization and normalized email.
create or replace function public.expire_stale_user_invitations(p_organization_id uuid, p_email text)
returns integer language plpgsql security invoker set search_path = '' as $$
declare v_expired integer;
begin
  update public.user_invitations
  set status='expired'
  where organization_id=p_organization_id and lower(email)=lower(btrim(p_email))
    and status in ('pending','sent') and expires_at<=now();
  get diagnostics v_expired=row_count;
  return v_expired;
end; $$;
revoke all on function public.expire_stale_user_invitations(uuid,text) from public;
revoke all on function public.expire_stale_user_invitations(uuid,text) from anon, authenticated;
grant execute on function public.expire_stale_user_invitations(uuid,text) to service_role;
commit;
