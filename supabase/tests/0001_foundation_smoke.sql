-- Run after migrations in a disposable/local database.
-- These are structural smoke assertions and intentionally do not require auth fixtures.

do $$
begin
  if to_regclass('public.organizations') is null then
    raise exception 'organizations table missing';
  end if;
  if to_regclass('public.factories') is null then
    raise exception 'factories table missing';
  end if;
  if to_regclass('public.organization_members') is null then
    raise exception 'organization_members table missing';
  end if;
  if to_regclass('public.factory_members') is null then
    raise exception 'factory_members table missing';
  end if;
  if to_regclass('public.audit_logs') is null then
    raise exception 'audit_logs table missing';
  end if;
end $$;

do $$
declare
  missing_rls text;
begin
  select string_agg(c.relname, ', ')
  into missing_rls
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'organizations','factories','profiles','organization_members','factory_members',
      'app_modules','organization_modules','audit_logs'
    )
    and c.relrowsecurity is false;

  if missing_rls is not null then
    raise exception 'RLS disabled on: %', missing_rls;
  end if;
end $$;

select 'foundation smoke checks passed' as result;
