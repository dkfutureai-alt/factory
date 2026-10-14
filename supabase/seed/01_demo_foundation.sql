-- FactoryOS demo foundation seed
-- Safe fictional business data only. Auth users are seeded separately after a dedicated project exists.

insert into public.organizations (code, name, slug)
values ('DKIM', 'DK Industrial Manufacturing Pvt Ltd', 'dk-industrial-manufacturing')
on conflict (code) do update set name = excluded.name, slug = excluded.slug;

insert into public.organization_settings (
  organization_id, currency_code, timezone, financial_year_start_month,
  default_language, app_display_name, primary_color, secondary_color
)
select id, 'INR', 'Asia/Kolkata', 4, 'en', 'FactoryOS', '#2563EB', '#0F172A'
from public.organizations where code = 'DKIM'
on conflict (organization_id) do update set
  currency_code = excluded.currency_code,
  timezone = excluded.timezone,
  financial_year_start_month = excluded.financial_year_start_month,
  default_language = excluded.default_language,
  app_display_name = excluded.app_display_name,
  primary_color = excluded.primary_color,
  secondary_color = excluded.secondary_color;

insert into public.factories (organization_id, code, name, city, state, country_code)
select id, v.code, v.name, v.city, 'Maharashtra', 'IN'
from public.organizations o
cross join (values
  ('PLANT-01', 'Main Manufacturing Plant', 'Pune'),
  ('PLANT-02', 'Secondary Processing Plant', 'Nashik')
) as v(code, name, city)
where o.code = 'DKIM'
on conflict (organization_id, code) do update set
  name = excluded.name, city = excluded.city, state = excluded.state;

insert into public.departments (organization_id, factory_id, code, name)
select o.id, f.id, d.code, d.name
from public.organizations o
join public.factories f on f.organization_id = o.id and f.code = 'PLANT-01'
cross join (values
  ('PROD', 'Production'),
  ('WH', 'Warehouse'),
  ('QC', 'Quality Control'),
  ('MNT', 'Maintenance'),
  ('DSP', 'Dispatch'),
  ('LOG', 'Logistics'),
  ('HR', 'HR'),
  ('SAL', 'Sales'),
  ('PUR', 'Purchase'),
  ('FIN', 'Finance'),
  ('ADM', 'Administration')
) as d(code, name)
where o.code = 'DKIM'
on conflict (organization_id, factory_id, code) do update set name = excluded.name;

insert into public.warehouses (organization_id, factory_id, code, name, warehouse_type)
select o.id, f.id, w.code, w.name, w.kind
from public.organizations o
join public.factories f on f.organization_id = o.id and f.code = 'PLANT-01'
cross join (values
  ('RM-WH', 'Raw Material Warehouse', 'raw_material'),
  ('FG-WH', 'Finished Goods Warehouse', 'finished_goods'),
  ('SP-WH', 'Spares & Consumables Store', 'spares')
) as w(code, name, kind)
where o.code = 'DKIM'
on conflict (organization_id, code) do update set
  name = excluded.name, warehouse_type = excluded.warehouse_type;

insert into public.permissions (key, module_key, description)
values
  ('organization.read', 'administration', 'Read organization configuration'),
  ('organization.update', 'administration', 'Update organization configuration'),
  ('factory.read', 'administration', 'Read factory configuration'),
  ('factory.manage', 'administration', 'Manage factories, departments and warehouses'),
  ('employee.read', 'hr', 'Read employee records'),
  ('employee.create', 'hr', 'Create employee records'),
  ('employee.update', 'hr', 'Update employee records'),
  ('employee.deactivate', 'hr', 'Deactivate employees'),
  ('attendance.read', 'hr', 'Read attendance'),
  ('attendance.self_checkin', 'hr', 'Create own check-in/out events'),
  ('attendance.manage', 'hr', 'Manage attendance'),
  ('leave.self_create', 'hr', 'Create own leave requests'),
  ('leave.approve', 'hr', 'Approve leave requests'),
  ('inventory.read', 'inventory', 'Read inventory'),
  ('inventory.receive', 'inventory', 'Receive stock'),
  ('inventory.issue', 'inventory', 'Issue stock'),
  ('inventory.transfer', 'inventory', 'Transfer stock'),
  ('inventory.adjust', 'inventory', 'Create approved stock adjustments'),
  ('production.read', 'production', 'Read production data'),
  ('production.create', 'production', 'Create production orders'),
  ('production.start', 'production', 'Start production'),
  ('production.complete', 'production', 'Complete production batches'),
  ('quality.read', 'quality', 'Read quality records'),
  ('quality.inspect', 'quality', 'Perform inspections'),
  ('quality.release', 'quality', 'Release or reject controlled output'),
  ('sales.read', 'sales', 'Read sales data'),
  ('sales.manage', 'sales', 'Manage customers, orders and invoices'),
  ('purchase.read', 'purchase', 'Read purchase data'),
  ('purchase.manage', 'purchase', 'Manage purchase workflow'),
  ('dispatch.read', 'dispatch', 'Read dispatch data'),
  ('dispatch.manage', 'dispatch', 'Manage dispatch workflow'),
  ('vehicle.read', 'fleet', 'Read vehicle data'),
  ('vehicle.manage', 'fleet', 'Manage vehicles and assignments'),
  ('trip.assigned_read', 'fleet', 'Read own assigned trips'),
  ('trip.assigned_update', 'fleet', 'Update own assigned trips'),
  ('fuel.create', 'fleet', 'Create fuel entry for assigned vehicle'),
  ('fuel.manage', 'fleet', 'Manage fuel records'),
  ('delivery.assigned_read', 'delivery', 'Read own assigned deliveries'),
  ('delivery.assigned_update', 'delivery', 'Update own assigned deliveries'),
  ('maintenance.read', 'maintenance', 'Read maintenance data'),
  ('maintenance.manage', 'maintenance', 'Manage maintenance'),
  ('report.read', 'reports', 'Read authorized reports'),
  ('approval.read', 'approvals', 'Read approvals'),
  ('approval.act', 'approvals', 'Approve or reject authorized requests'),
  ('audit.read', 'administration', 'Read audit history'),
  ('settings.manage', 'administration', 'Manage organization settings and modules')
