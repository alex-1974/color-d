module app;

import std.math : pow;
import std.stdio : writeln;

enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


// --------------------------------------------------------------------------
// Candidate types
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

struct Oklab(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T a;
    T b;
}

alias LinearSRgbf = LinearSRgb!float;
alias LinearSRgbd = LinearSRgb!double;

alias XyzD65f = XyzD65!float;
alias XyzD65d = XyzD65!double;

alias Oklabf = Oklab!float;
alias Oklabd = Oklab!double;


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

T cube(T)(T value)
@safe pure nothrow @nogc
{
    return value * value * value;
}

T cubeRoot(T)(const T value)
@safe pure nothrow @nogc
{
    // Portable CTFE baseline.
    //
    // pow(value, 1/3) cannot be applied directly to negative values.
    // Oklab requires a real, sign-preserving cube root because extended
    // colors may produce negative LMS intermediates.
    //
    // Returning zero unchanged also preserves the sign of -0.0.
    if (value == 0)
        return value;

    const T absValue =
        value < 0
            ? -value
            : value;

    const T root = cast(T)pow(
        absValue,
        cast(T)(1.0L / 3.0L)
    );

    return value < 0
        ? -root
        : root;
}


// --------------------------------------------------------------------------
// Linear sRGB -> XYZ D65
//
// Same rational matrix validated in R0.3.
// --------------------------------------------------------------------------

T q(T)(long numerator, long denominator)
@safe pure nothrow @nogc
{
    return cast(T)numerator / cast(T)denominator;
}

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
// XYZ D65 -> Oklab
//
// Current CSS Color 4 high-precision matrices.
//
// XYZ -> LMS
// --------------------------------------------------------------------------

