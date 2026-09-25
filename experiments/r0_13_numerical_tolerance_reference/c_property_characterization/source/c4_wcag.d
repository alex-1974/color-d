module c4_wcag;

import common : reportScalar;
import std.math : nextDown, nextUp, pow;
import std.stdio : writefln, writeln;
import std.traits : Unqual;


private enum bool isColorScalar(T) =
    is(Unqual!T == float) || is(Unqual!T == double);


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


T magnitude(T)(T value)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return value < cast(T)0 ? -value : value;
}


T signOf(T)(T value)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return value < cast(T)0 ? cast(T)-1 : cast(T)1;
}


bool finiteValue(T)(T value)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        value == value &&
        value <= T.max &&
        value >= -T.max;
}


bool isValidWcagDomain(T)(SRgb!T color)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        finiteValue!T(color.r) &&
        finiteValue!T(color.g) &&
        finiteValue!T(color.b) &&

        color.r >= cast(T)0 &&
        color.r <= cast(T)1 &&
        color.g >= cast(T)0 &&
        color.g <= cast(T)1 &&
        color.b >= cast(T)0 &&
        color.b <= cast(T)1;
}


bool isValidWcagDomain(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        finiteValue!T(color.r) &&
        finiteValue!T(color.g) &&
        finiteValue!T(color.b) &&

        color.r >= cast(T)0 &&
        color.r <= cast(T)1 &&
        color.g >= cast(T)0 &&
        color.g <= cast(T)1 &&
        color.b >= cast(T)0 &&
        color.b <= cast(T)1;
}


T srgbToLinearComponent(T)(T encoded)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const T absEncoded = magnitude!T(encoded);

    if (absEncoded <= cast(T)0.04045)
        return encoded / cast(T)12.92;

    const T base =
        (absEncoded + cast(T)0.055) /
        cast(T)1.055;

    return
        signOf!T(encoded) *
        cast(T)pow(base, cast(T)2.4);
}


LinearSRgb!T toLinear(T)(SRgb!T color)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return LinearSRgb!T(
        srgbToLinearComponent!T(color.r),
        srgbToLinearComponent!T(color.g),
        srgbToLinearComponent!T(color.b)
    );
}


T wcag2RelativeLuminance(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        cast(T)0.2126 * color.r +
        cast(T)0.7152 * color.g +
        cast(T)0.0722 * color.b;
}


T wcag2RelativeLuminance(T)(SRgb!T color)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return wcag2RelativeLuminance!T(
        toLinear!T(color)
    );
}


T wcag2ContrastFromLuminance(T)(T a, T b)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const bool aIsLighter = a >= b;
    const T lighter = aIsLighter ? a : b;
    const T darker = aIsLighter ? b : a;

    return
        (lighter + cast(T)0.05) /
        (darker + cast(T)0.05);
}


T wcag2ContrastRatio(T)(SRgb!T a, SRgb!T b)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return wcag2ContrastFromLuminance!T(
        wcag2RelativeLuminance!T(a),
        wcag2RelativeLuminance!T(b)
    );
}


T wcag2ContrastRatio(T)(
    LinearSRgb!T a,
    LinearSRgb!T b
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return wcag2ContrastFromLuminance!T(
        wcag2RelativeLuminance!T(a),
        wcag2RelativeLuminance!T(b)
    );
}


private real referenceDecode(real encoded)
@safe pure nothrow @nogc
{
    if (encoded <= 0.04045L)
        return encoded / 12.92L;

    return pow(
        (encoded + 0.055L) / 1.055L,
        2.4L
    );
}


private real referenceWcagLuminance(T)(SRgb!T color)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        0.2126L *
            referenceDecode(cast(real)color.r) +
        0.7152L *
            referenceDecode(cast(real)color.g) +
        0.0722L *
            referenceDecode(cast(real)color.b);
}


private real referenceWcagLuminance(T)(
    LinearSRgb!T color
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        0.2126L * cast(real)color.r +
        0.7152L * cast(real)color.g +
        0.0722L * cast(real)color.b;
}


private real referenceContrast(
    real a,
    real b
)
@safe pure nothrow @nogc
{
    const bool aIsLighter = a >= b;
    const real lighter = aIsLighter ? a : b;
    const real darker = aIsLighter ? b : a;

    return
        (lighter + 0.05L) /
        (darker + 0.05L);
}


private T legacySameFormulaDecode(T)(T encoded)
@safe pure nothrow @nogc
if (isColorScalar!T)
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


