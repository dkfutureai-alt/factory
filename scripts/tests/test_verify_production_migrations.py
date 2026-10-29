"""Offline tests for fail-closed linked Supabase migration-history gate."""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_production_migrations import (
    HistoryError, cli_versions, local_versions, verify_history,
)


def table(*rows, ascii=False):
    sep = "|" if ascii else "│"
    return "\n".join([
        f" LOCAL {sep} REMOTE {sep} TIME (UTC)",
        f"──────────{sep}──────────{sep}────────────────",
        *[f" {local:<8} {sep} {remote:<8} {sep} 2026-01-01" for local, remote in rows],
    ])


class MigrationHistoryTests(unittest.TestCase):
    def setUp(self):
        self.committed = {"0001", "0002", "0046", "0047"}

    def test_new_project_preflight_allows_pending(self):
        local, remote = cli_versions(table(("0001", ""), ("0002", ""), ("0046", ""), ("0047", "")))
        self.assertIn("4 pending", verify_history(self.committed, local, remote, "preflight"))

    def test_partial_deploy_preflight_allows_only_known_remote(self):
        local, remote = cli_versions(table(("0001", "0001"), ("0002", "0002"), ("0046", ""), ("0047", "")))
        self.assertIn("2 pending", verify_history(self.committed, local, remote, "preflight"))

    def test_postdeploy_requires_every_committed_migration(self):
        local, remote = cli_versions(table(("0001", "0001"), ("0002", "0002"), ("0046", "0046"), ("0047", "0047")))
        self.assertIn("0 pending", verify_history(self.committed, local, remote, "postdeploy"))

    def test_postdeploy_fails_on_missing_remote(self):
        local, remote = cli_versions(table(("0001", "0001"), ("0002", "0002"), ("0046", "0046"), ("0047", "")))
        with self.assertRaisesRegex(HistoryError, "Deployment incomplete"):
            verify_history(self.committed, local, remote, "postdeploy")

    def test_remote_unknown_version_blocks_preflight(self):
        local, remote = cli_versions(table(("0001", "0001"), ("0002", "0002"), ("0046", "0046"), ("0047", "0047"), ("", "9999")))
        with self.assertRaisesRegex(HistoryError, "Unexpected remote"):
            verify_history(self.committed, local, remote, "preflight")

    def test_cli_local_version_missing_fails(self):
        local, remote = cli_versions(table(("0001", "0001"), ("0002", "0002"), ("0046", "0046")))
        with self.assertRaisesRegex(HistoryError, "CLI local migration"):
            verify_history(self.committed, local, remote, "preflight")

    def test_ascii_table_and_warning_banner(self):
        out = "A new version of Supabase CLI is available.\n" + table(("0001", "0001"), ("0002", "0002"), ("0046", "0046"), ("0047", "0047"), ascii=True)
        local, remote = cli_versions(out)
        self.assertEqual(local, self.committed)
        self.assertEqual(remote, self.committed)

    def test_malformed_column_or_empty_output_rejected(self):
        for output in ["", "LOCAL │ REMOTE │ TIME", " 0001 │ NOTAVERSION │ 2026-01-01"]:
            with self.subTest(output=output):
                with self.assertRaises(HistoryError):
                    cli_versions(output)

    def test_duplicate_remote_rejected(self):
        with self.assertRaisesRegex(HistoryError, "Duplicate remote"):
            cli_versions(table(("0001", "0001"), ("0002", "0001")))

    def test_early_supabase_ci_checks_migration_versions(self):
        workflow = (Path(__file__).resolve().parents[2]
                    / ".github/workflows/supabase-foundation.yml").read_text()
        command = "python3 scripts/check_migration_versions.py"
        self.assertIn(command, workflow)
        self.assertLess(workflow.index(command), workflow.index("supabase start"))
        self.assertLess(workflow.index(command), workflow.index("supabase/setup-cli@v1"))

    def test_fail_fast_script_calls_shared_version_parser(self):
        script = (Path(__file__).resolve().parents[1]
                  / "check_migration_versions.py").read_text()
        self.assertIn("local_versions(directory)", script)
        self.assertIn("except HistoryError", script)
        self.assertNotIn("db push", script)
        self.assertNotIn("db reset", script)

    def test_filenames_must_have_unique_exact_versions(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            (path / "0001_core.sql").write_text("select 1;")
            (path / "0002_intake.sql").write_text("select 1;")
            self.assertEqual(local_versions(path), {"0001", "0002"})
            (path / "0001_second.sql").write_text("select 1;")
            with self.assertRaisesRegex(HistoryError, "Duplicate migration version"):
                local_versions(path)

    def test_missing_first_or_middle_migration_blocks_empty_remote_release(self):
        for filenames in (
            ("0002_orphan.sql",),
            ("0001_core.sql", "0003_skipped.sql"),
            ("0000_invalid.sql", "0001_core.sql"),
        ):
            with self.subTest(filenames=filenames), tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary)
                for filename in filenames:
                    (path / filename).write_text("select 1;")
                with self.assertRaisesRegex(HistoryError, "contiguous from 0001"):
                    local_versions(path)

    def test_timestamp_or_extra_digit_version_cannot_bypass_numbered_chain(self):
        for filename in ("202610290001_extra.sql", "00001_extra.sql"):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary)
                (path / "0001_core.sql").write_text("select 1;")
                (path / filename).write_text("select 1;")
                with self.assertRaisesRegex(HistoryError, "Invalid migration filename"):
                    local_versions(path)

    def test_actual_committed_factoryos_migrations_form_contiguous_chain(self):
        root = Path(__file__).resolve().parents[2]
        versions = local_versions(root / "supabase/migrations")
        self.assertIn("0001", versions)
        self.assertGreaterEqual(len(versions), 52)


if __name__ == "__main__":
    unittest.main()
