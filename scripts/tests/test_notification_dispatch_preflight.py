"""Offline regressions for the scheduled notification dispatch target guard."""

import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from notification_dispatch_preflight import validate_dispatch_environment


class NotificationDispatchPreflightTests(unittest.TestCase):
    def setUp(self):
        self.config = {
            "FACTORYOS_SUPABASE_PROJECT_REF": "abcdefghijklmnopqrst",
            "FACTORYOS_SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
            "NOTIFICATION_DISPATCH_SECRET": "fabricated-integration-secret-not-real",
        }

    def test_exact_factoryos_target_allowed(self):
        self.assertEqual(validate_dispatch_environment(self.config)[0], "ready")

    def test_all_missing_skips_without_contacting_any_project(self):
        self.assertEqual(validate_dispatch_environment({})[0], "skip")

    def test_partially_configured_target_is_an_error(self):
        for missing in self.config:
            with self.subTest(missing=missing):
                config = {**self.config, missing: ""}
                self.assertEqual(validate_dispatch_environment(config)[0], "error")

    def test_whitespace_only_dispatch_secret_rejected(self):
        config = {**self.config, "NOTIFICATION_DISPATCH_SECRET": "   "}
        self.assertEqual(validate_dispatch_environment(config)[0], "error")

    def test_cross_project_url_rejected(self):
        config = {**self.config, "FACTORYOS_SUPABASE_URL": "https://differentprojectref.supabase.co"}
        self.assertEqual(validate_dispatch_environment(config)[0], "error")

    def test_redirect_and_credentials_targets_rejected(self):
        urls = [
            "https://abcdefghijklmnopqrst.supabase.co.evil.invalid",
            "https://abcdefghijklmnopqrst.supabase.co@evil.invalid",
            "http://abcdefghijklmnopqrst.supabase.co",
            "https://abcdefghijklmnopqrst.supabase.co/",
            "https://abcdefghijklmnopqrst.supabase.co/functions/v1/send-notifications",
        ]
        for url in urls:
            with self.subTest(url=url):
                self.assertEqual(
                    validate_dispatch_environment({**self.config, "FACTORYOS_SUPABASE_URL": url})[0],
                    "error",
                )

    def test_reference_injection_and_bad_format_rejected(self):
        references = [
            "short", "ABCDEFGHIJKLMNOPQRST",
            "abcdefghijklmnopqrst@evil.invalid/path",
            "abcdefghijklmnopqrs-", "abcdefghijklmnopqrs/",
            "abcdefghijklmnopqrs\n",
        ]
        for ref in references:
            with self.subTest(ref=ref):
                config = {**self.config, "FACTORYOS_SUPABASE_PROJECT_REF": ref}
                self.assertEqual(validate_dispatch_environment(config)[0], "error")

    def test_no_secret_leak_in_error_messages(self):
        for config in ({}, {**self.config, "FACTORYOS_SUPABASE_URL": "https://evil.invalid"}):
            _, message = validate_dispatch_environment(config)
            self.assertNotIn(self.config["NOTIFICATION_DISPATCH_SECRET"], message)

    def test_cli_exit_codes(self):
        script = Path(__file__).resolve().parents[1] / "notification_dispatch_preflight.py"
        for config, expected in [
            (self.config, 0),
            ({}, 3),
            ({**self.config, "FACTORYOS_SUPABASE_PROJECT_REF": "bad"}, 2),
        ]:
            with self.subTest(expected=expected):
                process = subprocess.run(
                    [sys.executable, str(script)],
                    env=config,
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(process.returncode, expected)
                self.assertNotIn(self.config["NOTIFICATION_DISPATCH_SECRET"], process.stdout)


if __name__ == "__main__":
    unittest.main()
