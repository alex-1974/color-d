/++
 sRGB gamut diagnostics, hard clipping, and explicit perceptual gamut mapping.

 Clipping and perceptual mapping are distinct operations. Perceptual mapping requires an explicit algorithm choice; the module defines no default mapper.
+/
module color.gamut;

private import color.rgb :
    SRgb,
    SRgbf,
    SRgbd,
    LinearSRgb,
    LinearSRgbf,
    LinearSRgbd;

private import color.alpha :
    Alpha;

private import color.difference :
    deltaEOK;

private import color.xyz :
    xyzFromLinearSRgb = toXyzD65,
    linearSRgbFromXyz = toLinearSRgb;

private import color.oklab :
    Oklab,
    oklabFromXyz = toOklab,
    xyzFromOklab = toXyzD65;

private import color.oklch :
    Oklch,
    oklabFromOklch = toOklab;

private import std.math :
    PI,
    cos,
    sin,
    sqrt;

private bool isFiniteScalar(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}

private bool inUnitInterval(T)(T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        isFiniteScalar(value) &&
        value >= cast(T)0 &&
        value <= cast(T)1;
}

private T clampFiniteUnit(T)(T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    // Hard clipping must not make invalid numerical state look valid.
    if (!isFiniteScalar(value))
        return value;

    if (value < cast(T)0)
        return cast(T)0;

    if (value > cast(T)1)
        return cast(T)1;

    return value;
}

/**
 * Tests strict membership in the encoded-sRGB target gamut.
 *
 * All three components must be finite and in `[0, 1]`; no tolerance is implied.
 *
 * Params:
 *     color = Encoded sRGB value to test.
 *
 * Returns:
 *     `true` exactly when all components are finite and in `[0, 1]`.
 */

bool inGamut(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return
        inUnitInterval(color.r) &&
        inUnitInterval(color.g) &&
        inUnitInterval(color.b);
}

///
@safe pure nothrow @nogc unittest
{
    assert(SRgbd(0.1, 0.5, 1.0).inGamut);
    assert(!SRgbd(-0.1, 0.5, 1.0).inGamut);
}

/**
 * Tests strict membership in the linear-sRGB target gamut.
 *
 * All three components must be finite and in `[0, 1]`; no tolerance is implied.
 *
 * Params:
 *     color = Linear-light sRGB value to test.
 *
 * Returns:
 *     `true` exactly when all components are finite and in `[0, 1]`.
 */

bool inGamut(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return
        inUnitInterval(color.r) &&
        inUnitInterval(color.g) &&
        inUnitInterval(color.b);
}

/**
 * Hard-clips encoded sRGB components to `[0, 1]`.
 *
 * Finite values below zero become zero and finite values above one become one.
 * NaN and infinities remain visible rather than being silently repaired.
 *
 * Params:
 *     color = Encoded sRGB value to clip.
 *
 * Returns:
 *     The component-wise hard-clipped encoded sRGB value.
 */

SRgb!T clip(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return SRgb!T(
        clampFiniteUnit(color.r),
        clampFiniteUnit(color.g),
        clampFiniteUnit(color.b)
    );
}

///
@safe pure nothrow @nogc unittest
{
    const clipped = SRgbd(-0.25, 0.50, 1.25).clip;

    assert(clipped == SRgbd(0.0, 0.50, 1.0));
}

/**
 * Hard-clips linear-light sRGB components to `[0, 1]`.
 *
 * Finite values below zero become zero and finite values above one become one.
 * NaN and infinities remain visible rather than being silently repaired.
 *
 * Params:
 *     color = Linear-light sRGB value to clip.
 *
 * Returns:
 *     The component-wise hard-clipped linear-light sRGB value.
 */

LinearSRgb!T clip(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        clampFiniteUnit(color.r),
        clampFiniteUnit(color.g),
        clampFiniteUnit(color.b)
    );
}


private bool isFiniteOklch(T)(Oklch!T value)
@safe pure nothrow @nogc
{
    return
        isFiniteScalar(value.l) &&
        isFiniteScalar(value.c) &&
        isFiniteScalar(value.h.rawDegrees);
}


private bool isFiniteLinearSRgb(T)(LinearSRgb!T value)
@safe pure nothrow @nogc
{
    return
        isFiniteScalar(value.r) &&
        isFiniteScalar(value.g) &&
        isFiniteScalar(value.b);
}


private LinearSRgb!T oklabToLinearSRgb(T)(Oklab!T value)
@safe pure nothrow @nogc
{
    return
        linearSRgbFromXyz(
            xyzFromOklab(value)
        );
}


private Oklab!T linearSRgbToOklab(T)(LinearSRgb!T value)
@safe pure nothrow @nogc
{
    return
        oklabFromXyz(
            xyzFromLinearSRgb(value)
        );
}


private LinearSRgb!T oklchToLinearSRgb(T)(Oklch!T value)
@safe pure nothrow @nogc
{
    return
        oklabToLinearSRgb(
            oklabFromOklch(value)
        );
}


private Oklab!T fixedHueOklab(T)(
    const T lightness,
    const T chroma,
    const T cosHue,
    const T sinHue
)
@safe pure nothrow @nogc
{
    return Oklab!T(
        lightness,
        chroma * cosHue,
        chroma * sinHue
    );
}


private T hueRadians(T)(Oklch!T value)
@safe pure nothrow @nogc
{
    /*
     * Preserve raw hue storage, but reduce complete revolutions before
     * converting to radians. This avoids overflow for very large finite raw
     * degree values while preserving the represented Cartesian direction.
     */
    return
        value.h.positiveDegrees *
        cast(T)(PI / 180.0L);
}


