module app;

import std.stdio : writeln;
import std.traits : Unqual;


// --------------------------------------------------------------------------
// Scalar model
// --------------------------------------------------------------------------

enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


// --------------------------------------------------------------------------
// Minimal color types needed by the alpha experiment
// --------------------------------------------------------------------------

struct SRgb(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}


struct LinearSRgb(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}


struct Oklab(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T a;
    T b;
}


struct OklabHue(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T degrees;
}


struct Oklch(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T c;
    OklabHue!T h;
}


alias SRgbf = SRgb!float;
alias SRgbd = SRgb!double;

alias LinearSRgbf = LinearSRgb!float;
alias LinearSRgbd = LinearSRgb!double;

alias Oklabf = Oklab!float;
alias Oklabd = Oklab!double;

alias Oklchf = Oklch!float;
alias Oklchd = Oklch!double;


// --------------------------------------------------------------------------
// Straight alpha
// --------------------------------------------------------------------------

struct Alpha(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;

    @property bool isValidAlpha() const
    @safe pure nothrow @nogc
    {
        // NaN fails both ordered comparisons.
        // +/- infinity also fails the [0, 1] interval.
        return alpha >= cast(Scalar)0 &&
               alpha <= cast(Scalar)1;
    }
}


// --------------------------------------------------------------------------
// Premultiplied representation
// --------------------------------------------------------------------------

struct Premultiplied(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;

    @property bool isValidAlpha() const
    @safe pure nothrow @nogc
    {
        return alpha >= cast(Scalar)0 &&
               alpha <= cast(Scalar)1;
    }
}


// --------------------------------------------------------------------------
// Construction helper
// --------------------------------------------------------------------------

Alpha!Color withAlpha(Color)(
    Color color,
    Color.Scalar alpha
)
@safe pure nothrow @nogc
{
    return Alpha!Color(color, alpha);
}


// --------------------------------------------------------------------------
// Generic numerical helpers
// --------------------------------------------------------------------------

Unqual!T magnitude(T)(T value)
@safe pure nothrow @nogc
{
    alias U = Unqual!T;

    const U v = cast(U)value;

    return v < cast(U)0
        ? -v
        : v;
}


bool approxEqual(T)(
    T actual,
    T expected,
    T absoluteTolerance,
    T relativeTolerance
)
@safe pure nothrow @nogc
{
    const T diff =
        magnitude(actual - expected);

    if (diff <= absoluteTolerance)
        return true;

    const T absActual =
        magnitude(actual);

    const T absExpected =
        magnitude(expected);

    const T scale =
        absActual > absExpected
            ? absActual
            : absExpected;

    return diff <= relativeTolerance * scale;
}


bool approxLinearRgb(T)(
    LinearSRgb!T actual,
    LinearSRgb!T expected,
    T tolerance
)
@safe pure nothrow @nogc
{
    return approxEqual(
               actual.r,
               expected.r,
               tolerance,
               tolerance
           ) &&
           approxEqual(
               actual.g,
               expected.g,
               tolerance,
               tolerance
           ) &&
           approxEqual(
               actual.b,
               expected.b,
               tolerance,
               tolerance
           );
}


bool approxPremultiplied(T)(
    Premultiplied!(LinearSRgb!T) actual,
    Premultiplied!(LinearSRgb!T) expected,
    T tolerance
)
@safe pure nothrow @nogc
{
    return approxLinearRgb(
               actual.color,
               expected.color,
               tolerance
           ) &&
           approxEqual(
               actual.alpha,
               expected.alpha,
               tolerance,
               tolerance
           );
}


// --------------------------------------------------------------------------
// Premultiplication
//
// R0.6 deliberately defines compositing premultiplication only for
// LinearSRgb!T.
// --------------------------------------------------------------------------

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


// --------------------------------------------------------------------------
// Unpremultiplication
// --------------------------------------------------------------------------

