module app;

import std.math :
    atan2,
    cos,
    PI,
    sin,
    sqrt;

import std.stdio : writeln;
import std.traits : Unqual;


enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


// --------------------------------------------------------------------------
// Candidate value types
// --------------------------------------------------------------------------

struct OklabHue(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T degrees;

    static OklabHue fromDegrees(T value)
    @safe pure nothrow @nogc
    {
        // Deliberately preserve the raw angle.
        return OklabHue(value);
    }

    @property T rawDegrees() const
    @safe pure nothrow @nogc
    {
        return degrees;
    }

    @property T positiveDegrees() const
    @safe pure nothrow @nogc
    {
        return normalizePositiveDegrees(degrees);
    }

    @property T signedDegrees() const
    @safe pure nothrow @nogc
    {
        return normalizeSignedDegrees(degrees);
    }

    @property T radians() const
    @safe pure nothrow @nogc
    {
        return degreesToRadians(degrees);
    }
}


struct Oklab(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T a;
    T b;
}


struct Oklch(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T c;
    OklabHue!T h;

    @property bool isAchromatic() const
    @safe pure nothrow @nogc
    {
        return c == cast(T)0;
    }

    bool isNearAchromatic(T epsilon) const
    @safe pure nothrow @nogc
    {
        return magnitude(c) <= epsilon;
    }

    @property Oklch canonicalized() const
    @safe pure nothrow @nogc
    {
        if (c >= cast(T)0)
            return this;

        // Preserve represented Cartesian color:
        //
        // (-C, h) == (C, h + 180°)
        //
        // Do not normalize the hue here. The operation preserves raw hue
        // semantics while making chroma non-negative.
        return Oklch(
            l,
            -c,
            OklabHue!T.fromDegrees(
                h.rawDegrees + cast(T)180
            )
        );
    }
}


alias OklabHuef = OklabHue!float;
alias OklabHued = OklabHue!double;

alias Oklabf = Oklab!float;
alias Oklabd = Oklab!double;

alias Oklchf = Oklch!float;
alias Oklchd = Oklch!double;


// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

T magnitude(T)(T value)
@safe pure nothrow @nogc
{
    return value < 0 ? -value : value;
}


bool approxEqual(T)(
    T actual,
    T expected,
    T absoluteTolerance,
    T relativeTolerance
)
@safe pure nothrow @nogc
{
    const T diff = magnitude(actual - expected);

    if (diff <= absoluteTolerance)
        return true;

    const T absActual = magnitude(actual);
    const T absExpected = magnitude(expected);

    const T scale =
        absActual > absExpected
            ? absActual
            : absExpected;

    return diff <= relativeTolerance * scale;
}


// --------------------------------------------------------------------------
// Angle helpers
// --------------------------------------------------------------------------

Unqual!T normalizePositiveDegrees(T)(T degrees)
@safe pure nothrow @nogc
{
    alias U = Unqual!T;

    // Template inference may receive const(float) / const(double).
    // Arithmetic works on an unqualified local value and returns the
    // corresponding unqualified scalar type.
    U result = cast(U)degrees % cast(U)360;

    if (result < cast(U)0)
        result += cast(U)360;

    // Defensive canonicalization for any future implementation or rounding
    // behavior that might expose 360 exactly.
    if (result >= cast(U)360)
        result -= cast(U)360;

    // Canonical positive representation uses +0.
    if (result == cast(U)0)
        return cast(U)0;

    return result;
}


Unqual!T normalizeSignedDegrees(T)(T degrees)
@safe pure nothrow @nogc
{
    alias U = Unqual!T;

    U result = normalizePositiveDegrees(degrees);

    // Desired interval: (-180, 180]
    if (result > cast(U)180)
        result -= cast(U)360;

    return result;
}


T degreesToRadians(T)(T degrees)
@safe pure nothrow @nogc
{
    return degrees * cast(T)(PI / 180.0L);
}


