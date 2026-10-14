-- FactoryOS fictional notification foundation seed
-- No auth users, device tokens or recipient rows are seeded here.

insert into public.permissions (key, module_key, description)
values
  ('notification.read', 'notifications', 'Read authorized factory notifications and alert rules'),
  ('notification.manage', 'notifications', 'Manage notification templates and alert rules')
on conflict (key) do update set module_key = excluded.module_key, description = excluded.description;

-- Company owner receives new permissions added after the foundation seed.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id = r.organization_id and o.code = 'DKIM'
join public.permissions p on p.key in ('notification.read', 'notification.manage')
where r.key = 'company_owner'
on conflict do nothing;

-- Factory manager can monitor and configure factory alert routing.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id = r.organization_id and o.code = 'DKIM'
join public.permissions p on p.key in ('notification.read', 'notification.manage')
where r.key = 'factory_manager'
on conflict do nothing;

insert into public.notification_templates (organization_id, template_key, title_template, body_template, route_template)
select o.id, v.template_key, v.title_template, v.body_template, v.route_template
from public.organizations o
cross join (values
  ('inventory.low_stock', 'Low stock alert', '{{item_code}} is below reorder level at {{warehouse_name}}.', '/inventory/item'),
  ('maintenance.breakdown', 'Maintenance breakdown', '{{asset_code}} stopped at {{factory_name}}. Open {{work_order_number}} for action.', '/maintenance/work-order'),
  ('leave.approval_required', 'Leave approval required', 'A leave request is waiting for authorized HR review.', '/hr/attendance-leave'),
  ('delivery.assigned', 'Delivery assigned', '{{delivery_number}} is assigned and ready for driver action.', '/delivery/driver')
) as v(template_key, title_template, body_template, route_template)
where o.code = 'DKIM'
on conflict (organization_id, template_key) do update set
  title_template = excluded.title_template,
  body_template = excluded.body_template,
  route_template = excluded.route_template,
  is_active = true;

insert into public.notification_rules (
  organization_id, factory_id, trigger_key, template_id, audience_role_key,
  priority, in_app_enabled, push_enabled, is_enabled
)
select o.id, f.id, v.trigger_key, t.id, v.audience_role_key,
       v.priority::public.notification_priority, true, true, true
from public.organizations o
join public.factories f on f.organization_id = o.id and f.code = 'PLANT-01'
cross join (values
  ('inventory.low_stock', 'warehouse_manager', 'high'),
  ('maintenance.breakdown', 'maintenance_manager', 'critical'),
  ('leave.approval_required', 'hr_manager', 'normal'),
  ('delivery.assigned', 'driver', 'normal')
) as v(trigger_key, audience_role_key, priority)
join public.notification_templates t on t.organization_id = o.id and t.template_key = v.trigger_key
where o.code = 'DKIM'
on conflict (organization_id, factory_id, trigger_key, audience_role_key) do update set
  template_id = excluded.template_id,
  priority = excluded.priority,
  in_app_enabled = true,
  push_enabled = true,
  is_enabled = true;

insert into public.notifications (
  organization_id, factory_id, trigger_key, source_module, source_type, source_id,
  title, body, route, priority, requires_action, created_at
)
select o.id, f.id, v.trigger_key, v.source_module, v.source_type, v.source_id,
       v.title, v.body, v.route, v.priority::public.notification_priority, v.requires_action, v.created_at
from public.organizations o
join public.factories f on f.organization_id = o.id and f.code = 'PLANT-01'
cross join (values
  ('maintenance.breakdown','maintenance','work_order','WO-2026-00241','Production line 02 stopped','AC-02 breakdown requires maintenance action.','/maintenance/work-order','critical',true,'2026-10-14 16:30:00+05:30'::timestamptz),
  ('inventory.low_stock','inventory','item','RM-STL-304-02','RM-STL-304-02 below reorder level','Current stock may affect PRD-2026-01040.','/inventory/item','high',true,'2026-10-14 16:22:00+05:30'::timestamptz),
  ('leave.approval_required','hr','leave_request','DEMO-LR-001','Leave request needs approval','A fictional demo leave request is waiting for HR review.','/hr/attendance-leave','normal',true,'2026-10-14 16:10:00+05:30'::timestamptz),
  ('delivery.assigned','delivery','delivery','DEL-2026-00681','Delivery DEL-2026-00681 assigned','Trip TRIP-2026-00814 is ready for pickup.','/delivery/driver','normal',false,'2026-10-14 15:54:00+05:30'::timestamptz)
) as v(trigger_key, source_module, source_type, source_id, title, body, route, priority, requires_action, created_at)
where o.code = 'DKIM'
  and not exists (
    select 1 from public.notifications n
    where n.organization_id = o.id
      and n.trigger_key = v.trigger_key
      and n.source_type = v.source_type
      and n.source_id = v.source_id
  );
