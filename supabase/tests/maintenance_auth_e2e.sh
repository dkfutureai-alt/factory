#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
MANAGER_EMAIL='e2e-manager@factoryos.test'
MANAGER_PASSWORD='Manager123!'
EMPLOYEE_EMAIL='e2e-login@factoryos.test'
EMPLOYEE_PASSWORD='Password123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ID='42000000-0000-4000-8000-000000000001'
BLOCKED_FACTORY_ID='42000000-0000-4000-8000-000000000002'
EMPLOYEE_ID='46000000-0000-4000-8000-000000000001'
INV_CATEGORY_ID='50000000-0000-4000-8000-000000000001'
INV_UNIT_ID='51000000-0000-4000-8000-000000000001'
INV_SOURCE_ID='53000000-0000-4000-8000-000000000001'
SPARE_ITEM_ID='ab110000-0000-4000-8000-000000000001'

STATUS_ENV="$(supabase status -o env)"
ANON_KEY="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')"
if [[ -z "$ANON_KEY" ]]; then echo 'Could not resolve local anonymous API key.' >&2; exit 1; fi

login() {
  curl -fsS -X POST "$API_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}"
}
rpc_checked() {
  local token="$1" name="$2" payload="$3" file status
  file="$(mktemp)"
  status="$(curl -sS -o "$file" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/$name" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -d "$payload")"
  if [[ "$status" != 2* ]]; then
    echo "$name failed with HTTP $status" >&2
    cat "$file" >&2
    rm -f "$file"
    return 1
  fi
  cat "$file"
  rm -f "$file"
}
expect_denied() {
  local token="$1" name="$2" payload="$3" label="$4" file status
  file="$(mktemp)"
  status="$(curl -sS -o "$file" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/$name" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -d "$payload")"
  if [[ "$status" == 2* ]]; then
    echo "$label unexpectedly succeeded." >&2
    cat "$file" >&2
    rm -f "$file"
    exit 1
  fi
  rm -f "$file"
  echo "$label denial passed"
}

MANAGER_TOKEN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
EMPLOYEE_TOKEN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
TODAY="$(psql "$DB_URL" -Atc 'select current_date')"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.inventory_items(id,organization_id,category_id,unit_id,sku,name,item_type,barcode,qr_code,is_batch_tracked)
values('$SPARE_ITEM_ID','$ORG_ID','$INV_CATEGORY_ID','$INV_UNIT_ID','E2E-MAINT-SPARE','E2E Maintenance Spare','spare','E2E-MAINT-SPARE-BC','E2E:MAINT:SPARE',false);
SQL

rpc_checked "$MANAGER_TOKEN" inventory_receive_stock "{\"p_factory_id\":\"$FACTORY_ID\",\"p_item_id\":\"$SPARE_ITEM_ID\",\"p_to_location_id\":\"$INV_SOURCE_ID\",\"p_quantity\":5,\"p_unit_cost\":50,\"p_external_reference\":\"E2E-MAINT-RCV\"}" >/dev/null

expect_denied "$EMPLOYEE_TOKEN" maintenance_create_asset "{\"p_factory_id\":\"$FACTORY_ID\",\"p_asset_code\":\"EMP-DENY\",\"p_name\":\"Employee Denied Asset\",\"p_asset_type\":\"equipment\",\"p_work_center_id\":null,\"p_location_id\":null,\"p_manufacturer\":null,\"p_model\":null,\"p_serial_no\":null,\"p_criticality\":\"medium\",\"p_qr_code\":null,\"p_notes\":null}" 'employee maintenance asset creation'
expect_denied "$MANAGER_TOKEN" maintenance_create_asset "{\"p_factory_id\":\"$BLOCKED_FACTORY_ID\",\"p_asset_code\":\"BLOCK-DENY\",\"p_name\":\"Blocked Factory Asset\",\"p_asset_type\":\"equipment\",\"p_work_center_id\":null,\"p_location_id\":null,\"p_manufacturer\":null,\"p_model\":null,\"p_serial_no\":null,\"p_criticality\":\"medium\",\"p_qr_code\":null,\"p_notes\":null}" 'factory manager blocked-factory maintenance asset creation'

