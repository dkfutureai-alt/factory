#!/usr/bin/env python3
"""Fail-closed release candidate configuration checks; never accesses the network."""

import argparse
import os
import re
import sys
from urllib.parse import urlsplit

BASE_RE = re.compile(r"/(?:[a-zA-Z0-9_-]+/)*")


def validate_configuration(env: dict[str, str], target: str) -> list[str]:
    """Return non-secret error descriptions."""
    errors: list[str] = []
    if target not in {"web", "android-qa"}:
        return ["Target must be web or android-qa."]
    if env.get("FACTORYOS_RELEASE_ENV", "").strip() not in {"staging", "production"}:
        errors.append("Release environment must be staging or production.")

    url = env.get("FACTORYOS_SUPABASE_URL", "").strip()
    try:
        parsed = urlsplit(url)
        host = (parsed.hostname or "").lower()
        if (
            parsed.scheme != "https"
            or not host
            or parsed.port is not None
            or host in {"localhost", "127.0.0.1", "0.0.0.0", "::1", "example.supabase.co"}
            or host.endswith((".localhost", ".example", ".example.com"))
            or "placeholder" in host
            or parsed.username is not None
            or parsed.password is not None
            or parsed.query
            or parsed.fragment
            or parsed.path not in {"", "/"}
        ):
            errors.append("FACTORYOS_SUPABASE_URL must be a real HTTPS API origin, without credentials or a path.")
    except ValueError:
        errors.append("FACTORYOS_SUPABASE_URL is not a valid HTTPS API origin.")

    key = env.get("FACTORYOS_SUPABASE_PUBLISHABLE_KEY", "").strip()
    if (
        not key.startswith("sb_publishable_")
        or len(key) <= len("sb_publishable_") + 8
        or any(c.isspace() for c in key)
    ):
        errors.append("Use the real sb_publishable_ client key, never a service-role/secret key.")

    if target == "web":
        path = env.get("FACTORYOS_ADMIN_BASE_HREF", "").strip()
        if not BASE_RE.fullmatch(path):
            errors.append("Web base href must be '/' or an absolute path ending with '/'.")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, choices=["web", "android-qa"])
    target = parser.parse_args().target
    errors = validate_configuration(dict(os.environ), target)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print("BLOCKED: no release candidate produced.", file=sys.stderr)
        return 2
    print(f"PASS: {target} input checks (remote project ownership remains unverified).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
