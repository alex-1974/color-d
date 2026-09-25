module c3_interpolation;

import common : reportScalar;
import std.stdio : writefln, writeln;


private enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


struct LinearSRgb(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}


struct OklabHue(T)
if (isColorScalar!T)
{
    T degrees;

    T positiveDegrees() const
    @safe pure nothrow @nogc
    {
        T value = degrees % cast(T)360;

        if (value < cast(T)0)
            value += cast(T)360;

        if (value >= cast(T)360)
            value -= cast(T)360;

        return value;
    }
}


struct Oklch(T)
if (isColorScalar!T)
{
    T l;
    T c;
    OklabHue!T h;
}


struct Alpha(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}


enum HuePath : ubyte
{
    shorter,
    longer,
    increasing,
    decreasing
}


struct HueEndpoints(T)
if (isColorScalar!T)
{
    T first;
    T second;
}


T legacyLerp(T)(T a, T b, T t)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return a + (b - a) * t;
}


T endpointAwareLerp(T)(T a, T b, T t)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    if (t == cast(T)0)
        return a;

    if (t == cast(T)1)
        return b;

    return legacyLerp(a, b, t);
}


private real referenceLerp(T)(T a, T b, T t)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const real ar = cast(real)a;
    const real br = cast(real)b;
    const real tr = cast(real)t;

    return ar + (br - ar) * tr;
}


HueEndpoints!T adjustedHueEndpoints(T)(
    OklabHue!T first,
    OklabHue!T second,
    HuePath path
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    T h1 = first.positiveDegrees();
    T h2 = second.positiveDegrees();
    const T delta = h2 - h1;

    final switch (path)
    {
        case HuePath.shorter:
            if (delta > cast(T)180)
                h1 += cast(T)360;
            else if (delta < cast(T)-180)
                h2 += cast(T)360;
            break;

        case HuePath.longer:
            if (delta > cast(T)0 &&
                delta < cast(T)180)
            {
                h1 += cast(T)360;
            }
            else if (delta > cast(T)-180 &&
                     delta <= cast(T)0)
            {
                h2 += cast(T)360;
            }
            break;

        case HuePath.increasing:
            if (h2 < h1)
                h2 += cast(T)360;
            break;

        case HuePath.decreasing:
            if (h1 < h2)
                h1 += cast(T)360;
            break;
    }

    return HueEndpoints!T(h1, h2);
}


OklabHue!T interpolateHue(T)(
    OklabHue!T first,
    OklabHue!T second,
    T t,
    HuePath path
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const adjusted =
        adjustedHueEndpoints(first, second, path);

    return OklabHue!T(
        legacyLerp(adjusted.first, adjusted.second, t)
    );
}


private real referenceHue(T)(
    OklabHue!T first,
    OklabHue!T second,
    T t,
    HuePath path
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const adjusted =
        adjustedHueEndpoints(first, second, path);

    return referenceLerp(
        adjusted.first,
        adjusted.second,
        t
    );
}


Oklch!T canonicalized(T)(Oklch!T color)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    if (color.c < cast(T)0)
    {
        color.c = -color.c;
        color.h.degrees += cast(T)180;
    }

    return color;
}


Oklch!T interpolateOklch(T)(
    Oklch!T first,
    Oklch!T second,
    T t,
    HuePath path
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    first = canonicalized(first);
    second = canonicalized(second);

    auto h1 = first.h;
    auto h2 = second.h;

    if (first.c == cast(T)0 &&
        second.c != cast(T)0)
    {
        h1 = h2;
    }
    else if (second.c == cast(T)0 &&
             first.c != cast(T)0)
    {
        h2 = h1;
    }

    return Oklch!T(
        legacyLerp(first.l, second.l, t),
        legacyLerp(first.c, second.c, t),
        interpolateHue(h1, h2, t, path)
    );
}


Alpha!(LinearSRgb!T) interpolateAlphaLinear(T)(
    Alpha!(LinearSRgb!T) first,
    Alpha!(LinearSRgb!T) second,
    T t
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    T alpha =
        legacyLerp(first.alpha, second.alpha, t);

    T r = legacyLerp(
        first.color.r * first.alpha,
        second.color.r * second.alpha,
        t
    );
    T g = legacyLerp(
        first.color.g * first.alpha,
        second.color.g * second.alpha,
        t
    );
    T b = legacyLerp(
        first.color.b * first.alpha,
        second.color.b * second.alpha,
        t
    );

    if (alpha != cast(T)0)
    {
        r /= alpha;
        g /= alpha;
        b /= alpha;
    }

    return Alpha!(LinearSRgb!T)(
        LinearSRgb!T(r, g, b),
        alpha
    );
}


