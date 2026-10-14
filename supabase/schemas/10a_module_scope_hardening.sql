-- FactoryOS module scope hardening.
-- Apply after 10_notifications.sql.
--
-- Existing module schemas were intentionally built before the final scope model and some child
-- tables used private.has_permission(..., NULL). After 01a, NULL means organization-wide only.
-- This migration preserves least-privilege factory access by resolving child rows through their
-- authoritative parent record instead of widening NULL semantics again.

-- -----------------------------------------------------------------------------
-- Inventory: organization-global catalog + factory-scoped ledger children.
-- -----------------------------------------------------------------------------
drop policy if exists item_categories_select on public.item_categories;
create policy item_categories_select on public.item_categories for select to authenticated
using ((select private.has_any_permission(organization_id, 'inventory.read')));

drop policy if exists item_categories_manage on public.item_categories;
create policy item_categories_manage on public.item_categories for all to authenticated
using ((select private.has_org_permission(organization_id, 'inventory.manage')))
with check ((select private.has_org_permission(organization_id, 'inventory.manage')));

drop policy if exists item_units_select on public.item_units;
create policy item_units_select on public.item_units for select to authenticated
using ((select private.has_any_permission(organization_id, 'inventory.read')));

drop policy if exists item_units_manage on public.item_units;
create policy item_units_manage on public.item_units for all to authenticated
using ((select private.has_org_permission(organization_id, 'inventory.manage')))
with check ((select private.has_org_permission(organization_id, 'inventory.manage')));

drop policy if exists items_select on public.items;
create policy items_select on public.items for select to authenticated
using ((select private.has_any_permission(organization_id, 'inventory.read')));

drop policy if exists items_manage on public.items;
create policy items_manage on public.items for all to authenticated
using ((select private.has_org_permission(organization_id, 'inventory.manage')))
with check ((select private.has_org_permission(organization_id, 'inventory.manage')));

drop policy if exists batches_select on public.batches;
create policy batches_select on public.batches for select to authenticated
using ((select private.has_any_permission(organization_id, 'inventory.read')));

drop policy if exists batches_manage on public.batches;
create policy batches_manage on public.batches for all to authenticated
using ((select private.has_org_permission(organization_id, 'inventory.manage')))
with check ((select private.has_org_permission(organization_id, 'inventory.manage')));

drop policy if exists serial_numbers_select on public.serial_numbers;
create policy serial_numbers_select on public.serial_numbers for select to authenticated
using ((select private.has_any_permission(organization_id, 'inventory.read')));

drop policy if exists serial_numbers_manage on public.serial_numbers;
create policy serial_numbers_manage on public.serial_numbers for all to authenticated
using ((select private.has_org_permission(organization_id, 'inventory.manage')))
with check ((select private.has_org_permission(organization_id, 'inventory.manage')));

drop policy if exists stock_lines_select on public.stock_transaction_lines;
create policy stock_lines_select on public.stock_transaction_lines for select to authenticated
using (
  exists (
    select 1 from public.stock_transactions t
    where t.id = stock_transaction_id
      and t.organization_id = organization_id
      and (select private.has_factory_permission(t.organization_id, 'inventory.read', t.factory_id))
  )
);

drop policy if exists stock_lines_insert on public.stock_transaction_lines;
create policy stock_lines_insert on public.stock_transaction_lines for insert to authenticated
with check (
  exists (
    select 1 from public.stock_transactions t
    where t.id = stock_transaction_id
      and t.organization_id = organization_id
      and t.status = 'draft'
      and (select private.has_factory_permission(t.organization_id, 'inventory.transact', t.factory_id))
  )
);

drop policy if exists stock_lines_update_draft on public.stock_transaction_lines;
create policy stock_lines_update_draft on public.stock_transaction_lines for update to authenticated
using (
  exists (
    select 1 from public.stock_transactions t
    where t.id = stock_transaction_id
      and t.organization_id = organization_id
      and t.status = 'draft'
      and (select private.has_factory_permission(t.organization_id, 'inventory.transact', t.factory_id))
  )
)
with check (
  exists (
    select 1 from public.stock_transactions t
    where t.id = stock_transaction_id
      and t.organization_id = organization_id
      and t.status = 'draft'
      and (select private.has_factory_permission(t.organization_id, 'inventory.transact', t.factory_id))
  )
);

