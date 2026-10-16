-- Fictional Phase 10 Dispatch, Delivery & Returnables demo data. No real person/company data.

-- Empty cylinders are returnable assets for the customer-return flow.
update public.inventory_items
set is_returnable=true
where id='43000000-0000-4000-8000-000000000003';

-- Stage the four fictional filled cylinders already allocated by Phase 7.
insert into public.inventory_transactions(
 id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,
 from_location_id,to_location_id,external_reference,notes,occurred_at
) values (
 '98000000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000001',
 '20000000-0000-4000-8000-000000000001',
 '43000000-0000-4000-8000-000000000006',
 'P10-PICK-STAGE-001','transfer',4,
 '44000000-0000-4000-8000-000000000003',
 '96000000-0000-4000-8000-000000000006',
 'PICK-DEMO-P8-001','Warehouse pick staged for Phase 10 dispatch',now()-interval '50 minutes'
) on conflict (id) do nothing;

insert into public.stock_ledger_entries(
 organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,occurred_at
)
select * from (values
 ('10000000-0000-4000-8000-000000000001'::uuid,'20000000-0000-4000-8000-000000000001'::uuid,'98000000-0000-4000-8000-000000000001'::uuid,'43000000-0000-4000-8000-000000000006'::uuid,'44000000-0000-4000-8000-000000000003'::uuid,-4::numeric,now()-interval '50 minutes'),
 ('10000000-0000-4000-8000-000000000001'::uuid,'20000000-0000-4000-8000-000000000001'::uuid,'98000000-0000-4000-8000-000000000001'::uuid,'43000000-0000-4000-8000-000000000006'::uuid,'96000000-0000-4000-8000-000000000006'::uuid,4::numeric,now()-interval '50 minutes')
) as x(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,occurred_at)
where not exists(
 select 1 from public.stock_ledger_entries
 where transaction_id='98000000-0000-4000-8000-000000000001'
);

update public.warehouse_pick_lines
set picked_quantity=4,
    status='picked',
    transfer_transaction_id='98000000-0000-4000-8000-000000000001',
    picked_at=coalesce(picked_at,now()-interval '50 minutes')
where id='96300000-0000-4000-8000-000000000001';

update public.warehouse_pick_lists
set status='handed_off',
    started_at=coalesce(started_at,now()-interval '60 minutes'),
    staged_at=coalesce(staged_at,now()-interval '45 minutes')
where id='96200000-0000-4000-8000-000000000001';

insert into public.warehouse_dispatch_handoffs(
 id,organization_id,factory_id,handoff_no,pick_list_id,sales_order_id,staging_location_id,
 status,notes,handed_off_at,created_at
) values (
 '98100000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000001',
 '20000000-0000-4000-8000-000000000001',
 'WH-HO-DEMO-P10-001',
 '96200000-0000-4000-8000-000000000001',
 '95200000-0000-4000-8000-000000000001',
 '96000000-0000-4000-8000-000000000006',
 'handed_off','Fictional load handed from Warehouse to Dispatch',
 now()-interval '40 minutes',now()-interval '45 minutes'
) on conflict (id) do nothing;

-- Reuse the fictional assigned truck trip from Phase 9 and link it to this handoff/order.
update public.fleet_trips
set sales_order_id='95200000-0000-4000-8000-000000000001',
    warehouse_handoff_id='98100000-0000-4000-8000-000000000001',
    origin='Aarohan Solapur Plant',
    destination='Sunrise Care Hospital'
where id='97400000-0000-4000-8000-000000000001';

insert into public.dispatch_deliveries(
 id,organization_id,factory_id,delivery_no,warehouse_handoff_id,trip_id,sales_order_id,
 customer_id,vehicle_id,driver_id,staging_location_id,vehicle_location_id,status,notes,created_at
) values (
 '98200000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000001',
 '20000000-0000-4000-8000-000000000001',
 'DEL-DEMO-P10-001',
 '98100000-0000-4000-8000-000000000001',
 '97400000-0000-4000-8000-000000000001',
 '95200000-0000-4000-8000-000000000001',
 '91000000-0000-4000-8000-000000000003',
 '97100000-0000-4000-8000-000000000001',
 '97200000-0000-4000-8000-000000000001',
 '96000000-0000-4000-8000-000000000006',
 '97000000-0000-4000-8000-000000000001',
 'ready_to_load','Fictional delivery ready for Admin load confirmation',now()-interval '35 minutes'
) on conflict (id) do nothing;

insert into public.dispatch_delivery_lines(
 id,organization_id,delivery_id,warehouse_pick_line_id,sales_order_line_id,item_id,planned_quantity
) values (
 '98300000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000001',
 '98200000-0000-4000-8000-000000000001',
 '96300000-0000-4000-8000-000000000001',
 '95300000-0000-4000-8000-000000000001',
 '43000000-0000-4000-8000-000000000006',4
) on conflict (id) do nothing;
