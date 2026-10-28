#!/usr/bin/env python3
"""Fail-closed, read-only GitHub Actions gate for FactoryOS production database releases.

The exact dispatch commit must be the current main HEAD and have a completed,
successful Supabase Foundation Checks *push* run for that SHA. No GitHub writes,
Supabase calls, credentials, or customer data are exposed by this script.
"""

import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

REPOSITORY = "dkfutureai-alt/factory"
WORKFLOW = "supabase-foundation.yml"
SHA_PATTERN = re.compile(r"[0-9a-f]{40}")


class ReleaseGateError(ValueError):
    """Non-sensitive error for a rejected or unverifiable release."""


def verify_inputs(env: dict[str, str]) -> str:
    if env.get("GITHUB_REPOSITORY") != REPOSITORY:
        raise ReleaseGateError("Release repository does not match FactoryOS.")
    sha = env.get("GITHUB_SHA", "")
    if not SHA_PATTERN.fullmatch(sha):
        raise ReleaseGateError("Release commit SHA is missing or malformed.")
    if env.get("GITHUB_REF") != "refs/heads/main":
        raise ReleaseGateError("Production database release must target main.")
    if not env.get("GH_TOKEN", ""):
        raise ReleaseGateError("Read-only Actions API token is unavailable.")
    return sha


def verify_main_ref(payload: object, sha: str) -> None:
    if not isinstance(payload, dict) or payload.get("ref") != "refs/heads/main":
        raise ReleaseGateError("Cannot verify the current main branch.")
    obj = payload.get("object")
    if not isinstance(obj, dict) or obj.get("sha") != sha:
        raise ReleaseGateError("Release SHA is no longer the current main HEAD.")


def verify_successful_exact_head_run(payload: object, sha: str) -> int:
    if not isinstance(payload, dict) or not isinstance(payload.get("workflow_runs"), list):
        raise ReleaseGateError("Workflow run history is unavailable.")
    candidates = []
    for run in payload["workflow_runs"]:
        if not isinstance(run, dict):
            continue
        if (
            run.get("head_sha") == sha
            and run.get("head_branch") == "main"
            and run.get("event") == "push"
            and run.get("path") == ".github/workflows/supabase-foundation.yml"
        ):
            try:
                run_id = int(run["id"])
                attempt = int(run.get("run_attempt", 1))
            except (KeyError, TypeError, ValueError):
                raise ReleaseGateError("Database CI run identity is malformed.") from None
            if run_id <= 0 or attempt <= 0:
                raise ReleaseGateError("Database CI run identity is invalid.")
            candidates.append((run_id, attempt, run))

    if not candidates:
        raise ReleaseGateError("No exact-main-SHA database integration run exists.")
    latest_id, _, latest = max(candidates, key=lambda item: (item[0], item[1]))
    if latest.get("status") != "completed" or latest.get("conclusion") != "success":
        raise ReleaseGateError("Latest exact-main-SHA database integration run has not passed.")
    return latest_id


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def github_json(path: str, token: str) -> object:
    # Caller-constructed API paths only; no untrusted URL redirects.
    request = Request(
        f"https://api.github.com/repos/{REPOSITORY}/{path}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with build_opener(NoRedirects).open(request, timeout=20) as response:
            if response.status != 200:
                raise ReleaseGateError("GitHub release evidence could not be read.")
            return json.load(response)
    except (HTTPError, URLError, TimeoutError, ValueError, OSError):
        # Never log an exception that could contain response bodies or tokens.
        raise ReleaseGateError("GitHub release evidence request failed.") from None


def main() -> int:
    env = dict(os.environ)
    try:
        sha = verify_inputs(env)
        verify_main_ref(github_json("git/ref/heads/main", env["GH_TOKEN"]), sha)
        run_id = verify_successful_exact_head_run(
            github_json(
                f"actions/workflows/{WORKFLOW}/runs?head_sha={sha}&branch=main&per_page=100",
                env["GH_TOKEN"],
            ),
            sha,
        )
    except ReleaseGateError as exc:
        print(f"BLOCKED: FactoryOS production database CI gate: {exc}", file=sys.stderr)
        return 2
    print(f"PASS: FactoryOS exact-head database integration verified (GitHub Actions run {run_id}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
