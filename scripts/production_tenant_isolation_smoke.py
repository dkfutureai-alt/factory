#!/usr/bin/env python3
"""Read-only, two-organization FactoryOS production authorization smoke.

Uses dedicated, owner-provisioned test accounts. Only password authentication is
POSTed; every application-table request is a GET. Never prints credentials,
access tokens, email addresses, tenant IDs, response bodies or personal data.
"""

import json
import os
import sys
import uuid
from dataclasses import dataclass
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener

PROJECT_REF = "zevrmvhnibztbxizswgu"
VALID_ROLES = frozenset({"org_admin", "factory_manager", "supervisor", "employee", "driver", "viewer"})


class SmokeError(Exception):
    """Safe diagnostic; never include response bodies, user fields, or secrets."""


@dataclass(frozen=True)
class Account:
    label: str
    token: str
    user_id: str
    organization_id: str


def validate_environment(env: dict[str, str]) -> None:
    ref = env.get("SUPABASE_PROJECT_REF", "")
    url = env.get("SUPABASE_URL", "")
    if ref != PROJECT_REF or url != f"https://{PROJECT_REF}.supabase.co":
        raise SmokeError("Production API origin is not the dedicated FactoryOS project.")
    for variable in (
        "SUPABASE_PUBLISHABLE_KEY", "SMOKE_EMAIL", "SMOKE_PASSWORD",
        "SMOKE_SECOND_EMAIL", "SMOKE_SECOND_PASSWORD",
    ):
        if not env.get(variable, "").strip():
            raise SmokeError(f"Missing required two-tenant smoke configuration: {variable}.")
    if env["SMOKE_EMAIL"].strip().casefold() == env["SMOKE_SECOND_EMAIL"].strip().casefold():
        raise SmokeError("Two-tenant smoke requires different test account emails.")


