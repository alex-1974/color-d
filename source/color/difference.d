/++
 Measure perceptual distance between Oklab colors.

 Use `deltaEOK` when both colors are already in Oklab and you need their
 Euclidean perceptual distance. The operation does not convert colors, resolve
 alpha, clip, gamut-map, or decide whether a difference is noticeable.
+/
module color.difference;

private import color.oklab :
    Oklab,
    Oklabf,
    Oklabd;

private import color.cielab :
    CieLabD50,
    CieLabD50f,
    CieLabD50d;

private import std.math :
    fabs,
    hypot,
    isNaN,
    atan2,
    cos,
    sin,
    exp2,
    PI;


/**
 * Measures the perceptual distance between two Oklab colors.
 *
 * Use this to compare colors that are already expressed in Oklab. A result of
 * zero means identical Oklab coordinates; larger values mean greater distance.
 * Finite extended coordinates are accepted. The operation performs no hidden
 * conversion, clipping, gamut mapping, alpha resolution, or just-noticeable
 * difference classification.
 *
 * NaN component differences produce NaN; otherwise any infinite component
 * difference produces positive infinity.
 *
 * Params:
 *     lhs = First Oklab color.
 *     rhs = Second Oklab color.
 *
 * Returns:
 *     The three-dimensional Euclidean distance in Oklab.
 *
 * Standards:
 *     DeltaEOK follows the Euclidean Oklab definition described by W3C CSS
 *     Color Module Level 4.
 */

T deltaEOK(T)(
    Oklab!T lhs,
    Oklab!T rhs
)
@safe pure nothrow @nogc
{
    const T dl = lhs.l - rhs.l;
    const T da = lhs.a - rhs.a;
    const T db = lhs.b - rhs.b;

    if (isNaN(dl) || isNaN(da) || isNaN(db))
        return T.nan;

    if (
        fabs(dl) == T.infinity ||
        fabs(da) == T.infinity ||
        fabs(db) == T.infinity
    )
    {
        return T.infinity;
    }

    return hypot(dl, da, db);
}

///
@safe pure nothrow @nogc unittest
{
    const origin = Oklabd(0, 0, 0);
    const sample = Oklabd(3, 4, 12);

    assert(origin.deltaEOK(sample) == 13);
}


