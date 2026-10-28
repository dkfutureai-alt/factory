#!/usr/bin/env python3
"""Read-only, two-account FactoryOS tenant isolation acceptance smoke.

Runs only by a protected, manually approved GitHub Actions workflow.
Uses two consenting real FactoryOS smoke identities; never creates users,
customers, organizations, factories, or test passes. Never prints credentials.
"""

import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

PROJECT_REF = "zevrmvhnibztbxizswgu"
PROJECT_URL = f"https://{PROJECT_REF}.supabase.co"
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)

REQUIRED = (
    "FACTORYOS_SUPABASE_URL",
    "FACTORYOS_SUPABASE_PROJECT_REF",
    "FACTORYOS_SUPABASE_PUBLISHABLE_KEY",
    "FACTORYOS_TENANT_A_SMOKE_EMAIL",
    "FACTORYOS_TENANT_A_SMOKE_PASSWORD",
    "FACTORYOS_TENANT_B_SMOKE_EMAIL",
    "FACTORYOS_TENANT_B_SMOKE_PASSWORD",
)


class SmokeBlocked(ValueError):
    """Fail closed with safe, non-secret diagnostic text."""


def require_configuration(settings):
    for name in REQUIRED:
        if not str(settings.get(name, "")).strip():
            raise SmokeBlocked(f"Missing required FactoryOS smoke configuration: {name}")
    if (settings["FACTORYOS_SUPABASE_PROJECT_REF"] != PROJECT_REF or
            settings["FACTORYOS_SUPABASE_URL"] != PROJECT_URL):
        raise SmokeBlocked("Refusing smoke against a non-FactoryOS production project.")
    key = settings["FACTORYOS_SUPABASE_PUBLISHABLE_KEY"]
    if not key.startswith("sb_publishable_") or len(key) <= 23 or any(c.isspace() for c in key):
        raise SmokeBlocked("Use a valid FactoryOS publishable API key, never a privileged key.")
    if settings["FACTORYOS_TENANT_A_SMOKE_EMAIL"].strip().lower() == settings["FACTORYOS_TENANT_B_SMOKE_EMAIL"].strip().lower():
        raise SmokeBlocked("Two distinct consenting pilot identities are required.")
    return key


def require_uuid(value, label):
    if not isinstance(value, str) or not UUID_RE.fullmatch(value):
        raise SmokeBlocked(f"Invalid {label} in authenticated FactoryOS response.")
    return value


def extract_org_membership(rows, user_id):
    """Exactly one active organization, never silently choose the first."""
    require_uuid(user_id, "user ID")
    if not isinstance(rows, list) or len(rows) != 1:
        raise SmokeBlocked("Each smoke user must have exactly one active organization membership.")
    row = rows[0]
    if not isinstance(row, dict) or row.get("user_id") != user_id:
        raise SmokeBlocked("Organization membership does not match signed-in user.")
    return require_uuid(row.get("organization_id"), "organization ID")


def extract_own_factory(rows, org_id):
    """Require at least one real, active, authorized factory in the expected tenant."""
    require_uuid(org_id, "organization ID")
    if not isinstance(rows, list) or not rows:
        raise SmokeBlocked("No authorized active factory was returned for the pilot user.")
    for row in rows:
        if (not isinstance(row, dict) or row.get("organization_id") != org_id):
            raise SmokeBlocked("Factory read includes an unexpected organization.")
        require_uuid(row.get("id"), "factory ID")
    return rows[0]["id"]


def require_hidden(rows, resource):
    if not isinstance(rows, list) or rows:
        raise SmokeBlocked(f"Cross-tenant read was not denied for {resource}.")