Alpha!(LinearSRgb!T) unpremultiply(T)(
    Premultiplied!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
{
    if (value.alpha == cast(T)0)
    {
        // Hidden straight RGB cannot be recovered from a transparent
        // premultiplied value.
        //
        // Return canonical transparent black instead of dividing by zero.
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


// --------------------------------------------------------------------------
// Porter-Duff source-over
//
// Inputs and output are premultiplied linear-light sRGB.
// --------------------------------------------------------------------------

Premultiplied!(LinearSRgb!T) sourceOver(T)(
    Premultiplied!(LinearSRgb!T) source,
    Premultiplied!(LinearSRgb!T) destination
)
@safe pure nothrow @nogc
{
    const T destinationFactor =
        cast(T)1 - source.alpha;

    return Premultiplied!(LinearSRgb!T)(
        LinearSRgb!T(
            source.color.r +
                destination.color.r * destinationFactor,

            source.color.g +
                destination.color.g * destinationFactor,

            source.color.b +
                destination.color.b * destinationFactor
        ),

        source.alpha +
            destination.alpha * destinationFactor
    );
}


// --------------------------------------------------------------------------
// Type distinction
// --------------------------------------------------------------------------

static assert(
    !is(
        Alpha!(LinearSRgbf) ==
        Premultiplied!(LinearSRgbf)
    )
);


// --------------------------------------------------------------------------
// Compile-negative compositing checks
// --------------------------------------------------------------------------

// Straight alpha is not accepted by the low-level compositor.
static assert(!__traits(compiles,
    sourceOver(
        Alpha!(LinearSRgbf)(
            LinearSRgbf(0, 0, 0),
            1
        ),
        Alpha!(LinearSRgbf)(
            LinearSRgbf(0, 0, 0),
            1
        )
    )
));


// Encoded premultiplied sRGB is not accepted either.
static assert(!__traits(compiles,
    sourceOver(
        Premultiplied!SRgbf(
            SRgbf(0, 0, 0),
            1
        ),
        Premultiplied!SRgbf(
            SRgbf(0, 0, 0),
            1
        )
    )
));


// Polar premultiplied OKLCH has no compositing semantics in R0.6.
static assert(!__traits(compiles,
    sourceOver(
        Premultiplied!Oklchf(
            Oklchf(
                0.5f,
                0.2f,
                OklabHue!float(30)
            ),
            1
        ),
        Premultiplied!Oklchf(
            Oklchf(
                0.5f,
                0.2f,
                OklabHue!float(30)
            ),
            1
        )
    )
));


// --------------------------------------------------------------------------
// Layout
// --------------------------------------------------------------------------

static assert(
    Alpha!SRgbf.sizeof == 16
);

static assert(
    Alpha!LinearSRgbf.sizeof == 16
);

static assert(
    Alpha!Oklabf.sizeof == 16
);

static assert(
    Alpha!Oklchf.sizeof == 16
);

static assert(
    Premultiplied!LinearSRgbf.sizeof == 16
);


static assert(
    Alpha!SRgbd.sizeof == 32
);

static assert(
    Alpha!LinearSRgbd.sizeof == 32
);

static assert(
    Alpha!Oklabd.sizeof == 32
);

static assert(
    Alpha!Oklchd.sizeof == 32
);

static assert(
    Premultiplied!LinearSRgbd.sizeof == 32
);


// --------------------------------------------------------------------------
// D default initialization
// --------------------------------------------------------------------------

enum initAlphaF =
    Alpha!LinearSRgbf.init;

enum initAlphaD =
    Alpha!LinearSRgbd.init;


// NaN is unequal to itself.
static assert(
    initAlphaF.alpha != initAlphaF.alpha
);

static assert(
    initAlphaD.alpha != initAlphaD.alpha
);

static assert(
    initAlphaF.color.r != initAlphaF.color.r
);

static assert(
    !initAlphaF.isValidAlpha
);

static assert(
    !initAlphaD.isValidAlpha
);


// --------------------------------------------------------------------------
// Alpha validity
// --------------------------------------------------------------------------

enum validAlpha0 =
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        0
    );

enum validAlphaHalf =
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        0.5
    );

enum validAlpha1 =
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        1
    );

enum invalidAlphaNegative =
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        -0.1
    );

enum invalidAlphaLarge =
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        1.1
    );

enum invalidAlphaNaN =
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        double.nan
    );

enum invalidAlphaPositiveInfinity =
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        double.infinity
    );

enum invalidAlphaNegativeInfinity =
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 0),
        -double.infinity
    );


static assert(validAlpha0.isValidAlpha);
static assert(validAlphaHalf.isValidAlpha);
static assert(validAlpha1.isValidAlpha);

static assert(!invalidAlphaNegative.isValidAlpha);
static assert(!invalidAlphaLarge.isValidAlpha);
static assert(!invalidAlphaNaN.isValidAlpha);
static assert(!invalidAlphaPositiveInfinity.isValidAlpha);
static assert(!invalidAlphaNegativeInfinity.isValidAlpha);


