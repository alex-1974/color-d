// Extreme-finite conversion closure characterization.
//
// This experiment compares the production float/double conversion routes with
// a wider reference evaluation. It specifically counts cases where:
//   1. every input component is finite;
//   2. the wider mathematical reference result is representable in T;
//   3. production nevertheless produces NaN or infinity.
//
// Such a case is avoidable intermediate overflow/cancellation, not unavoidable
// output overflow.
//
// Experiment code only. It does not define public API policy.

module extreme_conversion_closure_probe;

import color :
    LinearSRgb,
    Oklab,
    XyzD65,
    toLinearSRgb,
    toOklab,
    toXyzD65;

import std.datetime.stopwatch : StopWatch;
import std.math : cbrt;
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

private bool representableAs(T, R)(R value)
{
    return
        value == value &&
        value <= cast(R)T.max &&
        value >= -cast(R)T.max;
}

private struct Ref3(R)
{
    R x;
    R y;
    R z;
}

private Ref3!R rgbToXyzReference(T, R)(LinearSRgb!T rgb)
{
    const R r = cast(R)rgb.r;
    const R g = cast(R)rgb.g;
    const R b = cast(R)rgb.b;

    return Ref3!R(
        ratio!R(506752, 1228815) * r +
        ratio!R(87881,   245763) * g +
        ratio!R(12673,    70218) * b,

        ratio!R(87098,   409605) * r +
        ratio!R(175762,  245763) * g +
        ratio!R(12673,   175545) * b,

        ratio!R(7918,    409605) * r +
        ratio!R(87881,   737289) * g +
        ratio!R(1001167, 1053270) * b
    );
}

private Ref3!R xyzToRgbReference(T, R)(XyzD65!T xyz)
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

private Ref3!R xyzToOklabReference(T, R)(XyzD65!T xyz)
{
    const R x = cast(R)xyz.x;
    const R y = cast(R)xyz.y;
    const R z = cast(R)xyz.z;

    const R l =
        cast(R)0.8190224379967030L * x +
        cast(R)0.3619062600528904L * y -
        cast(R)0.1288737815209879L * z;

    const R m =
        cast(R)0.0329836539323885L * x +
        cast(R)0.9292868615863434L * y +
        cast(R)0.0361446663506424L * z;

    const R s =
        cast(R)0.0481771893596242L * x +
        cast(R)0.2642395317527308L * y +
        cast(R)0.6335478284694309L * z;

    const R lp = cbrt(l);
    const R mp = cbrt(m);
    const R sp = cbrt(s);

    return Ref3!R(
        cast(R)0.2104542683093140L * lp +
        cast(R)0.7936177747023054L * mp -
        cast(R)0.0040720430116193L * sp,

        cast(R)1.9779985324311684L * lp -
        cast(R)2.4285922420485799L * mp +
        cast(R)0.4505937096174110L * sp,

        cast(R)0.0259040424655478L * lp +
        cast(R)0.7827717124575296L * mp -
        cast(R)0.8086757549230774L * sp
    );
}

private R cube(R)(R value)
{
    return value * value * value;
}

private Ref3!R oklabToXyzReference(T, R)(Oklab!T lab)
{
    const R l0 = cast(R)lab.l;
    const R a0 = cast(R)lab.a;
    const R b0 = cast(R)lab.b;

    const R lp =
        l0 +
        cast(R)0.3963377773761749L * a0 +
        cast(R)0.2158037573099136L * b0;

    const R mp =
        l0 -
        cast(R)0.1055613458156586L * a0 -
        cast(R)0.0638541728258133L * b0;

    const R sp =
        l0 -
        cast(R)0.0894841775298119L * a0 -
        cast(R)1.2914855480194092L * b0;

    const R l = cube(lp);
    const R m = cube(mp);
    const R s = cube(sp);

    return Ref3!R(
        cast(R)1.2268798758459243L * l -
        cast(R)0.5578149944602171L * m +
        cast(R)0.2813910456659647L * s,

       -cast(R)0.0405757452148008L * l +
        cast(R)1.1122868032803170L * m -
        cast(R)0.0717110580655164L * s,

       -cast(R)0.0763729366746601L * l -
        cast(R)0.4214933324022432L * m +
        cast(R)1.5869240198367816L * s
    );
}

