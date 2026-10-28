#!/usr/bin/env bash
set -euo pipefail
# Local CI fixtures only. Run after auth_login_e2e.sh and security_auth_e2e.sh.
# Those scripts run in separate shells. Re-authenticate rather than depend on
# non-exported variables or create duplicate accounts in a shared CI database.
API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
ORG_ID='41000000-0000-4000-8000-000000000001'
ANON_KEY="$(supabase status -o env | sed -n 's/^ANON_KEY="\\(.*\\)"/\\1/p')"
if [[ -z "$ANON_KEY" ]]; then echo 'Local Supabase API key unavailable.' >&2; exit 1; fi
B_ORG='61000000-0000-4000-8000-000000000001'
B_EMAIL='e2e-pilot-other-tenant@factoryos.test'
B_PASSWORD='PilotOtherTenant123!'
api() {
  local token="$1" method="$2" path="$3"
  shift 3
  curl -fsS -X "$method" "$API_URL/rest/v1/$path" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' "$@"
}
denied() {
  local token="$1" method="$2" path="$3" data="$4" label="$5"
  local tmp status
  tmp="$(mktemp)"
  status="$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$API_URL/rest/v1/$path" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -d "$data")"
  rm -f "$tmp"
  if [[ "$status" != 4* ]]; then
    echo "Expected 4xx for $label; received HTTP $status" >&2
    exit 1
  fi
  echo "Denied: $label"
}
rows() {
  python3 -c 'import json,sys; r=json.load(sys.stdin); n=int(sys.argv[1]); assert isinstance(r,list) and len(r)==n, f"Expected {n}, got {r}"; print(sys.argv[2])' "$1" "$2"
}
login() {
  curl -fsS -X POST "$API_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}"
}
A_LOGIN="$(login e2e-login@factoryos.test 'Password123!')"
USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$A_LOGIN")"
ACCESS_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$A_LOGIN")"
B_SIGNUP="$(curl -fsS -X POST "$API_URL/auth/v1/signup" \
  -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$B_EMAIL\",\"password\":\"$B_PASSWORD\"}")"
B_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$B_SIGNUP")"
B_LOGIN="$(login "$B_EMAIL" "$B_PASSWORD")"
B_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$B_LOGIN")"
ADMIN_LOGIN="$(login e2e-security-admin@factoryos.test SecurityAdmin123!)"
ADMIN_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$ADMIN_LOGIN")"
psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.organizations(id,name,code)
values('$B_ORG','Pilot Other Tenant','PILOT-OTHER');
insert into public.organization_members(organization_id,user_id,role)
values('$B_ORG','$B_ID','viewer');
SQL
denied "$ANON_KEY" GET 'pilot_feedback?select=id' '' 'anonymous pilot-feedback read'
api "$ACCESS_TOKEN" GET 'pilot_participants?select=user_id' | rows 0 'No default enrollment'
api "$ACCESS_TOKEN" POST 'pilot_participants' \
  -d "{\"organization_id\":\"$ORG_ID\",\"user_id\":\"$USER_ID\"}" >/dev/null
api "$ACCESS_TOKEN" GET 'pilot_participants?select=user_id,consented_at' | \
  python3 -c 'import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["user_id"]==sys.argv[1] and r[0]["consented_at"]; print("Employee self-enrollment passed")' "$USER_ID"
api "$ACCESS_TOKEN" POST 'pilot_feedback' \
  -d "{\"organization_id\":\"$ORG_ID\",\"user_id\":\"$USER_ID\",\"scenario\":\"inventory\",\"result\":\"failed\",\"notes\":\"Local scanner failure test\"}" >/dev/null
api "$ACCESS_TOKEN" GET 'pilot_feedback?select=result,notes' | rows 1 'Real Auth feedback submission'
api "$ADMIN_TOKEN" GET "pilot_feedback?select=id&organization_id=eq.$ORG_ID" | rows 1 'Org admin review'
api "$B_TOKEN" GET 'pilot_feedback?select=id' | rows 0 'Other tenant feedback read denied'
api "$B_TOKEN" GET 'pilot_participants?select=user_id' | rows 0 'Other tenant participant read denied'
denied "$B_TOKEN" POST 'pilot_feedback' \
  "{\"organization_id\":\"$ORG_ID\",\"user_id\":\"$B_ID\",\"scenario\":\"hr\",\"result\":\"passed\"}" \
  'cross-tenant forged feedback'
denied "$ADMIN_TOKEN" POST 'pilot_participants' \
  "{\"organization_id\":\"$ORG_ID\",\"user_id\":\"$USER_ID\"}" \
  'admin creating consent for another tester'
denied "$ACCESS_TOKEN" POST 'pilot_feedback' \
  "{\"organization_id\":\"$ORG_ID\",\"user_id\":\"$B_ID\",\"scenario\":\"hr\",\"result\":\"passed\"}" \
  'employee impersonating another tester'
api "$B_TOKEN" POST 'pilot_participants' \
  -d "{\"organization_id\":\"$B_ORG\",\"user_id\":\"$B_ID\"}" >/dev/null
api "$B_TOKEN" POST 'pilot_feedback' \
  -d "{\"organization_id\":\"$B_ORG\",\"user_id\":\"$B_ID\",\"scenario\":\"hr\",\"result\":\"blocked\"}" >/dev/null
api "$B_TOKEN" GET 'pilot_feedback?select=result' | rows 1 'Independent tenant pilot reporting'
api "$ADMIN_TOKEN" GET 'pilot_feedback?select=id' | rows 1 'Org A admin cannot see Org B report'
api "$ACCESS_TOKEN" DELETE "pilot_participants?organization_id=eq.$ORG_ID&user_id=eq.$USER_ID" >/dev/null
api "$ACCESS_TOKEN" GET 'pilot_feedback?select=id' | rows 0 'Withdrawal erased pilot feedback'
api "$ACCESS_TOKEN" GET "organization_members?select=user_id&user_id=eq.$USER_ID" | \
  rows 1 'Withdrawal preserved normal factory membership'
denied "$ACCESS_TOKEN" POST 'pilot_feedback' \
  "{\"organization_id\":\"$ORG_ID\",\"user_id\":\"$USER_ID\",\"scenario\":\"inventory\",\"result\":\"passed\"}" \
  'report after consent withdrawal'
echo 'Phase 19 authenticated customer-pilot API E2E passed'
