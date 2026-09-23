module app;

import core.stdc.stdio : printf;
import std.math : fabs, hypot, isNaN, sqrt;
import std.traits : isFloatingPoint;

/*
 * R0.10 research-only types.
 *
 * These are deliberately local to the experiment. They do not establish
 * production module layout or public API.
 */

template isColorScalar(T)
{
    enum isColorScalar =
        isFloatingPoint!T &&
        (is(T == float) || is(T == double));
}

struct Oklab(T)
if (isColorScalar!T)
{
    T l;
    T a;
    T b;
}

struct SRgb(T)
if (isColorScalar!T)
{
    T r;
    T g;
    T b;
}

/*
 * Direct Euclidean comparison candidate.
 *
 * Same scalar type, same explicit Oklab space.
 * Free-function form is naturally UFCS-capable.
 *
 * Retained to expose the range behavior of the straightforward squared-sum
 * implementation. R0.10 does not select this as the preferred candidate.
 */
T deltaEOKDirect(T)(Oklab!T lhs, Oklab!T rhs)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const T dl = lhs.l - rhs.l;
    const T da = lhs.a - rhs.a;
    const T db = lhs.b - rhs.b;

    return sqrt(dl * dl + da * da + db * db);
}


/*
 * Numerically robust research candidate.
 *
 * The direct Euclidean expression can overflow or underflow while squaring
 * finite components even when the final Euclidean norm is representable.
 *
 * Scaling by the largest absolute component avoids that intermediate range
 * loss. This is a research candidate only; it does not establish the
 * production implementation.
 */
T scaledNorm3(T)(T x, T y, T z)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const T ax = fabs(x);
    const T ay = fabs(y);
    const T az = fabs(z);

    if (isNaN(ax) || isNaN(ay) || isNaN(az))
        return T.nan;

    T scale = ax;

    if (ay > scale)
        scale = ay;

    if (az > scale)
        scale = az;

    if (scale == T.infinity)
        return T.infinity;

    if (scale == T(0))
        return T(0);

    const T sx = x / scale;
    const T sy = y / scale;
    const T sz = z / scale;

    return scale * sqrt(
        sx * sx +
        sy * sy +
        sz * sz
    );
}


T deltaEOKScaled(T)(Oklab!T lhs, Oklab!T rhs)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return scaledNorm3(
        lhs.l - rhs.l,
        lhs.a - rhs.a,
        lhs.b - rhs.b
    );
}


/*
 * Phobos research candidate.
 *
 * R0.10 tests whether the standard-library 3D hypot implementation gives the
 * required finite extended-range robustness while retaining the public API
 * contracts required by color-d.
 */
T deltaEOKHypotRaw(T)(Oklab!T lhs, Oklab!T rhs)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return hypot(
        lhs.l - rhs.l,
        lhs.a - rhs.a,
        lhs.b - rhs.b
    );
}


/*
 * Guarded Phobos candidate.
 *
 * color-d defines special-value propagation explicitly:
 *
 * - any NaN delta -> NaN
 * - otherwise any infinite delta -> +Inf
 * - otherwise use Phobos hypot for the finite Euclidean norm
 *
 * This avoids relying on baseline-specific special-value behavior of the
 * three-argument Phobos hypot implementation.
 */
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



/*
 * Independent experiment reference route.
 *
 * Compute in `real`, then compare the candidate result against the wider
 * intermediate route. This is not a standards source; it is an implementation-
 * independent numerical cross-check inside the experiment.
 */
real referenceDeltaEOK(T)(Oklab!T lhs, Oklab!T rhs)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const real dl = cast(real) lhs.l - cast(real) rhs.l;
    const real da = cast(real) lhs.a - cast(real) rhs.a;
    const real db = cast(real) lhs.b - cast(real) rhs.b;

    return sqrt(dl * dl + da * da + db * db);
}


bool approxEqual(T)(T actual, T expected, T tolerance)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return fabs(actual - expected) <= tolerance;
}


