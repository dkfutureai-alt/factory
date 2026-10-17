#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
EMPLOYEE_EMAIL='e2e-login@factoryos.test'
EMPLOYEE_PASSWORD='Password123!'
MANAGER_EMAIL='e2e-manager@factoryos.test'
MANAGER_PASSWORD='Manager123!'
ADMIN_EMAIL='e2e-security-admin@factoryos.test'
ADMIN_PASSWORD='SecurityAdmin123!'
BLOCKED_EMAIL='e2e-security-blocked@factoryos.test'
BLOCKED_PASSWORD='BlockedUser123!'
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
signup() {
  curl -fsS -X POST "$API_URL/auth/v1/signup" \
    -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}"
}

EMPLOYEE_LOGIN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD")"
MANAGER_LOGIN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD")"
EMPLOYEE_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$EMPLOYEE_LOGIN")"
EMPLOYEE_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$EMPLOYEE_LOGIN")"
MANAGER_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$MANAGER_LOGIN")"
MANAGER_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$MANAGER_LOGIN")"

ADMIN_SIGNUP="$(signup "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
BLOCKED_SIGNUP="$(signup "$BLOCKED_EMAIL" "$BLOCKED_PASSWORD")"
ADMIN_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$ADMIN_SIGNUP")"
BLOCKED_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$BLOCKED_SIGNUP")"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.profiles(id,full_name,is_active) values
  ('$EMPLOYEE_USER_ID','E2E Employee',true),
  ('$MANAGER_USER_ID','E2E Factory Manager',true),
  ('$ADMIN_USER_ID','E2E Security Admin',true),
  ('$BLOCKED_USER_ID','E2E Blocked Employee',true)
on conflict(id) do update set full_name=excluded.full_name,is_active=true;

insert into public.organization_members(organization_id,user_id,role,is_active)
values('$ORG_ID','$ADMIN_USER_ID','org_admin',true),
      ('$ORG_ID','$BLOCKED_USER_ID','employee',true)
on conflict(organization_id,user_id) do update set role=excluded.role,is_active=true;

insert into public.factory_members(organization_id,factory_id,user_id,is_active)
values('$ORG_ID','$FACTORY_BLOCKED','$BLOCKED_USER_ID',true)
on conflict(factory_id,user_id) do update set is_active=true;
SQL

ADMIN_LOGIN="$(login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
ADMIN_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$ADMIN_LOGIN")"

ALLOWED_MEMBER="$(rpc "$MANAGER_TOKEN" is_factory_member "{\"target_factory_id\":\"$FACTORY_ALLOWED\"}")"
BLOCKED_MEMBER="$(rpc "$MANAGER_TOKEN" is_factory_member "{\"target_factory_id\":\"$FACTORY_BLOCKED\"}")"
python3 -c 'import json,sys; assert json.loads(sys.argv[1]) is True; assert json.loads(sys.argv[2]) is False; print("factory-manager assignment-scoped membership passed")' "$ALLOWED_MEMBER" "$BLOCKED_MEMBER"

MEMBERS="$(curl -fsS "$API_URL/rest/v1/organization_members?select=user_id,role&organization_id=eq.$ORG_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); blocked=sys.argv[1]; manager=sys.argv[2]; employee=sys.argv[3]; ids={r["user_id"] for r in rows}; assert blocked not in ids,rows; assert manager in ids and employee in ids,rows; print("factory-manager organization-member data minimization passed")' "$BLOCKED_USER_ID" "$MANAGER_USER_ID" "$EMPLOYEE_USER_ID" <<<"$MEMBERS"

PROFILES="$(curl -fsS "$API_URL/rest/v1/profiles?select=id,full_name" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); blocked=sys.argv[1]; ids={r["id"] for r in rows}; assert blocked not in ids,rows; print("factory-manager profile cross-factory privacy passed")' "$BLOCKED_USER_ID" <<<"$PROFILES"

ASSIGNMENTS="$(curl -fsS "$API_URL/rest/v1/factory_members?select=factory_id,user_id&organization_id=eq.$ORG_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); blocked_factory=sys.argv[1]; blocked_user=sys.argv[2]; assert not any(r["factory_id"]==blocked_factory and r["user_id"]==blocked_user for r in rows),rows; print("factory-manager factory-assignment privacy passed")' "$FACTORY_BLOCKED" "$BLOCKED_USER_ID" <<<"$ASSIGNMENTS"

