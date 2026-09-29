#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat <<'EOF'
usage: assemble-ddox-archive.sh <X.Y.Z> <ddox-directory> <output-directory>

Creates a deterministic gzip-compressed DDox asset for one released version.
The archive contains the DDox site at its root so it can be extracted directly
into a /vX.Y.Z/ documentation directory.
EOF
}

if [[ $# -ne 3 ]]
then
    usage >&2
    exit 2
fi

version="$1"
docs_dir="$2"
output_dir="$3"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
then
    echo "Invalid release version: $version" >&2
    exit 2
fi

if [[ ! -d "$docs_dir" || ! -s "$docs_dir/index.html" ]]
then
    echo "DDox directory has no index.html: $docs_dir" >&2
    exit 1
fi

docs_dir="$(cd "$docs_dir" && pwd)"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

archive="$output_dir/color-d-$version.ddox.tar.gz"

tar \
    --sort=name \
    --mtime='UTC 1970-01-01' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -C "$docs_dir" \
    -cf - \
    . |
    gzip -n > "$archive"

verify_dir="$(mktemp -d)"
trap 'rm -rf "$verify_dir"' EXIT

tar -xzf "$archive" -C "$verify_dir"
test -s "$verify_dir/index.html"

echo "DDox archive assembly: PASS"
echo "  version=$version"
echo "  archive=$archive"
