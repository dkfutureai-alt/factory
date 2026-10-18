#!/usr/bin/env python3
"""Offline, fail-closed guard for the scheduled FactoryOS push worker.

Exit codes: 0 = safe to dispatch, 2 = incomplete/unsafe configuration,
3 = all dispatch secrets absent (unconfigured environment; safe skip).
This script must run before any outbound request carrying the dispatch secret.
"""

import os
import re
from collections.abc import Mapping

PROJECT_REF_RE = re.compile(r"[a-z0-9]{20}")


def validate_dispatch_environment(env: Mapping[str, str]) -> tuple[str, str]:
    """Return (state, non-secret diagnostic) without network I/O."""
    project_ref = env.get("FACTORYOS_SUPABASE_PROJECT_REF", "").strip()
    project_url = env.get("FACTORYOS_SUPABASE_URL", "").strip()
    dispatch_secret = env.get("NOTIFICATION_DISPATCH_SECRET", "")

    if not any((project_ref, project_url, dispatch_secret)):
        return "skip", "FactoryOS push dispatch is not configured; skipping."
    if not project_ref or not project_url or not dispatch_secret.strip():
        return "error", "FactoryOS push dispatch configuration is incomplete."
    if not PROJECT_REF_RE.fullmatch(project_ref):
        return "error", "FactoryOS project reference must be 20 lowercase letters/digits."
    if project_url != f"https://{project_ref}.supabase.co":
        return "error", "FactoryOS push URL must exactly match the configured project reference."

    return "ready", "FactoryOS push target validated."


def main() -> int:
    state, message = validate_dispatch_environment(os.environ)
    print(message)
    return {"ready": 0, "error": 2, "skip": 3}[state]


if __name__ == "__main__":
    raise SystemExit(main())
