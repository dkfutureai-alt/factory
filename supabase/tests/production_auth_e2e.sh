#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
MANAGER_EMAIL='production-manager@factoryos.test'
MANAGER_PASSWORD='Production123!'
EMPLOYEE_EMAIL='production-operator@factoryos.test'
EMPLOYEE_PASSWORD='Operator123!'
ORG_ID='61000000-0000-4000-8000-000000000001'
FACTORY_ID='62000000-0000-4000-8000-000000000001'
BLOCKED_FACTORY_ID='62000000-0000-4000-8000-000000000002'
CATEGORY_ID='63000000-0000-4000-8000-000000000001'
UNIT_ID='63100000-0000-4000-8000-000000000001'
RAW_ITEM_ID='63200000-0000-4000-8000-000000000001'
FG_ITEM_ID='63200000-0000-4000-8000-000000000002'
RAW_LOCATION_ID='63300000-0000-4000-8000-000000000001'
FG_LOCATION_ID='63300000-0000-4000-8000-000000000002'
OPEN_TX_ID='63400000-0000-4000-8000-000000000001'
RECIPE_ID='63500000-0000-4000-8000-000000000001'
WORK_CENTER_ID='63600000-0000-4000-8000-000000000001'
BLOCKED_WORK_CENTER_ID='63600000-0000-4000-8000-000000000002'

STATUS_ENV="$(supabase status -o env)"
ANON_KEY="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')"
if [[ -z "$ANON_KEY" ]]; then
  echo 'Could not resolve local anonymous API key.' >&2
  exit 1
fi

signup() {
  local email="$1" password="$2"
  curl -fsS -X POST "$API_URL/auth/v1/signup" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' -d "{\"email\":\"$email\",\"password\":\"$password\"}"
}
login() {
  local email="$1" password="$2"
  curl -fsS -X POST "$API_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' -d "{\"email\":\"$email\",\"password\":\"$password\"}"
}

MANAGER_SIGNUP="$(signup "$MANAGER_EMAIL" "$MANAGER_PASSWORD")"
MANAGER_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$MANAGER_SIGNUP")"
EMPLOYEE_SIGNUP="$(signup "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD")"
EMPLOYEE_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$EMPLOYEE_SIGNUP")"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.organizations(id,name,code) values ('$ORG_ID','Production E2E Industries','PROD-E2E');
insert into public.factories(id,organization_id,name,code) values
 ('$FACTORY_ID','$ORG_ID','Production Allowed Plant','PROD-A'),
 ('$BLOCKED_FACTORY_ID','$ORG_ID','Production Blocked Plant','PROD-B');
insert into public.organization_members(organization_id,user_id,role) values
 ('$ORG_ID','$MANAGER_USER_ID','factory_manager'),
 ('$ORG_ID','$EMPLOYEE_USER_ID','employee');
insert into public.factory_members(organization_id,factory_id,user_id) values
 ('$ORG_ID','$FACTORY_ID','$MANAGER_USER_ID'),
 ('$ORG_ID','$FACTORY_ID','$EMPLOYEE_USER_ID');
insert into public.inventory_categories(id,organization_id,name,code) values ('$CATEGORY_ID','$ORG_ID','Production Materials','PROD');
insert into public.inventory_units(id,organization_id,name,code,decimal_places) values ('$UNIT_ID','$ORG_ID','Pieces','PCS',0);
insert into public.inventory_items(id,organization_id,category_id,unit_id,sku,name,item_type) values
 ('$RAW_ITEM_ID','$ORG_ID','$CATEGORY_ID','$UNIT_ID','RAW-001','Production Raw Component','raw_material'),
 ('$FG_ITEM_ID','$ORG_ID','$CATEGORY_ID','$UNIT_ID','FG-001','Production Finished Product','finished_good');
insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type) values
 ('$RAW_LOCATION_ID','$ORG_ID','$FACTORY_ID','Raw Store','RAW','warehouse'),
 ('$FG_LOCATION_ID','$ORG_ID','$FACTORY_ID','Finished Store','FG','warehouse');
insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,to_location_id,external_reference) values
 ('$OPEN_TX_ID','$ORG_ID','$FACTORY_ID','$RAW_ITEM_ID','PROD-E2E-OPEN','opening',20,'$RAW_LOCATION_ID','E2E opening');
insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta) values
 ('$ORG_ID','$FACTORY_ID','$OPEN_TX_ID','$RAW_ITEM_ID','$RAW_LOCATION_ID',20);
insert into public.production_recipes(id,organization_id,product_item_id,name,version,output_quantity) values
 ('$RECIPE_ID','$ORG_ID','$FG_ITEM_ID','Production E2E Recipe','V1',1);
insert into public.production_recipe_components(organization_id,recipe_id,item_id,quantity_required) values
 ('$ORG_ID','$RECIPE_ID','$RAW_ITEM_ID',2);
insert into public.work_centers(id,organization_id,factory_id,name,code,center_type) values
 ('$WORK_CENTER_ID','$ORG_ID','$FACTORY_ID','E2E Line A','LINE-A','line'),
 ('$BLOCKED_WORK_CENTER_ID','$ORG_ID','$BLOCKED_FACTORY_ID','E2E Line B','LINE-B','line');
SQL

MANAGER_LOGIN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD")"
MANAGER_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$MANAGER_LOGIN")"
EMPLOYEE_LOGIN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD")"
EMPLOYEE_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$EMPLOYEE_LOGIN")"

ORDER_RESPONSE="$(curl -fsS -X POST "$API_URL/rest/v1/rpc/production_create_order" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$FACTORY_ID\",\"p_recipe_id\":\"$RECIPE_ID\",\"p_work_center_id\":\"$WORK_CENTER_ID\",\"p_planned_quantity\":5}")"
ORDER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$ORDER_RESPONSE")"
echo 'factory manager production order creation passed'