private T absoluteValue(T)(T value)
@safe pure nothrow @nogc
{
    return
        value < cast(T)0
            ? -value
            : value;
}


private T minimum(T)(T first, T second)
@safe pure nothrow @nogc
{
    return
        first < second
            ? first
            : second;
}


private T maximum(T)(T first, T second)
@safe pure nothrow @nogc
{
    return
        first > second
            ? first
            : second;
}


private T rayEpsilon(T)()
@safe pure nothrow @nogc
{
    static if (is(T == float))
        return cast(T)1e-6;
    else
        return cast(T)1e-12;
}


private bool insideInterior(T)(
    LinearSRgb!T value,
    T low,
    T high
)
@safe pure nothrow @nogc
{
    return
        isFiniteScalar(value.r) &&
        isFiniteScalar(value.g) &&
        isFiniteScalar(value.b) &&
        value.r >= low &&
        value.r <= high &&
        value.g >= low &&
        value.g <= high &&
        value.b >= low &&
        value.b <= high;
}


private struct RayIntersection(T)
if (is(T == float) || is(T == double))
{
    LinearSRgb!T color;
    bool found;
}


private RayIntersection!T noRayIntersection(T)()
@safe pure nothrow @nogc
{
    return RayIntersection!T(
        LinearSRgb!T.init,
        false
    );
}


private pragma(inline, true)
RayIntersection!T intersectUnitRgbCube(T)(
    LinearSRgb!T start,
    LinearSRgb!T end
)
@safe pure nothrow @nogc
{
    if (
        !isFiniteScalar(start.r) ||
        !isFiniteScalar(start.g) ||
        !isFiniteScalar(start.b) ||
        !isFiniteScalar(end.r) ||
        !isFiniteScalar(end.g) ||
        !isFiniteScalar(end.b)
    )
    {
        return noRayIntersection!T();
    }

    const T eps =
        rayEpsilon!T();

    T[3] a = [
        start.r,
        start.g,
        start.b
    ];

    T[3] b = [
        end.r,
        end.g,
        end.b
    ];

    T[3] direction;

    T tNear =
        -T.infinity;

    T tFar =
        T.infinity;

    foreach (i; 0 .. 3)
    {
        const T d =
            b[i] - a[i];

        if (!isFiniteScalar(d))
            return noRayIntersection!T();

        direction[i] = d;

        if (
            absoluteValue(d) >
            eps
        )
        {
            const T inverse =
                cast(T)1 / d;

            const T first =
                (cast(T)0 - a[i]) *
                inverse;

            const T second =
                (cast(T)1 - a[i]) *
                inverse;

            tNear =
                maximum(
                    minimum(
                        first,
                        second
                    ),
                    tNear
                );

            tFar =
                minimum(
                    maximum(
                        first,
                        second
                    ),
                    tFar
                );
        }
        else if (
            a[i] < cast(T)0 ||
            a[i] > cast(T)1
        )
        {
            return noRayIntersection!T();
        }
    }

    if (
        tNear > tFar ||
        tFar < cast(T)0
    )
    {
        return noRayIntersection!T();
    }

    if (tNear < cast(T)0)
        tNear = tFar;

    if (!isFiniteScalar(tNear))
        return noRayIntersection!T();

    return RayIntersection!T(
        LinearSRgb!T(
            a[0] +
                direction[0] * tNear,
            a[1] +
                direction[1] * tNear,
            a[2] +
                direction[2] * tNear
        ),
        true
    );
}


/*
 * Intersect the unit linear-sRGB cube using an explicit ray direction.
 *
 * This is intentionally separate from intersectUnitRgbCube(). The ordinary
 * Ray Trace hot path retains the R0.8-validated endpoint implementation.
 * This helper exists only for the first-ray overflow fallback, where the
 * mathematically valid endpoint cannot itself be represented as finite RGB.
 */
private RayIntersection!T intersectUnitRgbCubeDirection(T)(
    LinearSRgb!T start,
    LinearSRgb!T direction
)
@safe pure nothrow @nogc
{
    if (
        !isFiniteLinearSRgb(start) ||
        !isFiniteLinearSRgb(direction)
    )
    {
        return noRayIntersection!T();
    }

    const T eps =
        rayEpsilon!T();

    T[3] a = [
        start.r,
        start.g,
        start.b
    ];

    T[3] d = [
        direction.r,
        direction.g,
        direction.b
    ];

    T tNear =
        -T.infinity;

    T tFar =
        T.infinity;

    foreach (i; 0 .. 3)
    {
        if (
            absoluteValue(d[i]) >
            eps
        )
        {
            const T inverse =
                cast(T)1 / d[i];

            const T first =
                (cast(T)0 - a[i]) *
                inverse;

            const T second =
                (cast(T)1 - a[i]) *
                inverse;

            tNear =
                maximum(
                    minimum(
                        first,
                        second
                    ),
                    tNear
                );

            tFar =
                minimum(
                    maximum(
                        first,
                        second
                    ),
                    tFar
                );
        }
        else if (
            a[i] < cast(T)0 ||
            a[i] > cast(T)1
        )
        {
            return noRayIntersection!T();
        }
    }

    if (
        tNear > tFar ||
        tFar < cast(T)0
    )
    {
        return noRayIntersection!T();
    }

    if (tNear < cast(T)0)
        tNear = tFar;

    if (!isFiniteScalar(tNear))
        return noRayIntersection!T();

    return RayIntersection!T(
        LinearSRgb!T(
            a[0] +
                d[0] * tNear,
            a[1] +
                d[1] * tNear,
            a[2] +
                d[2] * tNear
        ),
        true
    );
}