on conflict (key) do update set module_key = excluded.module_key, description = excluded.description;

insert into public.roles (organization_id, key, name, description, is_system)
select o.id, r.key, r.name, r.description, true
from public.organizations o
cross join (values
  ('company_owner', 'Company Owner', 'Full organization operational administration'),
  ('factory_manager', 'Factory Manager', 'Broad factory operations and approvals'),
  ('production_manager', 'Production Manager', 'Production planning and execution'),
  ('warehouse_manager', 'Warehouse Manager', 'Inventory and warehouse control'),
  ('hr_manager', 'HR Manager', 'Employee, attendance and leave management'),
  ('maintenance_manager', 'Maintenance Manager', 'Asset and maintenance management'),
  ('sales_manager', 'Sales Manager', 'Customer and sales management'),
  ('supervisor', 'Supervisor', 'Team and assigned production supervision'),
  ('driver', 'Driver', 'Assigned vehicle, trip and delivery operations'),
  ('employee', 'Employee', 'Employee self-service and assigned work')
) as r(key, name, description)
where o.code = 'DKIM'
on conflict (organization_id, key) do update set
  name = excluded.name, description = excluded.description, is_system = excluded.is_system;

-- Company owner gets all currently defined organization permissions.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id = r.organization_id and o.code = 'DKIM'
cross join public.permissions p
where r.key = 'company_owner'
on conflict do nothing;

-- Factory manager: operational breadth without organization/security configuration ownership.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id = r.organization_id and o.code = 'DKIM'
join public.permissions p on p.key = any(array[
  'factory.read','employee.read','attendance.read','inventory.read','inventory.receive','inventory.issue','inventory.transfer',
  'production.read','production.create','production.start','production.complete','quality.read','quality.inspect',
  'sales.read','purchase.read','dispatch.read','dispatch.manage','vehicle.read','vehicle.manage','fuel.manage',
  'maintenance.read','report.read','approval.read','approval.act'
])
where r.key = 'factory_manager'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id = r.organization_id and o.code = 'DKIM'
join public.permissions p on (
  (r.key = 'production_manager' and p.key = any(array['production.read','production.create','production.start','production.complete','inventory.read','quality.read','quality.inspect','report.read','approval.read'])) or
  (r.key = 'warehouse_manager' and p.key = any(array['inventory.read','inventory.receive','inventory.issue','inventory.transfer','dispatch.read','dispatch.manage','purchase.read','report.read','approval.read'])) or
  (r.key = 'hr_manager' and p.key = any(array['employee.read','employee.create','employee.update','employee.deactivate','attendance.read','attendance.manage','leave.approve','report.read','approval.read'])) or
  (r.key = 'maintenance_manager' and p.key = any(array['maintenance.read','maintenance.manage','inventory.read','inventory.issue','report.read','approval.read'])) or
  (r.key = 'sales_manager' and p.key = any(array['sales.read','sales.manage','dispatch.read','report.read','approval.read'])) or
  (r.key = 'supervisor' and p.key = any(array['employee.read','attendance.read','inventory.read','production.read','production.start','quality.read','quality.inspect','approval.read'])) or
  (r.key = 'driver' and p.key = any(array['vehicle.read','trip.assigned_read','trip.assigned_update','fuel.create','delivery.assigned_read','delivery.assigned_update'])) or
  (r.key = 'employee' and p.key = any(array['attendance.self_checkin','leave.self_create','production.read','inventory.read']))
)
on conflict do nothing;

insert into public.organization_modules (organization_id, module_key, is_enabled)
select o.id, m.module_key, true
from public.organizations o
cross join (values
  ('hr'),('inventory'),('purchase'),('production'),('quality'),('sales'),('warehouse'),('dispatch'),
  ('fleet'),('delivery'),('maintenance'),('reports'),('approvals'),('notifications'),('audit')
) as m(module_key)
where o.code = 'DKIM'
on conflict (organization_id, module_key) do update set is_enabled = excluded.is_enabled;
