-- Phase 18: Supabase 2026 explicit Data API privileges and RLS defense.
-- These checks run after all committed migrations, with the real role catalog.
begin;

do $$
declare
  table_name text;
  t text;
  s text;
begin
  -- No anonymous role may read or mutate any FactoryOS public table.
  for table_name in
    select c.relname from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p')
  loop
    t := format('public.%I',table_name);
    if has_table_privilege('anon',t,'select')
       or has_table_privilege('anon',t,'insert')
       or has_table_privilege('anon',t,'update')
       or has_table_privilege('anon',t,'delete') then
      raise exception 'Unexpected anonymous Data API access to %', t;
    end if;
    if not (select c.relrowsecurity from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
            where n.nspname='public' and c.relname=table_name
            and c.relkind in ('r','p')) then
      raise exception 'FactoryOS public table lacks RLS: %', t;
    end if;
    if not has_table_privilege('service_role',t,'select')
       or not has_table_privilege('service_role',t,'insert')
       or not has_table_privilege('service_role',t,'update')
       or not has_table_privilege('service_role',t,'delete') then
      raise exception 'FactoryOS service role cannot operate on %', t;
    end if;
  end loop;

  foreach table_name in array array[
    'organizations','profiles'
  ] loop
    t := format('public.%I',table_name);
    if not has_table_privilege('authenticated',t,'select')
       or not has_table_privilege('authenticated',t,'update')
       or has_table_privilege('authenticated',t,'insert')
       or has_table_privilege('authenticated',t,'delete') then
      raise exception 'Foundation read/update grant mismatch for %', t;
    end if;
  end loop;

  foreach table_name in array array[
    'factories','organization_members','factory_members','organization_modules'
  ] loop
    t := format('public.%I',table_name);
    if not has_table_privilege('authenticated',t,'select')
       or not has_table_privilege('authenticated',t,'insert')
       or not has_table_privilege('authenticated',t,'update')
       or not has_table_privilege('authenticated',t,'delete') then
      raise exception 'Foundation managed table grant mismatch for %', t;
    end if;
  end loop;

  foreach table_name in array array['app_modules','audit_logs'] loop
    t := format('public.%I',table_name);
    if not has_table_privilege('authenticated',t,'select')
       or has_table_privilege('authenticated',t,'insert')
       or has_table_privilege('authenticated',t,'update')
       or has_table_privilege('authenticated',t,'delete') then
      raise exception 'Foundation read-only grant mismatch for %', t;
    end if;
  end loop;

  -- This must remain a strictly authenticated-only pilot.
  foreach table_name in array array['pilot_participants','pilot_feedback'] loop
    t := format('public.%I',table_name);
    if not has_table_privilege('authenticated',t,'select')
       or not has_table_privilege('authenticated',t,'insert') then
      raise exception 'Pilot access lost with the privilege hardening: %', t;
    end if;
  end loop;
end $$;

rollback;
select 'FactoryOS explicit API grants and public RLS passed' as result;
