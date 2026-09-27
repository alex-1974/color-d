// Evidence-only control-flow instrumentation for current gamut mapping.
//
// This module deliberately lives outside the consumer package and duplicates
// the relevant production control flow. It does not change color.gamut.
//
// Every traced result is compared bit-for-bit with the public production
// mapper on the same deterministic corpus before the collected path data is
// accepted as evidence.
//
// The module name places this probe in package color so it can mirror the
// package-internal float XYZ inverse path used by color.gamut after #90.

module color.gamut_path_probe;

import color :
    LinearSRgb,
    Oklab,
    OklabHue,
    Oklch,
    deltaEOK,
    gamutMapLocalMindeToLinearSRgb,
    gamutMapRayTraceToLinearSRgb,
    inGamut,
    clip,
    toLinearSRgb,
    toOklab,
    toXyzD65;

import color.xyz :
    toLinearSRgbDirect;

import std.conv : bitCast;
import std.math :
    PI,
    cos,
    sin,
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


private bool isFiniteScalar(T)(const T value)
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}


private bool isFiniteOklch(T)(Oklch!T value)
{
    return
        isFiniteScalar(value.l) &&
        isFiniteScalar(value.c) &&
        isFiniteScalar(value.h.rawDegrees);
}


private bool isFiniteLinearSRgb(T)(LinearSRgb!T value)
{
    return
        isFiniteScalar(value.r) &&
        isFiniteScalar(value.g) &&
        isFiniteScalar(value.b);
}


private LinearSRgb!T tracedOklabToLinearSRgb(T)(Oklab!T value)
{
    const xyz =
        value.toXyzD65;

    // Mirror color.gamut after #90 exactly:
    // float uses the package direct matrix; double uses the robust public path.
    static if (is(T == float))
        return toLinearSRgbDirect(xyz);
    else
        return xyz.toLinearSRgb;
}


private Oklab!T tracedLinearSRgbToOklab(T)(LinearSRgb!T value)
{
    return
        value
            .toXyzD65
            .toOklab;
}


private LinearSRgb!T tracedOklchToLinearSRgb(T)(Oklch!T value)
{
    return
        tracedOklabToLinearSRgb(
            value.toOklab
        );
}


private Oklab!T fixedHueOklab(T)(
    const T lightness,
    const T chroma,
    const T cosHue,
    const T sinHue
)
{
    return Oklab!T(
        lightness,
        chroma * cosHue,
        chroma * sinHue
    );
}


private T hueRadians(T)(Oklch!T value)
{
    return
        value.h.positiveDegrees *
        cast(T)(PI / 180.0L);
}


private T absoluteValue(T)(T value)
{
    return
        value < cast(T)0
            ? -value
            : value;
}


private T minimum(T)(T first, T second)
{
    return
        first < second
            ? first
            : second;
}


private T maximum(T)(T first, T second)
{
    return
        first > second
            ? first
            : second;
}


private T rayEpsilon(T)()
{
    static if (is(T == float))
        return cast(T)1e-6;
    else
        return cast(T)1e-12;
}


private bool insideInterior(T)(
    LinearSRgb!T value,
    T low,
    T high
)
{
    return
        isFiniteScalar(value.r) &&
        isFiniteScalar(value.g) &&
        isFiniteScalar(value.b) &&
        value.r >= low &&
        value.r <= high &&
        value.g >= low &&
        value.g <= high &&
        value.b >= low &&
        value.b <= high;
}


private struct RayIntersection(T)
{
    LinearSRgb!T color;
    bool found;
}


private RayIntersection!T noRayIntersection(T)()
{
    return RayIntersection!T(
        LinearSRgb!T.init,
        false
    );
}


