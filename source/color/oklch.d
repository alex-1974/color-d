/++
 OKLCH values, degree-based hue handling, and component replacement.

 Use OKLCH when perceptual lightness, chroma, and hue are more convenient than
 Oklab's Cartesian axes. Hue storage is deliberately raw and unbounded.
 Normalization, canonicalization, component replacement, and conversion remain
 explicit operations.
+/
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


private T oklabChromaMagnitude(T)(
    T a,
    T b
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    import std.math :
        hypot,
        sqrt;

    /*
     * Preserve the ordinary direct path and its established rounding.
     *
     * For finite extreme values, a*a + b*b can overflow or underflow even
     * when the Euclidean magnitude itself is representable. Only those
     * exceptional finite cases take Phobos' scaled hypot path.
     *
     * NaN makes the squared sum NaN and therefore stays on the direct path.
     * Infinite squared sums may use hypot; for inputs without NaN this retains
     * the same visible infinity classification while also covering finite
     * overflow.
     */
    const T squared =
        a * a +
        b * b;

    const T direct =
        cast(T)sqrt(squared);

    if (
        squared == T.infinity ||
        (
            squared < T.min_normal &&
            (
                a != cast(T)0 ||
                b != cast(T)0
            )
        )
    )
    {
        return hypot(a, b);
    }

    return direct;
}

/**
 * Stores an Oklab-family hue in degrees.
 *
 * Use the normalized views when an algorithm needs a conventional angular
 * interval. The stored value itself remains raw and may contain any number of
 * complete revolutions.
 *
 * `T` must be `float` or `double`. The natural `.init` value contains
 * NaN and is not a usable hue.
 */

struct OklabHue(T)
if (is(T == float) || is(T == double))
{
    private T degrees_;

    /// Scalar component type.
    alias Scalar = T;

    /**
 * Constructs an Oklab-family hue from a raw degree value.
 *
 * No normalization is performed.
 *
 * Params:
 *     value = Raw hue in degrees.
 *
 * Returns:
 *     A hue storing `value` unchanged.
 */

    static OklabHue fromDegrees(T value)
    @safe pure nothrow @nogc
    {
        return OklabHue(value);
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const hue = OklabHued.fromDegrees(390.0);
        assert(hue.rawDegrees == 390.0);
    }

    /// Return the stored degree value without normalization.
    @property T rawDegrees() const
    @safe pure nothrow @nogc
    {
        return degrees_;
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const hue = OklabHued.fromDegrees(-30.0);
        assert(hue.rawDegrees == -30.0);
    }

    /// Return the equivalent hue from 0 degrees inclusive to 360 degrees exclusive.
    @property T positiveDegrees() const
    @safe pure nothrow @nogc
    {
        return normalizePositiveDegrees(degrees_);
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const hue = OklabHued.fromDegrees(390.0);
        assert(hue.positiveDegrees == 30.0);
    }

    /// Return the equivalent hue above -180 degrees and at most 180 degrees.
    @property T signedDegrees() const
    @safe pure nothrow @nogc
    {
        return normalizeSignedDegrees(degrees_);
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const hue = OklabHued.fromDegrees(330.0);
        assert(hue.signedDegrees == -30.0);
    }

    /// Return the raw stored hue converted to radians.
    @property T radians() const
    @safe pure nothrow @nogc
    {
        return degreesToRadians(degrees_);
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        import std.math : PI;

        const hue = OklabHued.fromDegrees(180.0);
        assert(hue.radians == PI);
    }
}

