#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
EMPLOYEE_EMAIL='e2e-login@factoryos.test'
EMPLOYEE_PASSWORD='Password123!'
MANAGER_EMAIL='e2e-manager@factoryos.test'
MANAGER_PASSWORD='Manager123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ALLOWED='42000000-0000-4000-8000-000000000001'

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

EMPLOYEE_LOGIN="$(login "$EMPLOYEE_EMAIL" "$EMPLOYEE_PASSWORD")"
MANAGER_LOGIN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD")"
EMPLOYEE_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$EMPLOYEE_LOGIN")"
EMPLOYEE_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$EMPLOYEE_LOGIN")"
MANAGER_TOKEN="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$MANAGER_LOGIN")"

PREFS="$(rpc "$EMPLOYEE_TOKEN" notification_update_preferences "{\"p_organization_id\":\"$ORG_ID\",\"p_in_app_enabled\":true,\"p_push_enabled\":true,\"p_quiet_hours_start\":null,\"p_quiet_hours_end\":null,\"p_allow_critical_during_quiet\":true,\"p_muted_categories\":[]}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert row["in_app_enabled"] is True and row["push_enabled"] is True,row; print("notification preference update passed")' <<<"$PREFS"

DEVICE_ID="$(rpc "$EMPLOYEE_TOKEN" notification_register_device "{\"p_organization_id\":\"$ORG_ID\",\"p_platform\":\"android\",\"p_device_token\":\"e2e-fcm-device-token-000000000001\",\"p_device_name\":\"E2E Android\"}")"
python3 -c 'import json,sys; value=json.load(sys.stdin); assert isinstance(value,str) and len(value)>20,value; print("device registration passed")' <<<"$DEVICE_ID"

BROADCAST_COUNT="$(rpc "$MANAGER_TOKEN" notification_broadcast "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_title\":\"Shift safety reminder\",\"p_body\":\"Wear required PPE before starting the production shift.\",\"p_priority\":\"high\",\"p_category\":\"system\",\"p_roles\":[\"employee\"],\"p_channels\":[\"in_app\",\"push\"]}")"
python3 -c 'import json,sys; value=int(json.load(sys.stdin)); assert value>=1,value; print("manager factory broadcast passed")' <<<"$BROADCAST_COUNT"

INBOX="$(rpc "$EMPLOYEE_TOKEN" notification_inbox '{"p_limit":20,"p_unread_only":true}')"
NOTIFICATION_ID="$(python3 -c 'import json,sys; rows=json.load(sys.stdin); matches=[r for r in rows if r["title"]=="Shift safety reminder"]; assert len(matches)==1,rows; assert matches[0]["priority"]=="high" and matches[0]["read_at"] is None,matches[0]; print(matches[0]["notification_id"])' <<<"$INBOX")"
echo 'employee notification inbox passed'

DELIVERIES="$(curl -fsS "$API_URL/rest/v1/notification_deliveries?select=channel,status,notifications!inner(recipient_user_id)&notifications.recipient_user_id=eq.$EMPLOYEE_USER_ID" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $EMPLOYEE_TOKEN")"
python3 -c 'import json,sys; rows=json.load(sys.stdin); statuses={(r["channel"],r["status"]) for r in rows}; assert ("in_app","sent") in statuses,statuses; assert ("push","queued") in statuses,statuses; print("in-app sent + push queued delivery contract passed")' <<<"$DELIVERIES"

MARKED="$(rpc "$EMPLOYEE_TOKEN" notification_mark_read "{\"p_notification_id\":\"$NOTIFICATION_ID\"}")"
python3 -c 'import json,sys; assert json.load(sys.stdin) is True; print("notification mark-read passed")' <<<"$MARKED"

UNREAD="$(rpc "$EMPLOYEE_TOKEN" notification_unread_count '{}')"
python3 -c 'import json,sys; value=json.load(sys.stdin); assert isinstance(value,int) and value>=0,value; print("notification unread count passed")' <<<"$UNREAD"

SUMMARY="$(rpc "$MANAGER_TOKEN" notification_admin_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); required={"notifications_24h","unread","actionable","push_queued","push_failed","active_devices","active_rules"}; assert required<=set(row),row; assert int(row["push_queued"])>=1,row; print("notification manager summary passed")' <<<"$SUMMARY"

expect_denied "$MANAGER_TOKEN" notification_admin_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":null}" 'factory manager organization-wide notification summary'
expect_denied "$EMPLOYEE_TOKEN" notification_broadcast "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_title\":\"Forbidden\",\"p_body\":\"Employee should not broadcast\"}" 'employee notification broadcast'

MUTED="$(rpc "$EMPLOYEE_TOKEN" notification_update_preferences "{\"p_organization_id\":\"$ORG_ID\",\"p_in_app_enabled\":true,\"p_push_enabled\":true,\"p_quiet_hours_start\":null,\"p_quiet_hours_end\":null,\"p_allow_critical_during_quiet\":true,\"p_muted_categories\":[\"inventory\"]}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert "inventory" in row["muted_categories"],row; print("notification muted-category preference passed")' <<<"$MUTED"

BEFORE="$(rpc "$EMPLOYEE_TOKEN" notification_inbox '{"p_limit":100,"p_unread_only":false}' | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
rpc "$MANAGER_TOKEN" notification_broadcast "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ALLOWED\",\"p_title\":\"Muted inventory alert\",\"p_body\":\"This should be suppressed for the employee.\",\"p_priority\":\"normal\",\"p_category\":\"inventory\",\"p_roles\":[\"employee\"],\"p_channels\":[\"in_app\",\"push\"]}" >/dev/null
AFTER="$(rpc "$EMPLOYEE_TOKEN" notification_inbox '{"p_limit":100,"p_unread_only":false}' | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
if [[ "$BEFORE" != "$AFTER" ]]; then echo "Muted category unexpectedly created inbox item: before=$BEFORE after=$AFTER" >&2; exit 1; fi
echo 'muted category suppression passed'

echo 'notifications authenticated E2E checks passed'
