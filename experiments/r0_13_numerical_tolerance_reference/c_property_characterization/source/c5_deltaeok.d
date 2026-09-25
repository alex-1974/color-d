module c5_deltaeok;

import common : reportScalar, ulpDistance;
import std.math : fabs, hypot, isNaN, sqrt;
import std.stdio : writefln, writeln;
import std.traits : Unqual;


private enum bool isColorScalar(T) =
    is(Unqual!T == float) || is(Unqual!T == double);


struct Oklab(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T a;
    T b;
}


T deltaEOKDirect(T)(Oklab!T lhs, Oklab!T rhs)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const T dl = lhs.l - rhs.l;
    const T da = lhs.a - rhs.a;
    const T db = lhs.b - rhs.b;

    return sqrt(
        dl * dl +
        da * da +
        db * db
    );
}


T deltaEOKRawHypot(T)(Oklab!T lhs, Oklab!T rhs)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return hypot(
        lhs.l - rhs.l,
        lhs.a - rhs.a,
        lhs.b - rhs.b
    );
}


T deltaEOK(T)(Oklab!T lhs, Oklab!T rhs)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const T dl = lhs.l - rhs.l;
    const T da = lhs.a - rhs.a;
    const T db = lhs.b - rhs.b;

    if (isNaN(dl) || isNaN(da) || isNaN(db))
        return T.nan;

    if (fabs(dl) == T.infinity ||
        fabs(da) == T.infinity ||
        fabs(db) == T.infinity)
    {
        return T.infinity;
    }

    return hypot(dl, da, db);
}


private real scaledNorm3Real(
    real x,
    real y,
    real z
)
@safe pure nothrow @nogc
{
    const real ax = fabs(x);
    const real ay = fabs(y);
    const real az = fabs(z);

    if (isNaN(ax) || isNaN(ay) || isNaN(az))
        return real.nan;

    real scale = ax;

    if (ay > scale)
        scale = ay;

    if (az > scale)
        scale = az;

    if (scale == real.infinity)
        return real.infinity;

    if (scale == 0)
        return 0;

    const real sx = x / scale;
    const real sy = y / scale;
    const real sz = z / scale;

    return scale * sqrt(
        sx * sx +
        sy * sy +
        sz * sz
    );
}


private real referenceDeltaEOK(T)(
    Oklab!T lhs,
    Oklab!T rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return scaledNorm3Real(
        cast(real)lhs.l - cast(real)rhs.l,
        cast(real)lhs.a - cast(real)rhs.a,
        cast(real)lhs.b - cast(real)rhs.b
    );
}


private T smallestPositive(T)()
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return T.min_normal * T.epsilon;
}


private void reportExactCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto x = Oklab!T(
        cast(T)0.25,
        cast(T)-0.5,
        cast(T)1.75
    );

    const T identity = deltaEOK!T(x, x);

    const auto origin = Oklab!T(0, 0, 0);

    const T axisL = deltaEOK!T(
        origin,
        Oklab!T(cast(T)0.25, 0, 0)
    );
    const T axisA = deltaEOK!T(
        origin,
        Oklab!T(0, cast(T)-0.5, 0)
    );
    const T axisB = deltaEOK!T(
        origin,
        Oklab!T(0, 0, cast(T)1.75)
    );
    const T pythagorean = deltaEOK!T(
        origin,
        Oklab!T(
            cast(T)3,
            cast(T)4,
            cast(T)12
        )
    );

    const auto a = Oklab!T(
        cast(T)0.18,
        cast(T)-0.42,
        cast(T)0.73
    );
    const auto b = Oklab!T(
        cast(T)-0.11,
        cast(T)0.27,
        cast(T)-0.39
    );

    writefln(
        "C5-EXACT-%s-analytical = identity:%s axisL:%s axisA:%s axisB:%s pythagorean:%s symmetry:%s",
        scalarName,
        identity == cast(T)0,
        axisL == cast(T)0.25,
        axisA == cast(T)0.5,
        axisB == cast(T)1.75,
        pythagorean == cast(T)13,
        deltaEOK!T(a, b) == deltaEOK!T(b, a)
    );
}


