#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat <<'EOF'
usage: verify-release-tag.sh <vX.Y.Z> [expected-main-ref]

Verifies that the named release tag:
- uses the exact vX.Y.Z form;
- is an annotated tag object;
- resolves to exactly the expected main commit.

Signature presence is reported but is not a release requirement.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]
then
    usage >&2
    exit 2
fi

tag="$1"
expected_ref="${2:-origin/main}"

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
then
    echo "Invalid release tag: $tag" >&2
    exit 2
fi

git rev-parse --git-dir >/dev/null

tag_ref="refs/tags/$tag"

if ! git show-ref --verify --quiet "$tag_ref"
then
    echo "Release tag does not exist: $tag" >&2
    exit 1
fi

tag_type="$(git cat-file -t "$tag_ref")"

if [[ "$tag_type" != "tag" ]]
then
    echo "Release tag is not annotated: $tag (object type: $tag_type)" >&2
    exit 1
fi

tag_commit="$(git rev-parse "$tag_ref^{commit}")"
expected_commit="$(git rev-parse "$expected_ref^{commit}")"

if [[ "$tag_commit" != "$expected_commit" ]]
then
    echo "Release tag does not point to the expected main commit" >&2
    echo "  tag=$tag_commit" >&2
    echo "  expected=$expected_commit" >&2
    exit 1
fi

signature_present=no

if git cat-file -p "$tag_ref" |
    grep -Eq '^-----BEGIN (PGP|SSH) SIGNATURE-----$'
then
    signature_present=yes
fi

echo "release tag verification: PASS"
echo "  tag=$tag"
echo "  version=${tag#v}"
echo "  commit=$tag_commit"
echo "  expected_ref=$expected_ref"
echo "  signature_present=$signature_present"