drop policy if exists stock_lines_delete_draft on public.stock_transaction_lines;
create policy stock_lines_delete_draft on public.stock_transaction_lines for delete to authenticated
using (
  exists (
    select 1 from public.stock_transactions t
    where t.id = stock_transaction_id
      and t.organization_id = organization_id
      and t.status = 'draft'
      and (select private.has_factory_permission(t.organization_id, 'inventory.transact', t.factory_id))
  )
);

-- -----------------------------------------------------------------------------
-- Production + quality child tables inherit factory scope from parent records.
-- -----------------------------------------------------------------------------
drop policy if exists production_requirements_select on public.production_material_requirements;
create policy production_requirements_select on public.production_material_requirements for select to authenticated
using (
  exists (
    select 1 from public.production_orders po
    where po.id = production_order_id
      and po.organization_id = organization_id
      and (select private.has_factory_permission(po.organization_id, 'production.read', po.factory_id))
  )
);

drop policy if exists production_requirements_manage on public.production_material_requirements;
create policy production_requirements_manage on public.production_material_requirements for all to authenticated
using (
  exists (
    select 1 from public.production_orders po
    where po.id = production_order_id
      and po.organization_id = organization_id
      and (select private.has_factory_permission(po.organization_id, 'production.manage', po.factory_id))
  )
)
with check (
  exists (
    select 1 from public.production_orders po
    where po.id = production_order_id
      and po.organization_id = organization_id
      and (select private.has_factory_permission(po.organization_id, 'production.manage', po.factory_id))
  )
);

drop policy if exists production_consumption_select on public.production_material_consumption;
create policy production_consumption_select on public.production_material_consumption for select to authenticated
using (
  exists (
    select 1 from public.production_batches pb
    where pb.id = production_batch_id
      and pb.organization_id = organization_id
      and (select private.has_factory_permission(pb.organization_id, 'production.read', pb.factory_id))
  )
);

drop policy if exists production_consumption_manage on public.production_material_consumption;
create policy production_consumption_manage on public.production_material_consumption for all to authenticated
using (
  exists (
    select 1 from public.production_batches pb
    where pb.id = production_batch_id
      and pb.organization_id = organization_id
      and (select private.has_factory_permission(pb.organization_id, 'production.manage', pb.factory_id))
  )
)
with check (
  exists (
    select 1 from public.production_batches pb
    where pb.id = production_batch_id
      and pb.organization_id = organization_id
      and (select private.has_factory_permission(pb.organization_id, 'production.manage', pb.factory_id))
  )
);

drop policy if exists production_outputs_select on public.production_outputs;
create policy production_outputs_select on public.production_outputs for select to authenticated
using (
  exists (
    select 1 from public.production_batches pb
    where pb.id = production_batch_id
      and pb.organization_id = organization_id
      and (select private.has_factory_permission(pb.organization_id, 'production.read', pb.factory_id))
  )
);

drop policy if exists production_outputs_manage on public.production_outputs;
create policy production_outputs_manage on public.production_outputs for all to authenticated
using (
  exists (
    select 1 from public.production_batches pb
    where pb.id = production_batch_id
      and pb.organization_id = organization_id
      and (select private.has_factory_permission(pb.organization_id, 'production.manage', pb.factory_id))
  )
)
with check (
  exists (
    select 1 from public.production_batches pb
    where pb.id = production_batch_id
      and pb.organization_id = organization_id
      and (select private.has_factory_permission(pb.organization_id, 'production.manage', pb.factory_id))
  )
);

drop policy if exists quality_parameters_select on public.quality_check_parameters;
create policy quality_parameters_select on public.quality_check_parameters for select to authenticated
using (
  exists (
    select 1 from public.quality_checks qc
    where qc.id = quality_check_id
      and qc.organization_id = organization_id
      and (select private.has_factory_permission(qc.organization_id, 'quality.read', qc.factory_id))
  )
);

