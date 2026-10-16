#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
MANAGER_EMAIL='quality-manager@factoryos.test'
MANAGER_PASSWORD='QualityManager123!'
EMPLOYEE_EMAIL='quality-inspector@factoryos.test'
EMPLOYEE_PASSWORD='QualityInspector123!'
ORG_ID='81000000-0000-4000-8000-000000000001'
FACTORY_ID='82000000-0000-4000-8000-000000000001'
BLOCKED_FACTORY_ID='82000000-0000-4000-8000-000000000002'
CATEGORY_ID='83000000-0000-4000-8000-000000000001'
UNIT_ID='83100000-0000-4000-8000-000000000001'
ITEM_ID='83200000-0000-4000-8000-000000000001'
SOURCE_LOCATION_ID='83300000-0000-4000-8000-000000000001'
QUARANTINE_LOCATION_ID='83300000-0000-4000-8000-000000000002'
RELEASE_LOCATION_ID='83300000-0000-4000-8000-000000000003'
OPEN_TX_ID='83400000-0000-4000-8000-000000000001'
PLAN_ID='83500000-0000-4000-8000-000000000001'
VISUAL_CHECK_ID='83600000-0000-4000-8000-000000000001'
NUMERIC_CHECK_ID='83600000-0000-4000-8000-000000000002'

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
rpc() {
  local token="$1" name="$2" payload="$3"
  curl -fsS -X POST "$API_URL/rest/v1/rpc/$name" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$payload"
}
expect_denied() {
  local token="$1" name="$2" payload="$3" label="$4"
  local file status
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

MANAGER_SIGNUP="$(signup "$MANAGER_EMAIL" "$MANAGER_PASSWORD")"
MANAGER_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$MANAGER_SIGNUP")"
EMPLOYEE_SIGNUP="$(signup "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD")"
EMPLOYEE_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$EMPLOYEE_SIGNUP")"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.organizations(id,name,code) values ('$ORG_ID','Quality E2E Industries','QUALITY-E2E');
insert into public.factories(id,organization_id,name,code) values
 ('$FACTORY_ID','$ORG_ID','Quality Allowed Plant','QA-A'),
 ('$BLOCKED_FACTORY_ID','$ORG_ID','Quality Blocked Plant','QA-B');
insert into public.organization_members(organization_id,user_id,role) values
 ('$ORG_ID','$MANAGER_USER_ID','factory_manager'),
 ('$ORG_ID','$EMPLOYEE_USER_ID','employee');
insert into public.factory_members(organization_id,factory_id,user_id) values
 ('$ORG_ID','$FACTORY_ID','$MANAGER_USER_ID'),
 ('$ORG_ID','$FACTORY_ID','$EMPLOYEE_USER_ID');
insert into public.inventory_categories(id,organization_id,name,code) values ('$CATEGORY_ID','$ORG_ID','Quality Test Items','QTEST');
insert into public.inventory_units(id,organization_id,name,code,decimal_places) values ('$UNIT_ID','$ORG_ID','Pieces','PCS',0);
insert into public.inventory_items(id,organization_id,category_id,unit_id,sku,name,item_type) values ('$ITEM_ID','$ORG_ID','$CATEGORY_ID','$UNIT_ID','QA-ITEM-001','Quality Test Component','raw_material');
insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type) values
 ('$SOURCE_LOCATION_ID','$ORG_ID','$FACTORY_ID','Incoming Store','IN-STORE','warehouse'),
 ('$QUARANTINE_LOCATION_ID','$ORG_ID','$FACTORY_ID','Quality Hold','QC-HOLD','quarantine'),
 ('$RELEASE_LOCATION_ID','$ORG_ID','$FACTORY_ID','Released Store','REL-STORE','warehouse');
insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,to_location_id,external_reference) values
 ('$OPEN_TX_ID','$ORG_ID','$FACTORY_ID','$ITEM_ID','QUALITY-E2E-OPEN','opening',10,'$SOURCE_LOCATION_ID','Quality E2E opening');
insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta) values
 ('$ORG_ID','$FACTORY_ID','$OPEN_TX_ID','$ITEM_ID','$SOURCE_LOCATION_ID',10);
insert into public.quality_inspection_plans(id,organization_id,item_id,name,code,version,inspection_type,sampling_method,default_sample_size) values
 ('$PLAN_ID','$ORG_ID','$ITEM_ID','Quality E2E Incoming Plan','QA-E2E-IN','V1','incoming','fixed',2);
insert into public.quality_plan_checks(id,organization_id,plan_id,sequence_no,parameter_name,check_type,acceptance_text,is_required) values
 ('$VISUAL_CHECK_ID','$ORG_ID','$PLAN_ID',1,'Visual condition','visual','No visible defects',true);
insert into public.quality_plan_checks(id,organization_id,plan_id,sequence_no,parameter_name,check_type,min_numeric,max_numeric,unit_text,is_required) values
 ('$NUMERIC_CHECK_ID','$ORG_ID','$PLAN_ID',2,'Dimension','numeric',9,11,'mm',true);
SQL

MANAGER_TOKEN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
EMPLOYEE_TOKEN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"

PASS_INSPECTION="$(rpc "$EMPLOYEE_TOKEN" quality_start_inspection "{\"p_factory_id\":\"$FACTORY_ID\",\"p_plan_id\":\"$PLAN_ID\",\"p_item_id\":\"$ITEM_ID\",\"p_lot_batch_no\":\"QA-PASS-LOT\",\"p_sample_size\":2}")"
PASS_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$PASS_INSPECTION")"
echo 'assigned employee inspection start passed'

