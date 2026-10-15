\set ON_ERROR_STOP on

-- FactoryOS Purchase Order authoring + approval workflow regressions.
-- Deterministic auth identities/role assignments are created by 01_rbac_scope_security.sql.

select set_config('factoryos.po.f1',(select id::text from public.factories f join public.organizations o on o.id=f.organization_id where o.code='DKIM' and f.code='PLANT-01'),false);
select set_config('factoryos.po.f2',(select id::text from public.factories f join public.organizations o on o.id=f.organization_id where o.code='DKIM' and f.code='PLANT-02'),false);
select set_config('factoryos.po.supplier',(select id::text from public.suppliers s join public.organizations o on o.id=s.organization_id where o.code='DKIM' and s.code='SUP-METALS'),false);
select set_config('factoryos.po.item1',(select id::text from public.items i join public.organizations o on o.id=i.organization_id where o.code='DKIM' and i.sku='RM-STL-304-02'),false);
select set_config('factoryos.po.item2',(select id::text from public.items i join public.organizations o on o.id=i.organization_id where o.code='DKIM' and i.sku='PK-CARTON-014'),false);

-- Raw authenticated clients must not bypass workflow RPCs.
select (not has_table_privilege('authenticated','public.purchase_orders','INSERT')
    and not has_table_privilege('authenticated','public.purchase_orders','UPDATE')
    and not has_table_privilege('authenticated','public.purchase_orders','DELETE')
    and not has_table_privilege('authenticated','public.purchase_order_lines','INSERT')
    and not has_table_privilege('authenticated','public.purchase_order_lines','UPDATE')
    and not has_table_privilege('authenticated','public.purchase_order_lines','DELETE')) as ok \gset grants_
\if :grants_ok
\else
  \echo 'PURCHASE PO TEST FAILED: authenticated raw PO/line DML remains granted'
  select 1/0;
\endif

-- Company Owner creates an audited draft with two validated lines.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
with x as (
  select public.create_purchase_order_draft(
    current_setting('factoryos.po.f1')::uuid,
    current_setting('factoryos.po.supplier')::uuid,
    current_date + 5,
    '30 days from accepted GRN',
    'CI purchase order authoring',
    jsonb_build_array(
      jsonb_build_object('item_id',current_setting('factoryos.po.item1'),'ordered_quantity',12,'unit_price',198,'tax_rate',18),
      jsonb_build_object('item_id',current_setting('factoryos.po.item2'),'ordered_quantity',30,'unit_price',22,'tax_rate',18)
    ),
    'ci-po-create-001'
  ) po
)
select (po).id as po_id,(po).order_number as po_number,(po).revision as po_revision,(po).status::text as po_status from x \gset created_
reset role;
select set_config('factoryos.po.id', :'created_po_id', false);

select (:created_po_revision::int=1 and :'created_po_status'='draft') as ok \gset create_state_
\if :create_state_ok
\else
  \echo 'PURCHASE PO TEST FAILED: create draft state/revision incorrect'
  select 1/0;
\endif
select (count(*)=2) as ok from public.purchase_order_lines where purchase_order_id=current_setting('factoryos.po.id')::uuid \gset create_lines_
\if :create_lines_ok
\else
  \echo 'PURCHASE PO TEST FAILED: draft lines were not created atomically'
  select 1/0;
\endif
select (count(*)=1) as ok from public.audit_logs where entity_type='purchase_order' and entity_id=current_setting('factoryos.po.id') and action='create' \gset create_audit_
\if :create_audit_ok
\else
  \echo 'PURCHASE PO TEST FAILED: create audit missing'
  select 1/0;
\endif

-- Exact create replay returns the same PO and cannot duplicate command side effects.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
with x as (
  select public.create_purchase_order_draft(
    current_setting('factoryos.po.f1')::uuid,current_setting('factoryos.po.supplier')::uuid,current_date + 5,
    '30 days from accepted GRN','CI purchase order authoring',
    jsonb_build_array(
      jsonb_build_object('item_id',current_setting('factoryos.po.item1'),'ordered_quantity',12,'unit_price',198,'tax_rate',18),
      jsonb_build_object('item_id',current_setting('factoryos.po.item2'),'ordered_quantity',30,'unit_price',22,'tax_rate',18)
    ),'ci-po-create-001'
  ) po
)
select ((po).id=current_setting('factoryos.po.id')::uuid) as ok from x \gset create_replay_
reset role;
\if :create_replay_ok
\else
  \echo 'PURCHASE PO TEST FAILED: create idempotency replay changed PO'
  select 1/0;
\endif
select (count(*)=1) as ok from public.purchase_order_command_receipts where idempotency_key='ci-po-create-001' \gset create_receipt_
\if :create_receipt_ok
\else
  \echo 'PURCHASE PO TEST FAILED: create replay duplicated command receipt'
  select 1/0;
\endif

