#!/usr/bin/env bash
set -euo pipefail

: "${API_URL:?auth_login_e2e.sh must be sourced first}"
: "${DB_URL:?auth_login_e2e.sh must be sourced first}"
: "${ANON_KEY:?auth_login_e2e.sh must be sourced first}"
: "${ACCESS_TOKEN:?auth_login_e2e.sh must be sourced first}"
: "${MANAGER_ACCESS_TOKEN:?auth_login_e2e.sh must be sourced first}"
: "${ORG_ID:?auth_login_e2e.sh must be sourced first}"
: "${FACTORY_ALLOWED:?auth_login_e2e.sh must be sourced first}"
: "${FACTORY_BLOCKED:?auth_login_e2e.sh must be sourced first}"

INV_CATEGORY_ID='50000000-0000-4000-8000-000000000001'
INV_UNIT_ID='51000000-0000-4000-8000-000000000001'
INV_ITEM_ID='52000000-0000-4000-8000-000000000001'
INV_SOURCE_ID='53000000-0000-4000-8000-000000000001'
INV_DEST_ID='53000000-0000-4000-8000-000000000002'
INV_BLOCKED_LOCATION_ID='53000000-0000-4000-8000-000000000003'

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.inventory_categories (id, organization_id, name, code)
values ('$INV_CATEGORY_ID', '$ORG_ID', 'E2E Materials', 'E2EMAT');

insert into public.inventory_units (id, organization_id, name, code, decimal_places)
values ('$INV_UNIT_ID', '$ORG_ID', 'Piece', 'PCS', 0);

insert into public.inventory_items (
  id, organization_id, category_id, unit_id, sku, name, item_type, barcode, qr_code
) values (
  '$INV_ITEM_ID', '$ORG_ID', '$INV_CATEGORY_ID', '$INV_UNIT_ID', 'E2E-ITEM',
  'E2E Inventory Item', 'raw_material', 'E2E-BARCODE-001', 'E2E:ITEM:001'
);

insert into public.stock_locations (
  id, organization_id, factory_id, name, code, location_type
) values
  ('$INV_SOURCE_ID', '$ORG_ID', '$FACTORY_ALLOWED', 'E2E Main Store', 'E2E-MAIN', 'warehouse'),
  ('$INV_DEST_ID', '$ORG_ID', '$FACTORY_ALLOWED', 'E2E Production Store', 'E2E-PROD', 'production'),
  ('$INV_BLOCKED_LOCATION_ID', '$ORG_ID', '$FACTORY_BLOCKED', 'E2E Blocked Store', 'E2E-BLOCK', 'warehouse');
SQL

SCAN_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/rest/v1/rpc/inventory_lookup_scan" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_organization_id\":\"$ORG_ID\",\"p_code\":\"E2E-BARCODE-001\"}")"
python3 -c 'import json,sys; item=sys.argv[1]; allowed=sys.argv[2]; rows=json.load(sys.stdin); assert rows and {r["item_id"] for r in rows}=={item}, rows; assert {r["factory_id"] for r in rows}=={allowed}, rows; print("employee inventory scan factory scope passed")' "$INV_ITEM_ID" "$FACTORY_ALLOWED" <<<"$SCAN_RESPONSE"

RECEIVE_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/rest/v1/rpc/inventory_receive_stock" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_item_id\":\"$INV_ITEM_ID\",\"p_to_location_id\":\"$INV_SOURCE_ID\",\"p_quantity\":10,\"p_unit_cost\":12.5,\"p_external_reference\":\"E2E-RECEIVE\"}")"
python3 -c 'import json,sys; value=json.load(sys.stdin); assert isinstance(value,str) and len(value)==36, value; print("factory manager inventory receive RPC passed")' <<<"$RECEIVE_RESPONSE"

