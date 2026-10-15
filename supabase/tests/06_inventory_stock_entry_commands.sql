\set ON_ERROR_STOP on

-- Inventory Stock Entry command regression tests.
-- Depends on 01_rbac_scope_security.sql creating deterministic auth users/role assignments.
-- Commands run as authenticated scoped users. Structural assertions intentionally reset
-- to the CI database owner so RLS does not hide rows that the command has already created.

-- Capture known target/sibling scope IDs before switching to an RLS-constrained actor.
select set_config(
  'factoryos.test.fg_wh_id',
  (select id::text from public.warehouses where code='FG-WH'),
  false
);
select set_config(
  'factoryos.test.fg_loc_id',
  (select wl.id::text
   from public.warehouse_locations wl
   join public.warehouses w on w.id=wl.warehouse_id
   where w.code='FG-WH' and wl.code='FG-A-R01-B08'),
  false
);
select set_config(
  'factoryos.test.rm_wh_id',
  (select id::text from public.warehouses where code='RM-WH'),
  false
);
select set_config(
  'factoryos.test.rm_loc_id',
  (select wl.id::text
   from public.warehouse_locations wl
   join public.warehouses w on w.id=wl.warehouse_id
   where w.code='RM-WH' and wl.code='RM-A-R03-B02'),
  false
);
select set_config(
  'factoryos.test.pk_carton_id',
  (select id::text from public.items where sku='PK-CARTON-014'),
  false
);

-- CI-only serial-tracked fixture. Production/demo seed intentionally remains free of fake serial stock.
insert into public.items(
  organization_id, category_id, unit_id, sku, name, cost, minimum_stock, reorder_level,
  batch_tracking, serial_tracking, status
)
select o.id, c.id, u.id, 'CI-SERIAL-001', 'CI Serial Controlled Item', 100, 0, 0,
       false, true, 'active'
from public.organizations o
join public.item_categories c on c.organization_id=o.id and c.code='SPARE'
join public.item_units u on u.organization_id=o.id and u.code='PCS'
where o.code='DKIM'
on conflict (organization_id,sku) do update set serial_tracking=true,batch_tracking=false,status='active';

insert into public.serial_numbers(organization_id,item_id,serial_number,status)
select o.id,i.id,'CI-SERIAL-0001','issued'
from public.organizations o
join public.items i on i.organization_id=o.id and i.sku='CI-SERIAL-001'
where o.code='DKIM'
on conflict (organization_id,item_id,serial_number) do update
set current_warehouse_id=null,current_location_id=null,status='issued';

-- Warehouse-scoped manager may adjust only the assigned RM-WH and only through posted ledger.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;

select public.post_manual_stock_adjustment(
  (select id from public.warehouses where code='RM-WH'),
  (select wl.id from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id where w.code='RM-WH' and wl.code='RM-A-R03-B02'),
  (select id from public.items where sku='PK-CARTON-014'),
  null,
  null,
  25,
  22,
  'CI approved physical count correction',
  'ci-stock-entry-in-pk-carton'
) as posted_adjustment \gset stock_in_

select (
  (:'stock_in_posted_adjustment')::text like '%posted%'
) as ok \gset stock_in_result_
\if :stock_in_result_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: authorized stock-in did not return posted transaction'
  select 1/0;
\endif

reset role;

select (count(*)=1) as ok
from public.stock_transactions st
join public.stock_transaction_lines l on l.stock_transaction_id=st.id
join public.items i on i.id=l.item_id
join public.warehouses w on w.id=l.warehouse_id
where st.idempotency_key='ci-stock-entry-in-pk-carton'
  and st.status='posted'
  and st.transaction_type='adjustment'
  and st.reference_type='manual_stock_adjustment'
  and i.sku='PK-CARTON-014'
  and w.code='RM-WH'
  and l.quantity_delta=25 \gset posted_line_
\if :posted_line_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: stock-in ledger line is incorrect'
  select 1/0;
\endif