-- Same key with changed payload is rejected.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin
    perform public.create_purchase_order_draft(
      current_setting('factoryos.po.f1')::uuid,current_setting('factoryos.po.supplier')::uuid,current_date + 5,
      '30 days from accepted GRN','different payload',jsonb_build_array(),'ci-po-create-001');
  exception when others then denied := position('idempotency key conflict' in sqlerrm)>0; end;
  if not denied then raise exception 'PURCHASE PO TEST: conflicting create replay was not denied'; end if;
end
$$;
reset role;

-- Owner replaces draft lines under optimistic revision control.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
with x as (
  select public.update_purchase_order_draft(
    current_setting('factoryos.po.id')::uuid,1,current_setting('factoryos.po.supplier')::uuid,current_date + 6,
    '30 days from accepted GRN','CI revised order',
    jsonb_build_array(jsonb_build_object('item_id',current_setting('factoryos.po.item1'),'ordered_quantity',15,'unit_price',197,'tax_rate',18)),
    'ci-po-update-001'
  ) po
)
select (po).revision as revision,(po).status::text as status from x \gset updated_
reset role;
select (:updated_revision::int=2 and :'updated_status'='draft') as ok \gset update_state_
\if :update_state_ok
\else
  \echo 'PURCHASE PO TEST FAILED: update did not increment draft revision'
  select 1/0;
\endif
select (count(*)=1 and min(ordered_quantity)=15 and min(unit_price)=197) as ok
from public.purchase_order_lines where purchase_order_id=current_setting('factoryos.po.id')::uuid \gset update_lines_
\if :update_lines_ok
\else
  \echo 'PURCHASE PO TEST FAILED: update did not replace draft lines'
  select 1/0;
\endif

-- Stale revision update is denied without changing revision/lines.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin
    perform public.update_purchase_order_draft(
      current_setting('factoryos.po.id')::uuid,1,current_setting('factoryos.po.supplier')::uuid,current_date + 6,
      'terms','stale',jsonb_build_array(jsonb_build_object('item_id',current_setting('factoryos.po.item2'),'ordered_quantity',1,'unit_price',22,'tax_rate',18)),
      'ci-po-update-stale');
  exception when others then denied := position('revision conflict' in sqlerrm)>0; end;
  if not denied then raise exception 'PURCHASE PO TEST: stale revision update was not denied'; end if;
end
$$;
reset role;

-- Submit freezes the PO and is retry-safe.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
with x as (select public.submit_purchase_order(current_setting('factoryos.po.id')::uuid,2,'ci-po-submit-001') po)
select (po).revision as revision,(po).status::text as status,(po).submitted_by::text as submitted_by from x \gset submitted_
reset role;
select (:submitted_revision::int=3 and :'submitted_status'='pending_approval' and :'submitted_submitted_by'='10000000-0000-0000-0000-000000000001') as ok \gset submit_state_
\if :submit_state_ok
\else
  \echo 'PURCHASE PO TEST FAILED: submit state/revision/actor incorrect'
  select 1/0;
\endif

-- Trigger must also freeze lines for privileged/direct SQL, not only client grants.
do $$
declare denied boolean:=false;
begin
  begin
    update public.purchase_order_lines set unit_price=unit_price where purchase_order_id=current_setting('factoryos.po.id')::uuid;
  exception when others then denied := position('only while order is draft' in sqlerrm)>0; end;
  if not denied then raise exception 'PURCHASE PO TEST: pending approval lines remained mutable'; end if;
end
$$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
with x as (select public.submit_purchase_order(current_setting('factoryos.po.id')::uuid,2,'ci-po-submit-001') po)
select ((po).id=current_setting('factoryos.po.id')::uuid and (po).status='pending_approval') as ok from x \gset submit_replay_
reset role;
\if :submit_replay_ok
\else
  \echo 'PURCHASE PO TEST FAILED: submit replay was not idempotent after state transition'
  select 1/0;
\endif

-- Factory Manager approves at PLANT-01. This is the state that makes the PO GRN-ready.
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
set role authenticated;
with x as (
  select public.decide_purchase_order(current_setting('factoryos.po.id')::uuid,'approve','Commercials and schedule verified','ci-po-approve-001') po
)
select (po).revision as revision,(po).status::text as status,(po).approved_by::text as approved_by from x \gset approved_
reset role;
select (:approved_revision::int=4 and :'approved_status'='approved' and :'approved_approved_by'='20000000-0000-0000-0000-000000000002') as ok \gset approve_state_
\if :approve_state_ok
\else
  \echo 'PURCHASE PO TEST FAILED: approve state/revision/reviewer incorrect'
  select 1/0;
\endif
select (approved_at is not null and submitted_at is not null) as ok from public.purchase_orders where id=current_setting('factoryos.po.id')::uuid \gset approval_times_
\if :approval_times_ok
\else
  \echo 'PURCHASE PO TEST FAILED: submission/approval timestamps missing'
  select 1/0;
\endif

