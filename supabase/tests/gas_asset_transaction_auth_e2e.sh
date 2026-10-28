#!/usr/bin/env bash
set -euo pipefail
# Local CI only. Requires auth_login, inventory_auth and gas_asset_auth fixtures.
: "${API_URL:?source auth_login_e2e.sh first}"
: "${ANON_KEY:?source auth_login_e2e.sh first}"
: "${MANAGER_ACCESS_TOKEN:?source auth_login_e2e.sh first}"
: "${ACCESS_TOKEN:?source auth_login_e2e.sh first}"
: "${GAS_ITEM_ID:?source gas_asset_auth_e2e.sh first}"
: "${FACTORY_ALLOWED:?source auth_login_e2e.sh first}"
: "${INV_SOURCE_ID:?source inventory_auth_e2e.sh first}"
: "${INV_DEST_ID:?source inventory_auth_e2e.sh first}"

gas_tx_rpc() {
  curl --fail-with-body --silent --show-error -X POST "$API_URL/rest/v1/rpc/$2" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' --data "$3"
}
gas_tx_denied() {
  local file status
  file="$(mktemp)"
  status="$(curl --silent --show-error -o "$file" -w '%{http_code}' \
    -X POST "$API_URL/rest/v1/rpc/$2" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' --data "$3")"
  if [[ "$status" == 2* ]]; then
    echo "Unauthorized serialized transaction operation succeeded: $2" >&2
    cat "$file" >&2
    rm -f "$file"
    exit 1
  fi
  rm -f "$file"
}

ASSET="$(gas_tx_rpc "$MANAGER_ACCESS_TOKEN" gas_register_container \
  "$(printf '{"p_factory_id":"%s","p_item_id":"%s","p_serial_number":"GAS-TX-E2E-101","p_container_type":"cylinder"}' "$FACTORY_ALLOWED" "$GAS_ITEM_ID")" | \
  python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$ASSET" ]]
RECEIPT="$(gas_tx_rpc "$MANAGER_ACCESS_TOKEN" inventory_receive_stock \
  "$(printf '{"p_factory_id":"%s","p_item_id":"%s","p_to_location_id":"%s","p_quantity":1,"p_unit_cost":10,"p_external_reference":"GAS-E2E-TX-RECEIPT"}' \
  "$FACTORY_ALLOWED" "$GAS_ITEM_ID" "$INV_SOURCE_ID")" | \
  python3 -c 'import json,sys; print(json.load(sys.stdin))')"

REQUEST_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
RECEIPT_JSON="$(printf '{"p_asset_id":"%s","p_transaction_id":"%s","p_scanned_code":"GAS-TX-E2E-101","p_request_key":"%s"}' "$ASSET" "$RECEIPT" "$REQUEST_ID")"

gas_tx_denied "$ACCESS_TOKEN" gas_link_container_transaction "$RECEIPT_JSON"
LINK_ID="$(gas_tx_rpc "$MANAGER_ACCESS_TOKEN" gas_link_container_transaction "$RECEIPT_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
REPLAY="$(gas_tx_rpc "$MANAGER_ACCESS_TOKEN" gas_link_container_transaction "$RECEIPT_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$LINK_ID" && "$LINK_ID" == "$REPLAY" ]]

SECOND_ASSET="$(gas_tx_rpc "$MANAGER_ACCESS_TOKEN" gas_register_container \
  "$(printf '{"p_factory_id":"%s","p_item_id":"%s","p_serial_number":"GAS-TX-E2E-102","p_container_type":"cylinder"}' "$FACTORY_ALLOWED" "$GAS_ITEM_ID")" | \
  python3 -c 'import json,sys; print(json.load(sys.stdin))')"
SECOND_REQ="$(python3 -c 'import uuid; print(uuid.uuid4())')"
gas_tx_denied "$MANAGER_ACCESS_TOKEN" gas_link_container_transaction \
  "$(printf '{"p_asset_id":"%s","p_transaction_id":"%s","p_scanned_code":"GAS-TX-E2E-102","p_request_key":"%s"}' "$SECOND_ASSET" "$RECEIPT" "$SECOND_REQ")"

TRANSFER="$(gas_tx_rpc "$MANAGER_ACCESS_TOKEN" inventory_transfer_stock \
  "$(printf '{"p_factory_id":"%s","p_item_id":"%s","p_from_location_id":"%s","p_to_location_id":"%s","p_quantity":1,"p_external_reference":"GAS-E2E-TX-TRANSFER"}' \
  "$FACTORY_ALLOWED" "$GAS_ITEM_ID" "$INV_SOURCE_ID" "$INV_DEST_ID")" | \
  python3 -c 'import json,sys; print(json.load(sys.stdin))')"