// Raw construction deliberately does not clamp.
static assert(
    invalidAlphaNegative.alpha == -0.1
);

static assert(
    invalidAlphaLarge.alpha == 1.1
);


// --------------------------------------------------------------------------
// Premultiplication: alpha 1
// --------------------------------------------------------------------------

enum opaqueStraight =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            0.2,
            0.3,
            0.4
        ),
        1
    );

enum opaquePremultiplied =
    opaqueStraight.premultiply;

static assert(
    opaquePremultiplied.color ==
    opaqueStraight.color
);

static assert(
    opaquePremultiplied.alpha == 1
);


// --------------------------------------------------------------------------
// Premultiplication: alpha 0.5
// --------------------------------------------------------------------------

enum halfStraight =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            0.2,
            0.4,
            0.8
        ),
        0.5
    );

enum halfPremultiplied =
    halfStraight.premultiply;

static assert(approxLinearRgb(
    halfPremultiplied.color,
    LinearSRgbd(
        0.1,
        0.2,
        0.4
    ),
    1e-15
));

static assert(
    halfPremultiplied.alpha == 0.5
);


// --------------------------------------------------------------------------
// Transparent hidden-color information loss
// --------------------------------------------------------------------------

enum transparentRed =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            1,
            0,
            0
        ),
        0
    );

enum transparentBlue =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            0,
            0,
            1
        ),
        0
    );

enum transparentRedPremultiplied =
    transparentRed.premultiply;

enum transparentBluePremultiplied =
    transparentBlue.premultiply;

static assert(
    transparentRed.color !=
    transparentBlue.color
);

static assert(
    transparentRedPremultiplied ==
    transparentBluePremultiplied
);

static assert(
    transparentRedPremultiplied.color ==
    LinearSRgbd(0, 0, 0)
);

static assert(
    transparentRedPremultiplied.alpha == 0
);


// --------------------------------------------------------------------------
// Unpremultiplication
// --------------------------------------------------------------------------

enum halfBack =
    halfPremultiplied.unpremultiply;

static assert(approxLinearRgb(
    halfBack.color,
    halfStraight.color,
    1e-15
));

static assert(
    halfBack.alpha ==
    halfStraight.alpha
);


// Zero alpha returns canonical transparent black.
enum transparentBack =
    transparentRedPremultiplied.unpremultiply;

static assert(
    transparentBack.color ==
    LinearSRgbd(0, 0, 0)
);

static assert(
    transparentBack.alpha == 0
);


// --------------------------------------------------------------------------
// Extended-range premultiplication
// --------------------------------------------------------------------------

enum extendedStraight =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            -0.2,
             1.3,
             0.5
        ),
        0.25
    );

enum extendedPremultiplied =
    extendedStraight.premultiply;

static assert(approxLinearRgb(
    extendedPremultiplied.color,
    LinearSRgbd(
        -0.05,
         0.325,
         0.125
    ),
    1e-15
));

static assert(
    extendedPremultiplied.alpha == 0.25
);

enum extendedBack =
    extendedPremultiplied.unpremultiply;

static assert(approxLinearRgb(
    extendedBack.color,
    extendedStraight.color,
    1e-15
));


// --------------------------------------------------------------------------
// Source-over: transparent source
// --------------------------------------------------------------------------

enum referenceDestination =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            0.3,
            0.4,
            0.5
        ),
        0.7
    ).premultiply;

enum transparentSource =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            1,
            0,
            0
        ),
        0
    ).premultiply;

enum transparentSourceOverDestination =
    sourceOver(
        transparentSource,
        referenceDestination
    );

static assert(
    transparentSourceOverDestination ==
    referenceDestination
);


// --------------------------------------------------------------------------
// Source-over: opaque source
// --------------------------------------------------------------------------

enum opaqueSource =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            0.8,
            0.1,
            0.2
        ),
        1
    ).premultiply;

enum opaqueSourceOverDestination =
    sourceOver(
        opaqueSource,
        referenceDestination
    );

static assert(
    opaqueSourceOverDestination ==
    opaqueSource
);


// --------------------------------------------------------------------------
// Source-over: transparent destination
// --------------------------------------------------------------------------

enum canonicalTransparentDestination =
    Premultiplied!LinearSRgbd(
        LinearSRgbd(
            0,
            0,
            0
        ),
        0
    );

enum sourceOverTransparentDestination =
    sourceOver(
        referenceDestination,
        canonicalTransparentDestination
    );