drop policy if exists quality_parameters_manage on public.quality_check_parameters;
create policy quality_parameters_manage on public.quality_check_parameters for all to authenticated
using (
  exists (
    select 1 from public.quality_checks qc
    where qc.id = quality_check_id
      and qc.organization_id = organization_id
      and (select private.has_factory_permission(qc.organization_id, 'quality.manage', qc.factory_id))
  )
)
with check (
  exists (
    select 1 from public.quality_checks qc
    where qc.id = quality_check_id
      and qc.organization_id = organization_id
      and (select private.has_factory_permission(qc.organization_id, 'quality.manage', qc.factory_id))
  )
);

-- -----------------------------------------------------------------------------
-- Purchase: supplier master is shared; order/receipt children inherit factory scope.
-- -----------------------------------------------------------------------------
drop policy if exists suppliers_select on public.suppliers;
create policy suppliers_select on public.suppliers for select to authenticated
using ((select private.has_any_permission(organization_id, 'purchase.read')));

drop policy if exists suppliers_manage on public.suppliers;
create policy suppliers_manage on public.suppliers for all to authenticated
using ((select private.has_any_permission(organization_id, 'purchase.manage')))
with check ((select private.has_any_permission(organization_id, 'purchase.manage')));

drop policy if exists purchase_order_lines_select on public.purchase_order_lines;
create policy purchase_order_lines_select on public.purchase_order_lines for select to authenticated
using (
  exists (
    select 1 from public.purchase_orders po
    where po.id = purchase_order_id
      and po.organization_id = organization_id
      and (select private.has_factory_permission(po.organization_id, 'purchase.read', po.factory_id))
  )
);

drop policy if exists purchase_order_lines_manage on public.purchase_order_lines;
create policy purchase_order_lines_manage on public.purchase_order_lines for all to authenticated
using (
  exists (
    select 1 from public.purchase_orders po
    where po.id = purchase_order_id
      and po.organization_id = organization_id
      and (select private.has_factory_permission(po.organization_id, 'purchase.manage', po.factory_id))
  )
)
with check (
  exists (
    select 1 from public.purchase_orders po
    where po.id = purchase_order_id
      and po.organization_id = organization_id
      and (select private.has_factory_permission(po.organization_id, 'purchase.manage', po.factory_id))
  )
);

drop policy if exists goods_receipt_lines_select on public.goods_receipt_lines;
create policy goods_receipt_lines_select on public.goods_receipt_lines for select to authenticated
using (
  exists (
    select 1 from public.goods_receipts gr
    where gr.id = goods_receipt_id
      and gr.organization_id = organization_id
      and (
        (select private.has_factory_permission(gr.organization_id, 'purchase.read', gr.factory_id))
        or (select private.has_factory_permission(gr.organization_id, 'inventory.read', gr.factory_id))
      )
  )
);

drop policy if exists goods_receipt_lines_manage on public.goods_receipt_lines;
create policy goods_receipt_lines_manage on public.goods_receipt_lines for all to authenticated
using (
  exists (
    select 1 from public.goods_receipts gr
    where gr.id = goods_receipt_id
      and gr.organization_id = organization_id
      and (
        (select private.has_factory_permission(gr.organization_id, 'purchase.manage', gr.factory_id))
        or (select private.has_factory_permission(gr.organization_id, 'inventory.receive', gr.factory_id))
      )
  )
)
with check (
  exists (
    select 1 from public.goods_receipts gr
    where gr.id = goods_receipt_id
      and gr.organization_id = organization_id
      and (
        (select private.has_factory_permission(gr.organization_id, 'purchase.manage', gr.factory_id))
        or (select private.has_factory_permission(gr.organization_id, 'inventory.receive', gr.factory_id))
      )
  )
);

-- -----------------------------------------------------------------------------
-- HR: self-service remains self-only; manager access inherits employee/factory scope.
-- -----------------------------------------------------------------------------
drop policy if exists shifts_read on public.shifts;
create policy shifts_read on public.shifts for select to authenticated
using (
  (factory_id is null and (select private.is_org_member(organization_id)))
  or (factory_id is not null and (select private.can_access_factory(organization_id, factory_id)))
);

