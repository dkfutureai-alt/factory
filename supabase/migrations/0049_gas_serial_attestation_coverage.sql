begin;

-- Phase 21C: report what is NOT yet attested by a physical serial.
-- Read-only, ledger-derived visibility; it neither creates inventory nor
-- claims custody, pressure certification or exhaustive scanned coverage.
create function public.gas_serial_attestation_coverage(
  p_organization_id uuid,
  p_factory_id uuid default null,
  p_limit integer default 200
)
returns table(
  transaction_id uuid,
  factory_id uuid,
  item_id uuid,
  transaction_no text,
  transaction_type text,
  sku text,
  item_name text,
  quantity numeric,
  linked_serial_count bigint,
  unattested_quantity numeric,
  coverage_status text,
  occurred_at timestamptz
)
language plpgsql stable security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_organization_id is null or
    (not public.is_org_member(p_organization_id)
     and not public.is_platform_owner()) then
    raise exception 'Organization access denied';
  end if;
  if p_limit is null or p_limit<1 or p_limit>500 then
    raise exception 'Report limit must be between 1 and 500';
  end if;
  if p_factory_id is not null and not exists(
    select 1 from public.factories f
    where f.id=p_factory_id and f.organization_id=p_organization_id
      and f.is_active and public.can_view_inventory_factory(f.id)
  ) then
    raise exception 'Factory report access denied';
  end if;

  return query
  select t.id,t.factory_id,t.item_id,t.transaction_no,t.transaction_type,
    i.sku,i.name,t.quantity,
    coalesce(l.count_linked,0)::bigint,
    greatest(t.quantity-coalesce(l.count_linked,0),0)::numeric,
    case
      when coalesce(l.count_linked,0)=0 then 'not_attested'
      when coalesce(l.count_linked,0)<t.quantity then 'partially_attested'
      else 'fully_attested'
    end::text,
    t.occurred_at
  from public.inventory_transactions t
  join public.inventory_items i
    on i.id=t.item_id and i.organization_id=t.organization_id
  left join lateral(
    select count(*)::bigint as count_linked
    from public.gas_container_transaction_links x
    where x.transaction_id=t.id and x.organization_id=t.organization_id
  ) l on true
  where t.organization_id=p_organization_id
    and (p_factory_id is null or t.factory_id=p_factory_id)
    and public.can_view_inventory_factory(t.factory_id)
    and (i.item_type='cylinder' or i.is_returnable)
  order by t.occurred_at desc,t.id desc
  limit p_limit;
end; $$;
revoke all on function public.gas_serial_attestation_coverage(uuid,uuid,integer)
from public,anon;
grant execute on function public.gas_serial_attestation_coverage(uuid,uuid,integer)
to authenticated;

commit;
