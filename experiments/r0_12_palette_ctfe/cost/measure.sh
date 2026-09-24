#!/usr/bin/env bash

export LC_ALL=C

ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)"

MEASUREMENTS="$ROOT/cost/measurements.tsv"

printf 'compiler\tprobe\trun\twall_seconds\tmax_rss_kib\n' \
  > "$MEASUREMENTS"

failures=0

compile_once()
{
    compiler="$1"
    probe="$2"
    run="$3"
    record="$4"

    case "$probe" in
        baseline)
            source_file="cost/probe_baseline.d"
            ;;
        15|60|240)
            source_file="cost/probe_${probe}.d"
            ;;
        *)
            echo "Unknown probe: $probe"
            failures=$((failures + 1))
            return 2
            ;;
    esac

    object="/tmp/color_d_r012d_${compiler}_${probe}.o"
    timing="/tmp/color_d_r012d_${compiler}_${probe}.time"

    rm -f "$object" "$timing"

    (
        cd "$ROOT"

        /usr/bin/time \
          -f '%e	%M' \
          -o "$timing" \
          "$compiler" \
            -c \
            -I../r0_8_gamut_semantics/fixture \
            -Icost \
            cost/probe_common.d \
            "$source_file" \
            -of="$object"
    )

    status=$?

    if [ "$status" -ne 0 ]; then
        echo "FAIL: ${compiler} ${probe} run ${run}, exit ${status}"
        failures=$((failures + 1))
        return "$status"
    fi

    if [ "$record" = "yes" ]; then
        read wall rss < "$timing"

        printf '%s\t%s\t%s\t%s\t%s\n' \
          "$compiler" \
          "$probe" \
          "$run" \
          "$wall" \
          "$rss" \
          >> "$MEASUREMENTS"

        printf '%-4s %-8s run %s  wall=%ss  rss=%s KiB\n' \
          "$compiler" \
          "$probe" \
          "$run" \
          "$wall" \
          "$rss"
    fi

    return 0
}

echo '=== R0.12-D COMPILERS ==='
dmd --version | head -n 2
echo
ldc2 --version | head -n 4

echo
echo '=== WARM-UP ==='

for compiler in dmd ldc2
do
    for probe in baseline 15 60 240
    do
        echo "warm-up: ${compiler} ${probe}"
        compile_once "$compiler" "$probe" 0 no
    done
done

echo
echo '=== FIVE INTERLEAVED MEASUREMENT ROUNDS ==='

for run in 1 2 3 4 5
do
    echo
    echo "--- round ${run} ---"

    for compiler in dmd ldc2
    do
        for probe in baseline 15 60 240
        do
            compile_once "$compiler" "$probe" "$run" yes
        done
    done
done

echo
echo '=== RAW MEASUREMENTS ==='
cat "$MEASUREMENTS"

echo
echo '=== MEDIANS AND SCALING ==='
python3 - "$MEASUREMENTS" <<'PY'
from pathlib import Path
from statistics import median
import csv
import sys

p = Path(sys.argv[1])

rows = list(
    csv.DictReader(
        p.open(),
        delimiter="\t"
    )
)

order = ["baseline", "15", "60", "240"]

for compiler in ["dmd", "ldc2"]:
    print()
    print(f"=== {compiler} ===")

    stats = {}

    for probe in order:
        selected = [
            r for r in rows
            if r["compiler"] == compiler
            and r["probe"] == probe
        ]

        walls = [
            float(r["wall_seconds"])
            for r in selected
        ]

        rss = [
            int(r["max_rss_kib"])
            for r in selected
        ]

        stats[probe] = {
            "wall": median(walls),
            "wall_min": min(walls),
            "wall_max": max(walls),
            "rss": median(rss),
            "rss_min": min(rss),
            "rss_max": max(rss),
        }

    baseline_wall = stats["baseline"]["wall"]
    baseline_rss = stats["baseline"]["rss"]

    print(
        "probe      wall_med_s    wall_range"
        "       extra_s   rss_med_KiB"
        "       rss_range   extra_rss_KiB"
    )

    for probe in order:
        st = stats[probe]

        extra_wall = (
            st["wall"] - baseline_wall
        )

        extra_rss = (
            st["rss"] - baseline_rss
        )

        print(
            f"{probe:8s}"
            f"  {st['wall']:10.3f}"
            f"  {st['wall_min']:.3f}-{st['wall_max']:.3f}"
            f"  {extra_wall:10.3f}"
            f"  {st['rss']:11.0f}"
            f"  {st['rss_min']}-{st['rss_max']}"
            f"  {extra_rss:13.0f}"
        )
PY

echo
echo '=== SAMPLE COUNT ==='
wc -l "$MEASUREMENTS"

echo
echo '=== FAILURES ==='
echo "$failures"
