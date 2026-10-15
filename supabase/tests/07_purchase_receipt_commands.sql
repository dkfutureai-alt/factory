\set ON_ERROR_STOP on

-- Purchase GRN / Goods Receipt regression tests.
-- Depends on deterministic users and role assignments from 01_rbac_scope_security.sql.

-- CI-only serial item; demo data remains fictional and unchanged.
insert into public.items(
  organization_id,category_id,unit_id,sku,name,cost,minimum_stock,reorder_level,
  batch_tracking,serial_tracking,status
)
select o.id,c.id,u.id,'CI-GRN-SERIAL-001','CI GRN Serial Item',250,0,0,false,true,'active'
from public.organizations o
join public.item_categories c on c.organization_id=o.id and c.code='SPARE'
join public.item_units u on u.organization_id=o.id and u.code='PCS'
where o.code='DKIM'
on conflict (organization_id,sku) do update
set serial_tracking=true,batch_tracking=false,status='active';

-- Real PO lifecycle: draft -> add immutable commercial lines -> approve -> receive.
insert into public.purchase_orders(
  organization_id,factory_id,supplier_id,order_number,order_date,expected_delivery_date,status,payment_terms
)
select o.id,f.id,s.id,'PO-CI-GRN-001',current_date,current_date+2,'draft','CI receipt terms'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.suppliers s on s.organization_id=o.id and s.code='SUP-METALS'
where o.code='DKIM'
on conflict (organization_id,order_number) do nothing;

insert into public.purchase_order_lines(
  organization_id,purchase_order_id,item_id,ordered_quantity,unit_price,tax_rate
)
select o.id,po.id,i.id,v.qty,v.price,18
from public.organizations o
join public.purchase_orders po on po.organization_id=o.id and po.order_number='PO-CI-GRN-001'
cross join (values
  ('RM-STL-304-02',9::numeric,198::numeric),
  ('PK-CARTON-014',20::numeric,22::numeric),
  ('CI-GRN-SERIAL-001',2::numeric,250::numeric)
) v(sku,qty,price)
join public.items i on i.organization_id=o.id and i.sku=v.sku
where o.code='DKIM'
on conflict (purchase_order_id,item_id) do nothing;

update public.purchase_orders
set status='approved',approved_at=now()
where order_number='PO-CI-GRN-001' and status='draft';

-- Capture exact IDs before RLS-constrained execution.
select set_config('factoryos.grn.po_id',(select id::text from public.purchase_orders where order_number='PO-CI-GRN-001'),false);
select set_config('factoryos.grn.rm_wh_id',(select id::text from public.warehouses where code='RM-WH'),false);
select set_config('factoryos.grn.fg_wh_id',(select id::text from public.warehouses where code='FG-WH'),false);
select set_config('factoryos.grn.batch_pol_id',(
  select pol.id::text from public.purchase_order_lines pol join public.items i on i.id=pol.item_id
  join public.purchase_orders po on po.id=pol.purchase_order_id
  where po.order_number='PO-CI-GRN-001' and i.sku='RM-STL-304-02'),false);
select set_config('factoryos.grn.carton_pol_id',(
  select pol.id::text from public.purchase_order_lines pol join public.items i on i.id=pol.item_id
  join public.purchase_orders po on po.id=pol.purchase_order_id
  where po.order_number='PO-CI-GRN-001' and i.sku='PK-CARTON-014'),false);
select set_config('factoryos.grn.serial_pol_id',(
  select pol.id::text from public.purchase_order_lines pol join public.items i on i.id=pol.item_id
  join public.purchase_orders po on po.id=pol.purchase_order_id
  where po.order_number='PO-CI-GRN-001' and i.sku='CI-GRN-SERIAL-001'),false);
select set_config('factoryos.grn.batch_loc_id',(
  select wl.id::text from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id
  where w.code='RM-WH' and wl.code='RM-A-R03-B02'),false);
