\set ON_ERROR_STOP on

begin;

do $$
begin
  if to_regclass('public.notification_templates') is null then raise exception 'notification_templates missing'; end if;
  if to_regclass('public.notification_rules') is null then raise exception 'notification_rules missing'; end if;
  if to_regclass('public.notification_preferences') is null then raise exception 'notification_preferences missing'; end if;
  if to_regclass('public.notification_devices') is null then raise exception 'notification_devices missing'; end if;
  if to_regclass('public.notifications') is null then raise exception 'notifications missing'; end if;
  if to_regclass('public.notification_deliveries') is null then raise exception 'notification_deliveries missing'; end if;
  if not exists(select 1 from public.app_modules where key='notifications' and is_active) then raise exception 'notifications module missing'; end if;
  if not exists(select 1 from pg_proc where proname='notification_inbox') then raise exception 'notification_inbox RPC missing'; end if;
  if not exists(select 1 from pg_proc where proname='notification_broadcast') then raise exception 'notification_broadcast RPC missing'; end if;
  if not exists(select 1 from pg_proc where proname='notification_register_device') then raise exception 'notification_register_device RPC missing'; end if;
  if not exists(select 1 from pg_proc where proname='notification_admin_summary') then raise exception 'notification_admin_summary RPC missing'; end if;
  if not exists(select 1 from pg_trigger where tgname='notification_maintenance_work_order' and not tgisinternal) then raise exception 'maintenance notification trigger missing'; end if;
  if not exists(select 1 from pg_trigger where tgname='notification_dispatch_exception' and not tgisinternal) then raise exception 'dispatch exception notification trigger missing'; end if;
  if not exists(select 1 from pg_trigger where tgname='notification_leave_decision' and not tgisinternal) then raise exception 'leave decision notification trigger missing'; end if;
end $$;

do $$
declare t text;
begin
  foreach t in array array['notification_templates','notification_rules','notification_preferences','notification_devices','notifications','notification_deliveries'] loop
    if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=t and c.relrowsecurity) then
      raise exception 'RLS not enabled for %',t;
    end if;
  end loop;
end $$;

do $$
begin
  if has_table_privilege('authenticated','public.notifications','INSERT') or has_table_privilege('authenticated','public.notifications','UPDATE') or has_table_privilege('authenticated','public.notifications','DELETE') then
    raise exception 'authenticated must not mutate notifications directly';
  end if;
  if has_table_privilege('authenticated','public.notification_deliveries','INSERT') or has_table_privilege('authenticated','public.notification_deliveries','UPDATE') or has_table_privilege('authenticated','public.notification_deliveries','DELETE') then
    raise exception 'authenticated must not mutate notification deliveries directly';
  end if;
  if has_table_privilege('authenticated','public.notification_devices','INSERT') or has_table_privilege('authenticated','public.notification_devices','UPDATE') or has_table_privilege('authenticated','public.notification_devices','DELETE') then
    raise exception 'device mutations must use RPCs';
  end if;
end $$;

rollback;