EMPLOYEE_CREATE_FILE="$(mktemp)"
EMPLOYEE_CREATE_STATUS="$(curl -sS -o "$EMPLOYEE_CREATE_FILE" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/production_create_order" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$FACTORY_ID\",\"p_recipe_id\":\"$RECIPE_ID\",\"p_work_center_id\":\"$WORK_CENTER_ID\",\"p_planned_quantity\":1}")"
if [[ "$EMPLOYEE_CREATE_STATUS" == 2* ]]; then
  echo 'Employee unexpectedly created a production order.' >&2
  cat "$EMPLOYEE_CREATE_FILE" >&2
  rm -f "$EMPLOYEE_CREATE_FILE"
  exit 1
fi
rm -f "$EMPLOYEE_CREATE_FILE"
echo 'employee production-order creation denial passed'

BATCH_RESPONSE="$(curl -fsS -X POST "$API_URL/rest/v1/rpc/production_start_batch" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_order_id\":\"$ORDER_ID\",\"p_batch_no\":\"E2E-BATCH-1\",\"p_planned_quantity\":5}")"
BATCH_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$BATCH_RESPONSE")"
echo 'assigned employee batch start passed'

curl -fsS -X POST "$API_URL/rest/v1/rpc/production_issue_material" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_batch_id\":\"$BATCH_ID\",\"p_item_id\":\"$RAW_ITEM_ID\",\"p_from_location_id\":\"$RAW_LOCATION_ID\",\"p_quantity\":10}" >/dev/null
echo 'assigned employee production material issue passed'

BOM_RESPONSE="$(curl -fsS -X POST "$API_URL/rest/v1/rpc/production_bom_requirements" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_order_id\":\"$ORDER_ID\"}")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert len(rows)==1,rows; row=rows[0]; assert float(row["required_quantity"])==10.0,row; assert float(row["issued_quantity"])==10.0,row; assert float(row["remaining_quantity"])==0.0,row; print("production BOM requirement accounting passed")' <<<"$BOM_RESPONSE"

OVER_ISSUE_FILE="$(mktemp)"
OVER_ISSUE_STATUS="$(curl -sS -o "$OVER_ISSUE_FILE" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/production_issue_material" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_batch_id\":\"$BATCH_ID\",\"p_item_id\":\"$RAW_ITEM_ID\",\"p_from_location_id\":\"$RAW_LOCATION_ID\",\"p_quantity\":11}")"
if [[ "$OVER_ISSUE_STATUS" == 2* ]]; then
  echo 'Production material issue unexpectedly allowed negative stock.' >&2
  cat "$OVER_ISSUE_FILE" >&2
  rm -f "$OVER_ISSUE_FILE"
  exit 1
fi
rm -f "$OVER_ISSUE_FILE"
echo 'production over-consumption / negative-stock denial passed'

curl -fsS -X POST "$API_URL/rest/v1/rpc/production_record_output" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_batch_id\":\"$BATCH_ID\",\"p_good_quantity\":5,\"p_scrap_quantity\":0,\"p_to_location_id\":\"$FG_LOCATION_ID\",\"p_lot_batch_no\":\"E2E-LOT-1\"}" >/dev/null
echo 'assigned employee finished-goods receipt passed'

OVER_OUTPUT_FILE="$(mktemp)"
OVER_OUTPUT_STATUS="$(curl -sS -o "$OVER_OUTPUT_FILE" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/production_record_output" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_batch_id\":\"$BATCH_ID\",\"p_good_quantity\":1,\"p_scrap_quantity\":0,\"p_to_location_id\":\"$FG_LOCATION_ID\"}")"
if [[ "$OVER_OUTPUT_STATUS" == 2* ]]; then
  echo 'Production output unexpectedly exceeded the batch plan.' >&2
  cat "$OVER_OUTPUT_FILE" >&2
  rm -f "$OVER_OUTPUT_FILE"
  exit 1
fi
rm -f "$OVER_OUTPUT_FILE"
echo 'production output-over-plan denial passed'

curl -fsS -X POST "$API_URL/rest/v1/rpc/production_set_batch_status" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_batch_id\":\"$BATCH_ID\",\"p_status\":\"completed\"}" >/dev/null
echo 'assigned employee batch completion passed'

STOCK_RESPONSE="$(curl -fsS -X POST "$API_URL/rest/v1/rpc/inventory_stock_report" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; raw=sys.argv[1]; fg=sys.argv[2]; rows=json.load(sys.stdin); by_item={r["item_id"]:float(r["quantity"]) for r in rows}; assert by_item.get(raw)==10.0,by_item; assert by_item.get(fg)==5.0,by_item; print("production inventory ledger balances passed")' "$RAW_ITEM_ID" "$FG_ITEM_ID" <<<"$STOCK_RESPONSE"

BLOCKED_FILE="$(mktemp)"
BLOCKED_STATUS="$(curl -sS -o "$BLOCKED_FILE" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/production_create_order" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"p_factory_id\":\"$BLOCKED_FACTORY_ID\",\"p_recipe_id\":\"$RECIPE_ID\",\"p_work_center_id\":\"$BLOCKED_WORK_CENTER_ID\",\"p_planned_quantity\":1}")"
if [[ "$BLOCKED_STATUS" == 2* ]]; then
  echo 'Factory manager unexpectedly created an order in a blocked factory.' >&2
  cat "$BLOCKED_FILE" >&2
  rm -f "$BLOCKED_FILE"
  exit 1
fi
rm -f "$BLOCKED_FILE"
echo 'factory manager cross-factory production denial passed'