T radiansToDegrees(T)(T radians)
@safe pure nothrow @nogc
{
    return radians * cast(T)(180.0L / PI);
}


// --------------------------------------------------------------------------
// Oklab -> OKLCH
// --------------------------------------------------------------------------

Oklch!T toOklch(T)(Oklab!T color)
@safe pure nothrow @nogc
{
    const T chroma =
        cast(T)sqrt(
            color.a * color.a +
            color.b * color.b
        );

    // atan2(0, 0) must not define our public semantics.
    //
    // Exact achromatic Oklab receives a deterministic numeric fallback:
    //
    //     C = 0
    //     h = 0 degrees
    //
    if (color.a == cast(T)0 &&
        color.b == cast(T)0)
    {
        return Oklch!T(
            color.l,
            cast(T)0,
            OklabHue!T.fromDegrees(cast(T)0)
        );
    }

    const T radians =
        cast(T)atan2(color.b, color.a);

    const T rawDegrees =
        radiansToDegrees(radians);

    const T canonicalDegrees =
        normalizePositiveDegrees(rawDegrees);

    return Oklch!T(
        color.l,
        chroma,
        OklabHue!T.fromDegrees(canonicalDegrees)
    );
}


// --------------------------------------------------------------------------
// OKLCH -> Oklab
// --------------------------------------------------------------------------

Oklab!T toOklab(T)(Oklch!T color)
@safe pure nothrow @nogc
{
    // No normalization is needed for sin/cos.
    //
    // Raw angles such as 390° and 30° represent the same Cartesian
    // direction while remaining observably different in Oklch storage.
    const T radians = color.h.radians;

    return Oklab!T(
        color.l,
        color.c * cast(T)cos(radians),
        color.c * cast(T)sin(radians)
    );
}


// --------------------------------------------------------------------------
// Type/layout checks
// --------------------------------------------------------------------------

static assert(
    OklabHuef.sizeof == float.sizeof
);

static assert(
    OklabHuef.alignof == float.alignof
);

static assert(
    OklabHued.sizeof == double.sizeof
);

static assert(
    OklabHued.alignof == double.alignof
);

static assert(
    Oklabf.sizeof == 3 * float.sizeof
);

static assert(
    Oklchf.sizeof == 3 * float.sizeof
);

static assert(
    Oklabd.sizeof == 3 * double.sizeof
);

static assert(
    Oklchd.sizeof == 3 * double.sizeof
);


// --------------------------------------------------------------------------
// CTFE: raw hue preservation
// --------------------------------------------------------------------------

enum raw390 =
    OklabHued.fromDegrees(390.0);

static assert(
    raw390.rawDegrees == 390.0
);

static assert(
    raw390.positiveDegrees == 30.0
);

static assert(
    raw390.signedDegrees == 30.0
);


enum rawMinus30 =
    OklabHued.fromDegrees(-30.0);

static assert(
    rawMinus30.rawDegrees == -30.0
);

static assert(
    rawMinus30.positiveDegrees == 330.0
);

static assert(
    rawMinus30.signedDegrees == -30.0
);


// --------------------------------------------------------------------------
// CTFE: wrapping table
// --------------------------------------------------------------------------

static assert(
    normalizePositiveDegrees(-720.0) == 0.0
);

static assert(
    normalizePositiveDegrees(-390.0) == 330.0
);

static assert(
    normalizePositiveDegrees(-360.0) == 0.0
);

static assert(
    normalizePositiveDegrees(-30.0) == 330.0
);

static assert(
    normalizePositiveDegrees(0.0) == 0.0
);

static assert(
    normalizePositiveDegrees(30.0) == 30.0
);

static assert(
    normalizePositiveDegrees(360.0) == 0.0
);

static assert(
    normalizePositiveDegrees(390.0) == 30.0
);

static assert(
    normalizePositiveDegrees(720.0) == 0.0
);

