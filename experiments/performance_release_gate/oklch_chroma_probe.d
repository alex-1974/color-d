// Release-performance audit for the Oklab -> OKLCH chroma hardening.
//
// Compares current public production against the former direct
// sqrt(a*a + b*b) implementation on an ordinary deterministic corpus.
// Dataset generation and validation happen outside timed regions.

module oklch_chroma_probe;

import color.oklab :
    Oklab;
import color.oklch :
    OklabHue,
    Oklch,
    toOklch;

import std.conv : bitCast;
import std.datetime.stopwatch : StopWatch;
import std.math :
    PI,
    atan2,
    sqrt;
import std.stdio :
    writefln,
    writeln;


private struct Lcg
{
    ulong state;

    ulong next()
    {
        state =
            state * 6364136223846793005UL +
            1442695040888963407UL;

        return state;
    }

    double unit()
    {
        return
            cast(double)(next() >> 11) *
            (1.0 / 9007199254740992.0);
    }
}


private T normalizePositiveDegrees(T)(T degrees)
{
    T result =
        degrees %
        cast(T)360;

    if (result < cast(T)0)
        result += cast(T)360;

    if (result >= cast(T)360)
        result -= cast(T)360;

    if (result == cast(T)0)
        return cast(T)0;

    return result;
}


private Oklch!T formerToOklch(T)(
    Oklab!T color
)
{
    const T chroma =
        cast(T)sqrt(
            color.a * color.a +
            color.b * color.b
        );

    if (
        color.a == cast(T)0 &&
        color.b == cast(T)0
    )
    {
        return Oklch!T(
            color.l,
            cast(T)0,
            OklabHue!T.fromDegrees(
                cast(T)0
            )
        );
    }

    const T radians =
        cast(T)atan2(
            color.b,
            color.a
        );

    const T rawDegrees =
        radians *
        cast(T)(180.0L / PI);

    return Oklch!T(
        color.l,
        chroma,
        OklabHue!T.fromDegrees(
            normalizePositiveDegrees(
                rawDegrees
            )
        )
    );
}


private bool finite(T)(T value)
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}


private ulong componentBits(T)(T value)
{
    static if (is(T == float))
        return cast(ulong)bitCast!uint(value);
    else
        return bitCast!ulong(value);
}


private void hashComponent(T)(
    ref ulong hash,
    T value
)
{
    hash ^=
        componentBits(value);

    hash *=
        1099511628211UL;
}


private void hashColor(T)(
    ref ulong hash,
    Oklch!T value
)
{
    hashComponent(hash, value.l);
    hashComponent(hash, value.c);
    hashComponent(
        hash,
        value.h.rawDegrees
    );
}


enum sampleCount =
    262_144;

enum rounds =
    7;


private Oklab!T[] makeOrdinaryCorpus(T)()
{
    auto values =
        new Oklab!T[sampleCount];

    Lcg rng =
        Lcg(
            is(T == double)
                ? 0xC010_D005_2026_0093UL
                : 0xC010_F005_2026_0093UL
        );

    foreach (i; 0 .. values.length)
    {
        const T l =
            cast(T)(
                rng.unit() * 1.20 -
                0.10
            );

        T a =
            cast(T)(
                rng.unit() * 0.80 -
                0.40
            );

        T b =
            cast(T)(
                rng.unit() * 0.80 -
                0.40
            );

        if (
            a == cast(T)0 &&
            b == cast(T)0
        )
        {
            a =
                cast(T)0.125;
        }

        values[i] =
            Oklab!T(
                l,
                a,
                b
            );
    }

    return values;
}


private bool validateOrdinary(T)(
    const(Oklab!T)[] values
)
{
    size_t mismatches = 0;

    ulong productionHash =
        1469598103934665603UL;

    ulong formerHash =
        1469598103934665603UL;

    foreach (value; values)
    {
        const production =
            value.toOklch;

        const former =
            formerToOklch(value);

        hashColor(
            productionHash,
            production
        );

        hashColor(
            formerHash,
            former
        );

        if (
            componentBits(production.l) !=
                componentBits(former.l) ||
            componentBits(production.c) !=
                componentBits(former.c) ||
            componentBits(
                production.h.rawDegrees
            ) !=
                componentBits(
                    former.h.rawDegrees
                )
        )
        {
            ++mismatches;
        }
    }

    writefln(
        "%s ordinary validation: samples=%s mismatches=%s production_hash=%016x former_hash=%016x",
        is(T == double)
            ? "double"
            : "float",
        values.length,
        mismatches,
        productionHash,
        formerHash
    );

    return
        mismatches == 0;
}


