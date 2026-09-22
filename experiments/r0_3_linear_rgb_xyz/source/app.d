module app;

import std.stdio : writeln;

enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


// --------------------------------------------------------------------------
// Candidate computational types
// --------------------------------------------------------------------------

struct LinearSRgb(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}

struct XyzD65(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T x;
    T y;
    T z;
}

alias LinearSRgbf = LinearSRgb!float;
alias LinearSRgbd = LinearSRgb!double;

alias XyzD65f = XyzD65!float;
alias XyzD65d = XyzD65!double;


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

    const T absActual   = magnitude(actual);
    const T absExpected = magnitude(expected);

    const T scale =
        absActual > absExpected
            ? absActual
            : absExpected;

    return diff <= relativeTolerance * scale;
}


// Rational coefficient helper.
//
// The conversion happens in T so that the experiment actually exercises
// float arithmetic for float colors and double arithmetic for double colors.
T q(T)(long numerator, long denominator)
@safe pure nothrow @nogc
{
    return cast(T)numerator / cast(T)denominator;
}


// --------------------------------------------------------------------------
// Linear sRGB -> XYZ D65
//
// Current CSS Color 4 reference coefficients:
//
// [ 506752/1228815   87881/245763    12673/70218   ]
// [  87098/409605   175762/245763    12673/175545  ]
// [   7918/409605    87881/737289  1001167/1053270 ]
// --------------------------------------------------------------------------

XyzD65!T toXyzD65(T)(LinearSRgb!T rgb)
@safe pure nothrow @nogc
{
    return XyzD65!T(
        q!T(506752, 1228815) * rgb.r +
        q!T(87881,   245763) * rgb.g +
        q!T(12673,    70218) * rgb.b,

        q!T(87098,   409605) * rgb.r +
        q!T(175762,  245763) * rgb.g +
        q!T(12673,   175545) * rgb.b,

        q!T(7918,    409605) * rgb.r +
        q!T(87881,   737289) * rgb.g +
        q!T(1001167, 1053270) * rgb.b
    );
}


// --------------------------------------------------------------------------
// XYZ D65 -> Linear sRGB
//
// Current CSS Color 4 inverse coefficients:
//
// [   12831/3959      -329/214      -1974/3959   ]
// [ -851781/878810  1648619/878810   36519/878810 ]
// [     705/12673     -2585/12673      705/667    ]
// --------------------------------------------------------------------------

LinearSRgb!T toLinearSRgb(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        q!T(12831,    3959)   * xyz.x +
        q!T(-329,      214)   * xyz.y +
        q!T(-1974,    3959)   * xyz.z,

        q!T(-851781, 878810)  * xyz.x +
        q!T(1648619, 878810)  * xyz.y +
        q!T(36519,   878810)  * xyz.z,

        q!T(705,      12673)  * xyz.x +
        q!T(-2585,    12673)  * xyz.y +
        q!T(705,        667)  * xyz.z
    );
}


// --------------------------------------------------------------------------
// Type/layout checks
// --------------------------------------------------------------------------

static assert(!is(LinearSRgbf == XyzD65f));
static assert(!is(LinearSRgbd == XyzD65d));

static assert(LinearSRgbf.sizeof == 3 * float.sizeof);
static assert(XyzD65f.sizeof     == 3 * float.sizeof);

static assert(LinearSRgbd.sizeof == 3 * double.sizeof);
static assert(XyzD65d.sizeof     == 3 * double.sizeof);


// --------------------------------------------------------------------------
// CTFE: black
// --------------------------------------------------------------------------

enum blackLinear = LinearSRgbd(0.0, 0.0, 0.0);
enum blackXyz = blackLinear.toXyzD65;

static assert(blackXyz.x == 0.0);
static assert(blackXyz.y == 0.0);
static assert(blackXyz.z == 0.0);


// --------------------------------------------------------------------------
// CTFE: sRGB primaries
//
// The XYZ coordinates of the unit primaries are the columns of the forward
// matrix. These assertions also protect against component/matrix ordering
// mistakes.
// --------------------------------------------------------------------------

enum redXyz =
    LinearSRgbd(1.0, 0.0, 0.0).toXyzD65;

static assert(approxEqual(
    redXyz.x,
    0.4123907992659595,
    1e-15,
    1e-14
));

static assert(approxEqual(
    redXyz.y,
    0.21263900587151036,
    1e-15,
    1e-14
));

static assert(approxEqual(
    redXyz.z,
    0.01933081871559185,
    1e-15,
    1e-14
));


enum greenXyz =
    LinearSRgbd(0.0, 1.0, 0.0).toXyzD65;

static assert(approxEqual(
    greenXyz.x,
    0.35758433938387796,
    1e-15,
    1e-14
));

static assert(approxEqual(
    greenXyz.y,
    0.7151686787677559,
    1e-15,
    1e-14
));

static assert(approxEqual(
    greenXyz.z,
    0.11919477979462599,
    1e-15,
    1e-14
));


enum blueXyz =
    LinearSRgbd(0.0, 0.0, 1.0).toXyzD65;

static assert(approxEqual(
    blueXyz.x,
    0.1804807884018343,
    1e-15,
    1e-14
));

static assert(approxEqual(
    blueXyz.y,
    0.07219231536073371,
    1e-15,
    1e-14
));