private void reportExactCases(T)(string scalarName)
if (isColorScalar!T)
{
    const T a = cast(T)0.25;
    const T b = cast(T)0.75;

    writefln(
        "C3-EXACT-%s-selected-endpoints = t0:%s t1:%s",
        scalarName,
        legacyLerp(a, b, cast(T)0) == a,
        legacyLerp(a, b, cast(T)1) == b
    );

    const auto shorter = interpolateHue(
        OklabHue!T(cast(T)350),
        OklabHue!T(cast(T)10),
        cast(T)0.5,
        HuePath.shorter
    );
    const auto longer = interpolateHue(
        OklabHue!T(cast(T)350),
        OklabHue!T(cast(T)10),
        cast(T)0.5,
        HuePath.longer
    );
    const auto increasing = interpolateHue(
        OklabHue!T(cast(T)350),
        OklabHue!T(cast(T)10),
        cast(T)0.5,
        HuePath.increasing
    );
    const auto decreasing = interpolateHue(
        OklabHue!T(cast(T)350),
        OklabHue!T(cast(T)10),
        cast(T)0.5,
        HuePath.decreasing
    );

    writefln(
        "C3-EXACT-%s-hue-paths-350-10 = shorter:%s longer:%s increasing:%s decreasing:%s",
        scalarName,
        shorter.degrees == cast(T)360,
        longer.degrees == cast(T)180,
        increasing.degrees == cast(T)360,
        decreasing.degrees == cast(T)180
    );

    const auto tieShort = interpolateHue(
        OklabHue!T(cast(T)30),
        OklabHue!T(cast(T)210),
        cast(T)0.5,
        HuePath.shorter
    );
    const auto tieLong = interpolateHue(
        OklabHue!T(cast(T)30),
        OklabHue!T(cast(T)210),
        cast(T)0.5,
        HuePath.longer
    );

    writefln(
        "C3-EXACT-%s-hue-180-tie = shorter:%s longer:%s",
        scalarName,
        tieShort.degrees == cast(T)120,
        tieLong.degrees == cast(T)120
    );

    const auto equalShorter = interpolateHue(
        OklabHue!T(cast(T)30),
        OklabHue!T(cast(T)390),
        cast(T)0.5,
        HuePath.shorter
    );
    const auto equalLonger = interpolateHue(
        OklabHue!T(cast(T)30),
        OklabHue!T(cast(T)390),
        cast(T)0.5,
        HuePath.longer
    );

    writefln(
        "C3-EXACT-%s-equal-normalized-hues = shorter:%s longer:%s",
        scalarName,
        equalShorter.degrees == cast(T)30,
        equalLonger.degrees == cast(T)210
    );

    const auto achromaticMix = interpolateOklch(
        Oklch!T(
            cast(T)0.25,
            cast(T)0,
            OklabHue!T(cast(T)10)
        ),
        Oklch!T(
            cast(T)0.75,
            cast(T)0.25,
            OklabHue!T(cast(T)200)
        ),
        cast(T)0.5,
        HuePath.shorter
    );

    writefln(
        "C3-EXACT-%s-achromatic-hue-borrow = %s",
        scalarName,
        achromaticMix.h.degrees == cast(T)200
    );

    const auto canonicalMix = interpolateOklch(
        Oklch!T(
            cast(T)0.5,
            cast(T)-0.25,
            OklabHue!T(cast(T)30)
        ),
        Oklch!T(
            cast(T)0.5,
            cast(T)0.25,
            OklabHue!T(cast(T)210)
        ),
        cast(T)0.5,
        HuePath.shorter
    );

    writefln(
        "C3-EXACT-%s-negative-chroma-canonicalization = c:%s h:%s",
        scalarName,
        canonicalMix.c == cast(T)0.25,
        canonicalMix.h.degrees == cast(T)210
    );

    const auto alphaVisible = interpolateAlphaLinear(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)1,
                cast(T)0,
                cast(T)0
            ),
            cast(T)1
        ),
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)0,
                cast(T)0,
                cast(T)1
            ),
            cast(T)0
        ),
        cast(T)0.5
    );

    writefln(
        "C3-EXACT-%s-alpha-hidden-color = alpha:%s r:%s g:%s b:%s",
        scalarName,
        alphaVisible.alpha == cast(T)0.5,
        alphaVisible.color.r == cast(T)1,
        alphaVisible.color.g == cast(T)0,
        alphaVisible.color.b == cast(T)0
    );

    const auto alphaZero = interpolateAlphaLinear(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)1,
                cast(T)2,
                cast(T)3
            ),
            cast(T)0
        ),
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)-4,
                cast(T)-5,
                cast(T)-6
            ),
            cast(T)0
        ),
        cast(T)0.5
    );

    writefln(
        "C3-EXACT-%s-alpha-zero-no-divide = alpha:%s rgb-zero:%s",
        scalarName,
        alphaZero.alpha == cast(T)0,
        alphaZero.color == LinearSRgb!T(0, 0, 0)
    );
}


