#!/usr/bin/env python3
"""Fail-fast validation for committed FactoryOS Supabase migration filenames.

Use the same version rules as the guarded production release preflight. Runs
before starting local Supabase or writing to any remote database.
"""
import sys
from pathlib import Path

from verify_production_migrations import HistoryError, local_versions


def main() -> int:
    directory = Path("supabase/migrations")
    try:
        versions = local_versions(directory)
        print(f"PASS: {len(versions)} unique FactoryOS migration versions.")
    except HistoryError as error:
        print(f"BLOCKED: unsafe FactoryOS migration history: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
