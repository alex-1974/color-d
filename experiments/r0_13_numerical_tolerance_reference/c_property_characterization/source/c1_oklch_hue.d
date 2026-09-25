module c1_oklch_hue;

import common : metricHypot, reportAngle, reportScalar;
import std.math : PI, atan2, cos, sin, sqrt;
import std.math.traits : isNaN;
import std.stdio : writefln, writeln;
import std.traits : Unqual, isFloatingPoint;

struct Oklab(T)
if (isFloatingPoint!T)
{
    T l;
    T a;
    T b;
}

struct Oklch(T)
if (isFloatingPoint!T)
{
    T l;
    T c;
    T hDegrees;
}

private T radiansToDegrees(T)(T radians) @safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    return radians * cast(T)(180.0L / PI);
}

private T degreesToRadians(T)(T degrees) @safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    return degrees * cast(T)(PI / 180.0L);
}

private Unqual!T normalizePositiveDegrees(T)(T degrees)
@safe pure nothrow @nogc
if (isFloatingPoint!(Unqual!T))
{
    alias U = Unqual!T;
    U result = cast(U)degrees;

    // atan2-derived input is in approximately [-180, 180].
    if (result < cast(U)0)
        result += cast(U)360;
    else if (result >= cast(U)360)
        result -= cast(U)360;

    return result;
}

private real normalizePositiveDegreesReal(real degrees)
@safe pure nothrow @nogc
{
    if (degrees < 0.0L)
        degrees += 360.0L;
    else if (degrees >= 360.0L)
        degrees -= 360.0L;

    return degrees;
}

/** R0.5 source form retained only as a comparison target. */
T legacyChroma(T)(T a, T b) @safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    return cast(T)sqrt(a * a + b * b);
}

/** Candidate chroma using the frontend-2.111-compatible two-argument hypot. */
T candidateChroma(T)(T a, T b) @safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    return metricHypot(a, b);
}

Oklch!T toOklchCandidate(T)(Oklab!T color)
@safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    if (color.a == cast(T)0 && color.b == cast(T)0)
    {
        return Oklch!T(
            color.l,
            cast(T)0,
            cast(T)0
        );
    }

    const T chroma = candidateChroma(color.a, color.b);
    const T radians = cast(T)atan2(color.b, color.a);
    const T hue = normalizePositiveDegrees(radiansToDegrees(radians));

    return Oklch!T(color.l, chroma, hue);
}

Oklab!T toOklabCandidate(T)(Oklch!T color)
@safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    const T radians = degreesToRadians(color.hDegrees);

    return Oklab!T(
        color.l,
        color.c * cast(T)cos(radians),
        color.c * cast(T)sin(radians)
    );
}

private real referenceHypot2(real x, real y)
@safe pure nothrow @nogc
{
    import core.math : fabs;

    const real ax = fabs(x);
    const real ay = fabs(y);

    if (ax == real.infinity || ay == real.infinity)
        return real.infinity;

    if (ax.isNaN || ay.isNaN)
        return real.nan;

    const real scale = ax >= ay ? ax : ay;
    if (scale == 0.0L)
        return 0.0L;

    const real sx = ax / scale;
    const real sy = ay / scale;
    return scale * sqrt(sx * sx + sy * sy);
}

struct ReferenceOklch
{
    real l;
    real c;
    real hDegrees;
}

struct ReferenceOklab
{
    real l;
    real a;
    real b;
}

ReferenceOklch referenceToOklch(T)(Oklab!T color)
@safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    const real l = cast(real)color.l;
    const real a = cast(real)color.a;
    const real b = cast(real)color.b;

    if (a == 0.0L && b == 0.0L)
        return ReferenceOklch(l, 0.0L, 0.0L);

    const real c = referenceHypot2(a, b);
    const real h = normalizePositiveDegreesReal(
        atan2(b, a) * (180.0L / PI)
    );

    return ReferenceOklch(l, c, h);
}

ReferenceOklab referenceToOklab(T)(Oklch!T color)
@safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    const real l = cast(real)color.l;
    const real c = cast(real)color.c;
    const real radians = cast(real)color.hDegrees * (PI / 180.0L);

    return ReferenceOklab(
        l,
        c * cos(radians),
        c * sin(radians)
    );
}

private void reportForward(T)(string name, Oklab!T input)
if (isFloatingPoint!T)
{
    const auto actual = toOklchCandidate(input);
    const auto reference = referenceToOklch(input);

    reportScalar(name ~ " L", actual.l, reference.l);
    reportScalar(name ~ " C", actual.c, reference.c);
    reportAngle(name ~ " h", actual.hDegrees, reference.hDegrees);
}

private void reportRoundTrip(T)(string name, Oklab!T input)
if (isFloatingPoint!T)
{
    const auto polar = toOklchCandidate(input);
    const auto back = toOklabCandidate(polar);

    reportScalar(name ~ " roundtrip L", back.l, cast(real)input.l);
    reportScalar(name ~ " roundtrip a", back.a, cast(real)input.a);
    reportScalar(name ~ " roundtrip b", back.b, cast(real)input.b);
}

