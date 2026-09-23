module app;

import std.math : pow;
import std.stdio : writeln;


// --------------------------------------------------------------------------
// Scalar model
// --------------------------------------------------------------------------

enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


// --------------------------------------------------------------------------
// Candidate color types
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

struct XyzD65(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T x;
    T y;
    T z;
}

alias SRgbf       = SRgb!float;
alias SRgbd       = SRgb!double;
alias LinearSRgbf = LinearSRgb!float;
alias LinearSRgbd = LinearSRgb!double;
alias XyzD65f     = XyzD65!float;
alias XyzD65d     = XyzD65!double;


// --------------------------------------------------------------------------
// Generic helpers
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

bool finiteValue(T)(T value)
@safe pure nothrow @nogc
{
    // NaN fails value == value.
    // +/- infinity exceed the largest finite magnitude.
    return
        value == value &&
        value <= T.max &&
        value >= -T.max;
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

T q(T)(long numerator, long denominator)
@safe pure nothrow @nogc
{
    return
        cast(T)numerator /
        cast(T)denominator;
}


// --------------------------------------------------------------------------
// Domain diagnostics
//
// Diagnostic only.
// No candidate measurement function below silently clamps or rejects.
// --------------------------------------------------------------------------

bool isValidWcag2SrgbDomain(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return
        finiteValue(color.r) &&
        finiteValue(color.g) &&
        finiteValue(color.b) &&

        color.r >= cast(T)0 &&
        color.r <= cast(T)1 &&

        color.g >= cast(T)0 &&
        color.g <= cast(T)1 &&

        color.b >= cast(T)0 &&
        color.b <= cast(T)1;
}

bool isValidWcag2LinearSrgbDomain(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return
        finiteValue(color.r) &&
        finiteValue(color.g) &&
        finiteValue(color.b) &&

        color.r >= cast(T)0 &&
        color.r <= cast(T)1 &&

        color.g >= cast(T)0 &&
        color.g <= cast(T)1 &&

        color.b >= cast(T)0 &&
        color.b <= cast(T)1;
}


// --------------------------------------------------------------------------
// color-d R0.2 extended sRGB transfer semantics
//
// This is intentionally sign-preserving outside the ordinary [0, 1] domain.
// Within [0, 1] it is the ordinary current sRGB transfer function.
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

    return
        signOf(encoded) *
        cast(T)pow(base, cast(T)2.4);
}

LinearSRgb!T toLinear(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        srgbToLinearComponent(color.r),
        srgbToLinearComponent(color.g),
        srgbToLinearComponent(color.b)
    );
}


// --------------------------------------------------------------------------
// Direct WCAG 2.2 reference decoder
//
// This follows the W3C formula literally.
//
// IMPORTANT:
// The normative WCAG sRGB domain is [0, 1].
// The behavior for negative extended values is observed only to expose
// the difference from color-d's sign-preserving extended transfer semantics.
// --------------------------------------------------------------------------

T wcag2ReferenceDecodeComponent(T)(T encoded)
@safe pure nothrow @nogc
{
    if (encoded <= cast(T)0.04045)
        return encoded / cast(T)12.92;

    const T base =
        (encoded + cast(T)0.055) /
        cast(T)1.055;

    return cast(T)pow(
        base,
        cast(T)2.4
    );
}


// --------------------------------------------------------------------------
// WCAG 2 relative luminance
//
// Published WCAG weights are intentionally used here rather than the more
// precise XYZ-D65 Y-row coefficients.
// --------------------------------------------------------------------------

T wcag2RelativeLuminance(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return
        cast(T)0.2126 * color.r +
        cast(T)0.7152 * color.g +
        cast(T)0.0722 * color.b;
}

T wcag2RelativeLuminance(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return wcag2RelativeLuminance(
        color.toLinear
    );
}


// --------------------------------------------------------------------------
// Independent direct WCAG reference path
// --------------------------------------------------------------------------

T referenceWcag2RelativeLuminance(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return
        cast(T)0.2126 *
            wcag2ReferenceDecodeComponent(color.r) +

        cast(T)0.7152 *
            wcag2ReferenceDecodeComponent(color.g) +

        cast(T)0.0722 *
            wcag2ReferenceDecodeComponent(color.b);
}


