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
CATEGORY_ID='a3000000-0000-4000-8000-000000000001'
UNIT_ID='a3100000-0000-4000-8000-000000000001'
RAW_ITEM_ID='a3200000-0000-4000-8000-000000000001'
FINISHED_ITEM_ID='a3200000-0000-4000-8000-000000000002'
IN_QC_ID='a3300000-0000-4000-8000-000000000001'
STORE_ID='a3300000-0000-4000-8000-000000000002'
FG_ID='a3300000-0000-4000-8000-000000000003'
OPEN_TX_ID='a3400000-0000-4000-8000-000000000001'
PLAN_ID='a3500000-0000-4000-8000-000000000001'
CHECK_ID='a3510000-0000-4000-8000-000000000001'
SUPPLIER_ID='a3600000-0000-4000-8000-000000000001'
CUSTOMER_ID='a3600000-0000-4000-8000-000000000002'
TODAY="$(date -u +%F)"
DUE_DATE="$(date -u -d '+10 days' +%F)"
VALID_UNTIL="$(date -u -d '+7 days' +%F)"
DELIVERY_DATE="$(date -u -d '+2 days' +%F)"

STATUS_ENV="$(supabase status -o env)"
ANON_KEY="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')"
if [[ -z "$ANON_KEY" ]]; then echo 'Could not resolve local anonymous API key.' >&2; exit 1; fi

signup() {
  curl -fsS -X POST "$API_URL/auth/v1/signup" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' -d "{\"email\":\"$1\",\"password\":\"$2\"}"
}
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

MANAGER_USER_ID="$(signup "$MANAGER_EMAIL" "$MANAGER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])')"
SUPERVISOR_USER_ID="$(signup "$SUPERVISOR_EMAIL" "$SUPERVISOR_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])')"
EMPLOYEE_USER_ID="$(signup "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])')"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.organizations(id,name,code) values ('$ORG_ID','Commercial E2E Industries','COMM-E2E');
insert into public.factories(id,organization_id,name,code) values
 ('$FACTORY_ID','$ORG_ID','Commercial Allowed Plant','COM-A'),
 ('$BLOCKED_FACTORY_ID','$ORG_ID','Commercial Blocked Plant','COM-B');
insert into public.organization_members(organization_id,user_id,role) values
 ('$ORG_ID','$MANAGER_USER_ID','factory_manager'),
 ('$ORG_ID','$SUPERVISOR_USER_ID','supervisor'),
 ('$ORG_ID','$EMPLOYEE_USER_ID','employee');
insert into public.factory_members(organization_id,factory_id,user_id) values
 ('$ORG_ID','$FACTORY_ID','$MANAGER_USER_ID'),
 ('$ORG_ID','$FACTORY_ID','$SUPERVISOR_USER_ID'),
 ('$ORG_ID','$FACTORY_ID','$EMPLOYEE_USER_ID');
insert into public.inventory_categories(id,organization_id,name,code) values ('$CATEGORY_ID','$ORG_ID','Commercial Test Items','COMM');
insert into public.inventory_units(id,organization_id,name,code,decimal_places) values ('$UNIT_ID','$ORG_ID','Pieces','PCS',0);
insert into public.inventory_items(id,organization_id,category_id,unit_id,sku,name,item_type) values
 ('$RAW_ITEM_ID','$ORG_ID','$CATEGORY_ID','$UNIT_ID','COMM-RAW-001','Commercial Incoming Component','raw_material'),
 ('$FINISHED_ITEM_ID','$ORG_ID','$CATEGORY_ID','$UNIT_ID','COMM-FG-001','Commercial Finished Product','finished_good');
insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type) values
 ('$IN_QC_ID','$ORG_ID','$FACTORY_ID','Incoming Quality','IN-QC','quality'),
 ('$STORE_ID','$ORG_ID','$FACTORY_ID','Raw Store','RAW-STORE','warehouse'),
 ('$FG_ID','$ORG_ID','$FACTORY_ID','Finished Goods','FG-STORE','warehouse');
insert into public.inventory_transactions(id,organization_id,factory_id,item_id,transaction_no,transaction_type,quantity,to_location_id,external_reference) values
 ('$OPEN_TX_ID','$ORG_ID','$FACTORY_ID','$FINISHED_ITEM_ID','COMM-E2E-OPEN','opening',8,'$FG_ID','Commercial E2E opening');
insert into public.stock_ledger_entries(organization_id,factory_id,transaction_id,item_id,location_id,quantity_delta) values
 ('$ORG_ID','$FACTORY_ID','$OPEN_TX_ID','$FINISHED_ITEM_ID','$FG_ID',8);
insert into public.quality_inspection_plans(id,organization_id,item_id,name,code,version,inspection_type,sampling_method,default_sample_size) values
 ('$PLAN_ID','$ORG_ID','$RAW_ITEM_ID','Commercial Incoming Quality','COMM-IN-QC','V1','incoming','fixed',2);
