module app;

import std.math : pow;
import std.stdio : writeln;

enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


// --------------------------------------------------------------------------
// Candidate types
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

alias SRgbf       = SRgb!float;
alias SRgbd       = SRgb!double;
alias LinearSRgbf = LinearSRgb!float;
alias LinearSRgbd = LinearSRgb!double;


// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

T magnitude(T)(T value)
@safe pure nothrow @nogc
{
    return value < 0 ? -value : value;
}

T signOf(T)(T value)
@safe pure nothrow @nogc
{
    return value < 0 ? cast(T)-1 : cast(T)1;
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
        absActual > absExpected ? absActual : absExpected;

    return diff <= relativeTolerance * scale;
}


// --------------------------------------------------------------------------
// sRGB transfer functions
// --------------------------------------------------------------------------

T srgbToLinearComponent(T)(T encoded)
@safe pure nothrow @nogc
{
    const T absEncoded = magnitude(encoded);

    if (absEncoded <= cast(T)0.04045)
        return encoded / cast(T)12.92;

    const T base =
        (absEncoded + cast(T)0.055) /
        cast(T)1.055;

    return signOf(encoded) *
        cast(T)pow(base, cast(T)2.4);
}

T linearToSrgbComponent(T)(T linear)
@safe pure nothrow @nogc
{
    const T absLinear = magnitude(linear);

    if (absLinear <= cast(T)0.0031308)
        return linear * cast(T)12.92;

    const T exponent =
        cast(T)(1.0 / 2.4);

    const T encodedMagnitude =
        cast(T)1.055 *
        cast(T)pow(absLinear, exponent) -
        cast(T)0.055;

    return signOf(linear) * encodedMagnitude;
}


// --------------------------------------------------------------------------
// Whole-color conversions
// --------------------------------------------------------------------------

LinearSRgb!T toLinear(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        srgbToLinearComponent(color.r),
        srgbToLinearComponent(color.g),
        srgbToLinearComponent(color.b)
    );
}

SRgb!T toSRgb(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return SRgb!T(
        linearToSrgbComponent(color.r),
        linearToSrgbComponent(color.g),
        linearToSrgbComponent(color.b)
    );
}


// --------------------------------------------------------------------------
// Type model
// --------------------------------------------------------------------------

static assert(!is(SRgbf == LinearSRgbf));
static assert(!is(SRgbd == LinearSRgbd));

static assert(SRgbf.sizeof == 12);
static assert(LinearSRgbf.sizeof == 12);
static assert(SRgbd.sizeof == 24);
static assert(LinearSRgbd.sizeof == 24);


// --------------------------------------------------------------------------
// CTFE reference tests — double
// --------------------------------------------------------------------------

static assert(approxEqual(
    srgbToLinearComponent(0.0),
    0.0,
    1e-15,
    1e-15
));

static assert(approxEqual(
    srgbToLinearComponent(1.0),
    1.0,
    1e-15,
    1e-15
));

static assert(approxEqual(
    srgbToLinearComponent(0.5),
    0.21404114048223255,
    1e-15,
    1e-14
));

static assert(approxEqual(
    srgbToLinearComponent(-0.5),
    -0.21404114048223255,
    1e-15,
    1e-14
));

static assert(approxEqual(
    srgbToLinearComponent(1.2),
    1.5168374366863642,
    1e-14,
    1e-14
));


// Threshold itself.
static assert(approxEqual(
    srgbToLinearComponent(0.04045),
    0.0031308049535603713,
    1e-15,
    1e-14
));


// CSS Color example, more precise result from the transfer equation.
static assert(approxEqual(
    srgbToLinearComponent(0.691),
    0.4352785666728059,
    1e-15,
    1e-14
));

static assert(approxEqual(
    srgbToLinearComponent(0.139),
    0.017175850397231969,
    1e-15,
    1e-14
));

static assert(approxEqual(
    srgbToLinearComponent(0.259),
    0.054553830782703643,
    1e-15,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE reference tests — float
// --------------------------------------------------------------------------

static assert(approxEqual(
    srgbToLinearComponent(0.5f),
    0.21404114f,
    1e-7f,
    1e-6f
));

static assert(approxEqual(
    srgbToLinearComponent(-0.5f),
    -0.21404114f,
    1e-7f,
    1e-6f
));

static assert(approxEqual(
    srgbToLinearComponent(1.2f),
    1.5168374f,
    2e-7f,
    2e-6f
));


// --------------------------------------------------------------------------
// Inverse transfer tests
// --------------------------------------------------------------------------

static assert(approxEqual(
    linearToSrgbComponent(0.21404114048223255),
    0.5,
    1e-15,
    1e-14
));

static assert(approxEqual(
    linearToSrgbComponent(-0.21404114048223255),
    -0.5,
    1e-15,
    1e-14
));

static assert(approxEqual(
    linearToSrgbComponent(1.5168374366863642),
    1.2,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// Full color CTFE
// --------------------------------------------------------------------------

enum encoded = SRgbf(
    0.691f,
    0.139f,
    0.259f
);

enum linear = encoded.toLinear;
enum roundTrip = linear.toSRgb;

static assert(approxEqual(
    roundTrip.r,
    encoded.r,
    2e-7f,
    2e-6f
));

static assert(approxEqual(
    roundTrip.g,
    encoded.g,
    2e-7f,
    2e-6f
));

static assert(approxEqual(
    roundTrip.b,
    encoded.b,
    2e-7f,
    2e-6f
));


// --------------------------------------------------------------------------
// Extended-range CTFE
// --------------------------------------------------------------------------

enum extendedEncoded = SRgbd(
    -0.5,
    1.2,
    0.5
);

enum extendedLinear = extendedEncoded.toLinear;
enum extendedRoundTrip = extendedLinear.toSRgb;

static assert(extendedLinear.r < 0.0);
static assert(extendedLinear.g > 1.0);

static assert(approxEqual(
    extendedRoundTrip.r,
    extendedEncoded.r,
    1e-14,
    1e-14
));

static assert(approxEqual(
    extendedRoundTrip.g,
    extendedEncoded.g,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// Runtime output
// --------------------------------------------------------------------------

void main()
{
    writeln("=== color-d R0.2 sRGB transfer / CTFE ===");
    writeln();

    writeln("Reference color:");
    writeln("  encoded = ", encoded);
    writeln("  linear  = ", linear);
    writeln("  back    = ", roundTrip);

    writeln();
    writeln("Extended-range color:");
    writeln("  encoded = ", extendedEncoded);
    writeln("  linear  = ", extendedLinear);
    writeln("  back    = ", extendedRoundTrip);

    writeln();
    writeln("Component reference values:");

    foreach (value; [
        -0.5,
        0.0,
        0.04045,
        0.5,
        1.0,
        1.2
    ])
    {
        const l = srgbToLinearComponent(value);
        const e = linearToSrgbComponent(l);

        writeln(
            "  ",
            value,
            " -> ",
            l,
            " -> ",
            e
        );
    }
}