T absT(T)(T value)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return value < T(0) ? -value : value;
}


T propertyTolerance(T)()
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    static if (is(T == double))
        return T(1e-12);
    else
        return T(2e-5);
}


real referenceTolerance(T)(real referenceValue)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    real scale = fabs(referenceValue);

    if (scale < real(1))
        scale = real(1);

    /*
     * R0.10 operation-specific research tolerance.
     *
     * This is not yet the library-wide numerical tolerance policy.
     */
    return real(8) * cast(real) T.epsilon * scale;
}


/*
 * CTFE / UFCS validation.
 */

enum ctfeZeroD =
    Oklab!double(0.25, -0.10, 0.20)
        .deltaEOK(Oklab!double(0.25, -0.10, 0.20));

static assert(ctfeZeroD == 0.0);

enum ctfeThirteenD =
    Oklab!double(0.0, 0.0, 0.0)
        .deltaEOK(Oklab!double(3.0, 4.0, 12.0));

static assert(ctfeThirteenD == 13.0);

enum ctfeAxisF =
    Oklab!float(0.2f, -0.3f, 0.4f)
        .deltaEOK(Oklab!float(0.2f, -0.1f, 0.4f));

static assert(
    ctfeAxisF > 0.19999f &&
    ctfeAxisF < 0.20001f
);


/*
 * Explicitly preserve CTFE validation for raw three-argument Phobos hypot.
 *
 * Raw hypot is not the preferred complete deltaEOK implementation because
 * its observed special-value behavior does not match the R0.10 policy.
 * Its finite CTFE capability is nevertheless an independently validated
 * property used by the guarded candidate.
 */
enum ctfeRawHypotThirteenD =
    deltaEOKHypotRaw(
        Oklab!double(0.0, 0.0, 0.0),
        Oklab!double(3.0, 4.0, 12.0)
    );

static assert(ctfeRawHypotThirteenD == 13.0);


/*
 * CTFE validation of the preferred guarded candidate.
 */
enum ctfePreferredThirteenD =
    deltaEOK(
        Oklab!double(0.0, 0.0, 0.0),
        Oklab!double(3.0, 4.0, 12.0)
    );

static assert(ctfePreferredThirteenD == 13.0);


/*
 * Compile-time API-shape checks.
 */

static assert(__traits(compiles,
    deltaEOK(
        Oklab!double(0, 0, 0),
        Oklab!double(1, 1, 1)
    )
));

static assert(__traits(compiles,
    Oklab!double(0, 0, 0)
        .deltaEOK(Oklab!double(1, 1, 1))
));

/* Mixed scalar types are intentionally rejected. */
static assert(!__traits(compiles,
    deltaEOK(
        Oklab!float(0, 0, 0),
        Oklab!double(1, 1, 1)
    )
));

/* Wrong color spaces are intentionally rejected. */
static assert(!__traits(compiles,
    deltaEOK(
        SRgb!double(0, 0, 0),
        SRgb!double(1, 1, 1)
    )
));


struct Lcg
{
    ulong state;

    uint nextU32()
    @safe pure nothrow @nogc
    {
        state = state * 6364136223846793005UL + 1442695040888963407UL;
        return cast(uint)(state >> 32);
    }

    T uniformSigned(T)()
    @safe pure nothrow @nogc
    if (isColorScalar!T)
    {
        const T unit =
            cast(T)(nextU32()) /
            cast(T)(uint.max);

        /*
         * Deliberately extended Oklab research domain.
         *
         * Range approximately [-4, +4].
         */
        return unit * T(8) - T(4);
    }
}


struct PropertyReport(T)
{
    size_t samples;
    size_t failures;

    size_t identityFailures;
    size_t negativeFailures;
    size_t symmetryFailures;
    size_t referenceFailures;
    size_t triangleFailures;

    /*
     * Floating-point .init is NaN in D.
     *
     * These accumulator fields therefore require explicit zero
     * initialization; otherwise max tracking never advances.
     */
    T maxSymmetryDelta = T(0);
    T maxReferenceDelta = T(0);
    T maxTriangleSlack = T(0);

