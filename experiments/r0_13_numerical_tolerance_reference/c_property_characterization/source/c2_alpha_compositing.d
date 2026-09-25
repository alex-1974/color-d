module c2_alpha_compositing;

import common : reportScalar;
import std.stdio : writefln, writeln;
import std.traits : isFloatingPoint;


private enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


struct LinearSRgb(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}


struct Alpha(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}


struct Premultiplied(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}


private struct RealStraight
{
    real r;
    real g;
    real b;
    real alpha;
}


private struct RealPremultiplied
{
    real r;
    real g;
    real b;
    real alpha;
}


bool isValidAlpha(T)(T alpha)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return alpha >= cast(T)0 &&
           alpha <= cast(T)1;
}


Premultiplied!(LinearSRgb!T) premultiply(T)(
    Alpha!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
if (isColorScalar!T)
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


Alpha!(LinearSRgb!T) unpremultiply(T)(
    Premultiplied!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
if (isColorScalar!T)
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


Premultiplied!(LinearSRgb!T) sourceOver(T)(
    Premultiplied!(LinearSRgb!T) source,
    Premultiplied!(LinearSRgb!T) destination
)
@safe pure nothrow @nogc
if (isColorScalar!T)
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


private RealStraight widenStraight(T)(
    Alpha!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return RealStraight(
        cast(real)value.color.r,
        cast(real)value.color.g,
        cast(real)value.color.b,
        cast(real)value.alpha
    );
}


private RealPremultiplied widenPremultiplied(T)(
    Premultiplied!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return RealPremultiplied(
        cast(real)value.color.r,
        cast(real)value.color.g,
        cast(real)value.color.b,
        cast(real)value.alpha
    );
}


private RealPremultiplied referencePremultiply(T)(
    Alpha!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const real alpha = cast(real)value.alpha;

    return RealPremultiplied(
        cast(real)value.color.r * alpha,
        cast(real)value.color.g * alpha,
        cast(real)value.color.b * alpha,
        alpha
    );
}


private RealStraight referenceUnpremultiply(T)(
    Premultiplied!(LinearSRgb!T) value
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const real alpha = cast(real)value.alpha;

    if (alpha == 0)
        return RealStraight(0, 0, 0, 0);

    return RealStraight(
        cast(real)value.color.r / alpha,
        cast(real)value.color.g / alpha,
        cast(real)value.color.b / alpha,
        alpha
    );
}


private RealPremultiplied referenceSourceOver(T)(
    Premultiplied!(LinearSRgb!T) source,
    Premultiplied!(LinearSRgb!T) destination
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const real sourceAlpha = cast(real)source.alpha;
    const real destinationFactor = 1.0L - sourceAlpha;

    return RealPremultiplied(
        cast(real)source.color.r +
            cast(real)destination.color.r * destinationFactor,
        cast(real)source.color.g +
            cast(real)destination.color.g * destinationFactor,
        cast(real)source.color.b +
            cast(real)destination.color.b * destinationFactor,
        sourceAlpha +
            cast(real)destination.alpha * destinationFactor
    );
}


private void reportPremultiplied(T)(
    string label,
    Premultiplied!(LinearSRgb!T) actual,
    RealPremultiplied reference
)
if (isColorScalar!T)
{
    reportScalar(label ~ " r", actual.color.r, reference.r);
    reportScalar(label ~ " g", actual.color.g, reference.g);
    reportScalar(label ~ " b", actual.color.b, reference.b);
    reportScalar(label ~ " alpha", actual.alpha, reference.alpha);
}


private void reportStraight(T)(
    string label,
    Alpha!(LinearSRgb!T) actual,
    RealStraight reference
)
if (isColorScalar!T)
{
    reportScalar(label ~ " r", actual.color.r, reference.r);
    reportScalar(label ~ " g", actual.color.g, reference.g);
    reportScalar(label ~ " b", actual.color.b, reference.b);
    reportScalar(label ~ " alpha", actual.alpha, reference.alpha);
}


private void reportExactIdentities(T)(string scalarName)
if (isColorScalar!T)
{
    auto opaqueStraight = Alpha!(LinearSRgb!T)(
        LinearSRgb!T(
            cast(T)0.2,
            cast(T)-0.3,
            cast(T)1.4
        ),
        cast(T)1
    );
    auto opaquePremultiplied = premultiply(opaqueStraight);

    writefln(
        "C2-EXACT-%s-premultiply-alpha-one = rgb:%s alpha:%s",
        scalarName,
        opaquePremultiplied.color == opaqueStraight.color,
        opaquePremultiplied.alpha == opaqueStraight.alpha
    );

    auto canonicalTransparent = Premultiplied!(LinearSRgb!T)(
        LinearSRgb!T(
            cast(T)0,
            cast(T)0,
            cast(T)0
        ),
        cast(T)0
    );
    auto transparentBack = unpremultiply(canonicalTransparent);

    writefln(
        "C2-EXACT-%s-unpremultiply-zero = rgb:%s alpha:%s",
        scalarName,
        transparentBack.color == LinearSRgb!T(0, 0, 0),
        transparentBack.alpha == cast(T)0
    );

    auto hiddenRed = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)1,
                cast(T)0,
                cast(T)0
            ),
            cast(T)0
        )
    );
    auto hiddenBlue = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)0,
                cast(T)0,
                cast(T)1
            ),
            cast(T)0
        )
    );

    writefln(
        "C2-EXACT-%s-zero-alpha-hidden-color-collapse = %s",
        scalarName,
        hiddenRed == hiddenBlue
    );

    auto destination = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)0.3,
                cast(T)-0.4,
                cast(T)1.2
            ),
            cast(T)0.7
        )
    );

    auto transparentSource = canonicalTransparent;
    auto transparentSourceResult =
        sourceOver(transparentSource, destination);

    writefln(
        "C2-EXACT-%s-source-over-transparent-source = %s",
        scalarName,
        transparentSourceResult == destination
    );

    auto opaqueSource = opaquePremultiplied;
    auto opaqueSourceResult =
        sourceOver(opaqueSource, destination);

    writefln(
        "C2-EXACT-%s-source-over-opaque-source = %s",
        scalarName,
        opaqueSourceResult == opaqueSource
    );

    auto transparentDestinationResult =
        sourceOver(destination, canonicalTransparent);

    writefln(
        "C2-EXACT-%s-source-over-transparent-destination = %s",
        scalarName,
        transparentDestinationResult == destination
    );
}