// --------------------------------------------------------------------------
// Validated R0.3 XYZ-D65 Y row
//
// CSS Color 4 rational matrix:
//
// Y =
//     87098/409605  * R +
//     175762/245763 * G +
//     12673/175545  * B
//
// This must NOT be silently substituted for the published WCAG weights.
// --------------------------------------------------------------------------

T xyzD65Y(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return
        q!T(87098, 409605) * color.r +
        q!T(175762, 245763) * color.g +
        q!T(12673, 175545) * color.b;
}

XyzD65!T toXyzD65(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return XyzD65!T(
        q!T(506752, 1228815) * color.r +
        q!T(87881,   245763) * color.g +
        q!T(12673,    70218) * color.b,

        xyzD65Y(color),

        q!T(7918,     409605) * color.r +
        q!T(87881,    737289) * color.g +
        q!T(1001167, 1053270) * color.b
    );
}


// --------------------------------------------------------------------------
// WCAG 2 contrast ratio
//
// Arithmetic candidate.
//
// No hidden validation, clipping or gamut mapping is performed so R0.9 can
// explicitly observe invalid-domain behavior before deciding the public API.
// --------------------------------------------------------------------------

T wcag2ContrastFromLuminance(T)(T a, T b)
@safe pure nothrow @nogc
{
    const bool aIsLighter = a >= b;

    const T lighter =
        aIsLighter ? a : b;

    const T darker =
        aIsLighter ? b : a;

    return
        (lighter + cast(T)0.05) /
        (darker  + cast(T)0.05);
}

T wcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b
)
@safe pure nothrow @nogc
{
    return wcag2ContrastFromLuminance(
        wcag2RelativeLuminance(a),
        wcag2RelativeLuminance(b)
    );
}

T wcag2ContrastRatio(T)(
    LinearSRgb!T a,
    LinearSRgb!T b
)
@safe pure nothrow @nogc
{
    return wcag2ContrastFromLuminance(
        wcag2RelativeLuminance(a),
        wcag2RelativeLuminance(b)
    );
}


// --------------------------------------------------------------------------
// Alpha study
//
// Only an opaque-background source-over helper is needed to demonstrate the
// semantic boundary. This is NOT a proposed contrast overload.
// --------------------------------------------------------------------------

LinearSRgb!T sourceOverOpaque(T)(
    LinearSRgb!T foreground,
    T alpha,
    LinearSRgb!T background
)
@safe pure nothrow @nogc
{
    const T oneMinusAlpha =
        cast(T)1 - alpha;

    return LinearSRgb!T(
        foreground.r * alpha +
            background.r * oneMinusAlpha,

        foreground.g * alpha +
            background.g * oneMinusAlpha,

        foreground.b * alpha +
            background.b * oneMinusAlpha
    );
}


// --------------------------------------------------------------------------
// Type / layout checks
// --------------------------------------------------------------------------

static assert(!is(SRgbf == LinearSRgbf));
static assert(!is(SRgbf == XyzD65f));
static assert(!is(LinearSRgbf == XyzD65f));

static assert(SRgbf.sizeof == 3 * float.sizeof);
static assert(LinearSRgbf.sizeof == 3 * float.sizeof);
static assert(XyzD65f.sizeof == 3 * float.sizeof);

static assert(SRgbd.sizeof == 3 * double.sizeof);
static assert(LinearSRgbd.sizeof == 3 * double.sizeof);
static assert(XyzD65d.sizeof == 3 * double.sizeof);


// --------------------------------------------------------------------------
// Compile-time API constraints
// --------------------------------------------------------------------------

static assert(!__traits(
    compiles,
    wcag2ContrastRatio(
        SRgbf(0.0f, 0.0f, 0.0f),
        SRgbd(1.0, 1.0, 1.0)
    )
));


// --------------------------------------------------------------------------
// R0.9-C — domain/API policy candidates
// --------------------------------------------------------------------------

// Candidate 1:
//
// Assertion-based contract.
//
// This can protect programmer invariants in assertion-enabled builds, but it
// is deliberately NOT treated as sufficient evidence for a standards-facing
// runtime domain contract. The assertion may not be present in all build
// configurations.
T assertingWcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b
)
@safe pure nothrow @nogc
{
    assert(isValidWcag2SrgbDomain(a));
    assert(isValidWcag2SrgbDomain(b));

    return wcag2ContrastRatio(a, b);
}


