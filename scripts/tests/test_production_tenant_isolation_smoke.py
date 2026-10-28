"""Synthetic two-tenant production smoke regressions: no live network calls."""

import sys
import unittest
from pathlib import Path
from urllib.parse import urlsplit, parse_qs

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from production_tenant_isolation_smoke import (
    PROJECT_REF, SmokeError, validate_environment, verify_isolation,
)

USER_IDS = ("11111111-1111-4111-8111-111111111111",
            "22222222-2222-4222-8222-222222222222")
ORG_IDS = ("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
           "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")


class FakeApi:
    def __init__(self, leak="", no_factory=False, platform_owner=False):
        self.calls = []
        self.leak = leak
        self.no_factory = no_factory
        self.platform_owner = platform_owner

    def __call__(self, method, path, *, token="", payload=None):
        self.calls.append((method, path))
        if method == "POST":
            return {"access_token": "t0" if payload["email"] == "a@example.test" else "t1"}
        index = 0 if token == "t0" else 1
        user, org = USER_IDS[index], ORG_IDS[index]
        if path == "/auth/v1/user":
            return {"id": user}
        parts = urlsplit(path)
        query = {k: v[0] for k, v in parse_qs(parts.query).items()}
        table = parts.path.rsplit("/", 1)[-1]
        if table == "organization_members" and "user_id" in query:
            return [{"organization_id": org, "user_id": user,
                     "role": "platform_owner" if self.platform_owner else "viewer"}]
        wanted = query.get("organization_id", query.get("id", "")).removeprefix("eq.")
        if wanted != org:
            return [{"id": USER_IDS[1 - index], "organization_id": wanted}] if self.leak == table else []
        if table == "organizations":
            return [{"id": org}]
        if table == "organization_members":
            return [{"id": user, "organization_id": org}]
        if table == "factories":
            return [] if self.no_factory else [{"id": user, "organization_id": org}]
        if table == "factory_members":
            return []
        raise AssertionError("Unexpected table")


class IsolationTests(unittest.TestCase):
    def setUp(self):
        self.env = {
            "SUPABASE_PROJECT_REF": PROJECT_REF,
            "SUPABASE_URL": f"https://{PROJECT_REF}.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_synthetic_not_a_real_key",
            "SMOKE_EMAIL": "a@example.test",
            "SMOKE_PASSWORD": "synthetic-a",
            "SMOKE_SECOND_EMAIL": "b@example.test",
            "SMOKE_SECOND_PASSWORD": "synthetic-b",
        }

    def test_two_realistic_scopes_pass_with_get_only(self):
        fake = FakeApi()
        verify_isolation(fake, self.env)
        self.assertEqual(sum(method == "POST" for method, _ in fake.calls), 2)
        self.assertTrue(all(method == "GET" for method, path in fake.calls
                            if path.startswith("/rest/v1/")))

    def test_wrong_project_rejected_before_request(self):
        self.env["SUPABASE_PROJECT_REF"] = "abcdefghijklmnopqrst"
        self.env["SUPABASE_URL"] = "https://abcdefghijklmnopqrst.supabase.co"
        with self.assertRaises(SmokeError):
            validate_environment(self.env)

    def test_secret_role_and_legacy_keys_rejected_before_any_request(self):
        for key in ("sb_secret_fake_but_forbidden", "eyJ.legacy_service_role_jwt",
                    "sb_publishable_short", "sb_publishable_synthetic\nleak"):
            with self.subTest(key=key):
                self.env["SUPABASE_PUBLISHABLE_KEY"] = key
                with self.assertRaisesRegex(SmokeError, "publishable"):
                    validate_environment(self.env)
        self.env["SUPABASE_PUBLISHABLE_KEY"] = "sb_publishable_synthetic_not_a_real_key"

    def test_no_positive_factory_cannot_pass(self):
        with self.assertRaisesRegex(SmokeError, "visible active factory"):
            verify_isolation(FakeApi(no_factory=True), self.env)

    def test_privileged_owner_cannot_mask_cross_tenant_leak(self):
        with self.assertRaisesRegex(SmokeError, "non-platform"):
            verify_isolation(FakeApi(platform_owner=True), self.env)

    def test_cross_tenant_leaks_fail(self):
        for table in ("organizations", "organization_members", "factories", "factory_members"):
            with self.subTest(table=table), self.assertRaisesRegex(SmokeError, "foreign"):
                verify_isolation(FakeApi(leak=table), self.env)

    def test_secondary_account_is_mandatory(self):
        self.env["SMOKE_SECOND_PASSWORD"] = ""
        with self.assertRaisesRegex(SmokeError, "SMOKE_SECOND_PASSWORD"):
            verify_isolation(FakeApi(), self.env)


if __name__ == "__main__":
    unittest.main()
