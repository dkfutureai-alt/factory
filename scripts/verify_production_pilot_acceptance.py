#!/usr/bin/env python3
"""Conservative, read-only acceptance gate for two consenting FactoryOS pilots.

No accounts, pilot reports, transactions, or customer records are created. A
green result means only that required positive records and latest 14-scenario
self-reports are visible under each approved pilot administrator's own JWT;
it cannot substitute for witnessed physical-device/release-owner sign-off.
"""

import os
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode

from production_tenant_isolation_smoke import (
    SmokeError, _sign_in, _uuid, _verify_scoped_reads,
    live_transport, validate_environment,
)

SCENARIOS = frozenset({
    "onboarding", "hr", "inventory", "production", "quality", "purchasing",
    "sales", "warehouse", "fleet", "delivery", "maintenance", "reports",
    "notifications", "security",
})
# Nonempty operational positive controls are required for *each* pilot org.
# These are evidence of visible records, NOT proof of correct workflow results.
OPERATIONAL_TABLES = (
    "attendance_records", "inventory_transactions", "production_orders",
    "quality_inspections", "purchase_orders", "sales_orders",
    "warehouse_pick_lists", "fleet_trips", "dispatch_deliveries",
    "dispatch_returnable_intakes", "maintenance_work_orders",
    "gas_container_assets", "gas_container_transaction_links",
)
PILOT_TABLES = ("pilot_participants", "pilot_feedback")
REQUIRED = (
    "PILOT_ADMIN_A_EMAIL", "PILOT_ADMIN_A_PASSWORD",
    "PILOT_ADMIN_B_EMAIL", "PILOT_ADMIN_B_PASSWORD",
)
MAX_REPORTS = 1000
MAX_REPORT_AGE = timedelta(days=14)


def normalize_environment(env):
    """Adapt dedicated pilot secrets to the existing pinned, redirect-safe Auth client."""
    for variable in REQUIRED:
        if not isinstance(env.get(variable), str) or not env[variable].strip():
            raise SmokeError(f"Missing owner-provisioned pilot credential: {variable}.")
    if env["PILOT_ADMIN_A_EMAIL"].strip().casefold() == env["PILOT_ADMIN_B_EMAIL"].strip().casefold():
        raise SmokeError("Pilot acceptance requires two distinct approved administrator accounts.")
    adapted = dict(env)
    adapted.update({
        "SMOKE_EMAIL": env["PILOT_ADMIN_A_EMAIL"],
        "SMOKE_PASSWORD": env["PILOT_ADMIN_A_PASSWORD"],
        "SMOKE_SECOND_EMAIL": env["PILOT_ADMIN_B_EMAIL"],
        "SMOKE_SECOND_PASSWORD": env["PILOT_ADMIN_B_PASSWORD"],
    })
    validate_environment(adapted)
    return adapted


def read_rows(request, account, table, *, foreign_org=None):
    """Only fixed scoped GET queries to known public tables; never fetch sensitive fields."""
    allowed = set(OPERATIONAL_TABLES) | set(PILOT_TABLES) | {"organization_members"}
    if table not in allowed:
        raise SmokeError("Unapproved resource in pilot acceptance query.")
    org_id = foreign_org if foreign_org is not None else account.organization_id
    _uuid(org_id, "pilot organization")
    params = {"organization_id": f"eq.{org_id}", "limit": "1"}
    if table == "organization_members":
        params.update({"select": "organization_id,user_id,role",
                       "user_id": f"eq.{account.user_id}", "is_active": "eq.true"})
    elif table == "pilot_participants":
        params["select"] = "organization_id,user_id,consented_at"
        if foreign_org is None:
            params["user_id"] = f"eq.{account.user_id}"
    elif table == "pilot_feedback":
        params.update({
            "select": "id,organization_id,user_id,scenario,result,created_at",
            "limit": str(MAX_REPORTS),
            "order": "created_at.desc,id.desc",
        })
        if foreign_org is None:
            params["user_id"] = f"eq.{account.user_id}"
        else:
            params["limit"] = "1"
    else:
        params["select"] = "id,organization_id"
    result = request("GET", f"/rest/v1/{table}?{urlencode(params)}", token=account.token)
    if not isinstance(result, list) or not all(isinstance(row, dict) for row in result):
        raise SmokeError(f"{table}: data API must return a JSON row array.")
    if len(result) > int(params["limit"]):
        raise SmokeError(f"{table}: API ignored the requested row limit.")
    return result


def parse_timestamp(value):
    if not isinstance(value, str):
        raise SmokeError("Missing timestamp in production pilot evidence.")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise SmokeError("Invalid production pilot evidence timestamp.") from None
    if parsed.tzinfo is None:
        raise SmokeError("Pilot evidence timestamp is missing a time zone.")
    return parsed.astimezone(timezone.utc)


