"""Offline tests: protected FactoryOS two-identity JWT/RLS smoke never uses real users."""

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import production_tenant_isolation_smoke as smoke

A_UID = "00000000-0000-4000-8000-000000000001"
B_UID = "00000000-0000-4000-8000-000000000002"
A_ORG = "10000000-0000-4000-8000-000000000001"
B_ORG = "10000000-0000-4000-8000-000000000002"
A_FACTORY = "20000000-0000-4000-8000-000000000001"
B_FACTORY = "20000000-0000-4000-8000-000000000002"


def settings():
    return {
        "FACTORYOS_SUPABASE_URL": smoke.PROJECT_URL,
        "FACTORYOS_SUPABASE_PROJECT_REF": smoke.PROJECT_REF,
        "FACTORYOS_SUPABASE_PUBLISHABLE_KEY": "sb_publishable_fake_test_key_not_real",
        "FACTORYOS_TENANT_A_SMOKE_EMAIL": "test-a@invalid.example",
        "FACTORYOS_TENANT_A_SMOKE_PASSWORD": "dummy-a",
        "FACTORYOS_TENANT_B_SMOKE_EMAIL": "test-b@invalid.example",
        "FACTORYOS_TENANT_B_SMOKE_PASSWORD": "dummy-b",
    }


class TwoTenantSmokeTests(unittest.TestCase):
    def test_configuration_accepts_only_dedicated_factoryos_target(self):
        self.assertEqual(smoke.require_configuration(settings()), settings()["FACTORYOS_SUPABASE_PUBLISHABLE_KEY"])
        for overrides in (
            {"FACTORYOS_SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
             "FACTORYOS_SUPABASE_PROJECT_REF": "abcdefghijklmnopqrst"},
            {"FACTORYOS_SUPABASE_URL": smoke.PROJECT_URL + "/"},
            {"FACTORYOS_SUPABASE_PUBLISHABLE_KEY": "sb_secret_not_for_client"},
            {"FACTORYOS_TENANT_B_SMOKE_EMAIL": "TEST-A@invalid.example"},
            {"FACTORYOS_TENANT_B_SMOKE_PASSWORD": ""},
        ):
            with self.subTest(overrides=overrides):
                with self.assertRaises(smoke.SmokeBlocked):
                    smoke.require_configuration({**settings(), **overrides})

    def test_active_membership_is_unique_and_owned_by_identity(self):
        row = {"organization_id": A_ORG, "user_id": A_UID}
        self.assertEqual(smoke.extract_org_membership([row], A_UID), A_ORG)
        for rows in ([], [row, {"organization_id": B_ORG, "user_id": A_UID}],
                     [{"organization_id": A_ORG, "user_id": B_UID}], [None]):
            with self.subTest(rows=rows):
                with self.assertRaises(smoke.SmokeBlocked):
                    smoke.extract_org_membership(rows, A_UID)

    def test_factory_positive_read_must_be_in_own_organization(self):
        self.assertEqual(smoke.extract_own_factory([{"id": A_FACTORY, "organization_id": A_ORG}], A_ORG), A_FACTORY)
        for rows in ([], [{"id": B_FACTORY, "organization_id": B_ORG}], [None],
                     [{"id": "not-uuid", "organization_id": A_ORG}]):
            with self.subTest(rows=rows):
                with self.assertRaises(smoke.SmokeBlocked):
                    smoke.extract_own_factory(rows, A_ORG)

    def test_foreign_read_denial_requires_empty_array_not_5xx_body(self):
        smoke.require_hidden([], "factories")
        for rows in ([{"id": B_FACTORY}], {"error": "permission denied"}, None):
            with self.subTest(rows=rows):
                with self.assertRaises(smoke.SmokeBlocked):
                    smoke.require_hidden(rows, "factories")

    def test_both_directions_must_run_and_accounts_must_be_distinct(self):
        a = {"token": "token-a", "user_id": A_UID, "org_id": A_ORG, "factory_id": A_FACTORY}
        b = {"token": "token-b", "user_id": B_UID, "org_id": B_ORG, "factory_id": B_FACTORY}
        with patch.object(smoke, "identity", side_effect=[a, b]), \
             patch.object(smoke, "verify_foreign_denial") as checker, \
             patch("builtins.print"):
            smoke.run(settings())
        self.assertEqual(checker.call_count, 2)
        checker.assert_any_call(a, b, settings()["FACTORYOS_SUPABASE_PUBLISHABLE_KEY"])
        checker.assert_any_call(b, a, settings()["FACTORYOS_SUPABASE_PUBLISHABLE_KEY"])
        with patch.object(smoke, "identity", side_effect=[a, a]):
            with self.assertRaisesRegex(smoke.SmokeBlocked, "different users"):
                smoke.run(settings())

    def test_real_cross_org_negative_probes_are_read_only(self):
        a = {"token": "a-token", "user_id": A_UID, "org_id": A_ORG, "factory_id": A_FACTORY}
        b = {"token": "b-token", "user_id": B_UID, "org_id": B_ORG, "factory_id": B_FACTORY}
        with patch.object(smoke, "get_rows", return_value=[]) as reader:
            smoke.verify_foreign_denial(a, b, "dummy-publishable")
        self.assertEqual(reader.call_count, 3)
        self.assertEqual({c.args[0] for c in reader.call_args_list},
                         {"organizations", "organization_members", "factories"})
        with patch.object(smoke, "get_rows", return_value=[{"id": B_FACTORY}]):
            with self.assertRaisesRegex(smoke.SmokeBlocked, "Cross-tenant"):
                smoke.verify_foreign_denial(a, b, "dummy-publishable")

    def test_github_workflow_needs_manual_confirmation_and_owner_environment(self):
        root = Path(__file__).resolve().parents[2]
        yaml = (root / ".github/workflows/production-tenant-isolation.yml").read_text()
        self.assertIn("inputs.confirm == 'VERIFY_TENANTS' && github.ref == 'refs/heads/main'", yaml)
        self.assertIn("environment: factoryos-production", yaml)
        self.assertIn("zevrmvhnibztbxizswgu", yaml)
        for variable in smoke.REQUIRED:
            self.assertIn(variable + ":", yaml)
        self.assertIn("python3 scripts/production_tenant_isolation_smoke.py", yaml)
        self.assertNotIn("supabase db push", yaml)
        self.assertNotIn("supabase db reset", yaml)


if __name__ == "__main__":
    unittest.main()