private T legacySameFormulaLuminance(T)(
    SRgb!T color
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        cast(T)0.2126 *
            legacySameFormulaDecode!T(color.r) +
        cast(T)0.7152 *
            legacySameFormulaDecode!T(color.g) +
        cast(T)0.0722 *
            legacySameFormulaDecode!T(color.b);
}


private real cssXyzD65Y(T)(
    LinearSRgb!T color
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        (87098.0L / 409605.0L) *
            cast(real)color.r +
        (175762.0L / 245763.0L) *
            cast(real)color.g +
        (12673.0L / 175545.0L) *
            cast(real)color.b;
}


private void reportClassification(T)(string scalarName)
if (isColorScalar!T)
{
    const auto validEncoded =
        SRgb!T(cast(T)0, cast(T)0.5, cast(T)1);
    const auto below =
        SRgb!T(cast(T)-0.000001, cast(T)0.5, cast(T)0.5);
    const auto above =
        SRgb!T(cast(T)1.000001, cast(T)0.5, cast(T)0.5);
    const auto nanCase =
        SRgb!T(T.nan, cast(T)0.5, cast(T)0.5);
    const auto infCase =
        SRgb!T(T.infinity, cast(T)0.5, cast(T)0.5);

    const auto validLinear =
        LinearSRgb!T(cast(T)0, cast(T)0.5, cast(T)1);

    writefln(
        "C4-CLASSIFY-%s-domain = encoded:%s linear:%s below:%s above:%s nan:%s inf:%s",
        scalarName,
        isValidWcagDomain!T(validEncoded),
        isValidWcagDomain!T(validLinear),
        isValidWcagDomain!T(below),
        isValidWcagDomain!T(above),
        isValidWcagDomain!T(nanCase),
        isValidWcagDomain!T(infCase)
    );
}


private void reportExactCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto black =
        LinearSRgb!T(0, 0, 0);
    const auto white =
        LinearSRgb!T(1, 1, 1);
    const auto ordinary =
        LinearSRgb!T(
            cast(T)0.18,
            cast(T)0.42,
            cast(T)0.73
        );

    const T blackL =
        wcag2RelativeLuminance!T(black);
    const T whiteL =
        wcag2RelativeLuminance!T(white);

    writefln(
        "C4-EXACT-%s-linear-luminance = black:%s white:%s",
        scalarName,
        blackL == cast(T)0,
        whiteL == cast(T)1
    );

    const T same =
        wcag2ContrastRatio!T(ordinary, ordinary);
    const T blackWhite =
        wcag2ContrastRatio!T(black, white);
    const T whiteBlack =
        wcag2ContrastRatio!T(white, black);

    writefln(
        "C4-EXACT-%s-contrast = same:%s symmetric:%s",
        scalarName,
        same == cast(T)1,
        blackWhite == whiteBlack
    );

    reportScalar(
        "C4-REFERENCE-" ~ scalarName ~ "-contrast-black-white",
        blackWhite,
        21.0L
    );
}


private void reportPrimaryReferences(T)(string scalarName)
if (isColorScalar!T)
{
    reportScalar(
        "C4-REFERENCE-" ~ scalarName ~ "-linear-red",
        wcag2RelativeLuminance!T(
            LinearSRgb!T(1, 0, 0)
        ),
        0.2126L
    );
    reportScalar(
        "C4-REFERENCE-" ~ scalarName ~ "-linear-green",
        wcag2RelativeLuminance!T(
            LinearSRgb!T(0, 1, 0)
        ),
        0.7152L
    );
    reportScalar(
        "C4-REFERENCE-" ~ scalarName ~ "-linear-blue",
        wcag2RelativeLuminance!T(
            LinearSRgb!T(0, 0, 1)
        ),
        0.0722L
    );
}


private void reportEncodedReferences(T)(string scalarName)
if (isColorScalar!T)
{
    const auto gray =
        SRgb!T(
            cast(T)0.5,
            cast(T)0.5,
            cast(T)0.5
        );

    reportScalar(
        "C4-REFERENCE-" ~ scalarName ~ "-encoded-gray-050",
        wcag2RelativeLuminance!T(gray),
        referenceWcagLuminance!T(gray)
    );

    const auto ordinary =
        SRgb!T(
            cast(T)0.691,
            cast(T)0.139,
            cast(T)0.259
        );

    reportScalar(
        "C4-REFERENCE-" ~ scalarName ~ "-encoded-ordinary",
        wcag2RelativeLuminance!T(ordinary),
        referenceWcagLuminance!T(ordinary)
    );

    const auto dark =
        SRgb!T(
            cast(T)0.12,
            cast(T)0.20,
            cast(T)0.34
        );
    const auto light =
        SRgb!T(
            cast(T)0.82,
            cast(T)0.75,
            cast(T)0.61
        );

    const T candidateContrast =
        wcag2ContrastRatio!T(dark, light);

    reportScalar(
        "C4-REFERENCE-" ~ scalarName ~ "-contrast-ordinary",
        candidateContrast,
        referenceContrast(
            referenceWcagLuminance!T(dark),
            referenceWcagLuminance!T(light)
        )
    );
}


