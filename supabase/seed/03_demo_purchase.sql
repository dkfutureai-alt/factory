-- FactoryOS fictional Purchase demo data.
-- Depends on 01_demo_foundation.sql, 02_demo_inventory_production.sql and 04_purchase.sql.

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id=r.organization_id and o.code='DKIM'
join public.permissions p on p.key='purchase.manage'
where r.key='factory_manager'
on conflict do nothing;

insert into public.suppliers (organization_id, code, name, gstin, contact_name, phone, email, payment_terms_days)
select o.id, s.code, s.name, s.gstin, s.contact_name, s.phone, s.email, s.terms
from public.organizations o
cross join (values
  ('SUP-METALS','Maharashtra Metals Pvt Ltd','27AAFCM4821A1ZQ','Rahul Deshmukh','020-5550-2101','orders@maharashtrametals.example',30),
  ('SUP-BEARING','Precision Bearings Co','27AAGCP7712D1Z5','Neha Kulkarni','020-5550-2102','sales@precisionbearings.example',30),
  ('SUP-PACK','Om Packaging Industries','27AAEFO5520B1ZP','Sanjay Patil','020-5550-2103','orders@ompackaging.example',21),
  ('SUP-CHEM','Western Industrial Chemicals','27AAACW9044J1ZS','Pooja Shah','020-5550-2104','dispatch@westernchem.example',30)
) as s(code,name,gstin,contact_name,phone,email,terms)
where o.code='DKIM'
on conflict (organization_id, code) do update set
  name=excluded.name, gstin=excluded.gstin, contact_name=excluded.contact_name,
  phone=excluded.phone, email=excluded.email, payment_terms_days=excluded.payment_terms_days;

insert into public.items (
  organization_id, category_id, unit_id, sku, name, barcode, qr_identifier,
  cost, minimum_stock, maximum_stock, reorder_level, batch_tracking
)
select o.id, c.id, u.id, 'RM-STL-304-02', 'SS Sheet 304 2mm', '890100000013', 'QR-RM-STL-304-02',
       198, 300, 2500, 500, true
from public.organizations o
join public.item_categories c on c.organization_id=o.id and c.code='RAW'
join public.item_units u on u.organization_id=o.id and u.code='KG'
where o.code='DKIM'
on conflict (organization_id, sku) do update set
  name=excluded.name, category_id=excluded.category_id, unit_id=excluded.unit_id,
  barcode=excluded.barcode, qr_identifier=excluded.qr_identifier, cost=excluded.cost,
  minimum_stock=excluded.minimum_stock, maximum_stock=excluded.maximum_stock,
  reorder_level=excluded.reorder_level, batch_tracking=excluded.batch_tracking;

insert into public.purchase_orders (
  organization_id, factory_id, supplier_id, order_number, order_date,
  expected_delivery_date, status, payment_terms
)
select o.id, f.id, s.id, v.order_number, v.order_date, v.expected_date,
       'draft'::public.purchase_order_status, v.payment_terms
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
cross join (values
  ('SUP-METALS','PO-2026-00481',date '2026-10-10',date '2026-10-17','30 days from accepted GRN'),
  ('SUP-BEARING','PO-2026-00482',date '2026-10-13',date '2026-10-18','30 days from accepted GRN'),
  ('SUP-PACK','PO-2026-00483',date '2026-10-11',date '2026-10-16','21 days from accepted GRN'),
  ('SUP-CHEM','PO-2026-00479',date '2026-10-07',date '2026-10-13','30 days from accepted GRN')
) as v(supplier_code,order_number,order_date,expected_date,payment_terms)
join public.suppliers s on s.organization_id=o.id and s.code=v.supplier_code
where o.code='DKIM'
on conflict (organization_id, order_number) do nothing;

insert into public.purchase_order_lines (
  organization_id, purchase_order_id, item_id, ordered_quantity, unit_price, tax_rate
)
select o.id, po.id, i.id, v.qty, v.unit_price, 18
from public.organizations o
cross join (values
  ('PO-2026-00481','RM-STL-304-02',1000::numeric,198::numeric),
  ('PO-2026-00481','RM-PIPE-001',400::numeric,120::numeric)
) as v(order_number,sku,qty,unit_price)
join public.purchase_orders po on po.organization_id=o.id and po.order_number=v.order_number
join public.items i on i.organization_id=o.id and i.sku=v.sku
where o.code='DKIM'
  and po.status in ('draft','pending_approval')
on conflict (purchase_order_id, item_id) do nothing;

update public.purchase_orders
set status=case order_number
      when 'PO-2026-00481' then 'part_received'::public.purchase_order_status
      when 'PO-2026-00482' then 'pending_approval'::public.purchase_order_status
      when 'PO-2026-00483' then 'approved'::public.purchase_order_status
      when 'PO-2026-00479' then 'approved'::public.purchase_order_status
      else status end,
    approved_at=case when order_number in ('PO-2026-00481','PO-2026-00483','PO-2026-00479')
                     then coalesce(approved_at,timestamptz '2026-10-12 10:00:00+05:30')
                     else approved_at end
where organization_id=(select id from public.organizations where code='DKIM')
  and order_number in ('PO-2026-00481','PO-2026-00482','PO-2026-00483','PO-2026-00479');

