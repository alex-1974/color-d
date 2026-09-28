#!/usr/bin/env python3
"""Create or compare deterministic color-d research migration manifests."""

from __future__ import annotations

import argparse
import hashlib
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

DIRECTORIES = (
    Path("experiments"),
    Path("docs/research"),
    Path("docs/spec"),
)
FILES = (
    Path("docs/RESEARCH_DOCUMENTS.md"),
)


@dataclass(frozen=True, order=True)
class Entry:
    path: str
    size: int
    sha256: str


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def iter_selected(root: Path) -> Iterable[Path]:
    for directory in DIRECTORIES:
        base = root / directory
        if not base.exists():
            continue
        if not base.is_dir():
            raise ValueError(f"expected directory: {directory}")
        for path in base.rglob("*"):
            if path.is_symlink():
                raise ValueError(f"research migration does not accept symlinks: {path}")
            if path.is_file():
                yield path

    for relative in FILES:
        path = root / relative
        if path.exists():
            if path.is_symlink():
                raise ValueError(f"research migration does not accept symlinks: {path}")
            if not path.is_file():
                raise ValueError(f"expected file: {relative}")
            yield path


def manifest(root: Path) -> list[Entry]:
    root = root.resolve()
    entries: list[Entry] = []

    for path in iter_selected(root):
        relative = path.relative_to(root).as_posix()
        entries.append(
            Entry(
                relative,
                path.stat().st_size,
                sha256_file(path),
            )
        )

    entries.sort()
    return entries


def write_manifest(entries: list[Entry], stream) -> None:
    stream.write("path\tbytes\tsha256\n")
    for entry in entries:
        stream.write(f"{entry.path}\t{entry.size}\t{entry.sha256}\n")

    stream.write(
        f"# files={len(entries)} bytes={sum(entry.size for entry in entries)}\n"
    )


def print_summary(label: str, entries: list[Entry]) -> None:
    print(
        f"{label}: files={len(entries)} "
        f"bytes={sum(entry.size for entry in entries)}"
    )


def verify(source_root: Path, destination_root: Path) -> int:
    source = manifest(source_root)
    destination = manifest(destination_root)

    print_summary("source", source)
    print_summary("destination", destination)

    source_by_path = {entry.path: entry for entry in source}
    destination_by_path = {entry.path: entry for entry in destination}

    paths = sorted(set(source_by_path) | set(destination_by_path))
    failures = 0

    for path in paths:
        left = source_by_path.get(path)
        right = destination_by_path.get(path)

        if left is None:
            print(f"EXTRA destination file: {path}", file=sys.stderr)
            failures += 1
            continue

        if right is None:
            print(f"MISSING destination file: {path}", file=sys.stderr)
            failures += 1
            continue

        if left.size != right.size:
            print(
                f"SIZE mismatch: {path}: source={left.size} "
                f"destination={right.size}",
                file=sys.stderr,
            )
            failures += 1

        if left.sha256 != right.sha256:
            print(
                f"SHA256 mismatch: {path}: source={left.sha256} "
                f"destination={right.sha256}",
                file=sys.stderr,
            )
            failures += 1

    if failures:
        print(f"research migration verification: FAIL ({failures} mismatch(es))")
        return 1

    if not source:
        print("research migration verification: FAIL (empty source manifest)")
        return 1

    print("research migration verification: PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    manifest_parser = subparsers.add_parser(
        "manifest",
        help="write the selected research manifest",
    )
    manifest_parser.add_argument("--root", type=Path, default=Path("."))
    manifest_parser.add_argument(
        "--output",
        type=Path,
        help="write to this path instead of stdout",
    )

    verify_parser = subparsers.add_parser(
        "verify",
        help="compare source and destination research trees",
    )
    verify_parser.add_argument("--source-root", type=Path, required=True)
    verify_parser.add_argument("--destination-root", type=Path, required=True)

    args = parser.parse_args()

    try:
        if args.command == "manifest":
            entries = manifest(args.root)
            if not entries:
                print("research manifest is empty", file=sys.stderr)
                return 1

            if args.output:
                args.output.parent.mkdir(parents=True, exist_ok=True)
                with args.output.open("w", encoding="utf-8", newline="\n") as stream:
                    write_manifest(entries, stream)
            else:
                write_manifest(entries, sys.stdout)
            return 0

        if args.command == "verify":
            return verify(args.source_root, args.destination_root)

    except (OSError, ValueError) as error:
        print(f"research migration verification error: {error}", file=sys.stderr)
        return 2

    raise AssertionError("unreachable")


if __name__ == "__main__":
    raise SystemExit(main())