private T magnitude(T)(T value)
{
    return value < cast(T)0 ? -value : value;
}

private T maximum(T)(T first, T second)
{
    return first > second ? first : second;
}

private T dot3Candidate(T)(
    T a,
    T x,
    T b,
    T y,
    T c,
    T z
)
{
    const T ordinary =
        a * x +
        b * y +
        c * z;

    if (
        finite(ordinary) ||
        !finite(x) ||
        !finite(y) ||
        !finite(z)
    )
    {
        return ordinary;
    }

    const T scale =
        maximum(
            magnitude(x),
            maximum(
                magnitude(y),
                magnitude(z)
            )
        );

    if (scale == cast(T)0)
        return ordinary;

    return
        scale *
        (
            a * (x / scale) +
            b * (y / scale) +
            c * (z / scale)
        );
}

private LinearSRgb!T xyzToRgbCandidate(T)(XyzD65!T xyz)
{
    /*
     * Conservative fast-path gate.
     *
     * The largest absolute row sum of the inverse sRGB matrix is the red row.
     * If every input magnitude is at most T.max / rowAbsSum, then every
     * product and every partial sum is bounded by T.max.
     */
    enum T rowAbsSum =
        cast(T)12831 / cast(T)3959 +
        cast(T)329 / cast(T)214 +
        cast(T)1974 / cast(T)3959;

    enum T safeInputMagnitude =
        T.max / rowAbsSum;

    if (
        magnitude(xyz.x) <= safeInputMagnitude &&
        magnitude(xyz.y) <= safeInputMagnitude &&
        magnitude(xyz.z) <= safeInputMagnitude
    )
    {
        return xyz.toLinearSRgb;
    }

    return LinearSRgb!T(
        dot3Candidate(
            cast(T)12831 / cast(T)3959, xyz.x,
            cast(T)-329 / cast(T)214, xyz.y,
            cast(T)-1974 / cast(T)3959, xyz.z
        ),
        dot3Candidate(
            cast(T)-851781 / cast(T)878810, xyz.x,
            cast(T)1648619 / cast(T)878810, xyz.y,
            cast(T)36519 / cast(T)878810, xyz.z
        ),
        dot3Candidate(
            cast(T)705 / cast(T)12673, xyz.x,
            cast(T)-2585 / cast(T)12673, xyz.y,
            cast(T)705 / cast(T)667, xyz.z
        )
    );
}

private Oklab!T xyzToOklabCandidate(T)(XyzD65!T xyz)
{
    /*
     * The first XYZ->LMS row has the largest absolute coefficient sum.
     * Below this conservative bound the ordinary LMS transform cannot
     * overflow through products or partial sums, so retain the production
     * path unchanged.
     */
    enum T lRowAbsSum =
        cast(T)0.8190224379967030 +
        cast(T)0.3619062600528904 +
        cast(T)0.1288737815209879;

    enum T safeInputMagnitude =
        T.max / lRowAbsSum;

    if (
        magnitude(xyz.x) <= safeInputMagnitude &&
        magnitude(xyz.y) <= safeInputMagnitude &&
        magnitude(xyz.z) <= safeInputMagnitude
    )
    {
        return xyz.toOklab;
    }

    if (
        !finite(xyz.x) ||
        !finite(xyz.y) ||
        !finite(xyz.z)
    )
    {
        return xyz.toOklab;
    }

    const T scale =
        maximum(
            magnitude(xyz.x),
            maximum(
                magnitude(xyz.y),
                magnitude(xyz.z)
            )
        );

    if (scale == cast(T)0)
        return xyz.toOklab;

    const T x = xyz.x / scale;
    const T y = xyz.y / scale;
    const T z = xyz.z / scale;

    const T l =
        cast(T)0.8190224379967030 * x +
        cast(T)0.3619062600528904 * y -
        cast(T)0.1288737815209879 * z;

    const T m =
        cast(T)0.0329836539323885 * x +
        cast(T)0.9292868615863434 * y +
        cast(T)0.0361446663506424 * z;

    const T s =
        cast(T)0.0481771893596242 * x +
        cast(T)0.2642395317527308 * y +
        cast(T)0.6335478284694309 * z;

    const T rootScale = cbrt(scale);

    const T lp = rootScale * cbrt(l);
    const T mp = rootScale * cbrt(m);
    const T sp = rootScale * cbrt(s);

    return Oklab!T(
        cast(T)0.2104542683093140 * lp +
        cast(T)0.7936177747023054 * mp -
        cast(T)0.0040720430116193 * sp,

        cast(T)1.9779985324311684 * lp -
        cast(T)2.4285922420485799 * mp +
        cast(T)0.4505937096174110 * sp,

        cast(T)0.0259040424655478 * lp +
        cast(T)0.7827717124575296 * mp -
        cast(T)0.8086757549230774 * sp
    );
}

