// Current-production gamut mapping benchmark.
//
// Built twice by CI:
//   1. against the pre-#86 develop baseline;
//   2. against the current branch.
//
// The executable uses only the public color API. Dataset generation and
// allocations happen outside timed regions.

module gamut_production_probe;

import color :
    LinearSRgb,
    OklabHue,
    Oklch,
    gamutMapLocalMindeToLinearSRgb,
    gamutMapRayTraceToLinearSRgb,
    inGamut,
    toLinearSRgb,
    toOklab,
    toXyzD65;

import std.conv : bitCast;
import std.datetime.stopwatch : StopWatch;
import std.stdio : writefln, writeln;

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

private LinearSRgb!T rawLinear(T)(Oklch!T value)
{
    return
        value
            .toOklab
            .toXyzD65
            .toLinearSRgb;
}

enum sampleCount = 4096;

private void makePairedOutOfGamut(
    ref Oklch!double[sampleCount] doubles,
    ref Oklch!float[sampleCount] floats
)
{
    Lcg rng =
        Lcg(0xC010_D008_2026_0020UL);

    size_t n = 0;

    while (n < sampleCount)
    {
        const double l =
            0.05 +
            rng.unit() * 0.90;

        const double chroma =
            0.22 +
            rng.unit() * 0.24;

        const double hue =
            rng.unit() * 360.0;

        const candidateD =
            Oklch!double(
                l,
                chroma,
                OklabHue!double.fromDegrees(hue)
            );

        const candidateF =
            Oklch!float(
                cast(float)l,
                cast(float)chroma,
                OklabHue!float.fromDegrees(
                    cast(float)hue
                )
            );

        if (
            !rawLinear(candidateD).inGamut &&
            !rawLinear(candidateF).inGamut
        )
        {
            doubles[n] =
                candidateD;

            floats[n] =
                candidateF;

            ++n;
        }
    }
}

private void makePairedInGamut(
    ref Oklch!double[sampleCount] doubles,
    ref Oklch!float[sampleCount] floats
)
{
    Lcg rng =
        Lcg(0xC010_D008_2026_0090UL);

    size_t n = 0;

    while (n < sampleCount)
    {
        const double l =
            0.08 +
            rng.unit() * 0.84;

        const double chroma =
            rng.unit() * 0.06;

        const double hue =
            rng.unit() * 360.0;

        const candidateD =
            Oklch!double(
                l,
                chroma,
                OklabHue!double.fromDegrees(hue)
            );

        const candidateF =
            Oklch!float(
                cast(float)l,
                cast(float)chroma,
                OklabHue!float.fromDegrees(
                    cast(float)hue
                )
            );

        if (
            rawLinear(candidateD).inGamut &&
            rawLinear(candidateF).inGamut
        )
        {
            doubles[n] =
                candidateD;

            floats[n] =
                candidateF;

            ++n;
        }
    }
}

enum hugeCount = 128;

private void makeHugeChroma(
    ref Oklch!double[hugeCount] doubles,
    ref Oklch!float[hugeCount] floats
)
{
    Lcg rng =
        Lcg(0xC010_D008_2026_0091UL);

    foreach (i; 0 .. hugeCount)
    {
        const double l =
            0.10 +
            rng.unit() * 0.80;

        const double hue =
            rng.unit() * 360.0;

        // Large enough to exercise endpoint-overflow handling without using
        // non-finite public input.
        const double chromaD =
            double.max *
            (
                0.50 +
                rng.unit() * 0.49
            );

        const float chromaF =
            float.max *
            cast(float)(
                0.50 +
                rng.unit() * 0.49
            );

        doubles[i] =
            Oklch!double(
                l,
                chromaD,
                OklabHue!double.fromDegrees(hue)
            );

        floats[i] =
            Oklch!float(
                cast(float)l,
                chromaF,
                OklabHue!float.fromDegrees(
                    cast(float)hue
                )
            );
    }
}

private bool finite(T)(T value)
{
    return
        value > -T.infinity &&
        value < T.infinity;
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
    LinearSRgb!T value
)
{
    hashComponent(hash, value.r);
    hashComponent(hash, value.g);
    hashComponent(hash, value.b);
}


