#!/usr/bin/env python3
"""Fail-closed, no-secret validation for FactoryOS scheduled FCM dispatch results.

Exit 0: worker responded coherently and reported no failed delivery rows.
Exit 2: missing/malformed response, claim mismatch or failed delivery rows.
Only counts are printed; response bodies, tokens, and message contents are never logged.
"""

import argparse
import json
import os
import sys
from pathlib import Path

COUNT_FIELDS = ("claimed", "processed", "sent", "failed", "skipped")
MAX_BATCH = 20  # notification_claim_push_deliveries clamps p_batch_size to 20.


class DispatchResultError(ValueError):
    pass


def validate_dispatch_result(payload: object) -> tuple[int, int, int]:
    """Return (processed, sent, skipped); raise for any unverified/failing run."""
    if not isinstance(payload, dict):
        raise DispatchResultError("Worker response is not a JSON object.")
    counts: dict[str, int] = {}
    for key in COUNT_FIELDS:
        value = payload.get(key)
        if type(value) is not int or not 0 <= value <= MAX_BATCH:
            raise DispatchResultError(f"Worker response has invalid '{key}' count.")
        counts[key] = value

    if counts["claimed"] != counts["processed"]:
        raise DispatchResultError("Some claimed queue rows were not processed.")
    if counts["processed"] != counts["sent"] + counts["failed"] + counts["skipped"]:
        raise DispatchResultError("Worker delivery accounting does not balance.")
    if counts["failed"] > 0:
        raise DispatchResultError(
            f"FCM dispatch reported {counts['failed']} failed delivery row(s)."
        )
    return counts["processed"], counts["sent"], counts["skipped"]


def parse_result_file(path: Path) -> object:
    try:
        if path.stat().st_size > 65536:
            raise DispatchResultError("Worker response exceeds size limit.")
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    except (OSError, UnicodeError, json.JSONDecodeError):
        # Never print raw body or an exception containing sensitive material.
        raise DispatchResultError("Worker response could not be parsed.") from None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args()
    try:
        processed, sent, skipped = validate_dispatch_result(
            parse_result_file(args.input)
        )
    except DispatchResultError as exc:
        print(f"BLOCKED: FactoryOS FCM dispatch: {exc}", file=sys.stderr)
        summary = "FactoryOS push dispatch: **FAILED**; inspect scoped worker logs."
        status = 2
    else:
        print(
            "PASS: FactoryOS FCM push batch accounted for "
            f"({processed} processed, {sent} accepted, {skipped} skipped); "
            "provider acceptance does not prove handset delivery."
        )
        summary = (
            "FactoryOS FCM push batch: "
            f"**{processed} processed**, **{sent} provider-accepted**, "
            f"**{skipped} skipped** (no active device); "
            "no failed delivery rows reported. Not proof of handset delivery."
        )
        status = 0
    output = os.environ.get("GITHUB_STEP_SUMMARY")
    if output:
        try:
            with open(output, "a", encoding="utf-8") as f:
                f.write(f"\n{summary}\n")
        except OSError:
            # Summaries are secondary to the actual validation result.
            pass
    return status


if __name__ == "__main__":
    raise SystemExit(main())
