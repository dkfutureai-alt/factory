begin;

-- Factory metadata is security-sensitive because names, locations and codes are
-- used by every application shell. Factory-scoped roles must not inherit the
-- old organization-wide visibility policy.
do $$
declare
  policy_qual text;
begin
  select qual
    into policy_qual
  from pg_policies
  where schemaname = 'public'
    and tablename = 'factories'
    and policyname = 'factories_select';

  if policy_qual is null then
    raise exception 'factories_select policy is missing';
  end if;

  if policy_qual ilike '%is_org_member%' then
    raise exception 'factories_select must not grant organization-wide visibility to every member';
  end if;

  if policy_qual not ilike '%factory_members%' then
    raise exception 'factories_select must require a factory assignment for scoped roles';
  end if;

  if policy_qual not ilike '%org_admin%' then
    raise exception 'factories_select must preserve organization admin visibility';
  end if;
end
$$;

rollback;
