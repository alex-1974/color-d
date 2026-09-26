module color.oklch;

private import color.oklab :
    Oklab,
    Oklabf,
    Oklabd;
private import std.traits : Unqual;

private Unqual!T normalizePositiveDegrees(T)(T degrees)
@safe pure nothrow @nogc
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    alias U = Unqual!T;

    U result = cast(U)degrees % cast(U)360;

    if (result < cast(U)0)
        result += cast(U)360;

    if (result >= cast(U)360)
        result -= cast(U)360;

    // Canonical positive representation uses +0.
    if (result == cast(U)0)
        return cast(U)0;

    return result;
}

private Unqual!T normalizeSignedDegrees(T)(T degrees)
@safe pure nothrow @nogc
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    alias U = Unqual!T;

    U result = normalizePositiveDegrees(degrees);

    // Canonical signed interval: (-180, 180].
    if (result > cast(U)180)
        result -= cast(U)360;

    return result;
}

private Unqual!T degreesToRadians(T)(T degrees)
@safe pure nothrow @nogc
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    import std.math : PI;

    alias U = Unqual!T;
    return cast(U)degrees * cast(U)(PI / 180.0L);
}

/**
 * Hue value for the Oklab family.
 *
 * Public/default units are degrees. The stored angle is raw and unbounded:
 * construction does not normalize complete revolutions.
 *
 * `T` is restricted to the v0.1 computational scalar set: `float` or
 * `double`.
 */
struct OklabHue(T)
if (is(T == float) || is(T == double))
{
    private T degrees_;

    /// Scalar component type.
    alias Scalar = T;

    /**
     * Construct a hue from a raw degree value.
     *
     * No normalization is performed.
     */
    static OklabHue fromDegrees(T value)
    @safe pure nothrow @nogc
    {
        return OklabHue(value);
    }

    /// Return the stored degree value without normalization.
    @property T rawDegrees() const
    @safe pure nothrow @nogc
    {
        return degrees_;
    }

    /// Return the equivalent hue in the canonical interval [0, 360).
    @property T positiveDegrees() const
    @safe pure nothrow @nogc
    {
        return normalizePositiveDegrees(degrees_);
    }

    /// Return the equivalent hue in the canonical interval (-180, 180].
    @property T signedDegrees() const
    @safe pure nothrow @nogc
    {
        return normalizeSignedDegrees(degrees_);
    }

    /// Return the raw stored hue converted to radians.
    @property T radians() const
    @safe pure nothrow @nogc
    {
        return degreesToRadians(degrees_);
    }
}

/**
 * OKLCH color value: the cylindrical form of Oklab.
 *
 * Lightness and chroma are stored as mathematical values. Chroma is not
 * silently clamped or canonicalized, and hue preserves its raw degree value.
 *
 * `T` is restricted to the v0.1 computational scalar set: `float` or
 * `double`.
 */
struct Oklch(T)
if (is(T == float) || is(T == double))
{
    /// Perceptual lightness component.
    T l;

    /// Chroma component.
    T c;

    /// Raw, degree-based Oklab-family hue.
    OklabHue!T h;

    /// Scalar component type.
    alias Scalar = T;

    /**
     * Whether chroma is exactly zero.
     *
     * Near-achromatic policy is deliberately separate.
     */
    @property bool isAchromatic() const
    @safe pure nothrow @nogc
    {
        return c == cast(T)0;
    }

    /**
     * Test caller-selected near-achromaticity.
     *
     * The library does not impose one global chroma epsilon.
     */
    bool isNearAchromatic(T epsilon) const
    @safe pure nothrow @nogc
    {
        const T magnitude =
            c < cast(T)0
                ? -c
                : c;

        return magnitude <= epsilon;
    }

    /**
     * Return an equivalent representation with non-negative chroma.
     *
     * Negative chroma is represented by flipping its sign and adding 180
     * degrees to the raw hue. The resulting hue is deliberately not wrapped.
     */
    @property Oklch canonicalized() const
    @safe pure nothrow @nogc
    {
        if (c >= cast(T)0)
            return this;

        return Oklch(
            l,
            -c,
            OklabHue!T.fromDegrees(
                h.rawDegrees + cast(T)180
            )
        );
    }
}

