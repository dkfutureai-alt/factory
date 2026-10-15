#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
EMAIL='e2e-login@factoryos.test'
PASSWORD='Password123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ALLOWED='42000000-0000-4000-8000-000000000001'
FACTORY_BLOCKED='42000000-0000-4000-8000-000000000002'

STATUS_ENV="$(supabase status -o env)"
ANON_KEY="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')"
if [[ -z "$ANON_KEY" ]]; then
  echo 'Could not resolve local anonymous API key.' >&2
  exit 1
fi

SIGNUP_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/auth/v1/signup" \
  -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")"

USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$SIGNUP_RESPONSE")"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.organizations (id, name, code)
values ('$ORG_ID', 'Auth E2E Industries', 'AUTH-E2E');
insert into public.factories (id, organization_id, name, code)
values
  ('$FACTORY_ALLOWED', '$ORG_ID', 'Allowed Plant', 'ALLOW'),
  ('$FACTORY_BLOCKED', '$ORG_ID', 'Blocked Plant', 'BLOCK');
insert into public.organization_members (organization_id, user_id, role)
values ('$ORG_ID', '$USER_ID', 'employee');
insert into public.factory_members (organization_id, factory_id, user_id)
values ('$ORG_ID', '$FACTORY_ALLOWED', '$USER_ID');
SQL

LOGIN_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")"
ACCESS_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$LOGIN_RESPONSE")"

FACTORY_RESPONSE="$(curl -fsS \
  "$API_URL/rest/v1/factories?select=id,name&order=name" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN")"

python3 -c 'import json,sys; allowed=sys.argv[1]; rows=json.load(sys.stdin); ids={r["id"] for r in rows}; assert ids=={allowed}, f"expected only {allowed}, got {ids}"; print("real signup + password login + JWT + factory RLS passed")' "$FACTORY_ALLOWED" <<<"$FACTORY_RESPONSE"
