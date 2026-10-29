"""Keep owner-facing FactoryOS production instructions at the actual migration head."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ProductionRunbookHeadTests(unittest.TestCase):
    def test_release_instructions_track_latest_source_migration(self):
        files = list((ROOT / "supabase/migrations").glob("*.sql"))
        self.assertTrue(files)
        versions = []
        for path in files:
            m = re.fullmatch(r"(\d{4})_[A-Za-z0-9_-]+\.sql", path.name)
            self.assertIsNotNone(m, path.name)
            versions.append(int(m.group(1)))
        head = f"{max(versions):04d}"
        runbook = (ROOT / "docs/FACTORYOS_STAGED_PRODUCTION_DEPLOYMENT.md").read_text(encoding="utf8")
        checklist = (ROOT / "docs/PRODUCTION_GO_LIVE_CHECKLIST.md").read_text(encoding="utf8")
        self.assertIn(f"0001–{head}", runbook)
        self.assertIn(f"through `{head}`", checklist)
        self.assertIn("Supabase Production Plan", runbook)
        self.assertIn("Supabase Production Release", checklist)
        self.assertIn("backup", runbook.lower())
        self.assertIn("restore", checklist.lower())


if __name__ == "__main__":
    unittest.main()