/// Oklab-family hue with `float` storage.
alias OklabHuef = OklabHue!float;

/// Oklab-family hue with `double` storage.
alias OklabHued = OklabHue!double;

/// OKLCH with `float` components.
alias Oklchf = Oklch!float;

/// OKLCH with `double` components.
alias Oklchd = Oklch!double;

/**
 * Convert Oklab to its cylindrical OKLCH representation.
 *
 * Cartesian Oklab has no stored hue revolutions to preserve. Non-achromatic
 * results therefore use non-negative chroma and a hue in [0, 360). Exact
 * achromatic Oklab uses the deterministic numeric fallback C = 0, h = 0°.
 */
Oklch!T toOklch(T)(Oklab!T color)
@safe pure nothrow @nogc
{
    import std.math : atan2, sqrt;

    const T chroma =
        cast(T)sqrt(
            color.a * color.a +
            color.b * color.b
        );

    // atan2(0, 0) must not define the public achromatic semantics.
    if (color.a == cast(T)0 &&
        color.b == cast(T)0)
    {
        return Oklch!T(
            color.l,
            cast(T)0,
            OklabHue!T.fromDegrees(cast(T)0)
        );
    }

    import std.math : PI;

    const T radians =
        cast(T)atan2(color.b, color.a);

    const T rawDegrees =
        radians * cast(T)(180.0L / PI);

    return Oklch!T(
        color.l,
        chroma,
        OklabHue!T.fromDegrees(
            normalizePositiveDegrees(rawDegrees)
        )
    );
}

/**
 * Convert OKLCH to Cartesian Oklab.
 *
 * Raw hue storage is respected directly. Equivalent angles such as 30° and
 * 390° therefore map to the same Cartesian direction without mutating the
 * stored OKLCH value. Negative chroma is also accepted as raw mathematical
 * input.
 */
Oklab!T toOklab(T)(Oklch!T color)
@safe pure nothrow @nogc
{
    import std.math : cos, sin;

    const T radians = color.h.radians;

    return Oklab!T(
        color.l,
        color.c * cast(T)cos(radians),
        color.c * cast(T)sin(radians)
    );
}

@safe pure nothrow @nogc unittest
{
    const hue390 = OklabHued.fromDegrees(390.0);
    const hueNegative = OklabHued.fromDegrees(-30.0);

    assert(hue390.rawDegrees == 390.0);
    assert(hueNegative.rawDegrees == -30.0);

    const color = Oklchd(
        0.6,
        0.2,
        OklabHued.fromDegrees(30.0)
    );

    assert(color.l == 0.6);
    assert(color.c == 0.2);
    assert(color.h.rawDegrees == 30.0);

    // Negative chroma remains representable as a non-canonical mathematical
    // value. Canonicalization is explicit.
    const negativeChroma = Oklchd(
        0.6,
        -0.2,
        OklabHued.fromDegrees(30.0)
    );

    assert(negativeChroma.c == -0.2);
    assert(negativeChroma.h.rawDegrees == 30.0);
}

static assert(is(OklabHuef.Scalar == float));
static assert(is(OklabHued.Scalar == double));
static assert(is(Oklchf.Scalar == float));
static assert(is(Oklchd.Scalar == double));

static assert(!__traits(compiles, OklabHue!ubyte));
static assert(!__traits(compiles, OklabHue!int));
static assert(!__traits(compiles, OklabHue!real));
static assert(!__traits(compiles, Oklch!ubyte));
static assert(!__traits(compiles, Oklch!int));
static assert(!__traits(compiles, Oklch!real));

static assert(!__traits(compiles, Oklchf.init.toOklch));
static assert(!__traits(compiles, Oklabf.init.toOklab));