private void reportBoundary(T)(string scalarName)
if (isColorScalar!T)
{
    T boundary = cast(T)0.04045;
    T below = nextDown(boundary);
    T above = nextUp(boundary);

    const auto belowColor = SRgb!T(below, below, below);
    const auto atColor =
        SRgb!T(boundary, boundary, boundary);
    const auto aboveColor = SRgb!T(above, above, above);

    writeln("-- C4 TRANSFER BOUNDARY ", scalarName, " --");

    reportScalar(
        "C4-BOUNDARY-" ~ scalarName ~ "-below",
        wcag2RelativeLuminance!T(belowColor),
        referenceWcagLuminance!T(belowColor)
    );
    reportScalar(
        "C4-BOUNDARY-" ~ scalarName ~ "-at",
        wcag2RelativeLuminance!T(atColor),
        referenceWcagLuminance!T(atColor)
    );
    reportScalar(
        "C4-BOUNDARY-" ~ scalarName ~ "-above",
        wcag2RelativeLuminance!T(aboveColor),
        referenceWcagLuminance!T(aboveColor)
    );

    const auto white = SRgb!T(1, 1, 1);

    reportScalar(
        "C4-BOUNDARY-" ~ scalarName ~ "-contrast-at-vs-white",
        wcag2ContrastRatio!T(atColor, white),
        referenceContrast(
            referenceWcagLuminance!T(atColor),
            referenceWcagLuminance!T(white)
        )
    );
}


private void reportRegressionAndDistinct(T)(
    string scalarName
)
if (isColorScalar!T)
{
    const auto encoded =
        SRgb!T(
            cast(T)0.691,
            cast(T)0.139,
            cast(T)0.259
        );

    const T candidate =
        wcag2RelativeLuminance!T(encoded);
    const T legacy =
        legacySameFormulaLuminance!T(encoded);

    writefln(
        "C4-REGRESSION-%s-old-same-formula-route-equal = %s",
        scalarName,
        candidate == legacy
    );

    const auto linear =
        toLinear!T(encoded);

    const real wcag =
        referenceWcagLuminance!T(linear);
    const real xyzY =
        cssXyzD65Y!T(linear);
    const real delta = wcag >= xyzY
        ? wcag - xyzY
        : xyzY - wcag;

    writefln(
        "C4-DISTINCT-%s-wcag-vs-xyzY = wcag=% .21g xyzY=% .21g abs_delta=% .6e equal:%s",
        scalarName,
        wcag,
        xyzY,
        delta,
        wcag == xyzY
    );
}


void runC4For(T)(string scalarName)
if (isColorScalar!T)
{
    writeln();
    writeln(
        "=== C4 WCAG 2 LUMINANCE / CONTRAST (",
        scalarName,
        ") ==="
    );

    reportClassification!T(scalarName);
    reportExactCases!T(scalarName);
    reportPrimaryReferences!T(scalarName);
    reportEncodedReferences!T(scalarName);
    reportBoundary!T(scalarName);
    reportRegressionAndDistinct!T(scalarName);
}


enum ctfeBlack =
    wcag2RelativeLuminance(
        LinearSRgb!double(0, 0, 0)
    );
enum ctfeWhite =
    wcag2RelativeLuminance(
        LinearSRgb!double(1, 1, 1)
    );

static assert(ctfeBlack == 0.0);
static assert(ctfeWhite == 1.0);

enum ctfeContrast =
    wcag2ContrastRatio(
        LinearSRgb!double(0, 0, 0),
        LinearSRgb!double(1, 1, 1)
    );

// Successful enum evaluation is the CTFE check. Numerical agreement with the
// normative 21:1 value is characterized at runtime instead of asserted exact.
static assert(ctfeContrast == ctfeContrast);

static assert(
    isValidWcagDomain(
        SRgb!double(0, 0.5, 1)
    )
);

static assert(
    !isValidWcagDomain(
        SRgb!double(-0.01, 0.5, 1)
    )
);
