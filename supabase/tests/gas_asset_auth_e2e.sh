#!/usr/bin/env bash
set -euo pipefail

# Uses local Auth users, role memberships and Inventory fixtures created by
# auth_login_e2e.sh and inventory_auth_e2e.sh. Never targets a remote project.
: "${API_URL:?source auth_login_e2e.sh first}"
: "${DB_URL:?source auth_login_e2e.sh first}"
: "${ANON_KEY:?source auth_login_e2e.sh first}"
: "${MANAGER_ACCESS_TOKEN:?source auth_login_e2e.sh first}"
: "${ACCESS_TOKEN:?source auth_login_e2e.sh first}"
: "${ORG_ID:?source auth_login_e2e.sh first}"
: "${FACTORY_ALLOWED:?source auth_login_e2e.sh first}"
: "${FACTORY_BLOCKED:?source auth_login_e2e.sh first}"
: "${INV_CATEGORY_ID:?source inventory_auth_e2e.sh first}"
: "${INV_UNIT_ID:?source inventory_auth_e2e.sh first}"

GAS_ITEM_ID='54710000-0000-4000-8000-000000000001'
psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.inventory_items(
  id,organization_id,category_id,unit_id,sku,name,item_type,is_returnable,is_active
) values(
  '$GAS_ITEM_ID','$ORG_ID','$INV_CATEGORY_ID','$INV_UNIT_ID',
  'E2E-GAS-CYL','E2E Cylinder and Dura Asset','cylinder',true,true
);
SQL

post_rpc() {
  local token="$1" name="$2" body="$3"
  curl --fail-with-body --silent --show-error \
    -X POST "$API_URL/rest/v1/rpc/$name" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    --data "$body"
}
expect_rpc_denied() {
  local token="$1" name="$2" body="$3" message="$4"
  local result status
  result="$(mktemp)"
  status="$(curl --silent --show-error -o "$result" -w '%{http_code}' \
    -X POST "$API_URL/rest/v1/rpc/$name" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' --data "$body")"
  if [[ "$status" == 2* ]]; then
    echo "$message unexpectedly passed" >&2
    cat "$result" >&2
    rm -f "$result"
    exit 1
  fi
  rm -f "$result"
}

REGISTER_JSON="$(printf '{"p_factory_id":"%s","p_item_id":"%s","p_serial_number":"  dura-e2e-001  ","p_container_type":"dura","p_ownership":"leased","p_test_due_on":"2026-10-01"}' "$FACTORY_ALLOWED" "$GAS_ITEM_ID")"
expect_rpc_denied "$ACCESS_TOKEN" gas_register_container "$REGISTER_JSON" 'employee serial registration'

BLOCKED_JSON="$(printf '{"p_factory_id":"%s","p_item_id":"%s","p_serial_number":"dura-blocked","p_container_type":"dura"}' "$FACTORY_BLOCKED" "$GAS_ITEM_ID")"
expect_rpc_denied "$MANAGER_ACCESS_TOKEN" gas_register_container "$BLOCKED_JSON" 'manager cross-factory registration'

ASSET_ID="$(post_rpc "$MANAGER_ACCESS_TOKEN" gas_register_container "$REGISTER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$ASSET_ID" ]]
ASSET_ROWS="$(curl --fail-with-body --silent --show-error \
  "$API_URL/rest/v1/gas_container_assets?select=id,serial_number,qr_code,container_type,state,condition,test_due_on&id=eq.$ASSET_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ACCESS_TOKEN")"
ASSET_QR="$(python3 -c 'import json,sys,re; r=json.load(sys.stdin); assert len(r)==1, r; a=r[0]; assert a["serial_number"]=="DURA-E2E-001" and a["container_type"]=="dura" and a["state"]=="hold" and a["condition"]=="unverified"; assert re.fullmatch(r"FA-[0-9A-F]{32}",a["qr_code"]); print(a["qr_code"])' <<<"$ASSET_ROWS")"

SCAN_ROWS="$(curl --fail-with-body --silent --show-error \
  "$API_URL/rest/v1/gas_container_assets?select=id,qr_code&organization_id=eq.$ORG_ID&qr_code=eq.$ASSET_QR&limit=1" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ACCESS_TOKEN")"
python3 -c 'import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["id"]==sys.argv[1],r; print("employee local JWT serialized QR visibility passed")' "$ASSET_ID" <<<"$SCAN_ROWS"

expect_rpc_denied "$MANAGER_ACCESS_TOKEN" gas_register_container "$REGISTER_JSON" 'duplicate canonical serial'
INSPECT_JSON="$(printf '{"p_asset_id":"%s","p_condition":"damaged","p_notes":"Visible valve damage. Quarantine without filling."}' "$ASSET_ID")"
expect_rpc_denied "$ACCESS_TOKEN" gas_record_container_inspection "$INSPECT_JSON" 'employee inspection mutation'
EVENT_ID="$(post_rpc "$MANAGER_ACCESS_TOKEN" gas_record_container_inspection "$INSPECT_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$EVENT_ID" ]]
STATE_ROWS="$(curl --fail-with-body --silent --show-error \
  "$API_URL/rest/v1/gas_container_assets?select=id,state,condition&id=eq.$ASSET_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN")"
python3 -c 'import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["state"]=="quarantined" and r[0]["condition"]=="damaged",r; print("manager inspection -> quarantine API passed")' <<<"$STATE_ROWS"

EVENT_ROWS="$(curl --fail-with-body --silent --show-error \
  "$API_URL/rest/v1/gas_container_asset_events?select=id,event_type,condition_after,notes&asset_id=eq.$ASSET_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN")"
python3 -c 'import json,sys; r=json.load(sys.stdin); assert len(r)==2 and {x["event_type"] for x in r}=={"registered","inspection"},r; print("immutable API event history visible")' <<<"$EVENT_ROWS"

# Direct asset updates must never allow an authenticated client to forge release.
PATCH_STATUS="$(curl --silent --show-error -o /dev/null -w '%{http_code}' \
  -X PATCH "$API_URL/rest/v1/gas_container_assets?id=eq.$ASSET_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' --data '{"state":"inspection_recorded"}')"
if [[ "$PATCH_STATUS" == 2* ]]; then
  echo 'Direct asset state mutation unexpectedly succeeded' >&2
  exit 1
fi

ANON_STATUS="$(curl --silent --show-error -o /dev/null -w '%{http_code}' \
  "$API_URL/rest/v1/gas_container_assets?select=id&limit=1" \
  -H "apikey: $ANON_KEY")"
if [[ "$ANON_STATUS" == 2* ]]; then
  echo 'Anonymous asset metadata access unexpectedly succeeded' >&2
  exit 1
fi

RETIRE_JSON="$(printf '{"p_asset_id":"%s","p_reason":"Removed from service after failed inspection"}' "$ASSET_ID")"
post_rpc "$MANAGER_ACCESS_TOKEN" gas_retire_container "$RETIRE_JSON" >/dev/null
expect_rpc_denied "$MANAGER_ACCESS_TOKEN" gas_record_container_inspection "$INSPECT_JSON" 'retired container inspection'
EVENT_COUNT="$(psql "$DB_URL" -Atc "select count(*) from public.gas_container_asset_events where asset_id='$ASSET_ID'")"
[[ "$EVENT_COUNT" == "3" ]]
echo 'Phase 21A real Auth/JWT gas serial registration, QR, quarantine and retirement passed'
