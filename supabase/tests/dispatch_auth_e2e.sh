#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
MANAGER_EMAIL='e2e-manager@factoryos.test'
MANAGER_PASSWORD='Manager123!'
DRIVER_EMAIL='fleet-driver@factoryos.test'
DRIVER_PASSWORD='FleetDriver123!'
EMPLOYEE_EMAIL='e2e-login@factoryos.test'
EMPLOYEE_PASSWORD='Password123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ID='42000000-0000-4000-8000-000000000001'
BLOCKED_FACTORY_ID='42000000-0000-4000-8000-000000000002'
INV_CATEGORY_ID='50000000-0000-4000-8000-000000000001'
INV_UNIT_ID='51000000-0000-4000-8000-000000000001'
INV_ITEM_ID='52000000-0000-4000-8000-000000000001'
INV_SOURCE_ID='53000000-0000-4000-8000-000000000001'
STAGING_ID='99100000-0000-4000-8000-000000000001'
RETURN_ITEM_ID='99100000-0000-4000-8000-000000000002'
CUSTOMER_ID='99100000-0000-4000-8000-000000000003'
SALES_ORDER_ID='99100000-0000-4000-8000-000000000004'
SALES_LINE_ID='99100000-0000-4000-8000-000000000005'
ALLOCATION_ID='99100000-0000-4000-8000-000000000006'
PICK_LIST_ID='99100000-0000-4000-8000-000000000007'
PICK_LINE_ID='99100000-0000-4000-8000-000000000008'
HANDOFF_ID='99100000-0000-4000-8000-000000000009'

STATUS_ENV="$(supabase status -o env)"
ANON_KEY="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')"
if [[ -z "$ANON_KEY" ]]; then echo 'Could not resolve local anonymous API key.' >&2; exit 1; fi

login() {
  curl -fsS -X POST "$API_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}"
}
rpc() {
  curl -fsS -X POST "$API_URL/rest/v1/rpc/$2" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -d "$3"
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
DRIVER_TOKEN="$(login "$DRIVER_EMAIL" "$DRIVER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
EMPLOYEE_TOKEN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"

VEHICLE_ID="$(psql "$DB_URL" -Atc "select id from public.fleet_vehicles where factory_id='$FACTORY_ID' and vehicle_code='E2ETRK' limit 1")"
DRIVER_ID="$(psql "$DB_URL" -Atc "select id from public.fleet_drivers where factory_id='$FACTORY_ID' and employee_id='48000000-0000-4000-8000-000000000001' limit 1")"
VEHICLE_LOCATION_ID="$(psql "$DB_URL" -Atc "select stock_location_id from public.fleet_vehicles where id='$VEHICLE_ID'")"
if [[ -z "$VEHICLE_ID" || -z "$DRIVER_ID" || -z "$VEHICLE_LOCATION_ID" ]]; then
  echo 'Phase 9 Fleet E2E fixture was not found.' >&2
  exit 1
fi

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type,is_active)
values('$STAGING_ID','$ORG_ID','$FACTORY_ID','Dispatch E2E Staging','DSP-E2E','staging',true);

insert into public.inventory_items(
  id,organization_id,category_id,unit_id,sku,name,item_type,is_returnable,is_active
) values(
  '$RETURN_ITEM_ID','$ORG_ID','$INV_CATEGORY_ID','$INV_UNIT_ID','E2E-EMPTY-CYL','E2E Empty Returnable Cylinder','cylinder',true,true
);

insert into public.business_partners(
  id,organization_id,partner_code,name,partner_type,contact_person,phone,address_line1,city,state,country_code
) values(
  '$CUSTOMER_ID','$ORG_ID','E2E-CUS-DSP','E2E Dispatch Customer','customer','E2E Receiver','+91 90000 30001','E2E Customer Site','Solapur','Maharashtra','IN'
);

insert into public.sales_orders(
  id,organization_id,factory_id,sales_order_no,customer_id,order_date,requested_delivery_date,status,dispatch_ready_at,notes
) values(
  '$SALES_ORDER_ID','$ORG_ID','$FACTORY_ID','SO-E2E-DSP-001','$CUSTOMER_ID',current_date,current_date,'dispatch_ready',now(),'Dispatch E2E sales order'
);