/*
 * Recover one component of the fixed-L/fixed-hue cubic RGB(C) polynomial
 * from the safe C = 1, 2, 3 samples, then evaluate a direction proportional
 * to RGB(C) - RGB(0) without ever forming C^2 or C^3.
 *
 * For positive canonical chroma:
 *
 *   RGB(C) - RGB(0)
 *       = q1*C + q2*C^2 + q3*C^3
 *
 * and therefore the positive-scaled equivalent ray direction is:
 *
 *   q3 + q2/C + q1/C^2.
 */
private T scaledCubicRayDirectionComponent(T)(
    const T sample1,
    const T sample2,
    const T sample3,
    const T base,
    const T chroma
)
@safe pure nothrow @nogc
{
    const T first =
        sample1 - base;

    const T second =
        sample2 - base;

    const T third =
        sample3 - base;

    const T cubic =
        (
            third -
            cast(T)3 * second +
            cast(T)3 * first
        ) /
        cast(T)6;

    const T quadratic =
        (
            second -
            cast(T)2 * first -
            cast(T)6 * cubic
        ) /
        cast(T)2;

    const T linear =
        first -
        quadratic -
        cubic;

    const T inverseChroma =
        cast(T)1 / chroma;

    return
        cubic +
        quadratic * inverseChroma +
        linear *
            inverseChroma *
            inverseChroma;
}


/*
 * Construct a finite direction for the first Ray Trace intersection when
 * direct fixed-L/fixed-hue conversion overflows.
 *
 * Sampling C = 1, 2, 3 uses the ordinary production conversion route. The
 * returned vector is only a positive scaling of the required first ray and
 * therefore preserves the cube intersection while avoiding C^3 overflow.
 */
private LinearSRgb!T scaledHugeChromaRayDirection(T)(
    const T lightness,
    const T chroma,
    const T cosHue,
    const T sinHue,
    LinearSRgb!T anchor
)
@safe pure nothrow @nogc
{
    const LinearSRgb!T sample1 =
        oklabToLinearSRgb(
            fixedHueOklab(
                lightness,
                cast(T)1,
                cosHue,
                sinHue
            )
        );

    const LinearSRgb!T sample2 =
        oklabToLinearSRgb(
            fixedHueOklab(
                lightness,
                cast(T)2,
                cosHue,
                sinHue
            )
        );

    const LinearSRgb!T sample3 =
        oklabToLinearSRgb(
            fixedHueOklab(
                lightness,
                cast(T)3,
                cosHue,
                sinHue
            )
        );

    return LinearSRgb!T(
        scaledCubicRayDirectionComponent(
            sample1.r,
            sample2.r,
            sample3.r,
            anchor.r,
            chroma
        ),
        scaledCubicRayDirectionComponent(
            sample1.g,
            sample2.g,
            sample3.g,
            anchor.g,
            chroma
        ),
        scaledCubicRayDirectionComponent(
            sample1.b,
            sample2.b,
            sample3.b,
            anchor.b,
            chroma
        )
    );
}


private T binaryMidpoint(T)(
    T low,
    T high
)
@safe pure nothrow @nogc
{
    /*
     * Preserve the R0.8 arithmetic for ordinary values. Only switch to the
     * overflow-safe form when low + high itself cannot be represented.
     */
    if (
        low > cast(T)0 &&
        high > T.max - low
    )
    {
        return
            low +
            (high - low) /
            cast(T)2;
    }

    return
        (low + high) /
        cast(T)2;
}


private LinearSRgb!T gamutMapLocalMindeImpl(T)(
    Oklch!T origin
)
@safe pure nothrow @nogc
{
    const T radians =
        hueRadians(origin);

    const T cosHue =
        cast(T)cos(radians);

    const T sinHue =
        cast(T)sin(radians);

    Oklab!T currentLab =
        fixedHueOklab(
            origin.l,
            origin.c,
            cosHue,
            sinHue
        );

    LinearSRgb!T currentRgb =
        oklabToLinearSRgb(
            currentLab
        );

    // Required identity/fast path.
    if (currentRgb.inGamut)
        return currentRgb;

    enum T jnd =
        cast(T)0.02;

    enum T epsilon =
        cast(T)0.0001;

    LinearSRgb!T clipped =
        currentRgb.clip;

    T difference =
        deltaEOK(
            linearSRgbToOklab(clipped),
            currentLab
        );

    if (difference < jnd)
        return clipped;

    T low =
        cast(T)0;

    T high =
        origin.c;

    bool lowInGamut =
        true;

    /*
     * 2048 is a defensive numerical-progress ceiling, not public policy.
     * It is larger than required to bisect the complete finite float/double
     * chroma range down to the Local-MINDE epsilon.
     */
    foreach (_; 0 .. 2048)
    {
        if (
            high - low <=
            epsilon
        )
        {
            break;
        }

        const T chroma =
            binaryMidpoint(
                low,
                high
            );

        if (
            chroma == low ||
            chroma == high
        )
        {
            break;
        }

        currentLab =
            fixedHueOklab(
                origin.l,
                chroma,
                cosHue,
                sinHue
            );

        currentRgb =
            oklabToLinearSRgb(
                currentLab
            );

        if (
            lowInGamut &&
            currentRgb.inGamut
        )
        {
            low = chroma;
            continue;
        }

        clipped =
            currentRgb.clip;

        difference =
            deltaEOK(
                linearSRgbToOklab(
                    clipped
                ),
                currentLab
            );

        if (difference < jnd)
        {
            if (
                jnd - difference <
                epsilon
            )
            {
                return clipped;
            }

            lowInGamut = false;
            low = chroma;
        }
        else
        {
            high = chroma;
        }
    }

    return clipped;
}


