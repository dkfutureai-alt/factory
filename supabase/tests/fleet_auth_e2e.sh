#!/usr/bin/env bash
set -euo pipefail

API_URL='http://127.0.0.1:54321'
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
MANAGER_EMAIL='e2e-manager@factoryos.test'
MANAGER_PASSWORD='Manager123!'
DRIVER_EMAIL='fleet-driver@factoryos.test'
DRIVER_PASSWORD='FleetDriver123!'
ORG_ID='41000000-0000-4000-8000-000000000001'
FACTORY_ID='42000000-0000-4000-8000-000000000001'
BLOCKED_FACTORY_ID='42000000-0000-4000-8000-000000000002'
DEPARTMENT_ID='43000000-0000-4000-8000-000000000001'
DRIVER_EMPLOYEE_ID='48000000-0000-4000-8000-000000000001'
BLOCKED_LOCATION_ID='48100000-0000-4000-8000-000000000001'
BLOCKED_VEHICLE_ID='48200000-0000-4000-8000-000000000001'

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
rpc_checked() {
  local token="$1" name="$2" payload="$3" file status
  file="$(mktemp)"
  status="$(curl -sS -o "$file" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/$name" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$payload")"
  if [[ "$status" != 2* ]]; then
    echo "$name failed with HTTP $status" >&2
    cat "$file" >&2
    rm -f "$file"
    return 1
  fi
  cat "$file"
  rm -f "$file"
}
expect_denied() {
  local token="$1" name="$2" payload="$3" label="$4" file status
  file="$(mktemp)"
  status="$(curl -sS -o "$file" -w '%{http_code}' -X POST "$API_URL/rest/v1/rpc/$name" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$payload")"
  if [[ "$status" == 2* ]]; then echo "$label unexpectedly succeeded." >&2; cat "$file" >&2; rm -f "$file"; exit 1; fi
  rm -f "$file"
  echo "$label denial passed"
}

DRIVER_SIGNUP="$(signup "$DRIVER_EMAIL" "$DRIVER_PASSWORD")"
DRIVER_USER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])' <<<"$DRIVER_SIGNUP")"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
insert into public.organization_members(organization_id,user_id,role)
values('$ORG_ID','$DRIVER_USER_ID','driver');

insert into public.factory_members(organization_id,factory_id,user_id)
values('$ORG_ID','$FACTORY_ID','$DRIVER_USER_ID');

insert into public.employees(
 id,organization_id,user_id,employee_code,full_name,email,primary_factory_id,department_id,join_date,status
) values(
 '$DRIVER_EMPLOYEE_ID','$ORG_ID','$DRIVER_USER_ID','E2EDRV1','E2E Fleet Driver','$DRIVER_EMAIL','$FACTORY_ID','$DEPARTMENT_ID',current_date,'active'
);

insert into public.stock_locations(id,organization_id,factory_id,name,code,location_type,is_active)
values('$BLOCKED_LOCATION_ID','$ORG_ID','$BLOCKED_FACTORY_ID','Blocked E2E Vehicle Location','VEH-BLOCKE2E','vehicle',true);

insert into public.fleet_vehicles(
 id,organization_id,factory_id,stock_location_id,vehicle_code,registration_no,vehicle_type,fuel_type,current_odometer_km,status
) values(
 '$BLOCKED_VEHICLE_ID','$ORG_ID','$BLOCKED_FACTORY_ID','$BLOCKED_LOCATION_ID','BLK01','E2E-BLOCKED-01','truck','diesel',500,'active'
);
SQL

MANAGER_TOKEN="$(login "$MANAGER_EMAIL" "$MANAGER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
DRIVER_TOKEN="$(login "$DRIVER_EMAIL" "$DRIVER_PASSWORD" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"

expect_denied "$DRIVER_TOKEN" fleet_create_vehicle '{"p_factory_id":"42000000-0000-4000-8000-000000000001","p_vehicle_code":"DRVNO","p_registration_no":"E2E-DENIED","p_vehicle_type":"truck"}' 'driver vehicle creation'
expect_denied "$MANAGER_TOKEN" fleet_create_vehicle "{\"p_factory_id\":\"$BLOCKED_FACTORY_ID\",\"p_vehicle_code\":\"CROSS\",\"p_registration_no\":\"E2E-CROSS\",\"p_vehicle_type\":\"truck\"}" 'factory manager cross-factory vehicle creation'