insert into public.sales_order_lines(
  id,organization_id,sales_order_id,item_id,ordered_quantity,unit_price,tax_rate,allocated_quantity,dispatched_quantity,notes
) values(
  '$SALES_LINE_ID','$ORG_ID','$SALES_ORDER_ID','$INV_ITEM_ID',2,100,0,2,0,'Two E2E units allocated for delivery'
);

insert into public.sales_allocations(
  id,organization_id,factory_id,sales_order_id,sales_order_line_id,item_id,location_id,quantity,status
) values(
  '$ALLOCATION_ID','$ORG_ID','$FACTORY_ID','$SALES_ORDER_ID','$SALES_LINE_ID','$INV_ITEM_ID','$INV_SOURCE_ID',2,'allocated'
);
SQL

STAGE_TX="$(rpc_checked "$MANAGER_TOKEN" inventory_transfer_stock "{\"p_factory_id\":\"$FACTORY_ID\",\"p_item_id\":\"$INV_ITEM_ID\",\"p_from_location_id\":\"$INV_SOURCE_ID\",\"p_to_location_id\":\"$STAGING_ID\",\"p_quantity\":2,\"p_external_reference\":\"E2E-DISPATCH-STAGE\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$STAGE_TX" ]]

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.warehouse_pick_lists(
  id,organization_id,factory_id,pick_list_no,sales_order_id,staging_location_id,priority,status,started_at,staged_at,notes
) values(
  '$PICK_LIST_ID','$ORG_ID','$FACTORY_ID','PICK-E2E-DSP-001','$SALES_ORDER_ID','$STAGING_ID','high','handed_off',now()-interval '5 minutes',now()-interval '2 minutes','Dispatch E2E staged pick'
);

insert into public.warehouse_pick_lines(
  id,organization_id,pick_list_id,sales_allocation_id,sales_order_line_id,item_id,from_location_id,
  quantity_required,picked_quantity,status,transfer_transaction_id,picked_at
) values(
  '$PICK_LINE_ID','$ORG_ID','$PICK_LIST_ID','$ALLOCATION_ID','$SALES_LINE_ID','$INV_ITEM_ID','$INV_SOURCE_ID',
  2,2,'picked','$STAGE_TX',now()-interval '2 minutes'
);

insert into public.warehouse_dispatch_handoffs(
  id,organization_id,factory_id,handoff_no,pick_list_id,sales_order_id,staging_location_id,status,handed_off_at,notes
) values(
  '$HANDOFF_ID','$ORG_ID','$FACTORY_ID','WH-HO-E2E-DSP-001','$PICK_LIST_ID','$SALES_ORDER_ID','$STAGING_ID','handed_off',now()-interval '1 minute','Dispatch E2E handoff'
);
SQL

expect_denied "$MANAGER_TOKEN" dispatch_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$BLOCKED_FACTORY_ID\"}" 'factory manager blocked-factory Dispatch dashboard'
expect_denied "$DRIVER_TOKEN" dispatch_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}" 'driver aggregate Dispatch dashboard'

TRIP_RESPONSE="$(rpc_checked "$MANAGER_TOKEN" fleet_create_trip "{\"p_factory_id\":\"$FACTORY_ID\",\"p_vehicle_id\":\"$VEHICLE_ID\",\"p_driver_id\":\"$DRIVER_ID\",\"p_origin\":\"Allowed Plant\",\"p_destination\":\"E2E Dispatch Customer\",\"p_planned_start_at\":\"2099-02-01T08:00:00Z\",\"p_planned_end_at\":\"2099-02-01T12:00:00Z\",\"p_sales_order_id\":\"$SALES_ORDER_ID\",\"p_warehouse_handoff_id\":\"$HANDOFF_ID\",\"p_notes\":\"Phase 10 Dispatch E2E trip\"}")"
TRIP_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$TRIP_RESPONSE")"
[[ -n "$TRIP_ID" ]]

