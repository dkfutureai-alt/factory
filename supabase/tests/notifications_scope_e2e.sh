#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
MANAGER_EMAIL='e2e-manager@factoryos.test'
MANAGER_PASSWORD='Manager123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ALLOWED='42000000-0000-4000-8000-000000000001'
FACTORY_BLOCKED='42000000-0000-4000-8000-000000000002'

STATUS_ENV="$(supabase status -o env)"
ANON_KEY="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')"
LOGIN="$(curl -fsS -X POST "$API_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$MANAGER_EMAIL\",\"password\":\"$MANAGER_PASSWORD\"}")"
TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$LOGIN")"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.notification_rules(
  organization_id,factory_id,event_key,template_id,audience_roles,channels,is_active
)
select
  '$ORG_ID'::uuid,
  '$FACTORY_BLOCKED'::uuid,
  'system.blocked_factory_test',
  nt.id,
  array['factory_manager']::public.app_role[],
  array['in_app']::text[],
  true
from public.notification_templates nt
where nt.organization_id='$ORG_ID'::uuid
order by nt.created_at
limit 1
on conflict do nothing;
SQL

GLOBAL_RULES="$(curl -fsS \
  "$API_URL/rest/v1/notification_rules?select=factory_id,event_key&factory_id=is.null&order=event_key" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert rows, rows; assert all(r["factory_id"] is None for r in rows), rows; print("factory manager global notification-rule visibility passed")' <<<"$GLOBAL_RULES"

BLOCKED_RULES="$(curl -fsS \
  "$API_URL/rest/v1/notification_rules?select=factory_id,event_key&event_key=eq.system.blocked_factory_test" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert rows==[], rows; print("factory manager cross-factory notification-rule denial passed")' <<<"$BLOCKED_RULES"

TMP="$(mktemp)"
STATUS="$(curl -sS -o "$TMP" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/notification_admin_summary" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_BLOCKED\"}")"
if [[ "$STATUS" == 2* ]]; then
  echo 'Factory manager unexpectedly accessed blocked-factory notification summary.' >&2
  cat "$TMP" >&2
  rm -f "$TMP"
  exit 1
fi
rm -f "$TMP"
echo 'factory manager blocked-factory notification summary denial passed'

ALLOWED="$(curl -fsS -X POST "$API_URL/rest/v1/rpc/notification_admin_summary" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert "active_rules" in row,row; print("factory manager allowed-factory notification summary passed")' <<<"$ALLOWED"

echo 'notification exact-scope E2E checks passed'
