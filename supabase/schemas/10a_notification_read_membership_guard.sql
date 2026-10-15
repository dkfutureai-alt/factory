-- FactoryOS notification read-state authorization hardening.
-- Apply after 10_notifications.sql; do not deploy to janseva-production.
create or replace function public.mark_notification_read(target_recipient_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.notification_recipients r
     set read_at = coalesce(r.read_at, now())
    from public.notifications n
   where r.id = target_recipient_id
     and n.id = r.notification_id
     and r.user_id = (select auth.uid())
     and n.organization_id = r.organization_id
     and private.is_org_member(r.organization_id);
  if not found then
    raise exception 'Notification recipient not found or not authorized';
  end if;
end;
$$;
revoke all on function public.mark_notification_read(uuid) from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;