DELIVERY_RESPONSE="$(rpc_checked "$MANAGER_TOKEN" dispatch_create_delivery "{\"p_handoff_id\":\"$HANDOFF_ID\",\"p_trip_id\":\"$TRIP_ID\"}")"
DELIVERY_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$DELIVERY_RESPONSE")"
[[ -n "$DELIVERY_ID" ]]

echo 'manager handoff + trip → delivery creation passed'

DRIVER_ROWS="$(curl -fsS "$API_URL/rest/v1/dispatch_deliveries?select=id,status,driver_id&id=eq.$DELIVERY_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $DRIVER_TOKEN")"
python3 -c 'import json,sys; expected=sys.argv[1]; rows=json.load(sys.stdin); assert len(rows)==1 and rows[0]["id"]==expected and rows[0]["status"]=="ready_to_load", rows; print("assigned driver delivery RLS visibility passed")' "$DELIVERY_ID" <<<"$DRIVER_ROWS"

EMPLOYEE_ROWS="$(curl -fsS "$API_URL/rest/v1/dispatch_deliveries?select=id&id=eq.$DELIVERY_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert rows==[], rows; print("unassigned employee delivery RLS denial passed")' <<<"$EMPLOYEE_ROWS"

expect_denied "$DRIVER_TOKEN" dispatch_confirm_vehicle_load "{\"p_delivery_id\":\"$DELIVERY_ID\"}" 'driver vehicle-load confirmation'
rpc_checked "$MANAGER_TOKEN" dispatch_confirm_vehicle_load "{\"p_delivery_id\":\"$DELIVERY_ID\"}" >/dev/null

LOAD_STATE="$(psql "$DB_URL" -Atc "select status||'|'||loaded_quantity from public.dispatch_deliveries d join public.dispatch_delivery_lines l on l.delivery_id=d.id where d.id='$DELIVERY_ID'")"
[[ "$LOAD_STATE" == 'loaded|2.0000' || "$LOAD_STATE" == 'loaded|2' ]]
STAGING_BAL="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$INV_ITEM_ID' and location_id='$STAGING_ID'")"
VEHICLE_BAL="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$INV_ITEM_ID' and location_id='$VEHICLE_LOCATION_ID'")"
python3 -c 'import sys; assert float(sys.argv[1])==0 and float(sys.argv[2])==2, sys.argv; print("vehicle-load inventory transfer passed")' "$STAGING_BAL" "$VEHICLE_BAL"

CURRENT_ODO="$(psql "$DB_URL" -Atc "select current_odometer_km from public.fleet_vehicles where id='$VEHICLE_ID'")"
START_ODO="$(python3 -c 'import sys; print(float(sys.argv[1])+10)' "$CURRENT_ODO")"
ARRIVE_ODO="$(python3 -c 'import sys; print(float(sys.argv[1])+20)' "$CURRENT_ODO")"
END_ODO="$(python3 -c 'import sys; print(float(sys.argv[1])+25)' "$CURRENT_ODO")"

rpc_checked "$DRIVER_TOKEN" fleet_start_trip "{\"p_trip_id\":\"$TRIP_ID\",\"p_odometer_km\":$START_ODO,\"p_notes\":\"Dispatch E2E start\"}" >/dev/null
rpc_checked "$DRIVER_TOKEN" dispatch_begin_delivery "{\"p_delivery_id\":\"$DELIVERY_ID\"}" >/dev/null
expect_denied "$EMPLOYEE_TOKEN" dispatch_begin_delivery "{\"p_delivery_id\":\"$DELIVERY_ID\"}" 'unassigned employee delivery execution'
rpc_checked "$DRIVER_TOKEN" fleet_mark_trip_arrived "{\"p_trip_id\":\"$TRIP_ID\",\"p_odometer_km\":$ARRIVE_ODO,\"p_notes\":\"Dispatch E2E arrival\"}" >/dev/null
rpc_checked "$DRIVER_TOKEN" dispatch_mark_arrived "{\"p_delivery_id\":\"$DELIVERY_ID\"}" >/dev/null