drop policy if exists employee_private_read on public.employee_private_details;
create policy employee_private_read on public.employee_private_details for select to authenticated
using (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        e.profile_user_id = (select auth.uid())
        or (e.factory_id is null and (select private.has_org_permission(organization_id, 'employee.sensitive.read')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'employee.sensitive.read', e.factory_id)))
      )
  )
);

drop policy if exists employee_private_manage on public.employee_private_details;
create policy employee_private_manage on public.employee_private_details for all to authenticated
using (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'employee.sensitive.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'employee.sensitive.manage', e.factory_id)))
      )
  )
)
with check (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'employee.sensitive.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'employee.sensitive.manage', e.factory_id)))
      )
  )
);

drop policy if exists attendance_corrections_read on public.attendance_corrections;
create policy attendance_corrections_read on public.attendance_corrections for select to authenticated
using (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        e.profile_user_id = (select auth.uid())
        or (e.factory_id is null and (select private.has_org_permission(organization_id, 'attendance.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'attendance.manage', e.factory_id)))
      )
  )
);

drop policy if exists attendance_corrections_manage on public.attendance_corrections;
create policy attendance_corrections_manage on public.attendance_corrections for update to authenticated
using (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'attendance.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'attendance.manage', e.factory_id)))
      )
  )
)
with check (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'attendance.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'attendance.manage', e.factory_id)))
      )
  )
);

drop policy if exists leave_types_read on public.leave_types;
create policy leave_types_read on public.leave_types for select to authenticated
using ((select private.is_org_member(organization_id)));

drop policy if exists leave_types_manage on public.leave_types;
create policy leave_types_manage on public.leave_types for all to authenticated
using ((select private.has_org_permission(organization_id, 'leave.manage')))
with check ((select private.has_org_permission(organization_id, 'leave.manage')));

drop policy if exists leave_balances_read on public.leave_balances;
create policy leave_balances_read on public.leave_balances for select to authenticated
using (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        e.profile_user_id = (select auth.uid())
        or (e.factory_id is null and (select private.has_org_permission(organization_id, 'leave.read')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'leave.read', e.factory_id)))
      )
  )
);

drop policy if exists leave_balances_manage on public.leave_balances;
create policy leave_balances_manage on public.leave_balances for all to authenticated
using (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'leave.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'leave.manage', e.factory_id)))
      )
  )
)
with check (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'leave.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'leave.manage', e.factory_id)))
      )
  )
);

drop policy if exists holidays_read on public.holidays;
create policy holidays_read on public.holidays for select to authenticated
using (
  (factory_id is null and (select private.is_org_member(organization_id)))
  or (factory_id is not null and (select private.can_access_factory(organization_id, factory_id)))
);

-- -----------------------------------------------------------------------------
-- Sales: shared customer master + order-scoped children and payments.
-- -----------------------------------------------------------------------------
drop policy if exists customers_select on public.customers;
create policy customers_select on public.customers for select to authenticated
using ((select private.has_any_permission(organization_id, 'sales.read')));

drop policy if exists customers_manage on public.customers;
create policy customers_manage on public.customers for all to authenticated
using ((select private.has_any_permission(organization_id, 'sales.manage')))
with check ((select private.has_any_permission(organization_id, 'sales.manage')));

drop policy if exists customer_contacts_select on public.customer_contacts;
create policy customer_contacts_select on public.customer_contacts for select to authenticated
using ((select private.has_any_permission(organization_id, 'sales.read')));

drop policy if exists customer_contacts_manage on public.customer_contacts;
create policy customer_contacts_manage on public.customer_contacts for all to authenticated
using ((select private.has_any_permission(organization_id, 'sales.manage')))
with check ((select private.has_any_permission(organization_id, 'sales.manage')));

drop policy if exists customer_addresses_select on public.customer_delivery_addresses;
create policy customer_addresses_select on public.customer_delivery_addresses for select to authenticated
using ((select private.has_any_permission(organization_id, 'sales.read')));

drop policy if exists customer_addresses_manage on public.customer_delivery_addresses;
create policy customer_addresses_manage on public.customer_delivery_addresses for all to authenticated
using ((select private.has_any_permission(organization_id, 'sales.manage')))
with check ((select private.has_any_permission(organization_id, 'sales.manage')));

