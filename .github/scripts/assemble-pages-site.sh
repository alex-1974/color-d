#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat <<'EOF'
usage: assemble-pages-site.sh <dev-docs-dir> <release-docs-root> <output-dir> <pre-release-index>

Assembles the color-d Pages trust layout without publishing it:

  /              latest stable docs, or pre-release landing page
  /dev/          current develop/unreleased docs
  /vX.Y.Z/       immutable versioned release docs

release-docs-root contains zero or more directories named exactly vX.Y.Z.
EOF
}

if [[ $# -ne 4 ]]
then
    usage >&2
    exit 2
fi

dev_docs="$1"
release_root="$2"
output_dir="$3"
pre_release_index="$4"

for path in "$dev_docs" "$release_root"
do
    if [[ ! -d "$path" ]]
    then
        echo "Required documentation directory missing: $path" >&2
        exit 1
    fi
done

if [[ ! -f "$dev_docs/index.html" ]]
then
    echo "Development documentation has no index.html" >&2
    exit 1
fi

if [[ ! -f "$pre_release_index" ]]
then
    echo "Pre-release landing page missing: $pre_release_index" >&2
    exit 1
fi

dev_docs="$(cd "$dev_docs" && pwd)"
release_root="$(cd "$release_root" && pwd)"
pre_release_index="$(cd "$(dirname "$pre_release_index")" && pwd)/$(basename "$pre_release_index")"

rm -rf "$output_dir"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

versions=()

shopt -s nullglob
for path in "$release_root"/v*
do
    name="$(basename "$path")"

    if [[ ! -d "$path" ]]
    then
        echo "Release-doc entry is not a directory: $name" >&2
        exit 1
    fi

    if [[ ! "$name" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
    then
        echo "Invalid release-doc directory name: $name" >&2
        exit 1
    fi

    if [[ ! -f "$path/index.html" ]]
    then
        echo "Release documentation has no index.html: $name" >&2
        exit 1
    fi

    versions+=("$name")
done
shopt -u nullglob

if [[ ${#versions[@]} -eq 0 ]]
then
    cp "$pre_release_index" "$output_dir/index.html"
else
    latest="$(
        printf '%s\n' "${versions[@]}" |
            sort -V |
            tail -n 1
    )"

    cp -a "$release_root/$latest/." "$output_dir/"

    for version in "${versions[@]}"
    do
        mkdir -p "$output_dir/$version"
        cp -a "$release_root/$version/." "$output_dir/$version/"
    done
fi

mkdir -p "$output_dir/dev"
cp -a "$dev_docs/." "$output_dir/dev/"

touch "$output_dir/.nojekyll"

test -f "$output_dir/index.html"
test -f "$output_dir/dev/index.html"

for version in "${versions[@]}"
do
    test -f "$output_dir/$version/index.html"
done

echo "pages site assembly: PASS"

if [[ ${#versions[@]} -eq 0 ]]
then
    echo "  stable=none (pre-release landing page)"
else
    echo "  stable=$latest"
    printf '  version=%s\n' "${versions[@]}" | sort -V
fi

echo "  dev=$dev_docs"
echo "  output=$output_dir"