version (unittest)
{
    private import color.alpha :
        Alpha;

    private import color.oklch :
        Oklchd;

    private import color.rgb :
        SRgbd,
        LinearSRgbd;

    private import color.xyz :
        XyzD65d;

    private import std.math :
        sqrt;


    // The operation is deliberately same-space and same-scalar.
    static assert(!__traits(compiles,
        deltaEOK(
            Oklabf(0, 0, 0),
            Oklabd(1, 1, 1)
        )
    ));

    static assert(!__traits(compiles,
        deltaEOK(
            SRgbd(0, 0, 0),
            SRgbd(1, 1, 1)
        )
    ));

    static assert(!__traits(compiles,
        deltaEOK(
            LinearSRgbd(0, 0, 0),
            LinearSRgbd(1, 1, 1)
        )
    ));

    static assert(!__traits(compiles,
        deltaEOK(
            XyzD65d(0, 0, 0),
            XyzD65d(1, 1, 1)
        )
    ));

    static assert(!__traits(compiles,
        deltaEOK(
            Oklchd.init,
            Oklchd.init
        )
    ));

    // Alpha resolution remains a separate caller policy.
    static assert(!__traits(compiles,
        deltaEOK(
            Alpha!Oklabd(
                Oklabd(0, 0, 0),
                1
            ),
            Alpha!Oklabd(
                Oklabd(1, 1, 1),
                1
            )
        )
    ));


    // Exact analytical reference cases.
    enum originD = Oklabd(0, 0, 0);

    static assert(
        deltaEOK(
            originD,
            Oklabd(0.25, 0, 0)
        ) == 0.25
    );

    static assert(
        deltaEOK(
            originD,
            Oklabd(0, -0.5, 0)
        ) == 0.5
    );

    static assert(
        deltaEOK(
            originD,
            Oklabd(0, 0, 1.75)
        ) == 1.75
    );

    static assert(
        deltaEOK(
            originD,
            Oklabd(3, 4, 12)
        ) == 13
    );

    // Identity and UFCS are CTFE-capable.
    enum identityD =
        Oklabd(0.25, -0.10, 0.20)
            .deltaEOK(
                Oklabd(0.25, -0.10, 0.20)
            );

    static assert(identityD == 0);


    // Exercise the float path independently.
    enum originF = Oklabf(0, 0, 0);

    static assert(
        deltaEOK(
            originF,
            Oklabf(3, 4, 12)
        ) == 13
    );

    static assert(
        Oklabf(0.2f, -0.3f, 0.4f)
            .deltaEOK(
                Oklabf(0.2f, 0.2f, 0.4f)
            ) == 0.5f
    );


    // Symmetry is exact for these representative finite inputs.
    enum symmetryA =
        Oklabd(-1.5, 0.25, 2.0);

    enum symmetryB =
        Oklabd(0.75, -2.25, 0.5);

    static assert(
        deltaEOK(symmetryA, symmetryB) ==
        deltaEOK(symmetryB, symmetryA)
    );

    static assert(
        deltaEOK(symmetryA, symmetryB) >= 0
    );


    // R0.10 range regression:
    //
    // A direct sqrt(x*x + y*y + z*z) implementation can overflow or
    // underflow in these cases even though the mathematical norm is
    // representable. Guarded hypot must preserve them.
    enum largeD = double.max / 4;
    enum tinyD = double.min_normal;

    static assert(
        deltaEOK(
            originD,
            Oklabd(largeD, 0, 0)
        ) == largeD
    );

    static assert(
        deltaEOK(
            originD,
            Oklabd(tinyD, 0, 0)
        ) == tinyD
    );

    enum largeF = float.max / 4;
    enum tinyF = float.min_normal;

    static assert(
        deltaEOK(
            originF,
            Oklabf(largeF, 0, 0)
        ) == largeF
    );

    static assert(
        deltaEOK(
            originF,
            Oklabf(tinyF, 0, 0)
        ) == tinyF
    );


    // Current-Phobos range audit:
    //
    // std.math.hypot(x, y, z) scales by the largest component. Exercise the
    // three-component path close to the representable upper bound and in the
    // subnormal range, rather than only one-axis controls.
    enum nearMaxComponentD =
        double.max / 2;

    enum nearMaxNormD =
        deltaEOK(
            originD,
            Oklabd(
                nearMaxComponentD,
                nearMaxComponentD,
                nearMaxComponentD
            )
        );

    enum nearMaxReferenceD =
        cast(double)(
            cast(real)nearMaxComponentD *
            sqrt(real(3))
        );

    static assert(
        nearMaxNormD < double.infinity
    );

    static assert(
        nearMaxNormD ==
        nearMaxReferenceD
    );


    enum nearMaxComponentF =
        float.max / 2;

    enum nearMaxNormF =
        deltaEOK(
            originF,
            Oklabf(
                nearMaxComponentF,
                nearMaxComponentF,
                nearMaxComponentF
            )
        );

    enum nearMaxReferenceF =
        cast(float)(
            cast(real)nearMaxComponentF *
            sqrt(real(3))
        );

    static assert(
        nearMaxNormF < float.infinity
    );

    static assert(
        nearMaxNormF ==
        nearMaxReferenceF
    );


    enum minSubnormalD =
        double.min_normal *
        double.epsilon;

    enum minSubnormalNormD =
        deltaEOK(
            originD,
            Oklabd(
                minSubnormalD,
                minSubnormalD,
                minSubnormalD
            )
        );

    enum minSubnormalReferenceD =
        cast(double)(
            cast(real)minSubnormalD *
            sqrt(real(3))
        );

    static assert(
        minSubnormalNormD ==
        minSubnormalReferenceD
    );

    static assert(
        minSubnormalNormD >
        cast(double)0
    );


    enum minSubnormalF =
        float.min_normal *
        float.epsilon;

    enum minSubnormalNormF =
        deltaEOK(
            originF,
            Oklabf(
                minSubnormalF,
                minSubnormalF,
                minSubnormalF
            )
        );

    enum minSubnormalReferenceF =
        cast(float)(
            cast(real)minSubnormalF *
            sqrt(real(3))
        );

    static assert(
        minSubnormalNormF ==
        minSubnormalReferenceF
    );

    static assert(
        minSubnormalNormF >
        cast(float)0
    );


    // Finite endpoints can have a non-representable component difference.
    // The mathematical distance is then also non-representable in T, so +Inf
    // is the correct floating-point result rather than a repair or clamp.
    static assert(
        deltaEOK(
            Oklabd(
                double.max,
                0,
                0
            ),
            Oklabd(
                -double.max,
                0,
                0
            )
        ) ==
        double.infinity
    );

    static assert(
        deltaEOK(
            Oklabf(
                float.max,
                0,
                0
            ),
            Oklabf(
                -float.max,
                0,
                0
            )
        ) ==
        float.infinity
    );


    // NaN propagates.
    enum nanD =
        deltaEOK(
            Oklabd(double.nan, 0, 0),
            originD
        );

    static assert(nanD != nanD);


    // Either sign of an infinite component difference produces +infinity.
    enum positiveInfinityD =
        deltaEOK(
            Oklabd(double.infinity, 0, 0),
            originD
        );

    enum negativeInfinityD =
        deltaEOK(
            Oklabd(-double.infinity, 0, 0),
            originD
        );

    static assert(
        positiveInfinityD == double.infinity
    );

    static assert(
        negativeInfinityD == double.infinity
    );


    // NaN takes precedence when NaN and infinity occur together.
    enum nanAndInfinityD =
        deltaEOK(
            Oklabd(
                double.nan,
                double.infinity,
                0
            ),
            originD
        );

    static assert(nanAndInfinityD != nanAndInfinityD);


    // Equal infinities subtract to NaN and therefore retain NaN semantics.
    enum equalInfinityD =
        deltaEOK(
            Oklabd(
                double.infinity,
                0,
                0
            ),
            Oklabd(
                double.infinity,
                0,
                0
            )
        );

    static assert(equalInfinityD != equalInfinityD);
}


