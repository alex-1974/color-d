#!/usr/bin/env python3
"""Validate stable invariants of a generated DDox site."""

from __future__ import annotations

import argparse
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

PUBLIC_MODULES = (
    "color.html",
    "color/alpha.html",
    "color/composite.html",
    "color/difference.html",
    "color/gamut.html",
    "color/interpolate.html",
    "color/oklab.html",
    "color/oklch.html",
    "color/rgb.html",
    "color/tone.html",
    "color/wcag.html",
    "color/xyz.html",
)


class LinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "a":
            return
        for name, value in attrs:
            if name == "href" and value:
                self.links.append(value)


def local_target(page: Path, site: Path, href: str) -> Path | None:
    parsed = urlsplit(href)
    if parsed.scheme or parsed.netloc or href.startswith(("#", "mailto:", "javascript:")):
        return None

    raw_path = unquote(parsed.path)
    if not raw_path:
        return None

    if raw_path.startswith("/"):
        target = site / raw_path.lstrip("/")
    else:
        target = page.parent / raw_path

    if raw_path.endswith("/"):
        target /= "index.html"

    return target.resolve()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("site", type=Path)
    args = parser.parse_args()

    site = args.site.resolve()
    failures: list[str] = []

    if not (site / "index.html").is_file():
        failures.append("missing site index.html")

    for module in PUBLIC_MODULES:
        if not (site / module).is_file():
            failures.append(f"missing public module page: {module}")

    html_pages = sorted(site.rglob("*.html"))
    if not html_pages:
        failures.append("site contains no HTML pages")

    for page in html_pages:
        parser_ = LinkParser()
        parser_.feed(page.read_text(encoding="utf-8"))

        for href in parser_.links:
            target = local_target(page, site, href)
            if target is None:
                continue

            try:
                target.relative_to(site)
            except ValueError:
                failures.append(f"{page.relative_to(site)}: link escapes site: {href}")
                continue

            if not target.exists():
                failures.append(f"{page.relative_to(site)}: broken local link: {href}")

    if failures:
        print("DDox rendered-site validation: FAIL")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("DDox rendered-site validation: PASS")
    print(f"  html_pages={len(html_pages)}")
    print(f"  public_module_pages={len(PUBLIC_MODULES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
