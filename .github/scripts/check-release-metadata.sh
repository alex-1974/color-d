#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat <<'EOF'
usage: check-release-metadata.sh <X.Y.Z> <preflight|release> [repository-root]

Checks color-d release metadata without creating tags, releases, or published
documentation.
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]
then
    usage >&2
    exit 2
fi

version="$1"
mode="$2"
root="${3:-.}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
then
    echo "Invalid release version: $version" >&2
    exit 2
fi

case "$mode" in
    preflight|release)
        ;;
    *)
        echo "Invalid metadata mode: $mode" >&2
        usage >&2
        exit 2
        ;;
esac

root="$(cd "$root" && pwd)"

require_file()
{
    local path="$1"
    test -s "$root/$path" || {
        echo "Missing or empty release file: $path" >&2
        exit 1
    }
}

require_fixed()
{
    local text="$1"
    local path="$2"

    grep -Fq -- "$text" "$root/$path" || {
        echo "Missing release metadata in $path: $text" >&2
        exit 1
    }
}

require_file README.md
require_file ROADMAP.md
require_file CHANGELOG.md
require_file LICENSE
require_file dub.sdl

require_fixed 'name "color-d"' dub.sdl
require_fixed 'targetType "library"' dub.sdl
require_fixed 'homepage "https://alex-1974.github.io/color-d/"' dub.sdl
require_fixed 'authors "Alexander"' dub.sdl
require_fixed 'copyright "Copyright (c) 2026 Alexander"' dub.sdl
require_fixed 'license "MIT"' dub.sdl
require_fixed 'Copyright (c) 2026 Alexander' LICENSE
require_fixed 'Permission is hereby granted, free of charge' LICENSE
require_fixed '| DMD | 2.113.0 on Ubuntu 24.04 x86-64 |' README.md
require_fixed '| LDC | 1.43.0 on Ubuntu 24.04 x86-64 |' README.md
require_fixed "v$version — First public release" ROADMAP.md

case "$mode" in
    preflight)
        require_fixed '## Unreleased' CHANGELOG.md
        require_fixed "has not published v$version yet" README.md
        require_fixed "**Status: HARDENING — v$version FEATURE FREEZE.**" ROADMAP.md
        ;;

    release)
        escaped_version="${version//./\\.}"

        if ! grep -Eq "^## \\[$escaped_version\\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" "$root/CHANGELOG.md"
        then
            echo "CHANGELOG does not contain an exact versioned release heading for $version" >&2
            exit 1
        fi

        if grep -Fq -- "has not published v$version yet" "$root/README.md"
        then
            echo "README still describes v$version as unpublished" >&2
            exit 1
        fi

        require_fixed "dependency \"color-d\" version=\"~>$version\"" README.md
        require_fixed "**Status: COMPLETE — v$version RELEASED.**" ROADMAP.md
        ;;
esac

echo "release metadata check: PASS ($mode $version)"
