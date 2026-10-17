#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
EMPLOYEE_EMAIL='e2e-login@factoryos.test'
EMPLOYEE_PASSWORD='Password123!'
MANAGER_EMAIL='e2e-manager@factoryos.test'
MANAGER_PASSWORD='Manager123!'
ADMIN_EMAIL='e2e-reports-admin@factoryos.test'
ADMIN_PASSWORD='ReportsAdmin123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ALLOWED='42000000-0000-4000-8000-000000000001'
FACTORY_BLOCKED='42000000-0000-4000-8000-000000000002'

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
expect_denied() {
  local token="$1" endpoint="$2" payload="$3" label="$4" tmp status
  tmp="$(mktemp)"
  status="$(curl -sS -o "$tmp" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/$endpoint" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -d "$payload")"
  if [[ "$status" == 2* ]]; then
    echo "$label unexpectedly succeeded." >&2
    cat "$tmp" >&2
    rm -f "$tmp"
    exit 1
  fi
  rm -f "$tmp"
  echo "$label denial passed"
}

EMPLOYEE_TOKEN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
MANAGER_TOKEN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"

ADMIN_SIGNUP="$(curl -fsS -X POST "$API_URL/auth/v1/signup" \
  -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")"
ADMIN_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$ADMIN_SIGNUP")"
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "insert into public.organization_members(organization_id,user_id,role) values('$ORG_ID','$ADMIN_USER_ID','org_admin');"
ADMIN_TOKEN="$(login "$ADMIN_EMAIL" "$ADMIN_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"

FROM_DATE="$(date -u -d '29 days ago' +%F)"
TO_DATE="$(date -u +%F)"

MANAGER_DASH="$(rpc "$MANAGER_TOKEN" reports_executive_dashboard "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_from\":\"$FROM_DATE\",\"p_to\":\"$TO_DATE\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); required={"sales_billed","purchase_billed","inventory_quantity","production_output","quality_pass_rate","open_sales_orders","warehouse_open_picks","active_trips","dispatch_open_exceptions","maintenance_open_work","active_employees"}; missing=required-set(row); assert not missing,(missing,row); print("factory manager executive dashboard passed")' <<<"$MANAGER_DASH"

TREND="$(rpc "$MANAGER_TOKEN" reports_daily_trend "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_from\":\"$FROM_DATE\",\"p_to\":\"$TO_DATE\"}")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert len(rows)==30,len(rows); assert all({"day","sales_billed","purchase_billed","production_planned","production_output","deliveries_completed"}<=set(r) for r in rows); print("daily reporting trend passed")' <<<"$TREND"

EXCEPTIONS="$(rpc "$MANAGER_TOKEN" reports_operational_exceptions "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_limit\":50}")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert all({"module","severity","title","detail","entity_type","entity_id","occurred_at"}<=set(r) for r in rows),rows; print("operational exceptions report passed")' <<<"$EXCEPTIONS"

ACTIVITY="$(rpc "$MANAGER_TOKEN" reports_recent_activity "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_limit\":20}")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert all({"audit_id","action","entity_type","entity_id","actor_name","occurred_at"}<=set(r) for r in rows),rows; print("recent audited activity report passed")' <<<"$ACTIVITY"

expect_denied "$MANAGER_TOKEN" reports_executive_dashboard "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":null,\"p_from\":\"$FROM_DATE\",\"p_to\":\"$TO_DATE\"}" 'factory manager organization-wide report'
expect_denied "$MANAGER_TOKEN" reports_executive_dashboard "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_BLOCKED\",\"p_from\":\"$FROM_DATE\",\"p_to\":\"$TO_DATE\"}" 'factory manager cross-factory report'
expect_denied "$EMPLOYEE_TOKEN" reports_executive_dashboard "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_from\":\"$FROM_DATE\",\"p_to\":\"$TO_DATE\"}" 'employee executive report'

ADMIN_DASH="$(rpc "$ADMIN_TOKEN" reports_executive_dashboard "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":null,\"p_from\":\"$FROM_DATE\",\"p_to\":\"$TO_DATE\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert "active_employees" in row and int(row["active_employees"])>=2,row; print("organization admin organization-wide report passed")' <<<"$ADMIN_DASH"

VIEW_RESPONSE="$(curl -fsS -X POST "$API_URL/rest/v1/report_saved_views?select=id,name,report_key,factory_id" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN" \
  -H 'Content-Type: application/json' -H 'Prefer: return=representation' \
  -d "{\"organization_id\":\"$ORG_ID\",\"factory_id\":\"$FACTORY_ALLOWED\",\"user_id\":\"$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD")")\",\"name\":\"30-day plant view\",\"report_key\":\"executive\",\"filters\":{\"days\":30},\"is_default\":true}")"
VIEW_ID="$(python3 -c 'import json,sys; rows=json.load(sys.stdin); assert len(rows)==1 and rows[0]["name"]=="30-day plant view",rows; print(rows[0]["id"])' <<<"$VIEW_RESPONSE")"
[[ -n "$VIEW_ID" ]]
echo 'manager saved report view passed'

TMP="$(mktemp)"
MANAGER_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD")")"
STATUS="$(curl -sS -o "$TMP" -w '%{http_code}' -X POST "$API_URL/rest/v1/report_saved_views" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"organization_id\":\"$ORG_ID\",\"factory_id\":null,\"user_id\":\"$MANAGER_USER_ID\",\"name\":\"Forbidden org view\",\"report_key\":\"executive\",\"filters\":{}}")"
if [[ "$STATUS" == 2* ]]; then
  echo 'Factory manager unexpectedly saved an organization-wide report view.' >&2
  cat "$TMP" >&2
  rm -f "$TMP"
  exit 1
fi
rm -f "$TMP"
echo 'saved-view scope denial passed'

echo 'reports and dashboards authenticated E2E checks passed'