insert into public.quality_plan_checks(id,organization_id,plan_id,sequence_no,parameter_name,check_type,acceptance_text,is_required) values
 ('$CHECK_ID','$ORG_ID','$PLAN_ID',1,'Incoming visual condition','visual','No visible defects',true);
insert into public.business_partners(id,organization_id,partner_code,name,partner_type,country_code,credit_days) values
 ('$SUPPLIER_ID','$ORG_ID','SUP-E2E','Commercial Demo Supplier','supplier','IN',10),
 ('$CUSTOMER_ID','$ORG_ID','CUS-E2E','Commercial Demo Customer','customer','IN',10);
SQL

MANAGER_TOKEN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
SUPERVISOR_TOKEN="$(login "$SUPERVISOR_EMAIL" "$SUPERVISOR_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
EMPLOYEE_TOKEN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"

PR_PAYLOAD="{\"p_factory_id\":\"$FACTORY_ID\",\"p_required_date\":\"$DELIVERY_DATE\",\"p_purpose\":\"Commercial E2E raw material\",\"p_lines\":[{\"item_id\":\"$RAW_ITEM_ID\",\"quantity\":6,\"estimated_unit_cost\":20}]}"
expect_denied "$EMPLOYEE_TOKEN" commercial_create_requisition "$PR_PAYLOAD" 'employee purchase requisition creation'
PR_ID="$(rpc "$SUPERVISOR_TOKEN" commercial_create_requisition "$PR_PAYLOAD" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$PR_ID" ]]
echo 'supervisor purchase requisition creation passed'

rpc "$MANAGER_TOKEN" commercial_decide_requisition "{\"p_requisition_id\":\"$PR_ID\",\"p_status\":\"approved\",\"p_note\":\"Approved in E2E\"}" >/dev/null
echo 'manager requisition approval passed'

PO_PAYLOAD="{\"p_factory_id\":\"$FACTORY_ID\",\"p_supplier_id\":\"$SUPPLIER_ID\",\"p_requisition_id\":\"$PR_ID\",\"p_expected_date\":\"$DELIVERY_DATE\",\"p_currency_code\":\"INR\",\"p_notes\":\"Commercial E2E PO\",\"p_lines\":[{\"item_id\":\"$RAW_ITEM_ID\",\"quantity\":6,\"unit_price\":20,\"tax_rate\":5}]}"
expect_denied "$SUPERVISOR_TOKEN" commercial_create_purchase_order "$PO_PAYLOAD" 'supervisor purchase order creation'
PO_ID="$(rpc "$MANAGER_TOKEN" commercial_create_purchase_order "$PO_PAYLOAD" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$PO_ID" ]]
rpc "$MANAGER_TOKEN" commercial_set_purchase_order_status "{\"p_purchase_order_id\":\"$PO_ID\",\"p_status\":\"sent\"}" >/dev/null
echo 'manager purchase order creation + send passed'

PO_LINE_ID="$(psql "$DB_URL" -Atc "select id from public.purchase_order_lines where purchase_order_id='$PO_ID' limit 1")"
GRN_ID="$(rpc "$SUPERVISOR_TOKEN" commercial_receive_goods "{\"p_purchase_order_id\":\"$PO_ID\",\"p_received_location_id\":\"$IN_QC_ID\",\"p_lines\":[{\"purchase_order_line_id\":\"$PO_LINE_ID\",\"quantity\":6,\"lot_batch_no\":\"COMM-LOT-001\",\"quality_required\":true}],\"p_notes\":\"E2E receipt\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$GRN_ID" ]]
INSPECTION_ID="$(psql "$DB_URL" -Atc "select quality_inspection_id from public.goods_receipt_lines where goods_receipt_id='$GRN_ID' limit 1")"
[[ -n "$INSPECTION_ID" ]]
echo 'supervisor goods receipt + automatic incoming quality creation passed'

rpc "$SUPERVISOR_TOKEN" quality_record_result "{\"p_inspection_id\":\"$INSPECTION_ID\",\"p_plan_check_id\":\"$CHECK_ID\",\"p_result_status\":\"pass\",\"p_text_value\":\"Accepted\"}" >/dev/null
rpc "$SUPERVISOR_TOKEN" quality_complete_inspection "{\"p_inspection_id\":\"$INSPECTION_ID\",\"p_hold\":false}" >/dev/null
GRN_STATUS="$(psql "$DB_URL" -Atc "select status from public.goods_receipts where id='$GRN_ID'")"
[[ "$GRN_STATUS" == 'quality_passed' ]]
echo 'incoming quality completion synchronized goods receipt status passed'