MODULE="$(curl -fsS "$API_URL/rest/v1/organization_modules?select=module_key,is_enabled&organization_id=eq.$ORG_ID&module_key=eq.security" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert len(rows)==1 and rows[0]["is_enabled"] is True,rows; print("security module auto-enable passed")' <<<"$MODULE"

MANAGER_SUMMARY="$(rpc "$MANAGER_TOKEN" security_admin_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); required={"audit_events_24h","high_risk_changes_7d","access_anomalies","privileged_members","integrity_status"}; assert required<=set(row),row; assert row["integrity_status"]=="verified",row; print("factory-manager scoped security summary passed")' <<<"$MANAGER_SUMMARY"
expect_denied "$MANAGER_TOKEN" security_admin_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":null}" 'factory-manager organization-wide security summary'
expect_denied "$MANAGER_TOKEN" security_admin_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_BLOCKED\"}" 'factory-manager blocked-factory security summary'
expect_denied "$EMPLOYEE_TOKEN" security_admin_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\"}" 'employee security summary'

ADMIN_SUMMARY="$(rpc "$ADMIN_TOKEN" security_admin_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":null}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert row["integrity_status"]=="verified",row; print("organization-admin security summary passed")' <<<"$ADMIN_SUMMARY"

MANAGER_REVIEW="$(rpc "$MANAGER_TOKEN" security_access_review "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\"}")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); blocked=sys.argv[1]; assert blocked not in {r["user_id"] for r in rows},rows; print("factory-manager access review scope passed")' "$BLOCKED_USER_ID" <<<"$MANAGER_REVIEW"
ADMIN_REVIEW="$(rpc "$ADMIN_TOKEN" security_access_review "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":null}")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); blocked=sys.argv[1]; assert blocked in {r["user_id"] for r in rows},rows; print("organization-admin access review passed")' "$BLOCKED_USER_ID" <<<"$ADMIN_REVIEW"

MANAGER_INTEGRITY="$(rpc "$MANAGER_TOKEN" security_verify_audit_integrity "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_limit\":1000}")"
ADMIN_INTEGRITY="$(rpc "$ADMIN_TOKEN" security_verify_audit_integrity "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":null,\"p_limit\":1000}")"
python3 -c 'import json,sys; a=json.loads(sys.argv[1]); b=json.loads(sys.argv[2]); assert a["status"]=="verified" and int(a["broken_hashes"])==0 and int(a["broken_chain_links"])==0,a; assert b["status"]=="verified",b; print("audit integrity verification passed")' "$MANAGER_INTEGRITY" "$ADMIN_INTEGRITY"

AUDIT_FEED="$(rpc "$MANAGER_TOKEN" security_audit_feed "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_limit\":100}")"
AUDIT_ID="$(python3 -c 'import json,sys; rows=json.load(sys.stdin); allowed=sys.argv[1]; assert rows,rows; assert all(r["factory_id"]==allowed for r in rows),rows; assert all(len(r["integrity_hash"] or "")==64 for r in rows),rows; print(rows[0]["audit_id"])' "$FACTORY_ALLOWED" <<<"$AUDIT_FEED")"
echo 'factory-manager audit-feed factory isolation passed'

DIRECT_AUDIT="$(curl -fsS "$API_URL/rest/v1/audit_logs?select=id,factory_id&organization_id=eq.$ORG_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); blocked=sys.argv[1]; assert not any(r["factory_id"]==blocked for r in rows),rows; print("audit-log RLS blocked-factory isolation passed")' "$FACTORY_BLOCKED" <<<"$DIRECT_AUDIT"

TMP="$(mktemp)"
PATCH_STATUS="$(curl -sS -o "$TMP" -w '%{http_code}' -X PATCH "$API_URL/rest/v1/audit_logs?id=eq.$AUDIT_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $MANAGER_TOKEN" \
  -H 'Content-Type: application/json' -d '{"action":"tampered"}')"
if [[ "$PATCH_STATUS" == 2* ]]; then
  echo 'Authenticated audit mutation unexpectedly succeeded.' >&2
  cat "$TMP" >&2
  rm -f "$TMP"
  exit 1
fi
rm -f "$TMP"
echo 'audit immutability permission denial passed'

echo 'Phase 14 authenticated Audit & Security hardening E2E passed'