    T worstReferenceCandidate = T(0);
    real worstReferenceValue = real(0);
    real worstReferenceScale = real(0);
    real worstReferenceEpsilonUnits = real(0);
}


PropertyReport!T runProperties(T)(size_t samples)
@safe nothrow @nogc
if (isColorScalar!T)
{
    PropertyReport!T report;
    report.samples = samples;

    Lcg rng = Lcg(0x4f4b4c41425f5230UL);

    foreach (_; 0 .. samples)
    {
        const Oklab!T x = Oklab!T(
            rng.uniformSigned!T(),
            rng.uniformSigned!T(),
            rng.uniformSigned!T()
        );

        const Oklab!T y = Oklab!T(
            rng.uniformSigned!T(),
            rng.uniformSigned!T(),
            rng.uniformSigned!T()
        );

        const Oklab!T z = Oklab!T(
            rng.uniformSigned!T(),
            rng.uniformSigned!T(),
            rng.uniformSigned!T()
        );

        const T dxx = deltaEOK(x, x);
        const T dxy = deltaEOK(x, y);
        const T dyx = deltaEOK(y, x);

        const T symmetryDelta = absT!T(dxy - dyx);

        if (symmetryDelta > report.maxSymmetryDelta)
            report.maxSymmetryDelta = symmetryDelta;

        const real referenceValue = referenceDeltaEOK(x, y);
        const real referenceDeltaReal =
            fabs(cast(real) dxy - referenceValue);
        const T referenceDelta =
            cast(T) referenceDeltaReal;

        if (referenceDelta > report.maxReferenceDelta)
        {
            report.maxReferenceDelta = referenceDelta;
            report.worstReferenceCandidate = dxy;
            report.worstReferenceValue = referenceValue;

            real scale = fabs(referenceValue);
            if (scale < real(1))
                scale = real(1);

            report.worstReferenceScale = scale;
            report.worstReferenceEpsilonUnits =
                referenceDeltaReal /
                (cast(real) T.epsilon * scale);
        }

        const T dxz = deltaEOK(x, z);
        const T dzy = deltaEOK(z, y);

        /*
         * Triangle inequality:
         *
         * d(x,y) <= d(x,z) + d(z,y)
         *
         * Positive slack means candidate exceeded the RHS.
         */
        const T triangleSlack = dxy - (dxz + dzy);

        if (triangleSlack > report.maxTriangleSlack)
            report.maxTriangleSlack = triangleSlack;

        bool ok = true;

        if (dxx != T(0))
        {
            ++report.identityFailures;
            ok = false;
        }

        if (dxy < T(0))
        {
            ++report.negativeFailures;
            ok = false;
        }

        if (symmetryDelta > propertyTolerance!T())
        {
            ++report.symmetryFailures;
            ok = false;
        }

        if (referenceDeltaReal > referenceTolerance!T(referenceValue))
        {
            ++report.referenceFailures;
            ok = false;
        }

        if (triangleSlack > propertyTolerance!T())
        {
            ++report.triangleFailures;
            ok = false;
        }

        if (!ok)
            ++report.failures;
    }

    return report;
}


void printAnalyticalCases(T)(const(char)* scalarName)
if (isColorScalar!T)
{
    const Oklab!T origin = Oklab!T(0, 0, 0);

    const T axisL =
        deltaEOK(origin, Oklab!T(T(0.25), 0, 0));

    const T axisA =
        deltaEOK(origin, Oklab!T(0, T(-0.5), 0));

    const T axisB =
        deltaEOK(origin, Oklab!T(0, 0, T(1.75)));

    const T pythagorean =
        deltaEOK(origin, Oklab!T(T(3), T(4), T(12)));

    printf(
        "%s analytical:\n" ~
        "  axis L       = %.17g\n" ~
        "  axis a       = %.17g\n" ~
        "  axis b       = %.17g\n" ~
        "  3-4-12       = %.17g\n",
        scalarName,
        cast(double) axisL,
        cast(double) axisA,
        cast(double) axisB,
        cast(double) pythagorean
    );

    assert(approxEqual(axisL, T(0.25), propertyTolerance!T()));
    assert(approxEqual(axisA, T(0.5), propertyTolerance!T()));
    assert(approxEqual(axisB, T(1.75), propertyTolerance!T()));
    assert(approxEqual(pythagorean, T(13), propertyTolerance!T()));
}