version (unittest)
{
    // R0.10 production property/reference regression.
    //
    // These helpers remain test-only. They independently exercise the public
    // operation over deterministic extended finite Oklab values.

    private struct DeltaETestLcg
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
        if (is(T == float) || is(T == double))
        {
            const T unit =
                cast(T)(nextU32()) /
                cast(T)(uint.max);

            // Deliberately extended finite Oklab test domain:
            // approximately [-4, +4].
            return unit * cast(T)8 - cast(T)4;
        }
    }

    private T deltaETestAbs(T)(const T value)
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
    {
        return value < cast(T)0 ? -value : value;
    }

    private real deltaETestAbsReal(real value)
    @safe pure nothrow @nogc
    {
        return value < real(0) ? -value : value;
    }

    private T deltaEPropertyTolerance(T)()
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
    {
        static if (is(T == double))
            return cast(T)1e-12;
        else
            return cast(T)2e-5;
    }

    private real deltaEReferenceTolerance(T)(
        real referenceValue
    )
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
    {
        real scale =
            deltaETestAbsReal(referenceValue);

        if (scale < real(1))
            scale = real(1);

        return
            real(8) *
            cast(real)T.epsilon *
            scale;
    }

    private real referenceDeltaEOK(T)(
        Oklab!T lhs,
        Oklab!T rhs
    )
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
    {
        import std.math : sqrt;

        const real dl =
            cast(real)lhs.l -
            cast(real)rhs.l;

        const real da =
            cast(real)lhs.a -
            cast(real)rhs.a;

        const real db =
            cast(real)lhs.b -
            cast(real)rhs.b;

        return sqrt(
            dl * dl +
            da * da +
            db * db
        );
    }

    private void verifyDeltaEProperties(T)(
        size_t samples
    )
    @safe pure nothrow @nogc
    if (is(T == float) || is(T == double))
    {
        DeltaETestLcg rng =
            DeltaETestLcg(
                0x4f4b4c41425f5230UL
            );

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

            const T dxx =
                deltaEOK(x, x);

            const T dxy =
                deltaEOK(x, y);

            const T dyx =
                deltaEOK(y, x);

            // Identity.
            assert(dxx == cast(T)0);

            // Non-negativity.
            assert(dxy >= cast(T)0);

            // Symmetry.
            assert(
                deltaETestAbs(dxy - dyx) <=
                deltaEPropertyTolerance!T()
            );

            // Independent wider-precision reference route.
            const real referenceValue =
                referenceDeltaEOK(x, y);

            assert(
                deltaETestAbsReal(
                    cast(real)dxy -
                    referenceValue
                ) <=
                deltaEReferenceTolerance!T(
                    referenceValue
                )
            );

            // Triangle inequality, allowing only the validated floating-point
            // property tolerance from R0.10.
            const T dxz =
                deltaEOK(x, z);

            const T dzy =
                deltaEOK(z, y);

            const T triangleSlack =
                dxy - (dxz + dzy);

            assert(
                triangleSlack <=
                deltaEPropertyTolerance!T()
            );
        }
    }
}