def request_json(path, key, token=None, payload=None, params=None):
    """Only connects to the pinned FactoryOS origin; hides sensitive HTTP bodies."""
    url = PROJECT_URL + path
    if params:
        url += "?" + urlencode(params)
    headers = {"apikey": key, "Accept": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    body = None
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = Request(url, headers=headers, data=body, method="POST" if body else "GET")
    try:
        with urlopen(req, timeout=20) as resp:
            data = resp.read(1024 * 1024 + 1)
    except (HTTPError, URLError, TimeoutError) as exc:
        raise SmokeBlocked("FactoryOS Auth/Data API request failed; inspect protected runner logs.") from None
    if len(data) > 1024 * 1024:
        raise SmokeBlocked("Unexpectedly large API response.")
    try:
        return json.loads(data)
    except (ValueError, UnicodeDecodeError):
        raise SmokeBlocked("Non-JSON FactoryOS API response.") from None


def get_rows(table, key, token, **filters):
    allowed = {"organizations", "organization_members", "factories"}
    if table not in allowed:
        raise SmokeBlocked("Disallowed tenant-smoke resource.")
    query = {"limit": "2", **filters}
    data = request_json("/rest/v1/" + table, key, token=token, params=query)
    if not isinstance(data, list):
        raise SmokeBlocked("Data API returned a non-list response.")
    return data


def identity(email, password, key):
    auth = request_json(
        "/auth/v1/token", key,
        payload={"email": email, "password": password},
        params={"grant_type": "password"},
    )
    if not isinstance(auth, dict) or not isinstance(auth.get("access_token"), str):
        raise SmokeBlocked("A test identity could not obtain its own JWT.")
    token = auth["access_token"]
    if not token or any(c.isspace() for c in token):
        raise SmokeBlocked("Malformed smoke JWT.")
    user = request_json("/auth/v1/user", key, token=token)
    if not isinstance(user, dict):
        raise SmokeBlocked("The Auth user endpoint returned an invalid identity.")
    user_id = require_uuid(user.get("id"), "signed-in user ID")
    memberships = get_rows(
        "organization_members", key, token,
        select="organization_id,user_id", user_id="eq." + user_id,
        is_active="eq.true",
    )
    org_id = extract_org_membership(memberships, user_id)
    factories = get_rows(
        "factories", key, token,
        select="id,organization_id", organization_id="eq." + org_id,
        is_active="eq.true",
    )
    factory_id = extract_own_factory(factories, org_id)
    return {"token": token, "user_id": user_id, "org_id": org_id, "factory_id": factory_id}


def verify_foreign_denial(viewer, other, key):
    token = viewer["token"]
    foreign_org = other["org_id"]
    foreign_factory = other["factory_id"]
    for table, filters in (
        ("organizations", {"select": "id", "id": "eq." + foreign_org}),
        ("organization_members", {"select": "organization_id,user_id", "organization_id": "eq." + foreign_org}),
        ("factories", {"select": "id,organization_id", "id": "eq." + foreign_factory}),
    ):
        require_hidden(get_rows(table, key, token, **filters), table)


def run(settings):
    key = require_configuration(settings)
    tenant_a = identity(settings["FACTORYOS_TENANT_A_SMOKE_EMAIL"], settings["FACTORYOS_TENANT_A_SMOKE_PASSWORD"], key)
    tenant_b = identity(settings["FACTORYOS_TENANT_B_SMOKE_EMAIL"], settings["FACTORYOS_TENANT_B_SMOKE_PASSWORD"], key)
    if tenant_a["user_id"] == tenant_b["user_id"] or tenant_a["org_id"] == tenant_b["org_id"]:
        raise SmokeBlocked("Pilot accounts must belong to different users and organizations.")
    verify_foreign_denial(tenant_a, tenant_b, key)
    verify_foreign_denial(tenant_b, tenant_a, key)
    print("PASS: two real JWT identities, own factories visible, reciprocal cross-tenant reads denied.")
    print("NOTE: read-only smoke is not a substitute for customer workflow/device acceptance.")


def main():
    try:
        run(dict(os.environ))
    except SmokeBlocked as error:
        print(f"BLOCKED: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
