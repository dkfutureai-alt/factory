insert into public.maintenance_spare_requirements(organization_id,factory_id,work_order_id,item_id,requested_quantity)
select w.organization_id,w.factory_id,w.id,i.id,s.quantity
from (values ('WO-2026-00241','SP-BRG-6204',2::numeric),('WO-2026-00242','SP-BELT-A42',1::numeric)) s(number,sku,quantity)
join public.organizations o on o.code='DKIM'
join public.maintenance_work_orders w on w.organization_id=o.id and w.order_number=s.number
join public.items i on i.organization_id=o.id and i.sku=s.sku
on conflict (work_order_id,item_id) do nothing;

insert into public.maintenance_events(organization_id,factory_id,work_order_id,event_type,details)
select w.organization_id,w.factory_id,w.id,'reported',jsonb_build_object('source','fictional_demo')
from public.maintenance_work_orders w
join public.organizations o on o.id=w.organization_id and o.code='DKIM'
where not exists(select 1 from public.maintenance_events e where e.work_order_id=w.id and e.event_type='reported');