unittest
{
    assert(OklabHuef.sizeof == float.sizeof);
    assert(OklabHued.sizeof == double.sizeof);
    assert(Oklchf.sizeof == 3 * float.sizeof);
    assert(Oklchd.sizeof == 3 * double.sizeof);

    // Preserve D's natural floating-point .init state throughout the polar
    // value representation.
    assert(OklabHuef.init.rawDegrees != OklabHuef.init.rawDegrees);
    assert(OklabHued.init.rawDegrees != OklabHued.init.rawDegrees);

    assert(Oklchf.init.l != Oklchf.init.l);
    assert(Oklchf.init.c != Oklchf.init.c);
    assert(Oklchf.init.h.rawDegrees != Oklchf.init.h.rawDegrees);

    assert(Oklchd.init.l != Oklchd.init.l);
    assert(Oklchd.init.c != Oklchd.init.c);
    assert(Oklchd.init.h.rawDegrees != Oklchd.init.h.rawDegrees);
}

version (unittest)
{
    private T referenceMagnitude(T)(T value)
    @safe pure nothrow @nogc
    {
        return value < cast(T)0 ? -value : value;
    }

    private bool oklchReferenceClose(T)(
        T actual,
        T expected,
        T absoluteTolerance,
        T relativeTolerance
    )
    @safe pure nothrow @nogc
    {
        const T diff = referenceMagnitude(actual - expected);
        if (diff <= absoluteTolerance)
            return true;

        const T absActual = referenceMagnitude(actual);
        const T absExpected = referenceMagnitude(expected);
        const T scale =
            absActual > absExpected ? absActual : absExpected;

        return diff <= relativeTolerance * scale;
    }

    private T wrappedHueDifference(T)(T actual, T expected)
    @safe pure nothrow @nogc
    {
        return referenceMagnitude(
            normalizeSignedDegrees(actual - expected)
        );
    }

    // EXACT: raw storage and normalization views remain distinct.
    enum raw390 = OklabHued.fromDegrees(390.0);
    enum rawMinus30 = OklabHued.fromDegrees(-30.0);

    static assert(raw390.rawDegrees == 390.0);
    static assert(raw390.positiveDegrees == 30.0);
    static assert(raw390.signedDegrees == 30.0);

    static assert(rawMinus30.rawDegrees == -30.0);
    static assert(rawMinus30.positiveDegrees == 330.0);
    static assert(rawMinus30.signedDegrees == -30.0);

    static assert(OklabHued.fromDegrees(-180.0).signedDegrees == 180.0);
    static assert(OklabHued.fromDegrees(180.0).signedDegrees == 180.0);

    // EXACT / CLASSIFY: exact achromaticity is C == 0 only.
    enum grayLch = Oklabd(0.42, 0.0, 0.0).toOklch;
    static assert(grayLch.c == 0.0);
    static assert(grayLch.h.rawDegrees == 0.0);
    static assert(grayLch.isAchromatic);
    static assert(grayLch.isNearAchromatic(1e-12));

    enum tinyChroma = Oklchd(
        0.5,
        1e-10,
        OklabHued.fromDegrees(123.0)
    );
    static assert(!tinyChroma.isAchromatic);
    static assert(tinyChroma.isNearAchromatic(1e-9));
    static assert(!tinyChroma.isNearAchromatic(1e-11));

    // REFERENCE: primary Cartesian axes define the canonical hue quadrants.
    enum axis0 = Oklabd(0.5, 0.2, 0.0).toOklch;
    enum axis90 = Oklabd(0.5, 0.0, 0.2).toOklch;
    enum axis180 = Oklabd(0.5, -0.2, 0.0).toOklch;
    enum axis270 = Oklabd(0.5, 0.0, -0.2).toOklch;

    static assert(wrappedHueDifference(axis0.h.rawDegrees, 0.0) <= 1e-13);
    static assert(wrappedHueDifference(axis90.h.rawDegrees, 90.0) <= 1e-13);
    static assert(wrappedHueDifference(axis180.h.rawDegrees, 180.0) <= 1e-13);
    static assert(wrappedHueDifference(axis270.h.rawDegrees, 270.0) <= 1e-13);

    // REFERENCE: ordinary double Cartesian -> polar result.
    enum ordinaryLab = Oklabd(
        0.49956838997607944,
        0.16935376231011406,
        0.04475580639007088
    );
    enum ordinaryLch = ordinaryLab.toOklch;

    static assert(oklchReferenceClose(
        ordinaryLch.c,
        0.17516785953540712,
        1e-14,
        1e-14
    ));
    static assert(
        wrappedHueDifference(
            ordinaryLch.h.rawDegrees,
            14.803356023033423
        ) <= 1e-13
    );

    // DERIVED: ordinary double Cartesian/polar round trip.
    enum ordinaryBack = ordinaryLch.toOklab;
    static assert(oklchReferenceClose(
        ordinaryBack.l,
        ordinaryLab.l,
        1e-14,
        1e-14
    ));
    static assert(oklchReferenceClose(
        ordinaryBack.a,
        ordinaryLab.a,
        1e-14,
        1e-14
    ));
    static assert(oklchReferenceClose(
        ordinaryBack.b,
        ordinaryLab.b,
        1e-14,
        1e-14
    ));

    // RAW SEMANTICS: extra revolutions are preserved in storage but not in
    // the represented Cartesian direction.
    enum lch30 = Oklchd(
        0.6,
        0.2,
        OklabHued.fromDegrees(30.0)
    );
    enum lch390 = Oklchd(
        0.6,
        0.2,
        OklabHued.fromDegrees(390.0)
    );

    static assert(lch30.h.rawDegrees != lch390.h.rawDegrees);
    static assert(lch30.h.positiveDegrees == lch390.h.positiveDegrees);

    enum lab30 = lch30.toOklab;
    enum lab390 = lch390.toOklab;

    static assert(oklchReferenceClose(
        lab30.a,
        lab390.a,
        1e-14,
        1e-14
    ));
    static assert(oklchReferenceClose(
        lab30.b,
        lab390.b,
        1e-14,
        1e-14
    ));

    enum lch390Back = lab390.toOklch;
    static assert(
        wrappedHueDifference(
            lch390Back.h.rawDegrees,
            30.0
        ) <= 1e-13
    );

    // RAW/CANONICAL SEMANTICS: negative chroma remains constructible and
    // canonicalization preserves the represented Cartesian color.
    enum negativeChroma = Oklchd(
        0.6,
        -0.2,
        OklabHued.fromDegrees(30.0)
    );
    static assert(!negativeChroma.isAchromatic);

    enum canonicalNegative = negativeChroma.canonicalized;
    static assert(canonicalNegative.c == 0.2);
    static assert(canonicalNegative.h.rawDegrees == 210.0);

    enum negativeLab = negativeChroma.toOklab;
    enum canonicalLab = canonicalNegative.toOklab;

    static assert(oklchReferenceClose(
        negativeLab.a,
        canonicalLab.a,
        1e-14,
        1e-14
    ));
    static assert(oklchReferenceClose(
        negativeLab.b,
        canonicalLab.b,
        1e-14,
        1e-14
    ));

    // DERIVED: float path is characterized independently.
    enum ordinaryLabF = Oklabf(
        0.4995684f,
        0.16935377f,
        0.04475581f
    );
    enum ordinaryBackF = ordinaryLabF.toOklch.toOklab;

    static assert(oklchReferenceClose(
        ordinaryBackF.l,
        ordinaryLabF.l,
        3e-6f,
        3e-6f
    ));
    static assert(oklchReferenceClose(
        ordinaryBackF.a,
        ordinaryLabF.a,
        3e-6f,
        3e-6f
    ));
    static assert(oklchReferenceClose(
        ordinaryBackF.b,
        ordinaryLabF.b,
        3e-6f,
        3e-6f
    ));
}
