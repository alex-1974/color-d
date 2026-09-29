#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


if len(sys.argv) != 4:
    fail(
        "usage: extract-release-notes.py "
        "<CHANGELOG.md> <X.Y.Z> <output-file>"
    )

changelog_path = Path(sys.argv[1])
version = sys.argv[2]
output_path = Path(sys.argv[3])

if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    fail(f"invalid release version: {version}")

lines = changelog_path.read_text(encoding="utf-8").splitlines()
heading = re.compile(
    rf"^## \[{re.escape(version)}\] - \d{{4}}-\d{{2}}-\d{{2}}$"
)

start: int | None = None
end = len(lines)

for index, line in enumerate(lines):
    if start is None:
        if heading.fullmatch(line):
            start = index + 1
        continue

    if line.startswith("## ") or re.match(r"^\[[^]]+\]:\s", line):
        end = index
        break

if start is None:
    fail(f"CHANGELOG has no exact release heading for {version}")

body = "\n".join(lines[start:end]).strip()

if not body:
    fail(f"CHANGELOG release section is empty for {version}")

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(body + "\n", encoding="utf-8")

print(f"release notes extraction: PASS ({version})")