void printExtendedCase(T)(const(char)* scalarName)
if (isColorScalar!T)
{
    const Oklab!T a =
        Oklab!T(T(-2.0), T(3.5), T(-4.25));

    const Oklab!T b =
        Oklab!T(T(1.75), T(-2.0), T(5.5));

    const T d = deltaEOK(a, b);

    printf(
        "%s extended finite = %.17g\n",
        scalarName,
        cast(double) d
    );

    assert(d > T(0));
}


void printMixedSpecialCases(T)(const(char)* scalarName)
if (isColorScalar!T)
{
    const T nan = T.nan;
    const T inf = T.infinity;

    const Oklab!T origin =
        Oklab!T(0, 0, 0);

    const Oklab!T infNan =
        Oklab!T(inf, nan, 0);

    const Oklab!T negInfNan =
        Oklab!T(-inf, nan, 0);

    const Oklab!T nanFinite =
        Oklab!T(nan, T(1), T(2));

    const T directInfNan =
        deltaEOKDirect(origin, infNan);
    const T scaledInfNan =
        deltaEOKScaled(origin, infNan);
    const T hypotInfNan =
        deltaEOKHypotRaw(origin, infNan);

    const T directNegInfNan =
        deltaEOKDirect(origin, negInfNan);
    const T scaledNegInfNan =
        deltaEOKScaled(origin, negInfNan);
    const T hypotNegInfNan =
        deltaEOKHypotRaw(origin, negInfNan);

    const T directNanFinite =
        deltaEOKDirect(origin, nanFinite);
    const T scaledNanFinite =
        deltaEOKScaled(origin, nanFinite);
    const T hypotNanFinite =
        deltaEOKHypotRaw(origin, nanFinite);

    printf(
        "%s mixed special values:\n" ~
        "  +Inf+NaN direct isNaN = %d\n" ~
        "  +Inf+NaN scaled isNaN = %d\n" ~
        "  +Inf+NaN hypot  isNaN = %d\n" ~
        "  +Inf+NaN hypot  isInf = %d\n" ~
        "  -Inf+NaN direct isNaN = %d\n" ~
        "  -Inf+NaN scaled isNaN = %d\n" ~
        "  -Inf+NaN hypot  isNaN = %d\n" ~
        "  -Inf+NaN hypot  isInf = %d\n" ~
        "  NaN+finite direct isNaN = %d\n" ~
        "  NaN+finite scaled isNaN = %d\n" ~
        "  NaN+finite hypot  isNaN = %d\n",
        scalarName,
        cast(int) isNaN(directInfNan),
        cast(int) isNaN(scaledInfNan),
        cast(int) isNaN(hypotInfNan),
        cast(int)(hypotInfNan == inf),
        cast(int) isNaN(directNegInfNan),
        cast(int) isNaN(scaledNegInfNan),
        cast(int) isNaN(hypotNegInfNan),
        cast(int)(hypotNegInfNan == inf),
        cast(int) isNaN(directNanFinite),
        cast(int) isNaN(scaledNanFinite),
        cast(int) isNaN(hypotNanFinite)
    );
}