private LinearSRgb!T gamutMapRayTraceImpl(T)(
    Oklch!T origin
)
@safe pure nothrow @nogc
{
    const T originalLightness =
        origin.l;

    const T radians =
        hueRadians(origin);

    const T cosHue =
        cast(T)cos(radians);

    const T sinHue =
        cast(T)sin(radians);

    LinearSRgb!T anchor =
        oklabToLinearSRgb(
            fixedHueOklab(
                originalLightness,
                cast(T)0,
                cosHue,
                sinHue
            )
        );

    LinearSRgb!T originRgb =
        oklabToLinearSRgb(
            fixedHueOklab(
                originalLightness,
                origin.c,
                cosHue,
                sinHue
            )
        );

    // Required identity/fast path.
    if (originRgb.inGamut)
        return originRgb;

    const T eps =
        rayEpsilon!T();

    const T low =
        cast(T)0 + eps;

    const T high =
        cast(T)1 - eps;

    LinearSRgb!T last =
        originRgb;

    // R0.8 validated the bounded four-intersection form.
    foreach (i; 0 .. 4)
    {
        if (i > 0)
        {
            /*
             * Only chroma is required from the intermediate Oklab value.
             * Retain original L and hue direction and avoid atan2 entirely.
             */
            const Oklab!T currentLab =
                linearSRgbToOklab(
                    originRgb
                );

            const T chroma =
                cast(T)sqrt(
                    currentLab.a *
                        currentLab.a +
                    currentLab.b *
                        currentLab.b
                );

            originRgb =
                oklabToLinearSRgb(
                    fixedHueOklab(
                        originalLightness,
                        chroma,
                        cosHue,
                        sinHue
                    )
                );
        }

        auto intersection =
            intersectUnitRgbCube(
                anchor,
                originRgb
            );

        if (!intersection.found)
        {
            /*
             * A finite OKLCH value can have such large chroma that the
             * mathematically valid fixed-L/fixed-hue RGB endpoint overflows.
             *
             * Preserve the ordinary R0.8 path whenever that endpoint is
             * representable. Only the first failed intersection of a finite,
             * positive-canonical input receives the scaled-direction
             * fallback.
             */
            if (
                i == 0 &&
                isFiniteOklch(origin) &&
                origin.c > cast(T)0 &&
                !isFiniteLinearSRgb(
                    originRgb
                )
            )
            {
                intersection =
                    intersectUnitRgbCubeDirection(
                        anchor,
                        scaledHugeChromaRayDirection(
                            originalLightness,
                            origin.c,
                            cosHue,
                            sinHue,
                            anchor
                        )
                    );
            }

            if (!intersection.found)
            {
                originRgb = last;
                break;
            }
        }

        if (
            i > 0 &&
            originRgb.insideInterior(
                low,
                high
            )
        )
        {
            anchor =
                originRgb;
        }

        originRgb =
            intersection.color;

        last =
            intersection.color;
    }

    return originRgb.clip;
}


/**
 * Perceptually maps an OKLCH color into linear sRGB using Local MINDE.
 *
 * Local MINDE is the perceptual/reference-oriented mapping strategy. Negative
 * finite chroma is canonicalized before mapping. Lightness at or above 1 maps
 * to white and lightness at or below 0 maps to black. Already-in-gamut colors
 * take the identity path after explicit conversion.
 *
 * Non-finite input is not repaired. This is per-color mathematical mapping and
 * does not define image-wide rendering intent, encoding, or alpha compositing.
 *
 * Params:
 *     color = OKLCH color to map.
 *
 * Returns:
 *     A linear-sRGB color in gamut for finite mapped input.
 *
 * See_Also:
 *     gamutMapRayTraceToLinearSRgb, clip
 */

LinearSRgb!T gamutMapLocalMindeToLinearSRgb(T)(
    Oklch!T color
)
@safe pure nothrow @nogc
{
    if (!isFiniteOklch(color))
        return oklchToLinearSRgb(color);

    color =
        color.canonicalized;

    if (color.l >= cast(T)1)
    {
        return LinearSRgb!T(
            cast(T)1,
            cast(T)1,
            cast(T)1
        );
    }

    if (color.l <= cast(T)0)
    {
        return LinearSRgb!T(
            cast(T)0,
            cast(T)0,
            cast(T)0
        );
    }

    return
        gamutMapLocalMindeImpl(
            color
        );
}


/**
 * Perceptually maps an OKLCH color into linear sRGB using Ray Trace.
 *
 * Ray Trace is the bounded-cost/performance-oriented mapping strategy.
 * Negative finite chroma is canonicalized before mapping. Lightness at or
 * above 1 maps to white and lightness at or below 0 maps to black.
 * Already-in-gamut colors take the identity path after explicit conversion.
 *
 * Non-finite input is not repaired. This is per-color mathematical mapping and
 * does not define image-wide rendering intent, encoding, or alpha compositing.
 *
 * Params:
 *     color = OKLCH color to map.
 *
 * Returns:
 *     A linear-sRGB color in gamut for finite mapped input.
 *
 * See_Also:
 *     gamutMapLocalMindeToLinearSRgb, clip
 */