-- Same idempotency key + same payload must be replay-safe and create no duplicate transaction/line.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
select public.post_manual_stock_adjustment(
  (select id from public.warehouses where code='RM-WH'),
  (select wl.id from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id where w.code='RM-WH' and wl.code='RM-A-R03-B02'),
  (select id from public.items where sku='PK-CARTON-014'),
  null,null,25,22,'CI approved physical count correction','ci-stock-entry-in-pk-carton'
);
reset role;

select (count(*)=1) as ok from public.stock_transactions where idempotency_key='ci-stock-entry-in-pk-carton' \gset replay_tx_
\if :replay_tx_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: idempotent replay duplicated transaction'
  select 1/0;
\endif
select (count(*)=1) as ok
from public.stock_transaction_lines l
join public.stock_transactions st on st.id=l.stock_transaction_id
where st.idempotency_key='ci-stock-entry-in-pk-carton' \gset replay_line_
\if :replay_line_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: idempotent replay duplicated ledger line'
  select 1/0;
\endif

-- Permission and validation failures run as the scoped warehouse manager.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;

-- A warehouse-scoped user cannot adjust a sibling warehouse even when the UUID is already known.
do $$
declare denied boolean:=false;
begin
  begin
    perform public.post_manual_stock_adjustment(
      current_setting('factoryos.test.fg_wh_id')::uuid,
      current_setting('factoryos.test.fg_loc_id')::uuid,
      (select id from public.items where sku='PK-CARTON-014'),
      null,null,5,22,'CI cross warehouse attempt','ci-stock-entry-cross-wh'
    );
  exception when others then
    denied := position('stock adjustment permission denied' in sqlerrm)>0;
  end;
  if not denied then raise exception 'INVENTORY STOCK ENTRY TEST: known sibling warehouse UUID was not denied'; end if;
end
$$;

-- Batch-tracked item cannot be adjusted without a batch.
do $$
declare denied boolean:=false;
begin
  begin
    perform public.post_manual_stock_adjustment(
      (select id from public.warehouses where code='RM-WH'),
      (select wl.id from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id where w.code='RM-WH' and wl.code='RM-A-R03-B02'),
      (select id from public.items where sku='RM-STEEL-001'),
      null,null,10,72.5,'CI missing batch attempt','ci-stock-entry-missing-batch'
    );
  exception when others then
    denied := position('batch-tracked item requires batch' in sqlerrm)>0;
  end;
  if not denied then raise exception 'INVENTORY STOCK ENTRY TEST: missing batch was not denied'; end if;
end
$$;

-- Oversized stock-out must be rejected by the immutable ledger projected-balance guard.
do $$
declare denied boolean:=false;
begin
  begin
    perform public.post_manual_stock_adjustment(
      (select id from public.warehouses where code='RM-WH'),
      (select wl.id from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id where w.code='RM-WH' and wl.code='RM-A-R03-B02'),
      (select id from public.items where sku='PK-CARTON-014'),
      null,null,-999999,22,'CI impossible stock out','ci-stock-entry-negative-guard'
    );
  exception when others then
    denied := position('insufficient inventory' in sqlerrm)>0;
  end;
  if not denied then raise exception 'INVENTORY STOCK ENTRY TEST: negative stock was not denied'; end if;
end
$$;
reset role;

select (count(*)=0) as ok from public.stock_transactions where idempotency_key='ci-stock-entry-negative-guard' \gset negative_rollback_
\if :negative_rollback_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: failed stock-out left transaction side effects'
  select 1/0;
\endif

-- Serial Stock In: exactly +1, ledger-backed, then serial metadata follows warehouse/location.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
select public.post_manual_stock_adjustment(
  (select id from public.warehouses where code='RM-WH'),
  (select wl.id from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id where w.code='RM-WH' and wl.code='RM-A-R03-B02'),
  (select id from public.items where sku='CI-SERIAL-001'),
  null,
  (select sn.id from public.serial_numbers sn join public.items i on i.id=sn.item_id where i.sku='CI-SERIAL-001' and sn.serial_number='CI-SERIAL-0001'),
  1,100,'CI serial stock in','ci-stock-entry-serial-in'
);
reset role;