private void reportClassification(T)(string scalarName)
if (isColorScalar!T)
{
    writefln(
        "C2-CLASSIFY-%s-alpha = zero:%s half:%s one:%s negative:%s above-one:%s nan:%s inf:%s",
        scalarName,
        isValidAlpha(cast(T)0),
        isValidAlpha(cast(T)0.5),
        isValidAlpha(cast(T)1),
        isValidAlpha(cast(T)-0.1),
        isValidAlpha(cast(T)1.1),
        isValidAlpha(T.nan),
        isValidAlpha(T.infinity)
    );
}


private void reportReferenceCases(T)(string scalarName)
if (isColorScalar!T)
{
    auto ordinaryStraight = Alpha!(LinearSRgb!T)(
        LinearSRgb!T(
            cast(T)0.2,
            cast(T)0.4,
            cast(T)0.8
        ),
        cast(T)0.5
    );
    auto ordinaryPremultiplied = premultiply(ordinaryStraight);

    reportPremultiplied(
        "C2-REFERENCE-" ~ scalarName ~ "-premultiply-ordinary",
        ordinaryPremultiplied,
        referencePremultiply(ordinaryStraight)
    );

    auto ordinaryBack = unpremultiply(ordinaryPremultiplied);

    reportStraight(
        "C2-REFERENCE-" ~ scalarName ~ "-unpremultiply-ordinary",
        ordinaryBack,
        referenceUnpremultiply(ordinaryPremultiplied)
    );

    auto extendedStraight = Alpha!(LinearSRgb!T)(
        LinearSRgb!T(
            cast(T)-0.2,
            cast(T)1.3,
            cast(T)0.5
        ),
        cast(T)0.25
    );
    auto extendedPremultiplied = premultiply(extendedStraight);

    reportPremultiplied(
        "C2-REFERENCE-" ~ scalarName ~ "-premultiply-extended",
        extendedPremultiplied,
        referencePremultiply(extendedStraight)
    );

    auto halfBlue = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)0,
                cast(T)0,
                cast(T)1
            ),
            cast(T)0.5
        )
    );
    auto halfRed = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)1,
                cast(T)0,
                cast(T)0
            ),
            cast(T)0.5
        )
    );
    auto halfComposite = sourceOver(halfBlue, halfRed);

    reportPremultiplied(
        "C2-REFERENCE-" ~ scalarName ~ "-source-over-half",
        halfComposite,
        referenceSourceOver(halfBlue, halfRed)
    );

    auto extendedSource = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)-0.2,
                cast(T)1.3,
                cast(T)0.5
            ),
            cast(T)0.25
        )
    );
    auto extendedDestination = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)1.2,
                cast(T)-0.1,
                cast(T)0.3
            ),
            cast(T)0.5
        )
    );
    auto extendedComposite =
        sourceOver(extendedSource, extendedDestination);

    reportPremultiplied(
        "C2-REFERENCE-" ~ scalarName ~ "-source-over-extended",
        extendedComposite,
        referenceSourceOver(
            extendedSource,
            extendedDestination
        )
    );
}