LinearSRgb!T gamutMapRayTraceToLinearSRgb(T)(
    Oklch!T color
)
@safe pure nothrow @nogc
{
    if (!isFiniteOklch(color))
        return oklchToLinearSRgb(color);

    color =
        color.canonicalized;

    if (color.l >= cast(T)1)
    {
        return LinearSRgb!T(
            cast(T)1,
            cast(T)1,
            cast(T)1
        );
    }

    if (color.l <= cast(T)0)
    {
        return LinearSRgb!T(
            cast(T)0,
            cast(T)0,
            cast(T)0
        );
    }

    return
        gamutMapRayTraceImpl(
            color
        );
}


/**
 * Maps a straight-alpha OKLCH color using Local MINDE.
 *
 * Only the wrapped color is mapped. Alpha is copied unchanged and is not
 * clamped, premultiplied, composited, or otherwise interpreted.
 *
 * Params:
 *     value = Straight-alpha OKLCH value to map.
 *
 * Returns:
 *     Straight-alpha linear sRGB with unchanged alpha.
 */

Alpha!(LinearSRgb!T) gamutMapLocalMindeToLinearSRgb(T)(
    Alpha!(Oklch!T) value
)
@safe pure nothrow @nogc
{
    return Alpha!(LinearSRgb!T)(
        gamutMapLocalMindeToLinearSRgb(
            value.color
        ),
        value.alpha
    );
}


/**
 * Maps a straight-alpha OKLCH color using Ray Trace.
 *
 * Only the wrapped color is mapped. Alpha is copied unchanged and is not
 * clamped, premultiplied, composited, or otherwise interpreted.
 *
 * Params:
 *     value = Straight-alpha OKLCH value to map.
 *
 * Returns:
 *     Straight-alpha linear sRGB with unchanged alpha.
 */

Alpha!(LinearSRgb!T) gamutMapRayTraceToLinearSRgb(T)(
    Alpha!(Oklch!T) value
)
@safe pure nothrow @nogc
{
    return Alpha!(LinearSRgb!T)(
        gamutMapRayTraceToLinearSRgb(
            value.color
        ),
        value.alpha
    );
}


/// Explicit per-color perceptual mapping requires an algorithm choice.
@safe pure nothrow @nogc unittest
{
    import color.oklch :
        OklabHued,
        Oklchd;

    const input =
        Oklchd(
            0.96476,
            0.24503,
            OklabHued.fromDegrees(
                110.23
            )
        );

    const mapped =
        input.gamutMapRayTraceToLinearSRgb();

    assert(mapped.inGamut);
}