static assert(
    sourceOverTransparentDestination ==
    referenceDestination
);


// --------------------------------------------------------------------------
// W3C-style vector: half-transparent blue over opaque red
// --------------------------------------------------------------------------

enum halfBlue =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            0,
            0,
            1
        ),
        0.5
    ).premultiply;

enum opaqueRed =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            1,
            0,
            0
        ),
        1
    ).premultiply;

enum halfBlueOverOpaqueRed =
    sourceOver(
        halfBlue,
        opaqueRed
    );

static assert(approxPremultiplied(
    halfBlueOverOpaqueRed,
    Premultiplied!LinearSRgbd(
        LinearSRgbd(
            0.5,
            0,
            0.5
        ),
        1
    ),
    1e-15
));


// --------------------------------------------------------------------------
// W3C-style vector: half-transparent blue over half-transparent red
// --------------------------------------------------------------------------

enum halfRed =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            1,
            0,
            0
        ),
        0.5
    ).premultiply;

enum halfBlueOverHalfRed =
    sourceOver(
        halfBlue,
        halfRed
    );

static assert(approxPremultiplied(
    halfBlueOverHalfRed,
    Premultiplied!LinearSRgbd(
        LinearSRgbd(
            0.25,
            0,
            0.5
        ),
        0.75
    ),
    1e-15
));

enum halfBlueOverHalfRedStraight =
    halfBlueOverHalfRed.unpremultiply;

static assert(approxLinearRgb(
    halfBlueOverHalfRedStraight.color,
    LinearSRgbd(
        1.0 / 3.0,
        0,
        2.0 / 3.0
    ),
    1e-15
));

static assert(approxEqual(
    halfBlueOverHalfRedStraight.alpha,
    0.75,
    1e-15,
    1e-15
));


// --------------------------------------------------------------------------
// Extended-range source-over
// --------------------------------------------------------------------------

enum extendedSource =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            -0.2,
             1.3,
             0.5
        ),
        0.25
    ).premultiply;

enum extendedDestination =
    Alpha!LinearSRgbd(
        LinearSRgbd(
             1.2,
            -0.1,
             0.3
        ),
        0.5
    ).premultiply;

enum extendedComposite =
    sourceOver(
        extendedSource,
        extendedDestination
    );

static assert(approxPremultiplied(
    extendedComposite,
    Premultiplied!LinearSRgbd(
        LinearSRgbd(
            0.4,
            0.2875,
            0.2375
        ),
        0.625
    ),
    1e-15
));

enum extendedCompositeStraight =
    extendedComposite.unpremultiply;

static assert(approxLinearRgb(
    extendedCompositeStraight.color,
    LinearSRgbd(
        0.64,
        0.46,
        0.38
    ),
    1e-14
));

static assert(approxEqual(
    extendedCompositeStraight.alpha,
    0.625,
    1e-15,
    1e-15
));


// --------------------------------------------------------------------------
// Alpha result remains valid for valid source-over inputs
// --------------------------------------------------------------------------

static assert(
    halfBlueOverOpaqueRed.isValidAlpha
);

static assert(
    halfBlueOverHalfRed.isValidAlpha
);

static assert(
    extendedComposite.isValidAlpha
);


// --------------------------------------------------------------------------
// Source-over associativity
// --------------------------------------------------------------------------

enum layerA =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            0.9,
            0.2,
            1.1
        ),
        0.3
    ).premultiply;

enum layerB =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            -0.1,
             0.8,
             0.4
        ),
        0.6
    ).premultiply;

enum layerC =
    Alpha!LinearSRgbd(
        LinearSRgbd(
            0.3,
            0.7,
            0.2
        ),
        0.4
    ).premultiply;

enum associativeLeft =
    sourceOver(
        sourceOver(
            layerA,
            layerB
        ),
        layerC
    );

enum associativeRight =
    sourceOver(
        layerA,
        sourceOver(
            layerB,
            layerC
        )
    );

static assert(approxPremultiplied(
    associativeLeft,
    associativeRight,
    1e-14
));


// --------------------------------------------------------------------------
// float path
// --------------------------------------------------------------------------

enum halfBlueF =
    Alpha!LinearSRgbf(
        LinearSRgbf(
            0,
            0,
            1
        ),
        0.5f
    ).premultiply;

enum halfRedF =
    Alpha!LinearSRgbf(
        LinearSRgbf(
            1,
            0,
            0
        ),
        0.5f
    ).premultiply;