rpc "$SUPERVISOR_TOKEN" commercial_release_goods_receipt "{\"p_goods_receipt_id\":\"$GRN_ID\",\"p_to_location_id\":\"$STORE_ID\"}" >/dev/null
STOCK_RESPONSE="$(rpc "$MANAGER_TOKEN" inventory_stock_report "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; item,inqc,store=sys.argv[1:]; rows=json.load(sys.stdin); by={r["location_id"]:float(r["quantity"]) for r in rows if r["item_id"]==item}; assert by.get(inqc,0.0)==0.0,by; assert by.get(store)==6.0,by; print("goods receipt quality release inventory balances passed")' "$RAW_ITEM_ID" "$IN_QC_ID" "$STORE_ID" <<<"$STOCK_RESPONSE"

SUPPLIER_INVOICE_ID="$(rpc "$MANAGER_TOKEN" commercial_create_supplier_invoice "{\"p_purchase_order_id\":\"$PO_ID\",\"p_invoice_no\":\"SUP-E2E-INV-001\",\"p_invoice_date\":\"$TODAY\",\"p_due_date\":\"$DUE_DATE\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
rpc "$MANAGER_TOKEN" commercial_record_supplier_payment "{\"p_supplier_invoice_id\":\"$SUPPLIER_INVOICE_ID\",\"p_amount\":126,\"p_payment_method\":\"bank_transfer\",\"p_reference_no\":\"E2E-SUP-PAY\"}" >/dev/null
SUPPLIER_STATUS="$(psql "$DB_URL" -Atc "select status from public.supplier_invoices where id='$SUPPLIER_INVOICE_ID'")"
[[ "$SUPPLIER_STATUS" == 'paid' ]]
echo 'supplier invoice + payment passed'

QUOTE_ID="$(rpc "$MANAGER_TOKEN" commercial_create_quotation "{\"p_factory_id\":\"$FACTORY_ID\",\"p_customer_id\":\"$CUSTOMER_ID\",\"p_valid_until\":\"$VALID_UNTIL\",\"p_currency_code\":\"INR\",\"p_notes\":\"Commercial E2E quote\",\"p_lines\":[{\"item_id\":\"$FINISHED_ITEM_ID\",\"quantity\":3,\"unit_price\":100,\"tax_rate\":10}]}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
rpc "$MANAGER_TOKEN" commercial_set_quotation_status "{\"p_quotation_id\":\"$QUOTE_ID\",\"p_status\":\"sent\"}" >/dev/null
SO_ID="$(rpc "$MANAGER_TOKEN" commercial_convert_quotation "{\"p_quotation_id\":\"$QUOTE_ID\",\"p_requested_delivery_date\":\"$DELIVERY_DATE\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$SO_ID" ]]
echo 'quotation to sales order conversion passed'

expect_denied "$EMPLOYEE_TOKEN" commercial_allocate_sales_order "{\"p_sales_order_id\":\"$SO_ID\",\"p_location_id\":\"$FG_ID\"}" 'employee sales allocation'
rpc "$SUPERVISOR_TOKEN" commercial_allocate_sales_order "{\"p_sales_order_id\":\"$SO_ID\",\"p_location_id\":\"$FG_ID\"}" >/dev/null
rpc "$SUPERVISOR_TOKEN" commercial_mark_dispatch_ready "{\"p_sales_order_id\":\"$SO_ID\"}" >/dev/null
SO_STATUS="$(psql "$DB_URL" -Atc "select status from public.sales_orders where id='$SO_ID'")"
[[ "$SO_STATUS" == 'dispatch_ready' ]]
echo 'supervisor stock allocation + dispatch readiness passed'

CUSTOMER_INVOICE_ID="$(rpc "$MANAGER_TOKEN" commercial_create_customer_invoice "{\"p_sales_order_id\":\"$SO_ID\",\"p_invoice_date\":\"$TODAY\",\"p_due_date\":\"$DUE_DATE\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
rpc "$MANAGER_TOKEN" commercial_record_customer_payment "{\"p_customer_invoice_id\":\"$CUSTOMER_INVOICE_ID\",\"p_amount\":330,\"p_payment_method\":\"bank_transfer\",\"p_reference_no\":\"E2E-CUS-PAY\"}" >/dev/null
CUSTOMER_STATUS="$(psql "$DB_URL" -Atc "select status from public.customer_invoices where id='$CUSTOMER_INVOICE_ID'")"
[[ "$CUSTOMER_STATUS" == 'paid' ]]
echo 'customer invoice + payment passed'

expect_denied "$MANAGER_TOKEN" commercial_create_requisition "{\"p_factory_id\":\"$BLOCKED_FACTORY_ID\",\"p_required_date\":\"$DELIVERY_DATE\",\"p_purpose\":\"Blocked\",\"p_lines\":[{\"item_id\":\"$RAW_ITEM_ID\",\"quantity\":1}]}" 'factory manager cross-factory commercial operation'

echo 'authenticated Phase 7 purchase and sales flow passed'