static assert(approxEqual(
    blueXyz.z,
    0.9505321522496606,
    1e-15,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: reference white
//
// Unit linear sRGB white must map to the D65 white point in normalized XYZ,
// with Y = 1.
// --------------------------------------------------------------------------

enum whiteLinear =
    LinearSRgbd(1.0, 1.0, 1.0);

enum whiteXyz =
    whiteLinear.toXyzD65;

enum double d65X =
    0.3127 / 0.3290;

enum double d65Y =
    1.0;

enum double d65Z =
    (1.0 - 0.3127 - 0.3290) / 0.3290;

static assert(approxEqual(
    whiteXyz.x,
    d65X,
    1e-15,
    1e-14
));

static assert(approxEqual(
    whiteXyz.y,
    d65Y,
    1e-15,
    1e-14
));

static assert(approxEqual(
    whiteXyz.z,
    d65Z,
    1e-15,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: inverse transform
// --------------------------------------------------------------------------

enum whiteBack =
    whiteXyz.toLinearSRgb;

static assert(approxEqual(
    whiteBack.r,
    1.0,
    1e-14,
    1e-14
));

static assert(approxEqual(
    whiteBack.g,
    1.0,
    1e-14,
    1e-14
));

static assert(approxEqual(
    whiteBack.b,
    1.0,
    1e-14,
    1e-14
));


enum redBack =
    redXyz.toLinearSRgb;

static assert(approxEqual(
    redBack.r,
    1.0,
    1e-14,
    1e-14
));

static assert(approxEqual(
    redBack.g,
    0.0,
    1e-14,
    1e-14
));

static assert(approxEqual(
    redBack.b,
    0.0,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: arbitrary in-gamut double round trip
// --------------------------------------------------------------------------

enum ordinary =
    LinearSRgbd(
        0.4352785666728059,
        0.017175850397231969,
        0.054553830782703643
    );

enum ordinaryXyz =
    ordinary.toXyzD65;

enum ordinaryBack =
    ordinaryXyz.toLinearSRgb;

static assert(approxEqual(
    ordinaryBack.r,
    ordinary.r,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryBack.g,
    ordinary.g,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryBack.b,
    ordinary.b,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: extended-range double
//
// This deliberately contains a negative channel and a channel above 1.
// No clipping must occur.
// --------------------------------------------------------------------------

enum extended =
    LinearSRgbd(
        -0.2,
         1.3,
         0.5
    );

enum extendedXyz =
    extended.toXyzD65;

enum extendedBack =
    extendedXyz.toLinearSRgb;


// Regression values calculated from the rational forward matrix.
static assert(approxEqual(
    extendedXyz.x,
    0.4726218755467666,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedXyz.y,
    0.9232876389041474,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedXyz.z,
    0.6263531261147257,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedBack.r,
    extended.r,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedBack.g,
    extended.g,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedBack.b,
    extended.b,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: float round trip
// --------------------------------------------------------------------------

enum ordinaryF =
    LinearSRgbf(
        0.43527857f,
        0.01717585f,
        0.05455383f
    );

enum ordinaryXyzF =
    ordinaryF.toXyzD65;

enum ordinaryBackF =
    ordinaryXyzF.toLinearSRgb;

static assert(approxEqual(
    ordinaryBackF.r,
    ordinaryF.r,
    2e-6f,
    2e-6f
));

static assert(approxEqual(
    ordinaryBackF.g,
    ordinaryF.g,
    2e-6f,
    2e-6f
));

static assert(approxEqual(
    ordinaryBackF.b,
    ordinaryF.b,
    2e-6f,
    2e-6f
));


// --------------------------------------------------------------------------
// Runtime inspection
// --------------------------------------------------------------------------

void main()
{
    writeln("=== color-d R0.3 linear sRGB <-> XYZ D65 ===");
    writeln();

    writeln("layout:");
    writeln(
        "  LinearSRgbf.sizeof = ",
        LinearSRgbf.sizeof,
        ", alignof = ",
        LinearSRgbf.alignof
    );

    writeln(
        "  XyzD65f.sizeof     = ",
        XyzD65f.sizeof,
        ", alignof = ",
        XyzD65f.alignof
    );

    writeln(
        "  LinearSRgbd.sizeof = ",
        LinearSRgbd.sizeof,
        ", alignof = ",
        LinearSRgbd.alignof
    );

    writeln(
        "  XyzD65d.sizeof     = ",
        XyzD65d.sizeof,
        ", alignof = ",
        XyzD65d.alignof
    );

    writeln();
    writeln("unit primaries:");
    writeln("  red   -> ", redXyz);
    writeln("  green -> ", greenXyz);
    writeln("  blue  -> ", blueXyz);

    writeln();
    writeln("D65 white:");
    writeln("  RGB  = ", whiteLinear);
    writeln("  XYZ  = ", whiteXyz);
    writeln("  back = ", whiteBack);

    writeln();
    writeln("ordinary:");
    writeln("  RGB  = ", ordinary);
    writeln("  XYZ  = ", ordinaryXyz);
    writeln("  back = ", ordinaryBack);

    writeln();
    writeln("extended range:");
    writeln("  RGB  = ", extended);
    writeln("  XYZ  = ", extendedXyz);
    writeln("  back = ", extendedBack);

    writeln();
    writeln("float:");
    writeln("  RGB  = ", ordinaryF);
    writeln("  XYZ  = ", ordinaryXyzF);
    writeln("  back = ", ordinaryBackF);
}