@safe pure nothrow @nogc unittest
{
    // R0.10 used 4096 generated cases per scalar. Retain the same production
    // regression depth so promotion does not weaken the validated property
    // evidence.
    verifyDeltaEProperties!float(4096);
    verifyDeltaEProperties!double(4096);
}


/**
 * Measures CIE 1976 Euclidean colour difference between two CIELAB D50 values.
 *
 * This is the Delta E 1976 metric. It operates directly on CIELAB coordinates;
 * it performs no conversion, clipping, gamut mapping, alpha resolution, or
 * perceptual-threshold classification.
 *
 * Params:
 *     lhs = First CIELAB D50 value.
 *     rhs = Second CIELAB D50 value.
 *
 * Returns:
 *     The Euclidean distance in CIELAB coordinates. NaN input propagates as
 *     NaN. An infinite component difference produces positive infinity.
 *
 * Standards:
 *     ISO/CIE 11664-4:2019.
 */
T deltaE76(T)(
    CieLabD50!T lhs,
    CieLabD50!T rhs
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T dl = lhs.l - rhs.l;
    const T da = lhs.a - rhs.a;
    const T db = lhs.b - rhs.b;

    if (isNaN(dl) || isNaN(da) || isNaN(db))
        return T.nan;

    if (
        fabs(dl) == T.infinity ||
        fabs(da) == T.infinity ||
        fabs(db) == T.infinity
    )
        return T.infinity;

    return hypot(dl, da, db);
}

///
@safe pure nothrow @nogc unittest
{
    const lhs = CieLabD50d(50, 2.6772, -79.7751);
    const rhs = CieLabD50d(50, 0, -82.7485);
    const value = lhs.deltaE76(rhs);

    assert(value > 4.00106 && value < 4.00107);
}

/**
 * Measures the CIEDE2000 colour difference between two CIELAB D50 values.
 *
 * CIEDE2000 is a named CIELAB-based metric with lightness, chroma, hue, and
 * chroma-hue interaction corrections. The calculation is deterministic and
 * allocation-free. It does not choose thresholds or decide whether a
 * difference is perceptually significant.
 *
 * Params:
 *     lhs = First CIELAB D50 value.
 *     rhs = Second CIELAB D50 value.
 *
 * Returns:
 *     The CIEDE2000 colour difference. NaN input propagates as NaN. An
 *     infinite component difference produces positive infinity.
 *
 * Standards:
 *     ISO/CIE 11664-6:2014, based on CIE Technical Report 142-2001.
 */