select set_config('factoryos.grn.carton_loc_id',(
  select wl.id::text from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id
  where w.code='RM-WH' and wl.code='RM-B-R01-B04'),false);

-- Warehouse Manager posts one GRN. One batch unit is rejected, so it must never enter stock.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
select public.post_purchase_goods_receipt(
  current_setting('factoryos.grn.po_id')::uuid,
  current_setting('factoryos.grn.rm_wh_id')::uuid,
  'CI-INV-GRN-001','CI-DN-GRN-001','CI atomic receiving regression',
  jsonb_build_array(
    jsonb_build_object(
      'purchase_order_line_id',current_setting('factoryos.grn.batch_pol_id'),
      'received_quantity',10,'accepted_quantity',9,'rejected_quantity',1,
      'supplier_batch_number','CI-SUP-BATCH-001',
      'allocations',jsonb_build_array(jsonb_build_object(
        'location_id',current_setting('factoryos.grn.batch_loc_id'),
        'batch_number','CI-GRN-BATCH-001','quantity',9
      ))
    ),
    jsonb_build_object(
      'purchase_order_line_id',current_setting('factoryos.grn.carton_pol_id'),
      'received_quantity',20,'accepted_quantity',20,'rejected_quantity',0,
      'allocations',jsonb_build_array(jsonb_build_object(
        'location_id',current_setting('factoryos.grn.carton_loc_id'),'quantity',20
      ))
    ),
    jsonb_build_object(
      'purchase_order_line_id',current_setting('factoryos.grn.serial_pol_id'),
      'received_quantity',2,'accepted_quantity',2,'rejected_quantity',0,
      'allocations',jsonb_build_array(
        jsonb_build_object('location_id',current_setting('factoryos.grn.carton_loc_id'),'serial_number','CI-GRN-SERIAL-A','quantity',1),
        jsonb_build_object('location_id',current_setting('factoryos.grn.carton_loc_id'),'serial_number','CI-GRN-SERIAL-B','quantity',1)
      )
    )
  ),
  'ci-purchase-grn-001'
);
reset role;

select (count(*)=1) as ok
from public.goods_receipts gr
join public.stock_transactions st on st.id=gr.stock_transaction_id
where gr.purchase_order_id=current_setting('factoryos.grn.po_id')::uuid
  and gr.status='posted'
  and gr.supplier_invoice_number='CI-INV-GRN-001'
  and st.transaction_type='purchase_receipt'
  and st.status='posted'
  and st.reference_type='goods_receipt'
  and st.idempotency_key='ci-purchase-grn-001' \gset header_
\if :header_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: finalized GRN/ledger header missing'
  select 1/0;
\endif

-- Accepted only: 9 batch + 20 carton + 2 serial = 31. Rejected quantity has no stock effect.
select (coalesce(sum(l.quantity_delta),0)=31) as ok
from public.stock_transaction_lines l
join public.stock_transactions st on st.id=l.stock_transaction_id
where st.idempotency_key='ci-purchase-grn-001' \gset accepted_only_
\if :accepted_only_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: rejected quantity affected inventory'
  select 1/0;
\endif

select (count(*)=1) as ok
from public.stock_transaction_lines l
join public.stock_transactions st on st.id=l.stock_transaction_id
join public.batches b on b.id=l.batch_id
join public.items i on i.id=l.item_id
where st.idempotency_key='ci-purchase-grn-001'
  and i.sku='RM-STL-304-02'
  and b.batch_number='CI-GRN-BATCH-001'
  and b.supplier_batch_number='CI-SUP-BATCH-001'
  and l.quantity_delta=9 \gset batch_
\if :batch_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: batch allocation incorrect'
  select 1/0;
\endif

select (count(*)=2 and min(l.quantity_delta)=1 and max(l.quantity_delta)=1) as ok
from public.stock_transaction_lines l
join public.stock_transactions st on st.id=l.stock_transaction_id
join public.items i on i.id=l.item_id
where st.idempotency_key='ci-purchase-grn-001' and i.sku='CI-GRN-SERIAL-001' \gset serial_lines_
\if :serial_lines_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: serial ledger allocation incorrect'
  select 1/0;