rpc "$EMPLOYEE_TOKEN" quality_record_result "{\"p_inspection_id\":\"$PASS_ID\",\"p_plan_check_id\":\"$VISUAL_CHECK_ID\",\"p_result_status\":\"pass\",\"p_text_value\":\"Acceptable\"}" >/dev/null
rpc "$EMPLOYEE_TOKEN" quality_record_result "{\"p_inspection_id\":\"$PASS_ID\",\"p_plan_check_id\":\"$NUMERIC_CHECK_ID\",\"p_numeric_value\":10.2}" >/dev/null
PASS_RESULT="$(rpc "$EMPLOYEE_TOKEN" quality_complete_inspection "{\"p_inspection_id\":\"$PASS_ID\",\"p_hold\":false}")"
python3 -c 'import json,sys; assert json.load(sys.stdin)=="pass"' <<<"$PASS_RESULT"
echo 'quality checklist + pass completion passed'

expect_denied "$EMPLOYEE_TOKEN" quality_issue_certificate "{\"p_inspection_id\":\"$PASS_ID\"}" 'employee certificate issue'
CERT_ID="$(rpc "$MANAGER_TOKEN" quality_issue_certificate "{\"p_inspection_id\":\"$PASS_ID\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$CERT_ID" ]]
echo 'manager quality certificate issue passed'

FAIL_INSPECTION="$(rpc "$EMPLOYEE_TOKEN" quality_start_inspection "{\"p_factory_id\":\"$FACTORY_ID\",\"p_plan_id\":\"$PLAN_ID\",\"p_item_id\":\"$ITEM_ID\",\"p_lot_batch_no\":\"QA-FAIL-LOT\",\"p_sample_size\":2}")"
FAIL_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$FAIL_INSPECTION")"
rpc "$EMPLOYEE_TOKEN" quality_record_result "{\"p_inspection_id\":\"$FAIL_ID\",\"p_plan_check_id\":\"$VISUAL_CHECK_ID\",\"p_result_status\":\"pass\"}" >/dev/null
rpc "$EMPLOYEE_TOKEN" quality_record_result "{\"p_inspection_id\":\"$FAIL_ID\",\"p_plan_check_id\":\"$NUMERIC_CHECK_ID\",\"p_numeric_value\":14.5}" >/dev/null
FAIL_RESULT="$(rpc "$EMPLOYEE_TOKEN" quality_complete_inspection "{\"p_inspection_id\":\"$FAIL_ID\",\"p_hold\":false}")"
python3 -c 'import json,sys; assert json.load(sys.stdin)=="fail"' <<<"$FAIL_RESULT"
echo 'numeric tolerance automatic failure passed'

NCR_ID="$(rpc "$EMPLOYEE_TOKEN" quality_create_ncr "{\"p_inspection_id\":\"$FAIL_ID\",\"p_severity\":\"high\",\"p_category\":\"Dimension\",\"p_description\":\"Measured dimension exceeds maximum tolerance\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$NCR_ID" ]]
echo 'employee NCR creation passed'

Q_ID="$(rpc "$EMPLOYEE_TOKEN" quality_quarantine_stock "{\"p_inspection_id\":\"$FAIL_ID\",\"p_from_location_id\":\"$SOURCE_LOCATION_ID\",\"p_quarantine_location_id\":\"$QUARANTINE_LOCATION_ID\",\"p_quantity\":2,\"p_lot_batch_no\":\"QA-FAIL-LOT\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$Q_ID" ]]
echo 'employee quality quarantine ledger transfer passed'

expect_denied "$EMPLOYEE_TOKEN" quality_release_quarantine "{\"p_quarantine_id\":\"$Q_ID\",\"p_to_location_id\":\"$RELEASE_LOCATION_ID\",\"p_disposition\":\"use_as_is\"}" 'employee quarantine release'

rpc "$MANAGER_TOKEN" quality_update_ncr "{\"p_ncr_id\":\"$NCR_ID\",\"p_status\":\"closed\",\"p_disposition\":\"use_as_is\",\"p_root_cause\":\"Measurement drift verified\",\"p_corrective_action\":\"Lot reviewed and concession approved\"}" >/dev/null
rpc "$MANAGER_TOKEN" quality_release_quarantine "{\"p_quarantine_id\":\"$Q_ID\",\"p_to_location_id\":\"$RELEASE_LOCATION_ID\",\"p_disposition\":\"use_as_is\"}" >/dev/null
echo 'manager NCR closure + quarantine release passed'

STOCK_RESPONSE="$(rpc "$MANAGER_TOKEN" inventory_stock_report "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; source=sys.argv[1]; quarantine=sys.argv[2]; release=sys.argv[3]; rows=json.load(sys.stdin); by_loc={r["location_id"]:float(r["quantity"]) for r in rows if r["item_id"]==sys.argv[4]}; assert by_loc.get(source)==8.0,by_loc; assert by_loc.get(quarantine,0.0)==0.0,by_loc; assert by_loc.get(release)==2.0,by_loc; print("quality quarantine/release inventory balances passed")' "$SOURCE_LOCATION_ID" "$QUARANTINE_LOCATION_ID" "$RELEASE_LOCATION_ID" "$ITEM_ID" <<<"$STOCK_RESPONSE"

expect_denied "$MANAGER_TOKEN" quality_start_inspection "{\"p_factory_id\":\"$BLOCKED_FACTORY_ID\",\"p_plan_id\":\"$PLAN_ID\",\"p_item_id\":\"$ITEM_ID\"}" 'factory manager cross-factory quality start'

echo 'authenticated Phase 6 quality flow passed'