private void validateMapped(T)(
    string label,
    const(Oklch!T)[] values
)
{
    size_t localFailures = 0;
    size_t rayFailures = 0;

    ulong localHash =
        1469598103934665603UL;

    ulong rayHash =
        1469598103934665603UL;

    foreach (value; values)
    {
        const local =
            gamutMapLocalMindeToLinearSRgb(value);

        const ray =
            gamutMapRayTraceToLinearSRgb(value);

        hashColor(localHash, local);
        hashColor(rayHash, ray);

        if (
            !local.inGamut &&
            finite(value.l) &&
            finite(value.c) &&
            finite(value.h.rawDegrees) &&
            value.l > cast(T)0 &&
            value.l < cast(T)1
        )
        {
            ++localFailures;
        }

        if (
            !ray.inGamut &&
            finite(value.l) &&
            finite(value.c) &&
            finite(value.h.rawDegrees) &&
            value.l > cast(T)0 &&
            value.l < cast(T)1
        )
        {
            ++rayFailures;
        }
    }

    writefln(
        "%s %s validation: samples=%s local_failures=%s ray_failures=%s local_hash=%016x ray_hash=%016x",
        is(T == double) ? "double" : "float",
        label,
        values.length,
        localFailures,
        rayFailures,
        localHash,
        rayHash
    );
}

private double timeLocal(T)(
    const(Oklch!T)[] values,
    uint rounds,
    ref double sink
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. rounds)
    foreach (value; values)
    {
        const result =
            gamutMapLocalMindeToLinearSRgb(value);

        sink +=
            cast(double)result.r +
            cast(double)result.g * 0.5 +
            cast(double)result.b * 0.25;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * rounds);
}

private double timeRay(T)(
    const(Oklch!T)[] values,
    uint rounds,
    ref double sink
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. rounds)
    foreach (value; values)
    {
        const result =
            gamutMapRayTraceToLinearSRgb(value);

        sink +=
            cast(double)result.r +
            cast(double)result.g * 0.5 +
            cast(double)result.b * 0.25;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * rounds);
}

enum rounds = 7;

private double median(double[rounds] values)
{
    foreach (i; 1 .. values.length)
    {
        const double key = values[i];
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

        values[j] = key;
    }

    return
        values[
            values.length / 2
        ];
}

private void benchmarkDataset(T)(
    string label,
    const(Oklch!T)[] values,
    uint localRounds,
    uint rayRounds
)
{
    double[rounds] localNs;
    double[rounds] rayNs;
    double sink = 0;

    foreach (round; 0 .. rounds)
    {
        if ((round & 1) == 0)
        {
            localNs[round] =
                timeLocal(
                    values,
                    localRounds,
                    sink
                );

            rayNs[round] =
                timeRay(
                    values,
                    rayRounds,
                    sink
                );
        }
        else
        {
            rayNs[round] =
                timeRay(
                    values,
                    rayRounds,
                    sink
                );

            localNs[round] =
                timeLocal(
                    values,
                    localRounds,
                    sink
                );
        }
    }

    writefln(
        "%s %s: local_median=%.3f ns ray_median=%.3f ns ray_over_local=%.4f sink=%.17g",
        is(T == double) ? "double" : "float",
        label,
        median(localNs),
        median(rayNs),
        median(rayNs) / median(localNs),
        sink
    );
}

int main()
{
    Oklch!double[sampleCount] outD;
    Oklch!float[sampleCount] outF;

    Oklch!double[sampleCount] inD;
    Oklch!float[sampleCount] inF;

    Oklch!double[hugeCount] hugeD;
    Oklch!float[hugeCount] hugeF;

    makePairedOutOfGamut(outD, outF);
    makePairedInGamut(inD, inF);
    makeHugeChroma(hugeD, hugeF);

    writeln("=== color-d current gamut production audit ===");

    validateMapped("out-of-gamut", outD[]);
    validateMapped("out-of-gamut", outF[]);
    validateMapped("in-gamut", inD[]);
    validateMapped("in-gamut", inF[]);
    validateMapped("huge-chroma", hugeD[]);
    validateMapped("huge-chroma", hugeF[]);

    benchmarkDataset(
        "out-of-gamut",
        outD[],
        50,
        100
    );

    benchmarkDataset(
        "out-of-gamut",
        outF[],
        50,
        100
    );

    benchmarkDataset(
        "in-gamut",
        inD[],
        250,
        250
    );

    benchmarkDataset(
        "in-gamut",
        inF[],
        250,
        250
    );

    benchmarkDataset(
        "huge-chroma",
        hugeD[],
        1,
        20
    );

    benchmarkDataset(
        "huge-chroma",
        hugeF[],
        1,
        20
    );

    return 0;
}
