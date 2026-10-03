#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat <<'EOF'
usage: run-real-consumer-gates.sh <compiler> <debug|release> [repository-root]

Runs the v0.2 storage/interop external-consumer fixture plus the accepted
imagery-d and Dunia color-d consumer slices against the current color-d
checkout. Consumer repositories must already be checked out under
consumer-workspace/ at their pinned validated commits.
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]
then
    usage >&2
    exit 2
fi

compiler="$1"
build="$2"
root="${3:-.}"

case "$build" in
    debug|release)
        ;;
    *)
        echo "invalid consumer build: $build" >&2
        exit 2
        ;;
esac

root="$(cd "$root" && pwd)"
consumer_root="$root/consumer-workspace"

imagery="$consumer_root/imagery-d"
raster="$consumer_root/raster-d"
dunia="$consumer_root/dunia"

for path in "$imagery" "$raster" "$dunia"
do
    test -d "$path/.git" || {
        echo "missing pinned consumer checkout: $path" >&2
        exit 1
    }
done

ln -sfn "$root" "$consumer_root/color-d"

echo "color-d=$(git -C "$root" rev-parse HEAD)"
echo "imagery-d=$(git -C "$imagery" rev-parse HEAD)"
echo "raster-d=$(git -C "$raster" rev-parse HEAD)"
echo "dunia=$(git -C "$dunia" rev-parse HEAD)"

echo
echo "=== color-d v0.2 storage/interop external consumer ==="
(
    cd "$root/tests/consumer/v0_2_storage_interop"

    dub run \
        --compiler="$compiler" \
        --build="$build" \
        --force
)

echo
echo "=== imagery-d accepted consumer ==="
(
    cd "$imagery/experiments/m3_color_d_srgb_consumer"

    dub run \
        --compiler="$compiler" \
        --build="$build" \
        --force
)

echo
echo "=== Dunia accepted consumer ==="
(
    cd "$dunia"

    # Explicit debug test mode runs Dunia's own unittests while dependencies
    # remain normal external libraries instead of enabling provider unittests.
    dub test \
        --compiler="$compiler" \
        --build=debug \
        --force

    dub run \
        --compiler="$compiler" \
        --build="$build" \
        --force
)

echo
echo "real consumer gates: PASS"