ASSET_RESPONSE="$(rpc_checked "$MANAGER_TOKEN" maintenance_create_asset "{\"p_factory_id\":\"$FACTORY_ID\",\"p_asset_code\":\"E2E-MNT-01\",\"p_name\":\"E2E Maintenance Pump\",\"p_asset_type\":\"equipment\",\"p_work_center_id\":null,\"p_location_id\":\"$INV_SOURCE_ID\",\"p_manufacturer\":\"E2E Demo\",\"p_model\":\"P-100\",\"p_serial_no\":\"E2E-SN-001\",\"p_criticality\":\"high\",\"p_qr_code\":\"E2E:ASSET:MNT-01\",\"p_notes\":\"Maintenance E2E asset\"}")"
ASSET_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$ASSET_RESPONSE")"
[[ -n "$ASSET_ID" ]]
echo 'manager maintenance asset creation passed'

EMP_ASSET_ROWS="$(curl -fsS "$API_URL/rest/v1/maintenance_assets?select=id,asset_code,status&id=eq.$ASSET_ID" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN")"
python3 -c 'import json,sys; expected=sys.argv[1]; rows=json.load(sys.stdin); assert len(rows)==1 and rows[0]["id"]==expected, rows; print("employee asset visibility passed")' "$ASSET_ID" <<<"$EMP_ASSET_ROWS"

REQUEST_RESPONSE="$(rpc_checked "$EMPLOYEE_TOKEN" maintenance_create_request "{\"p_asset_id\":\"$ASSET_ID\",\"p_issue_type\":\"noise\",\"p_priority\":\"high\",\"p_description\":\"Bearing noise during operation\"}")"
REQUEST_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$REQUEST_RESPONSE")"
[[ -n "$REQUEST_ID" ]]
REQUEST_STATE="$(psql "$DB_URL" -Atc "select status||'|'||requested_by_employee_id from public.maintenance_requests where id='$REQUEST_ID'")"
[[ "$REQUEST_STATE" == "open|$EMPLOYEE_ID" ]]
echo 'employee maintenance request passed'

PLAN_RESPONSE="$(rpc_checked "$MANAGER_TOKEN" maintenance_create_plan "{\"p_asset_id\":\"$ASSET_ID\",\"p_name\":\"E2E Weekly PM\",\"p_maintenance_type\":\"preventive\",\"p_frequency_unit\":\"weeks\",\"p_frequency_value\":1,\"p_next_due_date\":\"$TODAY\",\"p_default_technician_employee_id\":\"$EMPLOYEE_ID\",\"p_default_priority\":\"high\",\"p_estimated_minutes\":45,\"p_instructions\":\"Perform weekly pump PM\"}")"
PLAN_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$PLAN_RESPONSE")"
[[ -n "$PLAN_ID" ]]
rpc_checked "$MANAGER_TOKEN" maintenance_add_plan_task "{\"p_plan_id\":\"$PLAN_ID\",\"p_instruction\":\"Inspect bearing and coupling\",\"p_is_required\":true}" >/dev/null
rpc_checked "$MANAGER_TOKEN" maintenance_add_plan_task "{\"p_plan_id\":\"$PLAN_ID\",\"p_instruction\":\"Check mounting bolts\",\"p_is_required\":true}" >/dev/null

GENERATED="$(rpc_checked "$MANAGER_TOKEN" maintenance_generate_due_work_orders "{\"p_factory_id\":\"$FACTORY_ID\",\"p_horizon_days\":7}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
python3 -c 'import sys; assert int(sys.argv[1])>=1, sys.argv; print("preventive work-order generation passed")' "$GENERATED"
WORK_ORDER_ID="$(psql "$DB_URL" -Atc "select id from public.maintenance_work_orders where plan_id='$PLAN_ID' and status='assigned' limit 1")"
[[ -n "$WORK_ORDER_ID" ]]

EMP_WO_ROWS="$(curl -fsS "$API_URL/rest/v1/maintenance_work_orders?select=id,status,assigned_employee_id&id=eq.$WORK_ORDER_ID" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN")"
python3 -c 'import json,sys; expected=sys.argv[1]; employee=sys.argv[2]; rows=json.load(sys.stdin); assert len(rows)==1 and rows[0]["id"]==expected and rows[0]["assigned_employee_id"]==employee, rows; print("assigned technician work-order visibility passed")' "$WORK_ORDER_ID" "$EMPLOYEE_ID" <<<"$EMP_WO_ROWS"

