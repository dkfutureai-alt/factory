\set ON_ERROR_STOP on

-- Deterministic CI-only auth identities.
insert into auth.users (id, email) values
  ('10000000-0000-0000-0000-000000000001', 'owner@factoryos.test'),
  ('20000000-0000-0000-0000-000000000002', 'factory@factoryos.test'),
  ('30000000-0000-0000-0000-000000000003', 'warehouse@factoryos.test'),
  ('40000000-0000-0000-0000-000000000004', 'department@factoryos.test'),
  ('50000000-0000-0000-0000-000000000005', 'suspended@factoryos.test'),
  ('60000000-0000-0000-0000-000000000006', 'invalid@factoryos.test')
on conflict (id) do nothing;

-- A second tenant exists only to prove cross-tenant denial.
insert into public.organizations (code, name, slug)
values ('OTHER', 'Other Tenant Manufacturing', 'other-tenant-manufacturing')
on conflict (code) do update set name=excluded.name;

insert into public.factories (organization_id, code, name, city, state, country_code)
select o.id, 'OTHER-01', 'Other Tenant Plant', 'Mumbai', 'Maharashtra', 'IN'
from public.organizations o where o.code='OTHER'
on conflict (organization_id, code) do update set name=excluded.name;

-- Membership fixtures.
insert into public.organization_memberships (organization_id, user_id, status, activated_at)
select o.id, u.user_id, u.status::public.membership_status,
       case when u.status='active' then now() else null end
from public.organizations o
join (values
  ('DKIM','10000000-0000-0000-0000-000000000001'::uuid,'active'),
  ('DKIM','20000000-0000-0000-0000-000000000002'::uuid,'active'),
  ('DKIM','30000000-0000-0000-0000-000000000003'::uuid,'active'),
  ('DKIM','40000000-0000-0000-0000-000000000004'::uuid,'active'),
  ('DKIM','50000000-0000-0000-0000-000000000005'::uuid,'suspended'),
  ('DKIM','60000000-0000-0000-0000-000000000006'::uuid,'active'),
  ('OTHER','60000000-0000-0000-0000-000000000006'::uuid,'active')
) u(org_code,user_id,status) on u.org_code=o.code
on conflict (organization_id,user_id) do update set status=excluded.status, activated_at=excluded.activated_at;

-- Organization-wide company owner.
insert into public.user_roles (organization_id,user_id,role_id)
select o.id,'10000000-0000-0000-0000-000000000001'::uuid,r.id
from public.organizations o join public.roles r on r.organization_id=o.id and r.key='company_owner'
where o.code='DKIM'
on conflict do nothing;

-- Factory-scoped Factory Manager for PLANT-01 only.
insert into public.user_roles (organization_id,user_id,role_id,factory_id)
select o.id,'20000000-0000-0000-0000-000000000002'::uuid,r.id,f.id
from public.organizations o
join public.roles r on r.organization_id=o.id and r.key='factory_manager'
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
where o.code='DKIM'
on conflict do nothing;

-- Warehouse-scoped Warehouse Manager for RM-WH only.
insert into public.user_roles (organization_id,user_id,role_id,factory_id,warehouse_id)
select o.id,'30000000-0000-0000-0000-000000000003'::uuid,r.id,f.id,w.id
from public.organizations o
join public.roles r on r.organization_id=o.id and r.key='warehouse_manager'
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.warehouses w on w.organization_id=o.id and w.factory_id=f.id and w.code='RM-WH'
where o.code='DKIM'
on conflict do nothing;

-- Department-scoped Production Manager for PROD only.
insert into public.user_roles (organization_id,user_id,role_id,factory_id,department_id)
select o.id,'40000000-0000-0000-0000-000000000004'::uuid,r.id,f.id,d.id
from public.organizations o
join public.roles r on r.organization_id=o.id and r.key='production_manager'
join public.factories f on f.organization_id=o.id and f.code='PLANT-01'
join public.departments d on d.organization_id=o.id and d.factory_id=f.id and d.code='PROD'
where o.code='DKIM'
on conflict do nothing;

-- Suspended membership with an otherwise powerful role must still have no effective permission.
insert into public.user_roles (organization_id,user_id,role_id)
select o.id,'50000000-0000-0000-0000-000000000005'::uuid,r.id
from public.organizations o join public.roles r on r.organization_id=o.id and r.key='company_owner'
where o.code='DKIM'
on conflict do nothing;

-- Deterministic production child fixture. Product demo intentionally has no material
-- requirements, so the RLS child-table assertion needs one CI-only record.
insert into public.production_material_requirements(
  organization_id, production_order_id, item_id, planned_quantity, issued_quantity, returned_quantity
)
select po.organization_id,po.id,i.id,25,0,0
from public.production_orders po
join public.items i on i.organization_id=po.organization_id and i.sku='RM-STEEL-001'
where po.order_number='PRD-2026-01040'
on conflict (production_order_id,item_id) do nothing;