void printRobustnessCases(T)(const(char)* scalarName)
if (isColorScalar!T)
{
    const Oklab!T origin = Oklab!T(0, 0, 0);

    /*
     * One-axis vectors make the mathematically correct norm exact:
     *
     * norm(big, 0, 0)  = big
     * norm(tiny, 0, 0) = tiny
     *
     * The direct implementation nevertheless squares the component first.
     */
    const T big = T.max / T(4);
    const T tiny = T.min_normal;

    const Oklab!T bigPoint = Oklab!T(big, 0, 0);
    const Oklab!T tinyPoint = Oklab!T(tiny, 0, 0);

    const T directBig = deltaEOKDirect(origin, bigPoint);
    const T scaledBig = deltaEOKScaled(origin, bigPoint);
    const T hypotBig = deltaEOKHypotRaw(origin, bigPoint);
    const T preferredBig = deltaEOK(origin, bigPoint);

    const T directTiny = deltaEOKDirect(origin, tinyPoint);
    const T scaledTiny = deltaEOKScaled(origin, tinyPoint);
    const T hypotTiny = deltaEOKHypotRaw(origin, tinyPoint);
    const T preferredTiny = deltaEOK(origin, tinyPoint);

    const T normalDirect =
        deltaEOKDirect(
            origin,
            Oklab!T(T(3), T(4), T(12))
        );

    const T normalScaled =
        deltaEOKScaled(
            origin,
            Oklab!T(T(3), T(4), T(12))
        );

    const T normalHypot =
        deltaEOKHypotRaw(
            origin,
            Oklab!T(T(3), T(4), T(12))
        );

    printf(
        "%s range robustness:\n" ~
        "  big                  = %.17g\n" ~
        "  direct(big)          = %.17g\n" ~
        "  scaled(big)          = %.17g\n" ~
        "  hypot(big)           = %.17g\n" ~
        "  preferred(big)       = %.17g\n" ~
        "  direct-big-is-inf    = %d\n" ~
        "  tiny                 = %.17g\n" ~
        "  direct(tiny)         = %.17g\n" ~
        "  scaled(tiny)         = %.17g\n" ~
        "  hypot(tiny)          = %.17g\n" ~
        "  preferred(tiny)      = %.17g\n" ~
        "  direct-tiny-is-zero  = %d\n" ~
        "  normal direct        = %.17g\n" ~
        "  normal scaled        = %.17g\n" ~
        "  normal hypot         = %.17g\n",
        scalarName,
        cast(double) big,
        cast(double) directBig,
        cast(double) scaledBig,
        cast(double) hypotBig,
        cast(double) preferredBig,
        cast(int)(directBig == T.infinity),
        cast(double) tiny,
        cast(double) directTiny,
        cast(double) scaledTiny,
        cast(double) hypotTiny,
        cast(double) preferredTiny,
        cast(int)(directTiny == T(0)),
        cast(double) normalDirect,
        cast(double) normalScaled,
        cast(double) normalHypot
    );

    /*
     * Validate the robust candidate itself.
     *
     * We deliberately do not assert that the direct form must overflow or
     * underflow; that behavior is being observed across compilers/build modes.
     */
    assert(scaledBig == big);
    assert(scaledTiny == tiny);

    assert(hypotBig == big);
    assert(hypotTiny == tiny);

    assert(preferredBig == big);
    assert(preferredTiny == tiny);

    assert(approxEqual(
        normalScaled,
        T(13),
        propertyTolerance!T()
    ));

    assert(approxEqual(
        normalHypot,
        T(13),
        propertyTolerance!T()
    ));
    assert(approxEqual(
        normalDirect,
        normalScaled,
        propertyTolerance!T()
    ));
}



