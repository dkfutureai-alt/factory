begin;

-- Phase 31: prevent a serialized *customer-issue attestation* from asserting
-- that an uninspected, quarantined or out-of-test cylinder/Dura was safely
-- released. This does NOT stop generic quantity-only Inventory/Dispatch writes:
-- serial linking remains optional pending a separate full custody migration.
-- The operator must still verify physical pressure tests and local regulations.
create function public.gas_serial_issue_readiness_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_state text;
  v_condition text;
  v_due date;
  v_inspected timestamptz;
  v_org uuid;
  v_factory uuid;
begin
  if new.transaction_type <> 'issue' then
    return new;
  end if;

  -- The parent gas_link_container_transaction RPC already locks the asset
  -- FOR UPDATE, validates actual Inventory ledger posting and completed POD.
  -- This trigger is defense in depth for any future privileged insertion path.
  select a.state, a.condition, a.test_due_on, a.last_inspection_at,
         a.organization_id, a.factory_id
    into v_state, v_condition, v_due, v_inspected, v_org, v_factory
  from public.gas_container_assets a
  where a.id = new.asset_id
  for share;

  if not found or v_org is distinct from new.organization_id
      or v_factory is distinct from new.factory_id then
    raise exception 'Customer issue serial attestation references a different asset scope';
  end if;

  if v_state <> 'inspection_recorded' or v_condition <> 'good'
      or v_inspected is null or v_inspected > now()
      or v_due is null or v_due < current_date then
    raise exception 'Customer issue serial attestation blocked: container inspection or test date is not current';
  end if;

  return new;
end;
$$;

revoke all on function public.gas_serial_issue_readiness_guard()
  from public, anon, authenticated;
drop trigger if exists gas_serial_issue_readiness on public.gas_container_transaction_links;
create trigger gas_serial_issue_readiness
  before insert on public.gas_container_transaction_links
  for each row execute function public.gas_serial_issue_readiness_guard();

commit;