VEHICLE_ID="$(rpc "$MANAGER_TOKEN" fleet_create_vehicle "{\"p_factory_id\":\"$FACTORY_ID\",\"p_vehicle_code\":\"E2ETRK\",\"p_registration_no\":\"E2E-MH13-TRK01\",\"p_vehicle_type\":\"truck\",\"p_make\":\"E2E Motors\",\"p_model\":\"Test Hauler\",\"p_fuel_type\":\"diesel\",\"p_capacity_quantity\":80,\"p_capacity_unit\":\"cylinders\",\"p_current_odometer_km\":1000}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$VEHICLE_ID" ]]
OTHER_VEHICLE_ID="$(rpc "$MANAGER_TOKEN" fleet_create_vehicle "{\"p_factory_id\":\"$FACTORY_ID\",\"p_vehicle_code\":\"E2EOTH\",\"p_registration_no\":\"E2E-MH13-OTH01\",\"p_vehicle_type\":\"truck\",\"p_fuel_type\":\"diesel\",\"p_current_odometer_km\":500}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$OTHER_VEHICLE_ID" ]]
DRIVER_ID="$(rpc "$MANAGER_TOKEN" fleet_create_driver "{\"p_factory_id\":\"$FACTORY_ID\",\"p_employee_id\":\"$DRIVER_EMPLOYEE_ID\",\"p_license_no\":\"E2E-LIC-HMV-01\",\"p_license_type\":\"HMV\",\"p_license_expiry\":\"2099-12-31\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$DRIVER_ID" ]]
ASSIGNMENT_ID="$(rpc "$MANAGER_TOKEN" fleet_assign_driver "{\"p_vehicle_id\":\"$VEHICLE_ID\",\"p_driver_id\":\"$DRIVER_ID\",\"p_effective_from\":\"2026-01-01T00:00:00Z\",\"p_notes\":\"E2E active assignment\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$ASSIGNMENT_ID" ]]
echo 'manager vehicle + driver + active assignment passed'

expect_denied "$DRIVER_TOKEN" fleet_record_fuel "{\"p_vehicle_id\":\"$OTHER_VEHICLE_ID\",\"p_driver_id\":\"$DRIVER_ID\",\"p_trip_id\":null,\"p_quantity_liters\":5,\"p_price_per_liter\":95,\"p_odometer_km\":510}" 'driver fuel entry for unassigned vehicle'
expect_denied "$DRIVER_TOKEN" fleet_create_trip "{\"p_factory_id\":\"$FACTORY_ID\",\"p_vehicle_id\":\"$VEHICLE_ID\",\"p_driver_id\":\"$DRIVER_ID\",\"p_origin\":\"Allowed Plant\",\"p_destination\":\"E2E Customer\",\"p_planned_start_at\":\"2099-01-01T08:00:00Z\"}" 'driver trip planning'

TRIP_RESPONSE="$(rpc_checked "$MANAGER_TOKEN" fleet_create_trip "{\"p_factory_id\":\"$FACTORY_ID\",\"p_vehicle_id\":\"$VEHICLE_ID\",\"p_driver_id\":\"$DRIVER_ID\",\"p_origin\":\"Allowed Plant\",\"p_destination\":\"E2E Customer\",\"p_planned_start_at\":\"2099-01-01T08:00:00Z\",\"p_planned_end_at\":\"2099-01-01T12:00:00Z\",\"p_sales_order_id\":null,\"p_warehouse_handoff_id\":null,\"p_notes\":\"Fleet E2E trip\"}")"
TRIP_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin))' <<<"$TRIP_RESPONSE")"
[[ -n "$TRIP_ID" ]]

rpc_checked "$DRIVER_TOKEN" fleet_start_trip "{\"p_trip_id\":\"$TRIP_ID\",\"p_odometer_km\":1010,\"p_notes\":\"Driver started\"}" >/dev/null
FUEL_ID="$(rpc_checked "$DRIVER_TOKEN" fleet_record_fuel "{\"p_vehicle_id\":\"$VEHICLE_ID\",\"p_driver_id\":\"$DRIVER_ID\",\"p_trip_id\":\"$TRIP_ID\",\"p_quantity_liters\":20,\"p_price_per_liter\":95,\"p_odometer_km\":1030,\"p_vendor\":\"E2E Fuel Point\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$FUEL_ID" ]]
rpc_checked "$DRIVER_TOKEN" fleet_mark_trip_arrived "{\"p_trip_id\":\"$TRIP_ID\",\"p_odometer_km\":1050,\"p_notes\":\"Reached customer\"}" >/dev/null
rpc_checked "$DRIVER_TOKEN" fleet_complete_trip "{\"p_trip_id\":\"$TRIP_ID\",\"p_odometer_km\":1060,\"p_notes\":\"Returned/closed route\"}" >/dev/null