private RayIntersection!T intersectUnitRgbCube(T)(
    LinearSRgb!T start,
    LinearSRgb!T end
)
{
    if (
        !isFiniteScalar(start.r) ||
        !isFiniteScalar(start.g) ||
        !isFiniteScalar(start.b) ||
        !isFiniteScalar(end.r) ||
        !isFiniteScalar(end.g) ||
        !isFiniteScalar(end.b)
    )
    {
        return noRayIntersection!T();
    }

    const T eps =
        rayEpsilon!T();

    T[3] a = [
        start.r,
        start.g,
        start.b
    ];

    T[3] b = [
        end.r,
        end.g,
        end.b
    ];

    T[3] direction;

    T tNear =
        -T.infinity;

    T tFar =
        T.infinity;

    foreach (i; 0 .. 3)
    {
        const T d =
            b[i] - a[i];

        if (!isFiniteScalar(d))
            return noRayIntersection!T();

        direction[i] = d;

        if (
            absoluteValue(d) >
            eps
        )
        {
            const T inverse =
                cast(T)1 / d;

            const T first =
                (cast(T)0 - a[i]) *
                inverse;

            const T second =
                (cast(T)1 - a[i]) *
                inverse;

            tNear =
                maximum(
                    minimum(
                        first,
                        second
                    ),
                    tNear
                );

            tFar =
                minimum(
                    maximum(
                        first,
                        second
                    ),
                    tFar
                );
        }
        else if (
            a[i] < cast(T)0 ||
            a[i] > cast(T)1
        )
        {
            return noRayIntersection!T();
        }
    }

    if (
        tNear > tFar ||
        tFar < cast(T)0
    )
    {
        return noRayIntersection!T();
    }

    if (tNear < cast(T)0)
        tNear = tFar;

    if (!isFiniteScalar(tNear))
        return noRayIntersection!T();

    return RayIntersection!T(
        LinearSRgb!T(
            a[0] +
                direction[0] * tNear,
            a[1] +
                direction[1] * tNear,
            a[2] +
                direction[2] * tNear
        ),
        true
    );
}


private RayIntersection!T intersectUnitRgbCubeDirection(T)(
    LinearSRgb!T start,
    LinearSRgb!T direction
)
{
    if (
        !isFiniteLinearSRgb(start) ||
        !isFiniteLinearSRgb(direction)
    )
    {
        return noRayIntersection!T();
    }

    const T eps =
        rayEpsilon!T();

    T[3] a = [
        start.r,
        start.g,
        start.b
    ];

    T[3] d = [
        direction.r,
        direction.g,
        direction.b
    ];

    T tNear =
        -T.infinity;

    T tFar =
        T.infinity;

    foreach (i; 0 .. 3)
    {
        if (
            absoluteValue(d[i]) >
            eps
        )
        {
            const T inverse =
                cast(T)1 / d[i];

            const T first =
                (cast(T)0 - a[i]) *
                inverse;

            const T second =
                (cast(T)1 - a[i]) *
                inverse;

            tNear =
                maximum(
                    minimum(
                        first,
                        second
                    ),
                    tNear
                );

            tFar =
                minimum(
                    maximum(
                        first,
                        second
                    ),
                    tFar
                );
        }
        else if (
            a[i] < cast(T)0 ||
            a[i] > cast(T)1
        )
        {
            return noRayIntersection!T();
        }
    }

    if (
        tNear > tFar ||
        tFar < cast(T)0
    )
    {
        return noRayIntersection!T();
    }

    if (tNear < cast(T)0)
        tNear = tFar;

    if (!isFiniteScalar(tNear))
        return noRayIntersection!T();

    return RayIntersection!T(
        LinearSRgb!T(
            a[0] +
                d[0] * tNear,
            a[1] +
                d[1] * tNear,
            a[2] +
                d[2] * tNear
        ),
        true
    );
}


private T scaledCubicRayDirectionComponent(T)(
    const T sample1,
    const T sample2,
    const T sample3,
    const T base,
    const T chroma
)
{
    const T first =
        sample1 - base;

    const T second =
        sample2 - base;

    const T third =
        sample3 - base;

    const T cubic =
        (
            third -
            cast(T)3 * second +
            cast(T)3 * first
        ) /
        cast(T)6;

    const T quadratic =
        (
            second -
            cast(T)2 * first -
            cast(T)6 * cubic
        ) /
        cast(T)2;

    const T linear =
        first -
        quadratic -
        cubic;

    const T inverseChroma =
        cast(T)1 / chroma;

    return
        cubic +
        quadratic * inverseChroma +
        linear *
            inverseChroma *
            inverseChroma;
}


