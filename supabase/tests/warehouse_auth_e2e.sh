#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
MANAGER_EMAIL='commercial-manager@factoryos.test'
MANAGER_PASSWORD='CommercialManager123!'
SUPERVISOR_EMAIL='commercial-supervisor@factoryos.test'
SUPERVISOR_PASSWORD='CommercialSupervisor123!'
EMPLOYEE_EMAIL='commercial-employee@factoryos.test'
EMPLOYEE_PASSWORD='CommercialEmployee123!'
ORG_ID='a1000000-0000-4000-8000-000000000001'
FACTORY_ID='a2000000-0000-4000-8000-000000000001'
BLOCKED_FACTORY_ID='a2000000-0000-4000-8000-000000000002'
RAW_ITEM_ID='a3200000-0000-4000-8000-000000000001'
FINISHED_ITEM_ID='a3200000-0000-4000-8000-000000000002'
STORE_ID='a3300000-0000-4000-8000-000000000002'
FG_ID='a3300000-0000-4000-8000-000000000003'
ZONE_ID='b1000000-0000-4000-8000-000000000001'
BIN_ID='b1000000-0000-4000-8000-000000000002'
STAGING_ID='b1000000-0000-4000-8000-000000000003'
BLOCKED_STORE_ID='b1000000-0000-4000-8000-000000000004'
BLOCKED_BIN_ID='b1000000-0000-4000-8000-000000000005'

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
  if [[ "$status" == 2* ]]; then echo "$label unexpectedly succeeded." >&2; cat "$file" >&2; rm -f "$file"; exit 1; fi
  rm -f "$file"
  echo "$label denial passed"
}

MANAGER_TOKEN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
SUPERVISOR_TOKEN="$(login "$SUPERVISOR_EMAIL" "$SUPERVISOR_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
EMPLOYEE_TOKEN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"

SO_ID="$(psql "$DB_URL" -Atc "select id from public.sales_orders where organization_id='$ORG_ID' and factory_id='$FACTORY_ID' and status='dispatch_ready' order by created_at desc limit 1")"
if [[ -z "$SO_ID" ]]; then echo 'Phase 7 authenticated sales order fixture is required before Warehouse E2E.' >&2; exit 1; fi

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type,parent_location_id,capacity_quantity) values
 ('$ZONE_ID','$ORG_ID','$FACTORY_ID','E2E Raw Zone','E2E-WZ','zone','$STORE_ID',100),
 ('$BIN_ID','$ORG_ID','$FACTORY_ID','E2E Raw Bin','E2E-WBIN','bin','$ZONE_ID',50),
 ('$STAGING_ID','$ORG_ID','$FACTORY_ID','E2E Dispatch Staging','E2E-STAGE','staging','$FG_ID',50),
 ('$BLOCKED_STORE_ID','$ORG_ID','$BLOCKED_FACTORY_ID','Blocked Warehouse','E2E-BW','warehouse',null,50),
 ('$BLOCKED_BIN_ID','$ORG_ID','$BLOCKED_FACTORY_ID','Blocked Bin','E2E-BBIN','bin','$BLOCKED_STORE_ID',50);
SQL

echo 'warehouse zone/bin/staging hierarchy fixture created'

PUTAWAY_ID="$(rpc "$SUPERVISOR_TOKEN" warehouse_create_putaway_task "{\"p_factory_id\":\"$FACTORY_ID\",\"p_item_id\":\"$RAW_ITEM_ID\",\"p_source_location_id\":\"$STORE_ID\",\"p_target_location_id\":\"$BIN_ID\",\"p_quantity\":2,\"p_notes\":\"Warehouse E2E putaway\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$PUTAWAY_ID" ]]
rpc "$EMPLOYEE_TOKEN" warehouse_start_putaway "{\"p_task_id\":\"$PUTAWAY_ID\"}" >/dev/null
PUTAWAY_TX="$(rpc "$EMPLOYEE_TOKEN" warehouse_complete_putaway "{\"p_task_id\":\"$PUTAWAY_ID\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$PUTAWAY_TX" ]]
PUTAWAY_STATUS="$(psql "$DB_URL" -Atc "select status from public.warehouse_putaway_tasks where id='$PUTAWAY_ID'")"
[[ "$PUTAWAY_STATUS" == 'completed' ]]
BIN_BALANCE="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$RAW_ITEM_ID' and location_id='$BIN_ID'")"
[[ "$BIN_BALANCE" == '2.0000' || "$BIN_BALANCE" == '2' ]]
echo 'supervisor planned + employee completed ledger-backed put-away passed'

