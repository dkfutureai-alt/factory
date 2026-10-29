begin;

-- Phase 32: pilot acceptance reports use the database's clock, never a
-- client-supplied created_at. Otherwise a reporter can supply future or
-- artificially recent timestamps and defeat the 14-day acceptance gate.
-- The client may still self-report Passed: this is NOT independent proof of
-- completed factory work or a physical-device/customer sign-off.
create function public.stamp_pilot_feedback_created_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.created_at := now();
  return new;
end;
$$;

revoke all on function public.stamp_pilot_feedback_created_at()
  from public, anon, authenticated;

create trigger pilot_feedback_stamp_created_at
before insert on public.pilot_feedback
for each row execute function public.stamp_pilot_feedback_created_at();

commit;