private LinearSRgb!T scaledHugeChromaRayDirection(T)(
    const T lightness,
    const T chroma,
    const T cosHue,
    const T sinHue,
    LinearSRgb!T anchor
)
{
    const LinearSRgb!T sample1 =
        tracedOklabToLinearSRgb(
            fixedHueOklab(
                lightness,
                cast(T)1,
                cosHue,
                sinHue
            )
        );

    const LinearSRgb!T sample2 =
        tracedOklabToLinearSRgb(
            fixedHueOklab(
                lightness,
                cast(T)2,
                cosHue,
                sinHue
            )
        );

    const LinearSRgb!T sample3 =
        tracedOklabToLinearSRgb(
            fixedHueOklab(
                lightness,
                cast(T)3,
                cosHue,
                sinHue
            )
        );

    return LinearSRgb!T(
        scaledCubicRayDirectionComponent(
            sample1.r,
            sample2.r,
            sample3.r,
            anchor.r,
            chroma
        ),
        scaledCubicRayDirectionComponent(
            sample1.g,
            sample2.g,
            sample3.g,
            anchor.g,
            chroma
        ),
        scaledCubicRayDirectionComponent(
            sample1.b,
            sample2.b,
            sample3.b,
            anchor.b,
            chroma
        )
    );
}


private T binaryMidpoint(T)(
    T low,
    T high
)
{
    if (
        low > cast(T)0 &&
        high > T.max - low
    )
    {
        return
            low +
            (high - low) /
            cast(T)2;
    }

    return
        (low + high) /
        cast(T)2;
}


private enum LocalStop : ubyte
{
    nonFiniteBypass,
    whiteBoundary,
    blackBoundary,
    identity,
    initialJnd,
    jndConverged,
    intervalConverged,
    stagnated,
    iterationCap
}


private struct LocalTrace(T)
{
    LinearSRgb!T color;
    LocalStop stop;
    size_t evaluations;
}


private LocalTrace!T tracedLocalImpl(T)(
    Oklch!T origin
)
{
    const T radians =
        hueRadians(origin);

    const T cosHue =
        cast(T)cos(radians);

    const T sinHue =
        cast(T)sin(radians);

    Oklab!T currentLab =
        fixedHueOklab(
            origin.l,
            origin.c,
            cosHue,
            sinHue
        );

    LinearSRgb!T currentRgb =
        tracedOklabToLinearSRgb(
            currentLab
        );

    if (currentRgb.inGamut)
    {
        return LocalTrace!T(
            currentRgb,
            LocalStop.identity,
            0
        );
    }

    enum T jnd =
        cast(T)0.02;

    enum T epsilon =
        cast(T)0.0001;

    LinearSRgb!T clipped =
        currentRgb.clip;

    T difference =
        deltaEOK(
            tracedLinearSRgbToOklab(clipped),
            currentLab
        );

    if (difference < jnd)
    {
        return LocalTrace!T(
            clipped,
            LocalStop.initialJnd,
            0
        );
    }

    T low =
        cast(T)0;

    T high =
        origin.c;

    bool lowInGamut =
        true;

    size_t evaluations = 0;

    foreach (_; 0 .. 2048)
    {
        if (
            high - low <=
            epsilon
        )
        {
            return LocalTrace!T(
                clipped,
                LocalStop.intervalConverged,
                evaluations
            );
        }

        const T chroma =
            binaryMidpoint(
                low,
                high
            );

        if (
            chroma == low ||
            chroma == high
        )
        {
            return LocalTrace!T(
                clipped,
                LocalStop.stagnated,
                evaluations
            );
        }

        ++evaluations;

        currentLab =
            fixedHueOklab(
                origin.l,
                chroma,
                cosHue,
                sinHue
            );

        currentRgb =
            tracedOklabToLinearSRgb(
                currentLab
            );

        if (
            lowInGamut &&
            currentRgb.inGamut
        )
        {
            low = chroma;
            continue;
        }

        clipped =
            currentRgb.clip;

        difference =
            deltaEOK(
                tracedLinearSRgbToOklab(
                    clipped
                ),
                currentLab
            );

        if (difference < jnd)
        {
            if (
                jnd - difference <
                epsilon
            )
            {
                return LocalTrace!T(
                    clipped,
                    LocalStop.jndConverged,
                    evaluations
                );
            }

            lowInGamut = false;
            low = chroma;
        }
        else
        {
            high = chroma;
        }
    }

    return LocalTrace!T(
        clipped,
        LocalStop.iterationCap,
        evaluations
    );
}


