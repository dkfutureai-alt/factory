-- Run only against isolated local reset database; no production writes.
begin;
do $$
begin
  if has_table_privilege('anon', 'public.mobile_release_policies', 'SELECT') then
    raise exception 'Anonymous direct table read must remain denied';
  end if;
  if not has_function_privilege(
      'anon', 'public.get_mobile_release_policy(text,text)', 'EXECUTE') then
    raise exception 'Public pre-login release RPC missing';
  end if;
  if has_table_privilege('anon', 'public.mobile_release_policies', 'INSERT') or
     has_table_privilege('anon', 'public.mobile_release_policies', 'UPDATE') or
     has_table_privilege('anon', 'public.mobile_release_policies', 'DELETE') then
    raise exception 'Anonymous release policy write grant detected';
  end if;
  if not has_table_privilege('authenticated', 'public.mobile_release_policies', 'SELECT') then
    raise exception 'Authenticated release policy select missing';
  end if;
  if not (select relrowsecurity from pg_class
     where oid = 'public.mobile_release_policies'::regclass) then
    raise exception 'Mobile release RLS missing';
  end if;
  if (select count(*) from pg_policies
      where schemaname = 'public' and tablename = 'mobile_release_policies') < 5 then
    raise exception 'Required read/manage RLS policies missing';
  end if;
end;
$$;
-- Verify the actual public RPC with fictional packages and no tenant data.
insert into public.mobile_release_policies
  (application_id, platform, minimum_version, latest_version, download_url, enabled)
values
  ('com.example.factorydemo', 'android', '1.0.0', '2.0.0', 'https://example.org/factory', true),
  ('com.example.factorydraft', 'android', '1.0.0', '2.0.0', 'https://example.org/factory', false);

set local role anon;

do $
declare
  published jsonb;
begin
  published := public.get_mobile_release_policy('com.example.factorydemo', 'android');
  if published is null or published->>'minimum_version' <> '1.0.0'
     or published ? 'updated_by' or published ? 'application_id' then
    raise exception 'Public DTO leaked fields or lost published policy';
  end if;
  if public.get_mobile_release_policy('com.example.factorydraft', 'android') is not null then
    raise exception 'Draft release policy was exposed';
  end if;
  if public.get_mobile_release_policy('com.example.factorydemo', 'ios') is not null then
    raise exception 'Cross-platform policy was exposed';
  end if;
end;
$;

reset role;
rollback;
