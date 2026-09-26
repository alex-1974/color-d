module color.oklch;

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

    /**
     * Return the stored degree value without normalization.
     */
    @property T rawDegrees() const
    @safe pure nothrow @nogc
    {
        return degrees_;
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
}

/// Oklab-family hue with `float` storage.
alias OklabHuef = OklabHue!float;

/// Oklab-family hue with `double` storage.
alias OklabHued = OklabHue!double;

/// OKLCH with `float` components.
alias Oklchf = Oklch!float;

/// OKLCH with `double` components.
alias Oklchd = Oklch!double;

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
    // value. Canonicalization is an explicit later operation.
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
