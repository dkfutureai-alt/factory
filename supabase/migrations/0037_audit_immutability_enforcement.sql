begin;

-- Run as the invoking database role so current_user reflects the caller.
-- Authenticated clients already lack UPDATE/DELETE privileges; this trigger is a
-- second independent guard for any future path that might acquire such rights.
create or replace function public.audit_logs_reject_mutation()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  if current_user not in ('postgres','supabase_admin') then
    raise exception 'Audit logs are immutable';
  end if;
  return case when tg_op='DELETE' then old else new end;
end;
$$;
revoke all on function public.audit_logs_reject_mutation() from public;

commit;