private LocalTrace!T tracedLocal(T)(
    Oklch!T color
)
{
    if (!isFiniteOklch(color))
    {
        return LocalTrace!T(
            tracedOklchToLinearSRgb(color),
            LocalStop.nonFiniteBypass,
            0
        );
    }

    color =
        color.canonicalized;

    if (color.l >= cast(T)1)
    {
        return LocalTrace!T(
            LinearSRgb!T(
                cast(T)1,
                cast(T)1,
                cast(T)1
            ),
            LocalStop.whiteBoundary,
            0
        );
    }

    if (color.l <= cast(T)0)
    {
        return LocalTrace!T(
            LinearSRgb!T(
                cast(T)0,
                cast(T)0,
                cast(T)0
            ),
            LocalStop.blackBoundary,
            0
        );
    }

    return tracedLocalImpl(color);
}


private enum RayStop : ubyte
{
    nonFiniteBypass,
    whiteBoundary,
    blackBoundary,
    identity,
    completedFour,
    terminalMiss
}


private struct RayTrace(T)
{
    LinearSRgb!T color;
    RayStop stop;
    size_t iterations;
    size_t directMisses;
    size_t reanchors;
    bool fallbackAttempted;
    bool fallbackSucceeded;
}


private RayTrace!T tracedRayImpl(T)(
    Oklch!T origin
)
{
    const T originalLightness =
        origin.l;

    const T radians =
        hueRadians(origin);

    const T cosHue =
        cast(T)cos(radians);

    const T sinHue =
        cast(T)sin(radians);

    LinearSRgb!T anchor =
        tracedOklabToLinearSRgb(
            fixedHueOklab(
                originalLightness,
                cast(T)0,
                cosHue,
                sinHue
            )
        );

    LinearSRgb!T originRgb =
        tracedOklabToLinearSRgb(
            fixedHueOklab(
                originalLightness,
                origin.c,
                cosHue,
                sinHue
            )
        );

    if (originRgb.inGamut)
    {
        return RayTrace!T(
            originRgb,
            RayStop.identity,
            0,
            0,
            0,
            false,
            false
        );
    }

    const T eps =
        rayEpsilon!T();

    const T low =
        cast(T)0 + eps;

    const T high =
        cast(T)1 - eps;

    LinearSRgb!T last =
        originRgb;

    size_t iterations = 0;
    size_t directMisses = 0;
    size_t reanchors = 0;
    bool fallbackAttempted = false;
    bool fallbackSucceeded = false;

    foreach (i; 0 .. 4)
    {
        ++iterations;

        if (i > 0)
        {
            const Oklab!T currentLab =
                tracedLinearSRgbToOklab(
                    originRgb
                );

            const T chroma =
                cast(T)sqrt(
                    currentLab.a *
                        currentLab.a +
                    currentLab.b *
                        currentLab.b
                );

            originRgb =
                tracedOklabToLinearSRgb(
                    fixedHueOklab(
                        originalLightness,
                        chroma,
                        cosHue,
                        sinHue
                    )
                );
        }

        auto intersection =
            intersectUnitRgbCube(
                anchor,
                originRgb
            );

        if (!intersection.found)
        {
            ++directMisses;

            if (
                i == 0 &&
                isFiniteOklch(origin) &&
                origin.c > cast(T)0 &&
                !isFiniteLinearSRgb(
                    originRgb
                )
            )
            {
                fallbackAttempted = true;

                intersection =
                    intersectUnitRgbCubeDirection(
                        anchor,
                        scaledHugeChromaRayDirection(
                            originalLightness,
                            origin.c,
                            cosHue,
                            sinHue,
                            anchor
                        )
                    );

                fallbackSucceeded =
                    intersection.found;
            }

            if (!intersection.found)
            {
                originRgb = last;

                return RayTrace!T(
                    originRgb.clip,
                    RayStop.terminalMiss,
                    iterations,
                    directMisses,
                    reanchors,
                    fallbackAttempted,
                    fallbackSucceeded
                );
            }
        }

        if (
            i > 0 &&
            originRgb.insideInterior(
                low,
                high
            )
        )
        {
            anchor =
                originRgb;

            ++reanchors;
        }

        originRgb =
            intersection.color;

        last =
            intersection.color;
    }

    return RayTrace!T(
        originRgb.clip,
        RayStop.completedFour,
        iterations,
        directMisses,
        reanchors,
        fallbackAttempted,
        fallbackSucceeded
    );
}