private bool referenceFits(T, R)(Ref3!R value)
{
    return
        representableAs!T(value.x) &&
        representableAs!T(value.y) &&
        representableAs!T(value.z);
}

private bool productionFinite(T)(LinearSRgb!T value)
{
    return finite(value.r) && finite(value.g) && finite(value.b);
}

private bool productionFinite(T)(XyzD65!T value)
{
    return finite(value.x) && finite(value.y) && finite(value.z);
}

private bool productionFinite(T)(Oklab!T value)
{
    return finite(value.l) && finite(value.a) && finite(value.b);
}

private T scaledMax(T)(double factor)
{
    return cast(T)(cast(ReferenceScalar!T)T.max * cast(ReferenceScalar!T)factor);
}

private void auditLinearTransforms(T)(string scalarName)
{
    alias R = ReferenceScalar!T;

    const double[9] factors = [
        -1.0, -0.75, -0.50, -0.25,
         0.0,
         0.25, 0.50, 0.75, 1.0
    ];

    size_t rgbToXyzReferenceFinite = 0;
    size_t rgbToXyzAvoidable = 0;
    size_t xyzToRgbReferenceFinite = 0;
    size_t xyzToRgbAvoidable = 0;
    size_t xyzToRgbCandidateAvoidable = 0;
    size_t xyzToLabReferenceFinite = 0;
    size_t xyzToLabAvoidable = 0;
    size_t xyzToLabCandidateAvoidable = 0;

    foreach (fx; factors)
    foreach (fy; factors)
    foreach (fz; factors)
    {
        const T x = scaledMax!T(fx);
        const T y = scaledMax!T(fy);
        const T z = scaledMax!T(fz);

        const auto rgb = LinearSRgb!T(x, y, z);
        const auto rgbXyzRef = rgbToXyzReference!(T, R)(rgb);
        if (referenceFits!T(rgbXyzRef))
        {
            ++rgbToXyzReferenceFinite;
            if (!productionFinite(rgb.toXyzD65))
                ++rgbToXyzAvoidable;
        }

        const auto xyz = XyzD65!T(x, y, z);

        const auto xyzRgbRef = xyzToRgbReference!(T, R)(xyz);
        if (referenceFits!T(xyzRgbRef))
        {
            ++xyzToRgbReferenceFinite;
            if (!productionFinite(xyz.toLinearSRgb))
                ++xyzToRgbAvoidable;
            if (!productionFinite(xyzToRgbCandidate(xyz)))
                ++xyzToRgbCandidateAvoidable;
        }

        const auto xyzLabRef = xyzToOklabReference!(T, R)(xyz);
        if (referenceFits!T(xyzLabRef))
        {
            ++xyzToLabReferenceFinite;
            if (!productionFinite(xyz.toOklab))
                ++xyzToLabAvoidable;
            if (!productionFinite(xyzToOklabCandidate(xyz)))
                ++xyzToLabCandidateAvoidable;
        }
    }

    writefln(
        "%s LinearRGB->XYZ: representable=%s avoidable_nonfinite=%s",
        scalarName,
        rgbToXyzReferenceFinite,
        rgbToXyzAvoidable
    );

    writefln(
        "%s XYZ->LinearRGB: representable=%s production_avoidable=%s candidate_avoidable=%s",
        scalarName,
        xyzToRgbReferenceFinite,
        xyzToRgbAvoidable,
        xyzToRgbCandidateAvoidable
    );

    writefln(
        "%s XYZ->Oklab: representable=%s production_avoidable=%s candidate_avoidable=%s",
        scalarName,
        xyzToLabReferenceFinite,
        xyzToLabAvoidable,
        xyzToLabCandidateAvoidable
    );
}