static assert(
    normalizePositiveDegrees(740.0) == 20.0
);


static assert(
    normalizeSignedDegrees(270.0) == -90.0
);

static assert(
    normalizeSignedDegrees(190.0) == -170.0
);

static assert(
    normalizeSignedDegrees(-190.0) == 170.0
);

static assert(
    normalizeSignedDegrees(180.0) == 180.0
);

static assert(
    normalizeSignedDegrees(-180.0) == 180.0
);


// --------------------------------------------------------------------------
// CTFE: degree/radian conversion
// --------------------------------------------------------------------------

static assert(approxEqual(
    degreesToRadians(180.0),
    cast(double)PI,
    1e-15,
    1e-15
));

static assert(approxEqual(
    radiansToDegrees(cast(double)PI),
    180.0,
    1e-15,
    1e-15
));


// --------------------------------------------------------------------------
// CTFE: primary polar axes
// --------------------------------------------------------------------------

enum axis0 =
    Oklabd(0.5, 0.2, 0.0).toOklch;

static assert(approxEqual(
    axis0.c,
    0.2,
    1e-15,
    1e-14
));

static assert(approxEqual(
    axis0.h.rawDegrees,
    0.0,
    1e-14,
    1e-14
));


enum axis90 =
    Oklabd(0.5, 0.0, 0.2).toOklch;

static assert(approxEqual(
    axis90.c,
    0.2,
    1e-15,
    1e-14
));

static assert(approxEqual(
    axis90.h.rawDegrees,
    90.0,
    1e-14,
    1e-14
));


enum axis180 =
    Oklabd(0.5, -0.2, 0.0).toOklch;

static assert(approxEqual(
    axis180.h.rawDegrees,
    180.0,
    1e-14,
    1e-14
));


enum axis270 =
    Oklabd(0.5, 0.0, -0.2).toOklch;