-- Approval retry after transition returns same PO without duplicate audit/receipt.
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
set role authenticated;
with x as (select public.decide_purchase_order(current_setting('factoryos.po.id')::uuid,'approve','Commercials and schedule verified','ci-po-approve-001') po)
select ((po).status='approved' and (po).revision=4) as ok from x \gset approve_replay_
reset role;
\if :approve_replay_ok
\else
  \echo 'PURCHASE PO TEST FAILED: approval replay was not idempotent'
  select 1/0;
\endif
select (count(*)=1) as ok from public.purchase_order_command_receipts where idempotency_key='ci-po-approve-001' \gset approve_receipt_
\if :approve_receipt_ok
\else
  \echo 'PURCHASE PO TEST FAILED: approval replay duplicated command receipt'
  select 1/0;
\endif

-- Rejection returns a submitted PO to editable draft and records a mandatory reason.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
with x as (
  select public.create_purchase_order_draft(
    current_setting('factoryos.po.f1')::uuid,current_setting('factoryos.po.supplier')::uuid,current_date + 8,
    '30 days','CI reject path',jsonb_build_array(jsonb_build_object('item_id',current_setting('factoryos.po.item2'),'ordered_quantity',5,'unit_price',22,'tax_rate',18)),
    'ci-po-reject-create'
  ) po
)
select (po).id as po_id from x \gset reject_created_
reset role;
select set_config('factoryos.po.reject_id', :'reject_created_po_id', false);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
select public.submit_purchase_order(current_setting('factoryos.po.reject_id')::uuid,1,'ci-po-reject-submit');
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
set role authenticated;
with x as (select public.decide_purchase_order(current_setting('factoryos.po.reject_id')::uuid,'reject','Price exceeds approved sourcing limit','ci-po-reject-decision') po)
select (po).status::text as status,(po).revision as revision,(po).rejection_reason as reason from x \gset rejected_
reset role;
select (:'rejected_status'='draft' and :rejected_revision::int=3 and :'rejected_reason'='Price exceeds approved sourcing limit') as ok \gset reject_state_
\if :reject_state_ok
\else
  \echo 'PURCHASE PO TEST FAILED: rejection did not return order to draft with reason'
  select 1/0;
\endif

-- Empty drafts may be saved, but cannot be submitted.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
with x as (select public.create_purchase_order_draft(
  current_setting('factoryos.po.f1')::uuid,current_setting('factoryos.po.supplier')::uuid,current_date+9,
  '30 days','CI empty draft','[]'::jsonb,'ci-po-empty-create') po)
select (po).id as po_id from x \gset empty_
do $$
declare denied boolean:=false;
begin
  begin perform public.submit_purchase_order(:'empty_po_id'::uuid,1,'ci-po-empty-submit');
  exception when others then denied := position('requires at least one line' in sqlerrm)>0; end;
  if not denied then raise exception 'PURCHASE PO TEST: empty draft submission was not denied'; end if;
end
$$;
reset role;

-- Warehouse Manager has purchase.read but cannot author.
select set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000003',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin perform public.create_purchase_order_draft(
    current_setting('factoryos.po.f1')::uuid,current_setting('factoryos.po.supplier')::uuid,current_date+5,
    '30 days','unauthorized',jsonb_build_array(),'ci-po-warehouse-deny');
  exception when others then denied := position('management permission denied' in sqlerrm)>0; end;
  if not denied then raise exception 'PURCHASE PO TEST: warehouse-scoped reader authored PO'; end if;
end
$$;
reset role;

-- PLANT-01 Factory Manager cannot approve a known PLANT-02 PO UUID.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
set role authenticated;
with x as (select public.create_purchase_order_draft(
  current_setting('factoryos.po.f2')::uuid,current_setting('factoryos.po.supplier')::uuid,current_date+7,
  '30 days','CI cross-factory approval',jsonb_build_array(jsonb_build_object('item_id',current_setting('factoryos.po.item2'),'ordered_quantity',2,'unit_price',22,'tax_rate',18)),
  'ci-po-f2-create') po)
select (po).id as po_id from x \gset f2_
select public.submit_purchase_order(:'f2_po_id'::uuid,1,'ci-po-f2-submit');
reset role;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',false);
set role authenticated;
do $$
declare denied boolean:=false;
begin
  begin perform public.decide_purchase_order(:'f2_po_id'::uuid,'approve','known UUID','ci-po-f2-deny');
  exception when others then denied := position('approval permission denied' in sqlerrm)>0; end;
  if not denied then raise exception 'PURCHASE PO TEST: factory approver crossed factory boundary'; end if;
end
$$;
reset role;

-- Audited transition chain exists exactly once for the accepted PO.
select (count(*)=4) as ok from public.audit_logs
where entity_type='purchase_order' and entity_id=current_setting('factoryos.po.id') and action in ('create','update','submit','approve') \gset audit_chain_
\if :audit_chain_ok
\else
  \echo 'PURCHASE PO TEST FAILED: audited create/update/submit/approve chain incomplete or duplicated'
  select 1/0;
\endif

select set_config('request.jwt.claim.sub','',false);
\echo 'Purchase Order workflow assertions passed.'