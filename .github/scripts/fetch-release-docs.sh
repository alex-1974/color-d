#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat <<'EOF'
usage: fetch-release-docs.sh <owner/repository> <output-directory>

Downloads the DDox asset attached to every published non-prerelease semantic
release and extracts each site under output-directory/vX.Y.Z.
EOF
}

if [[ $# -ne 2 ]]
then
    usage >&2
    exit 2
fi

repo="$1"
output_dir="$2"

if [[ ! "$repo" =~ ^[^/]+/[^/]+$ ]]
then
    echo "Invalid repository name: $repo" >&2
    exit 2
fi

command -v gh >/dev/null || {
    echo "gh is required" >&2
    exit 1
}

if [[ -z "${GH_TOKEN:-}" ]]
then
    echo "GH_TOKEN is required" >&2
    exit 1
fi

rm -rf "$output_dir"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

mapfile -t tags < <(
    gh release list \
        --repo "$repo" \
        --limit 100 \
        --json tagName,isDraft,isPrerelease \
        --jq '.[] | select(.isDraft == false and .isPrerelease == false) | .tagName'
)

for tag in "${tags[@]}"
do
    if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
    then
        echo "Ignoring non-semantic published release tag: $tag" >&2
        continue
    fi

    version="${tag#v}"
    asset="color-d-$version.ddox.tar.gz"
    tmp="$(mktemp -d)"

    cleanup_tmp()
    {
        rm -rf "$tmp"
    }

    trap cleanup_tmp RETURN

    gh release download "$tag" \
        --repo "$repo" \
        --pattern "$asset" \
        --dir "$tmp"

    test -s "$tmp/$asset"

    mkdir -p "$output_dir/$tag"
    tar -xzf "$tmp/$asset" -C "$output_dir/$tag"

    if [[ ! -s "$output_dir/$tag/index.html" ]]
    then
        echo "Release DDox asset has no index.html: $tag" >&2
        exit 1
    fi

    rm -rf "$tmp"
    trap - RETURN

    echo "release docs fetched: $tag"
done

echo "release docs fetch: PASS"
echo "  repository=$repo"
echo "  output=$output_dir"