static assert(approxEqual(
    axis270.h.rawDegrees,
    270.0,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: exact achromatic fallback
// --------------------------------------------------------------------------

enum grayLab =
    Oklabd(0.42, 0.0, 0.0);

enum grayLch =
    grayLab.toOklch;

static assert(
    grayLch.c == 0.0
);

static assert(
    grayLch.h.rawDegrees == 0.0
);

static assert(
    grayLch.isAchromatic
);

static assert(
    grayLch.isNearAchromatic(1e-12)
);


// --------------------------------------------------------------------------
// CTFE: ordinary R0.4 reference
// --------------------------------------------------------------------------

enum ordinaryLab =
    Oklabd(
        0.49956838997607944,
        0.16935376231011406,
        0.04475580639007088
    );

enum ordinaryLch =
    ordinaryLab.toOklch;

static assert(approxEqual(
    ordinaryLch.c,
    0.17516785953540712,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryLch.h.rawDegrees,
    14.803356023033423,
    1e-13,
    1e-13
));

enum ordinaryBack =
    ordinaryLch.toOklab;

static assert(approxEqual(
    ordinaryBack.l,
    ordinaryLab.l,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryBack.a,
    ordinaryLab.a,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryBack.b,
    ordinaryLab.b,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: R0.4 unit-primary references
// --------------------------------------------------------------------------

enum redLab =
    Oklabd(
        0.6279553639214313,
        0.2248630684262741,
        0.1258462773305850
    );

enum redLch = redLab.toOklch;

static assert(approxEqual(
    redLch.c,
    0.25768330380536053,
    1e-14,
    1e-14
));

static assert(approxEqual(
    redLch.h.rawDegrees,
    29.233880279627897,
    1e-13,
    1e-13
));


enum greenLab =
    Oklabd(
        0.8664396175234368,
        -0.2338875809365576,
        0.1794984451609376
    );

enum greenLch = greenLab.toOklch;

static assert(approxEqual(
    greenLch.c,
    0.29482722454269533,
    1e-14,
    1e-14
));

static assert(approxEqual(
    greenLch.h.rawDegrees,
    142.49534504144384,
    1e-13,
    1e-13
));


enum blueLab =
    Oklabd(
        0.45201371817442365,
        -0.03245697517079776,
        -0.3115281656775777
    );

enum blueLch = blueLab.toOklch;

static assert(approxEqual(
    blueLch.c,
    0.3132143886344848,
    1e-14,
    1e-14
));

static assert(approxEqual(
    blueLch.h.rawDegrees,
    264.0520226163699,
    1e-13,
    1e-13
));


// --------------------------------------------------------------------------
// CTFE: extended-range R0.4 reference
// --------------------------------------------------------------------------

enum extendedLab =
    Oklabd(
        0.9430178754560363,
        -0.2434398510145207,
        0.0716841414885879
    );

enum extendedLch =
    extendedLab.toOklch;

static assert(approxEqual(
    extendedLch.c,
    0.25377465831506485,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedLch.h.rawDegrees,
    163.5922251268966,
    1e-13,
    1e-13
));

enum extendedBack =
    extendedLch.toOklab;

static assert(approxEqual(
    extendedBack.a,
    extendedLab.a,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedBack.b,
    extendedLab.b,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: raw hue revolution preservation
// --------------------------------------------------------------------------

enum lch30 =
    Oklchd(
        0.6,
        0.2,
        OklabHued.fromDegrees(30.0)
    );

enum lch390 =
    Oklchd(
        0.6,
        0.2,
        OklabHued.fromDegrees(390.0)
    );

static assert(
    lch30.h.rawDegrees != lch390.h.rawDegrees
);

static assert(
    lch30.h.positiveDegrees ==
    lch390.h.positiveDegrees
);

enum lab30 =
    lch30.toOklab;

enum lab390 =
    lch390.toOklab;

static assert(approxEqual(
    lab30.a,
    lab390.a,
    1e-14,
    1e-14
));

static assert(approxEqual(
    lab30.b,
    lab390.b,
    1e-14,
    1e-14
));


// Cartesian round trip cannot recover the extra revolution.
enum lch390Back =
    lab390.toOklch;

static assert(approxEqual(
    lch390Back.h.rawDegrees,
    30.0,
    1e-13,
    1e-13
));


// --------------------------------------------------------------------------
// CTFE: negative chroma
// --------------------------------------------------------------------------

enum negativeChroma =
    Oklchd(
        0.6,
        -0.2,
        OklabHued.fromDegrees(30.0)
    );

static assert(
    !negativeChroma.isAchromatic
);

enum canonicalNegativeChroma =
    negativeChroma.canonicalized;

static assert(
    canonicalNegativeChroma.c == 0.2
);

static assert(
    canonicalNegativeChroma.h.rawDegrees == 210.0
);

enum negativeLab =
    negativeChroma.toOklab;

enum canonicalNegativeLab =
    canonicalNegativeChroma.toOklab;

static assert(approxEqual(
    negativeLab.a,
    canonicalNegativeLab.a,
    1e-14,
    1e-14
));

static assert(approxEqual(
    negativeLab.b,
    canonicalNegativeLab.b,
    1e-14,
    1e-14
));


// Cartesian -> polar canonicalizes chroma and hue.
enum negativeRoundTrip =
    negativeLab.toOklch;

static assert(approxEqual(
    negativeRoundTrip.c,
    0.2,
    1e-14,
    1e-14
));

static assert(approxEqual(
    negativeRoundTrip.h.rawDegrees,
    210.0,
    1e-13,
    1e-13
));


// --------------------------------------------------------------------------
// CTFE: near-achromatic policy remains explicit
// --------------------------------------------------------------------------

enum tinyChroma =
    Oklchd(
        0.5,
        1e-10,
        OklabHued.fromDegrees(123.0)
    );

static assert(
    !tinyChroma.isAchromatic
);

static assert(
    tinyChroma.isNearAchromatic(1e-9)
);

static assert(
    !tinyChroma.isNearAchromatic(1e-11)
);


// --------------------------------------------------------------------------
// CTFE: float round trip
// --------------------------------------------------------------------------

enum ordinaryLabF =
    Oklabf(
        0.4995684f,
        0.16935377f,
        0.04475581f
    );

enum ordinaryLchF =
    ordinaryLabF.toOklch;

enum ordinaryBackF =
    ordinaryLchF.toOklab;

static assert(approxEqual(
    ordinaryBackF.l,
    ordinaryLabF.l,
    3e-6f,
    3e-6f
));

static assert(approxEqual(
    ordinaryBackF.a,
    ordinaryLabF.a,
    3e-6f,
    3e-6f
));

static assert(approxEqual(
    ordinaryBackF.b,
    ordinaryLabF.b,
    3e-6f,
    3e-6f
));


// --------------------------------------------------------------------------
// Runtime inspection
// --------------------------------------------------------------------------

void main()
{
    writeln("=== color-d R0.5 Oklab / OKLCH semantics ===");
    writeln();

    writeln("layout:");
    writeln(
        "  OklabHuef.sizeof = ",
        OklabHuef.sizeof,
        ", alignof = ",
        OklabHuef.alignof
    );

    writeln(
        "  OklabHued.sizeof = ",
        OklabHued.sizeof,
        ", alignof = ",
        OklabHued.alignof
    );

    writeln(
        "  Oklabf.sizeof    = ",
        Oklabf.sizeof,
        ", alignof = ",
        Oklabf.alignof
    );

    writeln(
        "  Oklchf.sizeof    = ",
        Oklchf.sizeof,
        ", alignof = ",
        Oklchf.alignof
    );

    writeln(
        "  Oklabd.sizeof    = ",
        Oklabd.sizeof,
        ", alignof = ",
        Oklabd.alignof
    );

    writeln(
        "  Oklchd.sizeof    = ",
        Oklchd.sizeof,
        ", alignof = ",
        Oklchd.alignof
    );

    writeln();
    writeln("hue normalization:");
    writeln(
        "  390 raw      = ",
        raw390.rawDegrees
    );
    writeln(
        "  390 positive = ",
        raw390.positiveDegrees
    );
    writeln(
        "  390 signed   = ",
        raw390.signedDegrees
    );
    writeln(
        "  -30 positive = ",
        rawMinus30.positiveDegrees
    );

    writeln();
    writeln("axes:");
    writeln("    0° = ", axis0);
    writeln("   90° = ", axis90);
    writeln("  180° = ", axis180);
    writeln("  270° = ", axis270);

    writeln();
    writeln("achromatic:");
    writeln("  lab = ", grayLab);
    writeln("  lch = ", grayLch);

    writeln();
    writeln("R0.4 references:");
    writeln("  red      = ", redLch);
    writeln("  green    = ", greenLch);
    writeln("  blue     = ", blueLch);
    writeln("  ordinary = ", ordinaryLch);
    writeln("  extended = ", extendedLch);

    writeln();
    writeln("raw revolution:");
    writeln("  30°  lch = ", lch30);
    writeln("  390° lch = ", lch390);
    writeln("  30°  lab = ", lab30);
    writeln("  390° lab = ", lab390);
    writeln("  back     = ", lch390Back);

    writeln();
    writeln("negative chroma:");
    writeln("  raw       = ", negativeChroma);
    writeln("  canonical = ", canonicalNegativeChroma);
    writeln("  raw lab   = ", negativeLab);
    writeln("  canon lab = ", canonicalNegativeLab);
    writeln("  back      = ", negativeRoundTrip);

    writeln();
    writeln("float:");
    writeln("  lab  = ", ordinaryLabF);
    writeln("  lch  = ", ordinaryLchF);
    writeln("  back = ", ordinaryBackF);
}