\endif

select (count(*)=2) as ok
from public.serial_numbers s
join public.items i on i.id=s.item_id
where i.sku='CI-GRN-SERIAL-001'
  and s.serial_number in ('CI-GRN-SERIAL-A','CI-GRN-SERIAL-B')
  and s.current_warehouse_id=current_setting('factoryos.grn.rm_wh_id')::uuid
  and s.current_location_id=current_setting('factoryos.grn.carton_loc_id')::uuid
  and s.status='available' \gset serial_meta_
\if :serial_meta_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: serial metadata not reconciled'
  select 1/0;
\endif

select (status='received') as ok
from public.purchase_orders where id=current_setting('factoryos.grn.po_id')::uuid \gset po_status_
\if :po_status_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: fully received PO did not close'
  select 1/0;
\endif

-- Retry after PO closure must return the prior GRN and never double-receive.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
select public.post_purchase_goods_receipt(
  current_setting('factoryos.grn.po_id')::uuid,
  current_setting('factoryos.grn.rm_wh_id')::uuid,
  'CI-INV-GRN-001','CI-DN-GRN-001','CI retry after PO closure',
  '[]'::jsonb,'ci-purchase-grn-001'
);
reset role;
select (count(*)=1) as ok from public.stock_transactions where idempotency_key='ci-purchase-grn-001' \gset replay_
\if :replay_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: idempotent replay duplicated stock transaction'
  select 1/0;
\endif

-- Same idempotency key with changed invoice is a conflict.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin
    perform public.post_purchase_goods_receipt(
      current_setting('factoryos.grn.po_id')::uuid,
      current_setting('factoryos.grn.rm_wh_id')::uuid,
      'CI-INV-CONFLICT','CI-DN-GRN-001','conflict','[]'::jsonb,'ci-purchase-grn-001'
    );
  exception when others then
    denied := position('purchase receipt idempotency key conflict' in sqlerrm)>0;
  end;
  if not denied then raise exception 'PURCHASE GRN TEST: conflicting idempotent retry was not denied'; end if;
end
$$;
reset role;

-- Cross-warehouse denial fixture: draft -> line -> approve.
insert into public.purchase_orders(organization_id,factory_id,supplier_id,order_number,status)
select o.id,f.id,s.id,'PO-CI-GRN-DENY','draft'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.suppliers s on s.organization_id=o.id and s.code='SUP-PACK'
where o.code='DKIM'
on conflict (organization_id,order_number) do nothing;
insert into public.purchase_order_lines(organization_id,purchase_order_id,item_id,ordered_quantity,unit_price)
select o.id,po.id,i.id,5,22
from public.organizations o
join public.purchase_orders po on po.organization_id=o.id and po.order_number='PO-CI-GRN-DENY'
join public.items i on i.organization_id=o.id and i.sku='PK-CARTON-014'
where o.code='DKIM'
on conflict (purchase_order_id,item_id) do nothing;
update public.purchase_orders set status='approved',approved_at=now()
where order_number='PO-CI-GRN-DENY' and status='draft';
select set_config('factoryos.grn.deny_po_id',(select id::text from public.purchase_orders where order_number='PO-CI-GRN-DENY'),false);
select set_config('factoryos.grn.deny_pol_id',(
  select pol.id::text from public.purchase_order_lines pol join public.purchase_orders po on po.id=pol.purchase_order_id
  where po.order_number='PO-CI-GRN-DENY'),false);
select set_config('factoryos.grn.fg_loc_id',(
  select wl.id::text from public.warehouse_locations wl join public.warehouses w on w.id=wl.warehouse_id
  where w.code='FG-WH' order by wl.code limit 1),false);