drop policy if exists sales_order_lines_select on public.sales_order_lines;
create policy sales_order_lines_select on public.sales_order_lines for select to authenticated
using (
  exists (
    select 1 from public.sales_orders so
    where so.id = sales_order_id
      and so.organization_id = organization_id
      and (select private.has_factory_permission(so.organization_id, 'sales.read', so.factory_id))
  )
);

drop policy if exists sales_order_lines_manage on public.sales_order_lines;
create policy sales_order_lines_manage on public.sales_order_lines for all to authenticated
using (
  exists (
    select 1 from public.sales_orders so
    where so.id = sales_order_id
      and so.organization_id = organization_id
      and (select private.has_factory_permission(so.organization_id, 'sales.manage', so.factory_id))
  )
)
with check (
  exists (
    select 1 from public.sales_orders so
    where so.id = sales_order_id
      and so.organization_id = organization_id
      and (select private.has_factory_permission(so.organization_id, 'sales.manage', so.factory_id))
  )
);

drop policy if exists customer_payments_select on public.customer_payments;
create policy customer_payments_select on public.customer_payments for select to authenticated
using (
  (sales_order_id is null and (select private.has_any_permission(organization_id, 'sales.read')))
  or exists (
    select 1 from public.sales_orders so
    where so.id = sales_order_id
      and so.organization_id = organization_id
      and (select private.has_factory_permission(so.organization_id, 'sales.read', so.factory_id))
  )
);

drop policy if exists customer_payments_manage on public.customer_payments;
create policy customer_payments_manage on public.customer_payments for all to authenticated
using (
  (sales_order_id is null and (select private.has_any_permission(organization_id, 'sales.manage')))
  or exists (
    select 1 from public.sales_orders so
    where so.id = sales_order_id
      and so.organization_id = organization_id
      and (select private.has_factory_permission(so.organization_id, 'sales.manage', so.factory_id))
  )
)
with check (
  (sales_order_id is null and (select private.has_any_permission(organization_id, 'sales.manage')))
  or exists (
    select 1 from public.sales_orders so
    where so.id = sales_order_id
      and so.organization_id = organization_id
      and (select private.has_factory_permission(so.organization_id, 'sales.manage', so.factory_id))
  )
);

-- -----------------------------------------------------------------------------
-- Fleet: document/driver rows inherit vehicle/employee factory scope.
-- -----------------------------------------------------------------------------
drop policy if exists vehicle_documents_select on public.vehicle_documents;
create policy vehicle_documents_select on public.vehicle_documents for select to authenticated
using (
  exists (
    select 1 from public.vehicles v
    where v.id = vehicle_id
      and v.organization_id = organization_id
      and (select private.has_factory_permission(v.organization_id, 'vehicle.read', v.factory_id))
  )
  or exists (
    select 1 from public.vehicle_driver_assignments a
    where a.vehicle_id = vehicle_documents.vehicle_id
      and a.organization_id = vehicle_documents.organization_id
      and a.driver_employee_id = (select private.current_employee_id(vehicle_documents.organization_id))
      and a.assigned_until is null
  )
);

drop policy if exists vehicle_documents_manage on public.vehicle_documents;
create policy vehicle_documents_manage on public.vehicle_documents for all to authenticated
using (
  exists (
    select 1 from public.vehicles v
    where v.id = vehicle_id
      and v.organization_id = organization_id
      and (select private.has_factory_permission(v.organization_id, 'vehicle.manage', v.factory_id))
  )
)
with check (
  exists (
    select 1 from public.vehicles v
    where v.id = vehicle_id
      and v.organization_id = organization_id
      and (select private.has_factory_permission(v.organization_id, 'vehicle.manage', v.factory_id))
  )
);

drop policy if exists driver_profiles_select on public.driver_profiles;
create policy driver_profiles_select on public.driver_profiles for select to authenticated
using (
  employee_id = (select private.current_employee_id(organization_id))
  or exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'vehicle.read')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'vehicle.read', e.factory_id)))
      )
  )
);

