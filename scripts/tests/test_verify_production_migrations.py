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

    def test_filenames_must_have_unique_exact_versions(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            (path / "0001_core.sql").write_text("select 1;")
            (path / "0046_intake.sql").write_text("select 1;")
            self.assertEqual(local_versions(path), {"0001", "0046"})
            (path / "0001_second.sql").write_text("select 1;")
            with self.assertRaisesRegex(HistoryError, "Duplicate migration version"):
                local_versions(path)


if __name__ == "__main__":
    unittest.main()
