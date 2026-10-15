-- FactoryOS demo role grants for manual Inventory Stock Entry.
-- Applies after 01_demo_foundation.sql and 02_demo_inventory_production.sql.
-- Company Owner already receives inventory.adjust from the core permission set.

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.organizations o on o.id = r.organization_id and o.code = 'DKIM'
join public.permissions p on p.key = 'inventory.adjust'
where r.key in ('factory_manager', 'warehouse_manager')
on conflict do nothing;
