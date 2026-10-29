begin;

-- Phase 33: source-of-truth validation for every serialized Inventory link,
-- including any future trusted-service insertion path. The Phase 21B RPC
-- already validates these fields; the table itself must not accept a claim
-- with different ledger type/item/location/tenant metadata.
--
-- Important: PostgreSQL fires same-event triggers in name order. The prior
-- gas_serial_issue_readiness trigger checks NEW.transaction_type='issue'.
-- This new guard ensures a caller cannot avoid that safety assertion by
-- claiming a different event type than the actual Inventory transaction.
--
-- This guard DOES NOT enforce that all quantity-based movements are scanned,
-- validate customer POD/return custody, or certify container pressure safety.
create function public.gas_serial_link_source_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_asset public.gas_container_assets%rowtype;
  v_tx public.inventory_transactions%rowtype;
  v_count bigint;
begin
  -- Read/lock the asset before the transaction in the same order as the
  -- manager RPC. This avoids cross-path lock inversion during concurrent use.
  select * into v_asset
    from public.gas_container_assets
    where id = new.asset_id
    for share;
  if not found
      or v_asset.organization_id is distinct from new.organization_id
      or v_asset.factory_id is distinct from new.factory_id then
    raise exception 'Serial evidence source mismatch: asset scope';
  end if;

  -- Serialize direct privileged inserts and RPC inserts against the actual
  -- immutable Inventory transaction when checking its whole-unit capacity.
  select * into v_tx
    from public.inventory_transactions
    where id = new.transaction_id
    for update;
  if not found
      or v_tx.organization_id is distinct from new.organization_id
      or v_tx.factory_id is distinct from new.factory_id
      or v_tx.item_id is distinct from v_asset.item_id then
    raise exception 'Serial evidence source mismatch: Inventory scope/item';
  end if;

  if v_tx.transaction_type is distinct from new.transaction_type
      or v_tx.from_location_id is distinct from new.from_location_id
      or v_tx.to_location_id is distinct from new.to_location_id then
    raise exception 'Serial evidence source mismatch: Inventory movement type/locations';
  end if;
  if v_tx.quantity < 1 or v_tx.quantity is distinct from trunc(v_tx.quantity) then
    raise exception 'Serial evidence source mismatch: whole-unit Inventory quantity required';
  end if;

  select count(*) into v_count
    from public.gas_container_transaction_links
    where transaction_id = new.transaction_id;
  if v_count >= v_tx.quantity then
    raise exception 'Serial evidence source mismatch: Inventory quantity already fully attested';
  end if;

  return new;
end;
$$;

revoke all on function public.gas_serial_link_source_guard()
  from public, anon, authenticated;

drop trigger if exists gas_serial_link_source_integrity
  on public.gas_container_transaction_links;
create trigger gas_serial_link_source_integrity
  before insert on public.gas_container_transaction_links
  for each row execute function public.gas_serial_link_source_guard();

commit;
