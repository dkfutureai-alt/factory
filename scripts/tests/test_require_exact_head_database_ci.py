"""Synthetic, network-free tests for the exact-head production DB release gate."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from require_exact_head_database_ci import (
    ReleaseGateError, verify_inputs, verify_main_ref, verify_successful_exact_head_run,
)

SHA = "a" * 40
OTHER_SHA = "b" * 40


def successful_run(run_id=100, sha=SHA, **changes):
    return {
        "id": run_id,
        "run_attempt": 1,
        "head_sha": sha,
        "head_branch": "main",
        "event": "push",
        "path": ".github/workflows/supabase-foundation.yml",
        "status": "completed",
        "conclusion": "success",
        **changes,
    }


class ExactHeadDatabaseGateTests(unittest.TestCase):
    def setUp(self):
        self.env = {
            "GITHUB_REPOSITORY": "dkfutureai-alt/factory",
            "GITHUB_SHA": SHA,
            "GITHUB_REF": "refs/heads/main",
            "GH_TOKEN": "synthetic-token-never-used",
        }

    def test_correct_release_identity(self):
        self.assertEqual(verify_inputs(self.env), SHA)
        verify_main_ref({"ref": "refs/heads/main", "object": {"sha": SHA}}, SHA)

    def test_other_repo_is_rejected(self):
        with self.assertRaisesRegex(ReleaseGateError, "repository"):
            verify_inputs({**self.env, "GITHUB_REPOSITORY": "another/repo"})

    def test_missing_token_or_branch_or_sha_is_rejected(self):
        cases = (
            {"GH_TOKEN": ""},
            {"GITHUB_REF": "refs/heads/feature"},
            {"GITHUB_SHA": OTHER_SHA[:20]},
        )
        for updates in cases:
            with self.subTest(updates=updates), self.assertRaises(ReleaseGateError):
                verify_inputs({**self.env, **updates})

    def test_old_main_sha_rejected_even_if_ci_was_green(self):
        with self.assertRaisesRegex(ReleaseGateError, "no longer"):
            verify_main_ref({"ref": "refs/heads/main", "object": {"sha": OTHER_SHA}}, SHA)

    def test_missing_main_ref_rejected(self):
        with self.assertRaises(ReleaseGateError):
            verify_main_ref({}, SHA)

    def test_exact_successful_push_to_main_allows_release(self):
        self.assertEqual(verify_successful_exact_head_run(
            {"workflow_runs": [successful_run()]}, SHA), 100)

    def test_missing_history_and_no_runs_fail(self):
        for payload in ({}, {"workflow_runs": []}, None):
            with self.subTest(payload=payload), self.assertRaises(ReleaseGateError):
                verify_successful_exact_head_run(payload, SHA)

    def test_other_commit_is_never_reused(self):
        with self.assertRaises(ReleaseGateError):
            verify_successful_exact_head_run({"workflow_runs": [successful_run(sha=OTHER_SHA)]}, SHA)

    def test_pr_success_is_not_equivalent_to_main_push(self):
        with self.assertRaises(ReleaseGateError):
            verify_successful_exact_head_run(
                {"workflow_runs": [successful_run(event="pull_request")]}, SHA)

    def test_other_branch_does_not_allow_release(self):
        with self.assertRaises(ReleaseGateError):
            verify_successful_exact_head_run(
                {"workflow_runs": [successful_run(head_branch="feature")]}, SHA)

    def test_other_workflow_does_not_allow_release(self):
        with self.assertRaises(ReleaseGateError):
            verify_successful_exact_head_run(
                {"workflow_runs": [successful_run(path=".github/workflows/release-workflow-lint.yml")]}, SHA)

    def test_in_progress_or_failed_run_is_rejected(self):
        for changes in ({"status": "in_progress", "conclusion": None},
                        {"status": "completed", "conclusion": "failure"},
                        {"status": "completed", "conclusion": "cancelled"}):
            with self.subTest(changes=changes), self.assertRaises(ReleaseGateError):
                verify_successful_exact_head_run(
                    {"workflow_runs": [successful_run(**changes)]}, SHA)

    def test_newer_failed_run_overrides_prior_success(self):
        payload = {"workflow_runs": [
            successful_run(100),
            successful_run(101, conclusion="failure"),
        ]}
        with self.assertRaisesRegex(ReleaseGateError, "Latest"):
            verify_successful_exact_head_run(payload, SHA)

    def test_newer_run_success_is_verified(self):
        payload = {"workflow_runs": [
            successful_run(100, conclusion="failure"),
            successful_run(101),
        ]}
        self.assertEqual(verify_successful_exact_head_run(payload, SHA), 101)

    def test_invalid_run_identity_blocks(self):
        with self.assertRaisesRegex(ReleaseGateError, "identity"):
            verify_successful_exact_head_run(
                {"workflow_runs": [successful_run(run_id="not-an-id")]}, SHA)


if __name__ == "__main__":
    unittest.main()