version (unittest)
{
    private import color.oklab :
        Oklabf;

    private import color.oklch :
        OklabHue,
        OklabHuef,
        OklabHued,
        Oklchf,
        Oklchd,
        toOklch;

    // ------------------------------------------------------------------
    // R0.8 reference implementations.
    //
    // These intentionally retain the slower pre-optimization algorithmic
    // routes. They exist only in unittest builds and are not public API.
    // ------------------------------------------------------------------

    private LinearSRgb!T referenceLocalMinde(T)(
        Oklch!T origin
    )
    @safe pure nothrow @nogc
    {
        if (!isFiniteOklch(origin))
            return LinearSRgb!T.init;

        origin =
            origin.canonicalized;

        if (origin.l >= cast(T)1)
        {
            return LinearSRgb!T(
                cast(T)1,
                cast(T)1,
                cast(T)1
            );
        }

        if (origin.l <= cast(T)0)
        {
            return LinearSRgb!T(
                cast(T)0,
                cast(T)0,
                cast(T)0
            );
        }

        LinearSRgb!T currentRgb =
            oklchToLinearSRgb(
                origin
            );

        if (currentRgb.inGamut)
            return currentRgb;

        enum T jnd =
            cast(T)0.02;

        enum T epsilon =
            cast(T)0.0001;

        Oklch!T current =
            origin;

        LinearSRgb!T clipped =
            currentRgb.clip;

        T difference =
            deltaEOK(
                linearSRgbToOklab(
                    clipped
                ),
                oklabFromOklch(
                    current
                )
            );

        if (difference < jnd)
            return clipped;

        T low =
            cast(T)0;

        T high =
            origin.c;

        bool lowInGamut =
            true;

        uint iterations = 0;

        while (
            high - low >
            epsilon
        )
        {
            ++iterations;

            // R0.8 reference arithmetic, deliberately not binaryMidpoint().
            const T chroma =
                (low + high) /
                cast(T)2;

            current.c =
                chroma;

            currentRgb =
                oklchToLinearSRgb(
                    current
                );

            if (
                lowInGamut &&
                currentRgb.inGamut
            )
            {
                low = chroma;
                continue;
            }

            clipped =
                currentRgb.clip;

            difference =
                deltaEOK(
                    linearSRgbToOklab(
                        clipped
                    ),
                    oklabFromOklch(
                        current
                    )
                );

            if (difference < jnd)
            {
                if (
                    jnd - difference <
                    epsilon
                )
                {
                    return clipped;
                }

                lowInGamut = false;
                low = chroma;
            }
            else
            {
                high = chroma;
            }

            // Same defensive research bound used by R0.8.
            assert(iterations <= 128);
        }

        return clipped;
    }


    private LinearSRgb!T referenceRayTrace(T)(
        Oklch!T origin
    )
    @safe pure nothrow @nogc
    {
        if (!isFiniteOklch(origin))
            return LinearSRgb!T.init;

        origin =
            origin.canonicalized;

        if (origin.l >= cast(T)1)
        {
            return LinearSRgb!T(
                cast(T)1,
                cast(T)1,
                cast(T)1
            );
        }

        if (origin.l <= cast(T)0)
        {
            return LinearSRgb!T(
                cast(T)0,
                cast(T)0,
                cast(T)0
            );
        }

        const T originalLightness =
            origin.l;

        const T originalHue =
            origin.h.rawDegrees;

        LinearSRgb!T anchor =
            oklchToLinearSRgb(
                Oklch!T(
                    originalLightness,
                    cast(T)0,
                    OklabHue!T.fromDegrees(
                        originalHue
                    )
                )
            );

        LinearSRgb!T originRgb =
            oklchToLinearSRgb(
                origin
            );

        if (originRgb.inGamut)
            return originRgb;

        const T eps =
            rayEpsilon!T();

        const T low =
            cast(T)0 + eps;

        const T high =
            cast(T)1 - eps;

        LinearSRgb!T last =
            originRgb;

        foreach (i; 0 .. 4)
        {
            if (i > 0)
            {
                /*
                 * R0.8 reference route:
                 *
                 * Linear RGB -> Oklab -> OKLCH,
                 * restore original L and hue,
                 * OKLCH -> Oklab -> Linear RGB.
                 *
                 * The production implementation avoids this atan2 route.
                 */
                Oklch!T current =
                    toOklch(
                        linearSRgbToOklab(
                            originRgb
                        )
                    );

                current.l =
                    originalLightness;

                current.h =
                    OklabHue!T.fromDegrees(
                        originalHue
                    );

                originRgb =
                    oklchToLinearSRgb(
                        current
                    );
            }

            const auto intersection =
                intersectUnitRgbCube(
                    anchor,
                    originRgb
                );

            if (!intersection.found)
            {
                originRgb = last;
                break;
            }

            if (
                i > 0 &&
                originRgb.insideInterior(
                    low,
                    high
                )
            )
            {
                anchor =
                    originRgb;
            }

            originRgb =
                intersection.color;

            last =
                intersection.color;
        }

        return originRgb.clip;
    }


    private struct R08GamutLcg
    {
        ulong state;

        uint next()
        @safe pure nothrow @nogc
        {
            state =
                state *
                    6364136223846793005UL +
                1442695040888963407UL;

            return
                cast(uint)(
                    state >> 32
                );
        }

        double unit()
        @safe pure nothrow @nogc
        {
            return
                cast(double)next() /
                cast(double)uint.max;
        }
    }


    private void verifyR08OptimizedMappings(
        size_t sampleCount
    )
    @safe pure nothrow @nogc
    {
        R08GamutLcg rng =
            R08GamutLcg(
                0xC010_D008_2026_0020UL
            );

        size_t accepted = 0;

        while (
            accepted <
            sampleCount
        )
        {
            const double lightness =
                0.05 +
                rng.unit() * 0.90;

            const double chroma =
                0.22 +
                rng.unit() * 0.24;

            const double hue =
                rng.unit() * 360.0;

            Oklchd candidateD =
                Oklchd(
                    lightness,
                    chroma,
                    OklabHued.fromDegrees(
                        hue
                    )
                );

            Oklchf candidateF =
                Oklchf(
                    cast(float)lightness,
                    cast(float)chroma,
                    OklabHuef.fromDegrees(
                        cast(float)hue
                    )
                );

            // Preserve the paired R0.8 dataset contract.
            if (
                oklchToLinearSRgb(
                    candidateD
                ).inGamut ||
                oklchToLinearSRgb(
                    candidateF
                ).inGamut
            )
            {
                continue;
            }

            const auto referenceLocalD =
                referenceLocalMinde(
                    candidateD
                );

            const auto productionLocalD =
                gamutMapLocalMindeToLinearSRgb(candidateD);

            const auto referenceRayD =
                referenceRayTrace(
                    candidateD
                );

            const auto productionRayD =
                gamutMapRayTraceToLinearSRgb(candidateD);

            assert(referenceLocalD.inGamut);
            assert(productionLocalD.inGamut);
            assert(referenceRayD.inGamut);
            assert(productionRayD.inGamut);

            // R0.8 observed exact numerical equivalence in Oklab.
            assert(
                deltaEOK(
                    linearSRgbToOklab(
                        referenceLocalD
                    ),
                    linearSRgbToOklab(
                        productionLocalD
                    )
                ) == 0
            );

            assert(
                deltaEOK(
                    linearSRgbToOklab(
                        referenceRayD
                    ),
                    linearSRgbToOklab(
                        productionRayD
                    )
                ) == 0
            );


            const auto referenceLocalF =
                referenceLocalMinde(
                    candidateF
                );

            const auto productionLocalF =
                gamutMapLocalMindeToLinearSRgb(candidateF);

            const auto referenceRayF =
                referenceRayTrace(
                    candidateF
                );

            const auto productionRayF =
                gamutMapRayTraceToLinearSRgb(candidateF);

            assert(referenceLocalF.inGamut);
            assert(productionLocalF.inGamut);
            assert(referenceRayF.inGamut);
            assert(productionRayF.inGamut);

            assert(
                deltaEOK(
                    linearSRgbToOklab(
                        referenceLocalF
                    ),
                    linearSRgbToOklab(
                        productionLocalF
                    )
                ) == 0
            );

            assert(
                deltaEOK(
                    linearSRgbToOklab(
                        referenceRayF
                    ),
                    linearSRgbToOklab(
                        productionRayF
                    )
                ) == 0
            );


            // R0.8 "approximate idempotence" boundary:
            // once mapped, remapping the represented target color remains
            // inside the target gamut. No exact second-pass identity is
            // promoted as a stronger public contract.
            Oklchd localAgainInputD =
                toOklch(
                    linearSRgbToOklab(
                        productionLocalD
                    )
                );

            Oklchd rayAgainInputD =
                toOklch(
                    linearSRgbToOklab(
                        productionRayD
                    )
                );

            assert(
                gamutMapLocalMindeToLinearSRgb(localAgainInputD).inGamut
            );

            assert(
                gamutMapRayTraceToLinearSRgb(rayAgainInputD).inGamut
            );

            ++accepted;
        }
    }


    private void verifyR08InGamutFastPath(
        size_t sampleCount
    )
    @safe pure nothrow @nogc
    {
        R08GamutLcg rng =
            R08GamutLcg(
                0xC010_D008_2026_0010UL
            );

        size_t accepted = 0;

        while (
            accepted <
            sampleCount
        )
        {
            /*
             * Same comfortably interior linear-sRGB dataset shape used by
             * R0.8 to isolate the fast path from cube-boundary noise.
             */
            LinearSRgbd source =
                LinearSRgbd(
                    0.05 +
                        rng.unit() * 0.90,
                    0.05 +
                        rng.unit() * 0.90,
                    0.05 +
                        rng.unit() * 0.90
                );

            Oklchd candidate =
                toOklch(
                    linearSRgbToOklab(
                        source
                    )
                );

            LinearSRgbd expected =
                oklchToLinearSRgb(
                    candidate
                );

            if (!expected.inGamut)
                continue;

            // This exact equality is the actual production fast-path contract:
            // no perceptual mapping work changes an already-valid target color
            // after the explicit OKLCH -> linear-sRGB conversion.
            assert(
                gamutMapLocalMindeToLinearSRgb(candidate) == expected
            );

            assert(
                gamutMapRayTraceToLinearSRgb(candidate) == expected
            );

            ++accepted;
        }
    }


    // Mapping is deliberately available only from OKLCH and requires an
    // explicit algorithm choice.
    static assert(!__traits(compiles,
        gamutMapRayTraceToLinearSRgb(SRgbd.init)
    ));

    static assert(!__traits(compiles,
        gamutMapRayTraceToLinearSRgb(LinearSRgbd.init)
    ));

    static assert(!__traits(compiles,
        gamutMapLocalMindeToLinearSRgb(Oklabf.init)
    ));

    // R0.8 published yellow: representative out-of-gamut mapping case.
    enum mappingYellowD =
        Oklchd(
            0.96476,
            0.24503,
            OklabHued.fromDegrees(
                110.23
            )
        );

    enum mappedYellowLocalD =
        gamutMapLocalMindeToLinearSRgb(mappingYellowD);

    enum mappedYellowRayD =
        gamutMapRayTraceToLinearSRgb(mappingYellowD);

    static assert(
        mappedYellowLocalD.inGamut
    );

    static assert(
        mappedYellowRayD.inGamut
    );


    // Independent float instantiation.
    enum mappingYellowF =
        Oklchf(
            0.96476f,
            0.24503f,
            OklabHuef.fromDegrees(
                110.23f
            )
        );

    enum mappedYellowRayF =
        gamutMapRayTraceToLinearSRgb(mappingYellowF);

    static assert(
        mappedYellowRayF.inGamut
    );


    // Already-in-gamut conversion is the exact fast path.
    enum ordinaryLchD =
        Oklchd(
            0.60,
            0.05,
            OklabHued.fromDegrees(
                30.0
            )
        );

    enum ordinaryLinearD =
        oklchToLinearSRgb(
            ordinaryLchD
        );

    static assert(
        ordinaryLinearD.inGamut
    );

    static assert(
        gamutMapLocalMindeToLinearSRgb(ordinaryLchD) == ordinaryLinearD
    );

    static assert(
        gamutMapRayTraceToLinearSRgb(ordinaryLchD) == ordinaryLinearD
    );


    // Mapping canonicalizes negative chroma only as required by the mapping
    // algorithm; the stored input value itself remains untouched.
    enum negativeChromaD =
        Oklchd(
            0.60,
            -0.20,
            OklabHued.fromDegrees(
                30.0
            )
        );

    enum canonicalChromaD =
        negativeChromaD.canonicalized;

    static assert(
        gamutMapLocalMindeToLinearSRgb(negativeChromaD) ==
        gamutMapLocalMindeToLinearSRgb(canonicalChromaD)
    );

    static assert(
        gamutMapRayTraceToLinearSRgb(negativeChromaD) ==
        gamutMapRayTraceToLinearSRgb(canonicalChromaD)
    );


    // Lightness extremes retain the R0.8 exact boundary behavior.
    enum tooLightD =
        Oklchd(
            1.2,
            0.2,
            OklabHued.fromDegrees(
                30
            )
        );

    enum tooDarkD =
        Oklchd(
            -0.2,
            0.2,
            OklabHued.fromDegrees(
                30
            )
        );

    static assert(
        gamutMapLocalMindeToLinearSRgb(tooLightD) ==
        LinearSRgbd(1, 1, 1)
    );

    static assert(
        gamutMapRayTraceToLinearSRgb(tooLightD) ==
        LinearSRgbd(1, 1, 1)
    );

    static assert(
        gamutMapLocalMindeToLinearSRgb(tooDarkD) ==
        LinearSRgbd(0, 0, 0)
    );

    static assert(
        gamutMapRayTraceToLinearSRgb(tooDarkD) ==
        LinearSRgbd(0, 0, 0)
    );


    // Non-finite input must not be repaired into an apparently valid color.
    enum nonFiniteMappingD =
        Oklchd(
            double.nan,
            0.2,
            OklabHued.fromDegrees(
                30
            )
        );

    enum nonFiniteLocalD =
        gamutMapLocalMindeToLinearSRgb(nonFiniteMappingD);

    enum nonFiniteRayD =
        gamutMapRayTraceToLinearSRgb(nonFiniteMappingD);

    static assert(
        !nonFiniteLocalD.inGamut
    );

    static assert(
        !nonFiniteRayD.inGamut
    );

    static assert(
        nonFiniteLocalD.r !=
        nonFiniteLocalD.r
    );

    static assert(
        nonFiniteRayD.r !=
        nonFiniteRayD.r
    );


    // Straight alpha is orthogonal and preserved byte-for-byte numerically.
    enum alphaYellowD =
        Alpha!Oklchd(
            mappingYellowD,
            0.37
        );

    enum alphaMappedLocalD =
        gamutMapLocalMindeToLinearSRgb(alphaYellowD);

    enum alphaMappedRayD =
        gamutMapRayTraceToLinearSRgb(alphaYellowD);

    static assert(
        alphaMappedLocalD.alpha ==
        0.37
    );

    static assert(
        alphaMappedRayD.alpha ==
        0.37
    );

    static assert(
        alphaMappedLocalD.color.inGamut
    );

    static assert(
        alphaMappedRayD.color.inGamut
    );


    // STRICT CLASSIFICATION: exact target-space geometry, no hidden epsilon.
    static assert(SRgbd(0.0, 0.0, 0.0).inGamut);
    static assert(SRgbd(1.0, 1.0, 1.0).inGamut);
    static assert(LinearSRgbd(0.0, 0.0, 0.0).inGamut);
    static assert(LinearSRgbd(1.0, 1.0, 1.0).inGamut);

    static assert(!SRgbd(-0.0001, 0.5, 0.5).inGamut);
    static assert(!SRgbd(1.0001, 0.5, 0.5).inGamut);
    static assert(!LinearSRgbd(-0.0001, 0.5, 0.5).inGamut);
    static assert(!LinearSRgbd(1.0001, 0.5, 0.5).inGamut);

    // Non-finite coordinates are outside the strict target gamut.
    static assert(!SRgbd(double.nan, 0.5, 0.5).inGamut);
    static assert(!SRgbd(double.infinity, 0.5, 0.5).inGamut);
    static assert(!SRgbd(-double.infinity, 0.5, 0.5).inGamut);

    static assert(!LinearSRgbf(float.nan, 0.5f, 0.5f).inGamut);
    static assert(!LinearSRgbf(float.infinity, 0.5f, 0.5f).inGamut);
    static assert(!LinearSRgbf(-float.infinity, 0.5f, 0.5f).inGamut);

    // EXACT: hard clipping saturates finite target coordinates.
    enum clippedLinear =
        LinearSRgbd(-0.2, 0.4, 1.3).clip;

    static assert(clippedLinear.r == 0.0);
    static assert(clippedLinear.g == 0.4);
    static assert(clippedLinear.b == 1.0);
    static assert(clippedLinear.inGamut);

    enum clippedEncoded =
        SRgbf(-0.2f, 0.4f, 1.3f).clip;

    static assert(clippedEncoded.r == 0.0f);
    static assert(clippedEncoded.g == 0.4f);
    static assert(clippedEncoded.b == 1.0f);
    static assert(clippedEncoded.inGamut);

    // EXACT: finite clipping is idempotent.
    static assert(clippedLinear.clip == clippedLinear);
    static assert(clippedEncoded.clip == clippedEncoded);

    // Non-finite state is deliberately not repaired by clipping.
    enum nonFinite =
        LinearSRgbd(
            double.nan,
            double.infinity,
            -double.infinity
        ).clip;

    static assert(nonFinite.r != nonFinite.r);
    static assert(nonFinite.g == double.infinity);
    static assert(nonFinite.b == -double.infinity);
    static assert(!nonFinite.inGamut);

    // Gamut operations are target-space operations in this R1 slice.
    static assert(!__traits(compiles, Oklabf.init.inGamut));
    static assert(!__traits(compiles, Oklchf.init.inGamut));
    static assert(!__traits(compiles, Oklabf.init.clip));
    static assert(!__traits(compiles, Oklchf.init.clip));
}

@safe pure nothrow @nogc unittest
{
    // R0.8 optimization-validation dataset, now exercised against the
    // production implementations for both public scalar widths.
    verifyR08OptimizedMappings(4096);

    // R0.8 separate in-gamut dataset: both explicit mapping methods must take
    // the identity/fast path after ordinary target-space conversion.
    verifyR08InGamutFastPath(4096);
}


@safe pure nothrow @nogc unittest
{
    const inside = LinearSRgbd(0.2, 0.4, 0.6);
    const outside = LinearSRgbd(-0.2, 0.4, 1.3);

    assert(inside.inGamut);
    assert(inside.clip == inside);

    const clipped = outside.clip;
    assert(clipped == LinearSRgbd(0.0, 0.4, 1.0));
    assert(clipped.inGamut);
}
