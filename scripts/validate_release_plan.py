#!/usr/bin/env python3
"""Fail closed unless a fresh, successful FactoryOS-only migration plan is proven.

Production release-only preflight. GitHub workflow metadata is queried read-only.
This does not deploy anything, and never displays a token or API response body.
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

PLAN_WORKFLOW = ".github/workflows/supabase-production-plan.yml"
PROJECT_REPO = "dkfutureai-alt/factory"
MAX_PLAN_AGE = timedelta(hours=24)


class PlanError(ValueError):
    """Safe, non-secret release diagnostic."""


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _timestamp(value):
    if not isinstance(value, str) or not value.endswith("Z"):
        raise PlanError("Planning run has an invalid completion timestamp.")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise PlanError("Planning run has an invalid completion timestamp.") from None
    return parsed


def verify_plan(run, *, run_id, repository, expected_sha, now=None):
    """Ensure the approved plan was successful on this exact current main commit."""
    if not isinstance(run_id, str) or not re.fullmatch(r"[1-9][0-9]{0,14}", run_id):
        raise PlanError("An actual numeric, nonzero GitHub plan run ID is required.")
    if repository != PROJECT_REPO or not re.fullmatch(r"[0-9a-f]{40}", expected_sha):
        raise PlanError("Wrong repository or invalid release commit SHA.")
    if not isinstance(run, dict) or run.get("id") != int(run_id):
        raise PlanError("GitHub returned an invalid planning run.")
    source = run.get("repository")
    if not isinstance(source, dict) or source.get("full_name") != repository:
        raise PlanError("Planning run originated in another repository.")
    workflow = run.get("path")
    if not isinstance(workflow, str) or workflow.split("@", 1)[0] != PLAN_WORKFLOW:
        raise PlanError("Referenced run is not the FactoryOS production migration plan.")
    if run.get("event") != "workflow_dispatch" or run.get("head_branch") != "main":
        raise PlanError("Planning run must be a manually approved main-branch dispatch.")
    if run.get("head_sha") != expected_sha:
        raise PlanError("Planning run commit differs from the exact release commit.")
    if run.get("status") != "completed" or run.get("conclusion") != "success":
        raise PlanError("Planning run has not passed all preflight steps.")
    checked_at = _timestamp(run.get("updated_at"))
    now = datetime.now(timezone.utc) if now is None else now
    if now.tzinfo is None:
        raise PlanError("Expected an aware UTC timestamp.")
    elapsed = now - checked_at
    if elapsed < timedelta(minutes=-5) or elapsed > MAX_PLAN_AGE:
        raise PlanError("Planning run has expired; rerun and review a fresh plan.")
    return "PASS: successful recent approved FactoryOS migration plan matches release SHA."


def fetch_github_run(run_id, token):
    """Read only an exact API endpoint; forbid cross-origin redirects."""
    if not isinstance(run_id, str) or not re.fullmatch(r"[1-9][0-9]{0,14}", run_id):
        raise PlanError("Invalid planning run identifier.")
    if not token:
        raise PlanError("Missing GitHub workflow identity.")
    url = f"https://api.github.com/repos/{PROJECT_REPO}/actions/runs/{run_id}"
    request = Request(
        url,
        method="GET",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with build_opener(NoRedirect).open(request, timeout=20) as response:
            content = response.read(262145)
            if len(content) > 262144:
                raise PlanError("Planning run API payload was unexpectedly large.")
            return json.loads(content)
    except (HTTPError, URLError, TimeoutError, OSError, ValueError):
        raise PlanError("Unable to verify reviewed planning run via GitHub API.") from None


def main():
    env = os.environ
    run_id = env.get("APPROVED_PLAN_RUN_ID", "")
    try:
        if env.get("GITHUB_REF") != "refs/heads/main":
            raise PlanError("Production releases require the main branch.")
        result = fetch_github_run(run_id, env.get("GITHUB_TOKEN", ""))
        print(verify_plan(
            result,
            run_id=run_id,
            repository=env.get("GITHUB_REPOSITORY", ""),
            expected_sha=env.get("GITHUB_SHA", ""),
        ))
    except PlanError as error:
        print(f"BLOCKED: migration release authorization: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