T deltaE2000(T)(
    CieLabD50!T lhs,
    CieLabD50!T rhs
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T dlInput = lhs.l - rhs.l;
    const T daInput = lhs.a - rhs.a;
    const T dbInput = lhs.b - rhs.b;

    if (
        isNaN(dlInput) ||
        isNaN(daInput) ||
        isNaN(dbInput)
    )
        return T.nan;

    if (
        fabs(dlInput) == T.infinity ||
        fabs(daInput) == T.infinity ||
        fabs(dbInput) == T.infinity
    )
        return T.infinity;

    enum T kL = 1;
    enum T kC = 1;
    enum T kH = 1;
    enum T pi = cast(T)PI;

    const T c1 = hypot(lhs.a, lhs.b);
    const T c2 = hypot(rhs.a, rhs.b);
    const T cBar = (c1 + c2) / cast(T)2;

    const T cBar7 =
        cBar * cBar * cBar * cBar *
        cBar * cBar * cBar;

    const T g =
        cast(T)0.5 *
        (
            cast(T)1 -
            sqrt(
                cBar7 /
                (
                    cBar7 +
                    cast(T)6103515625.0
                )
            )
        );

    const T a1Prime = (cast(T)1 + g) * lhs.a;
    const T a2Prime = (cast(T)1 + g) * rhs.a;

    const T c1Prime = hypot(a1Prime, lhs.b);
    const T c2Prime = hypot(a2Prime, rhs.b);

    T h1Prime =
        atan2(lhs.b, a1Prime) * cast(T)(180.0L / PI);
    T h2Prime =
        atan2(rhs.b, a2Prime) * cast(T)(180.0L / PI);

    if (h1Prime < cast(T)0)
        h1Prime += cast(T)360;
    if (h2Prime < cast(T)0)
        h2Prime += cast(T)360;

    const T deltaLPrime = rhs.l - lhs.l;
    const T deltaCPrime = c2Prime - c1Prime;

    T deltaHPrime = h2Prime - h1Prime;

    if (c1Prime * c2Prime == cast(T)0)
        deltaHPrime = cast(T)0;
    else if (deltaHPrime > cast(T)180)
        deltaHPrime -= cast(T)360;
    else if (deltaHPrime < cast(T)-180)
        deltaHPrime += cast(T)360;

    const T deltaHPrimeTerm =
        cast(T)2 *
        sqrt(c1Prime * c2Prime) *
        sin(
            (deltaHPrime / cast(T)2) *
            cast(T)(PI / 180.0L)
        );

    const T lBarPrime = (lhs.l + rhs.l) / cast(T)2;
    const T cBarPrime = (c1Prime + c2Prime) / cast(T)2;

    T hBarPrime;

    if (c1Prime * c2Prime == cast(T)0)
        hBarPrime = h1Prime + h2Prime;
    else if (fabs(h1Prime - h2Prime) <= cast(T)180)
        hBarPrime = (h1Prime + h2Prime) / cast(T)2;
    else if (h1Prime + h2Prime < cast(T)360)
        hBarPrime =
            (h1Prime + h2Prime + cast(T)360) /
            cast(T)2;
    else
        hBarPrime =
            (h1Prime + h2Prime - cast(T)360) /
            cast(T)2;

    const T t =
        cast(T)1 -
        cast(T)0.17 * cos(
            (hBarPrime - cast(T)30) *
            cast(T)(PI / 180.0L)
        ) +
        cast(T)0.24 * cos(
            cast(T)2 * hBarPrime *
            cast(T)(PI / 180.0L)
        ) +
        cast(T)0.32 * cos(
            (cast(T)3 * hBarPrime + cast(T)6) *
            cast(T)(PI / 180.0L)
        ) -
        cast(T)0.20 * cos(
            (cast(T)4 * hBarPrime - cast(T)63) *
            cast(T)(PI / 180.0L)
        );

    const T deltaTheta =
        cast(T)30 *
        exp2(
            -(
                (hBarPrime - cast(T)275) / cast(T)25
            ) *
            (
                (hBarPrime - cast(T)275) / cast(T)25
            )
        );

    const T rC =
        cast(T)2 *
        sqrt(
            cBarPrime * cBarPrime * cBarPrime * cBarPrime *
            cBarPrime * cBarPrime * cBarPrime /
            (
                cBarPrime * cBarPrime * cBarPrime * cBarPrime *
                cBarPrime * cBarPrime * cBarPrime +
                cast(T)6103515625.0
            )
        );

    const T rT =
        -sin(deltaTheta * cast(T)(PI / 180.0L)) * rC;

    const T lScale =
        cast(T)1 +
        cast(T)0.015 *
        (
            (lBarPrime - cast(T)50) *
            (lBarPrime - cast(T)50)
        ) /
        sqrt(
            cast(T)20 +
            (
                (lBarPrime - cast(T)50) *
                (lBarPrime - cast(T)50)
            )
        );

    const T cScale =
        cast(T)1 +
        cast(T)0.045 * cBarPrime;

    const T hScale =
        cast(T)1 +
        cast(T)0.015 * cBarPrime * t;

    const T lTerm = deltaLPrime / (kL * lScale);
    const T cTerm = deltaCPrime / (kC * cScale);
    const T hTerm =
        deltaHPrimeTerm /
        (kH * hScale);

    return sqrt(
        lTerm * lTerm +
        cTerm * cTerm +
        hTerm * hTerm +
        rT * cTerm * hTerm
    );
}

