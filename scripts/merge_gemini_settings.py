#!/usr/bin/env python3
"""Merge or create .gemini/settings.json with required context.fileName entries.

Ensures that `context.fileName` contains every entry from the base file's
`context.fileName` list (typically `AGENTS.md` and `GEMINI.md`) while
preserving any pre-existing entries and any other top-level settings the
target repo has configured.

Usage:
    merge_gemini_settings.py <target_path> <base_path>
"""

from __future__ import annotations

import json
import os
import sys


def merge_filenames(existing: list, required: list) -> list:
    """Append required entries to `existing` (preserving order, no duplicates)."""
    result = list(existing)
    for name in required:
        if name not in result:
            result.append(name)
    return result


def load_json(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: str, data: dict) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <target_path> <base_path>", file=sys.stderr)
        return 2

    target_path, base_path = sys.argv[1], sys.argv[2]

    try:
        base = load_json(base_path)
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: cannot load base {base_path!r}: {e}", file=sys.stderr)
        return 1

    required = base.get("context", {}).get("fileName", [])
    if not isinstance(required, list):
        print(
            f"error: base {base_path!r} has non-list context.fileName",
            file=sys.stderr,
        )
        return 1

    if not os.path.exists(target_path):
        write_json(target_path, base)
        print(f"created {target_path}")
        return 0

    try:
        target = load_json(target_path)
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: cannot load target {target_path!r}: {e}", file=sys.stderr)
        return 1

    if not isinstance(target, dict):
        print(
            f"error: target {target_path!r} is not a JSON object",
            file=sys.stderr,
        )
        return 1

    ctx = target.get("context") or {}
    if not isinstance(ctx, dict):
        ctx = {}
    existing = ctx.get("fileName") or []
    if not isinstance(existing, list):
        existing = []

    merged = merge_filenames(existing, required)
    if merged == existing and "context" in target and target["context"].get("fileName") == existing:
        print(f"unchanged {target_path}")
        return 0

    ctx["fileName"] = merged
    target["context"] = ctx
    write_json(target_path, target)
    print(f"updated {target_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