private bool validateExtreme(T)()
{
    const T halfMax =
        T.max /
        cast(T)2;

    Oklab!T nearMax =
        Oklab!T(
            cast(T)0.5,
            halfMax,
            halfMax
        );

    Oklab!T minNormal =
        Oklab!T(
            cast(T)0.5,
            T.min_normal,
            cast(T)0
        );

    const productionMax =
        nearMax.toOklch;

    const formerMax =
        formerToOklch(
            nearMax
        );

    const productionMin =
        minNormal.toOklch;

    const formerMin =
        formerToOklch(
            minNormal
        );

    writefln(
        "%s extreme validation: production_max=% .21g former_max=% .21g production_min=% .21g former_min=% .21g",
        is(T == double)
            ? "double"
            : "float",
        cast(real)productionMax.c,
        cast(real)formerMax.c,
        cast(real)productionMin.c,
        cast(real)formerMin.c
    );

    return
        finite(productionMax.c) &&
        productionMax.c > halfMax &&
        productionMin.c ==
            T.min_normal;
}


private double timeProduction(T)(
    const(Oklab!T)[] values,
    uint iterations,
    ref double sink
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. iterations)
    foreach (value; values)
    {
        const result =
            value.toOklch;

        sink +=
            cast(double)result.c +
            cast(double)result.h.rawDegrees *
                0.0001;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(
            values.length *
            iterations
        );
}


private double timeFormer(T)(
    const(Oklab!T)[] values,
    uint iterations,
    ref double sink
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. iterations)
    foreach (value; values)
    {
        const result =
            formerToOklch(value);

        sink +=
            cast(double)result.c +
            cast(double)result.h.rawDegrees *
                0.0001;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(
            values.length *
            iterations
        );
}


private double median(
    double[rounds] values
)
{
    foreach (i; 1 .. values.length)
    {
        const double key =
            values[i];

        size_t j = i;

        while (
            j > 0 &&
            values[j - 1] > key
        )
        {
            values[j] =
                values[j - 1];

            --j;
        }

        values[j] =
            key;
    }

    return
        values[
            values.length / 2
        ];
}


private void benchmark(T)(
    const(Oklab!T)[] values
)
{
    double[rounds] productionNs;
    double[rounds] formerNs;

    double sink = 0;

    enum uint iterations =
        4;

    foreach (round; 0 .. rounds)
    {
        if ((round & 1) == 0)
        {
            productionNs[round] =
                timeProduction(
                    values,
                    iterations,
                    sink
                );

            formerNs[round] =
                timeFormer(
                    values,
                    iterations,
                    sink
                );
        }
        else
        {
            formerNs[round] =
                timeFormer(
                    values,
                    iterations,
                    sink
                );

            productionNs[round] =
                timeProduction(
                    values,
                    iterations,
                    sink
                );
        }
    }

    const double productionMedian =
        median(productionNs);

    const double formerMedian =
        median(formerNs);

    writefln(
        "%s ordinary timing: production=%.3f ns former=%.3f ns production_over_former=%.4f sink=%.17g",
        is(T == double)
            ? "double"
            : "float",
        productionMedian,
        formerMedian,
        productionMedian /
            formerMedian,
        sink
    );
}


int main()
{
    writeln(
        "=== color-d Oklab -> OKLCH chroma production audit ==="
    );

    auto valuesD =
        makeOrdinaryCorpus!double();

    auto valuesF =
        makeOrdinaryCorpus!float();

    bool ok = true;

    ok =
        validateOrdinary(
            valuesD
        ) &&
        ok;

    ok =
        validateOrdinary(
            valuesF
        ) &&
        ok;

    ok =
        validateExtreme!double() &&
        ok;

    ok =
        validateExtreme!float() &&
        ok;

    benchmark(
        valuesD
    );

    benchmark(
        valuesF
    );

    return
        ok ? 0 : 1;
}