private void reportDerivedCases(T)(string scalarName)
if (isColorScalar!T)
{
    auto ordinaryStraight = Alpha!(LinearSRgb!T)(
        LinearSRgb!T(
            cast(T)0.2,
            cast(T)0.4,
            cast(T)0.8
        ),
        cast(T)0.5
    );
    auto ordinaryBack =
        unpremultiply(premultiply(ordinaryStraight));

    reportStraight(
        "C2-DERIVED-" ~ scalarName ~ "-roundtrip-ordinary",
        ordinaryBack,
        widenStraight(ordinaryStraight)
    );

    auto extendedStraight = Alpha!(LinearSRgb!T)(
        LinearSRgb!T(
            cast(T)-0.2,
            cast(T)1.3,
            cast(T)0.5
        ),
        cast(T)0.25
    );
    auto extendedBack =
        unpremultiply(premultiply(extendedStraight));

    reportStraight(
        "C2-DERIVED-" ~ scalarName ~ "-roundtrip-extended",
        extendedBack,
        widenStraight(extendedStraight)
    );

    auto layerA = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)0.9,
                cast(T)0.2,
                cast(T)1.1
            ),
            cast(T)0.3
        )
    );
    auto layerB = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)-0.1,
                cast(T)0.8,
                cast(T)0.4
            ),
            cast(T)0.6
        )
    );
    auto layerC = premultiply(
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                cast(T)0.3,
                cast(T)0.7,
                cast(T)0.2
            ),
            cast(T)0.4
        )
    );

    auto associativeLeft =
        sourceOver(sourceOver(layerA, layerB), layerC);
    auto associativeRight =
        sourceOver(layerA, sourceOver(layerB, layerC));

    reportPremultiplied(
        "C2-DERIVED-" ~ scalarName ~ "-associativity-left-vs-right",
        associativeLeft,
        widenPremultiplied(associativeRight)
    );
}


private void reportRangeCases(T)(string scalarName)
if (isColorScalar!T)
{
    const T smallest =
        T.min_normal * T.epsilon;

    auto tinyAlphaStraight = Alpha!(LinearSRgb!T)(
        LinearSRgb!T(
            cast(T)0.5,
            cast(T)1,
            cast(T)-0.5
        ),
        smallest
    );
    auto tinyAlphaPremultiplied =
        premultiply(tinyAlphaStraight);

    writeln("-- C2 RANGE ", scalarName, " --");

    reportPremultiplied(
        "C2-RANGE-" ~ scalarName ~ "-tiny-alpha-premultiply",
        tinyAlphaPremultiplied,
        referencePremultiply(tinyAlphaStraight)
    );

    auto tinyAlphaBack =
        unpremultiply(tinyAlphaPremultiplied);

    reportStraight(
        "C2-RANGE-" ~ scalarName ~ "-tiny-alpha-roundtrip",
        tinyAlphaBack,
        widenStraight(tinyAlphaStraight)
    );
}


void runC2For(T)(string scalarName)
if (isColorScalar!T)
{
    writeln();
    writeln(
        "=== C2 ALPHA / PREMULTIPLIED SOURCE-OVER (",
        scalarName,
        ") ==="
    );

    reportExactIdentities!T(scalarName);
    reportClassification!T(scalarName);
    reportReferenceCases!T(scalarName);
    reportDerivedCases!T(scalarName);
    reportRangeCases!T(scalarName);
}


enum ctfeOpaque = premultiply(
    Alpha!(LinearSRgb!double)(
        LinearSRgb!double(0.2, -0.3, 1.4),
        1.0
    )
);
static assert(ctfeOpaque.color == LinearSRgb!double(0.2, -0.3, 1.4));
static assert(ctfeOpaque.alpha == 1.0);

enum ctfeTransparentBack = unpremultiply(
    Premultiplied!(LinearSRgb!double)(
        LinearSRgb!double(0, 0, 0),
        0.0
    )
);
static assert(ctfeTransparentBack.color == LinearSRgb!double(0, 0, 0));
static assert(ctfeTransparentBack.alpha == 0.0);

enum ctfeDestination = premultiply(
    Alpha!(LinearSRgb!double)(
        LinearSRgb!double(0.3, 0.4, 0.5),
        0.7
    )
);
enum ctfeTransparent = Premultiplied!(LinearSRgb!double)(
    LinearSRgb!double(0, 0, 0),
    0.0
);
static assert(
    sourceOver(ctfeTransparent, ctfeDestination) ==
    ctfeDestination
);
