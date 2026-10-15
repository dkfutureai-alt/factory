#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
EMAIL='e2e-login@factoryos.test'
PASSWORD='Password123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ALLOWED='42000000-0000-4000-8000-000000000001'
FACTORY_BLOCKED='42000000-0000-4000-8000-000000000002'
DEPARTMENT_ID='43000000-0000-4000-8000-000000000001'
SHIFT_ID='44000000-0000-4000-8000-000000000001'
LEAVE_TYPE_ID='45000000-0000-4000-8000-000000000001'
EMPLOYEE_ALLOWED='46000000-0000-4000-8000-000000000001'
EMPLOYEE_BLOCKED='46000000-0000-4000-8000-000000000002'

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

insert into public.departments (id, organization_id, name, code)
values ('$DEPARTMENT_ID', '$ORG_ID', 'Production', 'PROD');

insert into public.shifts (
  id, organization_id, factory_id, name, code, start_time, end_time
) values (
  '$SHIFT_ID', '$ORG_ID', '$FACTORY_ALLOWED', 'Day Shift', 'D1', '06:00', '14:00'
);

insert into public.leave_types (
  id, organization_id, name, code, is_paid, max_days_per_year
) values (
  '$LEAVE_TYPE_ID', '$ORG_ID', 'Casual Leave', 'CL', true, 12
);

insert into public.employees (
  id, organization_id, user_id, employee_code, full_name,
  primary_factory_id, department_id, shift_id, join_date
) values (
  '$EMPLOYEE_ALLOWED', '$ORG_ID', '$USER_ID', 'E2E001', 'E2E Employee',
  '$FACTORY_ALLOWED', '$DEPARTMENT_ID', '$SHIFT_ID', current_date
), (
  '$EMPLOYEE_BLOCKED', '$ORG_ID', null, 'E2E002', 'Blocked Employee',
  '$FACTORY_BLOCKED', '$DEPARTMENT_ID', null, current_date
);
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

EMPLOYEE_RESPONSE="$(curl -fsS \
  "$API_URL/rest/v1/employees?select=id,employee_code,full_name&order=employee_code" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN")"

python3 -c 'import json,sys; allowed=sys.argv[1]; rows=json.load(sys.stdin); ids={r["id"] for r in rows}; assert ids=={allowed}, f"expected only linked employee {allowed}, got {ids}"; print("employee HR RLS passed")' "$EMPLOYEE_ALLOWED" <<<"$EMPLOYEE_RESPONSE"

MY_EMPLOYEE_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/rest/v1/rpc/my_employee_record" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{}')"

python3 -c 'import json,sys; expected=sys.argv[1]; rows=json.load(sys.stdin); assert len(rows)==1 and rows[0]["employee_id"]==expected, rows; print("employee self profile RPC passed")' "$EMPLOYEE_ALLOWED" <<<"$MY_EMPLOYEE_RESPONSE"

ATTENDANCE_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/rest/v1/rpc/mark_my_attendance" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"p_action":"check_in"}')"

python3 -c 'import json,sys; row=json.load(sys.stdin); assert row["status"]=="present" and row["check_in_at"], row; print("employee self check-in RPC passed")' <<<"$ATTENDANCE_RESPONSE"

LEAVE_RESPONSE="$(curl -fsS \
  -X POST "$API_URL/rest/v1/rpc/request_my_leave" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"p_leave_type_id\":\"$LEAVE_TYPE_ID\",\"p_start_date\":\"2099-01-10\",\"p_end_date\":\"2099-01-11\",\"p_reason\":\"E2E leave test\"}")"

LEAVE_ID="$(python3 -c 'import json,sys; value=json.load(sys.stdin); print(value)' <<<"$LEAVE_RESPONSE")"
LEAVE_ROWS="$(curl -fsS \
  "$API_URL/rest/v1/leave_requests?select=id,status,employee_id&id=eq.$LEAVE_ID" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN")"

python3 -c 'import json,sys; employee=sys.argv[1]; rows=json.load(sys.stdin); assert len(rows)==1 and rows[0]["employee_id"]==employee and rows[0]["status"]=="pending", rows; print("employee leave request RPC + RLS passed")' "$EMPLOYEE_ALLOWED" <<<"$LEAVE_ROWS"