TRIP_STATE="$(psql "$DB_URL" -Atc "select status||'|'||start_odometer_km||'|'||arrival_odometer_km||'|'||end_odometer_km from public.fleet_trips where id='$TRIP_ID'")"
[[ "$TRIP_STATE" == 'completed|1010.00|1050.00|1060.00' || "$TRIP_STATE" == 'completed|1010|1050|1060' ]]
VEHICLE_ODO="$(psql "$DB_URL" -Atc "select current_odometer_km from public.fleet_vehicles where id='$VEHICLE_ID'")"
[[ "$VEHICLE_ODO" == '1060.00' || "$VEHICLE_ODO" == '1060' ]]
ODO_LOGS="$(psql "$DB_URL" -Atc "select count(*) from public.fleet_odometer_logs where trip_id='$TRIP_ID'")"
[[ "$ODO_LOGS" == '4' ]]
FUEL_TOTAL="$(psql "$DB_URL" -Atc "select total_amount from public.fleet_fuel_entries where id='$FUEL_ID'")"
[[ "$FUEL_TOTAL" == '1900.00' || "$FUEL_TOTAL" == '1900' ]]
echo 'driver start → fuel → arrive → complete with odometer history passed'

expect_denied "$DRIVER_TOKEN" fleet_create_service_reminder "{\"p_vehicle_id\":\"$VEHICLE_ID\",\"p_reminder_type\":\"service\",\"p_title\":\"Driver must not schedule service\",\"p_due_odometer_km\":2000}" 'driver service-reminder creation'
REMINDER_ID="$(rpc "$MANAGER_TOKEN" fleet_create_service_reminder "{\"p_vehicle_id\":\"$VEHICLE_ID\",\"p_reminder_type\":\"service\",\"p_title\":\"E2E preventive service\",\"p_due_odometer_km\":1500}" | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
[[ -n "$REMINDER_ID" ]]
rpc "$MANAGER_TOKEN" fleet_complete_service_reminder "{\"p_reminder_id\":\"$REMINDER_ID\",\"p_completed_odometer_km\":1060,\"p_notes\":\"E2E service closed\"}" >/dev/null
REMINDER_STATUS="$(psql "$DB_URL" -Atc "select status from public.fleet_service_reminders where id='$REMINDER_ID'")"
[[ "$REMINDER_STATUS" == 'completed' ]]
echo 'manager service reminder lifecycle passed'

DRIVER_VEHICLES="$(curl -fsS "$API_URL/rest/v1/fleet_vehicles?select=id,factory_id&order=vehicle_code" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $DRIVER_TOKEN")"
python3 -c 'import json,sys; allowed=sys.argv[1]; blocked=sys.argv[2]; rows=json.load(sys.stdin); ids={r["id"] for r in rows}; assert allowed in ids and blocked not in ids, rows; print("driver fleet RLS factory isolation passed")' "$VEHICLE_ID" "$BLOCKED_VEHICLE_ID" <<<"$DRIVER_VEHICLES"

expect_denied "$DRIVER_TOKEN" fleet_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\"}" 'driver organization-wide fleet dashboard'
DRIVER_DASHBOARD="$(rpc "$DRIVER_TOKEN" fleet_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert int(row["active_vehicles"])>=1, row; print("driver factory-scoped fleet dashboard passed")' <<<"$DRIVER_DASHBOARD"

DASHBOARD="$(rpc "$MANAGER_TOKEN" fleet_dashboard_summary "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\"}")"
python3 -c 'import json,sys; row=json.load(sys.stdin); assert int(row["active_vehicles"])>=1 and int(row["active_drivers"])>=1, row; print("fleet dashboard report passed")' <<<"$DASHBOARD"
TRIPS="$(rpc "$MANAGER_TOKEN" fleet_trip_report "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\",\"p_limit\":20}")"
python3 -c 'import json,sys; trip=sys.argv[1]; rows=json.load(sys.stdin); assert any(r["trip_id"]==trip and r["status"]=="completed" for r in rows), rows; print("fleet trip report passed")' "$TRIP_ID" <<<"$TRIPS"
FUEL="$(rpc "$MANAGER_TOKEN" fleet_fuel_report "{\"p_organization_id\":\"$ORG_ID\",\"p_factory_id\":\"$FACTORY_ID\",\"p_limit\":20}")"
python3 -c 'import json,sys; fuel=sys.argv[1]; rows=json.load(sys.stdin); assert any(r["fuel_entry_id"]==fuel for r in rows), rows; print("fleet fuel report passed")' "$FUEL_ID" <<<"$FUEL"

echo 'authenticated fleet E2E flow passed'
