module color.difference;

private import color.oklab :
    Oklab,
    Oklabf,
    Oklabd;

private import std.math :
    fabs,
    hypot,
    isNaN;


/**
 * Measure Euclidean color difference directly in Oklab.
 *
 * `deltaEOK` is the three-dimensional Euclidean distance between two Oklab
 * triples with the same scalar type.
 *
 * Finite extended Oklab coordinates are accepted. The operation does not
 * clamp, convert, gamut-map, or otherwise modify either operand.
 *
 * Special-value behavior is explicit:
 *
 * - if any component difference is NaN, the result is NaN;
 * - otherwise, if any component difference is infinite, the result is
 *   positive infinity;
 * - otherwise the finite Euclidean norm is evaluated with the three-argument
 *   `hypot` implementation.
 *
 * This operation is a measurement only. It does not assign a just-noticeable
 * difference threshold or another perceptual classification.
 *
 * Alpha-bearing colors are deliberately not accepted. Alpha must first be
 * resolved according to explicit caller rendering/compositing policy.
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
