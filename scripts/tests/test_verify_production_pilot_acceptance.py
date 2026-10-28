"""Synthetic, offline tests for the real-user pilot acceptance read gate.

No cloud calls, real customers, credentials, production mutations, or seeds.
"""

import sys
import unittest
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from verify_production_pilot_acceptance import (
    MAX_REPORTS, OPERATIONAL_TABLES, SCENARIOS, SmokeError,
    normalize_environment, parse_timestamp, require_completed_reports,
    verify_pilot,
)
from production_tenant_isolation_smoke import PROJECT_REF

USER_IDS = (str(uuid.UUID(int=1)), str(uuid.UUID(int=2)))
ORG_IDS = (str(uuid.UUID(int=101)), str(uuid.UUID(int=102)))
NOW = datetime(2026, 10, 29, 0, 0, tzinfo=timezone.utc)


def config():
    return {
        "SUPABASE_PROJECT_REF": PROJECT_REF,
        "SUPABASE_URL": f"https://{PROJECT_REF}.supabase.co",
        "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_synthetic_not_a_real_key",
        "PILOT_ADMIN_A_EMAIL": "admin-a@example.test",
        "PILOT_ADMIN_A_PASSWORD": "fake-a",
        "PILOT_ADMIN_B_EMAIL": "admin-b@example.test",
        "PILOT_ADMIN_B_PASSWORD": "fake-b",
    }


class FakeApi:
    def __init__(self, *, missing_scenario=None, latest_bad=None,
                 stale=False, no_consent=False, no_table=None, leak=None,
                 role="org_admin"):
        self.calls = []
        self.missing_scenario = missing_scenario
        self.latest_bad = latest_bad
        self.stale = stale
        self.no_consent = no_consent
        self.no_table = no_table
        self.leak = leak
        self.role = role

    def __call__(self, method, path, *, token="", payload=None):
        self.calls.append((method, path))
        if method == "POST":
            if path != "/auth/v1/token?grant_type=password":
                raise AssertionError("Never allow a business POST.")
            return {"access_token": "token-a" if payload["email"] == "admin-a@example.test" else "token-b"}
        if method != "GET":
            raise AssertionError("No mutation permitted in pilot verifier.")
        idx = 0 if token == "token-a" else 1
        own_uid, own_org = USER_IDS[idx], ORG_IDS[idx]
        if path == "/auth/v1/user":
            return {"id": own_uid}
        p = urlsplit(path)
        query = {k: v[0] for k, v in parse_qs(p.query).items()}
        table = p.path.rsplit("/", 1)[-1]
        if table == "organization_members" and "user_id" in query:
            return [{"organization_id": own_org, "user_id": own_uid, "role": self.role}]
        target = query.get("organization_id", query.get("id", "")).removeprefix("eq.")
        if target != own_org:
            if self.leak == table:
                return [{"id": str(uuid.UUID(int=800)), "organization_id": target}]
            return []
        if table == "organizations":
            return [{"id": own_org}]
        if table == "organization_members":
            return [{"id": str(uuid.UUID(int=1000)), "organization_id": own_org}]
        if table == "factories":
            return [{"id": str(uuid.UUID(int=2000 + idx)), "organization_id": own_org}]
        if table == "factory_members":
            return []
        if table == "pilot_participants":
            return [] if self.no_consent else [{
                "organization_id": own_org, "user_id": own_uid,
                "consented_at": "2026-10-27T00:00:00Z",
            }]
        if table == "pilot_feedback":
            records = []
            for i, scenario in enumerate(sorted(SCENARIOS)):
                if scenario == self.missing_scenario:
                    continue
                records.append({
                    "id": str(uuid.UUID(int=4000 + idx * 100 + i)),
                    "organization_id": own_org,
                    "user_id": own_uid,
                    "scenario": scenario,
                    "result": "passed",
                    "created_at": "2026-10-01T00:00:00Z" if self.stale else "2026-10-28T00:00:00Z",
                })
                if self.latest_bad == scenario:
                    records.append({
                        **records[-1],
                        "id": str(uuid.UUID(int=6000 + idx * 100 + i)),
                        "result": "failed",
                        "created_at": "2026-10-28T23:00:00Z",
                    })
            return records
        if table in OPERATIONAL_TABLES:
            if self.no_table == table:
                return []
            return [{"id": str(uuid.UUID(int=3000)), "organization_id": own_org}]
        raise AssertionError("Unknown table: " + table)


