#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat <<'EOF'
usage: assemble-release-archive.sh <X.Y.Z> <output-directory> [git-ref]

Creates a deterministic gzip-compressed consumer archive, a metadata record,
and SHA-256 checksums. It does not create or publish a Git tag or GitHub
Release.
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]
then
    usage >&2
    exit 2
fi

version="$1"
output_dir="$2"
git_ref="${3:-HEAD}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
then
    echo "Invalid release version: $version" >&2
    exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
commit="$(git -C "$repo_root" rev-parse "$git_ref^{commit}")"

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

archive_name="color-d-$version.tar.gz"
metadata_name="color-d-$version.metadata.txt"
archive_path="$output_dir/$archive_name"
metadata_path="$output_dir/$metadata_name"
checksums_path="$output_dir/SHA256SUMS"
prefix="color-d-$version/"

git -C "$repo_root" archive \
    --format=tar \
    --prefix="$prefix" \
    "$git_ref" |
    gzip -n > "$archive_path"

list_file="$(mktemp)"
trap 'rm -f "$list_file"' EXIT

tar -tzf "$archive_path" > "$list_file"

require_member()
{
    local path="$1"

    grep -Fxq -- "$prefix$path" "$list_file" || {
        echo "Release archive missing required member: $path" >&2
        exit 1
    }
}

reject_prefix()
{
    local path="$1"
    local member

    while IFS= read -r member
    do
        case "$member" in
            "$prefix$path"|"$prefix$path/"*)
                echo "Release archive unexpectedly contains: $path" >&2
                exit 1
                ;;
        esac
    done < "$list_file"
}

require_member README.md
require_member LICENSE
require_member CHANGELOG.md
require_member dub.sdl
require_member source/color/package.d
require_member docs/README.md

reject_prefix .gitattributes
reject_prefix .gitignore
reject_prefix .github
reject_prefix AGENTS.md
reject_prefix CONTRIBUTING.md
reject_prefix DESIGN_PRINCIPLES.md
reject_prefix ROADMAP.md
reject_prefix RESEARCH.md
reject_prefix dscanner.ini
reject_prefix docs/RESEARCH_DOCUMENTS.md
reject_prefix docs/adr
reject_prefix docs/pages-publication.md
reject_prefix docs/research
reject_prefix docs/spec
reject_prefix experiments
reject_prefix tests

archive_sha="$(sha256sum "$archive_path" | awk '{print $1}')"

cat > "$metadata_path" <<EOF
package=color-d
version=$version
commit=$commit
archive=$archive_name
archive_sha256=$archive_sha
EOF

(
    cd "$output_dir"
    sha256sum "$archive_name" "$metadata_name" > SHA256SUMS
    sha256sum -c SHA256SUMS
)

echo "release archive assembly: PASS"
echo "  version=$version"
echo "  commit=$commit"
echo "  archive=$archive_path"
echo "  checksums=$checksums_path"
