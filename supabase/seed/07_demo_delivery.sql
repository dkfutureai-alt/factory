-- FactoryOS fictional Delivery demo seed
-- Depends on Sales, Fleet and Delivery schemas plus their demo seed data.

insert into public.permissions (key,module_key,description)
values
  ('delivery.read','delivery','Read delivery, POD and exception records'),
  ('delivery.manage','delivery','Manage delivery, POD and exception workflows')
on conflict (key) do update set module_key=excluded.module_key,description=excluded.description;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.roles r
join public.organizations o on o.id=r.organization_id and o.code='DKIM'
join public.permissions p on p.key in ('delivery.read','delivery.manage')
where r.key='company_owner'
   or (r.key='factory_manager')
   or (r.key='sales_manager' and p.key='delivery.read')
   or (r.key='warehouse_manager' and p.key='delivery.read')
on conflict do nothing;

-- Additional fictional trips provide completed/exception delivery examples.
insert into public.trips(organization_id,factory_id,trip_number,vehicle_id,driver_employee_id,sales_order_id,origin_label,destination_label,planned_start_at,actual_start_at,completed_at,start_odometer_km,end_odometer_km,status)
select v.organization_id,v.factory_id,x.trip_number,v.id,e.id,so.id,'Main Manufacturing Plant',c.name,
       x.planned_start,x.planned_start+interval '8 minutes',x.completed_at,x.start_km,x.end_km,'completed'::public.trip_status
from (values
  ('TRIP-2026-00823','VEH-004','DEMO-004','SO-2026-01836',timestamptz '2026-10-12 10:00:00+05:30',timestamptz '2026-10-12 12:05:00+05:30',73420,73550),
  ('TRIP-2026-00824','VEH-006','DEMO-006','SO-2026-01839',timestamptz '2026-10-14 07:30:00+05:30',timestamptz '2026-10-14 09:10:00+05:30',38310,38420)
) x(trip_number,vehicle_code,employee_code,sales_order_number,planned_start,completed_at,start_km,end_km)
join public.organizations o on o.code='DKIM'
join public.vehicles v on v.organization_id=o.id and v.vehicle_code=x.vehicle_code
join public.employees e on e.organization_id=o.id and e.employee_code=x.employee_code
join public.sales_orders so on so.organization_id=o.id and so.order_number=x.sales_order_number
join public.customers c on c.id=so.customer_id
on conflict (organization_id,trip_number) do update set
  vehicle_id=excluded.vehicle_id,driver_employee_id=excluded.driver_employee_id,sales_order_id=excluded.sales_order_id,
  origin_label=excluded.origin_label,destination_label=excluded.destination_label,planned_start_at=excluded.planned_start_at,
  actual_start_at=excluded.actual_start_at,completed_at=excluded.completed_at,start_odometer_km=excluded.start_odometer_km,
  end_odometer_km=excluded.end_odometer_km,status=excluded.status;

insert into public.deliveries(
  organization_id,factory_id,delivery_number,sales_order_id,trip_id,customer_id,ship_to_address_id,
  driver_employee_id,vehicle_id,planned_delivery_at,arrived_at,delivered_at,status,receiver_note
)
select so.organization_id,so.factory_id,x.delivery_number,so.id,t.id,so.customer_id,so.ship_to_address_id,t.driver_employee_id,t.vehicle_id,
       x.planned_at,x.arrived_at,x.delivered_at,x.status::public.delivery_status,x.note
from (values
  ('DEL-2026-00681','SO-2026-01842','TRIP-2026-00814',timestamptz '2026-10-14 11:20:00+05:30',null::timestamptz,null::timestamptz,'in_transit',null::text),
  ('DEL-2026-00682','SO-2026-01843','TRIP-2026-00815',timestamptz '2026-10-14 14:15:00+05:30',timestamptz '2026-10-14 14:08:00+05:30',null::timestamptz,'arrived','Awaiting customer receiving desk'),
  ('DEL-2026-00679','SO-2026-01836','TRIP-2026-00823',timestamptz '2026-10-12 11:50:00+05:30',timestamptz '2026-10-12 11:46:00+05:30',timestamptz '2026-10-12 11:58:00+05:30','delivered','Delivered in full'),
  ('DEL-2026-00678','SO-2026-01839','TRIP-2026-00824',timestamptz '2026-10-14 08:55:00+05:30',timestamptz '2026-10-14 08:42:00+05:30',timestamptz '2026-10-14 08:50:00+05:30','exception','Partial customer rejection')
) x(delivery_number,sales_order_number,trip_number,planned_at,arrived_at,delivered_at,status,note)
join public.sales_orders so on so.order_number=x.sales_order_number
join public.organizations o on o.id=so.organization_id and o.code='DKIM'
join public.trips t on t.organization_id=o.id and t.trip_number=x.trip_number
on conflict (organization_id,delivery_number) do update set
  sales_order_id=excluded.sales_order_id,trip_id=excluded.trip_id,customer_id=excluded.customer_id,ship_to_address_id=excluded.ship_to_address_id,
  driver_employee_id=excluded.driver_employee_id,vehicle_id=excluded.vehicle_id,planned_delivery_at=excluded.planned_delivery_at,
  arrived_at=excluded.arrived_at,delivered_at=excluded.delivered_at,status=excluded.status,receiver_note=excluded.receiver_note;