class PilotAcceptanceTests(unittest.TestCase):
    def test_two_consenting_orgs_with_complete_recent_reports_and_real_records_pass(self):
        fake = FakeApi()
        self.assertEqual(verify_pilot(fake, config(), now=NOW), (14, len(OPERATIONAL_TABLES)))
        self.assertEqual(sum(m == "POST" for m, _ in fake.calls), 2)
        self.assertTrue(all(m == "GET" for m, p in fake.calls if p.startswith("/rest/v1/")))
        for table in OPERATIONAL_TABLES:
            self.assertTrue(any(f"/{table}?" in p for _, p in fake.calls))

    def test_missing_consent_is_blocked(self):
        with self.assertRaisesRegex(SmokeError, "consent"):
            verify_pilot(FakeApi(no_consent=True), config(), now=NOW)

    def test_missing_workflow_feedback_is_blocked(self):
        with self.assertRaisesRegex(SmokeError, "Missing reported pilot scenarios"):
            verify_pilot(FakeApi(missing_scenario="quality"), config(), now=NOW)

    def test_latest_failure_overrides_older_pass(self):
        with self.assertRaisesRegex(SmokeError, "quality"):
            verify_pilot(FakeApi(latest_bad="quality"), config(), now=NOW)

    def test_stale_reports_cannot_mark_production_approved(self):
        with self.assertRaisesRegex(SmokeError, "older than"):
            verify_pilot(FakeApi(stale=True), config(), now=NOW)

    def test_missing_actual_operational_data_is_not_accepted(self):
        for table in OPERATIONAL_TABLES:
            with self.subTest(table=table), self.assertRaisesRegex(SmokeError, table):
                verify_pilot(FakeApi(no_table=table), config(), now=NOW)

    def test_cross_tenant_leak_is_caught_for_every_operational_table(self):
        for table in (*OPERATIONAL_TABLES, "pilot_participants", "pilot_feedback"):
            with self.subTest(table=table), self.assertRaisesRegex(SmokeError, "foreign|Foreign"):
                verify_pilot(FakeApi(leak=table), config(), now=NOW)

    def test_admin_scope_required_not_employee_or_platform_owner(self):
        for role in ("employee", "driver", "viewer", "platform_owner"):
            with self.subTest(role=role), self.assertRaises(SmokeError):
                verify_pilot(FakeApi(role=role), config(), now=NOW)

    def test_pilot_identity_and_target_configuration_fail_closed(self):
        for bad in (
            {"PILOT_ADMIN_B_EMAIL": "ADMIN-A@example.test"},
            {"PILOT_ADMIN_B_PASSWORD": ""},
            {"SUPABASE_PROJECT_REF": "abcdefghijklmnopqrst",
             "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co"},
            {"SUPABASE_PUBLISHABLE_KEY": "sb_secret_private"},
        ):
            with self.subTest(bad=bad), self.assertRaises(SmokeError):
                normalize_environment({**config(), **bad})

    def test_timestamp_checks_and_feedback_history_overflow(self):
        for stamp in ("bad", "2026-10-28T11:00:00", None):
            with self.subTest(stamp=stamp), self.assertRaises(SmokeError):
                parse_timestamp(stamp)
        class Identity:
            organization_id = ORG_IDS[0]
            user_id = USER_IDS[0]
        with self.assertRaisesRegex(SmokeError, "truncated"):
            require_completed_reports([{}] * MAX_REPORTS, Identity(), NOW)

    def test_manual_workflow_stays_main_only_protected_read_only(self):
        yml = (Path(__file__).resolve().parents[2] /
               ".github/workflows/production-pilot-acceptance.yml").read_text()
        self.assertIn("inputs.confirm == 'VERIFY_PILOT' && github.ref == 'refs/heads/main'", yml)
        self.assertIn("environment: factoryos-production", yml)
        self.assertIn("zevrmvhnibztbxizswgu", yml)
        self.assertIn("python3 scripts/verify_production_pilot_acceptance.py", yml)
        for command in ("supabase db push", "supabase db reset", "supabase functions deploy"):
            self.assertNotIn(command, yml)


if __name__ == "__main__":
    unittest.main()
