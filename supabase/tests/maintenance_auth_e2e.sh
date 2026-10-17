#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
EMPLOYEE_EMAIL='e2e-login@factoryos.test'
EMPLOYEE_PASSWORD='Password123!'
MANAGER_EMAIL='e2e-manager@factoryos.test'
MANAGER_PASSWORD='Manager123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ID='42000000-0000-4000-8000-000000000001'
BLOCKED_FACTORY_ID='42000000-0000-4000-8000-000000000002'
EMPLOYEE_ID='46000000-0000-4000-8000-000000000001'
ASSET_ID='6a000000-0000-4000-8000-000000000001'
BLOCKED_ASSET_ID='6a000000-0000-4000-8000-000000000002'
PLAN_ID='6a000000-0000-4000-8000-000000000010'
UNIT_ID='6c000000-0000-4000-8000-000000000001'
ITEM_ID='6d000000-0000-4000-8000-000000000001'
LOCATION_ID='6e000000-0000-4000-8000-000000000001'
OPENING_TX_ID='6f000000-0000-4000-8000-000000000001'

STATUS_ENV="$(supabase status -o env)"
ANON_KEY="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')"
if [[ -z "$ANON_KEY" ]]; then echo 'Could not resolve local anonymous API key.' >&2; exit 1; fi

login() {
  curl -fsS -X POST "$API_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' -d "{\"email\":\"$1\",\"password\":\"$2\"}"
}
rpc() {
  curl -fsS -X POST "$API_URL/rest/v1/rpc/$2" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $1" -H 'Content-Type: application/json' -d "$3"
}
expect_denied() {
  local token="$1" name="$2" payload="$3" label="$4" file status
  file="$(mktemp)"
  status="$(curl -sS -o "$file" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/$name" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$payload")"
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

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.inventory_units(id,organization_id,name,code,decimal_places)
values('$UNIT_ID','$ORG_ID','Piece','MTPCE',0)
on conflict(id) do nothing;

insert into public.inventory_items(id,organization_id,unit_id,sku,name,item_type,is_batch_tracked)
values('$ITEM_ID','$ORG_ID','$UNIT_ID','MNT-E2E-SPARE','Maintenance E2E Bearing','spare',false)
on conflict(id) do nothing;

insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type,is_active)
values('$LOCATION_ID','$ORG_ID','$FACTORY_ID','Maintenance E2E Store','MNT-E2E','warehouse',true)
on conflict(id) do nothing;

insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,to_location_id,unit_cost,external_reference,notes)
values('$OPENING_TX_ID','$ORG_ID','$FACTORY_ID','$ITEM_ID','MNT-E2E-OPEN','opening',10,'$LOCATION_ID',250,'MNT-E2E','Maintenance E2E opening stock')
on conflict(id) do nothing;

insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta,unit_cost)
select '$ORG_ID','$FACTORY_ID','$OPENING_TX_ID','$ITEM_ID','$LOCATION_ID',10,250
where not exists(select 1 from public.stock_ledger_entries where transaction_id='$OPENING_TX_ID');

insert into public.maintenance_assets(id,organization_id,factory_id,asset_code,name,category,criticality,status,meter_type,current_meter,is_active)
values
 ('$ASSET_ID','$ORG_ID','$FACTORY_ID','E2E-PUMP-01','E2E Process Pump','machine','high','active','hours',100,true),
 ('$BLOCKED_ASSET_ID','$ORG_ID','$BLOCKED_FACTORY_ID','E2E-BLOCK-01','Blocked Factory Pump','machine','high','active','hours',50,true)
on conflict(id) do nothing;

insert into public.maintenance_plans(id,organization_id,factory_id,asset_id,plan_code,title,maintenance_type,frequency_days,meter_interval,next_due_at,next_due_meter,is_active)
values('$PLAN_ID','$ORG_ID','$FACTORY_ID','$ASSET_ID','E2E-PM-01','E2E overdue preventive','preventive',30,100,now()-interval '1 day',100,true)
on conflict(id) do nothing;
SQL