insert into public.delivery_lines(organization_id,delivery_id,sales_order_line_id,item_id,planned_quantity,accepted_quantity,rejected_quantity,rejection_reason)
select d.organization_id,d.id,sol.id,sol.item_id,x.planned,x.accepted,x.rejected,x.reason
from (values
  ('DEL-2026-00681','FG-COMP-X',80::numeric,0::numeric,0::numeric,null::text),
  ('DEL-2026-00681','FG-VALVE-25',40::numeric,0::numeric,0::numeric,null::text),
  ('DEL-2026-00682','FG-VALVE-25',120::numeric,0::numeric,0::numeric,null::text),
  ('DEL-2026-00679','FG-BRKT-A',200::numeric,200::numeric,0::numeric,null::text),
  ('DEL-2026-00678','FG-COMP-X',40::numeric,32::numeric,8::numeric,'Packaging damage')
) x(delivery_number,sku,planned,accepted,rejected,reason)
join public.deliveries d on d.delivery_number=x.delivery_number
join public.organizations o on o.id=d.organization_id and o.code='DKIM'
join public.sales_order_lines sol on sol.sales_order_id=d.sales_order_id
join public.items i on i.id=sol.item_id and i.sku=x.sku
on conflict (delivery_id,sales_order_line_id) do update set
  planned_quantity=excluded.planned_quantity,accepted_quantity=excluded.accepted_quantity,rejected_quantity=excluded.rejected_quantity,rejection_reason=excluded.rejection_reason;

insert into public.proof_of_deliveries(organization_id,delivery_id,receiver_name,captured_at,evidence_reference,verification_status,verified_at)
select d.organization_id,d.id,x.receiver_name,x.captured_at,x.evidence_reference,x.verification_status::public.pod_verification_status,x.verified_at
from (values
  ('DEL-2026-00679','Stores Receiver',timestamptz '2026-10-12 11:58:00+05:30','DEMO-POD-00679','verified',timestamptz '2026-10-12 12:10:00+05:30'),
  ('DEL-2026-00678','S. Kulkarni',timestamptz '2026-10-14 08:50:00+05:30','DEMO-POD-00678','captured',null::timestamptz)
) x(delivery_number,receiver_name,captured_at,evidence_reference,verification_status,verified_at)
join public.deliveries d on d.delivery_number=x.delivery_number
join public.organizations o on o.id=d.organization_id and o.code='DKIM'
on conflict (delivery_id) do update set
  receiver_name=excluded.receiver_name,captured_at=excluded.captured_at,evidence_reference=excluded.evidence_reference,
  verification_status=excluded.verification_status,verified_at=excluded.verified_at;

insert into public.delivery_exceptions(organization_id,delivery_id,delivery_line_id,exception_type,quantity,reason,evidence_reference,status)
select d.organization_id,d.id,dl.id,'rejected_quantity',dl.rejected_quantity,dl.rejection_reason,'DEMO-POD-00678','open'::public.delivery_exception_status
from public.deliveries d
join public.organizations o on o.id=d.organization_id and o.code='DKIM'
join public.delivery_lines dl on dl.delivery_id=d.id and dl.rejected_quantity>0
where d.delivery_number='DEL-2026-00678'
  and not exists(select 1 from public.delivery_exceptions de where de.delivery_id=d.id and de.delivery_line_id=dl.id and de.status<>'cancelled');

insert into public.delivery_events(organization_id,delivery_id,event_type,event_at,note)
select d.organization_id,d.id,x.event_type,x.event_at,x.note
from (values
  ('DEL-2026-00681','departed',timestamptz '2026-10-14 10:38:00+05:30','Vehicle departed plant'),
  ('DEL-2026-00682','arrived',timestamptz '2026-10-14 14:08:00+05:30','Driver arrived at customer'),
  ('DEL-2026-00679','delivered',timestamptz '2026-10-12 11:58:00+05:30','Delivered in full with verified POD'),
  ('DEL-2026-00678','exception',timestamptz '2026-10-14 08:50:00+05:30','Eight units rejected for packaging damage')
) x(delivery_number,event_type,event_at,note)
join public.deliveries d on d.delivery_number=x.delivery_number
join public.organizations o on o.id=d.organization_id and o.code='DKIM'
where not exists(select 1 from public.delivery_events de where de.delivery_id=d.id and de.event_type=x.event_type and de.event_at=x.event_at);
