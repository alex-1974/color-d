module color.alpha;

private import color.rgb :
    SRgb,
    SRgbf,
    SRgbd,
    LinearSRgb,
    LinearSRgbf,
    LinearSRgbd;
private import color.xyz :
    XyzD65,
    XyzD65f,
    XyzD65d;
private import color.oklab :
    Oklab,
    Oklabf,
    Oklabd;
private import color.oklch :
    Oklch,
    Oklchf,
    Oklchd,
    OklabHuef,
    OklabHued;
private import std.traits : isInstanceOf;

private enum bool isSupportedAlphaColor(Color) =
    isInstanceOf!(SRgb, Color) ||
    isInstanceOf!(LinearSRgb, Color) ||
    isInstanceOf!(XyzD65, Color) ||
    isInstanceOf!(Oklab, Color) ||
    isInstanceOf!(Oklch, Color);

private enum bool isSupportedPremultipliedColor(Color) =
    isInstanceOf!(LinearSRgb, Color);

/**
 * Straight-alpha color value.
 *
 * Alpha is orthogonal to the wrapped computational color space. Construction
 * stores the supplied values unchanged: alpha is not clamped and the color is
 * not converted, clipped or gamut-mapped.
 *
 * `Color` must be one of the public v0.1 computational color value types.
 */
struct Alpha(Color)
if (isSupportedAlphaColor!Color)
{
    /// Wrapped straight color value.
    Color color;

    /// Scalar component type shared with the wrapped color.
    alias Scalar = Color.Scalar;

    /// Raw straight alpha value.
    Scalar alpha;

    /**
     * Whether alpha lies in the strict semantic interval [0, 1].
     *
     * NaN and infinities are invalid automatically under ordered comparison.
     * No tolerance or clamping policy is implied.
     */
    @property bool isValidAlpha() const
    @safe pure nothrow @nogc
    {
        return
            alpha >= cast(Scalar)0 &&
            alpha <= cast(Scalar)1;
    }
}

///
@safe pure nothrow @nogc unittest
{
    const value = Alpha!SRgbf(
        SRgbf(0.2f, 0.4f, 0.8f),
        0.5f
    );

    assert(value.color == SRgbf(0.2f, 0.4f, 0.8f));
    assert(value.alpha == 0.5f);
    assert(value.isValidAlpha);
}

/**
 * Premultiplied-alpha color representation.
 *
 * This type is deliberately distinct from `Alpha!Color`. Encoded and
 * perceptual color spaces do not automatically gain premultiplication or
 * compositing semantics. The initial production representation is therefore
 * restricted to linear-light sRGB.
 *
 * Construction stores the supplied values unchanged. Direct construction is
 * an unchecked representation claim: the caller is responsible for supplying
 * coordinates that are already premultiplied by the associated alpha.
 */
struct Premultiplied(Color)
if (isSupportedPremultipliedColor!Color)
{
    /// Wrapped premultiplied color coordinates.
    Color color;

    /// Scalar component type shared with the wrapped color.
    alias Scalar = Color.Scalar;

    /// Raw alpha value associated with the premultiplied coordinates.
    Scalar alpha;

    /**
     * Whether alpha lies in the strict semantic interval [0, 1].
     *
     * The representation does not silently clamp invalid alpha values.
     */
    @property bool isValidAlpha() const
    @safe pure nothrow @nogc
    {
        return
            alpha >= cast(Scalar)0 &&
            alpha <= cast(Scalar)1;
    }
}

///
@safe pure nothrow @nogc unittest
{
    const value = Premultiplied!LinearSRgbf(
        LinearSRgbf(0.1f, 0.2f, 0.4f),
        0.5f
    );

    assert(value.color == LinearSRgbf(0.1f, 0.2f, 0.4f));
    assert(value.alpha == 0.5f);
    assert(value.isValidAlpha);
}

static assert(is(Alpha!SRgbf.Scalar == float));
static assert(is(Alpha!SRgbd.Scalar == double));
static assert(is(Alpha!LinearSRgbf.Scalar == float));
static assert(is(Alpha!XyzD65f.Scalar == float));
static assert(is(Alpha!Oklabf.Scalar == float));
static assert(is(Alpha!Oklchf.Scalar == float));

static assert(is(Premultiplied!LinearSRgbf.Scalar == float));
static assert(is(Premultiplied!LinearSRgbd.Scalar == double));

static assert(!is(Alpha!LinearSRgbf == Premultiplied!LinearSRgbf));

static assert(!__traits(compiles, Alpha!int));
static assert(!__traits(compiles, Alpha!float));
static assert(!__traits(compiles, Alpha!OklabHuef));
static assert(!__traits(compiles, Premultiplied!int));
static assert(!__traits(compiles, Premultiplied!double));
static assert(!__traits(compiles, Premultiplied!OklabHuef));
static assert(!__traits(compiles, Premultiplied!SRgbf));
static assert(!__traits(compiles, Premultiplied!XyzD65f));
static assert(!__traits(compiles, Premultiplied!Oklabf));
static assert(!__traits(compiles, Premultiplied!Oklchf));

