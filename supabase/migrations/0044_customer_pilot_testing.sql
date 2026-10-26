begin;

-- Phase 17: consent-based, tenant-scoped real customer pilot testing.
-- No synthetic customer accounts or production seed rows are created.
create table public.pilot_participants (
  organization_id uuid not null,
  user_id uuid not null,
  consented_at timestamptz not null default now(),
  primary key (organization_id, user_id),
  foreign key (organization_id, user_id)
    references public.organization_members (organization_id, user_id) on delete cascade
);

create table public.pilot_feedback (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  user_id uuid not null,
  scenario text not null check (scenario in (
    'onboarding','hr','inventory','production','quality','purchasing','sales',
    'warehouse','fleet','delivery','maintenance','reports','notifications','security'
  )),
  result text not null check (result in ('passed','failed','blocked')),
  notes text not null default '' check (char_length(notes) <= 1000),
  created_at timestamptz not null default now(),
  foreign key (organization_id, user_id)
    references public.pilot_participants (organization_id, user_id) on delete cascade
);

create index pilot_feedback_participant_fk_idx on public.pilot_feedback (organization_id, user_id);
create index pilot_feedback_org_recent_idx on public.pilot_feedback (organization_id, created_at desc);
create index pilot_feedback_user_recent_idx on public.pilot_feedback (user_id, created_at desc);

-- Database owns the consent timestamp: clients cannot claim an older acceptance.
create or replace function public.stamp_pilot_consent()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  new.consented_at := now();
  return new;
end; $$;
revoke all on function public.stamp_pilot_consent() from public;
create trigger pilot_participants_stamp_consent before insert on public.pilot_participants
for each row execute function public.stamp_pilot_consent();

alter table public.pilot_participants enable row level security;
alter table public.pilot_feedback enable row level security;

revoke all on public.pilot_participants, public.pilot_feedback from anon, authenticated;
grant select, insert, delete on public.pilot_participants to authenticated;
grant select, insert on public.pilot_feedback to authenticated;

-- Only the member can opt in. Admins can observe, never opt another person in.
create policy pilot_participants_read on public.pilot_participants
for select to authenticated
using (
  (user_id = (select auth.uid()) and public.is_org_member(organization_id))
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
);
create policy pilot_participants_join on public.pilot_participants
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.organization_members member
    where member.organization_id = pilot_participants.organization_id
      and member.user_id = (select auth.uid())
      and member.is_active
  )
);
-- Withdrawal removes participation and cascades all related feedback.
create policy pilot_participants_withdraw on public.pilot_participants
for delete to authenticated
using (user_id = (select auth.uid()));

-- Only a consented, currently active member can submit a report for self.
create policy pilot_feedback_read on public.pilot_feedback
for select to authenticated
using (
  (user_id = (select auth.uid()) and public.is_org_member(organization_id))
  or public.has_org_role(organization_id, array['org_admin']::public.app_role[])
);
create policy pilot_feedback_report on public.pilot_feedback
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.organization_members member
    where member.organization_id = pilot_feedback.organization_id
      and member.user_id = (select auth.uid())
      and member.is_active
  )
  and exists (
    select 1 from public.pilot_participants participant
    where participant.organization_id = pilot_feedback.organization_id
      and participant.user_id = (select auth.uid())
  )
);

commit;