expect_denied "$EMPLOYEE_TOKEN" maintenance_create_work_order "{\"p_asset_id\":\"$ASSET_ID\",\"p_work_type\":\"corrective\",\"p_priority\":\"high\",\"p_title\":\"Employee must not plan work\"}" 'employee work-order planning'
expect_denied "$MANAGER_TOKEN" maintenance_create_work_order "{\"p_asset_id\":\"$BLOCKED_ASSET_ID\",\"p_work_type\":\"corrective\",\"p_priority\":\"high\",\"p_title\":\"Cross factory attempt\"}" 'factory manager cross-factory maintenance planning'
expect_denied "$EMPLOYEE_TOKEN" maintenance_report_request "{\"p_asset_id\":\"$BLOCKED_ASSET_ID\",\"p_request_type\":\"breakdown\",\"p_priority\":\"high\",\"p_title\":\"Blocked request\",\"p_description\":\"Must be denied\"}" 'employee cross-factory maintenance request'

REQUEST_ID="$(rpc "$EMPLOYEE_TOKEN" maintenance_report_request "{\"p_asset_id\":\"$ASSET_ID\",\"p_request_type\":\"breakdown\",\"p_priority\":\"high\",\"p_title\":\"Pump bearing noise\",\"p_description\":\"Abnormal bearing noise detected during operation\",\"p_safety_stop\":true}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$REQUEST_ID" ]]
ASSET_AFTER_REQUEST="$(psql "$DB_URL" -Atc "select status from public.maintenance_assets where id='$ASSET_ID'")"
[[ "$ASSET_AFTER_REQUEST" == 'down' ]]
echo 'employee breakdown request + asset-down transition passed'

WORK_ORDER_ID="$(rpc "$MANAGER_TOKEN" maintenance_create_work_order "{\"p_asset_id\":\"$ASSET_ID\",\"p_work_type\":\"breakdown\",\"p_priority\":\"high\",\"p_title\":\"Replace pump bearing\",\"p_description\":\"Inspect coupling and replace failed bearing\",\"p_request_id\":\"$REQUEST_ID\",\"p_assigned_employee_id\":\"$EMPLOYEE_ID\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$WORK_ORDER_ID" ]]

rpc "$EMPLOYEE_TOKEN" maintenance_start_work_order "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_meter_reading\":101,\"p_notes\":\"LOTO applied and work started\"}" >/dev/null
WO_STARTED="$(psql "$DB_URL" -Atc "select status from public.maintenance_work_orders where id='$WORK_ORDER_ID'")"
[[ "$WO_STARTED" == 'in_progress' ]]
ASSET_MAINT="$(psql "$DB_URL" -Atc "select status from public.maintenance_assets where id='$ASSET_ID'")"
[[ "$ASSET_MAINT" == 'maintenance' ]]
echo 'assigned employee work-order start passed'

BALANCE_BEFORE="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$ITEM_ID' and location_id='$LOCATION_ID'")"
USAGE_ID="$(rpc "$EMPLOYEE_TOKEN" maintenance_issue_part "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_item_id\":\"$ITEM_ID\",\"p_from_location_id\":\"$LOCATION_ID\",\"p_quantity\":2,\"p_unit_cost\":250,\"p_notes\":\"Two bearings consumed\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$USAGE_ID" ]]
BALANCE_AFTER="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$ITEM_ID' and location_id='$LOCATION_ID'")"
python3 -c 'before=float("'$BALANCE_BEFORE'"); after=float("'$BALANCE_AFTER'"); assert before-after==2, (before,after); print("maintenance spare usage is Inventory-ledger-backed")'

