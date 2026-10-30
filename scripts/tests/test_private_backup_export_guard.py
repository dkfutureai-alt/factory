"""Regression tests for the tracked-private-export release guard (offline only)."""

import io
import subprocess
import sys
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_no_private_backups import find_private_exports, is_private_export, main


class PrivateBackupGuardTests(unittest.TestCase):
    def test_rejects_common_compressed_and_encrypted_database_exports(self):
        dangerous = (
            "backup.sql.xz", "backup.sql.bz2", "backup.sql.zip",
            "backup.sql.enc", "production.dump.gz", "production.dump.zst",
            "production.dump.age", "production.dump.gpg",
            "db.backup.gz", "db.backup.zst", "db.backup.age",
            "db.backup.gpg", "snapshot.pgdump.gz", "snapshot.pgdump.zst",
            "snapshot.pgdump.xz", "pg_dump.sql", "pg_dumpall.sql",
            "supabase-backup.sql",
        )
        for filename in dangerous:
            with self.subTest(filename=filename):
                self.assertTrue(is_private_export("exports/" + filename))

    def test_nested_private_directory_and_case_insensitive_suffix(self):
        self.assertTrue(is_private_export("Docs/BACKUPS/anything.txt"))
        self.assertTrue(is_private_export("private/DB.BACKUP.ZST"))
        self.assertTrue(is_private_export("FactoryOS-Recovery-2026/notes.txt"))
        self.assertTrue(is_private_export(r"tmp\\backup.sql.xz"))

    def test_does_not_block_normal_migrations_source_or_assets(self):
        safe = (
            "supabase/migrations/0052_gas_serial_link_source_integrity.sql",
            "docs/PRODUCTION_GO_LIVE_CHECKLIST.md",
            "assets/screenshots/app.zip", "scripts/backup_helpers.py",
            "supabase/tests/phase_33_gas.sql",
        )
        for filename in safe:
            with self.subTest(filename=filename):
                self.assertFalse(is_private_export(filename))

    def test_rejects_traversal_absolute_and_invalid_paths(self):
        for filename in ("../backup.txt", "/tmp/file.txt", "", "foo\x00bar"):
            with self.subTest(filename=repr(filename)):
                self.assertTrue(is_private_export(filename))

    def test_deduplicates_private_exports(self):
        self.assertEqual(
            find_private_exports(["db.dump.gz", "safe.py", "db.dump.gz", "roles.sql"]),
            ["db.dump.gz", "roles.sql"],
        )

    def test_git_failure_fails_closed(self):
        with patch("check_no_private_backups.subprocess.run", side_effect=subprocess.CalledProcessError(1, ["git"])):
            with redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(main(), 2)
        self.assertIn("could not safely inspect", errors.getvalue())

    def test_log_escapes_untrusted_filename_newlines(self):
        fake = SimpleNamespace(stdout=b"exports/backup\nPASS: fake check\n.sql.xz\x00")
        with patch("check_no_private_backups.subprocess.run", return_value=fake):
            with redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(main(), 2)
        self.assertIn(r"\nPASS: fake check\n", errors.getvalue())
        self.assertNotIn("\nPASS: fake check\n", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
