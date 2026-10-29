"""Release regression checks for FactoryOS agent handoff and backup-leak protection."""

import pathlib
import sys
import unittest
from unittest.mock import patch
from subprocess import CompletedProcess

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from check_no_private_backups import find_private_exports, is_private_export, main


class AgentAndRecoveryTests(unittest.TestCase):
    def test_handoff_written_for_both_humans_and_standard_coding_agents(self):
        self.assertTrue((ROOT / "agent.md").is_file())
        self.assertTrue((ROOT / "AGENTS.md").is_file())
        context = (ROOT / "agent.md").read_text(encoding="utf-8")
        standard = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        for marker in (
            "dkfutureai-alt/factory",
            "zevrmvhnibztbxizswgu",
            "docs/PRODUCTION_GO_LIVE_CHECKLIST.md",
            "scripts/tests",
            "supabase db reset",
            "Salon",
            "Janseva",
            "customer",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, context)
        self.assertIn("agent.md", standard)

    def test_public_migration_test_and_fictional_seed_paths_allowed(self):
        for path in (
            "supabase/migrations/0049_gas_serial_attestation_coverage.sql",
            "supabase/tests/0045_explicit_data_api_grants_smoke.sql",
            "supabase/seed.sql",
            "supabase/seed_phase10.sql",
            "docs/PHASE_30_FREE_PLAN_BACKUP_RECOVERY.md",
            "scripts/check_no_private_backups.py",
            ".github/workflows/supabase-production-plan.yml",
        ):
            with self.subTest(path=path):
                self.assertFalse(is_private_export(path))

    def test_private_backup_files_and_directories_blocked(self):
        for path in (
            "backups/roles.sql",
            "apps/mobile/backups/prod.txt",
            ".factoryos-private-backups/customer.data",
            "factoryos-recovery-20261029/data.sql",
            "private-backups/random.txt",
            "production.sql",
            "roles.sql",
            "schema.sql",
            "data.sql",
            "history_schema.sql",
            "history_data.sql",
            "backup.sql",
            "snapshot.dump",
            "snapshot.backup",
            "snapshot.PGDUMP",
            "customer.sql.gz",
            "customer.sql.zst",
            "customer.sql.age",
            "backup.tar.gpg",
            "FactoryOS-Production-Backup-2026.sql",
            "../escape",
            "",
        ):
            with self.subTest(path=path):
                self.assertTrue(is_private_export(path), path)

    def test_output_is_sorted_and_duplicate_free(self):
        self.assertEqual(
            find_private_exports(["schema.sql", "supabase/seed.sql",
                                  "data.sql", "schema.sql"]),
            ["data.sql", "schema.sql"],
        )

    def test_ci_rejects_private_exports_from_actual_git_index(self):
        with patch("check_no_private_backups.subprocess.run",
                   return_value=CompletedProcess(
                       ["git", "ls-files", "-z"], 0,
                       stdout=b"agent.md\x00factoryos-recovery-abc/data.sql\x00",
                       stderr=b"",
                   )), patch("builtins.print") as printer:
            self.assertEqual(main(), 2)
            self.assertTrue(any("BLOCKED" in str(call) for call in printer.call_args_list))

    def test_ci_passes_for_safe_tracked_names(self):
        with patch("check_no_private_backups.subprocess.run",
                   return_value=CompletedProcess(
                       ["git", "ls-files", "-z"], 0,
                       stdout=b"agent.md\x00supabase/migrations/0001_foundation.sql\x00",
                       stderr=b"",
                   )), patch("builtins.print"):
            self.assertEqual(main(), 0)

    def test_release_workflows_check_repository_index(self):
        for filename in ("release-workflow-lint.yml", "supabase-foundation.yml"):
            content = (ROOT / ".github/workflows" / filename).read_text(encoding="utf-8")
            self.assertIn("python3 scripts/check_no_private_backups.py", content)

    def test_gitignore_blocks_private_backup_filenames_but_not_migrations(self):
        ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("backups/", ignore)
        self.assertIn("*.sql.gz", ignore)
        self.assertIn("*.dump", ignore)
        self.assertNotIn("\n*.sql\n", ignore)
        self.assertTrue((ROOT / "docs/PHASE_30_FREE_PLAN_BACKUP_RECOVERY.md").is_file())


if __name__ == "__main__":
    unittest.main()