private void reportSpecialCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto origin = Oklab!T(0, 0, 0);

    const T withNaN = deltaEOK!T(
        Oklab!T(T.nan, 0, 0),
        origin
    );
    const T withPosInf = deltaEOK!T(
        Oklab!T(T.infinity, 0, 0),
        origin
    );
    const T withNegInf = deltaEOK!T(
        Oklab!T(-T.infinity, 0, 0),
        origin
    );
    const T withInfNan = deltaEOK!T(
        Oklab!T(T.infinity, T.nan, 0),
        origin
    );

    writefln(
        "C5-CLASSIFY-%s-special = nan:%s posinf:%s neginf:%s infnan-nan:%s",
        scalarName,
        isNaN(withNaN),
        withPosInf == T.infinity,
        withNegInf == T.infinity,
        isNaN(withInfNan)
    );

    const T rawNaN = deltaEOKRawHypot!T(
        Oklab!T(T.nan, 0, 0),
        origin
    );
    const T rawInf = deltaEOKRawHypot!T(
        Oklab!T(T.infinity, 0, 0),
        origin
    );
    const T rawInfNan = deltaEOKRawHypot!T(
        Oklab!T(T.infinity, T.nan, 0),
        origin
    );

    writefln(
        "C5-DIAGNOSTIC-%s-raw-hypot-special = nan-isnan:%s inf-isinf:%s infnan-isnan:%s",
        scalarName,
        isNaN(rawNaN),
        rawInf == T.infinity,
        isNaN(rawInfNan)
    );
}


private void reportReferenceCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto ordinaryA = Oklab!T(
        cast(T)0.61,
        cast(T)0.17,
        cast(T)-0.08
    );
    const auto ordinaryB = Oklab!T(
        cast(T)0.22,
        cast(T)-0.09,
        cast(T)0.14
    );

    reportScalar(
        "C5-REFERENCE-" ~ scalarName ~ "-ordinary",
        deltaEOK!T(ordinaryA, ordinaryB),
        referenceDeltaEOK!T(ordinaryA, ordinaryB)
    );

    const auto extendedA = Oklab!T(
        cast(T)-2.0,
        cast(T)3.5,
        cast(T)-4.25
    );
    const auto extendedB = Oklab!T(
        cast(T)1.75,
        cast(T)-2.0,
        cast(T)5.5
    );

    reportScalar(
        "C5-REFERENCE-" ~ scalarName ~ "-extended",
        deltaEOK!T(extendedA, extendedB),
        referenceDeltaEOK!T(extendedA, extendedB)
    );
}


private void reportRangeCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto origin = Oklab!T(0, 0, 0);

    const T big = T.max / cast(T)4;
    const T normalTiny = T.min_normal;
    const T subnormalTiny = smallestPositive!T();

    const auto bigPoint = Oklab!T(big, 0, 0);
    const auto normalTinyPoint =
        Oklab!T(normalTiny, 0, 0);
    const auto subnormalTinyPoint =
        Oklab!T(subnormalTiny, 0, 0);

    writeln("-- C5 RANGE ", scalarName, " --");

    reportScalar(
        "C5-RANGE-" ~ scalarName ~ "-direct-big",
        deltaEOKDirect!T(origin, bigPoint),
        cast(real)big
    );
    reportScalar(
        "C5-RANGE-" ~ scalarName ~ "-preferred-big",
        deltaEOK!T(origin, bigPoint),
        cast(real)big
    );

    reportScalar(
        "C5-RANGE-" ~ scalarName ~ "-direct-min-normal",
        deltaEOKDirect!T(origin, normalTinyPoint),
        cast(real)normalTiny
    );
    reportScalar(
        "C5-RANGE-" ~ scalarName ~ "-preferred-min-normal",
        deltaEOK!T(origin, normalTinyPoint),
        cast(real)normalTiny
    );

    reportScalar(
        "C5-RANGE-" ~ scalarName ~ "-direct-smallest-subnormal",
        deltaEOKDirect!T(origin, subnormalTinyPoint),
        cast(real)subnormalTiny
    );
    reportScalar(
        "C5-RANGE-" ~ scalarName ~ "-preferred-smallest-subnormal",
        deltaEOK!T(origin, subnormalTinyPoint),
        cast(real)subnormalTiny
    );

    writefln(
        "C5-RANGE-%s-preferred-axis-exact = big:%s min-normal:%s subnormal:%s",
        scalarName,
        deltaEOK!T(origin, bigPoint) == big,
        deltaEOK!T(origin, normalTinyPoint) == normalTiny,
        deltaEOK!T(origin, subnormalTinyPoint) == subnormalTiny
    );
}


