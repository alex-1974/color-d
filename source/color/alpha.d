/++
 Straight-alpha and premultiplied color values.

 Use `Alpha` when opacity accompanies a computational color value without
 changing its color-space coordinates. Use `Premultiplied` for linear-light
 compositing. Conversion between the two representations is always explicit.
+/
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
 * Stores a computational color together with straight alpha.
 *
 * Use straight alpha when color coordinates and opacity should remain
 * independent. Construction stores supplied values unchanged: alpha is not
 * clamped and the color is not converted, clipped, or gamut-mapped.
 *
 * `Color` must be one of the supported computational color value types. The
 * natural `.init` state is detectably invalid because its floating components
 * and alpha are NaN.
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
     * Reports whether alpha is a usable opacity from 0 through 1.
     *
     * Returns `false` for values below 0, above 1, NaN, and infinities.
     * The check does not clamp or otherwise modify the value.
     */
    @property bool isValidAlpha() const
    @safe pure nothrow @nogc
    {
        return
            alpha >= cast(Scalar)0 &&
            alpha <= cast(Scalar)1;
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const value = Alpha!SRgbf(SRgbf(0.2f, 0.4f, 0.8f), 0.5f);
        assert(value.isValidAlpha);
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
 * Stores premultiplied linear-light sRGB and its alpha.
 *
 * Use this representation for compositing. It is deliberately distinct from
 * straight `Alpha!Color` so the two forms cannot be mixed accidentally.
 *
 * Direct construction does not perform premultiplication: callers must supply
 * coordinates that are already multiplied by the associated alpha. The natural
 * `.init` state is detectably invalid because its floating components are NaN.
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
     * Reports whether alpha is a usable opacity from 0 through 1.
     *
     * Returns `false` for values below 0, above 1, NaN, and infinities.
     * The representation does not clamp invalid alpha values.
     */
    @property bool isValidAlpha() const
    @safe pure nothrow @nogc
    {
        return
            alpha >= cast(Scalar)0 &&
            alpha <= cast(Scalar)1;
    }

    ///
    @safe pure nothrow @nogc unittest
    {
        const value = Premultiplied!LinearSRgbf(
            LinearSRgbf(0.1f, 0.2f, 0.4f),
            0.5f
        );
        assert(value.isValidAlpha);
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

/**
 * Prepares straight linear-light sRGB for premultiplied-alpha compositing.
 *
 * Each RGB coordinate is multiplied by alpha and alpha itself is preserved.
 * No validation, clipping, gamut mapping, or color-space conversion occurs.
 * At zero alpha, finite hidden straight RGB becomes transparent black.
 *
 * Params:
 *     value = Straight-alpha linear-light sRGB value.
 *
 * Returns:
 *     The corresponding premultiplied representation.
 *
 * See_Also:
 *     unpremultiply
 */

Premultiplied!(LinearSRgb!T) premultiply(T)(
    Alpha!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
{
    return Premultiplied!(LinearSRgb!T)(
        LinearSRgb!T(
            value.color.r * value.alpha,
            value.color.g * value.alpha,
            value.color.b * value.alpha
        ),
        value.alpha
    );
}

///
@safe pure nothrow @nogc unittest
{
    const straight = Alpha!LinearSRgbf(
        LinearSRgbf(0.5f, 1.25f, -0.25f),
        0.5f
    );

    const value = premultiply(straight);

    assert(value.color == LinearSRgbf(0.25f, 0.625f, -0.125f));
    assert(value.alpha == 0.5f);
}

/**
 * Converts a premultiplied result back to straight linear-light sRGB.
 *
 * Use this after compositing when a consumer needs straight alpha. For nonzero
 * alpha, RGB coordinates are divided by alpha. At zero alpha the hidden
 * straight RGB is unrecoverable, so the function returns transparent black.
 *
 * Params:
 *     value = Premultiplied linear-light sRGB value.
 *
 * Returns:
 *     The corresponding straight-alpha representation.
 *
 * See_Also:
 *     premultiply
 */

Alpha!(LinearSRgb!T) unpremultiply(T)(
    Premultiplied!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
{
    if (value.alpha == cast(T)0)
    {
        return Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)0,
                cast(T)0,
                cast(T)0
            ),
            cast(T)0
        );
    }

    return Alpha!(LinearSRgb!T)(
        LinearSRgb!T(
            value.color.r / value.alpha,
            value.color.g / value.alpha,
            value.color.b / value.alpha
        ),
        value.alpha
    );
}

///
@safe pure nothrow @nogc unittest
{
    const premultiplied = Premultiplied!LinearSRgbf(
        LinearSRgbf(0.25f, 0.625f, -0.125f),
        0.5f
    );

    const straight = unpremultiply(premultiplied);

    assert(straight.color == LinearSRgbf(0.5f, 1.25f, -0.25f));
    assert(straight.alpha == 0.5f);

    const transparent = unpremultiply(
        Premultiplied!LinearSRgbf(
            LinearSRgbf(1.0f, -2.0f, 3.0f),
            0.0f
        )
    );

    assert(transparent.color == LinearSRgbf(0.0f, 0.0f, 0.0f));
    assert(transparent.alpha == 0.0f);
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

// Alpha representation is generic, but compositing premultiplication is not.
static assert(!__traits(compiles,
    premultiply(
        Alpha!SRgbf(
            SRgbf(0.2f, 0.4f, 0.8f),
            0.5f
        )
    )
));

static assert(!__traits(compiles,
    premultiply(
        Alpha!Oklabf(
            Oklabf(0.5f, 0.1f, -0.1f),
            0.5f
        )
    )
));

static assert(!__traits(compiles,
    unpremultiply(
        Alpha!LinearSRgbf(
            LinearSRgbf(0.2f, 0.4f, 0.8f),
            0.5f
        )
    )
));

version (unittest)
{
    // CTFE transition and exact binary-friendly reference values.
    enum ctfeStraight = Alpha!LinearSRgbd(
        LinearSRgbd(0.5, 1.25, -0.25),
        0.5
    );

    enum ctfePremultiplied = premultiply(ctfeStraight);

    static assert(
        ctfePremultiplied.color ==
        LinearSRgbd(0.25, 0.625, -0.125)
    );
    static assert(ctfePremultiplied.alpha == 0.5);

    enum ctfeRoundTrip = unpremultiply(ctfePremultiplied);

    static assert(ctfeRoundTrip.color == ctfeStraight.color);
    static assert(ctfeRoundTrip.alpha == ctfeStraight.alpha);

    // Different finite hidden colors collapse at zero alpha.
    enum transparentRed = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            0
        )
    );

    enum transparentBlue = premultiply(
        Alpha!LinearSRgbd(
            LinearSRgbd(0, 0, 1),
            0
        )
    );

    static assert(transparentRed == transparentBlue);
    static assert(transparentRed.color == LinearSRgbd(0, 0, 0));
    static assert(transparentRed.alpha == 0);

    // Even a non-canonical raw zero-alpha premultiplied value
    // unpremultiplies deterministically to transparent black.
    enum nonCanonicalZero = Premultiplied!LinearSRgbd(
        LinearSRgbd(2, -3, 4),
        0
    );

    enum canonicalZero = unpremultiply(nonCanonicalZero);

    static assert(canonicalZero.color == LinearSRgbd(0, 0, 0));
    static assert(canonicalZero.alpha == 0);

    // Invalid raw alpha remains representable and is not silently clamped.
    enum invalidStraight = Alpha!LinearSRgbd(
        LinearSRgbd(0.5, -0.25, 1.0),
        1.5
    );

    enum invalidPremultiplied = premultiply(invalidStraight);

    static assert(invalidPremultiplied.alpha == 1.5);
    static assert(!invalidPremultiplied.isValidAlpha);
    static assert(
        invalidPremultiplied.color ==
        LinearSRgbd(0.75, -0.375, 1.5)
    );

    enum invalidBack = unpremultiply(invalidPremultiplied);

    static assert(invalidBack.color == invalidStraight.color);
    static assert(invalidBack.alpha == invalidStraight.alpha);
}

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
