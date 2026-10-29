"""Keep the persistent FactoryOS agent handoff discoverable and source-grounded."""

import pathlib
import re
import unittest
from urllib.parse import urlsplit

ROOT = pathlib.Path(__file__).resolve().parents[2]
CANONICAL = ROOT / "agent.md"
ENTRY = ROOT / "AGENTS.md"


class AgentContextTests(unittest.TestCase):
    def test_root_agent_files_and_readme_discovery(self):
        self.assertTrue(CANONICAL.is_file(), "agent.md must be in repository root")
        self.assertTrue(ENTRY.is_file(), "standard AGENTS.md must be in root")
        entry = ENTRY.read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("agent.md", entry)
        self.assertIn("AGENTS.md", readme)
        self.assertIn("agent.md", readme)

    def test_handoff_defends_isolation_and_live_release_boundary(self):
        context = CANONICAL.read_text(encoding="utf-8")
        entry = ENTRY.read_text(encoding="utf-8")
        for fragment in (
            "zevrmvhnibztbxizswgu",
            "Salon", "Janseva", "RLS", "Inventory",
            "production", "backup", "restore", "QR",
            "pilot", "consent", "#12", "#27", "#45", "#47",
            "Supabase Production Plan", "Supabase Production Release",
            "Release Workflow Lint", "Supabase Foundation Checks",
            "Multi-tenancy", "Mobile multi-org",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, context)
        self.assertIn("Do not", entry)
        self.assertIn("production", entry)
        self.assertIn("Re-check", context)

    def test_context_migration_head_matches_committed_files(self):
        context = CANONICAL.read_text(encoding="utf-8")
        tick = chr(96)
        match = re.search(
            r"Ordered SQL migrations " + tick + "0001" + tick +
            r"–" + tick + r"(\d{4})" + tick,
            context,
        )
        self.assertIsNotNone(match, "State the latest committed migration in agent.md")
        versions = []
        for path in (ROOT / "supabase" / "migrations").glob("*.sql"):
            parsed = re.fullmatch(r"(\d{4})_[A-Za-z0-9_-]+\.sql", path.name)
            self.assertIsNotNone(parsed, f"Invalid migration filename {path.name}")
            versions.append(int(parsed.group(1)))
        self.assertTrue(versions)
        self.assertEqual(int(match.group(1)), max(versions),
                         "Update agent.md when adding a migration")

    def test_referenced_project_files_exist(self):
        context = CANONICAL.read_text(encoding="utf-8")
        expected = (
            "apps/admin_web/", "apps/mobile/", "packages/factoryos_core/",
            "supabase/migrations/", "supabase/tests/",
            "supabase/functions/invite-user/",
            "supabase/functions/send-notifications/",
            "scripts/tests/", ".github/workflows/",
            "docs/ARCHITECTURE.md", "docs/PRODUCTION_GO_LIVE_CHECKLIST.md",
            "docs/FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md",
            "docs/PHASE_29_REAL_CUSTOMER_PILOT_ACCEPTANCE.md",
            "docs/PHASE_29_PUSH_DISPATCH_ACCOUNTABILITY.md",
        )
        for path in expected:
            with self.subTest(path=path):
                self.assertIn(path, context)
                self.assertTrue((ROOT / path).exists())

    def test_agent_and_readme_relative_markdown_links_are_valid(self):
        for file in (ENTRY, CANONICAL, ROOT / "README.md"):
            body = file.read_text(encoding="utf-8")
            for target in re.findall(r"\]\(([^)#]+)(?:#[^)]+)?\)", body):
                if urlsplit(target).scheme or target.startswith("#"):
                    continue
                with self.subTest(file=file.name, target=target):
                    self.assertFalse(target.startswith("/"))
                    self.assertNotIn("..", pathlib.PurePosixPath(target).parts)
                    self.assertTrue((file.parent / target).exists(),
                                    f"Broken local link {file.name} to {target}")

    def test_agent_changes_trigger_ci_and_handoff_tests(self):
        lint = (ROOT / ".github/workflows/release-workflow-lint.yml").read_text(
            encoding="utf-8"
        )
        for path in ("AGENTS.md", "agent.md", "README.md"):
            self.assertEqual(lint.count(f"      - '{path}'"), 2, path)
        self.assertIn("python3 -m unittest discover -s scripts/tests -v", lint)


if __name__ == "__main__":
    unittest.main()
