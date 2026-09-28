// Public special-value regression for color-d.
//
// This is deliberately an external root-import consumer. It verifies only
// caller-visible semantics: signed-zero canonicalization/preservation where
// documented, representable finite edge behavior, invalid-domain
// classification, and visible NaN/Inf propagation. It does not require
// cross-compiler bit identity for derived ordinary coordinates.

module special_value_semantics;

import color;

import std.stdio :
    writefln,
    writeln;
import std.traits :
    Unqual;


private bool isNan(T)(T value)
{
    return value != value;
}


private bool finite(T)(T value)
if (
    is(Unqual!T == float) ||
    is(Unqual!T == double)
)
{
    alias U =
        Unqual!T;

    const U scalar =
        cast(U)value;

    return
        scalar == scalar &&
        scalar != U.infinity &&
        scalar != -U.infinity;
}


private bool positiveZero(T)(T value)
if (
    is(Unqual!T == float) ||
    is(Unqual!T == double)
)
{
    alias U =
        Unqual!T;

    const U scalar =
        cast(U)value;

    return
        scalar == cast(U)0 &&
        cast(U)1 / scalar ==
            U.infinity;
}


private bool negativeZero(T)(T value)
if (
    is(Unqual!T == float) ||
    is(Unqual!T == double)
)
{
    alias U =
        Unqual!T;

    const U scalar =
        cast(U)value;

    return
        scalar == cast(U)0 &&
        cast(U)1 / scalar ==
            -U.infinity;
}


private T minimumSubnormal(T)()
if (
    is(T == float) ||
    is(T == double)
)
{
    return
        T.min_normal *
        T.epsilon;
}


private bool finiteColor(T)(
    LinearSRgb!T value
)
{
    return
        finite(value.r) &&
        finite(value.g) &&
        finite(value.b);
}


private bool finiteColor(T)(
    XyzD65!T value
)
{
    return
        finite(value.x) &&
        finite(value.y) &&
        finite(value.z);
}


private bool finiteColor(T)(
    Oklab!T value
)
{
    return
        finite(value.l) &&
        finite(value.a) &&
        finite(value.b);
}


