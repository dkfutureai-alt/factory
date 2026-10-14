-- FactoryOS fictional Sales demo seed
-- Depends on 01_demo_foundation.sql, 02_demo_inventory_production.sql and 06_sales.sql.
-- Orders are created/reset as draft, lines are inserted, then the demo status is finalized.

insert into public.customers (organization_id, code, name, gstin, city, state, country_code, credit_terms_days, credit_limit, status)
select o.id, v.code, v.name, v.gstin, v.city, 'Maharashtra', 'IN', v.credit_days, v.credit_limit, 'active'::public.entity_status
from public.organizations o
cross join (values
  ('CUST-0042','Sahyadri Process Systems','27AAECS0000A1Z0','Pune',30,1000000::numeric),
  ('CUST-0031','Apex Hospital Engineering','27AAECA0000A1Z0','Pune',30,750000::numeric),
  ('CUST-0018','Western Industrial Gases','27AAECW0000A1Z0','Solapur',21,1200000::numeric),
  ('CUST-0026','Nashik Automation Works','27AAECN0000A1Z0','Nashik',30,800000::numeric)
) as v(code,name,gstin,city,credit_days,credit_limit)
where o.code='DKIM'
on conflict (organization_id, code) do update set
  name=excluded.name, gstin=excluded.gstin, city=excluded.city, state=excluded.state,
  credit_terms_days=excluded.credit_terms_days, credit_limit=excluded.credit_limit, status=excluded.status;

insert into public.customer_contacts (organization_id, customer_id, label, contact_name, business_phone, business_email, is_primary)
select c.organization_id, c.id, 'Primary', 'Procurement Desk', null, 'procurement@example.test', true
from public.customers c
join public.organizations o on o.id=c.organization_id and o.code='DKIM'
where c.code='CUST-0042'
and not exists (select 1 from public.customer_contacts cc where cc.customer_id=c.id and cc.is_primary);

insert into public.customer_delivery_addresses (organization_id, customer_id, code, line1, city, state, postal_code, is_default)
select c.organization_id, c.id, 'MAIN', v.line1, v.city, 'Maharashtra', v.postal_code, true
from public.customers c
join public.organizations o on o.id=c.organization_id and o.code='DKIM'
join (values
  ('CUST-0042','Chakan Industrial Area','Pune','410501'),
  ('CUST-0031','Bhosari MIDC','Pune','411026'),
  ('CUST-0018','Akkalkot Road Industrial Estate','Solapur','413006'),
  ('CUST-0026','Satpur MIDC','Nashik','422007')
) as v(code,line1,city,postal_code) on v.code=c.code
on conflict (customer_id, code) do update set
  line1=excluded.line1, city=excluded.city, state=excluded.state, postal_code=excluded.postal_code, is_default=excluded.is_default;

-- Keep orders draft until demo lines exist, preserving the production rule that confirmed lines are immutable.
insert into public.sales_orders (
  organization_id, factory_id, customer_id, order_number, order_date, requested_delivery_date,
  status, currency_code, customer_po_number, payment_terms, delivery_method, ship_to_address_id, confirmed_at, notes
)
select o.id, f.id, c.id, v.order_number, v.order_date, v.delivery_date,
       'draft'::public.sales_order_status, 'INR', v.customer_po, v.payment_terms, 'Company vehicle', a.id,
       null, 'Fictional FactoryOS demo sales order'
from public.organizations o
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join (values
  ('SO-2026-01842','CUST-0042',date '2026-10-14',date '2026-10-16','SPS/PO/2287','30 days'),
  ('SO-2026-01843','CUST-0031',date '2026-10-14',date '2026-10-17','AHE/PO/1049','30 days'),
  ('SO-2026-01839','CUST-0018',date '2026-10-11',date '2026-10-14','WIG/PO/7781','21 days'),
  ('SO-2026-01836','CUST-0026',date '2026-10-09',date '2026-10-12','NAW/PO/6642','30 days'),
  ('SO-2026-01791','CUST-0042',date '2026-09-26',date '2026-09-30','SPS/PO/2214','30 days'),
  ('SO-2026-01724','CUST-0042',date '2026-09-08',date '2026-09-12','SPS/PO/2147','30 days')
) as v(order_number,customer_code,order_date,delivery_date,customer_po,payment_terms) on true
join public.customers c on c.organization_id=o.id and c.code=v.customer_code
left join public.customer_delivery_addresses a on a.customer_id=c.id and a.is_default
where o.code='DKIM'
on conflict (organization_id, order_number) do update set
  customer_id=excluded.customer_id, requested_delivery_date=excluded.requested_delivery_date,
  status='draft'::public.sales_order_status, customer_po_number=excluded.customer_po_number, payment_terms=excluded.payment_terms,
  delivery_method=excluded.delivery_method, ship_to_address_id=excluded.ship_to_address_id,
  confirmed_at=null, notes=excluded.notes;