// Candidate 2:
//
// try-style API.
//
// On failure, `ratio` remains unchanged. This avoids returning a plausible
// numeric value for invalid-domain input.
bool tryWcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b,
    ref T ratio
)
@safe pure nothrow @nogc
{
    if (
        !isValidWcag2SrgbDomain(a) ||
        !isValidWcag2SrgbDomain(b)
    )
    {
        return false;
    }

    ratio = wcag2ContrastRatio(a, b);
    return true;
}

bool tryWcag2ContrastRatio(T)(
    LinearSRgb!T a,
    LinearSRgb!T b,
    ref T ratio
)
@safe pure nothrow @nogc
{
    if (
        !isValidWcag2LinearSrgbDomain(a) ||
        !isValidWcag2LinearSrgbDomain(b)
    )
    {
        return false;
    }

    ratio = wcag2ContrastRatio(a, b);
    return true;
}


// Candidate 3:
//
// Small value + validity result.
//
// Invalid input returns NaN as the payload so that ignoring `valid` does not
// silently turn invalid WCAG input into a plausible ordinary ratio.
struct Wcag2Measurement(T)
if (isColorScalar!T)
{
    T value;
    bool valid;
}

Wcag2Measurement!T checkedWcag2RelativeLuminance(T)(
    SRgb!T color
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2SrgbDomain(color))
    {
        return Wcag2Measurement!T(
            T.nan,
            false
        );
    }

    return Wcag2Measurement!T(
        wcag2RelativeLuminance(color),
        true
    );
}

Wcag2Measurement!T checkedWcag2RelativeLuminance(T)(
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2LinearSrgbDomain(color))
    {
        return Wcag2Measurement!T(
            T.nan,
            false
        );
    }

    return Wcag2Measurement!T(
        wcag2RelativeLuminance(color),
        true
    );
}

Wcag2Measurement!T checkedWcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b
)
@safe pure nothrow @nogc
{
    if (
        !isValidWcag2SrgbDomain(a) ||
        !isValidWcag2SrgbDomain(b)
    )
    {
        return Wcag2Measurement!T(
            T.nan,
            false
        );
    }

    return Wcag2Measurement!T(
        wcag2ContrastRatio(a, b),
        true
    );
}

Wcag2Measurement!T checkedWcag2ContrastRatio(T)(
    LinearSRgb!T a,
    LinearSRgb!T b
)
@safe pure nothrow @nogc
{
    if (
        !isValidWcag2LinearSrgbDomain(a) ||
        !isValidWcag2LinearSrgbDomain(b)
    )
    {
        return Wcag2Measurement!T(
            T.nan,
            false
        );
    }

    return Wcag2Measurement!T(
        wcag2ContrastRatio(a, b),
        true
    );
}


// CTFE checks for checked API candidates.

enum checkedBlackWhite =
    checkedWcag2ContrastRatio(
        SRgbd(0.0, 0.0, 0.0),
        SRgbd(1.0, 1.0, 1.0)
    );

static assert(checkedBlackWhite.valid);

static assert(approxEqual(
    checkedBlackWhite.value,
    21.0,
    1e-14,
    1e-14
));

enum checkedInvalid =
    checkedWcag2ContrastRatio(
        SRgbd(-0.5, 0.0, 0.0),
        SRgbd(1.0, 1.0, 1.0)
    );

static assert(!checkedInvalid.valid);
static assert(checkedInvalid.value != checkedInvalid.value);

// --------------------------------------------------------------------------
// CTFE — WCAG luminance invariants
// --------------------------------------------------------------------------

enum blackEncodedD =
    SRgbd(0.0, 0.0, 0.0);

enum whiteEncodedD =
    SRgbd(1.0, 1.0, 1.0);

enum blackLinearD =
    LinearSRgbd(0.0, 0.0, 0.0);

enum whiteLinearD =
    LinearSRgbd(1.0, 1.0, 1.0);

static assert(
    wcag2RelativeLuminance(blackLinearD) == 0.0
);

static assert(
    wcag2RelativeLuminance(whiteLinearD) == 1.0
);

static assert(approxEqual(
    wcag2RelativeLuminance(blackEncodedD),
    0.0,
    1e-15,
    1e-15
));