/**
 * Stores a color as Oklab lightness, chroma, and hue.
 *
 * Use OKLCH when editing or interpolating perceptual lightness, colorfulness,
 * or hue directly. Lightness and chroma are raw mathematical values; chroma is
 * not silently clamped or canonicalized, and hue preserves its raw degree
 * value.
 *
 * `T` must be `float` or `double`. The natural `.init` value contains
 * NaNs and is not a usable color.
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

    ///
    @safe pure nothrow @nogc unittest
    {
        const gray = Oklchd(0.5, 0.0, OklabHued.fromDegrees(120.0));
        assert(gray.isAchromatic);
    }

    /**
 * Tests caller-selected near-achromaticity.
 *
 * The library does not impose a global chroma epsilon.
 *
 * Params:
 *     epsilon = Non-negative caller-selected chroma magnitude threshold.
 *
 * Returns:
 *     `true` when `abs(c) <= epsilon`.
 *
 * Preconditions:
 *     `epsilon >= 0`. This is a programmer precondition; callers that need
 *     recoverable validation must validate external input before calling.
 */

    bool isNearAchromatic(T epsilon) const
    @safe pure nothrow @nogc
    {
        assert(epsilon >= cast(T)0);

        const T magnitude =
            c < cast(T)0
                ? -c
                : c;

        return magnitude <= epsilon;
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const color = Oklchd(0.5, 1e-4, OklabHued.fromDegrees(120.0));
        assert(color.isNearAchromatic(1e-3));
        assert(!color.isNearAchromatic(1e-5));
    }

    /**
     * Return an equivalent representation with non-negative chroma.
     *
     * Negative chroma is represented by flipping its sign and rotating hue
     * by 180 degrees.
     *
     * Raw hue revolutions are preserved when adding 180 degrees is exactly
     * representable in `T`. For very large finite raw hue values where that
     * addition would lose the required angular rotation through floating-point
     * rounding, the hue is first reduced to its positive-degree equivalent and
     * then rotated. The fallback hue is deliberately not wrapped after the
     * 180-degree addition.
     *
     * Non-finite hue values remain non-finite rather than being repaired.
 *
 * Returns:
 *     An equivalent OKLCH representation with non-negative chroma.
 */

    @property Oklch canonicalized() const
    @safe pure nothrow @nogc
    {
        if (c >= cast(T)0)
            return this;

        const T rawHue =
            h.rawDegrees;

        T oppositeHue =
            rawHue +
            cast(T)180;

        const bool finiteHue =
            rawHue == rawHue &&
            rawHue != T.infinity &&
            rawHue != -T.infinity;

        /*
         * Preserve the raw revolution count whenever the exact 180-degree
         * increment is representable.
         *
         * At sufficiently large magnitudes the ULP exceeds the requested
         * rotation. In that case rawHue + 180 may equal rawHue or may move by
         * some other representable increment. Preserving that raw value would
         * no longer preserve the represented color direction.
         */
        if (
            finiteHue &&
            oppositeHue - rawHue !=
                cast(T)180
        )
        {
            oppositeHue =
                h.positiveDegrees +
                cast(T)180;
        }

        return Oklch(
            l,
            -c,
            OklabHue!T.fromDegrees(
                oppositeHue
            )
        );
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const raw = Oklchd(-0.1, -0.2, OklabHued.fromDegrees(30.0));
        const canonical = raw.canonicalized;

        assert(canonical.l == raw.l);
        assert(canonical.c == 0.2);
        assert(canonical.h.rawDegrees == 210.0);
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
 * Returns a copy of an OKLCH value with raw lightness replaced.
 *
 * Chroma and stored hue are preserved exactly. No range restriction, clipping,
 * gamut mapping, canonicalization, or other policy is applied.
 *
 * Params:
 *     color = Source OKLCH value.
 *     lightness = Raw replacement lightness.
 *
 * Returns:
 *     A copy of `color` with only lightness replaced.
 *
 * See_Also:
 *     withChroma, withHue
 */

Oklch!T withLightness(T)(
    Oklch!T color,
    T lightness
)
@safe pure nothrow @nogc
{
    color.l = lightness;
    return color;
}

///
@safe pure nothrow @nogc unittest
{
    enum color = Oklchd(
        0.55,
        0.12,
        OklabHued.fromDegrees(250.0)
    );
    enum changed = color.withLightness(1.25);

    static assert(changed.l == 1.25);
    static assert(changed.c == color.c);
    static assert(changed.h.rawDegrees == color.h.rawDegrees);
}


/**
 * Returns a copy of an OKLCH value with raw chroma replaced.
 *
 * Lightness and stored hue are preserved exactly. Negative chroma is not
 * canonicalized, zero chroma does not erase powerless hue, and no clipping or
 * gamut mapping is performed.
 *
 * Params:
 *     color = Source OKLCH value.
 *     chroma = Raw replacement chroma.
 *
 * Returns:
 *     A copy of `color` with only chroma replaced.
 *
 * See_Also:
 *     withLightness, withHue
 */

Oklch!T withChroma(T)(
    Oklch!T color,
    T chroma
)
@safe pure nothrow @nogc
{
    color.c = chroma;
    return color;
}

///
@safe pure nothrow @nogc unittest
{
    enum color = Oklchd(
        0.55,
        0.12,
        OklabHued.fromDegrees(250.0)
    );
    enum changed = color.withChroma(-0.10);

    static assert(changed.l == color.l);
    static assert(changed.c == -0.10);
    static assert(changed.h.rawDegrees == color.h.rawDegrees);
}


/**
 * Returns a copy of an OKLCH value with raw stored hue replaced.
 *
 * Lightness and chroma are preserved exactly. The supplied hue is stored
 * without normalization, wrapping, chroma adjustment, clipping, or gamut mapping.
 *
 * Params:
 *     color = Source OKLCH value.
 *     hue = Raw replacement Oklab-family hue.
 *
 * Returns:
 *     A copy of `color` with only hue replaced.
 *
 * See_Also:
 *     withLightness, withChroma
 */

Oklch!T withHue(T)(
    Oklch!T color,
    OklabHue!T hue
)
@safe pure nothrow @nogc
{
    color.h = hue;
    return color;
}

///
@safe pure nothrow @nogc unittest
{
    enum color = Oklchd(
        0.55,
        0.12,
        OklabHued.fromDegrees(250.0)
    );
    enum changed =
        color.withHue(
            OklabHued.fromDegrees(725.0)
        );

    static assert(changed.l == color.l);
    static assert(changed.c == color.c);
    static assert(changed.h.rawDegrees == 725.0);
}


@safe pure nothrow @nogc unittest
{
    enum seedD =
        Oklchd(
            0.55,
            0.12,
            OklabHued.fromDegrees(250.0)
        );

    enum changedLightnessD =
        seedD.withLightness(-0.25);

    static assert(changedLightnessD.l == -0.25);
    static assert(changedLightnessD.c == seedD.c);
    static assert(
        changedLightnessD.h.rawDegrees ==
        seedD.h.rawDegrees
    );

    enum changedChromaD =
        seedD.withChroma(-0.10);

    static assert(changedChromaD.l == seedD.l);
    static assert(changedChromaD.c == -0.10);
    static assert(
        changedChromaD.h.rawDegrees ==
        seedD.h.rawDegrees
    );

    enum powerlessD =
        seedD.withChroma(0.0);

    static assert(powerlessD.c == 0.0);
    static assert(
        powerlessD.h.rawDegrees ==
        seedD.h.rawDegrees
    );

    enum restoredD =
        powerlessD.withChroma(seedD.c);

    static assert(restoredD == seedD);

    enum changedHueD =
        seedD.withHue(
            OklabHued.fromDegrees(725.0)
        );

    static assert(changedHueD.l == seedD.l);
    static assert(changedHueD.c == seedD.c);
    static assert(changedHueD.h.rawDegrees == 725.0);

    enum seedF =
        Oklchf(
            1.25f,
            -0.20f,
            OklabHuef.fromDegrees(-390.0f)
        );

    enum changedLightnessF =
        seedF.withLightness(-1.5f);

    static assert(changedLightnessF.l == -1.5f);
    static assert(changedLightnessF.c == seedF.c);
    static assert(
        changedLightnessF.h.rawDegrees ==
        seedF.h.rawDegrees
    );

    enum changedChromaF =
        seedF.withChroma(0.0f);

    static assert(changedChromaF.l == seedF.l);
    static assert(changedChromaF.c == 0.0f);
    static assert(
        changedChromaF.h.rawDegrees ==
        seedF.h.rawDegrees
    );

    enum changedHueF =
        seedF.withHue(
            OklabHuef.fromDegrees(1080.0f)
        );

    static assert(changedHueF.l == seedF.l);
    static assert(changedHueF.c == seedF.c);
    static assert(changedHueF.h.rawDegrees == 1080.0f);
}


@safe pure nothrow @nogc unittest
{
    const seed =
        Oklchd(
            0.55,
            0.12,
            OklabHued.fromDegrees(250.0)
        );

    const nonFiniteLightness =
        seed.withLightness(double.nan);

    assert(
        nonFiniteLightness.l !=
        nonFiniteLightness.l
    );
    assert(nonFiniteLightness.c == seed.c);
    assert(
        nonFiniteLightness.h.rawDegrees ==
        seed.h.rawDegrees
    );

    const nonFiniteChroma =
        seed.withChroma(double.infinity);

    assert(nonFiniteChroma.l == seed.l);
    assert(nonFiniteChroma.c == double.infinity);
    assert(
        nonFiniteChroma.h.rawDegrees ==
        seed.h.rawDegrees
    );

    const nonFiniteHue =
        seed.withHue(
            OklabHued.fromDegrees(
                -double.infinity
            )
        );

    assert(nonFiniteHue.l == seed.l);
    assert(nonFiniteHue.c == seed.c);
    assert(
        nonFiniteHue.h.rawDegrees ==
        -double.infinity
    );
}


@safe pure nothrow @nogc unittest
{
    /*
     * Negative-chroma canonicalization preserves ordinary raw hue
     * revolutions when the exact +180-degree operation is representable.
     */
    enum ordinaryPositive =
        Oklchd(
            0.7,
            -0.3,
            OklabHued.fromDegrees(400.0)
        )
        .canonicalized;

    static assert(
        ordinaryPositive.c == 0.3
    );

    static assert(
        ordinaryPositive.h.rawDegrees ==
            580.0
    );

    enum ordinaryNegative =
        Oklchd(
            0.7,
            -0.3,
            OklabHued.fromDegrees(-400.0)
        )
        .canonicalized;

    static assert(
        ordinaryNegative.h.rawDegrees ==
            -220.0
    );


    /*
     * At extreme finite raw hue magnitudes, +180 is no longer representable
     * relative to the raw value. Canonicalization must still preserve the
     * mathematically required opposite direction.
     */
    enum hugePositiveDouble =
        Oklchd(
            0.7,
            -0.3,
            OklabHued.fromDegrees(
                double.max
            )
        )
        .canonicalized;

    static assert(
        hugePositiveDouble.c == 0.3
    );

    static assert(
        hugePositiveDouble.h.rawDegrees ==
            308.0
    );

    static assert(
        hugePositiveDouble.h.positiveDegrees ==
            308.0
    );


    enum hugeNegativeDouble =
        Oklchd(
            0.7,
            -0.3,
            OklabHued.fromDegrees(
                -double.max
            )
        )
        .canonicalized;

    /*
     * Preserve the fallback's unwrapped +180 representation:
     * 232 + 180 = 412, whose positive-degree view is 52.
     */
    static assert(
        hugeNegativeDouble.h.rawDegrees ==
            412.0
    );

    static assert(
        hugeNegativeDouble.h.positiveDegrees ==
            52.0
    );


    enum hugePositiveFloat =
        Oklchf(
            0.7f,
            -0.3f,
            OklabHuef.fromDegrees(
                float.max
            )
        )
        .canonicalized;

    static assert(
        hugePositiveFloat.h.rawDegrees ==
            180.0f
    );

    static assert(
        hugePositiveFloat.h.positiveDegrees ==
            180.0f
    );


    enum hugeNegativeFloat =
        Oklchf(
            0.7f,
            -0.3f,
            OklabHuef.fromDegrees(
                -float.max
            )
        )
        .canonicalized;

    static assert(
        hugeNegativeFloat.h.rawDegrees ==
            180.0f
    );

    static assert(
        hugeNegativeFloat.h.positiveDegrees ==
            180.0f
    );


    /*
     * Non-finite hue remains non-finite.
     */
    enum positiveInfinity =
        Oklchd(
            0.7,
            -0.3,
            OklabHued.fromDegrees(
                double.infinity
            )
        )
        .canonicalized;

    static assert(
        positiveInfinity.h.rawDegrees ==
            double.infinity
    );

    enum nanHue =
        Oklchd(
            0.7,
            -0.3,
            OklabHued.fromDegrees(
                double.nan
            )
        )
        .canonicalized;

    static assert(
        nanHue.h.rawDegrees !=
            nanHue.h.rawDegrees
    );
}

/**
 * Converts Cartesian Oklab to lightness, chroma, and hue.
 *
 * Use this when chroma or hue is easier to work with directly. Non-achromatic
 * results have non-negative chroma and hue from 0° inclusive to 360° exclusive. Exactly achromatic
 * Oklab is represented as `C = 0, h = 0°`. Extreme finite components are
 * handled without avoidable loss from intermediate magnitude calculations.
 *
 * Params:
 *     color = Oklab value to convert.
 *
 * Returns:
 *     The corresponding OKLCH value.
 *
 * See_Also:
 *     toOklab
 */

Oklch!T toOklch(T)(Oklab!T color)
@safe pure nothrow @nogc
{
    import std.math : atan2;

    const T chroma =
        oklabChromaMagnitude(
            color.a,
            color.b
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

///
@safe pure nothrow @nogc unittest
{
    const neutral = Oklabd(0.5, 0.0, 0.0).toOklch;

    assert(neutral.l == 0.5);
    assert(neutral.c == 0.0);
    assert(neutral.h.rawDegrees == 0.0);
}

/**
 * Converts OKLCH to Cartesian Oklab coordinates.
 *
 * Use this when an OKLCH value must enter an Oklab-based calculation or
 * conversion path. Complete hue revolutions represent the same direction and
 * do not modify the stored OKLCH value. Negative chroma remains valid raw
 * mathematical input.
 *
 * Params:
 *     color = OKLCH value to convert.
 *
 * Returns:
 *     The corresponding Cartesian Oklab value.
 *
 * See_Also:
 *     toOklch
 */

Oklab!T toOklab(T)(Oklch!T color)
@safe pure nothrow @nogc
{
    import std.math : cos, sin;

    const T radians =
        degreesToRadians(
            color.h.positiveDegrees
        );

    return Oklab!T(
        color.l,
        color.c * cast(T)cos(radians),
        color.c * cast(T)sin(radians)
    );
}

///
@safe pure nothrow @nogc unittest
{
    const neutral = Oklchd(
        0.5,
        0.0,
        OklabHued.fromDegrees(725.0)
    ).toOklab;

    assert(neutral == Oklabd(0.5, 0.0, 0.0));
}

@safe pure nothrow @nogc unittest
{
    // Runtime companion to the CTFE/toolchain canary below. The public
    // conversion must preserve an axis-aligned minimum subnormal magnitude.
    double smallestPositiveD = 0x1p-1074;
    float smallestPositiveF = 0x1p-149f;

    const smallestPolarD =
        Oklabd(
            0.5,
            smallestPositiveD,
            0.0
        ).toOklch;

    const smallestPolarF =
        Oklabf(
            0.5f,
            smallestPositiveF,
            0.0f
        ).toOklch;

    assert(
        smallestPolarD.c ==
            smallestPositiveD
    );

    assert(
        smallestPolarF.c ==
            smallestPositiveF
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

@safe pure nothrow @nogc unittest
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

    // REGRESSION / TOOLCHAIN CANARY:
    // Phobos 2.111 two-argument hypot mishandled sufficiently tiny operands.
    // color-d does not support that frontend generation, but the public
    // Oklab -> OKLCH path deliberately exercises the exact smallest-positive
    // binary64 case so the current supported matrix cannot regress silently.
    enum smallestPositiveD = 0x1p-1074;
    enum smallestPositiveF = 0x1p-149f;

    enum smallestPolarD =
        Oklabd(
            0.5,
            smallestPositiveD,
            0.0
        ).toOklch;

    enum smallestPolarF =
        Oklabf(
            0.5f,
            smallestPositiveF,
            0.0f
        ).toOklch;

    static assert(
        smallestPolarD.c ==
            smallestPositiveD
    );

    static assert(
        smallestPolarF.c ==
            smallestPositiveF
    );

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

    // REGRESSION: very large finite raw hue remains a finite Cartesian
    // direction. Reducing complete revolutions before degree-to-radian
    // conversion avoids overflow while preserving raw stored hue.
    enum hugePositiveHue =
        OklabHued.fromDegrees(double.max);

    enum hugeNegativeHue =
        OklabHued.fromDegrees(-double.max);

    static assert(
        hugePositiveHue.rawDegrees == double.max
    );
    static assert(
        hugeNegativeHue.rawDegrees == -double.max
    );

    static assert(
        hugePositiveHue.positiveDegrees == 128.0
    );
    static assert(
        hugeNegativeHue.positiveDegrees == 232.0
    );

    enum hugePositive = Oklchd(
        0.7,
        0.3,
        hugePositiveHue
    ).toOklab;

    enum reducedPositive = Oklchd(
        0.7,
        0.3,
        OklabHued.fromDegrees(128.0)
    ).toOklab;

    enum hugeNegative = Oklchd(
        0.7,
        0.3,
        hugeNegativeHue
    ).toOklab;

    enum reducedNegative = Oklchd(
        0.7,
        0.3,
        OklabHued.fromDegrees(232.0)
    ).toOklab;

    static assert(
        hugePositive.a == hugePositive.a &&
        hugePositive.b == hugePositive.b
    );

    static assert(
        hugeNegative.a == hugeNegative.a &&
        hugeNegative.b == hugeNegative.b
    );

    static assert(oklchReferenceClose(
        hugePositive.a,
        reducedPositive.a,
        1e-14,
        1e-14
    ));
    static assert(oklchReferenceClose(
        hugePositive.b,
        reducedPositive.b,
        1e-14,
        1e-14
    ));

    static assert(oklchReferenceClose(
        hugeNegative.a,
        reducedNegative.a,
        1e-14,
        1e-14
    ));
    static assert(oklchReferenceClose(
        hugeNegative.b,
        reducedNegative.b,
        1e-14,
        1e-14
    ));

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
