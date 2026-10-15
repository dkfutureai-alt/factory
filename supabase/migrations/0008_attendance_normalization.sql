begin;

create or replace function public.normalize_attendance_record()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  fac public.factories%rowtype;
  sh public.shifts%rowtype;
  scheduled_start timestamptz;
begin
  if new.status in ('absent','on_leave','holiday','week_off') then
    new.check_in_at := null;
    new.check_out_at := null;
    new.worked_minutes := null;
    new.late_minutes := 0;
    return new;
  end if;

  if new.check_out_at is not null and new.check_in_at is null then
    raise exception 'Check-out requires a check-in time';
  end if;

  if new.check_in_at is not null and new.check_out_at is not null then
    if new.check_out_at < new.check_in_at then
      raise exception 'Check-out cannot be before check-in';
    end if;
    new.worked_minutes := floor(
      extract(epoch from (new.check_out_at - new.check_in_at)) / 60
    )::integer;
  elsif new.check_out_at is null then
    new.worked_minutes := null;
  end if;

  if new.check_in_at is not null and new.shift_id is not null then
    select * into sh from public.shifts where id = new.shift_id;
    select * into fac from public.factories where id = new.factory_id;
    if sh.id is not null and fac.id is not null then
      scheduled_start := (new.work_date + sh.start_time) at time zone fac.timezone;
      new.late_minutes := greatest(
        0,
        floor(extract(epoch from (new.check_in_at - scheduled_start)) / 60)::integer - sh.grace_minutes
      );
    end if;
  else
    new.late_minutes := coalesce(new.late_minutes, 0);
  end if;

  return new;
end;
$$;

create trigger attendance_records_normalize
before insert or update of status, check_in_at, check_out_at, shift_id, work_date
on public.attendance_records
for each row execute function public.normalize_attendance_record();

commit;