static assert(approxEqual(
    wcag2RelativeLuminance(whiteEncodedD),
    1.0,
    1e-15,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE — WCAG primary coefficients
// --------------------------------------------------------------------------

static assert(approxEqual(
    wcag2RelativeLuminance(
        LinearSRgbd(1.0, 0.0, 0.0)
    ),
    0.2126,
    1e-15,
    1e-15
));

static assert(approxEqual(
    wcag2RelativeLuminance(
        LinearSRgbd(0.0, 1.0, 0.0)
    ),
    0.7152,
    1e-15,
    1e-15
));

static assert(approxEqual(
    wcag2RelativeLuminance(
        LinearSRgbd(0.0, 0.0, 1.0)
    ),
    0.0722,
    1e-15,
    1e-15
));


// --------------------------------------------------------------------------
// CTFE — encoded middle gray
// --------------------------------------------------------------------------

static assert(approxEqual(
    wcag2RelativeLuminance(
        SRgbd(0.5, 0.5, 0.5)
    ),
    0.21404114048223255,
    1e-15,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE — current transfer breakpoint
// --------------------------------------------------------------------------

static assert(approxEqual(
    wcag2RelativeLuminance(
        SRgbd(0.04044, 0.04044, 0.04044)
    ),
    referenceWcag2RelativeLuminance(
        SRgbd(0.04044, 0.04044, 0.04044)
    ),
    1e-15,
    1e-14
));

static assert(approxEqual(
    wcag2RelativeLuminance(
        SRgbd(0.04045, 0.04045, 0.04045)
    ),
    referenceWcag2RelativeLuminance(
        SRgbd(0.04045, 0.04045, 0.04045)
    ),
    1e-15,
    1e-14
));

static assert(approxEqual(
    wcag2RelativeLuminance(
        SRgbd(0.04046, 0.04046, 0.04046)
    ),
    referenceWcag2RelativeLuminance(
        SRgbd(0.04046, 0.04046, 0.04046)
    ),
    1e-15,
    1e-14
));


// --------------------------------------------------------------------------
// CTFE — contrast invariants
// --------------------------------------------------------------------------

static assert(approxEqual(
    wcag2ContrastRatio(
        blackEncodedD,
        blackEncodedD
    ),
    1.0,
    1e-15,
    1e-14
));

static assert(approxEqual(
    wcag2ContrastRatio(
        whiteEncodedD,
        whiteEncodedD
    ),
    1.0,
    1e-15,
    1e-14
));

static assert(approxEqual(
    wcag2ContrastRatio(
        blackEncodedD,
        whiteEncodedD
    ),
    21.0,
    1e-14,
    1e-14
));

static assert(approxEqual(
    wcag2ContrastRatio(
        whiteEncodedD,
        blackEncodedD
    ),
    21.0,
    1e-14,
    1e-14
));


// --------------------------------------------------------------------------
// Deterministic generated-property checks
// --------------------------------------------------------------------------

uint nextRandom(ref uint state)
@safe nothrow @nogc
{
    state =
        state * 1664525U +
        1013904223U;

    return state;
}

T randomUnit(T)(ref uint state)
@safe nothrow @nogc
{
    const uint bits =
        nextRandom(state) & 0x00FF_FFFFU;

    return
        cast(T)bits /
        cast(T)0x00FF_FFFFU;
}

void runGeneratedChecks(T)(string scalarName)
if (isColorScalar!T)
{
    T absoluteTolerance;
    T relativeTolerance;

    static if (is(T == float))
    {
        absoluteTolerance = cast(T)2e-6;
        relativeTolerance = cast(T)2e-6;
    }
    else
    {
        absoluteTolerance = cast(T)2e-14;
        relativeTolerance = cast(T)2e-14;
    }

    uint state = 0xC01D_0009U;

    size_t failures = 0;

    T maxRouteDifference = cast(T)0;
    T maxXyzDifference   = cast(T)0;

    foreach (_; 0 .. 4096)
    {
        const SRgb!T a = SRgb!T(
            randomUnit!T(state),
            randomUnit!T(state),
            randomUnit!T(state)
        );

        const SRgb!T b = SRgb!T(
            randomUnit!T(state),
            randomUnit!T(state),
            randomUnit!T(state)
        );

        assert(isValidWcag2SrgbDomain(a));
        assert(isValidWcag2SrgbDomain(b));

        const T candidateA =
            wcag2RelativeLuminance(a);

        const T referenceA =
            referenceWcag2RelativeLuminance(a);

        const T routeDifference =
            magnitude(candidateA - referenceA);

        if (routeDifference > maxRouteDifference)
            maxRouteDifference = routeDifference;

        if (!approxEqual(
            candidateA,
            referenceA,
            absoluteTolerance,
            relativeTolerance
        ))
        {
            ++failures;
        }

        const LinearSRgb!T linearA =
            a.toLinear;

        const T y =
            xyzD65Y(linearA);

        const T xyzDifference =
            magnitude(candidateA - y);

        if (xyzDifference > maxXyzDifference)
            maxXyzDifference = xyzDifference;

        const T ab =
            wcag2ContrastRatio(a, b);

        const T ba =
            wcag2ContrastRatio(b, a);

        if (!approxEqual(
            ab,
            ba,
            absoluteTolerance,
            relativeTolerance
        ))
        {
            ++failures;
        }

        const T aa =
            wcag2ContrastRatio(a, a);

        if (!approxEqual(
            aa,
            cast(T)1,
            absoluteTolerance,
            relativeTolerance
        ))
        {
            ++failures;
        }

        if (
            !finiteValue(ab) ||
            ab < cast(T)1 - absoluteTolerance ||
            ab > cast(T)21 + absoluteTolerance
        )
        {
            ++failures;
        }
    }

    writeln(
        "Generated ", scalarName,
        ": failures=", failures,
        " max route delta=", maxRouteDifference,
        " max |WCAG-XYZ.Y|=", maxXyzDifference
    );

    assert(failures == 0);
}


// --------------------------------------------------------------------------
// Runtime report
// --------------------------------------------------------------------------

void main()
{
    writeln(
        "=== color-d R0.9 luminance / contrast semantics ==="
    );
    writeln();

    writeln("WCAG reference invariants:");
    writeln(
        "  black luminance = ",
        wcag2RelativeLuminance(blackEncodedD)
    );
    writeln(
        "  white luminance = ",
        wcag2RelativeLuminance(whiteEncodedD)
    );
    writeln(
        "  black/white contrast = ",
        wcag2ContrastRatio(
            blackEncodedD,
            whiteEncodedD
        )
    );

    writeln();
    writeln("WCAG primary luminances:");
    writeln(
        "  red   = ",
        wcag2RelativeLuminance(
            LinearSRgbd(1.0, 0.0, 0.0)
        )
    );
    writeln(
        "  green = ",
        wcag2RelativeLuminance(
            LinearSRgbd(0.0, 1.0, 0.0)
        )
    );
    writeln(
        "  blue  = ",
        wcag2RelativeLuminance(
            LinearSRgbd(0.0, 0.0, 1.0)
        )
    );

    writeln();
    writeln("Transfer boundary:");

    foreach (value; [
        0.04044,
        0.04045,
        0.04046
    ])
    {
        const SRgbd c =
            SRgbd(value, value, value);

        writeln(
            "  ",
            value,
            " candidate=",
            wcag2RelativeLuminance(c),
            " reference=",
            referenceWcag2RelativeLuminance(c)
        );
    }

    writeln();
    writeln("WCAG luminance versus XYZ-D65 Y:");

    const SRgbd referenceEncoded =
        SRgbd(
            0.691,
            0.139,
            0.259
        );

    const LinearSRgbd referenceLinear =
        referenceEncoded.toLinear;

    const double wcagL =
        wcag2RelativeLuminance(referenceLinear);

    const double xyzY =
        referenceLinear.xyzD65Y;

    writeln(
        "  color = ",
        referenceEncoded
    );
    writeln(
        "  WCAG  = ",
        wcagL
    );
    writeln(
        "  XYZ.Y = ",
        xyzY
    );
    writeln(
        "  delta = ",
        xyzY - wcagL
    );

    assert(wcagL != xyzY);

    writeln();
    writeln("Extended encoded negative value:");

    const SRgbd negativeEncoded =
        SRgbd(-0.5, 0.0, 0.0);

    writeln(
        "  valid WCAG domain = ",
        isValidWcag2SrgbDomain(
            negativeEncoded
        )
    );
    writeln(
        "  color-d extended path = ",
        wcag2RelativeLuminance(
            negativeEncoded
        )
    );
    writeln(
        "  literal WCAG formula = ",
        referenceWcag2RelativeLuminance(
            negativeEncoded
        )
    );

    assert(
        wcag2RelativeLuminance(
            negativeEncoded
        ) !=
        referenceWcag2RelativeLuminance(
            negativeEncoded
        )
    );

    writeln();
    writeln("Extended linear values:");

    const LinearSRgbd extendedLinear =
        LinearSRgbd(
            1.2,
            -0.1,
            0.5
        );

    writeln(
        "  value = ",
        extendedLinear
    );
    writeln(
        "  valid WCAG domain = ",
        isValidWcag2LinearSrgbDomain(
            extendedLinear
        )
    );
    writeln(
        "  raw weighted luminance = ",
        wcag2RelativeLuminance(
            extendedLinear
        )
    );

    const LinearSRgbd negativeLuminance =
        LinearSRgbd(
            0.0,
            -0.1,
            0.0
        );

    writeln(
        "  negative-luminance example = ",
        wcag2RelativeLuminance(
            negativeLuminance
        )
    );
    writeln(
        "  raw contrast vs white = ",
        wcag2ContrastRatio(
            negativeLuminance,
            whiteLinearD
        )
    );

    writeln();
    writeln("Non-finite behavior:");

    const LinearSRgbd nanColor =
        LinearSRgbd(
            double.nan,
            0.0,
            0.0
        );

    const LinearSRgbd positiveInfinity =
        LinearSRgbd(
            double.infinity,
            0.0,
            0.0
        );

    const LinearSRgbd negativeInfinity =
        LinearSRgbd(
            -double.infinity,
            0.0,
            0.0
        );

    const double nanL =
        wcag2RelativeLuminance(
            nanColor
        );

    const double positiveInfL =
        wcag2RelativeLuminance(
            positiveInfinity
        );

    const double negativeInfL =
        wcag2RelativeLuminance(
            negativeInfinity
        );

    writeln(
        "  NaN luminance = ",
        nanL,
        " finite=",
        finiteValue(nanL)
    );
    writeln(
        "  +Inf luminance = ",
        positiveInfL,
        " finite=",
        finiteValue(positiveInfL)
    );
    writeln(
        "  -Inf luminance = ",
        negativeInfL,
        " finite=",
        finiteValue(negativeInfL)
    );

    writeln(
        "  contrast(NaN, white) = ",
        wcag2ContrastFromLuminance(
            nanL,
            1.0
        )
    );
    writeln(
        "  contrast(+Inf, white) = ",
        wcag2ContrastFromLuminance(
            positiveInfL,
            1.0
        )
    );
    writeln(
        "  contrast(-Inf, white) = ",
        wcag2ContrastFromLuminance(
            negativeInfL,
            1.0
        )
    );

    assert(!finiteValue(nanL));
    assert(!finiteValue(positiveInfL));
    assert(!finiteValue(negativeInfL));

    writeln();
    writeln("Alpha/compositing boundary:");

    const LinearSRgbd black =
        LinearSRgbd(
            0.0,
            0.0,
            0.0
        );

    const LinearSRgbd white =
        LinearSRgbd(
            1.0,
            1.0,
            1.0
        );

    const LinearSRgbd resolved =
        sourceOverOpaque(
            black,
            0.5,
            white
        );

    const double resolvedContrast =
        wcag2ContrastRatio(
            resolved,
            white
        );

    const double naiveEncodedContrast =
        wcag2ContrastRatio(
            SRgbd(0.5, 0.5, 0.5),
            whiteEncodedD
        );

    writeln(
        "  50% black over white, linear result = ",
        resolved
    );
    writeln(
        "  resolved contrast = ",
        resolvedContrast
    );
    writeln(
        "  naive encoded 50% gray contrast = ",
        naiveEncodedContrast
    );

    assert(approxEqual(
        resolvedContrast,
        1.909090909090909,
        1e-14,
        1e-14
    ));

    assert(
        magnitude(
            resolvedContrast -
            naiveEncodedContrast
        ) > 1.0
    );

    writeln();
    writeln("Domain/API policy candidates:");

    const SRgbd validA =
        SRgbd(0.0, 0.0, 0.0);

    const SRgbd validB =
        SRgbd(1.0, 1.0, 1.0);

    const SRgbd invalidA =
        SRgbd(-0.5, 0.0, 0.0);

    const double assertingValid =
        assertingWcag2ContrastRatio(
            validA,
            validB
        );

    writeln(
        "  asserting valid = ",
        assertingValid
    );

    double tryValidValue = -999.0;

    const bool tryValid =
        tryWcag2ContrastRatio(
            validA,
            validB,
            tryValidValue
        );

    writeln(
        "  try valid: ok=",
        tryValid,
        " value=",
        tryValidValue
    );

    double tryInvalidValue = 123.0;

    const bool tryInvalid =
        tryWcag2ContrastRatio(
            invalidA,
            validB,
            tryInvalidValue
        );

    writeln(
        "  try invalid: ok=",
        tryInvalid,
        " value-after-call=",
        tryInvalidValue
    );

    const auto resultValid =
        checkedWcag2ContrastRatio(
            validA,
            validB
        );

    const auto resultInvalid =
        checkedWcag2ContrastRatio(
            invalidA,
            validB
        );

    writeln(
        "  result valid: valid=",
        resultValid.valid,
        " value=",
        resultValid.value
    );

    writeln(
        "  result invalid: valid=",
        resultInvalid.valid,
        " value=",
        resultInvalid.value
    );

    writeln(
        "  result sizeof float=",
        Wcag2Measurement!float.sizeof,
        " double=",
        Wcag2Measurement!double.sizeof
    );

    assert(tryValid);
    assert(tryValidValue == 21.0);

    assert(!tryInvalid);

    // Important ergonomic property:
    // failure did not overwrite the caller's existing value.
    assert(tryInvalidValue == 123.0);

    assert(resultValid.valid);
    assert(resultValid.value == 21.0);

    assert(!resultInvalid.valid);
    assert(
        resultInvalid.value !=
        resultInvalid.value
    );

    writeln();
    writeln("Checked-domain invalid classes:");

    const SRgbd[] invalidEncodedCases = [
        SRgbd(-0.000001, 0.5, 0.5),
        SRgbd(1.000001, 0.5, 0.5),
        SRgbd(double.nan, 0.5, 0.5),
        SRgbd(double.infinity, 0.5, 0.5),
        SRgbd(-double.infinity, 0.5, 0.5)
    ];

    size_t invalidEncodedFailures = 0;

    foreach (c; invalidEncodedCases)
    {
        double outValue = 123.0;

        const bool ok =
            tryWcag2ContrastRatio(
                c,
                whiteEncodedD,
                outValue
            );

        const auto result =
            checkedWcag2ContrastRatio(
                c,
                whiteEncodedD
            );

        const bool pass =
            !ok &&
            outValue == 123.0 &&
            !result.valid &&
            result.value != result.value;

        if (!pass)
            ++invalidEncodedFailures;
    }

    const LinearSRgbd[] invalidLinearCases = [
        LinearSRgbd(-0.000001, 0.5, 0.5),
        LinearSRgbd(1.000001, 0.5, 0.5),
        LinearSRgbd(double.nan, 0.5, 0.5),
        LinearSRgbd(double.infinity, 0.5, 0.5),
        LinearSRgbd(-double.infinity, 0.5, 0.5)
    ];

    size_t invalidLinearFailures = 0;

    foreach (c; invalidLinearCases)
    {
        double outValue = 123.0;

        const bool ok =
            tryWcag2ContrastRatio(
                c,
                whiteLinearD,
                outValue
            );

        const auto result =
            checkedWcag2ContrastRatio(
                c,
                whiteLinearD
            );

        const bool pass =
            !ok &&
            outValue == 123.0 &&
            !result.valid &&
            result.value != result.value;

        if (!pass)
            ++invalidLinearFailures;
    }

    writeln(
        "  encoded invalid failures = ",
        invalidEncodedFailures
    );

    writeln(
        "  linear invalid failures = ",
        invalidLinearFailures
    );

    assert(invalidEncodedFailures == 0);
    assert(invalidLinearFailures == 0);

    writeln();
    writeln("Generated properties:");

    runGeneratedChecks!double("double");
    runGeneratedChecks!float("float");

    writeln();
    writeln("R0.9 correctness spike: PASS");
}