drop policy if exists driver_profiles_manage on public.driver_profiles;
create policy driver_profiles_manage on public.driver_profiles for all to authenticated
using (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'vehicle.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'vehicle.manage', e.factory_id)))
      )
  )
)
with check (
  exists (
    select 1 from public.employees e
    where e.id = employee_id
      and e.organization_id = organization_id
      and (
        (e.factory_id is null and (select private.has_org_permission(organization_id, 'vehicle.manage')))
        or (e.factory_id is not null and (select private.has_factory_permission(organization_id, 'vehicle.manage', e.factory_id)))
      )
  )
);

-- -----------------------------------------------------------------------------
-- Delivery: POD/lines/exceptions/events inherit the delivery's factory.
-- -----------------------------------------------------------------------------
drop policy if exists delivery_lines_select on public.delivery_lines;
create policy delivery_lines_select on public.delivery_lines for select to authenticated
using (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (
        (select private.has_factory_permission(d.organization_id, 'delivery.read', d.factory_id))
        or d.driver_employee_id = (select private.current_employee_id(d.organization_id))
      )
  )
);

drop policy if exists delivery_lines_manage on public.delivery_lines;
create policy delivery_lines_manage on public.delivery_lines for all to authenticated
using (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (select private.has_factory_permission(d.organization_id, 'delivery.manage', d.factory_id))
  )
)
with check (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (select private.has_factory_permission(d.organization_id, 'delivery.manage', d.factory_id))
  )
);

drop policy if exists pod_select on public.proof_of_deliveries;
create policy pod_select on public.proof_of_deliveries for select to authenticated
using (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (
        (select private.has_factory_permission(d.organization_id, 'delivery.read', d.factory_id))
        or d.driver_employee_id = (select private.current_employee_id(d.organization_id))
      )
  )
);

drop policy if exists pod_manage on public.proof_of_deliveries;
create policy pod_manage on public.proof_of_deliveries for all to authenticated
using (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (select private.has_factory_permission(d.organization_id, 'delivery.manage', d.factory_id))
  )
)
with check (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (select private.has_factory_permission(d.organization_id, 'delivery.manage', d.factory_id))
  )
);

drop policy if exists delivery_exceptions_select on public.delivery_exceptions;
create policy delivery_exceptions_select on public.delivery_exceptions for select to authenticated
using (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (
        (select private.has_factory_permission(d.organization_id, 'delivery.read', d.factory_id))
        or d.driver_employee_id = (select private.current_employee_id(d.organization_id))
      )
  )
);

drop policy if exists delivery_exceptions_manage on public.delivery_exceptions;
create policy delivery_exceptions_manage on public.delivery_exceptions for all to authenticated
using (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (select private.has_factory_permission(d.organization_id, 'delivery.manage', d.factory_id))
  )
)
with check (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (select private.has_factory_permission(d.organization_id, 'delivery.manage', d.factory_id))
  )
);

drop policy if exists delivery_events_select on public.delivery_events;
create policy delivery_events_select on public.delivery_events for select to authenticated
using (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (
        (select private.has_factory_permission(d.organization_id, 'delivery.read', d.factory_id))
        or d.driver_employee_id = (select private.current_employee_id(d.organization_id))
      )
  )
);

drop policy if exists delivery_events_manage on public.delivery_events;
create policy delivery_events_manage on public.delivery_events for all to authenticated
using (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (select private.has_factory_permission(d.organization_id, 'delivery.manage', d.factory_id))
  )
)
with check (
  exists (
    select 1 from public.deliveries d
    where d.id = delivery_id
      and d.organization_id = organization_id
      and (select private.has_factory_permission(d.organization_id, 'delivery.manage', d.factory_id))
  )
);

-- -----------------------------------------------------------------------------
-- Notifications: shared templates are organization-managed; factory rules remain scoped.
-- -----------------------------------------------------------------------------
drop policy if exists notification_templates_read_member on public.notification_templates;
create policy notification_templates_read_member on public.notification_templates for select to authenticated
using ((select private.has_any_permission(organization_id, 'notification.read')));

drop policy if exists notification_templates_manage on public.notification_templates;
create policy notification_templates_manage on public.notification_templates for all to authenticated
using ((select private.has_org_permission(organization_id, 'notification.manage')))
with check ((select private.has_org_permission(organization_id, 'notification.manage')));