enum compositeF =
    sourceOver(
        halfBlueF,
        halfRedF
    );

static assert(approxPremultiplied(
    compositeF,
    Premultiplied!LinearSRgbf(
        LinearSRgbf(
            0.25f,
            0,
            0.5f
        ),
        0.75f
    ),
    3e-6f
));

enum compositeStraightF =
    compositeF.unpremultiply;

static assert(approxLinearRgb(
    compositeStraightF.color,
    LinearSRgbf(
        1.0f / 3.0f,
        0,
        2.0f / 3.0f
    ),
    3e-6f
));


// --------------------------------------------------------------------------
// Runtime inspection
// --------------------------------------------------------------------------

void main()
{
    writeln("=== color-d R0.6 alpha semantics ===");
    writeln();

    writeln("layout:");
    writeln(
        "  Alpha!SRgbf.sizeof                = ",
        Alpha!SRgbf.sizeof
    );
    writeln(
        "  Alpha!LinearSRgbf.sizeof          = ",
        Alpha!LinearSRgbf.sizeof
    );
    writeln(
        "  Alpha!Oklabf.sizeof               = ",
        Alpha!Oklabf.sizeof
    );
    writeln(
        "  Alpha!Oklchf.sizeof               = ",
        Alpha!Oklchf.sizeof
    );
    writeln(
        "  Premultiplied!LinearSRgbf.sizeof  = ",
        Premultiplied!LinearSRgbf.sizeof
    );

    writeln(
        "  Alpha!SRgbd.sizeof                = ",
        Alpha!SRgbd.sizeof
    );
    writeln(
        "  Alpha!LinearSRgbd.sizeof          = ",
        Alpha!LinearSRgbd.sizeof
    );
    writeln(
        "  Alpha!Oklabd.sizeof               = ",
        Alpha!Oklabd.sizeof
    );
    writeln(
        "  Alpha!Oklchd.sizeof               = ",
        Alpha!Oklchd.sizeof
    );
    writeln(
        "  Premultiplied!LinearSRgbd.sizeof  = ",
        Premultiplied!LinearSRgbd.sizeof
    );

    writeln();
    writeln("default initialization:");
    writeln(
        "  Alpha!LinearSRgbf.init = ",
        initAlphaF
    );
    writeln(
        "  valid alpha? = ",
        initAlphaF.isValidAlpha
    );

    writeln();
    writeln("raw alpha validity:");
    writeln(
        "  0.0  -> ",
        validAlpha0.isValidAlpha
    );
    writeln(
        "  0.5  -> ",
        validAlphaHalf.isValidAlpha
    );
    writeln(
        "  1.0  -> ",
        validAlpha1.isValidAlpha
    );
    writeln(
        " -0.1  -> ",
        invalidAlphaNegative.isValidAlpha
    );
    writeln(
        "  1.1  -> ",
        invalidAlphaLarge.isValidAlpha
    );
    writeln(
        "  NaN  -> ",
        invalidAlphaNaN.isValidAlpha
    );

    writeln();
    writeln("premultiplication:");
    writeln("  straight half = ", halfStraight);
    writeln("  premultiplied  = ", halfPremultiplied);
    writeln("  back           = ", halfBack);

    writeln();
    writeln("transparent hidden-color collapse:");
    writeln("  straight red   = ", transparentRed);
    writeln("  straight blue  = ", transparentBlue);
    writeln(
        "  premul red     = ",
        transparentRedPremultiplied
    );
    writeln(
        "  premul blue    = ",
        transparentBluePremultiplied
    );
    writeln("  unpremultiplied = ", transparentBack);

    writeln();
    writeln("half blue over opaque red:");
    writeln("  result = ", halfBlueOverOpaqueRed);

    writeln();
    writeln("half blue over half red:");
    writeln("  premultiplied = ", halfBlueOverHalfRed);
    writeln(
        "  straight      = ",
        halfBlueOverHalfRedStraight
    );

    writeln();
    writeln("extended range:");
    writeln("  source      = ", extendedSource);
    writeln("  destination = ", extendedDestination);
    writeln("  composite   = ", extendedComposite);
    writeln(
        "  straight    = ",
        extendedCompositeStraight
    );

    writeln();
    writeln("associativity:");
    writeln("  left  = ", associativeLeft);
    writeln("  right = ", associativeRight);

    writeln();
    writeln("float:");
    writeln("  premultiplied = ", compositeF);
    writeln("  straight      = ", compositeStraightF);
}