expect_denied "$EMPLOYEE_TOKEN" maintenance_issue_part "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_item_id\":\"$ITEM_ID\",\"p_from_location_id\":\"$LOCATION_ID\",\"p_quantity\":999}" 'maintenance negative stock'

rpc "$EMPLOYEE_TOKEN" maintenance_hold_work_order "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_reason\":\"Waiting for alignment check\"}" >/dev/null
rpc "$EMPLOYEE_TOKEN" maintenance_resume_work_order "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_notes\":\"Alignment cleared\"}" >/dev/null
rpc "$EMPLOYEE_TOKEN" maintenance_add_work_log "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_message\":\"Bearing replaced and coupling aligned\"}" >/dev/null
rpc "$EMPLOYEE_TOKEN" maintenance_complete_work_order "{\"p_work_order_id\":\"$WORK_ORDER_ID\",\"p_resolution\":\"Bearing replaced, alignment verified and pump test-run passed\",\"p_root_cause\":\"Bearing wear\",\"p_meter_reading\":102}" >/dev/null

FINAL_STATE="$(psql "$DB_URL" -Atc "select w.status||'|'||a.status||'|'||r.status from public.maintenance_work_orders w join public.maintenance_assets a on a.id=w.asset_id join public.maintenance_requests r on r.id=w.request_id where w.id='$WORK_ORDER_ID'")"
[[ "$FINAL_STATE" == 'completed|active|resolved' ]]
PART_TX="$(psql "$DB_URL" -Atc "select count(*) from public.maintenance_part_usages where work_order_id='$WORK_ORDER_ID' and inventory_transaction_id is not null")"
[[ "$PART_TX" == '1' ]]
DOWNTIME_CLOSED="$(psql "$DB_URL" -Atc "select count(*) from public.maintenance_downtime_events where work_order_id='$WORK_ORDER_ID' and ended_at is not null and duration_minutes is not null")"
[[ "$DOWNTIME_CLOSED" == '1' ]]
echo 'assigned technician start → parts → hold/resume → complete lifecycle passed'

GENERATED="$(rpc "$MANAGER_TOKEN" maintenance_generate_due_work_orders "{\"p_factory_id\":\"$FACTORY_ID\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
python3 -c 'value=int("'$GENERATED'"); assert value>=1, value; print("due preventive work generation passed")'
PLAN_WO="$(psql "$DB_URL" -Atc "select count(*) from public.maintenance_work_orders where plan_id='$PLAN_ID' and status in ('planned','assigned','in_progress','on_hold')")"
[[ "$PLAN_WO" == '1' ]]

EMPLOYEE_ASSETS="$(curl -fsS "$API_URL/rest/v1/maintenance_assets?select=id,factory_id&order=asset_code" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN")"
python3 -c 'import json,sys; allowed=sys.argv[1]; blocked=sys.argv[2]; rows=json.load(sys.stdin); ids={r["id"] for r in rows}; assert allowed in ids and blocked not in ids, rows; print("maintenance asset RLS factory isolation passed")' "$ASSET_ID" "$BLOCKED_ASSET_ID" <<<"$EMPLOYEE_ASSETS"

expect_denied "$EMPLOYEE_TOKEN" maintenance_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\"}" 'employee organization-wide maintenance dashboard'
DASHBOARD="$(rpc "$EMPLOYEE_TOKEN" maintenance_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert int(row["assets"])>=1 and int(row["completed_last_30_days"])>=1, row; print("factory-scoped maintenance dashboard passed")' <<<"$DASHBOARD"
REPORT="$(rpc "$MANAGER_TOKEN" maintenance_work_order_report "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\",\"p_limit\":50}")"
python3 -c 'import json,sys; target=sys.argv[1]; rows=json.load(sys.stdin); assert any(r["work_order_id"]==target and r["status"]=="completed" for r in rows), rows; print("maintenance work-order report passed")' "$WORK_ORDER_ID" <<<"$REPORT"

echo 'maintenance authenticated E2E checks passed'