insert into public.batches (organization_id, item_id, batch_number, manufactured_at, supplier_batch_number)
select o.id, i.id, v.batch_number, v.mfg, v.supplier_batch
from public.organizations o
cross join (values
  ('RM-STL-304-02','RM-141026-04',timestamptz '2026-10-11 08:00:00+05:30','MM-SS304-7781'),
  ('RM-PIPE-001','RM-141026-05',timestamptz '2026-10-10 09:00:00+05:30','MM-PIPE25-4419')
) as v(sku,batch_number,mfg,supplier_batch)
join public.items i on i.organization_id=o.id and i.sku=v.sku
where o.code='DKIM'
on conflict (organization_id,item_id,batch_number) do update set
  manufactured_at=excluded.manufactured_at, supplier_batch_number=excluded.supplier_batch_number;

insert into public.goods_receipts (
  organization_id, factory_id, purchase_order_id, supplier_id, warehouse_id,
  grn_number, status, received_at, supplier_delivery_note
)
select o.id, f.id, po.id, po.supplier_id, w.id, 'GRN-2026-00731', 'draft',
       timestamptz '2026-10-14 10:42:00+05:30', 'MM-DN-4498'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.purchase_orders po on po.organization_id=o.id and po.order_number='PO-2026-00481'
join public.warehouses w on w.organization_id=o.id and w.code='RM-WH'
where o.code='DKIM'
on conflict (organization_id, grn_number) do nothing;

insert into public.goods_receipt_lines (
  organization_id, goods_receipt_id, purchase_order_line_id, item_id,
  received_quantity, accepted_quantity, rejected_quantity, supplier_batch_number
)
select o.id, gr.id, pol.id, pol.item_id, v.received_qty, v.accepted_qty, 0, v.supplier_batch
from public.organizations o
join public.goods_receipts gr on gr.organization_id=o.id and gr.grn_number='GRN-2026-00731'
cross join (values
  ('RM-STL-304-02',650::numeric,650::numeric,'MM-SS304-7781'),
  ('RM-PIPE-001',400::numeric,400::numeric,'MM-PIPE25-4419')
) as v(sku,received_qty,accepted_qty,supplier_batch)
join public.items i on i.organization_id=o.id and i.sku=v.sku
join public.purchase_order_lines pol on pol.purchase_order_id=gr.purchase_order_id and pol.item_id=i.id
where o.code='DKIM'
  and gr.status='draft'
on conflict (goods_receipt_id, purchase_order_line_id) do nothing;

update public.goods_receipts
set status='checked', checked_at=timestamptz '2026-10-14 11:00:00+05:30'
where organization_id=(select id from public.organizations where code='DKIM')
  and grn_number='GRN-2026-00731' and status='draft';

insert into public.stock_transactions (
  organization_id, factory_id, transaction_number, transaction_type, status,
  reference_type, reference_id, occurred_at, reason, posted_at
)
select o.id, f.id, 'STK-PR-2026-00731', 'purchase_receipt', 'posted',
       'goods_receipt', gr.id, timestamptz '2026-10-14 10:42:00+05:30',
       'Demo purchase goods receipt', timestamptz '2026-10-14 11:05:00+05:30'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.goods_receipts gr on gr.organization_id=o.id and gr.grn_number='GRN-2026-00731'
where o.code='DKIM'
on conflict (organization_id, transaction_number) do nothing;

insert into public.stock_transaction_lines (
  organization_id, stock_transaction_id, item_id, batch_id, warehouse_id, location_id,
  quantity_delta, unit_cost, note
)
select o.id, st.id, i.id, b.id, w.id, wl.id, v.qty, v.unit_cost, 'GRN-2026-00731 accepted quantity'
from public.organizations o
join public.stock_transactions st on st.organization_id=o.id and st.transaction_number='STK-PR-2026-00731'
cross join (values
  ('RM-STL-304-02','RM-141026-04','RM-A-R03-B02',650::numeric,198::numeric),
  ('RM-PIPE-001','RM-141026-05','RM-B-R01-B04',400::numeric,120::numeric)
) as v(sku,batch_number,location_code,qty,unit_cost)
join public.items i on i.organization_id=o.id and i.sku=v.sku
join public.batches b on b.organization_id=o.id and b.item_id=i.id and b.batch_number=v.batch_number
join public.warehouses w on w.organization_id=o.id and w.code='RM-WH'
join public.warehouse_locations wl on wl.warehouse_id=w.id and wl.code=v.location_code
where o.code='DKIM'
  and not exists (
    select 1 from public.stock_transaction_lines x
    where x.stock_transaction_id=st.id and x.item_id=i.id and x.batch_id=b.id
  );

update public.goods_receipts gr
set status='posted', stock_transaction_id=st.id, checked_at=timestamptz '2026-10-14 11:05:00+05:30'
from public.stock_transactions st
where gr.organization_id=st.organization_id
  and gr.organization_id=(select id from public.organizations where code='DKIM')
  and gr.grn_number='GRN-2026-00731'
  and st.transaction_number='STK-PR-2026-00731'
  and gr.status='checked';