void printNonFiniteCases(T)(const(char)* scalarName)
if (isColorScalar!T)
{
    const T nan = T.nan;
    const T inf = T.infinity;

    const T withNaN =
        deltaEOK(
            Oklab!T(nan, 0, 0),
            Oklab!T(0, 0, 0)
        );

    const T withPosInf =
        deltaEOK(
            Oklab!T(inf, 0, 0),
            Oklab!T(0, 0, 0)
        );

    const T withNegInf =
        deltaEOK(
            Oklab!T(-inf, 0, 0),
            Oklab!T(0, 0, 0)
        );

    printf(
        "%s non-finite:\n" ~
        "  NaN isNaN = %d\n" ~
        "  +Inf       = %.17g\n" ~
        "  -Inf       = %.17g\n",
        scalarName,
        cast(int) isNaN(withNaN),
        cast(double) withPosInf,
        cast(double) withNegInf
    );

    /*
     * Preserve the baseline raw-Phobos observation separately from the
     * preferred guarded candidate. These are observations, not assertions:
     * compiler/build configurations may expose different raw hypot behavior.
     */
    const T rawWithNaN =
        deltaEOKHypotRaw(
            Oklab!T(nan, 0, 0),
            Oklab!T(0, 0, 0)
        );

    const T rawWithPosInf =
        deltaEOKHypotRaw(
            Oklab!T(inf, 0, 0),
            Oklab!T(0, 0, 0)
        );

    const T rawWithNegInf =
        deltaEOKHypotRaw(
            Oklab!T(-inf, 0, 0),
            Oklab!T(0, 0, 0)
        );

    printf(
        "%s raw hypot non-finite:\n" ~
        "  NaN isNaN = %d\n" ~
        "  +Inf isNaN = %d\n" ~
        "  +Inf isInf = %d\n" ~
        "  -Inf isNaN = %d\n" ~
        "  -Inf isInf = %d\n",
        scalarName,
        cast(int) isNaN(rawWithNaN),
        cast(int) isNaN(rawWithPosInf),
        cast(int)(rawWithPosInf == inf),
        cast(int) isNaN(rawWithNegInf),
        cast(int)(rawWithNegInf == inf)
    );

    assert(isNaN(withNaN));
    assert(withPosInf == inf);
    assert(withNegInf == inf);
}


void runScalar(T)(const(char)* scalarName)
if (isColorScalar!T)
{
    printAnalyticalCases!T(scalarName);
    printExtendedCase!T(scalarName);
    printNonFiniteCases!T(scalarName);
    printMixedSpecialCases!T(scalarName);
    printRobustnessCases!T(scalarName);

    enum sampleCount = 4096;

    const report =
        runProperties!T(sampleCount);

    printf(
        "%s generated properties:\n" ~
        "  samples              = %zu\n" ~
        "  failures             = %zu\n" ~
        "  identity failures    = %zu\n" ~
        "  negative failures    = %zu\n" ~
        "  symmetry failures    = %zu\n" ~
        "  reference failures   = %zu\n" ~
        "  triangle failures    = %zu\n" ~
        "  max symmetry delta   = %.17g\n" ~
        "  max reference delta  = %.17g\n" ~
        "  max triangle slack   = %.17g\n" ~
        "  worst candidate      = %.17g\n" ~
        "  worst reference      = %.21Lg\n" ~
        "  reference scale      = %.21Lg\n" ~
        "  epsilon units        = %.21Lg\n",
        scalarName,
        report.samples,
        report.failures,
        report.identityFailures,
        report.negativeFailures,
        report.symmetryFailures,
        report.referenceFailures,
        report.triangleFailures,
        cast(double) report.maxSymmetryDelta,
        cast(double) report.maxReferenceDelta,
        cast(double) report.maxTriangleSlack,
        cast(double) report.worstReferenceCandidate,
        report.worstReferenceValue,
        report.worstReferenceScale,
        report.worstReferenceEpsilonUnits
    );

    assert(report.failures == 0);
}


void main()
{
    printf("=== color-d R0.10 deltaEOK ===\n");

    printf(
        "CTFE:\n" ~
        "  double identity = %.17g\n" ~
        "  double 3-4-12   = %.17g\n" ~
        "  float axis      = %.17g\n",
        cast(double) ctfeZeroD,
        cast(double) ctfeThirteenD,
        cast(double) ctfeAxisF
    );

    runScalar!double("double");
    runScalar!float("float");

    printf("R0.10 correctness spike: PASS\n");
}