private RayTrace!T tracedRay(T)(
    Oklch!T color
)
{
    if (!isFiniteOklch(color))
    {
        return RayTrace!T(
            tracedOklchToLinearSRgb(color),
            RayStop.nonFiniteBypass,
            0,
            0,
            0,
            false,
            false
        );
    }

    color =
        color.canonicalized;

    if (color.l >= cast(T)1)
    {
        return RayTrace!T(
            LinearSRgb!T(
                cast(T)1,
                cast(T)1,
                cast(T)1
            ),
            RayStop.whiteBoundary,
            0,
            0,
            0,
            false,
            false
        );
    }

    if (color.l <= cast(T)0)
    {
        return RayTrace!T(
            LinearSRgb!T(
                cast(T)0,
                cast(T)0,
                cast(T)0
            ),
            RayStop.blackBoundary,
            0,
            0,
            0,
            false,
            false
        );
    }

    return tracedRayImpl(color);
}


private ulong componentBits(T)(T value)
{
    static if (is(T == float))
        return cast(ulong)bitCast!uint(value);
    else
        return bitCast!ulong(value);
}


private bool sameColorBits(T)(
    LinearSRgb!T first,
    LinearSRgb!T second
)
{
    return
        componentBits(first.r) ==
            componentBits(second.r) &&
        componentBits(first.g) ==
            componentBits(second.g) &&
        componentBits(first.b) ==
            componentBits(second.b);
}


private string localStopName(LocalStop stop)
{
    final switch (stop)
    {
        case LocalStop.nonFiniteBypass:
            return "nonfinite-bypass";
        case LocalStop.whiteBoundary:
            return "white-boundary";
        case LocalStop.blackBoundary:
            return "black-boundary";
        case LocalStop.identity:
            return "identity";
        case LocalStop.initialJnd:
            return "initial-jnd";
        case LocalStop.jndConverged:
            return "jnd-converged";
        case LocalStop.intervalConverged:
            return "interval-converged";
        case LocalStop.stagnated:
            return "stagnated";
        case LocalStop.iterationCap:
            return "iteration-cap";
    }
}


private string rayStopName(RayStop stop)
{
    final switch (stop)
    {
        case RayStop.nonFiniteBypass:
            return "nonfinite-bypass";
        case RayStop.whiteBoundary:
            return "white-boundary";
        case RayStop.blackBoundary:
            return "black-boundary";
        case RayStop.identity:
            return "identity";
        case RayStop.completedFour:
            return "completed-four";
        case RayStop.terminalMiss:
            return "terminal-miss";
    }
}


private enum localStopCount = 9;
private enum rayStopCount = 6;
private enum localHistogramSize = 2049;


private struct LocalSummary
{
    size_t samples;
    size_t mismatches;
    size_t[localStopCount] stops;
    size_t[localHistogramSize] evaluations;
    size_t totalEvaluations;
    size_t minEvaluations = size_t.max;
    size_t maxEvaluations;
}


private struct RaySummary
{
    size_t samples;
    size_t mismatches;
    size_t[rayStopCount] stops;
    size_t[5] iterations;
    size_t directMisses;
    size_t reanchors;
    size_t fallbackAttempts;
    size_t fallbackSuccesses;
}


private void observeLocal(
    T
)(
    ref LocalSummary summary,
    LocalTrace!T trace,
    LinearSRgb!T production
)
{
    ++summary.samples;

    if (!sameColorBits(trace.color, production))
        ++summary.mismatches;

    ++summary.stops[cast(size_t)trace.stop];

    const size_t n =
        trace.evaluations;

    ++summary.evaluations[n];

    summary.totalEvaluations +=
        n;

    if (n < summary.minEvaluations)
        summary.minEvaluations = n;

    if (n > summary.maxEvaluations)
        summary.maxEvaluations = n;
}


private void observeRay(
    T
)(
    ref RaySummary summary,
    RayTrace!T trace,
    LinearSRgb!T production
)
{
    ++summary.samples;

    if (!sameColorBits(trace.color, production))
        ++summary.mismatches;

    ++summary.stops[cast(size_t)trace.stop];

    ++summary.iterations[trace.iterations];

    summary.directMisses +=
        trace.directMisses;

    summary.reanchors +=
        trace.reanchors;

    if (trace.fallbackAttempted)
        ++summary.fallbackAttempts;

    if (trace.fallbackSucceeded)
        ++summary.fallbackSuccesses;
}


