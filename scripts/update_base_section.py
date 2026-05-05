#!/usr/bin/env python3
"""Sync the TEAM-BASE block of a target AGENTS.md from a canonical base file.

Behaviour:
  - If the target file does not exist: write the full base file (with metadata
    injected) so the next sync can replace the TEAM-BASE block in place.
  - If the target file exists and contains TEAM-BASE markers: replace only the
    region between them, preserving everything outside.
  - If the target file exists but has no markers: exit 1 with a clear error so
    the caller (e.g. GitHub Actions) can warn and skip the repo.

Usage:
  update_base_section.py <target_path> <base_path> [--commit HASH]
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import date

START_MARKER = "<!-- TEAM-BASE-START -->"
END_MARKER = "<!-- TEAM-BASE-END -->"

LAST_SYNCED_RE = re.compile(r"<!-- Last synced: [^\n]* -->")

EXIT_OK = 0
EXIT_NO_MARKERS = 1
EXIT_IO_ERROR = 2
EXIT_BAD_BASE = 3


def extract_team_base(text: str) -> str:
    """Return the TEAM-BASE region (including both markers) from `text`."""
    start = text.find(START_MARKER)
    end = text.find(END_MARKER)
    if start == -1 or end == -1 or end < start:
        raise ValueError("TEAM-BASE markers not found or malformed")
    return text[start : end + len(END_MARKER)]


def inject_metadata(block: str, commit_hash: str) -> str:
    """Replace the `Last synced` metadata line in `block`."""
    today = date.today().isoformat()
    short_hash = (commit_hash[:7] or "unknown") if commit_hash else "unknown"
    replacement = f"<!-- Last synced: {today} (commit {short_hash}) -->"
    new_block, count = LAST_SYNCED_RE.subn(replacement, block, count=1)
    if count == 0:
        print(
            "warning: no `Last synced` metadata line in base content; "
            "synced file will lack a sync timestamp.",
            file=sys.stderr,
        )
    return new_block


def replace_team_base(target: str, new_block: str) -> str:
    """Replace the TEAM-BASE region in `target` with `new_block`."""
    start = target.find(START_MARKER)
    end = target.find(END_MARKER)
    if start == -1 or end == -1 or end < start:
        raise ValueError("TEAM-BASE markers not found in target")
    return target[:start] + new_block + target[end + len(END_MARKER) :]


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write_text(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="Path to the target AGENTS.md")
    parser.add_argument("base", help="Path to the canonical base/AGENTS.md")
    parser.add_argument(
        "--commit",
        default="",
        help="Source commit hash (truncated to 7 chars in metadata).",
    )
    args = parser.parse_args()

    try:
        base_full = read_text(args.base)
    except OSError as e:
        print(f"error: cannot read base file {args.base!r}: {e}", file=sys.stderr)
        return EXIT_IO_ERROR

    try:
        base_block = extract_team_base(base_full)
    except ValueError as e:
        print(f"error: base file {args.base!r}: {e}", file=sys.stderr)
        return EXIT_BAD_BASE

    new_block = inject_metadata(base_block, args.commit)
    base_full_synced = base_full.replace(base_block, new_block, 1)

    if not os.path.exists(args.target):
        # Case 1: target does not exist — write the full template.
        try:
            write_text(args.target, base_full_synced)
        except OSError as e:
            print(f"error: cannot write target {args.target!r}: {e}", file=sys.stderr)
            return EXIT_IO_ERROR
        print(f"created {args.target}")
        return EXIT_OK

    try:
        target_text = read_text(args.target)
    except OSError as e:
        print(f"error: cannot read target {args.target!r}: {e}", file=sys.stderr)
        return EXIT_IO_ERROR

    if START_MARKER not in target_text or END_MARKER not in target_text:
        # Case 3: target exists but has no markers — manual init required.
        print(
            f"error: {args.target!r} exists without TEAM-BASE markers; "
            "manual initialization required before sync.",
            file=sys.stderr,
        )
        return EXIT_NO_MARKERS

    # Case 2: target has markers — replace the region.
    try:
        updated = replace_team_base(target_text, new_block)
    except ValueError as e:
        print(f"error: target {args.target!r}: {e}", file=sys.stderr)
        return EXIT_NO_MARKERS

    if updated == target_text:
        print(f"unchanged {args.target}")
        return EXIT_OK

    try:
        write_text(args.target, updated)
    except OSError as e:
        print(f"error: cannot write target {args.target!r}: {e}", file=sys.stderr)
        return EXIT_IO_ERROR

    print(f"updated {args.target}")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