private bool auditFiniteEdges(T)()
@safe pure nothrow @nogc
if (
    is(T == float) ||
    is(T == double)
)
{
    const T plusZero =
        cast(T)0;

    const T minusZero =
        -cast(T)0;

    const T minSub =
        minimumSubnormal!T();


    // Raw hue storage preserves -0, while the documented positive-degree view
    // canonicalizes zero to +0.
    const auto negativeZeroHue =
        OklabHue!T.fromDegrees(
            minusZero
        );

    if (
        !negativeZero(
            negativeZeroHue.rawDegrees
        ) ||
        !positiveZero(
            negativeZeroHue.positiveDegrees
        )
    )
    {
        return false;
    }


    // Raw component replacement remains policy-free and exact.
    const Oklch!T seed =
        Oklch!T(
            cast(T)0.5,
            cast(T)0.2,
            OklabHue!T.fromDegrees(
                cast(T)30
            )
        );

    const auto zeroLightness =
        seed.withLightness(
            minusZero
        );

    const auto tinyChroma =
        seed.withChroma(
            minSub
        );

    if (
        !negativeZero(
            zeroLightness.l
        ) ||
        tinyChroma.c != minSub
    )
    {
        return false;
    }


    // Strict alpha classification accepts both signs of zero and positive
    // subnormals because they are inside [0, 1].
    if (
        !Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                plusZero,
                plusZero,
                plusZero
            ),
            minusZero
        ).isValidAlpha ||
        !Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                plusZero,
                plusZero,
                plusZero
            ),
            minSub
        ).isValidAlpha
    )
    {
        return false;
    }


    // sRGB transfer keeps signed zero on its linear branch. A minimum-normal
    // input decodes into a finite positive/negative subnormal rather than
    // being repaired or clamped.
    const auto decoded =
        SRgb!T(
            minusZero,
            T.min_normal,
            -T.min_normal
        ).toLinear;

    if (
        !negativeZero(decoded.r) ||
        !finite(decoded.g) ||
        decoded.g <= plusZero ||
        decoded.g >= T.min_normal ||
        !finite(decoded.b) ||
        decoded.b >= plusZero ||
        -decoded.b >= T.min_normal
    )
    {
        return false;
    }

    const auto encoded =
        LinearSRgb!T(
            minusZero,
            minSub,
            -minSub
        ).toSRgb;

    if (
        !negativeZero(encoded.r) ||
        !finite(encoded.g) ||
        encoded.g <= plusZero ||
        !finite(encoded.b) ||
        encoded.b >= plusZero
    )
    {
        return false;
    }


    // Finite subnormal/magnitude edges through the rectangular conversion
    // families must stay finite; exact coordinate equality is not required.
    const auto subnormalXyz =
        LinearSRgb!T(
            T.min_normal,
            plusZero,
            plusZero
        ).toXyzD65;

    const auto subnormalLinear =
        XyzD65!T(
            T.min_normal,
            plusZero,
            plusZero
        ).toLinearSRgb;

    const auto subnormalLab =
        XyzD65!T(
            T.min_normal,
            plusZero,
            plusZero
        ).toOklab;

    if (
        !finiteColor(subnormalXyz) ||
        !finiteColor(subnormalLinear) ||
        !finiteColor(subnormalLab)
    )
    {
        return false;
    }


    // Oklab -> OKLCH is a Euclidean magnitude. These are the two regressions
    // that motivated the R4 hardening: both mathematical norms are
    // representable in T and therefore must not become Inf/zero.
    const T halfMax =
        T.max /
        cast(T)2;

    const auto nearMaxPolar =
        Oklab!T(
            cast(T)0.5,
            halfMax,
            halfMax
        ).toOklch;

    const auto minNormalPolar =
        Oklab!T(
            cast(T)0.5,
            T.min_normal,
            plusZero
        ).toOklch;

    if (
        !finite(nearMaxPolar.c) ||
        nearMaxPolar.c <= halfMax ||
        minNormalPolar.c !=
            T.min_normal
    )
    {
        return false;
    }

    const auto exactAchromatic =
        Oklab!T(
            cast(T)0.5,
            minusZero,
            plusZero
        ).toOklch;

    if (
        !positiveZero(
            exactAchromatic.c
        ) ||
        !positiveZero(
            exactAchromatic.h.rawDegrees
        )
    )
    {
        return false;
    }

    const auto tinyPolarBack =
        Oklch!T(
            cast(T)0.5,
            minSub,
            OklabHue!T.fromDegrees(
                plusZero
            )
        ).toOklab;

    if (
        !finiteColor(tinyPolarBack) ||
        tinyPolarBack.a != minSub
    )
    {
        return false;
    }


    // Gamut diagnostics use strict target-space comparison. -0 and positive
    // subnormal coordinates are inside; negative subnormal is outside.
    if (
        !SRgb!T(
            minusZero,
            minSub,
            cast(T)1
        ).inGamut ||
        SRgb!T(
            -minSub,
            plusZero,
            plusZero
        ).inGamut
    )
    {
        return false;
    }

    const auto clipped =
        SRgb!T(
            minusZero,
            -minSub,
            cast(T)2
        ).clip;

    if (
        !negativeZero(clipped.r) ||
        !positiveZero(clipped.g) ||
        clipped.b != cast(T)1
    )
    {
        return false;
    }


    // WCAG domain validation accepts representable values in [0, 1],
    // including -0 and positive subnormals.
    const auto encodedLuminance =
        wcag2RelativeLuminance(
            SRgb!T(
                minusZero,
                minSub,
                plusZero
            )
        );

    const auto linearLuminance =
        wcag2RelativeLuminance(
            LinearSRgb!T(
                minusZero,
                minSub,
                plusZero
            )
        );

    if (
        !encodedLuminance.valid ||
        !finite(encodedLuminance.value) ||
        !linearLuminance.valid ||
        !finite(linearLuminance.value)
    )
    {
        return false;
    }


    // One-axis Euclidean distance is exactly the axis magnitude even at the
    // normal/subnormal boundary.
    const T tinyDistance =
        deltaEOK(
            Oklab!T(
                plusZero,
                plusZero,
                plusZero
            ),
            Oklab!T(
                T.min_normal,
                plusZero,
                plusZero
            )
        );

    if (
        tinyDistance !=
        T.min_normal
    )
    {
        return false;
    }


    // Premultiplication preserves representable subnormal alpha arithmetic.
    const auto tinyPremultiplied =
        premultiply(
            Alpha!(LinearSRgb!T)(
                LinearSRgb!T(
                    cast(T)1,
                    plusZero,
                    plusZero
                ),
                minSub
            )
        );

    if (
        tinyPremultiplied.color.r != minSub ||
        tinyPremultiplied.alpha != minSub
    )
    {
        return false;
    }

    const auto tinyStraight =
        unpremultiply(
            tinyPremultiplied
        );

    if (
        tinyStraight.color.r != cast(T)1 ||
        tinyStraight.alpha != minSub
    )
    {
        return false;
    }

    // Both signs of zero alpha enter the explicit canonical transparent-black
    // branch; the returned representation is +0 transparent black.
    const auto zeroStraight =
        unpremultiply(
            Premultiplied!(LinearSRgb!T)(
                LinearSRgb!T(
                    cast(T)2,
                    cast(T)-3,
                    cast(T)4
                ),
                minusZero
            )
        );

    if (
        !positiveZero(zeroStraight.alpha) ||
        !positiveZero(zeroStraight.color.r) ||
        !positiveZero(zeroStraight.color.g) ||
        !positiveZero(zeroStraight.color.b)
    )
    {
        return false;
    }


    // Source-over with a valid subnormal alpha remains finite and valid.
    const auto tinyComposite =
        sourceOver(
            Premultiplied!(LinearSRgb!T)(
                LinearSRgb!T(
                    minSub,
                    plusZero,
                    plusZero
                ),
                minSub
            ),
            Premultiplied!(LinearSRgb!T)(
                LinearSRgb!T(
                    plusZero,
                    plusZero,
                    plusZero
                ),
                plusZero
            )
        );

    if (
        !tinyComposite.isValidAlpha ||
        !finiteColor(tinyComposite.color) ||
        tinyComposite.color.r != minSub ||
        tinyComposite.alpha != minSub
    )
    {
        return false;
    }


    // Rectangular interpolation does not clamp t. A positive minimum
    // subnormal interpolation factor remains observable.
    const auto tinyInterpolated =
        interpolate(
            LinearSRgb!T(
                plusZero,
                plusZero,
                plusZero
            ),
            LinearSRgb!T(
                cast(T)1,
                cast(T)1,
                cast(T)1
            ),
            minSub
        );

    if (
        tinyInterpolated.r != minSub ||
        tinyInterpolated.g != minSub ||
        tinyInterpolated.b != minSub
    )
    {
        return false;
    }

    const LinearSRgb!T first =
        LinearSRgb!T(
            cast(T)0.25,
            cast(T)-0.5,
            cast(T)1.25
        );

    const LinearSRgb!T second =
        LinearSRgb!T(
            cast(T)0.75,
            cast(T)0.5,
            cast(T)-0.25
        );

    if (
        interpolate(
            first,
            second,
            minusZero
        ) != first
    )
    {
        return false;
    }


    // Generated finite schedules preserve exact endpoints, including the sign
    // of zero. Opposite minimum-normal endpoints retain a finite zero midpoint.
    const auto zeroSchedule =
        linearSchedule!2(
            minusZero,
            plusZero
        );

    if (
        !negativeZero(
            zeroSchedule[0]
        ) ||
        !positiveZero(
            zeroSchedule[1]
        )
    )
    {
        return false;
    }

    const auto tinySchedule =
        linearSchedule!3(
            T.min_normal,
            -T.min_normal
        );

    if (
        tinySchedule[0] !=
            T.min_normal ||
        tinySchedule[2] !=
            -T.min_normal ||
        tinySchedule[1] !=
            plusZero
    )
    {
        return false;
    }


    // Raw tone-batch construction copies caller values without normalization.
    const T[2] lightnesses =
        [
            minusZero,
            T.min_normal
        ];

    const T[2] chromas =
        [
            minSub,
            plusZero
        ];

    Oklch!T[2] tones;

    tonesAtLightnessAndChromaInto(
        seed,
        lightnesses,
        chromas,
        tones
    );

    if (
        !negativeZero(tones[0].l) ||
        tones[0].c != minSub ||
        tones[1].l != T.min_normal ||
        !positiveZero(tones[1].c)
    )
    {
        return false;
    }


    return true;
}


