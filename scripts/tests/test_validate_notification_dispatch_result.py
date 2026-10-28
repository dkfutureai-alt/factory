"""Synthetic, no-network tests for FactoryOS push dispatch accounting."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from validate_notification_dispatch_result import (
    DispatchResultError,
    parse_result_file,
    validate_dispatch_result,
)


class DispatchResultTests(unittest.TestCase):
    def setUp(self):
        self.valid = {
            "claimed": 3,
            "processed": 3,
            "sent": 2,
            "failed": 0,
            "skipped": 1,
        }

    def test_successful_batch_reports_provider_acceptance_not_device_delivery(self):
        self.assertEqual(validate_dispatch_result(self.valid), (3, 2, 1))

    def test_empty_queue_is_valid_noop_not_fake_send(self):
        self.assertEqual(validate_dispatch_result({
            key: 0 for key in self.valid
        }), (0, 0, 0))

    def test_worker_reported_failure_fails_schedule(self):
        with self.assertRaisesRegex(DispatchResultError, "failed delivery"):
            validate_dispatch_result({**self.valid, "sent": 1, "failed": 1})

    def test_missing_claimed_field_rejects_legacy_unverified_worker(self):
        incomplete = dict(self.valid)
        del incomplete["claimed"]
        with self.assertRaisesRegex(DispatchResultError, "claimed"):
            validate_dispatch_result(incomplete)

    def test_partial_claim_or_unbalanced_result_rejected(self):
        for case in (
            {**self.valid, "claimed": 4},
            {**self.valid, "processed": 4},
            {**self.valid, "sent": 3},
        ):
            with self.subTest(case=case), self.assertRaises(DispatchResultError):
                validate_dispatch_result(case)

    def test_boolean_negative_float_string_and_oversized_counts_rejected(self):
        for value in (True, False, -1, 1.5, "2", 21, None):
            for key in self.valid:
                with self.subTest(key=key, value=value), self.assertRaises(DispatchResultError):
                    validate_dispatch_result({**self.valid, key: value})

    def test_unexpected_worker_shapes_are_rejected(self):
        for value in (None, [], "ready", 5, {"error": "provider unavailable"}):
            with self.subTest(value=value), self.assertRaises(DispatchResultError):
                validate_dispatch_result(value)

    def test_malformed_or_oversized_json_body_is_not_logged(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "worker.json"
            for text in ('{not-json secret-token', 'x' * 65537):
                p.write_text(text, encoding="utf-8")
                with self.assertRaises(DispatchResultError) as caught:
                    parse_result_file(p)
                self.assertNotIn("secret-token", str(caught.exception))

    def test_cli_suppresses_sensitive_response_bodies(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "worker.json"
            p.write_text('{"error":"SECRET-SENTINEL"}', encoding="utf-8")
            script = ROOT / "validate_notification_dispatch_result.py"
            result = subprocess.run(
                [sys.executable, str(script), "--input", str(p)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 2)
            self.assertNotIn("SECRET-SENTINEL", result.stdout + result.stderr)

    def test_cli_accepts_empty_queue(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "worker.json"
            p.write_text('{"claimed":0,"processed":0,"sent":0,"failed":0,"skipped":0}',
                         encoding="utf-8")
            script = ROOT / "validate_notification_dispatch_result.py"
            result = subprocess.run(
                [sys.executable, str(script), "--input", str(p)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("0 processed", result.stdout)


if __name__ == "__main__":
    unittest.main()
