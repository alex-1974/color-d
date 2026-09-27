// Isolated finalist benchmark for XYZ D65 -> linear-sRGB extreme-finite hardening.
//
// Build exactly one candidate into each executable with one of:
//   -d-version=CandidateResultGate
//   -d-version=CandidateRowScaled
//   -d-version=CandidateInfinityBounds
//   -d-version=CandidateInfinityBoundsBitwise
//   -d-version=CandidateBitMax
//   -d-version=CandidateDominantFactor
//   -d-version=CandidateRowScaledMinimal
//
// Keeping one candidate per binary avoids code-layout and optimizer-context
// interference from the broad exploratory probe.

module xyz_linear_rgb_finalist_probe;

import color :
    LinearSRgb,
    XyzD65,
    toLinearSRgb;

import std.datetime.stopwatch : StopWatch;
import std.math : fma;
import std.stdio : writefln, writeln;

template ReferenceScalar(T)
{
    static if (is(T == float))
        alias ReferenceScalar = double;
    else
        alias ReferenceScalar = real;
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

private T magnitude(T)(T value)
{
    return value < cast(T)0 ? -value : value;
}

private T maximum(T)(T first, T second)
{
    return first > second ? first : second;
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

private LinearSRgb!T candidateDominantFactor(T)(XyzD65!T xyz)
{
    /*
     * Exact rational refactorization of each inverse-matrix row around its
     * dominant coefficient:
     *
     * R = (12831/3959) * (X - 37/78 Y - 2/13 Z)
     * G = (1648619/878810) * (Y - 2589/5011 X + 111/5011 Z)
     * B = (705/667) * (Z + 1/19 X - 11/57 Y)
     *
     * Evaluate the two minor terms first. Their absolute coefficient sums are
     * below one, so their partial sums cannot overflow for finite XYZ. If the
     * final channel is representable, adding the dominant unscaled component
     * also has a representable exact result before the final multiplication.
     */
    const T redMinor =
       -ratio!T(37, 78) * xyz.y -
        ratio!T(2, 13) * xyz.z;

    const T greenMinor =
       -ratio!T(2589, 5011) * xyz.x +
        ratio!T(111, 5011) * xyz.z;

    const T blueMinor =
        ratio!T(1, 19) * xyz.x -
        ratio!T(11, 57) * xyz.y;

    return LinearSRgb!T(
        ratio!T(12831, 3959) *
            (redMinor + xyz.x),

        ratio!T(1648619, 878810) *
            (greenMinor + xyz.y),

        ratio!T(705, 667) *
            (blueMinor + xyz.z)
    );
}

private LinearSRgb!T candidateRowScaledMinimal(T)(XyzD65!T xyz)
{
    /*
     * Minimum power-of-two row factors with minor terms evaluated first.
     * Red needs 4; green and blue need 2.
     */
    enum T redScale = cast(T)4;
    enum T greenScale = cast(T)2;
    enum T blueScale = cast(T)2;

    const T redMinor =
        (ratio!T(-329, 214) / redScale) * xyz.y +
        (ratio!T(-1974, 3959) / redScale) * xyz.z;

    const T greenMinor =
        (ratio!T(-851781, 878810) / greenScale) * xyz.x +
        (ratio!T(36519, 878810) / greenScale) * xyz.z;

    const T blueMinor =
        (ratio!T(705, 12673) / blueScale) * xyz.x +
        (ratio!T(-2585, 12673) / blueScale) * xyz.y;

    return LinearSRgb!T(
        redScale * (
            redMinor +
            (ratio!T(12831, 3959) / redScale) * xyz.x
        ),
        greenScale * (
            greenMinor +
            (ratio!T(1648619, 878810) / greenScale) * xyz.y
        ),
        blueScale * (
            blueMinor +
            (ratio!T(705, 667) / blueScale) * xyz.z
        )
    );
}

private LinearSRgb!T candidateWiderWorking(T)(XyzD65!T xyz)
{
    alias R = ReferenceScalar!T;

    const R x = cast(R)xyz.x;
    const R y = cast(R)xyz.y;
    const R z = cast(R)xyz.z;

    return LinearSRgb!T(
        cast(T)(
            ratio!R(12831,    3959)   * x +
            ratio!R(-329,      214)   * y +
            ratio!R(-1974,    3959)   * z
        ),
        cast(T)(
            ratio!R(-851781, 878810)  * x +
            ratio!R(1648619, 878810)  * y +
            ratio!R(36519,   878810)  * z
        ),
        cast(T)(
            ratio!R(705,      12673)  * x +
            ratio!R(-2585,    12673)  * y +
            ratio!R(705,        667)  * z
        )
    );
}

private LinearSRgb!T candidateFma(T)(XyzD65!T xyz)
{
    const T redSafe =
        ratio!T(-1974, 3959) * xyz.z;

    const T greenSafe =
        ratio!T(36519, 878810) * xyz.z;

    const T blueSafe =
        ratio!T(705, 12673) * xyz.x;

    return LinearSRgb!T(
        fma(
            ratio!T(12831, 3959),
            xyz.x,
            fma(
                ratio!T(-329, 214),
                xyz.y,
                redSafe
            )
        ),
        fma(
            ratio!T(1648619, 878810),
            xyz.y,
            fma(
                ratio!T(-851781, 878810),
                xyz.x,
                greenSafe
            )
        ),
        fma(
            ratio!T(705, 667),
            xyz.z,
            fma(
                ratio!T(-2585, 12673),
                xyz.y,
                blueSafe
            )
        )
    );
}

private LinearSRgb!T candidateHybrid(T)(XyzD65!T xyz)
{
    static if (is(T == double))
        return candidateDominantFactor(xyz);
    else
        return candidateInfinityBounds(xyz);
}

private LinearSRgb!T candidateResultGate(T)(XyzD65!T xyz)
{
    const auto ordinary = xyz.toLinearSRgb;

    if (outputFinite(ordinary))
        return ordinary;

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T candidateRowScaled(T)(XyzD65!T xyz)
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

private bool finiteInfinityBounds(T)(T value)
{
    return
        value > -T.infinity &&
        value < T.infinity;
}

private LinearSRgb!T candidateInfinityBounds(T)(XyzD65!T xyz)
{
    const auto ordinary = xyz.toLinearSRgb;

    if (
        finiteInfinityBounds(ordinary.r) &&
        finiteInfinityBounds(ordinary.g) &&
        finiteInfinityBounds(ordinary.b)
    )
    {
        return ordinary;
    }

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T candidateBitMax(T)(XyzD65!T xyz)
{
    import std.conv : bitCast;

    const auto ordinary = xyz.toLinearSRgb;

    if (__ctfe)
    {
        if (outputFinite(ordinary))
            return ordinary;
    }
    else
    {
        static if (is(T == float))
        {
            alias U = uint;
            enum U signlessMask = 0x7FFF_FFFFU;
            enum U infinityBits = 0x7F80_0000U;
        }
        else
        {
            alias U = ulong;
            enum U signlessMask = 0x7FFF_FFFF_FFFF_FFFFUL;
            enum U infinityBits = 0x7FF0_0000_0000_0000UL;
        }

        const U rBits = bitCast!U(ordinary.r) & signlessMask;
        const U gBits = bitCast!U(ordinary.g) & signlessMask;
        const U bBits = bitCast!U(ordinary.b) & signlessMask;

        const U maxRG = rBits > gBits ? rBits : gBits;
        const U maxBits = maxRG > bBits ? maxRG : bBits;

        if (maxBits < infinityBits)
            return ordinary;
    }

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private LinearSRgb!T candidateInfinityBoundsBitwise(T)(XyzD65!T xyz)
{
    const auto ordinary = xyz.toLinearSRgb;

    const bool finiteResult =
        (ordinary.r > -T.infinity) &
        (ordinary.r <  T.infinity) &
        (ordinary.g > -T.infinity) &
        (ordinary.g <  T.infinity) &
        (ordinary.b > -T.infinity) &
        (ordinary.b <  T.infinity);

    if (finiteResult)
        return ordinary;

    if (!inputFinite(xyz))
        return ordinary;

    return scaledShared(xyz);
}

private const(char)[] candidateName()
{
    version (CandidateResultGate)
        return "result-gate";
    else version (CandidateRowScaled)
        return "row-scaled";
    else version (CandidateInfinityBounds)
        return "infinity-bounds";
    else version (CandidateInfinityBoundsBitwise)
        return "infinity-bounds-bitwise";
    else version (CandidateBitMax)
        return "bit-max";
    else version (CandidateDominantFactor)
        return "dominant-factor";
    else version (CandidateRowScaledMinimal)
        return "row-scaled-minimal";
    else version (CandidateWiderWorking)
        return "wider-working";
    else version (CandidateFma)
        return "fma";
    else version (CandidateHybrid)
        return "hybrid";
    else
        static assert(false, "select exactly one finalist version");
}

private LinearSRgb!T candidate(T)(XyzD65!T xyz)
{
    version (CandidateResultGate)
        return candidateResultGate(xyz);
    else version (CandidateRowScaled)
        return candidateRowScaled(xyz);
    else version (CandidateInfinityBounds)
        return candidateInfinityBounds(xyz);
    else version (CandidateInfinityBoundsBitwise)
        return candidateInfinityBoundsBitwise(xyz);
    else version (CandidateBitMax)
        return candidateBitMax(xyz);
    else version (CandidateDominantFactor)
        return candidateDominantFactor(xyz);
    else version (CandidateRowScaledMinimal)
        return candidateRowScaledMinimal(xyz);
    else version (CandidateWiderWorking)
        return candidateWiderWorking(xyz);
    else version (CandidateFma)
        return candidateFma(xyz);
    else version (CandidateHybrid)
        return candidateHybrid(xyz);
    else
        static assert(false, "select exactly one finalist version");
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
    return cast(T)(
        cast(ReferenceScalar!T)T.max *
        cast(ReferenceScalar!T)factor
    );
}

private void characterizeExtremeChannels(T)()
{
    alias R = ReferenceScalar!T;

    const double[9] factors = [
        -1.0, -0.75, -0.50, -0.25,
         0.0,
         0.25, 0.50, 0.75, 1.0
    ];

    size_t representable = 0;
    size_t redNonfinite = 0;
    size_t greenNonfinite = 0;
    size_t blueNonfinite = 0;
    size_t redOnly = 0;
    size_t greenOnly = 0;
    size_t blueOnly = 0;
    size_t multi = 0;

    foreach (fx; factors)
    foreach (fy; factors)
    foreach (fz; factors)
    {
        const auto xyz = XyzD65!T(
            scaledMax!T(fx),
            scaledMax!T(fy),
            scaledMax!T(fz)
        );

        const auto refValue = reference!(T, R)(xyz);
        if (!referenceFits!T(refValue))
            continue;

        ++representable;

        const auto actual = xyz.toLinearSRgb;
        const bool badR = !finite(actual.r);
        const bool badG = !finite(actual.g);
        const bool badB = !finite(actual.b);

        redNonfinite += badR;
        greenNonfinite += badG;
        blueNonfinite += badB;

        const uint badCount =
            cast(uint)badR +
            cast(uint)badG +
            cast(uint)badB;

        if (badCount == 1)
        {
            redOnly += badR;
            greenOnly += badG;
            blueOnly += badB;
        }
        else if (badCount > 1)
        {
            ++multi;
        }
    }

    writefln(
        "%s extreme channels: representable=%s r=%s g=%s b=%s r_only=%s g_only=%s b_only=%s multi=%s",
        is(T == double) ? "double" : "float",
        representable,
        redNonfinite,
        greenNonfinite,
        blueNonfinite,
        redOnly,
        greenOnly,
        blueOnly,
        multi
    );
}

private bool validateExtreme(T)()
{
    alias R = ReferenceScalar!T;

    const double[9] factors = [
        -1.0, -0.75, -0.50, -0.25,
         0.0,
         0.25, 0.50, 0.75, 1.0
    ];

    size_t representable = 0;
    size_t productionAvoidable = 0;
    size_t candidateAvoidable = 0;

    foreach (fx; factors)
    foreach (fy; factors)
    foreach (fz; factors)
    {
        const auto xyz = XyzD65!T(
            scaledMax!T(fx),
            scaledMax!T(fy),
            scaledMax!T(fz)
        );

        const auto refValue = reference!(T, R)(xyz);
        if (!referenceFits!T(refValue))
            continue;

        ++representable;

        if (!outputFinite(xyz.toLinearSRgb))
            ++productionAvoidable;

        if (!outputFinite(candidate(xyz)))
            ++candidateAvoidable;
    }

    writefln(
        "%s extreme: representable=%s production_avoidable=%s candidate_avoidable=%s",
        is(T == double) ? "double" : "float",
        representable,
        productionAvoidable,
        candidateAvoidable
    );

    return candidateAvoidable == 0;
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

enum validationSamples = 2_000_000;

private real referenceError(T, R)(T actual, R expected)
{
    const real diff =
        cast(real)actual -
        cast(real)expected;

    return diff < 0 ? -diff : diff;
}

private void updateAccuracy(
    T,
    R
)(
    T production,
    T candidateValue,
    R referenceValue,
    ref size_t candidateBetter,
    ref size_t equalError,
    ref size_t candidateWorse,
    ref real productionErrorSum,
    ref real candidateErrorSum,
    ref real productionMaxError,
    ref real candidateMaxError
)
{
    const real productionError =
        referenceError!(T, R)(
            production,
            referenceValue
        );

    const real candidateError =
        referenceError!(T, R)(
            candidateValue,
            referenceValue
        );

    productionErrorSum += productionError;
    candidateErrorSum += candidateError;

    if (productionError > productionMaxError)
        productionMaxError = productionError;

    if (candidateError > candidateMaxError)
        candidateMaxError = candidateError;

    if (candidateError < productionError)
        ++candidateBetter;
    else if (candidateError > productionError)
        ++candidateWorse;
    else
        ++equalError;
}

private void validateOrdinary(T)()
{
    alias R = ReferenceScalar!T;

    uint state = 0xC01D_0086U;
    size_t mismatches = 0;

    size_t candidateBetter = 0;
    size_t equalError = 0;
    size_t candidateWorse = 0;

    real productionErrorSum = 0;
    real candidateErrorSum = 0;
    real productionMaxError = 0;
    real candidateMaxError = 0;

    foreach (_; 0 .. validationSamples)
    {
        const auto xyz = XyzD65!T(
            ordinaryValue!T(state),
            ordinaryValue!T(state),
            ordinaryValue!T(state)
        );

        const auto production = xyz.toLinearSRgb;
        const auto actual = candidate(xyz);
        const auto refValue = reference!(T, R)(xyz);

        if (
            actual.r != production.r ||
            actual.g != production.g ||
            actual.b != production.b
        )
        {
            ++mismatches;
        }

        updateAccuracy!(
            T,
            R
        )(
            production.r,
            actual.r,
            refValue.r,
            candidateBetter,
            equalError,
            candidateWorse,
            productionErrorSum,
            candidateErrorSum,
            productionMaxError,
            candidateMaxError
        );

        updateAccuracy!(
            T,
            R
        )(
            production.g,
            actual.g,
            refValue.g,
            candidateBetter,
            equalError,
            candidateWorse,
            productionErrorSum,
            candidateErrorSum,
            productionMaxError,
            candidateMaxError
        );

        updateAccuracy!(
            T,
            R
        )(
            production.b,
            actual.b,
            refValue.b,
            candidateBetter,
            equalError,
            candidateWorse,
            productionErrorSum,
            candidateErrorSum,
            productionMaxError,
            candidateMaxError
        );
    }

    const real componentCount =
        cast(real)validationSamples * 3;

    writefln(
        "%s ordinary: samples=%s value_mismatches=%s",
        is(T == double) ? "double" : "float",
        validationSamples,
        mismatches
    );

    writefln(
        "%s reference-accuracy: better=%s equal=%s worse=%s prod_mean_abs=%s cand_mean_abs=%s prod_max_abs=%s cand_max_abs=%s",
        is(T == double) ? "double" : "float",
        candidateBetter,
        equalError,
        candidateWorse,
        productionErrorSum / componentCount,
        candidateErrorSum / componentCount,
        productionMaxError,
        candidateMaxError
    );
}

private void characterizeSubnormal(T)()
{
    alias R = ReferenceScalar!T;

    const T tiny = T.min_normal / cast(T)2;

    const XyzD65!T[8] values = [
        XyzD65!T(tiny, cast(T)0, cast(T)0),
        XyzD65!T(cast(T)0, tiny, cast(T)0),
        XyzD65!T(cast(T)0, cast(T)0, tiny),
        XyzD65!T(-tiny, tiny, cast(T)0),
        XyzD65!T(tiny, -tiny, tiny),
        XyzD65!T(-tiny, -tiny, -tiny),
        XyzD65!T(T.min_normal, tiny, -tiny),
        XyzD65!T(-T.min_normal, -tiny, tiny)
    ];

    size_t mismatches = 0;
    size_t candidateBetter = 0;
    size_t equalError = 0;
    size_t candidateWorse = 0;

    real productionErrorSum = 0;
    real candidateErrorSum = 0;
    real productionMaxError = 0;
    real candidateMaxError = 0;

    foreach (xyz; values)
    {
        const auto production = xyz.toLinearSRgb;
        const auto actual = candidate(xyz);
        const auto refValue = reference!(T, R)(xyz);

        if (
            actual.r != production.r ||
            actual.g != production.g ||
            actual.b != production.b
        )
        {
            ++mismatches;
        }

        updateAccuracy!(T, R)(
            production.r, actual.r, refValue.r,
            candidateBetter, equalError, candidateWorse,
            productionErrorSum, candidateErrorSum,
            productionMaxError, candidateMaxError
        );

        updateAccuracy!(T, R)(
            production.g, actual.g, refValue.g,
            candidateBetter, equalError, candidateWorse,
            productionErrorSum, candidateErrorSum,
            productionMaxError, candidateMaxError
        );

        updateAccuracy!(T, R)(
            production.b, actual.b, refValue.b,
            candidateBetter, equalError, candidateWorse,
            productionErrorSum, candidateErrorSum,
            productionMaxError, candidateMaxError
        );
    }

    writefln(
        "%s subnormal: samples=%s value_mismatches=%s better=%s equal=%s worse=%s prod_error_sum=%s cand_error_sum=%s prod_max_abs=%s cand_max_abs=%s",
        is(T == double) ? "double" : "float",
        values.length,
        mismatches,
        candidateBetter,
        equalError,
        candidateWorse,
        productionErrorSum,
        candidateErrorSum,
        productionMaxError,
        candidateMaxError
    );
}

private bool isNegativeZero(T)(T value)
{
    return
        value == cast(T)0 &&
        cast(T)1 / value == -T.infinity;
}

private void characterizeSignedZero(T)()
{
    const T positiveZero = cast(T)0;
    const T negativeZero = -cast(T)0;

    const XyzD65!T[8] values = [
        XyzD65!T(positiveZero, positiveZero, positiveZero),
        XyzD65!T(negativeZero, positiveZero, positiveZero),
        XyzD65!T(positiveZero, negativeZero, positiveZero),
        XyzD65!T(positiveZero, positiveZero, negativeZero),
        XyzD65!T(negativeZero, negativeZero, positiveZero),
        XyzD65!T(negativeZero, positiveZero, negativeZero),
        XyzD65!T(positiveZero, negativeZero, negativeZero),
        XyzD65!T(negativeZero, negativeZero, negativeZero)
    ];

    size_t signMismatches = 0;

    foreach (xyz; values)
    {
        const auto production = xyz.toLinearSRgb;
        const auto actual = candidate(xyz);

        signMismatches +=
            isNegativeZero(production.r) !=
            isNegativeZero(actual.r);

        signMismatches +=
            isNegativeZero(production.g) !=
            isNegativeZero(actual.g);

        signMismatches +=
            isNegativeZero(production.b) !=
            isNegativeZero(actual.b);
    }

    writefln(
        "%s signed-zero: components=%s sign_mismatches=%s",
        is(T == double) ? "double" : "float",
        values.length * 3,
        signMismatches
    );
}

private bool sameClassification(T)(T first, T second)
{
    if (first != first)
        return second != second;

    if (first == T.infinity)
        return second == T.infinity;

    if (first == -T.infinity)
        return second == -T.infinity;

    return finite(second);
}

private void characterizeNonFinite(T)()
{
    const T nan = T.nan;
    const T inf = T.infinity;

    const XyzD65!T[8] values = [
        XyzD65!T(nan, cast(T)0, cast(T)0),
        XyzD65!T(cast(T)0, nan, cast(T)0),
        XyzD65!T(cast(T)0, cast(T)0, nan),
        XyzD65!T(inf, cast(T)0, cast(T)0),
        XyzD65!T(-inf, cast(T)0, cast(T)0),
        XyzD65!T(cast(T)0, inf, cast(T)0),
        XyzD65!T(cast(T)0, cast(T)0, -inf),
        XyzD65!T(inf, -inf, nan)
    ];

    size_t classificationMismatches = 0;

    foreach (xyz; values)
    {
        const auto expected = xyz.toLinearSRgb;
        const auto actual = candidate(xyz);

        if (
            !sameClassification(expected.r, actual.r) ||
            !sameClassification(expected.g, actual.g) ||
            !sameClassification(expected.b, actual.b)
        )
        {
            ++classificationMismatches;
        }
    }

    writefln(
        "%s nonfinite: samples=%s classification_mismatches=%s",
        is(T == double) ? "double" : "float",
        values.length,
        classificationMismatches
    );
}

enum benchCount = 16_384;
enum repetitions = 800;
enum rounds = 13;

private double timeProduction(T)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. repetitions)
    foreach (value; values)
    {
        const auto result = value.toLinearSRgb;
        checksum += result.r + result.g + result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * repetitions);
}

private double timeCandidate(T)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. repetitions)
    foreach (value; values)
    {
        const auto result = candidate(value);
        checksum += result.r + result.g + result.b;
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

private void benchmark(T)()
{
    XyzD65!T[benchCount] values;
    uint state = 0xC01D_0087U;

    foreach (ref value; values)
    {
        value = XyzD65!T(
            ordinaryValue!T(state),
            ordinaryValue!T(state),
            ordinaryValue!T(state)
        );
    }

    double[rounds] ratios;
    T checksum = cast(T)0;

    foreach (round; 0 .. rounds)
    {
        double productionNs;
        double candidateNs;

        if ((round & 1) == 0)
        {
            productionNs = timeProduction(values[], checksum);
            candidateNs = timeCandidate(values[], checksum);
        }
        else
        {
            candidateNs = timeCandidate(values[], checksum);
            productionNs = timeProduction(values[], checksum);
        }

        ratios[round] = candidateNs / productionNs;

        writefln(
            "%s round %s: production=%.4f ns candidate=%.4f ns ratio=%.5f",
            is(T == double) ? "double" : "float",
            round + 1,
            productionNs,
            candidateNs,
            ratios[round]
        );
    }

    writefln(
        "%s median_ratio=%.5f checksum=%s",
        is(T == double) ? "double" : "float",
        median(ratios),
        checksum
    );
}

enum ctfeInput = XyzD65!double(0.25, 0.40, 0.10);
enum ctfeProduction = ctfeInput.toLinearSRgb;
enum ctfeCandidate = candidate(ctfeInput);

// Finalists must remain CTFE-capable. Exact equality is measured rather than
// required here because algebraically equivalent evaluation orders can differ
// by ordinary floating-point rounding.
static assert(ctfeCandidate.r == ctfeCandidate.r);
static assert(ctfeCandidate.g == ctfeCandidate.g);
static assert(ctfeCandidate.b == ctfeCandidate.b);

int main()
{
    writeln("=== XYZ -> linear-sRGB isolated finalist ===");
    writeln("candidate=", candidateName());

    bool ok = true;
    validateOrdinary!double();
    validateOrdinary!float();
    characterizeSubnormal!double();
    characterizeSubnormal!float();
    characterizeSignedZero!double();
    characterizeSignedZero!float();
    characterizeNonFinite!double();
    characterizeNonFinite!float();
    characterizeExtremeChannels!double();
    characterizeExtremeChannels!float();
    ok = validateExtreme!double() && ok;
    ok = validateExtreme!float() && ok;

    benchmark!double();
    benchmark!float();

    return ok ? 0 : 1;
}
