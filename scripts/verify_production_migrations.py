#!/usr/bin/env python3
"""Read-only, fail-closed local vs linked Supabase migration-history comparison.

Never authenticates, changes a database, or prints secrets. The caller supplies
the output of `supabase migration list --linked`.
"""

import argparse
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
FILENAME = re.compile(r"^(\d+)_[A-Za-z0-9][A-Za-z0-9_-]*\.sql$")


class HistoryError(ValueError):
    pass


def local_versions(directory: Path) -> set[str]:
    if not directory.is_dir():
        raise HistoryError("Migration directory is missing.")
    versions: set[str] = set()
    for path in sorted(directory.glob("*.sql")):
        match = FILENAME.fullmatch(path.name)
        if match is None:
            raise HistoryError(f"Invalid migration filename: {path.name}")
        version = match.group(1)
        if version in versions:
            raise HistoryError(f"Duplicate migration version: {version}")
        versions.add(version)
    if not versions:
        raise HistoryError("No committed migration files found.")
    return versions


def cli_versions(output: str) -> tuple[set[str], set[str]]:
    """Parse the two data columns from the documented Supabase CLI table.

    Supports both Unicode box separators (│) and ASCII '|'; tolerates the CLI
    warning/banner lines, leading color escapes and an optional UTC time field.
    """
    local: set[str] = set()
    remote: set[str] = set()
    data_rows = 0
    for raw in ANSI.sub("", output).splitlines():
        if "│" not in raw and "|" not in raw:
            continue
        parts = re.split(r"[│|]", raw, maxsplit=2)
        if len(parts) < 3:
            continue
        left = parts[0].strip()
        right = parts[1].strip()
        if not left and not right:
            continue
        if left.upper() == "LOCAL" and right.upper() == "REMOTE":
            continue
        if set(left + right).issubset(set("─-+ =")):
            continue
        if not ((left.isdigit() or not left) and (right.isdigit() or not right)):
            raise HistoryError("Malformed local/remote migration row.")
        if not left and not right:
            continue
        if left:
            if left in local:
                raise HistoryError(f"Duplicate local CLI version: {left}")
            local.add(left)
        if right:
            if right in remote:
                raise HistoryError(f"Duplicate remote CLI version: {right}")
            remote.add(right)
        data_rows += 1
    if data_rows == 0:
        raise HistoryError("No migration status rows found in Supabase CLI output.")
    return local, remote


def verify_history(committed: set[str], cli_local: set[str],
                   cli_remote: set[str], stage: str) -> str:
    if cli_local != committed:
        missing = sorted(committed - cli_local)
        extra = sorted(cli_local - committed)
        raise HistoryError(
            f"CLI local migration history differs from committed files "
            f"(missing={missing}, unexpected={extra})."
        )
    unknown_remote = cli_remote - committed
    if unknown_remote:
        raise HistoryError(
            f"Unexpected remote migrations: {sorted(unknown_remote)}. "
            "Stop and investigate; never auto-repair production history."
        )
    pending = sorted(committed - cli_remote)
    if stage == "postdeploy" and pending:
        raise HistoryError(
            f"Deployment incomplete: {len(pending)} committed migrations "
            f"remain absent remotely: {pending}."
        )
    if stage not in {"preflight", "postdeploy"}:
        raise HistoryError("Unknown verification stage.")
    return (
        f"PASS: migration {stage}: {len(committed)} committed, "
        f"{len(cli_remote)} remote applied, {len(pending)} pending."
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--stage", choices=("preflight", "postdeploy"), required=True)
    p.add_argument("--migrations-dir", type=Path, default=Path("supabase/migrations"))
    p.add_argument("--input", type=Path, required=True)
    args = p.parse_args()
    try:
        committed = local_versions(args.migrations_dir)
        cli_local, cli_remote = cli_versions(args.input.read_text(encoding="utf-8"))
        print(verify_history(committed, cli_local, cli_remote, args.stage))
    except (OSError, HistoryError) as exc:
        print(f"BLOCKED: migration history verification: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