-- Trigger integrity: reject warehouse/factory mismatch and cross-tenant role reuse.
do $$
declare
  o uuid; f2 uuid; w uuid; role_id uuid; other_org uuid;
  failed_as_expected boolean;
begin
  select id into o from public.organizations where code='DKIM';
  select id into f2 from public.factories where organization_id=o and code='PLANT-02';
  select id into w from public.warehouses where organization_id=o and code='RM-WH';
  select id into role_id from public.roles where organization_id=o and key='warehouse_manager';

  failed_as_expected := false;
  begin
    insert into public.user_roles(organization_id,user_id,role_id,factory_id,warehouse_id)
    values(o,'60000000-0000-0000-0000-000000000006'::uuid,role_id,f2,w);
  exception when others then
    failed_as_expected := position('warehouse/factory scope mismatch' in sqlerrm) > 0;
  end;
  if not failed_as_expected then raise exception 'RBAC TEST: mismatched warehouse/factory assignment was not rejected'; end if;

  select id into other_org from public.organizations where code='OTHER';
  failed_as_expected := false;
  begin
    insert into public.user_roles(organization_id,user_id,role_id)
    values(other_org,'60000000-0000-0000-0000-000000000006'::uuid,role_id);
  exception when others then
    failed_as_expected := position('role assignment organization mismatch' in sqlerrm) > 0;
  end;
  if not failed_as_expected then raise exception 'RBAC TEST: cross-tenant role assignment was not rejected'; end if;
end
$$;

-- Helper semantics: narrower scopes never satisfy broader permission checks.
do $$
declare
  o uuid; f1 uuid; f2 uuid; rm_wh uuid; fg_wh uuid; prod_dept uuid; wh_dept uuid;
begin
  select id into o from public.organizations where code='DKIM';
  select id into f1 from public.factories where organization_id=o and code='PLANT-01';
  select id into f2 from public.factories where organization_id=o and code='PLANT-02';
  select id into rm_wh from public.warehouses where organization_id=o and code='RM-WH';
  select id into fg_wh from public.warehouses where organization_id=o and code='FG-WH';
  select id into prod_dept from public.departments where organization_id=o and factory_id=f1 and code='PROD';
  select id into wh_dept from public.departments where organization_id=o and factory_id=f1 and code='WH';

  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
  if not private.has_org_permission(o,'settings.manage') then raise exception 'RBAC TEST: owner lacks organization permission'; end if;
  if not private.has_factory_permission(o,'report.read',f2) then raise exception 'RBAC TEST: org owner should cover every own-tenant factory'; end if;

  perform set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
  if private.has_org_permission(o,'report.read') then raise exception 'RBAC TEST: factory role escalated to organization scope'; end if;
  if private.has_permission(o,'report.read',null) then raise exception 'RBAC TEST: compatibility NULL still escalates factory role'; end if;
  if not private.has_factory_permission(o,'report.read',f1) then raise exception 'RBAC TEST: factory role cannot access assigned factory'; end if;
  if private.has_factory_permission(o,'report.read',f2) then raise exception 'RBAC TEST: factory role crossed factory boundary'; end if;

  perform set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
  if not private.has_any_permission(o,'inventory.read') then raise exception 'RBAC TEST: warehouse role lost granted permission entirely'; end if;
  if private.has_factory_permission(o,'inventory.read',f1) then raise exception 'RBAC TEST: warehouse role escalated to factory scope'; end if;
  if not private.has_warehouse_permission(o,'inventory.read',rm_wh) then raise exception 'RBAC TEST: warehouse role cannot access assigned warehouse'; end if;
  if private.has_warehouse_permission(o,'inventory.read',fg_wh) then raise exception 'RBAC TEST: warehouse role crossed warehouse boundary'; end if;

  perform set_config('request.jwt.claim.sub','40000000-0000-0000-0000-000000000004',false);
  if private.has_factory_permission(o,'production.read',f1) then raise exception 'RBAC TEST: department role escalated to factory scope'; end if;
  if not private.has_department_permission(o,'production.read',prod_dept) then raise exception 'RBAC TEST: department role cannot access assigned department'; end if;
  if private.has_department_permission(o,'production.read',wh_dept) then raise exception 'RBAC TEST: department role crossed department boundary'; end if;

  perform set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000005',false);
  if private.has_org_permission(o,'settings.manage') then raise exception 'RBAC TEST: suspended membership retained permission'; end if;
end
$$;