expect_denied "$EMPLOYEE_TOKEN" maintenance_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}" 'employee aggregate maintenance dashboard'
expect_denied "$MANAGER_TOKEN" maintenance_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$BLOCKED_FACTORY_ID\"}" 'factory manager blocked-factory maintenance dashboard'

rpc_checked "$EMPLOYEE_TOKEN" maintenance_start_work_order "{\"p_work_order_id\":\"$WORK_ORDER_ID\"}" >/dev/null
DOWNTIME_RESPONSE="$(rpc_checked "$EMPLOYEE_TOKEN" maintenance_start_downtime "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_reason\":\"Pump stopped for preventive inspection\"}")"
DOWNTIME_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$DOWNTIME_RESPONSE")"
[[ -n "$DOWNTIME_ID" ]]

SPARE_RESPONSE="$(rpc_checked "$EMPLOYEE_TOKEN" maintenance_use_spare "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_item_id\":\"$SPARE_ITEM_ID\",\"p_source_location_id\":\"$INV_SOURCE_ID\",\"p_quantity\":2,\"p_unit_cost\":50,\"p_note\":\"Replaced two worn inserts\"}")"
SPARE_USAGE_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$SPARE_RESPONSE")"
[[ -n "$SPARE_USAGE_ID" ]]
SPARE_BALANCE="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$SPARE_ITEM_ID' and location_id='$INV_SOURCE_ID'")"
python3 -c 'import sys; assert float(sys.argv[1])==3.0, sys.argv; print("maintenance spare ledger issue passed")' "$SPARE_BALANCE"

rpc_checked "$EMPLOYEE_TOKEN" maintenance_add_update "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_note\":\"Bearing inspected and spare inserts replaced\",\"p_photo_ref\":null}" >/dev/null
rpc_checked "$EMPLOYEE_TOKEN" maintenance_end_downtime "{\"p_downtime_id\":\"$DOWNTIME_ID\"}" >/dev/null

TASK_IDS="$(psql "$DB_URL" -Atc "select id from public.maintenance_work_order_tasks where work_order_id='$WORK_ORDER_ID' order by sequence_no")"
while IFS= read -r TASK_ID; do
  [[ -z "$TASK_ID" ]] && continue
  rpc_checked "$EMPLOYEE_TOKEN" maintenance_set_task "{\"p_task_id\":\"$TASK_ID\",\"p_completed\":true}" >/dev/null
done <<<"$TASK_IDS"

rpc_checked "$EMPLOYEE_TOKEN" maintenance_complete_work_order "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_resolution_notes\":\"Preventive inspection completed; bearing and mounting condition acceptable\",\"p_labor_minutes\":45,\"p_external_cost\":0}" >/dev/null

FINAL_STATE="$(psql "$DB_URL" -Atc "select w.status||'|'||a.status from public.maintenance_work_orders w join public.maintenance_assets a on a.id=w.asset_id where w.id='$WORK_ORDER_ID'")"
[[ "$FINAL_STATE" == 'completed|running' ]]
NEXT_DUE="$(psql "$DB_URL" -Atc "select next_due_date from public.maintenance_plans where id='$PLAN_ID'")"
python3 -c 'import datetime,sys; assert datetime.date.fromisoformat(sys.argv[1])>datetime.date.fromisoformat(sys.argv[2]); print("preventive next-due advancement passed")' "$NEXT_DUE" "$TODAY"

SUMMARY="$(rpc_checked "$MANAGER_TOKEN" maintenance_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert "assets_total" in row and "completed_month" in row and "downtime_minutes_month" in row and "spare_cost_month" in row, row; print("maintenance dashboard summary passed")' <<<"$SUMMARY"

AUDIT_COUNT="$(psql "$DB_URL" -Atc "select count(*) from public.audit_logs where entity_type='maintenance_work_orders' and entity_id='$WORK_ORDER_ID'")"
python3 -c 'import sys; assert int(sys.argv[1])>=2, sys.argv; print("maintenance work-order audit logging passed")' "$AUDIT_COUNT"

echo 'Maintenance authenticated E2E passed'