struct Lcg
{
    ulong state;

    uint nextU32()
    @safe pure nothrow @nogc
    {
        state =
            state * 6364136223846793005UL +
            1442695040888963407UL;

        return cast(uint)(state >> 32);
    }

    T uniformSigned(T)()
    @safe pure nothrow @nogc
    if (isColorScalar!T)
    {
        const T unit =
            cast(T)nextU32() /
            cast(T)uint.max;

        return unit * cast(T)8 - cast(T)4;
    }
}


private void reportGeneratedProperties(T)(
    string scalarName
)
if (isColorScalar!T)
{
    enum size_t samples = 4096;

    Lcg rng = Lcg(0x4f4b4c41425f5230UL);

    size_t identityFailures = 0;
    size_t negativeFailures = 0;
    size_t symmetryNonzero = 0;
    size_t trianglePositiveSlack = 0;

    real maxSymmetryAbs = 0;
    real maxReferenceAbs = 0;
    ulong maxReferenceUlp = 0;
    real maxTrianglePositiveSlack = 0;

    foreach (_; 0 .. samples)
    {
        const auto x = Oklab!T(
            rng.uniformSigned!T(),
            rng.uniformSigned!T(),
            rng.uniformSigned!T()
        );
        const auto y = Oklab!T(
            rng.uniformSigned!T(),
            rng.uniformSigned!T(),
            rng.uniformSigned!T()
        );
        const auto z = Oklab!T(
            rng.uniformSigned!T(),
            rng.uniformSigned!T(),
            rng.uniformSigned!T()
        );

        const T dxx = deltaEOK!T(x, x);
        const T dxy = deltaEOK!T(x, y);
        const T dyx = deltaEOK!T(y, x);

        if (dxx != cast(T)0)
            ++identityFailures;

        if (dxy < cast(T)0)
            ++negativeFailures;

        const real symmetryAbs =
            fabs(cast(real)dxy - cast(real)dyx);

        if (symmetryAbs != 0)
            ++symmetryNonzero;

        if (symmetryAbs > maxSymmetryAbs)
            maxSymmetryAbs = symmetryAbs;

        const real reference =
            referenceDeltaEOK!T(x, y);

        const real referenceAbs =
            fabs(cast(real)dxy - reference);

        if (referenceAbs > maxReferenceAbs)
            maxReferenceAbs = referenceAbs;

        const ulong referenceUlp =
            ulpDistance(dxy, reference);

        if (referenceUlp > maxReferenceUlp)
            maxReferenceUlp = referenceUlp;

        const T dxz = deltaEOK!T(x, z);
        const T dzy = deltaEOK!T(z, y);

        const real triangleSlack =
            cast(real)dxy -
            (
                cast(real)dxz +
                cast(real)dzy
            );

        if (triangleSlack > 0)
        {
            ++trianglePositiveSlack;

            if (triangleSlack >
                maxTrianglePositiveSlack)
            {
                maxTrianglePositiveSlack =
                    triangleSlack;
            }
        }
    }

    writefln(
        "C5-DERIVED-%s-properties samples=%s identity_failures=%s negative_failures=%s symmetry_nonzero=%s max_symmetry_abs=% .6e reference_max_abs=% .6e reference_max_ulp=%s triangle_positive_slack=%s triangle_max_positive_slack=% .6e",
        scalarName,
        samples,
        identityFailures,
        negativeFailures,
        symmetryNonzero,
        maxSymmetryAbs,
        maxReferenceAbs,
        maxReferenceUlp,
        trianglePositiveSlack,
        maxTrianglePositiveSlack
    );
}


void runC5For(T)(string scalarName)
if (isColorScalar!T)
{
    writeln();
    writeln(
        "=== C5 DELTAEOK (",
        scalarName,
        ") ==="
    );

    reportExactCases!T(scalarName);
    reportSpecialCases!T(scalarName);
    reportReferenceCases!T(scalarName);
    reportRangeCases!T(scalarName);
    reportGeneratedProperties!T(scalarName);
}


enum ctfeZero = deltaEOK(
    Oklab!double(0.25, -0.10, 0.20),
    Oklab!double(0.25, -0.10, 0.20)
);
static assert(ctfeZero == 0.0);

enum ctfeThirteen = deltaEOK(
    Oklab!double(0, 0, 0),
    Oklab!double(3, 4, 12)
);
static assert(ctfeThirteen == 13.0);
