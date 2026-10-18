begin;

-- Phase 15: make push dispatch safe when two scheduled Edge workers overlap.
-- Processing rows are claimed atomically; abandoned claims can be recovered.
alter table public.notification_deliveries
  add column claimed_at timestamptz,
  add column claim_token uuid;

alter table public.notification_deliveries
  drop constraint notification_deliveries_status_check;

alter table public.notification_deliveries
  add constraint notification_deliveries_status_check
  check (status in ('queued','processing','sent','failed','skipped'));

create index notification_deliveries_processing_lease_idx
  on public.notification_deliveries (claimed_at)
  where channel='push' and status='processing';

create or replace function public.notification_claim_push_deliveries(
  p_batch_size integer default 20
)
returns table (
  id uuid,
  notification_id uuid,
  attempts integer,
  claim_token uuid
)
language sql
volatile
security invoker
set search_path = ''
as $$
  with candidates as materialized (
    select d.id
    from public.notification_deliveries d
    where d.channel='push'
      and d.attempts < 100
      and (
        d.status='queued'
        or (
          d.status='processing'
          and (d.claimed_at is null or d.claimed_at < now() - interval '15 minutes')
        )
      )
    order by d.created_at,d.id
    limit least(greatest(coalesce(p_batch_size,20),1),20)
    for update skip locked
  ),
  claimed as (
    update public.notification_deliveries d
    set status='processing',
        attempts=d.attempts+1,
        claimed_at=now(),
        last_attempt_at=now(),
        claim_token=gen_random_uuid(),
        error_message=null
    from candidates c
    where d.id=c.id
    returning d.id,d.notification_id,d.attempts,d.claim_token
  )
  select c.id,c.notification_id,c.attempts,c.claim_token
  from claimed c;
$$;

-- This worker-only RPC runs with the calling role's rights, never as a
-- SECURITY DEFINER. It must not be available to browser/mobile sessions.
revoke all on function public.notification_claim_push_deliveries(integer)
  from public,anon,authenticated;
grant execute on function public.notification_claim_push_deliveries(integer)
  to service_role;

commit;
