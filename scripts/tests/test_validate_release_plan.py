"""Offline regression coverage for an evidence-bound FactoryOS SQL release plan."""

import os
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_release_plan import (
    PLAN_WORKFLOW, PROJECT_REPO, NoRedirect, PlanError, main, verify_plan,
)

SHA = "a" * 40
NOW = datetime(2026, 10, 28, 13, 0, tzinfo=timezone.utc)


def plan():
    return {
        "id": 12345678,
        "repository": {"full_name": PROJECT_REPO},
        "path": PLAN_WORKFLOW + "@main",
        "event": "workflow_dispatch",
        "head_branch": "main",
        "head_sha": SHA,
        "status": "completed",
        "conclusion": "success",
        "updated_at": "2026-10-28T12:00:00Z",
    }


def successful_job():
    return {"name": "FactoryOS read-only migration plan", "run_id": 12345678,
            "status": "completed", "conclusion": "success"}


DEFAULT_JOBS = object()


def verify(metadata, jobs=DEFAULT_JOBS, **kwargs):
    params = dict(run_id="12345678", repository=PROJECT_REPO, expected_sha=SHA, now=NOW)
    params.update(kwargs)
    return verify_plan(metadata, [successful_job()] if jobs is DEFAULT_JOBS else jobs, **params)


class PlanAuthorizationTests(unittest.TestCase):
    def test_exact_recent_successful_plan_is_accepted(self):
        self.assertIn("PASS:", verify(plan()))

    def test_plan_path_may_have_main_suffix_but_no_other_workflow(self):
        self.assertIn("PASS:", verify({**plan(), "path": PLAN_WORKFLOW}))
        for path in (".github/workflows/production-smoke.yml@main",
                     PLAN_WORKFLOW + "-evil@main", "other/" + PLAN_WORKFLOW, ""):
            with self.subTest(path=path), self.assertRaises(PlanError):
                verify({**plan(), "path": path})

    def test_workflow_success_is_not_enough_if_actual_plan_job_skipped(self):
        for invalid in (
            [], None,
            [{"name": "other", "run_id": 12345678, "status": "completed", "conclusion": "success"}],
            [{**successful_job(), "conclusion": "skipped"}],
            [{**successful_job(), "conclusion": "failure"}],
            [{**successful_job(), "status": "in_progress"}],
            [{**successful_job(), "run_id": 12345679}],
            [successful_job(), successful_job()],
        ):
            with self.subTest(invalid=invalid), self.assertRaises(PlanError):
                verify(plan(), jobs=invalid)

    def test_run_id_must_be_exact_nonzero_digits_and_match_response(self):
        for value in ("", "0", "-1", "1/foo", "notanumber", "12345678901234567"):
            with self.subTest(value=value), self.assertRaises(PlanError):
                verify(plan(), run_id=value)
        with self.assertRaises(PlanError):
            verify({**plan(), "id": 12345679})

    def test_source_repository_and_exact_sha(self):
        for change in (
            {"repository": {"full_name": "other/factory"}},
            {"repository": None}, {"head_sha": "b" * 40}, {"head_sha": None},
        ):
            with self.subTest(change=change), self.assertRaises(PlanError):
                verify({**plan(), **change})
        with self.assertRaises(PlanError):
            verify(plan(), expected_sha="b" * 40)
        with self.assertRaises(PlanError):
            verify(plan(), repository="other/factory")

    def test_unapproved_branch_or_event_blocks(self):
        for change in ({"head_branch": "dev"}, {"event": "push"},
                       {"event": "pull_request"}, {"status": "in_progress"},
                       {"conclusion": "failure"}, {"conclusion": "skipped"}):
            with self.subTest(change=change), self.assertRaises(PlanError):
                verify({**plan(), **change})

    def test_expired_future_and_malformed_metadata_blocks(self):
        for timestamp in ("2026-10-27T00:00:00Z", "2026-10-29T12:00:00Z",
                          "2026-10-28T14:00:00", "", "malformed"):
            with self.subTest(timestamp=timestamp), self.assertRaises(PlanError):
                verify({**plan(), "updated_at": timestamp})
        with self.assertRaises(PlanError):
            verify(None)

    def test_runner_cannot_follow_auth_header_redirects(self):
        self.assertIsNone(NoRedirect().redirect_request(None, None, 301, "redirect", {}, "https://evil.invalid"))

    def test_missing_main_checkout_never_calls_github(self):
        env = {"GITHUB_REF": "refs/heads/feature", "APPROVED_PLAN_RUN_ID": "12345678"}
        with patch.dict(os.environ, env, clear=True), patch(
            "validate_release_plan.fetch_github_api"
        ) as remote, patch("builtins.print"):
            self.assertEqual(main(), 2)
            remote.assert_not_called()

    def test_deploy_workflow_enforces_fresh_review_before_remote_writes(self):
        root = Path(__file__).resolve().parents[2]
        file = (root / ".github/workflows/supabase-production-release.yml").read_text()
        self.assertIn("approved_plan_run_id:", file)
        self.assertIn("group: factoryos-production-database-migrations", file)
        self.assertIn("cancel-in-progress: false", file)
        self.assertIn("  actions: read", file)
        self.assertIn("python3 scripts/validate_release_plan.py", file)
        self.assertIn("python3 scripts/check_migration_versions.py", file)
        self.assertLess(file.index("python3 scripts/validate_release_plan.py"),
                        file.index("supabase link --project-ref"))
        self.assertLess(file.index("supabase db push --dry-run"),
                        file.index("supabase db push\n"))
        self.assertLess(file.index("--stage postdeploy"),
                        file.index("supabase functions deploy"))
        self.assertNotIn("supabase db reset", file)

    def test_plan_workflow_is_protected_and_read_only(self):
        root = Path(__file__).resolve().parents[2]
        file = (root / ".github/workflows/supabase-production-plan.yml").read_text()
        self.assertIn("inputs.confirm == 'PLAN' && github.ref == 'refs/heads/main'", file)
        self.assertIn("name: FactoryOS read-only migration plan", file)
        self.assertIn("environment: factoryos-production", file)
        self.assertIn("group: factoryos-production-database-migrations", file)
        self.assertIn("cancel-in-progress: false", file)
        self.assertIn("zevrmvhnibztbxizswgu", file)
        self.assertIn("python3 scripts/check_migration_versions.py", file)
        self.assertIn("--stage preflight", file)
        self.assertIn("supabase db push --dry-run", file)
        self.assertNotIn("supabase db push\n", file)
        self.assertNotIn("supabase db reset", file)
        self.assertNotIn("supabase secrets set", file)
        self.assertNotIn("supabase functions deploy", file)


if __name__ == "__main__":
    unittest.main()