def require_completed_reports(rows, account, now):
    if not isinstance(rows, list) or len(rows) >= MAX_REPORTS:
        raise SmokeError("Pilot feedback is missing, unbounded, or potentially truncated.")
    if not isinstance(now, datetime) or now.tzinfo is None:
        raise SmokeError("Pilot evidence requires a timezone-aware evaluation time.")
    latest = {}
    for row in rows:
        if not isinstance(row, dict):
            raise SmokeError("Malformed pilot feedback row.")
        if row.get("organization_id") != account.organization_id or row.get("user_id") != account.user_id:
            raise SmokeError("Pilot feedback is not restricted to its signed-in participant.")
        scenario = row.get("scenario")
        if scenario not in SCENARIOS or row.get("result") not in {"passed", "blocked", "failed"}:
            raise SmokeError("Unknown scenario or result in pilot feedback.")
        identifier = _uuid(row.get("id"), "pilot feedback ID")
        created_at = parse_timestamp(row.get("created_at"))
        if created_at > now + timedelta(minutes=5):
            raise SmokeError("Future-dated pilot report cannot authorize release.")
        marker = (created_at, identifier)
        if scenario not in latest or marker > latest[scenario][0]:
            latest[scenario] = (marker, row["result"])
    missing = SCENARIOS - latest.keys()
    if missing:
        raise SmokeError("Missing reported pilot scenarios: " + ", ".join(sorted(missing)))
    for scenario in sorted(SCENARIOS):
        (stamp, _), result = latest[scenario]
        if result != "passed":
            raise SmokeError(f"Latest pilot report is not passed for scenario: {scenario}.")
        if now - stamp > MAX_REPORT_AGE:
            raise SmokeError(f"Pilot report is older than 14 days for scenario: {scenario}.")
    return len(SCENARIOS)


def verify_pilot(request, env, *, now=None):
    configured = normalize_environment(env)
    current = datetime.now(timezone.utc) if now is None else now
    a = _sign_in(request, "Pilot A", configured["SMOKE_EMAIL"], configured["SMOKE_PASSWORD"])
    b = _sign_in(request, "Pilot B", configured["SMOKE_SECOND_EMAIL"], configured["SMOKE_SECOND_PASSWORD"])
    if a.user_id == b.user_id or a.organization_id == b.organization_id:
        raise SmokeError("Pilot administrators must belong to different organizations.")
    _verify_scoped_reads(request, a, b)
    _verify_scoped_reads(request, b, a)

    for account, other in ((a, b), (b, a)):
        role = read_rows(request, account, "organization_members")
        if (len(role) != 1 or role[0].get("organization_id") != account.organization_id
                or role[0].get("user_id") != account.user_id
                or role[0].get("role") != "org_admin"):
            raise SmokeError(f"{account.label}: pilot acceptance needs an org_admin with single active membership.")

        participants = read_rows(request, account, "pilot_participants")
        if (len(participants) != 1
                or participants[0].get("organization_id") != account.organization_id
                or participants[0].get("user_id") != account.user_id):
            raise SmokeError(f"{account.label}: explicit active pilot consent is missing.")
        consent = parse_timestamp(participants[0].get("consented_at"))
        if consent > current + timedelta(minutes=5):
            raise SmokeError(f"{account.label}: pilot consent timestamp is invalid.")

        feedback = read_rows(request, account, "pilot_feedback")
        require_completed_reports(feedback, account, current)

        for table in OPERATIONAL_TABLES:
            own = read_rows(request, account, table)
            if (len(own) != 1 or own[0].get("organization_id") != account.organization_id):
                raise SmokeError(f"{account.label}: no visible real operational record for {table}.")
            _uuid(own[0].get("id"), f"{table} ID")

        # Reciprocal negative probes are meaningful because the peer account
        # proved that its organization has a visible record in every table.
        for table in (*PILOT_TABLES, *OPERATIONAL_TABLES):
            if read_rows(request, account, table, foreign_org=other.organization_id):
                raise SmokeError(f"{account.label}: foreign organization data was visible in {table}.")
    return (len(SCENARIOS), len(OPERATIONAL_TABLES))


def main():
    try:
        scenarios, table_count = verify_pilot(live_transport(normalize_environment(dict(os.environ))),
                                             dict(os.environ))
    except SmokeError as exc:
        print(f"BLOCKED: real pilot acceptance: {exc}", file=sys.stderr)
        return 2
    print(f"PASS: both consenting pilot admin identities reported all {scenarios} scenarios "
          f"passed within 14 days; own records present in {table_count} operational tables; "
          "reciprocal foreign data was hidden.")
    print("NOTE: read-only API evidence is NOT physical-device QA, push-delivery proof, "
          "independent role-mutation verification, recovery testing or release-owner sign-off.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
