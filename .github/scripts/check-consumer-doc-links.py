#!/usr/bin/env python3
"""Check relative Markdown links in the exported color-d consumer package."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

LINK_RE = re.compile(r"!?(?:\[[^\]]*\])\(([^)]+)\)")


def strip_fenced_code(text: str) -> str:
    lines: list[str] = []
    in_fence = False

    for line in text.splitlines():
        stripped = line.lstrip()

        if stripped.startswith("```") or stripped.startswith("~~~"):
            in_fence = not in_fence
            continue

        if not in_fence:
            lines.append(line)

    return "\n".join(lines)


def destination(raw: str) -> str:
    raw = raw.strip()

    if raw.startswith("<") and ">" in raw:
        return raw[1 : raw.index(">")]

    # Markdown permits an optional title after whitespace. color-d consumer
    # docs do not use spaces in relative paths, so the first token is the path.
    return raw.split(maxsplit=1)[0]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-consumer-doc-links.py <consumer-package-root>", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()

    if not root.is_dir():
        print(f"consumer package root does not exist: {root}", file=sys.stderr)
        return 2

    markdown = [root / "README.md"]

    docs = root / "docs"
    if docs.is_dir():
        markdown.extend(sorted(docs.rglob("*.md")))

    failures: list[str] = []

    for document in markdown:
        if not document.is_file():
            failures.append(f"missing documentation file: {document.relative_to(root)}")
            continue

        text = strip_fenced_code(document.read_text(encoding="utf-8"))

        for match in LINK_RE.finditer(text):
            target = destination(match.group(1))

            if not target or target.startswith("#"):
                continue

            parsed = urlsplit(target)

            if parsed.scheme or parsed.netloc:
                continue

            path_text = unquote(parsed.path)

            if not path_text:
                continue

            resolved = (document.parent / path_text).resolve()

            try:
                resolved.relative_to(root)
            except ValueError:
                failures.append(
                    f"{document.relative_to(root)} -> {target} escapes consumer package"
                )
                continue

            if not resolved.exists():
                failures.append(
                    f"{document.relative_to(root)} -> {target} does not resolve"
                )

    if failures:
        print("consumer documentation link check: FAIL", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1

    print(f"consumer documentation link check: PASS ({len(markdown)} Markdown files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
