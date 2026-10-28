begin;

-- Phase 21C: factory-scoped, read-only ledger-to-serial evidence coverage.
-- A 'complete' count means every quantity unit has a *recorded attestation*,
-- not that the actual container location, certification or custody is proven.
create function public.gas_serial_transaction_coverage(
  p_factory_id uuid,
  p_limit integer default 100,
  p_missing_only boolean default false
)
returns table (
  transaction_id uuid,
  transaction_no text,
  item_id uuid,
  item_sku text,
  transaction_type text,
  posted_quantity numeric,
  linked_serial_count bigint,
  unlinked_quantity numeric,
  coverage_status text,
  occurred_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_factory_id is null or not public.can_view_inventory_factory(p_factory_id) then
    raise exception 'Factory access denied';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 200 then
    raise exception 'Limit must be between 1 and 200';
  end if;
  if p_missing_only is null then
    raise exception 'Missing-only filter must be specified';
  end if;

  return query
  with candidate as (
    select
      tx.id,
      tx.transaction_no as number,
      tx.item_id as inventory_item_id,
      it.sku as inventory_sku,
      tx.transaction_type as movement_type,
      tx.quantity as qty,
      tx.occurred_at as movement_at,
      coalesce(links.n,0)::bigint as serials
    from public.inventory_transactions tx
    join public.inventory_items it
      on it.id=tx.item_id and it.organization_id=tx.organization_id
    left join lateral (
      select count(*)::bigint as n
      from public.gas_container_transaction_links gl
      where gl.transaction_id=tx.id and gl.organization_id=tx.organization_id
        and gl.factory_id=tx.factory_id
    ) links on true
    where tx.factory_id=p_factory_id
      and (it.item_type='cylinder' or it.is_returnable)
  )
  select c.id,c.number,c.inventory_item_id,c.inventory_sku,c.movement_type,
         c.qty,c.serials,
         greatest(c.qty-c.serials,0)::numeric,
         case
           when c.serials>c.qty then 'overlinked'
           when c.serials=c.qty then 'complete'
           when c.serials=0 then 'missing'
           else 'partial'
         end::text,
         c.movement_at
  from candidate c
  where not p_missing_only or c.serials<>c.qty
  order by c.movement_at desc,c.id desc
  limit p_limit;
end;
$$;

revoke all on function public.gas_serial_transaction_coverage(uuid,integer,boolean)
  from public,anon;
grant execute on function public.gas_serial_transaction_coverage(uuid,integer,boolean)
  to authenticated;

commit;