private bool auditNonFinite(T)()
@safe pure nothrow @nogc
if (
    is(T == float) ||
    is(T == double)
)
{
    const T zero =
        cast(T)0;


    // Raw component helpers preserve explicitly supplied non-finite values.
    const Oklch!T seed =
        Oklch!T(
            cast(T)0.5,
            cast(T)0.2,
            OklabHue!T.fromDegrees(
                cast(T)30
            )
        );

    if (
        !isNan(
            seed.withLightness(
                T.nan
            ).l
        ) ||
        seed.withChroma(
            T.infinity
        ).c != T.infinity ||
        seed.withHue(
            OklabHue!T.fromDegrees(
                -T.infinity
            )
        ).h.rawDegrees !=
            -T.infinity
    )
    {
        return false;
    }


    // Alpha validators reject NaN and both infinities without clamping.
    if (
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                zero,
                zero,
                zero
            ),
            T.nan
        ).isValidAlpha ||
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                zero,
                zero,
                zero
            ),
            T.infinity
        ).isValidAlpha ||
        Alpha!(LinearSRgb!T)(
            LinearSRgb!T(
                zero,
                zero,
                zero
            ),
            -T.infinity
        ).isValidAlpha
    )
    {
        return false;
    }


    // Transfer functions keep invalid numerical state visible.
    const auto decoded =
        SRgb!T(
            T.nan,
            T.infinity,
            -T.infinity
        ).toLinear;

    const auto encoded =
        LinearSRgb!T(
            T.nan,
            T.infinity,
            -T.infinity
        ).toSRgb;

    if (
        !isNan(decoded.r) ||
        decoded.g != T.infinity ||
        decoded.b != -T.infinity ||
        !isNan(encoded.r) ||
        encoded.g != T.infinity ||
        encoded.b != -T.infinity
    )
    {
        return false;
    }


    // Rectangular color-space transforms do not repair non-finite input.
    const auto nanXyz =
        LinearSRgb!T(
            T.nan,
            zero,
            zero
        ).toXyzD65;

    if (
        !isNan(nanXyz.x) ||
        !isNan(nanXyz.y) ||
        !isNan(nanXyz.z)
    )
    {
        return false;
    }

    const auto infiniteXyz =
        LinearSRgb!T(
            T.infinity,
            zero,
            zero
        ).toXyzD65;

    if (
        infiniteXyz.x != T.infinity ||
        infiniteXyz.y != T.infinity ||
        infiniteXyz.z != T.infinity
    )
    {
        return false;
    }

    const auto nanLinear =
        XyzD65!T(
            T.nan,
            zero,
            zero
        ).toLinearSRgb;

    if (
        !isNan(nanLinear.r) ||
        !isNan(nanLinear.g) ||
        !isNan(nanLinear.b)
    )
    {
        return false;
    }

    const auto infiniteLinear =
        XyzD65!T(
            T.infinity,
            zero,
            zero
        ).toLinearSRgb;

    if (
        finiteColor(
            infiniteLinear
        )
    )
    {
        return false;
    }


    const auto nanLab =
        XyzD65!T(
            T.nan,
            zero,
            zero
        ).toOklab;

    if (
        !isNan(nanLab.l) ||
        !isNan(nanLab.a) ||
        !isNan(nanLab.b)
    )
    {
        return false;
    }

    const auto nanXyzBack =
        Oklab!T(
            T.nan,
            zero,
            zero
        ).toXyzD65;

    if (
        !isNan(nanXyzBack.x) ||
        !isNan(nanXyzBack.y) ||
        !isNan(nanXyzBack.z)
    )
    {
        return false;
    }


    // Polar conversion preserves visible invalidity. A NaN Cartesian
    // coordinate yields NaN chroma/hue; infinite hue cannot become a plausible
    // finite Cartesian direction.
    const auto nanPolar =
        Oklab!T(
            cast(T)0.5,
            T.nan,
            zero
        ).toOklch;

    if (
        !isNan(nanPolar.c) ||
        !isNan(
            nanPolar.h.rawDegrees
        )
    )
    {
        return false;
    }

    const auto infinitePolar =
        Oklab!T(
            cast(T)0.5,
            T.infinity,
            zero
        ).toOklch;

    if (
        infinitePolar.c !=
            T.infinity
    )
    {
        return false;
    }

    const auto infiniteHueLab =
        Oklch!T(
            cast(T)0.5,
            cast(T)0.2,
            OklabHue!T.fromDegrees(
                T.infinity
            )
        ).toOklab;

    if (
        !isNan(infiniteHueLab.a) ||
        !isNan(infiniteHueLab.b)
    )
    {
        return false;
    }


    // Gamut predicates reject invalid coordinates; clipping retains them
    // visibly rather than making them look valid.
    if (
        SRgb!T(
            T.nan,
            zero,
            zero
        ).inGamut ||
        LinearSRgb!T(
            T.infinity,
            zero,
            zero
        ).inGamut
    )
    {
        return false;
    }

    const auto clipped =
        LinearSRgb!T(
            T.nan,
            T.infinity,
            -T.infinity
        ).clip;

    if (
        !isNan(clipped.r) ||
        clipped.g != T.infinity ||
        clipped.b != -T.infinity ||
        clipped.inGamut
    )
    {
        return false;
    }

    const Oklch!T invalidMapping =
        Oklch!T(
            T.nan,
            cast(T)0.2,
            OklabHue!T.fromDegrees(
                cast(T)30
            )
        );

    if (
        invalidMapping
            .gamutMapLocalMindeToLinearSRgb
            .inGamut ||
        invalidMapping
            .gamutMapRayTraceToLinearSRgb
            .inGamut
    )
    {
        return false;
    }


    // WCAG rejects non-finite standards input through its explicit validity
    // channel.
    const auto nanMeasurement =
        wcag2RelativeLuminance(
            SRgb!T(
                T.nan,
                zero,
                zero
            )
        );

    const auto infMeasurement =
        wcag2RelativeLuminance(
            LinearSRgb!T(
                T.infinity,
                zero,
                zero
            )
        );

    const auto invalidContrast =
        wcag2ContrastRatio(
            SRgb!T(
                T.nan,
                zero,
                zero
            ),
            SRgb!T(
                zero,
                zero,
                zero
            )
        );

    if (
        nanMeasurement.valid ||
        !isNan(
            nanMeasurement.value
        ) ||
        infMeasurement.valid ||
        !isNan(
            infMeasurement.value
        ) ||
        invalidContrast.valid ||
        !isNan(
            invalidContrast.value
        )
    )
    {
        return false;
    }


    // deltaEOK has an explicit special-value precedence contract.
    if (
        !isNan(
            deltaEOK(
                Oklab!T(
                    T.nan,
                    zero,
                    zero
                ),
                Oklab!T(
                    zero,
                    zero,
                    zero
                )
            )
        ) ||
        deltaEOK(
            Oklab!T(
                T.infinity,
                zero,
                zero
            ),
            Oklab!T(
                zero,
                zero,
                zero
            )
        ) != T.infinity
    )
    {
        return false;
    }


    // Alpha arithmetic leaves invalid state visible.
    const auto nanPremultiplied =
        premultiply(
            Alpha!(LinearSRgb!T)(
                LinearSRgb!T(
                    cast(T)1,
                    cast(T)1,
                    cast(T)1
                ),
                T.nan
            )
        );

    if (
        !isNan(
            nanPremultiplied.alpha
        ) ||
        !isNan(
            nanPremultiplied.color.r
        ) ||
        nanPremultiplied.isValidAlpha
    )
    {
        return false;
    }

    const auto invalidComposite =
        sourceOver(
            Premultiplied!(LinearSRgb!T)(
                LinearSRgb!T(
                    cast(T)0.25,
                    cast(T)0.50,
                    cast(T)0.75
                ),
                T.nan
            ),
            Premultiplied!(LinearSRgb!T)(
                LinearSRgb!T(
                    cast(T)0.1,
                    cast(T)0.2,
                    cast(T)0.3
                ),
                cast(T)0.5
            )
        );

    if (
        !isNan(
            invalidComposite.alpha
        ) ||
        invalidComposite.isValidAlpha
    )
    {
        return false;
    }


    // Interpolation does not silently clamp or validate its factor/alpha.
    const auto nanInterpolation =
        interpolate(
            LinearSRgb!T(
                zero,
                zero,
                zero
            ),
            LinearSRgb!T(
                cast(T)1,
                cast(T)1,
                cast(T)1
            ),
            T.nan
        );

    if (
        !isNan(nanInterpolation.r) ||
        !isNan(nanInterpolation.g) ||
        !isNan(nanInterpolation.b)
    )
    {
        return false;
    }

    const auto infiniteInterpolation =
        interpolate(
            Oklab!T(
                zero,
                zero,
                zero
            ),
            Oklab!T(
                cast(T)1,
                cast(T)1,
                cast(T)1
            ),
            T.infinity
        );

    if (
        finiteColor(
            infiniteInterpolation
        )
    )
    {
        return false;
    }

    const auto nanAlphaInterpolation =
        interpolate(
            Alpha!(LinearSRgb!T)(
                LinearSRgb!T(
                    cast(T)1,
                    zero,
                    zero
                ),
                T.nan
            ),
            Alpha!(LinearSRgb!T)(
                LinearSRgb!T(
                    zero,
                    zero,
                    cast(T)1
                ),
                cast(T)1
            ),
            cast(T)0.5
        );

    if (
        !isNan(
            nanAlphaInterpolation.alpha
        ) ||
        nanAlphaInterpolation.isValidAlpha
    )
    {
        return false;
    }


    // Tone-batch APIs are raw component builders: non-finite schedule values
    // are copied rather than repaired. Generated linearSchedule is excluded
    // here because non-finite endpoints are an explicit programmer
    // precondition violation.
    const T[2] lightnesses =
        [
            T.nan,
            -T.infinity
        ];

    const T[2] chromas =
        [
            T.infinity,
            T.nan
        ];

    Oklch!T[2] tones;

    tonesAtLightnessAndChromaInto(
        seed,
        lightnesses,
        chromas,
        tones
    );

    if (
        !isNan(tones[0].l) ||
        tones[0].c != T.infinity ||
        tones[1].l != -T.infinity ||
        !isNan(tones[1].c)
    )
    {
        return false;
    }


    return true;
}


static assert(
    auditFiniteEdges!float()
);

static assert(
    auditFiniteEdges!double()
);


private bool reportScalar(T)(
    string scalarName
)
{
    const bool finiteEdges =
        auditFiniteEdges!T();

    const bool nonFinite =
        auditNonFinite!T();

    writefln(
        "%s: finite-edge=%s non-finite=%s",
        scalarName,
        finiteEdges,
        nonFinite
    );

    return
        finiteEdges &&
        nonFinite;
}


int main()
{
    writeln(
        "=== color-d public special-value semantics ==="
    );

    const bool floatOk =
        reportScalar!float(
            "float"
        );

    const bool doubleOk =
        reportScalar!double(
            "double"
        );

    return
        floatOk &&
        doubleOk
            ? 0
            : 1;
}