select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin
    perform public.post_purchase_goods_receipt(
      current_setting('factoryos.grn.deny_po_id')::uuid,
      current_setting('factoryos.grn.fg_wh_id')::uuid,
      'CI-DENY',null,'cross warehouse deny',
      jsonb_build_array(jsonb_build_object(
        'purchase_order_line_id',current_setting('factoryos.grn.deny_pol_id'),
        'received_quantity',5,'accepted_quantity',5,'rejected_quantity',0,
        'allocations',jsonb_build_array(jsonb_build_object('location_id',current_setting('factoryos.grn.fg_loc_id'),'quantity',5))
      )),
      'ci-purchase-grn-deny'
    );
  exception when others then
    denied := position('purchase receipt permission denied' in sqlerrm)>0
              or position('inventory posting permission denied' in sqlerrm)>0;
  end;
  if not denied then raise exception 'PURCHASE GRN TEST: sibling warehouse was not denied'; end if;
end
$$;
reset role;
select (count(*)=0) as ok from public.stock_transactions where idempotency_key='ci-purchase-grn-deny' \gset denied_rollback_
\if :denied_rollback_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: denied receipt left ledger side effect'
  select 1/0;
\endif

-- Over-receipt fixture: draft -> line -> approve, then request more accepted quantity than ordered.
insert into public.purchase_orders(organization_id,factory_id,supplier_id,order_number,status)
select o.id,f.id,s.id,'PO-CI-GRN-OVER','draft'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.suppliers s on s.organization_id=o.id and s.code='SUP-PACK'
where o.code='DKIM'
on conflict (organization_id,order_number) do nothing;
insert into public.purchase_order_lines(organization_id,purchase_order_id,item_id,ordered_quantity,unit_price)
select o.id,po.id,i.id,5,22
from public.organizations o
join public.purchase_orders po on po.organization_id=o.id and po.order_number='PO-CI-GRN-OVER'
join public.items i on i.organization_id=o.id and i.sku='PK-CARTON-014'
where o.code='DKIM'
on conflict (purchase_order_id,item_id) do nothing;
update public.purchase_orders set status='approved',approved_at=now()
where order_number='PO-CI-GRN-OVER' and status='draft';
select set_config('factoryos.grn.over_po_id',(select id::text from public.purchase_orders where order_number='PO-CI-GRN-OVER'),false);
select set_config('factoryos.grn.over_pol_id',(
  select pol.id::text from public.purchase_order_lines pol join public.purchase_orders po on po.id=pol.purchase_order_id
  where po.order_number='PO-CI-GRN-OVER'),false);

select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin
    perform public.post_purchase_goods_receipt(
      current_setting('factoryos.grn.over_po_id')::uuid,
      current_setting('factoryos.grn.rm_wh_id')::uuid,
      'CI-OVER',null,'over receipt deny',
      jsonb_build_array(jsonb_build_object(
        'purchase_order_line_id',current_setting('factoryos.grn.over_pol_id'),
        'received_quantity',6,'accepted_quantity',6,'rejected_quantity',0,
        'allocations',jsonb_build_array(jsonb_build_object('location_id',current_setting('factoryos.grn.carton_loc_id'),'quantity',6))
      )),
      'ci-purchase-grn-over'
    );
  exception when others then
    denied := position('accepted quantity exceeds purchase order pending quantity' in sqlerrm)>0;
  end;
  if not denied then raise exception 'PURCHASE GRN TEST: over-receipt was not denied'; end if;
end
$$;
reset role;
select (count(*)=0) as ok from public.stock_transactions where idempotency_key='ci-purchase-grn-over' \gset over_rollback_
\if :over_rollback_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: over-receipt left ledger side effect'
  select 1/0;
\endif

select (count(*)=1) as ok
from public.audit_logs
where entity_type='goods_receipt'
  and metadata->>'source'='purchase_grn'
  and metadata->>'idempotency_key'='ci-purchase-grn-001' \gset audit_
\if :audit_ok
\else
  \echo 'PURCHASE GRN TEST FAILED: audit event missing'
  select 1/0;
\endif

select set_config('request.jwt.claim.sub','',false);
\echo 'Purchase GRN command assertions passed.'