select (
  sn.status='available'
  and w.code='RM-WH'
  and wl.code='RM-A-R03-B02'
) as ok
from public.serial_numbers sn
join public.items i on i.id=sn.item_id
left join public.warehouses w on w.id=sn.current_warehouse_id
left join public.warehouse_locations wl on wl.id=sn.current_location_id
where i.sku='CI-SERIAL-001' and sn.serial_number='CI-SERIAL-0001' \gset serial_in_
\if :serial_in_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: serial Stock In metadata did not reconcile'
  select 1/0;
\endif

-- Duplicate positive adjustment for a serial already in stock is forbidden.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin
    perform public.post_manual_stock_adjustment(
      (select id from public.warehouses where code='RM-WH'),
      (select wl.id from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id where w.code='RM-WH' and wl.code='RM-A-R03-B02'),
      (select id from public.items where sku='CI-SERIAL-001'),
      null,
      (select sn.id from public.serial_numbers sn join public.items i on i.id=sn.item_id where i.sku='CI-SERIAL-001' and sn.serial_number='CI-SERIAL-0001'),
      1,100,'CI duplicate serial in','ci-stock-entry-serial-duplicate'
    );
  exception when others then
    denied := position('serial number is already in stock' in sqlerrm)>0;
  end;
  if not denied then raise exception 'INVENTORY STOCK ENTRY TEST: duplicate serial Stock In was not denied'; end if;
end
$$;

-- Serial Stock Out: exactly -1 and serial metadata leaves the warehouse only after posting.
select public.post_manual_stock_adjustment(
  (select id from public.warehouses where code='RM-WH'),
  (select wl.id from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id where w.code='RM-WH' and wl.code='RM-A-R03-B02'),
  (select id from public.items where sku='CI-SERIAL-001'),
  null,
  (select sn.id from public.serial_numbers sn join public.items i on i.id=sn.item_id where i.sku='CI-SERIAL-001' and sn.serial_number='CI-SERIAL-0001'),
  -1,100,'CI serial stock out','ci-stock-entry-serial-out'
);
reset role;

select (sn.status='issued' and sn.current_warehouse_id is null and sn.current_location_id is null) as ok
from public.serial_numbers sn join public.items i on i.id=sn.item_id
where i.sku='CI-SERIAL-001' and sn.serial_number='CI-SERIAL-0001' \gset serial_out_
\if :serial_out_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: serial Stock Out metadata did not reconcile'
  select 1/0;
\endif
select (coalesce(sum(quantity_on_hand),0)=0) as ok
from public.inventory_balances b
join public.items i on i.id=b.item_id
where i.sku='CI-SERIAL-001' \gset serial_balance_
\if :serial_balance_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: serial ledger did not return to zero'
  select 1/0;
\endif

-- Production-department user has no inventory.adjust and cannot use manual Stock Entry even with known valid UUIDs.
select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-000000000004',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin
    perform public.post_manual_stock_adjustment(
      current_setting('factoryos.test.rm_wh_id')::uuid,
      current_setting('factoryos.test.rm_loc_id')::uuid,
      current_setting('factoryos.test.pk_carton_id')::uuid,
      null,null,1,22,'CI unauthorized role attempt','ci-stock-entry-unauthorized-role'
    );
  exception when others then
    denied := position('stock adjustment permission denied' in sqlerrm)>0;
  end;
  if not denied then raise exception 'INVENTORY STOCK ENTRY TEST: role without inventory.adjust was not denied'; end if;
end
$$;
reset role;

-- Audit trail exists for successful manual adjustments.
select (count(*)>=3) as ok
from public.audit_logs
where entity_type='stock_transaction'
  and metadata->>'source'='manual_stock_entry' \gset audit_rows_
\if :audit_rows_ok
\else
  \echo 'INVENTORY STOCK ENTRY TEST FAILED: manual adjustments were not audited'
  select 1/0;
\endif