class NoRedirect(HTTPRedirectHandler):
    """Never forward a publishable key or access token to another origin."""
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def live_transport(env: dict[str, str]) -> Callable[..., Any]:
    """Connect only to the exact validated FactoryOS API host."""
    validate_environment(env)
    origin = env["SUPABASE_URL"]
    key = env["SUPABASE_PUBLISHABLE_KEY"]
    opener = build_opener(NoRedirect)

    def request(method: str, path: str, *, token: str = "", payload: dict | None = None) -> Any:
        if method not in {"GET", "POST"} or not path.startswith(("/rest/v1/", "/auth/v1/")):
            raise SmokeError("Only scoped read requests and authentication are permitted.")
        if method == "POST" and path != "/auth/v1/token?grant_type=password":
            raise SmokeError("Only password sign-in is allowed to use POST.")
        if method == "GET" and payload is not None:
            raise SmokeError("GET must not carry a request body.")
        headers = {"apikey": key, "Accept": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        if payload is not None:
            headers["Content-Type"] = "application/json"
        body = json.dumps(payload).encode("utf-8") if payload is not None else None
        req = Request(origin + path, data=body, headers=headers, method=method)
        try:
            with opener.open(req, timeout=20) as response:
                if not 200 <= response.status < 300:
                    raise SmokeError("FactoryOS API returned an unexpected response status.")
                return json.load(response)
        except (HTTPError, URLError, TimeoutError, ValueError, OSError):
            # Suppress details: exception text can contain URLs, response bodies or data.
            raise SmokeError("FactoryOS API authorization request failed.") from None

    return request


def _uuid(value: Any, context: str) -> str:
    if not isinstance(value, str):
        raise SmokeError(f"{context}: expected a UUID.")
    try:
        return str(uuid.UUID(value))
    except ValueError:
        raise SmokeError(f"{context}: invalid UUID.") from None


def _get_rows(request: Callable[..., Any], account: Account, table: str,
              **filters: str) -> list[dict]:
    allowed = {"organizations", "factories", "organization_members", "factory_members"}
    if table not in allowed:
        raise SmokeError("Unexpected table requested by authorization smoke.")
    params = {"select": "id,organization_id" if table != "organizations" else "id",
              **filters, "limit": "2"}
    result = request("GET", f"/rest/v1/{table}?{urlencode(params)}", token=account.token)
    if not isinstance(result, list) or not all(isinstance(row, dict) for row in result):
        raise SmokeError(f"{table}: expected a JSON row array.")
    return result


def _sign_in(request: Callable[..., Any], label: str, email: str, password: str) -> Account:
    data = request("POST", "/auth/v1/token?grant_type=password",
                   payload={"email": email, "password": password})
    token = data.get("access_token") if isinstance(data, dict) else None
    if not isinstance(token, str) or not token:
        raise SmokeError(f"{label}: authentication did not return an access token.")
    identity = request("GET", "/auth/v1/user", token=token)
    uid = _uuid(identity.get("id") if isinstance(identity, dict) else None,
                f"{label} identity")
    rows = request("GET", "/rest/v1/organization_members?" + urlencode({
        "select": "organization_id,role,user_id", "user_id": f"eq.{uid}",
        "is_active": "eq.true", "limit": "2"}), token=token)
    if not isinstance(rows, list) or len(rows) != 1:
        raise SmokeError(f"{label}: exactly one active organization membership is required.")
    row = rows[0]
    if not isinstance(row, dict) or row.get("user_id") != uid or row.get("role") not in VALID_ROLES:
        raise SmokeError(f"{label}: membership is not a scoped non-platform account.")
    org = _uuid(row.get("organization_id"), f"{label} membership")
    return Account(label=label, token=token, user_id=uid, organization_id=org)


def _verify_scoped_reads(request: Callable[..., Any], viewer: Account, other: Account) -> None:
    own = viewer.organization_id
    foreign = other.organization_id
    # Positive controls are essential: a universally empty API is not an RLS pass.
    own_orgs = _get_rows(request, viewer, "organizations", id=f"eq.{own}")
    if len(own_orgs) != 1 or _uuid(own_orgs[0].get("id"), "Own organization") != own:
        raise SmokeError(f"{viewer.label}: cannot read own organization.")
    if _get_rows(request, viewer, "organizations", id=f"eq.{foreign}"):
        raise SmokeError(f"{viewer.label}: foreign organization visibility detected.")

    own_members = _get_rows(request, viewer, "organization_members", organization_id=f"eq.{own}")
    if not own_members or any(row.get("organization_id") != own for row in own_members):
        raise SmokeError(f"{viewer.label}: cannot read own organization membership.")
    if _get_rows(request, viewer, "organization_members", organization_id=f"eq.{foreign}"):
        raise SmokeError(f"{viewer.label}: foreign membership visibility detected.")

    own_factories = _get_rows(request, viewer, "factories", organization_id=f"eq.{own}", is_active="eq.true")
    if not own_factories or any(row.get("organization_id") != own for row in own_factories):
        raise SmokeError(f"{viewer.label}: visible active factory is required for a meaningful test.")
    if _get_rows(request, viewer, "factories", organization_id=f"eq.{foreign}"):
        raise SmokeError(f"{viewer.label}: foreign factory visibility detected.")
    if _get_rows(request, viewer, "factory_members", organization_id=f"eq.{foreign}"):
        raise SmokeError(f"{viewer.label}: foreign factory membership visibility detected.")


def verify_isolation(request: Callable[..., Any], env: dict[str, str]) -> None:
    validate_environment(env)
    a = _sign_in(request, "Account A", env["SMOKE_EMAIL"], env["SMOKE_PASSWORD"])
    b = _sign_in(request, "Account B", env["SMOKE_SECOND_EMAIL"], env["SMOKE_SECOND_PASSWORD"])
    if a.user_id == b.user_id or a.organization_id == b.organization_id:
        raise SmokeError("Two-tenant smoke requires separate identities and organizations.")
    _verify_scoped_reads(request, a, b)
    _verify_scoped_reads(request, b, a)


def main() -> int:
    env = dict(os.environ)
    try:
        validate_environment(env)
        verify_isolation(live_transport(env), env)
    except SmokeError as exc:
        print(f"BLOCKED: two-organization RLS smoke: {exc}", file=sys.stderr)
        return 2
    print("PASS: two distinct FactoryOS test organizations can see their own populated core rows, not each other's; read-only.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
