// Candidate audit for robust XYZ D65 -> linear-sRGB extreme-finite closure.
//
// Goal:
//   recover mathematically representable finite results at extreme magnitudes
//   without imposing the large ordinary-path cost of the #80 result-gated
//   fallback.
//
// This is benchmark/research code. It does not define public API policy.

module xyz_linear_rgb_extreme_gate_probe;

import color :
    LinearSRgb,
    XyzD65,
    toLinearSRgb;

import core.builtins : likely;
import std.conv : bitCast;
import std.datetime.stopwatch : StopWatch;
import std.stdio : writefln, writeln;

template ReferenceScalar(T)
{
    static if (is(T == float))
        alias ReferenceScalar = double;
    else
        alias ReferenceScalar = real;
}

template UIntFor(T)
{
    static if (is(T == float))
        alias UIntFor = uint;
    else
        alias UIntFor = ulong;
}

private R ratio(R)(long numerator, long denominator)
{
    return cast(R)numerator / cast(R)denominator;
}

private bool finite(T)(T value)
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}

private T magnitude(T)(T value)
{
    return value < cast(T)0 ? -value : value;
}

private T maximum(T)(T first, T second)
{
    return first > second ? first : second;
}

private bool inputFinite(T)(XyzD65!T xyz)
{
    return
        finite(xyz.x) &&
        finite(xyz.y) &&
        finite(xyz.z);
}

private bool outputFinite(T)(LinearSRgb!T rgb)
{
    return
        finite(rgb.r) &&
        finite(rgb.g) &&
        finite(rgb.b);
}


private bool finiteBounds(T)(T value)
{
    return
        value <= T.max &&
        value >= -T.max;
}

private bool finiteAbs(T)(T value)
{
    import std.math : fabs;

    return fabs(value) <= T.max;
}

private bool finiteSelfSubtract(T)(T value)
{
    return value - value == cast(T)0;
}

private bool outputFiniteBits(T)(LinearSRgb!T rgb)
{
    alias U = UIntFor!T;

    const U signlessMask =
        U.max >> 1;

    static if (is(T == float))
        enum U exponentMask = 0x7F80_0000U;
    else
        enum U exponentMask = 0x7FF0_0000_0000_0000UL;

    const U combined =
        (
            bitCast!U(rgb.r) |
            bitCast!U(rgb.g) |
            bitCast!U(rgb.b)
        ) &
        signlessMask;

    return (combined & exponentMask) != exponentMask;
}

private bool outputFiniteBitsRuntimeFpCtfe(T)(LinearSRgb!T rgb)
{
    if (__ctfe)
        return outputFinite(rgb);

    return outputFiniteBits(rgb);
}

private LinearSRgb!T scaledShared(T)(XyzD65!T xyz)
{
    const T scale =
        maximum(
            magnitude(xyz.x),
            maximum(
                magnitude(xyz.y),
                magnitude(xyz.z)
            )
        );

    if (scale == cast(T)0)
        return LinearSRgb!T(
            cast(T)0,
            cast(T)0,
            cast(T)0
        );

    const T x = xyz.x / scale;
    const T y = xyz.y / scale;
    const T z = xyz.z / scale;

    return LinearSRgb!T(
        scale * (
            ratio!T(12831,    3959)  * x +
            ratio!T(-329,      214)  * y +
            ratio!T(-1974,    3959)  * z
        ),
        scale * (
            ratio!T(-851781, 878810) * x +
            ratio!T(1648619, 878810) * y +
            ratio!T(36519,   878810) * z
        ),
        scale * (
            ratio!T(705,      12673) * x +
            ratio!T(-2585,    12673) * y +
            ratio!T(705,        667) * z
        )
    );
}

private pragma(inline, false)
LinearSRgb!T scaledSharedCold(T)(XyzD65!T xyz)
{
    return scaledShared(xyz);
}

// Largest inverse-matrix absolute row sum is about 5.277.
// If every input component has magnitude <= T.max / 6, every direct product
// and partial sum is bounded away from overflow.
private bool directSafeFp(T)(XyzD65!T xyz)
{
    const T bound =
        T.max / cast(T)6;

    return
        magnitude(xyz.x) <= bound &&
        magnitude(xyz.y) <= bound &&
        magnitude(xyz.z) <= bound;
}