MOVE_REQ="$(python3 -c 'import uuid; print(uuid.uuid4())')"
MOVE_ID="$(gas_tx_rpc "$MANAGER_ACCESS_TOKEN" gas_link_container_transaction \
  "$(printf '{"p_asset_id":"%s","p_transaction_id":"%s","p_scanned_code":"GAS-TX-E2E-101","p_request_key":"%s"}' "$ASSET" "$TRANSFER" "$MOVE_REQ")" | \
  python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$MOVE_ID" ]]

ROWS="$(curl --fail-with-body --silent --show-error \
  "$API_URL/rest/v1/gas_container_transaction_links?select=id,transaction_type,to_location_id&asset_id=eq.$ASSET&order=recorded_at.asc" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ACCESS_TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert len(rows)==2 and {x["transaction_type"] for x in rows}=={"receive","transfer"},rows; assert any(x["to_location_id"]==sys.argv[1] for x in rows),rows; print("employee factory-scoped serial history read passed")' "$INV_DEST_ID" <<<"$ROWS"

ISSUE="$(gas_tx_rpc "$MANAGER_ACCESS_TOKEN" inventory_issue_stock \
  "$(printf '{"p_factory_id":"%s","p_item_id":"%s","p_from_location_id":"%s","p_quantity":1,"p_external_reference":"NO-POD-ISSUE"}' \
  "$FACTORY_ALLOWED" "$GAS_ITEM_ID" "$INV_DEST_ID")" | \
  python3 -c 'import json,sys; print(json.load(sys.stdin))')"
ISSUE_REQ="$(python3 -c 'import uuid; print(uuid.uuid4())')"
gas_tx_denied "$MANAGER_ACCESS_TOKEN" gas_link_container_transaction \
  "$(printf '{"p_asset_id":"%s","p_transaction_id":"%s","p_scanned_code":"GAS-TX-E2E-101","p_request_key":"%s"}' "$ASSET" "$ISSUE" "$ISSUE_REQ")"

ANON_CODE="$(curl --silent --show-error -o /dev/null -w '%{http_code}' \
 "$API_URL/rest/v1/gas_container_transaction_links?select=id&limit=1" \
 -H "apikey: $ANON_KEY")"
if [[ "$ANON_CODE" == 2* ]]; then
  echo 'Anonymous serialized transaction history read unexpectedly succeeded' >&2
  exit 1
fi
echo 'Phase 21B JWT serial receipt→transfer, capacity, idempotency, POD and RLS passed'

# Phase 21C: actual JWT/PostgREST evidence report must never present an
# unscanned customer issue as complete cylinder custody.
COVERAGE_BODY="$(printf '{"p_organization_id":"%s","p_factory_id":"%s","p_limit":200}' "$ORG_ID" "$FACTORY_ALLOWED")"
COVERAGE="$(gas_tx_rpc "$ACCESS_TOKEN" gas_serial_attestation_coverage "$COVERAGE_BODY")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); receipt,transfer,issue=sys.argv[1:4]; by={x["transaction_id"]:x for x in rows}; assert all(x in by for x in (receipt,transfer,issue)),by; assert by[receipt]["coverage_status"]=="fully_attested" and float(by[receipt]["unattested_quantity"])==0,by[receipt]; assert by[transfer]["coverage_status"]=="fully_attested" and float(by[transfer]["linked_serial_count"])==1,by[transfer]; assert by[issue]["coverage_status"]=="not_attested" and float(by[issue]["unattested_quantity"])==1,by[issue]; print("real JWT report: fully linked receipt/transfer and unlinked customer issue passed")' "$RECEIPT" "$TRANSFER" "$ISSUE" <<<"$COVERAGE"

BLOCKED_COVERAGE="$(printf '{"p_organization_id":"%s","p_factory_id":"%s","p_limit":200}' "$ORG_ID" "$FACTORY_BLOCKED")"
gas_tx_denied "$ACCESS_TOKEN" gas_serial_attestation_coverage "$BLOCKED_COVERAGE"

ANON_COVERAGE_FILE="$(mktemp)"
ANON_COVERAGE_STATUS="$(curl --silent --show-error -o "$ANON_COVERAGE_FILE" -w '%{http_code}' \
 -X POST "$API_URL/rest/v1/rpc/gas_serial_attestation_coverage" \
 -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
 --data "$COVERAGE_BODY")"
if [[ "$ANON_COVERAGE_STATUS" == 2* ]]; then
  echo 'Anonymous serial attestation coverage API unexpectedly succeeded' >&2
  cat "$ANON_COVERAGE_FILE" >&2
  rm -f "$ANON_COVERAGE_FILE"
  exit 1
fi
rm -f "$ANON_COVERAGE_FILE"
echo 'Phase 21C JWT serial evidence coverage and access denial passed'