rpc_checked "$DRIVER_TOKEN" dispatch_complete_delivery "{\"p_delivery_id\":\"$DELIVERY_ID\",\"p_receiver_name\":\"E2E Receiver\",\"p_receiver_phone\":\"+91 90000 30001\",\"p_pod_photo_ref\":\"e2e://pod/photo-001\",\"p_pod_signature_ref\":null,\"p_notes\":\"Delivered in Dispatch E2E\"}" >/dev/null

DELIVERY_STATE="$(psql "$DB_URL" -Atc "select status||'|'||receiver_name||'|'||coalesce(pod_photo_ref,'') from public.dispatch_deliveries where id='$DELIVERY_ID'")"
[[ "$DELIVERY_STATE" == 'delivered|E2E Receiver|e2e://pod/photo-001' ]]
VEHICLE_PRODUCT_BAL="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$INV_ITEM_ID' and location_id='$VEHICLE_LOCATION_ID'")"
python3 -c 'import sys; assert float(sys.argv[1])==0, sys.argv; print("driver arrival → POD delivery → vehicle stock issue passed")' "$VEHICLE_PRODUCT_BAL"

RETURN_LINE="$(rpc_checked "$DRIVER_TOKEN" dispatch_record_returnable "{\"p_delivery_id\":\"$DELIVERY_ID\",\"p_item_id\":\"$RETURN_ITEM_ID\",\"p_quantity\":1,\"p_condition\":\"good\",\"p_notes\":\"One E2E empty cylinder returned\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$RETURN_LINE" ]]
rpc_checked "$DRIVER_TOKEN" dispatch_complete_returnables "{\"p_delivery_id\":\"$DELIVERY_ID\",\"p_notes\":\"Returnable pickup complete\"}" >/dev/null
RETURN_BAL="$(psql "$DB_URL" -Atc "select coalesce(sum(quantity_delta),0) from public.stock_ledger_entries where item_id='$RETURN_ITEM_ID' and location_id='$VEHICLE_LOCATION_ID'")"
RETURN_STATUS="$(psql "$DB_URL" -Atc "select status from public.dispatch_returnable_pickups where delivery_id='$DELIVERY_ID'")"
python3 -c 'import sys; assert float(sys.argv[1])==1, sys.argv; assert sys.argv[2]=="completed", sys.argv; print("customer returnable → vehicle inventory receipt passed")' "$RETURN_BAL" "$RETURN_STATUS"

EXCEPTION_ID="$(rpc_checked "$DRIVER_TOKEN" dispatch_report_exception "{\"p_delivery_id\":\"$DELIVERY_ID\",\"p_exception_type\":\"other\",\"p_details\":\"E2E proof note follow-up\",\"p_item_id\":null,\"p_quantity\":null}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$EXCEPTION_ID" ]]
rpc_checked "$MANAGER_TOKEN" dispatch_resolve_exception "{\"p_exception_id\":\"$EXCEPTION_ID\",\"p_resolution_note\":\"E2E manager reviewed proof\"}" >/dev/null
EXCEPTION_STATE="$(psql "$DB_URL" -Atc "select status from public.dispatch_delivery_exceptions where id='$EXCEPTION_ID'")"
[[ "$EXCEPTION_STATE" == 'resolved' ]]
echo 'driver exception → manager resolution passed'

rpc_checked "$DRIVER_TOKEN" fleet_complete_trip "{\"p_trip_id\":\"$TRIP_ID\",\"p_odometer_km\":$END_ODO,\"p_notes\":\"Dispatch E2E trip closed\"}" >/dev/null

DASHBOARD="$(rpc_checked "$MANAGER_TOKEN" dispatch_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert int(row["delivered_today"])>=1, row; print("manager Dispatch dashboard delivered KPI passed")' <<<"$DASHBOARD"

AUDIT_COUNT="$(psql "$DB_URL" -Atc "select count(*) from public.audit_logs where entity_type in ('dispatch_deliveries','dispatch_returnable_pickups','dispatch_returnable_lines','dispatch_delivery_exceptions') and metadata::text like '%$DELIVERY_ID%'")"
python3 -c 'import sys; assert int(sys.argv[1])>=3, sys.argv; print("Dispatch audit trail passed")' "$AUDIT_COUNT"

echo 'Phase 10 authenticated Dispatch → Delivery → POD → Returnables E2E passed'