TRANSFER_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/rest/v1/rpc/inventory_transfer_stock" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_item_id\":\"$INV_ITEM_ID\",\"p_from_location_id\":\"$INV_SOURCE_ID\",\"p_to_location_id\":\"$INV_DEST_ID\",\"p_quantity\":3,\"p_external_reference\":\"E2E-TRANSFER\"}")"
python3 -c 'import json,sys; value=json.load(sys.stdin); assert isinstance(value,str) and len(value)==36, value; print("factory manager inventory transfer RPC passed")' <<<"$TRANSFER_RESPONSE"

ISSUE_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/rest/v1/rpc/inventory_issue_stock" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_item_id\":\"$INV_ITEM_ID\",\"p_from_location_id\":\"$INV_SOURCE_ID\",\"p_quantity\":2,\"p_external_reference\":\"E2E-ISSUE\"}")"
python3 -c 'import json,sys; value=json.load(sys.stdin); assert isinstance(value,str) and len(value)==36, value; print("factory manager inventory issue RPC passed")' <<<"$ISSUE_RESPONSE"

STOCK_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/rest/v1/rpc/inventory_stock_report" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\"}")"
python3 -c 'import json,sys; item,src,dst=sys.argv[1:4]; rows=[r for r in json.load(sys.stdin) if r["item_id"]==item]; balances={r["location_id"]:float(r["quantity"]) for r in rows}; assert balances.get(src)==5.0, balances; assert balances.get(dst)==3.0, balances; print("ledger-derived inventory stock report passed")' "$INV_ITEM_ID" "$INV_SOURCE_ID" "$INV_DEST_ID" <<<"$STOCK_RESPONSE"

INSUFFICIENT_FILE="$(mktemp)"
INSUFFICIENT_STATUS="$(curl -sS -o "$INSUFFICIENT_FILE" -w '%{http_code}' \
  -X POST "$API_URL/rest/v1/rpc/inventory_issue_stock" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_item_id\":\"$INV_ITEM_ID\",\"p_from_location_id\":\"$INV_SOURCE_ID\",\"p_quantity\":99}")"
if [[ "$INSUFFICIENT_STATUS" == 2* ]]; then
  echo 'Inventory issue unexpectedly allowed negative stock.' >&2
  cat "$INSUFFICIENT_FILE" >&2
  rm -f "$INSUFFICIENT_FILE"
  exit 1
fi
rm -f "$INSUFFICIENT_FILE"
echo 'inventory insufficient-stock denial passed'

BLOCKED_INV_FILE="$(mktemp)"
BLOCKED_INV_STATUS="$(curl -sS -o "$BLOCKED_INV_FILE" -w '%{http_code}' \
  -X POST "$API_URL/rest/v1/rpc/inventory_receive_stock" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $MANAGER_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$FACTORY_BLOCKED\",\"p_item_id\":\"$INV_ITEM_ID\",\"p_to_location_id\":\"$INV_BLOCKED_LOCATION_ID\",\"p_quantity\":1}")"
if [[ "$BLOCKED_INV_STATUS" == 2* ]]; then
  echo 'Factory manager unexpectedly moved inventory in a blocked factory.' >&2
  cat "$BLOCKED_INV_FILE" >&2
  rm -f "$BLOCKED_INV_FILE"
  exit 1
fi
rm -f "$BLOCKED_INV_FILE"
echo 'factory manager cross-factory inventory denial passed'

EMPLOYEE_WRITE_FILE="$(mktemp)"
EMPLOYEE_WRITE_STATUS="$(curl -sS -o "$EMPLOYEE_WRITE_FILE" -w '%{http_code}' \
  -X POST "$API_URL/rest/v1/rpc/inventory_receive_stock" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_item_id\":\"$INV_ITEM_ID\",\"p_to_location_id\":\"$INV_SOURCE_ID\",\"p_quantity\":1}")"
if [[ "$EMPLOYEE_WRITE_STATUS" == 2* ]]; then
  echo 'Employee unexpectedly received inventory.' >&2
  cat "$EMPLOYEE_WRITE_FILE" >&2
  rm -f "$EMPLOYEE_WRITE_FILE"
  exit 1
fi
rm -f "$EMPLOYEE_WRITE_FILE"
echo 'employee inventory write denial passed'