///
@safe pure nothrow @nogc unittest
{
    const lhs = CieLabD50d(50, 2.6772, -79.7751);
    const rhs = CieLabD50d(50, 0, -82.7485);
    const value = lhs.deltaE2000(rhs);

    assert(value > 2.0424 && value < 2.0426);
}

///
@safe pure nothrow @nogc unittest
{
    enum lhs = CieLabD50d(50, 2.6772, -79.7751);
    enum rhs = CieLabD50d(50, 0, -82.7485);
    enum value = lhs.deltaE2000(rhs);

    static assert(value > 2.0424 && value < 2.0426);
}

///
@safe pure nothrow @nogc unittest
{
    const zero = CieLabD50d(50, 0, 0);
    assert(zero.deltaE2000(zero) == 0);
    assert(zero.deltaE76(zero) == 0);
}

///
@safe pure nothrow @nogc unittest
{
    const lhs = CieLabD50d(50, 0, 0);
    const rhs = CieLabD50d(50, 1e-12, 0);

    assert(lhs.deltaE2000(rhs) >= 0);
    assert(lhs.deltaE2000(rhs) == rhs.deltaE2000(lhs));
}

///
@safe pure nothrow @nogc unittest
{
    enum nanValue =
        deltaE2000(
            CieLabD50d(double.nan, 0, 0),
            CieLabD50d(50, 0, 0)
        );

    enum infinityValue =
        deltaE2000(
            CieLabD50d(double.infinity, 0, 0),
            CieLabD50d(50, 0, 0)
        );

    static assert(nanValue != nanValue);
    static assert(infinityValue == double.infinity);
}

static assert(!__traits(compiles,
    deltaE76(
        CieLabD50f(0, 0, 0),
        CieLabD50d(1, 1, 1)
    )
));

static assert(!__traits(compiles,
    deltaE2000(
        CieLabD50f(0, 0, 0),
        CieLabD50d(1, 1, 1)
    )
));

static assert(!__traits(compiles,
    deltaE76(
        Oklabf(0, 0, 0),
        Oklabf(1, 1, 1)
    )
));