private size_t quantileEvaluation(
    const ref LocalSummary summary,
    size_t numerator,
    size_t denominator
)
{
    const size_t target =
        (
            summary.samples *
                numerator +
            denominator -
            1
        ) /
        denominator;

    size_t cumulative = 0;

    foreach (i, count; summary.evaluations)
    {
        cumulative += count;

        if (
            cumulative >= target &&
            target != 0
        )
        {
            return i;
        }
    }

    return 0;
}


private void printLocal(
    string scalar,
    string dataset,
    const ref LocalSummary summary
)
{
    writefln(
        "LOCAL scalar=%s dataset=%s samples=%s mismatches=%s",
        scalar,
        dataset,
        summary.samples,
        summary.mismatches
    );

    foreach (i; 0 .. localStopCount)
    {
        const count =
            summary.stops[i];

        if (count != 0)
        {
            writefln(
                "  stop=%s count=%s",
                localStopName(
                    cast(LocalStop)i
                ),
                count
            );
        }
    }

    writefln(
        "  midpoint-evaluations min=%s p50=%s p90=%s p99=%s max=%s mean=%.3f",
        summary.minEvaluations,
        quantileEvaluation(summary, 50, 100),
        quantileEvaluation(summary, 90, 100),
        quantileEvaluation(summary, 99, 100),
        summary.maxEvaluations,
        cast(double)summary.totalEvaluations /
            cast(double)summary.samples
    );
}


private void printRay(
    string scalar,
    string dataset,
    const ref RaySummary summary
)
{
    writefln(
        "RAY scalar=%s dataset=%s samples=%s mismatches=%s",
        scalar,
        dataset,
        summary.samples,
        summary.mismatches
    );

    foreach (i; 0 .. rayStopCount)
    {
        const count =
            summary.stops[i];

        if (count != 0)
        {
            writefln(
                "  stop=%s count=%s",
                rayStopName(
                    cast(RayStop)i
                ),
                count
            );
        }
    }

    foreach (i, count; summary.iterations)
    {
        if (count != 0)
        {
            writefln(
                "  ray-iterations=%s count=%s",
                i,
                count
            );
        }
    }

    writefln(
        "  direct-misses=%s reanchors=%s fallback-attempts=%s fallback-successes=%s",
        summary.directMisses,
        summary.reanchors,
        summary.fallbackAttempts,
        summary.fallbackSuccesses
    );
}


private bool auditDataset(T)(
    string dataset,
    const(Oklch!T)[] values
)
{
    LocalSummary local;
    RaySummary ray;

    foreach (value; values)
    {
        const localTrace =
            tracedLocal(value);

        const localProduction =
            gamutMapLocalMindeToLinearSRgb(
                value
            );

        observeLocal(
            local,
            localTrace,
            localProduction
        );

        const rayTrace =
            tracedRay(value);

        const rayProduction =
            gamutMapRayTraceToLinearSRgb(
                value
            );

        observeRay(
            ray,
            rayTrace,
            rayProduction
        );
    }

    const scalar =
        is(T == double)
            ? "double"
            : "float";

    printLocal(
        scalar,
        dataset,
        local
    );

    printRay(
        scalar,
        dataset,
        ray
    );

    return
        local.mismatches == 0 &&
        ray.mismatches == 0;
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

    writeln("=== color-d gamut control-flow audit ===");
    writeln("traced result must be bit-identical to public production output");

    bool ok = true;

    ok =
        auditDataset(
            "out-of-gamut",
            outD[]
        ) &&
        ok;

    ok =
        auditDataset(
            "out-of-gamut",
            outF[]
        ) &&
        ok;

    ok =
        auditDataset(
            "in-gamut",
            inD[]
        ) &&
        ok;

    ok =
        auditDataset(
            "in-gamut",
            inF[]
        ) &&
        ok;

    ok =
        auditDataset(
            "huge-chroma",
            hugeD[]
        ) &&
        ok;

    ok =
        auditDataset(
            "huge-chroma",
            hugeF[]
        ) &&
        ok;

    return ok ? 0 : 1;
}