@safe pure nothrow @nogc unittest
{
    const straight = Alpha!LinearSRgbd(
        LinearSRgbd(0.2, 0.4, 0.8),
        0.5
    );

    assert(straight.color == LinearSRgbd(0.2, 0.4, 0.8));
    assert(straight.alpha == 0.5);
    assert(straight.isValidAlpha);

    // Construction preserves invalid raw alpha rather than clamping it.
    const invalidLow = Alpha!SRgbd(SRgbd(0.2, 0.4, 0.8), -0.1);
    const invalidHigh = Alpha!SRgbd(SRgbd(0.2, 0.4, 0.8), 1.1);

    assert(invalidLow.alpha == -0.1);
    assert(invalidHigh.alpha == 1.1);
    assert(!invalidLow.isValidAlpha);
    assert(!invalidHigh.isValidAlpha);

    const premultiplied = Premultiplied!LinearSRgbd(
        LinearSRgbd(0.1, 0.2, 0.4),
        0.5
    );

    assert(premultiplied.color == LinearSRgbd(0.1, 0.2, 0.4));
    assert(premultiplied.alpha == 0.5);
    assert(premultiplied.isValidAlpha);
}

version (unittest)
{
    // Compact fourth-scalar layout for all current three-component color types.
    static assert(Alpha!SRgbf.sizeof == 4 * float.sizeof);
    static assert(Alpha!LinearSRgbf.sizeof == 4 * float.sizeof);
    static assert(Alpha!XyzD65f.sizeof == 4 * float.sizeof);
    static assert(Alpha!Oklabf.sizeof == 4 * float.sizeof);
    static assert(Alpha!Oklchf.sizeof == 4 * float.sizeof);

    static assert(Alpha!SRgbd.sizeof == 4 * double.sizeof);
    static assert(Alpha!LinearSRgbd.sizeof == 4 * double.sizeof);
    static assert(Alpha!XyzD65d.sizeof == 4 * double.sizeof);
    static assert(Alpha!Oklabd.sizeof == 4 * double.sizeof);
    static assert(Alpha!Oklchd.sizeof == 4 * double.sizeof);

    static assert(Premultiplied!LinearSRgbf.sizeof == 4 * float.sizeof);
    static assert(Premultiplied!LinearSRgbd.sizeof == 4 * double.sizeof);

    // Natural D floating-point initialization stays visibly invalid.
    enum straightInitF = Alpha!LinearSRgbf.init;
    enum straightInitD = Alpha!LinearSRgbd.init;
    enum premultipliedInitF = Premultiplied!LinearSRgbf.init;

    static assert(straightInitF.alpha != straightInitF.alpha);
    static assert(straightInitD.alpha != straightInitD.alpha);
    static assert(straightInitF.color.r != straightInitF.color.r);
    static assert(!straightInitF.isValidAlpha);
    static assert(!straightInitD.isValidAlpha);

    static assert(
        premultipliedInitF.alpha != premultipliedInitF.alpha
    );
    static assert(
        premultipliedInitF.color.r != premultipliedInitF.color.r
    );
    static assert(!premultipliedInitF.isValidAlpha);

    // Strict alpha-domain classification.
    enum alpha0 = Alpha!LinearSRgbd(LinearSRgbd(0, 0, 0), 0.0);
    enum alphaHalf = Alpha!LinearSRgbd(LinearSRgbd(0, 0, 0), 0.5);
    enum alpha1 = Alpha!LinearSRgbd(LinearSRgbd(0, 0, 0), 1.0);
    enum alphaNan = Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        double.nan
    );
    enum alphaPosInf = Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        double.infinity
    );
    enum alphaNegInf = Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        -double.infinity
    );

    static assert(alpha0.isValidAlpha);
    static assert(alphaHalf.isValidAlpha);
    static assert(alpha1.isValidAlpha);
    static assert(!alphaNan.isValidAlpha);
    static assert(!alphaPosInf.isValidAlpha);
    static assert(!alphaNegInf.isValidAlpha);

    // Orthogonal straight alpha applies to every current computational space.
    enum encoded = Alpha!SRgbd(SRgbd(0.2, 0.4, 0.8), 0.5);
    enum linear = Alpha!LinearSRgbd(LinearSRgbd(0.2, 0.4, 0.8), 0.5);
    enum xyz = Alpha!XyzD65d(XyzD65d(0.2, 0.4, 0.8), 0.5);
    enum lab = Alpha!Oklabd(Oklabd(0.5, 0.1, -0.1), 0.5);
    enum lch = Alpha!Oklchd(
        Oklchd(
            0.5,
            0.2,
            OklabHued.fromDegrees(30.0)
        ),
        0.5
    );

    static assert(encoded.alpha == 0.5);
    static assert(linear.alpha == 0.5);
    static assert(xyz.alpha == 0.5);
    static assert(lab.alpha == 0.5);
    static assert(lch.alpha == 0.5);
}