insert into public.sales_order_lines (organization_id, sales_order_id, item_id, ordered_quantity, unit_price, tax_rate)
select so.organization_id, so.id, i.id, v.qty, v.unit_price, 0
from public.sales_orders so
join public.organizations o on o.id=so.organization_id and o.code='DKIM'
join (values
  ('SO-2026-01842','FG-COMP-X',120::numeric,2850::numeric),
  ('SO-2026-01842','FG-VALVE-25',80::numeric,1800::numeric),
  ('SO-2026-01843','FG-VALVE-25',120::numeric,2600::numeric),
  ('SO-2026-01839','FG-COMP-X',160::numeric,4000::numeric),
  ('SO-2026-01836','FG-BRKT-A',200::numeric,1380::numeric)
) as v(order_number,sku,qty,unit_price) on v.order_number=so.order_number
join public.items i on i.organization_id=so.organization_id and i.sku=v.sku
on conflict (sales_order_id, item_id) do update set ordered_quantity=excluded.ordered_quantity, unit_price=excluded.unit_price, tax_rate=excluded.tax_rate;

insert into public.sales_order_lines (organization_id, sales_order_id, item_id, ordered_quantity, unit_price, tax_rate)
select so.organization_id, so.id, i.id, 100,
       case when so.order_number='SO-2026-01791' then 3220 else 2950 end,
       0
from public.sales_orders so
join public.organizations o on o.id=so.organization_id and o.code='DKIM'
join public.items i on i.organization_id=so.organization_id and i.sku='FG-COMP-X'
where so.order_number in ('SO-2026-01791','SO-2026-01724')
on conflict (sales_order_id, item_id) do update set ordered_quantity=excluded.ordered_quantity, unit_price=excluded.unit_price;

-- Finalize the fictional demo lifecycle only after lines exist.
update public.sales_orders so
set status=v.status::public.sales_order_status,
    confirmed_at=so.order_date::timestamptz + interval '10 hours'
from (values
  ('SO-2026-01842','ready'),
  ('SO-2026-01843','production'),
  ('SO-2026-01839','dispatched'),
  ('SO-2026-01836','delivered'),
  ('SO-2026-01791','closed'),
  ('SO-2026-01724','closed')
) as v(order_number,status)
join public.organizations o on o.code='DKIM'
where so.organization_id=o.id and so.order_number=v.order_number;

insert into public.customer_payments (organization_id, customer_id, sales_order_id, payment_reference, received_at, amount, method, status, external_reference)
select so.organization_id, so.customer_id, so.id, v.payment_reference, v.received_at, v.amount, 'Bank transfer', 'received'::public.customer_payment_status, v.external_reference
from public.sales_orders so
join public.organizations o on o.id=so.organization_id and o.code='DKIM'
join (values
  ('SO-2026-01842','PAY-2026-01182',timestamptz '2026-10-14 11:10:00+05:30',200000::numeric,'DEMO-UTR-1182'),
  ('SO-2026-01842','PAY-2026-01174',timestamptz '2026-10-10 15:20:00+05:30',86000::numeric,'DEMO-UTR-1174'),
  ('SO-2026-01843','PAY-2026-01179',timestamptz '2026-10-12 12:40:00+05:30',312000::numeric,'DEMO-UTR-1179'),
  ('SO-2026-01839','PAY-2026-01166',timestamptz '2026-10-08 10:15:00+05:30',500000::numeric,'DEMO-UTR-1166'),
  ('SO-2026-01836','PAY-2026-01158',timestamptz '2026-10-06 16:00:00+05:30',276000::numeric,'DEMO-UTR-1158'),
  ('SO-2026-01791','PAY-2026-01096',timestamptz '2026-09-28 13:30:00+05:30',322000::numeric,'DEMO-UTR-1096'),
  ('SO-2026-01724','PAY-2026-01041',timestamptz '2026-09-10 14:05:00+05:30',295000::numeric,'DEMO-UTR-1041')
) as v(order_number,payment_reference,received_at,amount,external_reference) on v.order_number=so.order_number
on conflict (organization_id, payment_reference) do update set
  customer_id=excluded.customer_id, sales_order_id=excluded.sales_order_id, received_at=excluded.received_at,
  amount=excluded.amount, method=excluded.method, status=excluded.status, external_reference=excluded.external_reference;