Oklab!T toOklab(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
{
    const T l =
        cast(T)0.8190224379967030 * xyz.x +
        cast(T)0.3619062600528904 * xyz.y -
        cast(T)0.1288737815209879 * xyz.z;

    const T m =
        cast(T)0.0329836539323885 * xyz.x +
        cast(T)0.9292868615863434 * xyz.y +
        cast(T)0.0361446663506424 * xyz.z;

    const T s =
        cast(T)0.0481771893596242 * xyz.x +
        cast(T)0.2642395317527308 * xyz.y +
        cast(T)0.6335478284694309 * xyz.z;

    const T lp = cubeRoot(l);
    const T mp = cubeRoot(m);
    const T sp = cubeRoot(s);

    return Oklab!T(
        cast(T)0.2104542683093140 * lp +
        cast(T)0.7936177747023054 * mp -
        cast(T)0.0040720430116193 * sp,

        cast(T)1.9779985324311684 * lp -
        cast(T)2.4285922420485799 * mp +
        cast(T)0.4505937096174110 * sp,

        cast(T)0.0259040424655478 * lp +
        cast(T)0.7827717124575296 * mp -
        cast(T)0.8086757549230774 * sp
    );
}


// --------------------------------------------------------------------------
// Oklab -> XYZ D65
// --------------------------------------------------------------------------

XyzD65!T toXyzD65(T)(Oklab!T lab)
@safe pure nothrow @nogc
{
    const T lp =
        lab.l +
        cast(T)0.3963377773761749 * lab.a +
        cast(T)0.2158037573099136 * lab.b;

    const T mp =
        lab.l -
        cast(T)0.1055613458156586 * lab.a -
        cast(T)0.0638541728258133 * lab.b;

    const T sp =
        lab.l -
        cast(T)0.0894841775298119 * lab.a -
        cast(T)1.2914855480194092 * lab.b;

    const T l = cube(lp);
    const T m = cube(mp);
    const T s = cube(sp);

    return XyzD65!T(
        cast(T)1.2268798758459243 * l -
        cast(T)0.5578149944602171 * m +
        cast(T)0.2813910456659647 * s,

       -cast(T)0.0405757452148008 * l +
        cast(T)1.1122868032803170 * m -
        cast(T)0.0717110580655164 * s,

       -cast(T)0.0763729366746601 * l -
        cast(T)0.4214933324022432 * m +
        cast(T)1.5869240198367816 * s
    );
}


// --------------------------------------------------------------------------
// Independent direct linear-sRGB -> Oklab reference path
//
// Björn Ottosson 2021 matrices.
// This is a comparator, not assumed to be bit-identical to the CSS XYZ path.
// --------------------------------------------------------------------------

Oklab!T directLinearSRgbToOklab(T)(LinearSRgb!T rgb)
@safe pure nothrow @nogc
{
    const T l =
        cast(T)0.4122214708 * rgb.r +
        cast(T)0.5363325363 * rgb.g +
        cast(T)0.0514459929 * rgb.b;

    const T m =
        cast(T)0.2119034982 * rgb.r +
        cast(T)0.6806995451 * rgb.g +
        cast(T)0.1073969566 * rgb.b;

    const T s =
        cast(T)0.0883024619 * rgb.r +
        cast(T)0.2817188376 * rgb.g +
        cast(T)0.6299787005 * rgb.b;

    const T lp = cubeRoot(l);
    const T mp = cubeRoot(m);
    const T sp = cubeRoot(s);

    return Oklab!T(
        cast(T)0.2104542553 * lp +
        cast(T)0.7936177850 * mp -
        cast(T)0.0040720468 * sp,

        cast(T)1.9779984951 * lp -
        cast(T)2.4285922050 * mp +
        cast(T)0.4505937099 * sp,

        cast(T)0.0259040371 * lp +
        cast(T)0.7827717662 * mp -
        cast(T)0.8086757660 * sp
    );
}


// --------------------------------------------------------------------------
// Type/layout
// --------------------------------------------------------------------------

static assert(!is(XyzD65f == Oklabf));
static assert(!is(XyzD65d == Oklabd));

static assert(XyzD65f.sizeof == 3 * float.sizeof);
static assert(Oklabf.sizeof  == 3 * float.sizeof);

static assert(XyzD65d.sizeof == 3 * double.sizeof);
static assert(Oklabd.sizeof  == 3 * double.sizeof);


// --------------------------------------------------------------------------
// CTFE: cube root semantics
// --------------------------------------------------------------------------

static assert(cubeRoot(0.0) == 0.0);

enum positiveZeroRoot = cubeRoot(0.0);
enum negativeZeroRoot = cubeRoot(-0.0);

static assert(1.0 / positiveZeroRoot == double.infinity);
static assert(1.0 / negativeZeroRoot == -double.infinity);

static assert(approxEqual(
    cubeRoot(8.0),
    2.0,
    1e-15,
    1e-15
));

static assert(approxEqual(
    cubeRoot(-8.0),
    -2.0,
    1e-15,
    1e-15
));


// --------------------------------------------------------------------------
// CTFE: black
// --------------------------------------------------------------------------

enum blackXyz = XyzD65d(0.0, 0.0, 0.0);
enum blackLab = blackXyz.toOklab;

static assert(blackLab.l == 0.0);
static assert(blackLab.a == 0.0);
static assert(blackLab.b == 0.0);


// --------------------------------------------------------------------------
// CTFE: D65 white
// --------------------------------------------------------------------------

enum whiteRgb = LinearSRgbd(1.0, 1.0, 1.0);
enum whiteXyz = whiteRgb.toXyzD65;
enum whiteLab = whiteXyz.toOklab;

static assert(approxEqual(
    whiteLab.l,
    1.0,
    1e-14,
    1e-14
));

static assert(approxEqual(
    whiteLab.a,
    0.0,
    1e-14,
    1e-14
));

static assert(approxEqual(
    whiteLab.b,
    0.0,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: unit primaries
// --------------------------------------------------------------------------

enum redRgb = LinearSRgbd(1.0, 0.0, 0.0);
enum redLab = redRgb.toXyzD65.toOklab;

static assert(approxEqual(
    redLab.l,
    0.6279553639214313,
    1e-14,
    1e-14
));

static assert(approxEqual(
    redLab.a,
    0.2248630684262741,
    1e-14,
    1e-14
));

static assert(approxEqual(
    redLab.b,
    0.1258462773305850,
    1e-14,
    1e-14
));


enum greenRgb = LinearSRgbd(0.0, 1.0, 0.0);
enum greenLab = greenRgb.toXyzD65.toOklab;

static assert(approxEqual(
    greenLab.l,
    0.8664396175234368,
    1e-14,
    1e-14
));

static assert(approxEqual(
    greenLab.a,
    -0.2338875809365576,
    1e-14,
    1e-14
));

static assert(approxEqual(
    greenLab.b,
    0.1794984451609376,
    1e-14,
    1e-14
));


enum blueRgb = LinearSRgbd(0.0, 0.0, 1.0);
enum blueLab = blueRgb.toXyzD65.toOklab;

static assert(approxEqual(
    blueLab.l,
    0.45201371817442365,
    1e-14,
    1e-14
));

static assert(approxEqual(
    blueLab.a,
    -0.03245697517079776,
    1e-14,
    1e-14
));

static assert(approxEqual(
    blueLab.b,
    -0.3115281656775777,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: inverse XYZ round trip
// --------------------------------------------------------------------------

enum redXyz = redRgb.toXyzD65;
enum redXyzBack = redXyz.toOklab.toXyzD65;

static assert(approxEqual(
    redXyzBack.x,
    redXyz.x,
    1e-14,
    1e-14
));

static assert(approxEqual(
    redXyzBack.y,
    redXyz.y,
    1e-14,
    1e-14
));

static assert(approxEqual(
    redXyzBack.z,
    redXyz.z,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: ordinary reference
// --------------------------------------------------------------------------

enum ordinaryRgb =
    LinearSRgbd(
        0.4352785666728059,
        0.017175850397231969,
        0.054553830782703643
    );

enum ordinaryXyz = ordinaryRgb.toXyzD65;
enum ordinaryLab = ordinaryXyz.toOklab;
enum ordinaryXyzBack = ordinaryLab.toXyzD65;

static assert(approxEqual(
    ordinaryLab.l,
    0.49956838997607944,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryLab.a,
    0.16935376231011406,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryLab.b,
    0.04475580639007088,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryXyzBack.x,
    ordinaryXyz.x,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryXyzBack.y,
    ordinaryXyz.y,
    1e-14,
    1e-14
));

static assert(approxEqual(
    ordinaryXyzBack.z,
    ordinaryXyz.z,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: extended-range reference
// --------------------------------------------------------------------------

enum extendedRgb =
    LinearSRgbd(
        -0.2,
         1.3,
         0.5
    );

enum extendedXyz = extendedRgb.toXyzD65;
enum extendedLab = extendedXyz.toOklab;
enum extendedXyzBack = extendedLab.toXyzD65;

static assert(approxEqual(
    extendedLab.l,
    0.9430178754560363,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedLab.a,
    -0.2434398510145207,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedLab.b,
    0.0716841414885879,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedXyzBack.x,
    extendedXyz.x,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedXyzBack.y,
    extendedXyz.y,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedXyzBack.z,
    extendedXyz.z,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE: float
// --------------------------------------------------------------------------

enum ordinaryRgbF =
    LinearSRgbf(
        0.43527857f,
        0.01717585f,
        0.05455383f
    );

enum ordinaryXyzF = ordinaryRgbF.toXyzD65;
enum ordinaryLabF = ordinaryXyzF.toOklab;
enum ordinaryXyzBackF = ordinaryLabF.toXyzD65;

static assert(approxEqual(
    ordinaryXyzBackF.x,
    ordinaryXyzF.x,
    3e-6f,
    3e-6f
));

static assert(approxEqual(
    ordinaryXyzBackF.y,
    ordinaryXyzF.y,
    3e-6f,
    3e-6f
));

static assert(approxEqual(
    ordinaryXyzBackF.z,
    ordinaryXyzF.z,
    3e-6f,
    3e-6f
));


// --------------------------------------------------------------------------
// Direct-path comparison
//
// The two independently sourced paths are deliberately not expected to be
// bit-identical. They should, however, remain very close.
// --------------------------------------------------------------------------

enum redLabDirect = directLinearSRgbToOklab(redRgb);
enum ordinaryLabDirect = directLinearSRgbToOklab(ordinaryRgb);
enum extendedLabDirect = directLinearSRgbToOklab(extendedRgb);

static assert(approxEqual(
    redLabDirect.l,
    redLab.l,
    5e-8,
    5e-8
));

static assert(approxEqual(
    redLabDirect.a,
    redLab.a,
    5e-8,
    5e-8
));

static assert(approxEqual(
    redLabDirect.b,
    redLab.b,
    5e-8,
    5e-8
));

static assert(approxEqual(
    ordinaryLabDirect.l,
    ordinaryLab.l,
    5e-8,
    5e-8
));

static assert(approxEqual(
    ordinaryLabDirect.a,
    ordinaryLab.a,
    5e-8,
    5e-8
));

static assert(approxEqual(
    ordinaryLabDirect.b,
    ordinaryLab.b,
    5e-8,
    5e-8
));

static assert(approxEqual(
    extendedLabDirect.l,
    extendedLab.l,
    5e-8,
    5e-8
));

static assert(approxEqual(
    extendedLabDirect.a,
    extendedLab.a,
    5e-8,
    5e-8
));

static assert(approxEqual(
    extendedLabDirect.b,
    extendedLab.b,
    5e-8,
    5e-8
));


// --------------------------------------------------------------------------
// Runtime inspection
// --------------------------------------------------------------------------

void main()
{
    writeln("=== color-d R0.4 XYZ D65 <-> Oklab ===");
    writeln();

    writeln("layout:");
    writeln(
        "  XyzD65f.sizeof = ",
        XyzD65f.sizeof,
        ", alignof = ",
        XyzD65f.alignof
    );

    writeln(
        "  Oklabf.sizeof  = ",
        Oklabf.sizeof,
        ", alignof = ",
        Oklabf.alignof
    );

    writeln(
        "  XyzD65d.sizeof = ",
        XyzD65d.sizeof,
        ", alignof = ",
        XyzD65d.alignof
    );

    writeln(
        "  Oklabd.sizeof  = ",
        Oklabd.sizeof,
        ", alignof = ",
        Oklabd.alignof
    );

    writeln();
    writeln("D65 white:");
    writeln("  XYZ    = ", whiteXyz);
    writeln("  Oklab  = ", whiteLab);
    writeln("  back   = ", whiteLab.toXyzD65);

    writeln();
    writeln("unit primaries:");
    writeln("  red    = ", redLab);
    writeln("  green  = ", greenLab);
    writeln("  blue   = ", blueLab);

    writeln();
    writeln("ordinary:");
    writeln("  XYZ    = ", ordinaryXyz);
    writeln("  Oklab  = ", ordinaryLab);
    writeln("  back   = ", ordinaryXyzBack);

    writeln();
    writeln("extended range:");
    writeln("  XYZ    = ", extendedXyz);
    writeln("  Oklab  = ", extendedLab);
    writeln("  back   = ", extendedXyzBack);

    writeln();
    writeln("direct linear-sRGB comparison:");
    writeln("  red via XYZ      = ", redLab);
    writeln("  red direct       = ", redLabDirect);
    writeln("  ordinary via XYZ = ", ordinaryLab);
    writeln("  ordinary direct  = ", ordinaryLabDirect);
    writeln("  extended via XYZ = ", extendedLab);
    writeln("  extended direct  = ", extendedLabDirect);

    writeln();
    writeln("float:");
    writeln("  XYZ    = ", ordinaryXyzF);
    writeln("  Oklab  = ", ordinaryLabF);
    writeln("  back   = ", ordinaryXyzBackF);
}