expect_denied "$EMPLOYEE_TOKEN" warehouse_create_pick_list "{\"p_sales_order_id\":\"$SO_ID\",\"p_staging_location_id\":\"$STAGING_ID\",\"p_priority\":\"high\"}" 'employee pick-list planning'
PICK_ID="$(rpc "$SUPERVISOR_TOKEN" warehouse_create_pick_list "{\"p_sales_order_id\":\"$SO_ID\",\"p_staging_location_id\":\"$STAGING_ID\",\"p_priority\":\"high\",\"p_notes\":\"Warehouse E2E pick\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$PICK_ID" ]]
rpc "$EMPLOYEE_TOKEN" warehouse_start_pick_list "{\"p_pick_list_id\":\"$PICK_ID\"}" >/dev/null
PICK_LINE_ID="$(psql "$DB_URL" -Atc "select id from public.warehouse_pick_lines where pick_list_id='$PICK_ID' order by created_at limit 1")"
[[ -n "$PICK_LINE_ID" ]]
PICK_TX="$(rpc "$EMPLOYEE_TOKEN" warehouse_confirm_pick_line "{\"p_pick_line_id\":\"$PICK_LINE_ID\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$PICK_TX" ]]
PICK_STATUS="$(psql "$DB_URL" -Atc "select status from public.warehouse_pick_lists where id='$PICK_ID'")"
[[ "$PICK_STATUS" == 'picked' ]]
HANDOFF_ID="$(rpc "$EMPLOYEE_TOKEN" warehouse_stage_pick_list "{\"p_pick_list_id\":\"$PICK_ID\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$HANDOFF_ID" ]]
rpc "$SUPERVISOR_TOKEN" warehouse_handoff_pick_list "{\"p_pick_list_id\":\"$PICK_ID\",\"p_notes\":\"Ready for dispatch module\"}" >/dev/null
HANDOFF_STATUS="$(psql "$DB_URL" -Atc "select status from public.warehouse_dispatch_handoffs where id='$HANDOFF_ID'")"
[[ "$HANDOFF_STATUS" == 'handed_off' ]]
ALLOC_LOCATION="$(psql "$DB_URL" -Atc "select location_id from public.sales_allocations where sales_order_id='$SO_ID' and status='allocated' limit 1")"
[[ "$ALLOC_LOCATION" == "$STAGING_ID" ]]
STAGING_BALANCE="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$FINISHED_ITEM_ID' and location_id='$STAGING_ID'")"
[[ "$STAGING_BALANCE" == '3.0000' || "$STAGING_BALANCE" == '3' ]]
echo 'pick → staging → dispatch handoff and allocation-location sync passed'

COUNT_ID="$(rpc "$SUPERVISOR_TOKEN" warehouse_create_cycle_count "{\"p_factory_id\":\"$FACTORY_ID\",\"p_location_id\":\"$BIN_ID\",\"p_notes\":\"Warehouse E2E cycle count\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
COUNT_LINE_ID="$(psql "$DB_URL" -Atc "select id from public.warehouse_cycle_count_lines where cycle_count_id='$COUNT_ID' limit 1")"
rpc "$EMPLOYEE_TOKEN" warehouse_record_cycle_count_line "{\"p_line_id\":\"$COUNT_LINE_ID\",\"p_counted_quantity\":2,\"p_notes\":\"Exact E2E count\"}" >/dev/null
rpc "$EMPLOYEE_TOKEN" warehouse_submit_cycle_count "{\"p_cycle_count_id\":\"$COUNT_ID\"}" >/dev/null
expect_denied "$EMPLOYEE_TOKEN" warehouse_approve_cycle_count "{\"p_cycle_count_id\":\"$COUNT_ID\"}" 'employee cycle-count approval'
rpc "$MANAGER_TOKEN" warehouse_approve_cycle_count "{\"p_cycle_count_id\":\"$COUNT_ID\"}" >/dev/null
COUNT_STATUS="$(psql "$DB_URL" -Atc "select status from public.warehouse_cycle_counts where id='$COUNT_ID'")"
[[ "$COUNT_STATUS" == 'approved' ]]
echo 'employee count + manager cycle-count approval passed'

expect_denied "$EMPLOYEE_TOKEN" warehouse_adjust_stock "{\"p_factory_id\":\"$FACTORY_ID\",\"p_item_id\":\"$RAW_ITEM_ID\",\"p_location_id\":\"$BIN_ID\",\"p_quantity_delta\":1,\"p_reason\":\"Employee must not adjust\"}" 'employee manual stock adjustment'
ADJUST_ID="$(rpc "$MANAGER_TOKEN" warehouse_adjust_stock "{\"p_factory_id\":\"$FACTORY_ID\",\"p_item_id\":\"$RAW_ITEM_ID\",\"p_location_id\":\"$BIN_ID\",\"p_quantity_delta\":1,\"p_reason\":\"E2E approved variance\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$ADJUST_ID" ]]
BIN_BALANCE_AFTER="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$RAW_ITEM_ID' and location_id='$BIN_ID'")"
[[ "$BIN_BALANCE_AFTER" == '3.0000' || "$BIN_BALANCE_AFTER" == '3' ]]
echo 'manager immutable ledger-backed warehouse adjustment passed'

expect_denied "$MANAGER_TOKEN" warehouse_create_putaway_task "{\"p_factory_id\":\"$BLOCKED_FACTORY_ID\",\"p_item_id\":\"$RAW_ITEM_ID\",\"p_source_location_id\":\"$BLOCKED_STORE_ID\",\"p_target_location_id\":\"$BLOCKED_BIN_ID\",\"p_quantity\":1}" 'factory manager cross-factory warehouse planning'

DASHBOARD="$(rpc "$MANAGER_TOKEN" warehouse_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert int(row["bins"])>=1 and int(row["zones"])>=1, row; print("warehouse dashboard report passed")' <<<"$DASHBOARD"
STOCK_REPORT="$(rpc "$MANAGER_TOKEN" warehouse_bin_stock_report "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; bin_id=sys.argv[1]; staging=sys.argv[2]; rows=json.load(sys.stdin); ids={r["location_id"] for r in rows}; assert bin_id in ids and staging in ids, rows; print("warehouse ledger/reservation stock report passed")' "$BIN_ID" "$STAGING_ID" <<<"$STOCK_REPORT"

echo 'authenticated warehouse E2E flow passed'
