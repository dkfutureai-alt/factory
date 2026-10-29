#!/usr/bin/env python3
"""Reject tracked private FactoryOS backup artifacts before they reach CI/releases.

Only checks *tracked filenames*. This is defense in depth, NOT a secret scanner
or a completed disaster-recovery exercise. Backup data belongs in a private,
encrypted offsite vault, never in the source repository.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import PurePosixPath

PRIVATE_DIRECTORIES = frozenset({
    "backups", "private-backups", ".factoryos-private-backups",
    "database-backups", "db-backups", ".recovery",
})
PRIVATE_EXPORT_NAMES = frozenset({
    "roles.sql", "schema.sql", "data.sql", "history_schema.sql",
    "history_data.sql", "auth.sql", "storage.sql", "backup.sql",
    "database.sql", "production.sql", "production-db.sql",
})
PRIVATE_SUFFIXES = (
    ".dump", ".backup", ".pgdump", ".sql.gz", ".sql.zst", ".sql.age",
    ".sql.gpg", ".tar.gpg", ".tar.age", ".db.gz", ".db.age",
)


def is_private_export(path: str) -> bool:
    """Classify likely private snapshots; do not block ordinary migrations."""
    if not isinstance(path, str) or not path or "\x00" in path:
        return True
    posix = path.replace("\\", "/").lstrip("./")
    components = PurePosixPath(posix).parts
    if not components or ".." in components:
        return True
    lowered = tuple(x.casefold() for x in components)
    if any(x in PRIVATE_DIRECTORIES or x.startswith("factoryos-recovery-")
           for x in lowered[:-1]):
        return True
    name = lowered[-1]
    return (name in PRIVATE_EXPORT_NAMES
            or name.endswith(PRIVATE_SUFFIXES)
            or name.startswith(("factoryos-production-backup-", "factoryos-production-dump-")))


def find_private_exports(paths: list[str]) -> list[str]:
    return sorted({name for name in paths if is_private_export(name)})


def main() -> int:
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z"], check=True, capture_output=True,
            timeout=15,
        )
        tracked = [p.decode("utf-8", errors="replace")
                   for p in result.stdout.split(b"\x00") if p]
    except (OSError, subprocess.TimeoutExpired, subprocess.CalledProcessError):
        print("BLOCKED: could not safely inspect the repository index.", file=sys.stderr)
        return 2
    found = find_private_exports(tracked)
    if found:
        # Filenames only; never read or print private contents.
        print("BLOCKED: potential private database export tracked in Git:", file=sys.stderr)
        for name in found:
            print(f"  {name}", file=sys.stderr)
        return 2
    print("PASS: no tracked filenames matching known private backup patterns.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