private void reportPolicyCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto exact = interpolateOklch(
        Oklch!T(
            cast(T)0.4,
            cast(T)0,
            OklabHue!T(cast(T)10)
        ),
        Oklch!T(
            cast(T)0.8,
            cast(T)0.2,
            OklabHue!T(cast(T)200)
        ),
        cast(T)0.5,
        HuePath.shorter
    );

    const auto near = interpolateOklch(
        Oklch!T(
            cast(T)0.4,
            T.epsilon,
            OklabHue!T(cast(T)10)
        ),
        Oklch!T(
            cast(T)0.8,
            cast(T)0.2,
            OklabHue!T(cast(T)200)
        ),
        cast(T)0.5,
        HuePath.shorter
    );

    writefln(
        "C3-POLICY-%s-near-achromatic-not-borrowed = exact:%s near:%s",
        scalarName,
        exact.h.degrees == cast(T)200,
        near.h.degrees != cast(T)200
    );

    reportScalar(
        "C3-POLICY-" ~ scalarName ~ "-near-achromatic-hue",
        near.h.degrees,
        cast(real)285
    );
}


private void reportReferenceCases(T)(string scalarName)
if (isColorScalar!T)
{
    const T a = cast(T)-0.2;
    const T b = cast(T)1.4;
    const T ordinaryT = cast(T)0.3;
    const T extrapolationT = cast(T)1.25;

    reportScalar(
        "C3-REFERENCE-" ~ scalarName ~ "-scalar-ordinary",
        legacyLerp(a, b, ordinaryT),
        referenceLerp(a, b, ordinaryT)
    );

    reportScalar(
        "C3-REFERENCE-" ~ scalarName ~ "-scalar-extrapolation",
        legacyLerp(a, b, extrapolationT),
        referenceLerp(a, b, extrapolationT)
    );

    const T hueT = cast(T)0.3;
    const auto hue = interpolateHue(
        OklabHue!T(cast(T)350),
        OklabHue!T(cast(T)10),
        hueT,
        HuePath.shorter
    );

    reportScalar(
        "C3-REFERENCE-" ~ scalarName ~ "-hue-shorter-350-10",
        hue.degrees,
        referenceHue(
            OklabHue!T(cast(T)350),
            OklabHue!T(cast(T)10),
            hueT,
            HuePath.shorter
        )
    );
}


private void reportDerivedCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto polar = interpolateOklch(
        Oklch!T(
            cast(T)0.4,
            cast(T)0.1,
            OklabHue!T(cast(T)350)
        ),
        Oklch!T(
            cast(T)0.8,
            cast(T)0.3,
            OklabHue!T(cast(T)10)
        ),
        cast(T)0.3,
        HuePath.shorter
    );

    reportScalar(
        "C3-DERIVED-" ~ scalarName ~ "-oklch-L",
        polar.l,
        referenceLerp(
            cast(T)0.4,
            cast(T)0.8,
            cast(T)0.3
        )
    );
    reportScalar(
        "C3-DERIVED-" ~ scalarName ~ "-oklch-C",
        polar.c,
        referenceLerp(
            cast(T)0.1,
            cast(T)0.3,
            cast(T)0.3
        )
    );
    reportScalar(
        "C3-DERIVED-" ~ scalarName ~ "-oklch-h",
        polar.h.degrees,
        referenceHue(
            OklabHue!T(cast(T)350),
            OklabHue!T(cast(T)10),
            cast(T)0.3,
            HuePath.shorter
        )
    );

    const auto alpha = interpolateAlphaLinear(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)-0.2,
                cast(T)0.4,
                cast(T)1.2
            ),
            cast(T)0.25
        ),
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)1.4,
                cast(T)-0.1,
                cast(T)0.3
            ),
            cast(T)0.75
        ),
        cast(T)0.3
    );

    const real alphaReference = referenceLerp(
        cast(T)0.25,
        cast(T)0.75,
        cast(T)0.3
    );
    const real rNumerator = referenceLerp(
        cast(T)-0.2 * cast(T)0.25,
        cast(T)1.4 * cast(T)0.75,
        cast(T)0.3
    );
    const real gNumerator = referenceLerp(
        cast(T)0.4 * cast(T)0.25,
        cast(T)-0.1 * cast(T)0.75,
        cast(T)0.3
    );
    const real bNumerator = referenceLerp(
        cast(T)1.2 * cast(T)0.25,
        cast(T)0.3 * cast(T)0.75,
        cast(T)0.3
    );

    reportScalar(
        "C3-DERIVED-" ~ scalarName ~ "-alpha-linear-r",
        alpha.color.r,
        rNumerator / alphaReference
    );
    reportScalar(
        "C3-DERIVED-" ~ scalarName ~ "-alpha-linear-g",
        alpha.color.g,
        gNumerator / alphaReference
    );
    reportScalar(
        "C3-DERIVED-" ~ scalarName ~ "-alpha-linear-b",
        alpha.color.b,
        bNumerator / alphaReference
    );
    reportScalar(
        "C3-DERIVED-" ~ scalarName ~ "-alpha-linear-alpha",
        alpha.alpha,
        alphaReference
    );
}