// IEEE positive finite bit patterns are monotone with magnitude. OR is >= each
// operand, so an OR below the safe-bound encoding proves all three components
// are below the bound. It may produce conservative false positives (slow path)
// but cannot admit an unsafe component.
private bool directSafeBits(T)(XyzD65!T xyz)
{
    alias U = UIntFor!T;

    const U signlessMask =
        U.max >> 1;

    const U combined =
        (
            bitCast!U(xyz.x) |
            bitCast!U(xyz.y) |
            bitCast!U(xyz.z)
        ) &
        signlessMask;

    const T bound =
        T.max / cast(T)6;

    const U boundBits =
        bitCast!U(bound);

    return combined <= boundBits;
}

private bool directSafeBitRuntimeFpCtfe(T)(XyzD65!T xyz)
{
    if (__ctfe)
        return directSafeFp(xyz);

    return directSafeBits(xyz);
}

private LinearSRgb!T resultGate(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    if (outputFinite(ordinary))
        return ordinary;

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T aggregateResultGate(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    /*
     * Under strict IEEE arithmetic, any NaN/infinity component makes this
     * aggregate non-finite. Finite components can only create a conservative
     * false positive by overflowing the aggregate itself, which merely selects
     * the robust slow path.
     *
     * p - p is exactly zero for every finite p and NaN for ±infinity/NaN.
     */
    const T p =
        ordinary.r +
        ordinary.g +
        ordinary.b;

    if (p - p == cast(T)0)
        return ordinary;

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T resultGateAggregateSubtract(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    const T classification =
        (ordinary.r - ordinary.r) +
        (ordinary.g - ordinary.g) +
        (ordinary.b - ordinary.b);

    if (classification == cast(T)0)
        return ordinary;

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T resultGateAggregateZeroMultiply(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    const T zero = cast(T)0;
    const T classification =
        ordinary.r * zero +
        ordinary.g * zero +
        ordinary.b * zero;

    if (classification == cast(T)0)
        return ordinary;

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T resultGateStdIsFinite(T)(XyzD65!T xyz)
{
    import std.math : isFinite;

    const auto ordinary =
        xyz.toLinearSRgb;

    if (
        isFinite(ordinary.r) &&
        isFinite(ordinary.g) &&
        isFinite(ordinary.b)
    )
    {
        return ordinary;
    }

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T resultGateLikely(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    if (likely(outputFinite(ordinary)))
        return ordinary;

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T resultGateBounds(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    if (
        finiteBounds(ordinary.r) &&
        finiteBounds(ordinary.g) &&
        finiteBounds(ordinary.b)
    )
    {
        return ordinary;
    }

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T resultGateAbs(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    if (
        finiteAbs(ordinary.r) &&
        finiteAbs(ordinary.g) &&
        finiteAbs(ordinary.b)
    )
    {
        return ordinary;
    }

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T resultGateSelfSubtract(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    if (
        finiteSelfSubtract(ordinary.r) &&
        finiteSelfSubtract(ordinary.g) &&
        finiteSelfSubtract(ordinary.b)
    )
    {
        return ordinary;
    }

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T resultGateBits(T)(XyzD65!T xyz)
{
    const auto ordinary =
        xyz.toLinearSRgb;

    if (outputFiniteBitsRuntimeFpCtfe(ordinary))
        return ordinary;

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T fpGate(T)(XyzD65!T xyz)
{
    if (directSafeFp(xyz))
        return xyz.toLinearSRgb;

    if (!inputFinite(xyz))
        return xyz.toLinearSRgb;

    return scaledShared(xyz);
}

private LinearSRgb!T bitGate(T)(XyzD65!T xyz)
{
    if (directSafeBitRuntimeFpCtfe(xyz))
        return xyz.toLinearSRgb;

    if (!inputFinite(xyz))
        return xyz.toLinearSRgb;

    return scaledShared(xyz);
}

private LinearSRgb!T bitGateCold(T)(XyzD65!T xyz)
{
    if (directSafeBitRuntimeFpCtfe(xyz))
        return xyz.toLinearSRgb;

    if (!inputFinite(xyz))
        return xyz.toLinearSRgb;

    return scaledSharedCold(xyz);
}

private LinearSRgb!T bitGateColdLikely(T)(XyzD65!T xyz)
{
    if (__ctfe)
    {
        if (directSafeFp(xyz))
            return xyz.toLinearSRgb;
    }
    else
    {
        if (likely(directSafeBits(xyz)))
            return xyz.toLinearSRgb;
    }

    if (!inputFinite(xyz))
        return xyz.toLinearSRgb;

    return scaledSharedCold(xyz);
}

// Branchless algebraic candidate. Each row is scaled by a power of two larger
// than its absolute coefficient sum, so finite inputs cannot overflow inside
// the dot product. The final exact power-of-two rescale can overflow only when
// the row result itself is outside the scalar range, apart from rounding-edge
// effects. Validation below checks ordinary bit equality and extreme closure.
private LinearSRgb!T rowScaledMinFma(T)(XyzD65!T xyz)
{
    import core.stdc.math :
        fma,
        fmaf;

    if (__ctfe)
        return rowScaled(xyz);

    enum T redScale = cast(T)4;
    enum T greenScale = cast(T)2;
    enum T blueScale = cast(T)2;

    static if (is(T == float))
    {
        return LinearSRgb!T(
            redScale * fmaf(
                ratio!T(12831, 3959) / redScale,
                xyz.x,
                fmaf(
                    ratio!T(-329, 214) / redScale,
                    xyz.y,
                    (ratio!T(-1974, 3959) / redScale) * xyz.z
                )
            ),
            greenScale * fmaf(
                ratio!T(1648619, 878810) / greenScale,
                xyz.y,
                fmaf(
                    ratio!T(-851781, 878810) / greenScale,
                    xyz.x,
                    (ratio!T(36519, 878810) / greenScale) * xyz.z
                )
            ),
            blueScale * fmaf(
                ratio!T(705, 667) / blueScale,
                xyz.z,
                fmaf(
                    ratio!T(-2585, 12673) / blueScale,
                    xyz.y,
                    (ratio!T(705, 12673) / blueScale) * xyz.x
                )
            )
        );
    }
    else
    {
        return LinearSRgb!T(
            redScale * fma(
                ratio!T(12831, 3959) / redScale,
                xyz.x,
                fma(
                    ratio!T(-329, 214) / redScale,
                    xyz.y,
                    (ratio!T(-1974, 3959) / redScale) * xyz.z
                )
            ),
            greenScale * fma(
                ratio!T(1648619, 878810) / greenScale,
                xyz.y,
                fma(
                    ratio!T(-851781, 878810) / greenScale,
                    xyz.x,
                    (ratio!T(36519, 878810) / greenScale) * xyz.z
                )
            ),
            blueScale * fma(
                ratio!T(705, 667) / blueScale,
                xyz.z,
                fma(
                    ratio!T(-2585, 12673) / blueScale,
                    xyz.y,
                    (ratio!T(705, 12673) / blueScale) * xyz.x
                )
            )
        );
    }
}

private LinearSRgb!T rowScaled(T)(XyzD65!T xyz)
{
    enum T redScale = cast(T)8;
    enum T greenScale = cast(T)4;
    enum T blueScale = cast(T)2;

    return LinearSRgb!T(
        redScale * (
            (ratio!T(12831,    3959) / redScale) * xyz.x +
            (ratio!T(-329,      214) / redScale) * xyz.y +
            (ratio!T(-1974,    3959) / redScale) * xyz.z
        ),
        greenScale * (
            (ratio!T(-851781, 878810) / greenScale) * xyz.x +
            (ratio!T(1648619, 878810) / greenScale) * xyz.y +
            (ratio!T(36519,   878810) / greenScale) * xyz.z
        ),
        blueScale * (
            (ratio!T(705,      12673) / blueScale) * xyz.x +
            (ratio!T(-2585,    12673) / blueScale) * xyz.y +
            (ratio!T(705,        667) / blueScale) * xyz.z
        )
    );
}

private LinearSRgb!T path(T, int kind)(XyzD65!T xyz)
{
    static if (kind == 0)
        return xyz.toLinearSRgb;
    else static if (kind == 1)
        return resultGate(xyz);
    else static if (kind == 2)
        return fpGate(xyz);
    else static if (kind == 3)
        return bitGate(xyz);
    else static if (kind == 4)
        return bitGateCold(xyz);
    else static if (kind == 5)
        return bitGateColdLikely(xyz);
    else static if (kind == 6)
        return rowScaled(xyz);
    else static if (kind == 7)
        return aggregateResultGate(xyz);
    else static if (kind == 8)
        return rowScaledMinFma(xyz);
    else static if (kind == 9)
        return resultGateBounds(xyz);
    else static if (kind == 10)
        return resultGateAbs(xyz);
    else static if (kind == 11)
        return resultGateSelfSubtract(xyz);
    else static if (kind == 12)
        return resultGateBits(xyz);
    else static if (kind == 13)
        return resultGateAggregateSubtract(xyz);
    else static if (kind == 14)
        return resultGateAggregateZeroMultiply(xyz);
    else static if (kind == 15)
        return resultGateStdIsFinite(xyz);
    else static if (kind == 16)
        return resultGateLikely(xyz);
    else
        static assert(false, "unknown path");
}

private const(char)[] pathName(int kind)()
{
    static if (kind == 0)
        return "production";
    else static if (kind == 1)
        return "result-gate";
    else static if (kind == 2)
        return "fp-pre-gate";
    else static if (kind == 3)
        return "bit-pre-gate";
    else static if (kind == 4)
        return "bit-pre-gate-cold";
    else static if (kind == 5)
        return "bit-pre-gate-cold-likely";
    else static if (kind == 6)
        return "row-scaled";
    else static if (kind == 7)
        return "aggregate-result-gate";
    else static if (kind == 8)
        return "row-scaled-min-fma";
    else static if (kind == 9)
        return "result-gate-bounds";
    else static if (kind == 10)
        return "result-gate-fabs";
    else static if (kind == 11)
        return "result-gate-self-subtract";
    else static if (kind == 12)
        return "result-gate-bits";
    else static if (kind == 13)
        return "result-gate-aggregate-subtract";
    else static if (kind == 14)
        return "result-gate-zero-multiply";
    else static if (kind == 15)
        return "result-gate-std-isfinite";
    else static if (kind == 16)
        return "result-gate-likely";
    else
        static assert(false, "unknown path");
}

private struct Ref3(R)
{
    R r;
    R g;
    R b;
}

private Ref3!R reference(T, R)(XyzD65!T xyz)
{
    const R x = cast(R)xyz.x;
    const R y = cast(R)xyz.y;
    const R z = cast(R)xyz.z;

    return Ref3!R(
        ratio!R(12831,    3959)   * x +
        ratio!R(-329,      214)   * y +
        ratio!R(-1974,    3959)   * z,

        ratio!R(-851781, 878810)  * x +
        ratio!R(1648619, 878810)  * y +
        ratio!R(36519,   878810)  * z,

        ratio!R(705,      12673)  * x +
        ratio!R(-2585,    12673)  * y +
        ratio!R(705,        667)  * z
    );
}

private bool representableAs(T, R)(R value)
{
    return
        value == value &&
        value <= cast(R)T.max &&
        value >= -cast(R)T.max;
}

private bool referenceFits(T, R)(Ref3!R value)
{
    return
        representableAs!T(value.r) &&
        representableAs!T(value.g) &&
        representableAs!T(value.b);
}

private T scaledMax(T)(double factor)
{
    return
        cast(T)(
            cast(ReferenceScalar!T)T.max *
            cast(ReferenceScalar!T)factor
        );
}

private size_t extremeAvoidable(T, int kind)()
{
    alias R = ReferenceScalar!T;

    const double[9] factors = [
        -1.0, -0.75, -0.50, -0.25,
         0.0,
         0.25, 0.50, 0.75, 1.0
    ];

    size_t representable = 0;
    size_t avoidable = 0;

    foreach (fx; factors)
    foreach (fy; factors)
    foreach (fz; factors)
    {
        const auto xyz =
            XyzD65!T(
                scaledMax!T(fx),
                scaledMax!T(fy),
                scaledMax!T(fz)
            );

        const auto refValue =
            reference!(T, R)(xyz);

        if (!referenceFits!T(refValue))
            continue;

        ++representable;

        if (!outputFinite(path!(T, kind)(xyz)))
            ++avoidable;
    }

    writefln(
        "%s %s extreme: representable=%s avoidable_nonfinite=%s",
        is(T == double) ? "double" : "float",
        pathName!kind,
        representable,
        avoidable
    );

    return avoidable;
}

private uint nextRandom(ref uint state)
{
    state =
        state * 1_664_525U +
        1_013_904_223U;

    return state;
}

private T ordinaryValue(T)(ref uint state)
{
    const uint bits =
        nextRandom(state) &
        0x00FF_FFFFU;

    const T unit =
        cast(T)bits /
        cast(T)0x00FF_FFFFU;

    return
        cast(T)-0.25 +
        cast(T)1.50 * unit;
}

enum validationSamples = 1_000_000;

private size_t ordinaryMismatches(T, int kind)()
{
    uint state = 0xC01D_0083U;
    size_t mismatches = 0;

    foreach (_; 0 .. validationSamples)
    {
        const auto xyz =
            XyzD65!T(
                ordinaryValue!T(state),
                ordinaryValue!T(state),
                ordinaryValue!T(state)
            );

        const auto expected =
            xyz.toLinearSRgb;

        const auto actual =
            path!(T, kind)(xyz);

        if (
            actual.r != expected.r ||
            actual.g != expected.g ||
            actual.b != expected.b
        )
        {
            ++mismatches;
        }
    }

    writefln(
        "%s %s ordinary: samples=%s exact_mismatches=%s",
        is(T == double) ? "double" : "float",
        pathName!kind,
        validationSamples,
        mismatches
    );

    return mismatches;
}

private void gateInstrumentation(T)()
{
    uint state = 0xC01D_0084U;
    size_t fpSlow = 0;
    size_t bitSlow = 0;
    size_t bitConservative = 0;

    foreach (_; 0 .. validationSamples)
    {
        const auto xyz =
            XyzD65!T(
                ordinaryValue!T(state),
                ordinaryValue!T(state),
                ordinaryValue!T(state)
            );

        const bool fpSafe =
            directSafeFp(xyz);

        const bool bitSafe =
            directSafeBits(xyz);

        if (!fpSafe)
            ++fpSlow;

        if (!bitSafe)
            ++bitSlow;

        if (fpSafe && !bitSafe)
            ++bitConservative;
    }

    writefln(
        "%s gate instrumentation: samples=%s fp_slow=%s bit_slow=%s bit_conservative=%s",
        is(T == double) ? "double" : "float",
        validationSamples,
        fpSlow,
        bitSlow,
        bitConservative
    );
}

private void subnormalCharacterization(T, int kind)()
{
    const T tiny =
        T.min_normal / cast(T)2;

    const XyzD65!T[6] values = [
        XyzD65!T(tiny, cast(T)0, cast(T)0),
        XyzD65!T(cast(T)0, tiny, cast(T)0),
        XyzD65!T(cast(T)0, cast(T)0, tiny),
        XyzD65!T(-tiny, tiny, cast(T)0),
        XyzD65!T(tiny, -tiny, tiny),
        XyzD65!T(-tiny, -tiny, -tiny)
    ];

    size_t mismatches = 0;

    foreach (xyz; values)
    {
        const auto expected =
            xyz.toLinearSRgb;

        const auto actual =
            path!(T, kind)(xyz);

        if (
            actual.r != expected.r ||
            actual.g != expected.g ||
            actual.b != expected.b
        )
        {
            ++mismatches;
        }
    }

    writefln(
        "%s %s subnormal characterization: samples=%s exact_mismatches=%s",
        is(T == double) ? "double" : "float",
        pathName!kind,
        values.length,
        mismatches
    );
}

enum benchCount = 8_192;
enum repetitions = 1_000;
enum rounds = 9;

private double timePath(T, int kind)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. repetitions)
    foreach (value; values)
    {
        const auto result =
            path!(T, kind)(value);

        checksum +=
            result.r +
            result.g +
            result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * repetitions);
}

private double median(double[rounds] values)
{
    foreach (i; 1 .. values.length)
    {
        const double key = values[i];
        size_t j = i;

        while (j > 0 && values[j - 1] > key)
        {
            values[j] = values[j - 1];
            --j;
        }

        values[j] = key;
    }

    return values[values.length / 2];
}

private void benchmarkPair(T, int kind)(
    const(XyzD65!T)[] values
)
{
    double[rounds] ratios;
    T checksum = cast(T)0;

    foreach (round; 0 .. rounds)
    {
        double baselineNs;
        double candidateNs;

        if ((round & 1) == 0)
        {
            baselineNs =
                timePath!(T, 0)(values, checksum);

            candidateNs =
                timePath!(T, kind)(values, checksum);
        }
        else
        {
            candidateNs =
                timePath!(T, kind)(values, checksum);

            baselineNs =
                timePath!(T, 0)(values, checksum);
        }

        const double ratioValue =
            candidateNs / baselineNs;

        ratios[round] =
            ratioValue;

        writefln(
            "%s %s round %s: production=%.3f ns candidate=%.3f ns ratio=%.4f",
            is(T == double) ? "double" : "float",
            pathName!kind,
            round + 1,
            baselineNs,
            candidateNs,
            ratioValue
        );
    }

    writefln(
        "%s %s median_ratio=%.4f checksum=%s",
        is(T == double) ? "double" : "float",
        pathName!kind,
        median(ratios),
        checksum
    );
}

private void benchmarkAll(T)()
{
    XyzD65!T[benchCount] values;
    uint state = 0xC01D_0085U;

    foreach (ref value; values)
    {
        value =
            XyzD65!T(
                ordinaryValue!T(state),
                ordinaryValue!T(state),
                ordinaryValue!T(state)
            );
    }

    benchmarkPair!(T, 1)(values[]);
    benchmarkPair!(T, 2)(values[]);
    benchmarkPair!(T, 3)(values[]);
    benchmarkPair!(T, 4)(values[]);
    benchmarkPair!(T, 5)(values[]);
    benchmarkPair!(T, 6)(values[]);
    benchmarkPair!(T, 7)(values[]);
    benchmarkPair!(T, 8)(values[]);
    benchmarkPair!(T, 9)(values[]);
    benchmarkPair!(T, 10)(values[]);
    benchmarkPair!(T, 11)(values[]);
    benchmarkPair!(T, 12)(values[]);
    benchmarkPair!(T, 13)(values[]);
    benchmarkPair!(T, 14)(values[]);
    benchmarkPair!(T, 15)(values[]);
    benchmarkPair!(T, 16)(values[]);
}

// CTFE must retain the ordinary public result exactly for pre-gated candidates.
enum ctfeInput =
    XyzD65!double(0.25, 0.40, 0.10);

enum ctfeProduction =
    ctfeInput.toLinearSRgb;

enum ctfeFpGate =
    fpGate(ctfeInput);

enum ctfeBitGate =
    bitGate(ctfeInput);

static assert(ctfeFpGate == ctfeProduction);
static assert(ctfeBitGate == ctfeProduction);

int main()
{
    writeln("=== color-d XYZ -> linear-sRGB extreme gate audit ===");
    writefln(
        "real.sizeof=%s real.mant_dig=%s real.max_exp=%s",
        real.sizeof,
        real.mant_dig,
        real.max_exp
    );

    foreach (kind; 1 .. 7)
    {
        // Compile-time dispatch is required for path specialization, so this
        // loop is only a visual separator; actual calls remain explicit below.
    }

    gateInstrumentation!double();
    gateInstrumentation!float();

    ordinaryMismatches!(double, 1)();
    ordinaryMismatches!(double, 2)();
    ordinaryMismatches!(double, 3)();
    ordinaryMismatches!(double, 4)();
    ordinaryMismatches!(double, 5)();
    ordinaryMismatches!(double, 6)();
    ordinaryMismatches!(double, 7)();
    ordinaryMismatches!(double, 8)();
    ordinaryMismatches!(double, 9)();
    ordinaryMismatches!(double, 10)();
    ordinaryMismatches!(double, 11)();
    ordinaryMismatches!(double, 12)();
    ordinaryMismatches!(double, 13)();
    ordinaryMismatches!(double, 14)();
    ordinaryMismatches!(double, 15)();
    ordinaryMismatches!(double, 16)();

    ordinaryMismatches!(float, 1)();
    ordinaryMismatches!(float, 2)();
    ordinaryMismatches!(float, 3)();
    ordinaryMismatches!(float, 4)();
    ordinaryMismatches!(float, 5)();
    ordinaryMismatches!(float, 6)();
    ordinaryMismatches!(float, 7)();
    ordinaryMismatches!(float, 8)();
    ordinaryMismatches!(float, 9)();
    ordinaryMismatches!(float, 10)();
    ordinaryMismatches!(float, 11)();
    ordinaryMismatches!(float, 12)();
    ordinaryMismatches!(float, 13)();
    ordinaryMismatches!(float, 14)();
    ordinaryMismatches!(float, 15)();
    ordinaryMismatches!(float, 16)();

    subnormalCharacterization!(double, 2)();
    subnormalCharacterization!(double, 3)();
    subnormalCharacterization!(double, 6)();
    subnormalCharacterization!(double, 7)();
    subnormalCharacterization!(double, 8)();
    subnormalCharacterization!(double, 9)();
    subnormalCharacterization!(double, 10)();
    subnormalCharacterization!(double, 11)();
    subnormalCharacterization!(double, 12)();
    subnormalCharacterization!(double, 13)();
    subnormalCharacterization!(double, 14)();
    subnormalCharacterization!(double, 15)();
    subnormalCharacterization!(double, 16)();

    subnormalCharacterization!(float, 2)();
    subnormalCharacterization!(float, 3)();
    subnormalCharacterization!(float, 6)();
    subnormalCharacterization!(float, 7)();
    subnormalCharacterization!(float, 8)();
    subnormalCharacterization!(float, 9)();
    subnormalCharacterization!(float, 10)();
    subnormalCharacterization!(float, 11)();
    subnormalCharacterization!(float, 12)();
    subnormalCharacterization!(float, 13)();
    subnormalCharacterization!(float, 14)();
    subnormalCharacterization!(float, 15)();
    subnormalCharacterization!(float, 16)();

    extremeAvoidable!(double, 0)();
    extremeAvoidable!(double, 1)();
    extremeAvoidable!(double, 2)();
    extremeAvoidable!(double, 3)();
    extremeAvoidable!(double, 4)();
    extremeAvoidable!(double, 5)();
    extremeAvoidable!(double, 6)();
    extremeAvoidable!(double, 7)();
    extremeAvoidable!(double, 8)();
    extremeAvoidable!(double, 9)();
    extremeAvoidable!(double, 10)();
    extremeAvoidable!(double, 11)();
    extremeAvoidable!(double, 12)();
    extremeAvoidable!(double, 13)();
    extremeAvoidable!(double, 14)();
    extremeAvoidable!(double, 15)();
    extremeAvoidable!(double, 16)();

    extremeAvoidable!(float, 0)();
    extremeAvoidable!(float, 1)();
    extremeAvoidable!(float, 2)();
    extremeAvoidable!(float, 3)();
    extremeAvoidable!(float, 4)();
    extremeAvoidable!(float, 5)();
    extremeAvoidable!(float, 6)();
    extremeAvoidable!(float, 7)();
    extremeAvoidable!(float, 8)();
    extremeAvoidable!(float, 9)();
    extremeAvoidable!(float, 10)();
    extremeAvoidable!(float, 11)();
    extremeAvoidable!(float, 12)();
    extremeAvoidable!(float, 13)();
    extremeAvoidable!(float, 14)();
    extremeAvoidable!(float, 15)();
    extremeAvoidable!(float, 16)();

    version (LDC)
    {
        benchmarkAll!double();
        benchmarkAll!float();
    }

    return 0;
}