private void reportInverse(T)(string name, Oklch!T input)
if (isFloatingPoint!T)
{
    const auto actual = toOklabCandidate(input);
    const auto reference = referenceToOklab(input);

    reportScalar(name ~ " inverse L", actual.l, reference.l);
    reportScalar(name ~ " inverse a", actual.a, reference.a);
    reportScalar(name ~ " inverse b", actual.b, reference.b);
}

private void reportRange(T)(string scalarName)
if (isFloatingPoint!T)
{
    const T large = T.max / cast(T)2;
    const T smallest = T.min_normal * T.epsilon;

    writefln("-- C1 RANGE %s --", scalarName);

    reportScalar(
        "C1-RANGE-" ~ scalarName ~ "-large-pair-legacy",
        legacyChroma(large, large),
        referenceHypot2(cast(real)large, cast(real)large)
    );
    reportScalar(
        "C1-RANGE-" ~ scalarName ~ "-large-pair-candidate",
        candidateChroma(large, large),
        referenceHypot2(cast(real)large, cast(real)large)
    );

    reportScalar(
        "C1-RANGE-" ~ scalarName ~ "-tiny-axis-legacy",
        legacyChroma(smallest, cast(T)0),
        cast(real)smallest
    );
    reportScalar(
        "C1-RANGE-" ~ scalarName ~ "-tiny-axis-candidate",
        candidateChroma(smallest, cast(T)0),
        cast(real)smallest
    );
    reportScalar(
        "C1-RANGE-" ~ scalarName ~ "-tiny-pair-candidate",
        candidateChroma(smallest, smallest),
        referenceHypot2(cast(real)smallest, cast(real)smallest)
    );
}

void runC1For(T)(string scalarName)
if (isFloatingPoint!T)
{
    writefln("=== C1 OKLAB <-> OKLCH / HUE (%s) ===", scalarName);

    const Oklab!T achromatic = Oklab!T(
        cast(T)0.42,
        cast(T)0,
        cast(T)0
    );
    const auto achromaticLch = toOklchCandidate(achromatic);

    writefln(
        "C1-EXACT-%s-achromatic = L:%s C:%s h:%s",
        scalarName,
        achromaticLch.l == achromatic.l,
        achromaticLch.c == cast(T)0,
        achromaticLch.hDegrees == cast(T)0
    );

    reportForward(
        "C1-REFERENCE-" ~ scalarName ~ "-plus-a-axis",
        Oklab!T(cast(T)0.6, cast(T)0.2, cast(T)0)
    );
    reportForward(
        "C1-REFERENCE-" ~ scalarName ~ "-plus-b-axis",
        Oklab!T(cast(T)0.6, cast(T)0, cast(T)0.2)
    );
    reportForward(
        "C1-REFERENCE-" ~ scalarName ~ "-minus-a-axis",
        Oklab!T(cast(T)0.6, cast(T)-0.2, cast(T)0)
    );
    reportForward(
        "C1-REFERENCE-" ~ scalarName ~ "-minus-b-axis",
        Oklab!T(cast(T)0.6, cast(T)0, cast(T)-0.2)
    );

    const Oklab!T ordinary = Oklab!T(
        cast(T)0.499568,
        cast(T)0.169354,
        cast(T)0.0447558
    );
    const Oklab!T extended = Oklab!T(
        cast(T)1.2,
        cast(T)-0.35,
        cast(T)0.42
    );

    reportForward("C1-REFERENCE-" ~ scalarName ~ "-ordinary", ordinary);
    reportForward("C1-REFERENCE-" ~ scalarName ~ "-extended", extended);

    reportRoundTrip("C1-DERIVED-" ~ scalarName ~ "-ordinary", ordinary);
    reportRoundTrip("C1-DERIVED-" ~ scalarName ~ "-extended", extended);

    reportInverse(
        "C1-REFERENCE-" ~ scalarName ~ "-inverse-30",
        Oklch!T(cast(T)0.6, cast(T)0.2, cast(T)30)
    );
    reportInverse(
        "C1-REFERENCE-" ~ scalarName ~ "-inverse-390",
        Oklch!T(cast(T)0.6, cast(T)0.2, cast(T)390)
    );

    reportRange!T(scalarName);
    writeln();
}

// CTFE smoke checks cover the compatibility path and exact-achromatic branch.
enum double ctfeSmallestD = double.min_normal * double.epsilon;
static assert(candidateChroma(3.0, 4.0) == 5.0);
static assert(candidateChroma(ctfeSmallestD, 0.0) == ctfeSmallestD);

enum ctfeAchromaticD = toOklchCandidate(Oklab!double(0.42, 0.0, 0.0));
static assert(ctfeAchromaticD.l == 0.42);
static assert(ctfeAchromaticD.c == 0.0);
static assert(ctfeAchromaticD.hDegrees == 0.0);