private void reportRangeCases(T)(string scalarName)
if (isColorScalar!T)
{
    const T a = -T.max;
    const T b = T.max;

    writeln("-- C3 RANGE ", scalarName, " --");

    reportScalar(
        "C3-RANGE-" ~ scalarName ~ "-legacy-endpoint-t0",
        legacyLerp(a, b, cast(T)0),
        referenceLerp(a, b, cast(T)0)
    );
    reportScalar(
        "C3-RANGE-" ~ scalarName ~ "-legacy-endpoint-t1",
        legacyLerp(a, b, cast(T)1),
        referenceLerp(a, b, cast(T)1)
    );
    reportScalar(
        "C3-RANGE-" ~ scalarName ~ "-legacy-midpoint",
        legacyLerp(a, b, cast(T)0.5),
        referenceLerp(a, b, cast(T)0.5)
    );

    const T candidate0 =
        endpointAwareLerp(a, b, cast(T)0);
    const T candidate1 =
        endpointAwareLerp(a, b, cast(T)1);

    writefln(
        "C3-RANGE-%s-endpoint-aware-exact = t0:%s t1:%s",
        scalarName,
        candidate0 == a,
        candidate1 == b
    );

    reportScalar(
        "C3-RANGE-" ~ scalarName ~ "-endpoint-aware-t0",
        candidate0,
        referenceLerp(a, b, cast(T)0)
    );
    reportScalar(
        "C3-RANGE-" ~ scalarName ~ "-endpoint-aware-t1",
        candidate1,
        referenceLerp(a, b, cast(T)1)
    );
}


void runC3For(T)(string scalarName)
if (isColorScalar!T)
{
    writeln();
    writeln(
        "=== C3 INTERPOLATION / HUE / ALPHA (",
        scalarName,
        ") ==="
    );

    reportExactCases!T(scalarName);
    reportPolicyCases!T(scalarName);
    reportReferenceCases!T(scalarName);
    reportDerivedCases!T(scalarName);
    reportRangeCases!T(scalarName);
}


enum ctfeEndpoint0 =
    endpointAwareLerp(-double.max, double.max, 0.0);
enum ctfeEndpoint1 =
    endpointAwareLerp(-double.max, double.max, 1.0);

static assert(ctfeEndpoint0 == -double.max);
static assert(ctfeEndpoint1 == double.max);

enum ctfeShorter = interpolateHue(
    OklabHue!double(350),
    OklabHue!double(10),
    0.5,
    HuePath.shorter
);
static assert(ctfeShorter.degrees == 360);

enum ctfeTie = interpolateHue(
    OklabHue!double(30),
    OklabHue!double(210),
    0.5,
    HuePath.shorter
);
static assert(ctfeTie.degrees == 120);

enum ctfeBorrow = interpolateOklch(
    Oklch!double(
        0.25,
        0.0,
        OklabHue!double(10)
    ),
    Oklch!double(
        0.75,
        0.25,
        OklabHue!double(200)
    ),
    0.5,
    HuePath.shorter
);
static assert(ctfeBorrow.h.degrees == 200);