-- RLS visibility assertions execute as the same authenticated role used by the Data API.
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
set role authenticated;
select (count(*) = 1 and min(code) = 'PLANT-01') as ok from public.factories \gset factory_scope_
\if :factory_scope_ok
\else
  \echo 'RBAC TEST FAILED: factory-scoped manager can see wrong factories'
  select 1/0;
\endif
select (count(*) = 3) as ok from public.warehouses \gset factory_warehouses_
\if :factory_warehouses_ok
\else
  \echo 'RBAC TEST FAILED: factory-scoped manager warehouse visibility is incorrect'
  select 1/0;
\endif
select (count(*) = 1) as ok from public.organization_memberships \gset factory_memberships_
\if :factory_memberships_ok
\else
  \echo 'RBAC TEST FAILED: non-admin can enumerate organization memberships'
  select 1/0;
\endif
select (count(*) = 1) as ok from public.user_roles \gset factory_roles_
\if :factory_roles_ok
\else
  \echo 'RBAC TEST FAILED: non-admin can enumerate role assignments'
  select 1/0;
\endif
select (count(*) > 0) as ok from public.stock_transaction_lines \gset factory_stock_lines_
\if :factory_stock_lines_ok
\else
  \echo 'RBAC TEST FAILED: factory-scoped inventory child rows are inaccessible'
  select 1/0;
\endif
select (count(*) > 0) as ok from public.production_material_requirements \gset factory_prod_children_
\if :factory_prod_children_ok
\else
  \echo 'RBAC TEST FAILED: factory-scoped production child rows are inaccessible'
  select 1/0;
\endif
select (count(*) > 0) as ok from public.purchase_order_lines \gset factory_purchase_children_
\if :factory_purchase_children_ok
\else
  \echo 'RBAC TEST FAILED: factory-scoped purchase child rows are inaccessible'
  select 1/0;
\endif
select (count(*) > 0) as ok from public.sales_order_lines \gset factory_sales_children_
\if :factory_sales_children_ok
\else
  \echo 'RBAC TEST FAILED: factory-scoped sales child rows are inaccessible'
  select 1/0;
\endif
select (count(*) > 0) as ok from public.delivery_lines \gset factory_delivery_children_
\if :factory_delivery_children_ok
\else
  \echo 'RBAC TEST FAILED: factory-scoped delivery child rows are inaccessible'
  select 1/0;
\endif
with updated as (
  update public.organization_modules set is_enabled=is_enabled where module_key='hr' returning 1
)
select (count(*) = 0) as ok from updated \gset factory_org_write_
\if :factory_org_write_ok
\else
  \echo 'RBAC TEST FAILED: factory-scoped role mutated organization-level settings'
  select 1/0;
\endif
reset role;

-- Warehouse-scoped user sees its factory identity and exact warehouse, but not sibling warehouses.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
select (count(*) = 1 and min(code)='PLANT-01') as ok from public.factories \gset warehouse_factory_
\if :warehouse_factory_ok
\else
  \echo 'RBAC TEST FAILED: warehouse-scoped user factory visibility is incorrect'
  select 1/0;
\endif
select (count(*) = 1 and min(code)='RM-WH') as ok from public.warehouses \gset warehouse_exact_
\if :warehouse_exact_ok
\else
  \echo 'RBAC TEST FAILED: warehouse-scoped user crossed warehouse boundary'
  select 1/0;
\endif
reset role;

-- Department-scoped user sees its factory identity and exact department only.
select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-000000000004',false);
set role authenticated;
select (count(*) = 1 and min(code)='PLANT-01') as ok from public.factories \gset department_factory_
\if :department_factory_ok
\else
  \echo 'RBAC TEST FAILED: department-scoped user factory visibility is incorrect'
  select 1/0;
\endif
select (count(*) = 1 and min(code)='PROD') as ok from public.departments \gset department_exact_
\if :department_exact_ok
\else
  \echo 'RBAC TEST FAILED: department-scoped user crossed department boundary'
  select 1/0;
\endif
reset role;

-- Suspended membership sees no factory rows despite retaining a role assignment record.
select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000005',false);
set role authenticated;
select (count(*) = 0) as ok from public.factories \gset suspended_factories_
\if :suspended_factories_ok
\else
  \echo 'RBAC TEST FAILED: suspended membership retained factory visibility'
  select 1/0;
\endif
reset role;

-- Organization owner sees both own-tenant factories but never the second tenant.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
select (count(*) = 2 and bool_and(organization_id=(select id from public.organizations where code='DKIM'))) as ok
from public.factories \gset owner_factories_
\if :owner_factories_ok
\else
  \echo 'RBAC TEST FAILED: organization owner tenant isolation is incorrect'
  select 1/0;
\endif
reset role;

select set_config('request.jwt.claim.sub','',false);
\echo 'RBAC/RLS scope security assertions passed.'