private void auditOklabInverse(T)(string scalarName)
{
    alias R = ReferenceScalar!T;

    const R rootMax = cbrt(cast(R)T.max);
    const double[9] factors = [
        -2.0, -1.5, -1.0, -0.5,
         0.0,
         0.5, 1.0, 1.5, 2.0
    ];

    size_t referenceFinite = 0;
    size_t avoidable = 0;

    foreach (fl; factors)
    foreach (fa; factors)
    foreach (fb; factors)
    {
        const Oklab!T lab = Oklab!T(
            cast(T)(rootMax * cast(R)fl),
            cast(T)(rootMax * cast(R)fa),
            cast(T)(rootMax * cast(R)fb)
        );

        const auto reference =
            oklabToXyzReference!(T, R)(lab);

        if (referenceFits!T(reference))
        {
            ++referenceFinite;
            if (!productionFinite(lab.toXyzD65))
                ++avoidable;
        }
    }

    writefln(
        "%s Oklab->XYZ: representable=%s avoidable_nonfinite=%s",
        scalarName,
        referenceFinite,
        avoidable
    );
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

enum benchCount = 8_192;
enum rgbRepetitions = 1_000;
enum labRepetitions = 200;
enum benchRounds = 5;

private double timeRgbProduction(T)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. rgbRepetitions)
    foreach (value; values)
    {
        const auto result = value.toLinearSRgb;
        checksum += result.r + result.g + result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * rgbRepetitions);
}

private double timeRgbCandidate(T)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. rgbRepetitions)
    foreach (value; values)
    {
        const auto result = xyzToRgbCandidate(value);
        checksum += result.r + result.g + result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * rgbRepetitions);
}

private double timeLabProduction(T)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. labRepetitions)
    foreach (value; values)
    {
        const auto result = value.toOklab;
        checksum += result.l + result.a + result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * labRepetitions);
}

private double timeLabCandidate(T)(
    const(XyzD65!T)[] values,
    ref T checksum
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. labRepetitions)
    foreach (value; values)
    {
        const auto result = xyzToOklabCandidate(value);
        checksum += result.l + result.a + result.b;
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * labRepetitions);
}

private void benchmarkOrdinary(T)(string scalarName)
{
    XyzD65!T[benchCount] values;
    uint state = 0xC01D_0023U;

    foreach (ref value; values)
    {
        value =
            XyzD65!T(
                ordinaryValue!T(state),
                ordinaryValue!T(state),
                ordinaryValue!T(state)
            );
    }

    T checksum = cast(T)0;

    foreach (round; 0 .. benchRounds)
    {
        double rgbProduction;
        double rgbCandidate;
        double labProduction;
        double labCandidate;

        if ((round & 1) == 0)
        {
            rgbProduction =
                timeRgbProduction(values[], checksum);
            rgbCandidate =
                timeRgbCandidate(values[], checksum);
            labProduction =
                timeLabProduction(values[], checksum);
            labCandidate =
                timeLabCandidate(values[], checksum);
        }
        else
        {
            rgbCandidate =
                timeRgbCandidate(values[], checksum);
            rgbProduction =
                timeRgbProduction(values[], checksum);
            labCandidate =
                timeLabCandidate(values[], checksum);
            labProduction =
                timeLabProduction(values[], checksum);
        }

        writefln(
            "%s benchmark round %s RGB: production=%.3f ns candidate=%.3f ns candidate_over_production=%.4f",
            scalarName,
            round + 1,
            rgbProduction,
            rgbCandidate,
            rgbCandidate / rgbProduction
        );

        writefln(
            "%s benchmark round %s Oklab: production=%.3f ns candidate=%.3f ns candidate_over_production=%.4f",
            scalarName,
            round + 1,
            labProduction,
            labCandidate,
            labCandidate / labProduction
        );
    }

    writeln(
        scalarName,
        " benchmark checksum=",
        checksum
    );
}

int main()
{
    writeln("=== color-d extreme conversion closure audit ===");
    writefln(
        "real.sizeof=%s real.mant_dig=%s real.max_exp=%s",
        real.sizeof,
        real.mant_dig,
        real.max_exp
    );

    auditLinearTransforms!double("double");
    auditLinearTransforms!float("float");

    auditOklabInverse!double("double");
    auditOklabInverse!float("float");

    benchmarkOrdinary!double("double");
    benchmarkOrdinary!float("float");

    return 0;
}
