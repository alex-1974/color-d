module color.interpolate;

private import color.alpha :
    Alpha;

private import color.rgb :
    SRgb,
    LinearSRgb;

private import color.oklab :
    Oklab;

private import color.oklch :
    OklabHue,
    Oklch;

/**
 * Hue trajectory used by polar OKLCH interpolation.
 *
 * The four policies correspond to the validated CSS-style angular paths.
 * Raw stored-hue interpolation is deliberately not represented by this enum.
 */
enum HuePath : ubyte
{
    shorter,
    longer,
    increasing,
    decreasing
}

private struct HueEndpoints(T)
if (is(T == float) || is(T == double))
{
    T first;
    T second;
}

private T lerp(T)(
    T first,
    T second,
    T t
)
@safe pure nothrow @nogc
{
    return first + (second - first) * t;
}

/*
 * Interpolate one alpha-weighted rectangular coordinate.
 *
 * This is interpolation-specific premultiplication. It deliberately does not
 * use the persistent Premultiplied!Color compositing representation.
 *
 * If interpolated alpha is exactly zero, the weighted coordinate is retained
 * without division. At zero alpha the straight coordinate is mathematically
 * powerless, so this provides the deterministic R0.7 representation without
 * introducing division by zero.
 */
private T interpolateAlphaCoordinate(T)(
    T firstCoordinate,
    T firstAlpha,
    T secondCoordinate,
    T secondAlpha,
    T t,
    T alpha
)
@safe pure nothrow @nogc
{
    T coordinate = lerp(
        firstCoordinate * firstAlpha,
        secondCoordinate * secondAlpha,
        t
    );

    if (alpha != cast(T)0)
        coordinate /= alpha;

    return coordinate;
}

private HueEndpoints!T adjustedHueEndpoints(T)(
    OklabHue!T first,
    OklabHue!T second,
    HuePath path
)
@safe pure nothrow @nogc
{
    T firstDegrees = first.positiveDegrees;
    T secondDegrees = second.positiveDegrees;

    const T delta =
        secondDegrees - firstDegrees;

    final switch (path)
    {
        case HuePath.shorter:
            if (delta > cast(T)180)
                firstDegrees += cast(T)360;
            else if (delta < cast(T)-180)
                secondDegrees += cast(T)360;
            break;

        case HuePath.longer:
            if (delta > cast(T)0 &&
                delta < cast(T)180)
            {
                firstDegrees += cast(T)360;
            }
            else if (delta > cast(T)-180 &&
                     delta <= cast(T)0)
            {
                secondDegrees += cast(T)360;
            }
            break;

        case HuePath.increasing:
            if (secondDegrees < firstDegrees)
                secondDegrees += cast(T)360;
            break;

        case HuePath.decreasing:
            if (firstDegrees < secondDegrees)
                firstDegrees += cast(T)360;
            break;
    }

    return HueEndpoints!T(
        firstDegrees,
        secondDegrees
    );
}

private OklabHue!T interpolateHue(T)(
    OklabHue!T first,
    OklabHue!T second,
    T t,
    HuePath path
)
@safe pure nothrow @nogc
{
    const adjusted =
        adjustedHueEndpoints(
            first,
            second,
            path
        );

    return OklabHue!T.fromDegrees(
        lerp(
            adjusted.first,
            adjusted.second,
            t
        )
    );
}

/**
 * Interpolate encoded sRGB component-wise in encoded-sRGB coordinates.
 *
 * Both endpoints remain in encoded nonlinear sRGB. No conversion to
 * linear-light RGB is performed.
 *
 * The interpolation factor is not clamped. Values outside `[0, 1]` therefore
 * perform mathematical extrapolation.
 *
 * The operation does not clip components, gamut-map the result, or otherwise
 * impose display policy.
 */
SRgb!T interpolate(T)(
    SRgb!T first,
    SRgb!T second,
    T t
)
@safe pure nothrow @nogc
{
    return SRgb!T(
        lerp(first.r, second.r, t),
        lerp(first.g, second.g, t),
        lerp(first.b, second.b, t)
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.rgb : SRgbf;

    const first = SRgbf(0.0f, 0.25f, 0.5f);
    const second = SRgbf(1.0f, 0.75f, 1.0f);

    const value = interpolate(first, second, 0.5f);

    assert(value == SRgbf(0.5f, 0.5f, 0.75f));
}

/**
 * Interpolate linear-light sRGB component-wise.
 *
 * Both endpoints remain in linear-light sRGB. The operation does not encode
 * or otherwise convert the supplied colors.
 *
 * The interpolation factor is not clamped. Values outside `[0, 1]` therefore
 * perform mathematical extrapolation.
 *
 * Extended-range linear RGB is preserved. No clipping or gamut mapping is
 * performed.
 */
LinearSRgb!T interpolate(T)(
    LinearSRgb!T first,
    LinearSRgb!T second,
    T t
)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        lerp(first.r, second.r, t),
        lerp(first.g, second.g, t),
        lerp(first.b, second.b, t)
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.rgb : LinearSRgbf;

    const first =
        LinearSRgbf(-0.25f, 0.25f, 1.25f);

    const second =
        LinearSRgbf(1.25f, 0.75f, -0.25f);

    const value = interpolate(first, second, 0.5f);

    assert(value == LinearSRgbf(0.5f, 0.5f, 0.5f));
}

/**
 * Interpolate Oklab component-wise in its rectangular coordinates.
 *
 * Lightness and both opponent coordinates are interpolated directly. No
 * conversion to or from OKLCH is performed and no hue-path policy is involved.
 *
 * The interpolation factor is not clamped. Values outside `[0, 1]` therefore
 * perform mathematical extrapolation.
 *
 * Components remain mathematical values; no clipping or gamut mapping is
 * performed.
 */
Oklab!T interpolate(T)(
    Oklab!T first,
    Oklab!T second,
    T t
)
@safe pure nothrow @nogc
{
    return Oklab!T(
        lerp(first.l, second.l, t),
        lerp(first.a, second.a, t),
        lerp(first.b, second.b, t)
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.oklab : Oklabf;

    const first =
        Oklabf(0.25f, -0.25f, 0.5f);

    const second =
        Oklabf(0.75f, 0.25f, -0.5f);

    const value = interpolate(first, second, 0.5f);

    assert(value == Oklabf(0.5f, 0.0f, 0.0f));
}

/**
 * Interpolate two OKLCH colors using an explicit polar hue path.
 *
 * Lightness and chroma are interpolated linearly. Hue follows the supplied
 * `HuePath`; no default hue policy is selected implicitly.
 *
 * Negative-chroma endpoints are first converted to their equivalent
 * non-negative-chroma representation for interpolation. Consequently,
 * `t == 0` or `t == 1` preserves the represented endpoint color but may
 * return its canonical equivalent rather than its raw negative-chroma
 * representation.
 *
 * Exact achromatic endpoints (`C == 0`) borrow the hue of the chromatic
 * endpoint when exactly one endpoint is achromatic. If both endpoints are
 * exactly achromatic, neither hue is borrowed: their stored numeric hues are
 * interpolated according to the explicitly selected `HuePath`. Hue remains
 * powerless to the represented color in that case, but its numeric value is
 * retained deterministically. No near-achromatic epsilon is applied.
 *
 * Hue-path selection operates on normalized hue directions, while the
 * interpolated result retains its raw angular trajectory. The result is not
 * automatically wrapped to `[0, 360)`.
 *
 * The interpolation factor is not clamped, so values outside `[0, 1]`
 * perform mathematical extrapolation.
 *
 * No color-space conversion, clipping, or gamut mapping is performed.
 */
Oklch!T interpolate(T)(
    Oklch!T first,
    Oklch!T second,
    T t,
    HuePath path
)
@safe pure nothrow @nogc
{
    first = first.canonicalized;
    second = second.canonicalized;

    OklabHue!T firstHue = first.h;
    OklabHue!T secondHue = second.h;

    if (first.c == cast(T)0 &&
        second.c != cast(T)0)
    {
        firstHue = secondHue;
    }
    else if (second.c == cast(T)0 &&
             first.c != cast(T)0)
    {
        secondHue = firstHue;
    }

    return Oklch!T(
        lerp(first.l, second.l, t),
        lerp(first.c, second.c, t),
        interpolateHue(
            firstHue,
            secondHue,
            t,
            path
        )
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.oklch :
        OklabHued,
        Oklchd;

    const first = Oklchd(
        0.25,
        0.125,
        OklabHued.fromDegrees(350.0)
    );

    const second = Oklchd(
        0.75,
        0.375,
        OklabHued.fromDegrees(10.0)
    );

    const value = interpolate(
        first,
        second,
        0.5,
        HuePath.shorter
    );

    assert(value.l == 0.5);
    assert(value.c == 0.25);
    assert(value.h.rawDegrees == 360.0);
}

/**
 * Alpha-aware interpolation in encoded sRGB.
 *
 * RGB coordinates are multiplied by their endpoint alpha values before
 * interpolation. The interpolated coordinates are divided by interpolated
 * alpha when that alpha is nonzero.
 *
 * This weighting occurs in encoded-sRGB coordinates. It is interpolation
 * mathematics, not linear-light Porter-Duff compositing, and it does not use
 * the persistent `Premultiplied!Color` representation.
 *
 * A fully transparent endpoint therefore cannot leak hidden encoded RGB into
 * a visible intermediate result. At interpolated alpha zero, division is
 * skipped and the interpolated weighted coordinates are retained
 * deterministically. Consequently hidden straight color is not generally
 * preserved at transparent endpoints, and raw endpoint identity is not
 * guaranteed for a fully transparent endpoint even at `t == 0` or `t == 1`.
 *
 * Neither `t` nor alpha is clamped or validated. No color-space conversion,
 * clipping, or gamut mapping is performed.
 */
Alpha!(SRgb!T) interpolate(T)(
    Alpha!(SRgb!T) first,
    Alpha!(SRgb!T) second,
    T t
)
@safe pure nothrow @nogc
{
    const T alpha =
        lerp(first.alpha, second.alpha, t);

    return Alpha!(SRgb!T)(
        SRgb!T(
            interpolateAlphaCoordinate(
                first.color.r,
                first.alpha,
                second.color.r,
                second.alpha,
                t,
                alpha
            ),
            interpolateAlphaCoordinate(
                first.color.g,
                first.alpha,
                second.color.g,
                second.alpha,
                t,
                alpha
            ),
            interpolateAlphaCoordinate(
                first.color.b,
                first.alpha,
                second.color.b,
                second.alpha,
                t,
                alpha
            )
        ),
        alpha
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.alpha : Alpha;
    import color.rgb : SRgbd;

    const value = interpolate(
        Alpha!SRgbd(
            SRgbd(1.0, 0.0, 0.0),
            1.0
        ),
        Alpha!SRgbd(
            SRgbd(0.0, 0.0, 1.0),
            0.0
        ),
        0.5
    );

    assert(value.color == SRgbd(1.0, 0.0, 0.0));
    assert(value.alpha == 0.5);
}

/**
 * Alpha-aware interpolation in linear-light sRGB.
 *
 * Linear RGB coordinates participate in interpolation-specific alpha
 * weighting. A transparent endpoint therefore cannot contribute hidden RGB to
 * a visible intermediate result.
 *
 * This operation returns straight `Alpha!(LinearSRgb!T)` and remains distinct
 * from the persistent `Premultiplied!(LinearSRgb!T)` representation used by
 * compositing.
 *
 * At interpolated alpha zero, division is skipped and the interpolated
 * alpha-weighted coordinates are retained. They are not reconstructed hidden
 * straight color. Consequently raw endpoint identity is not guaranteed for a
 * fully transparent endpoint even at `t == 0` or `t == 1`.
 *
 * Neither `t` nor alpha is clamped or validated. Extended-range coordinates
 * remain representable and no clipping or gamut mapping is performed.
 */
Alpha!(LinearSRgb!T) interpolate(T)(
    Alpha!(LinearSRgb!T) first,
    Alpha!(LinearSRgb!T) second,
    T t
)
@safe pure nothrow @nogc
{
    const T alpha =
        lerp(first.alpha, second.alpha, t);

    return Alpha!(LinearSRgb!T)(
        LinearSRgb!T(
            interpolateAlphaCoordinate(
                first.color.r,
                first.alpha,
                second.color.r,
                second.alpha,
                t,
                alpha
            ),
            interpolateAlphaCoordinate(
                first.color.g,
                first.alpha,
                second.color.g,
                second.alpha,
                t,
                alpha
            ),
            interpolateAlphaCoordinate(
                first.color.b,
                first.alpha,
                second.color.b,
                second.alpha,
                t,
                alpha
            )
        ),
        alpha
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.alpha : Alpha;
    import color.rgb : LinearSRgbd;

    const value = interpolate(
        Alpha!LinearSRgbd(
            LinearSRgbd(1.0, 0.0, 0.0),
            1.0
        ),
        Alpha!LinearSRgbd(
            LinearSRgbd(0.0, 0.0, 1.0),
            0.0
        ),
        0.5
    );

    assert(value.color == LinearSRgbd(1.0, 0.0, 0.0));
    assert(value.alpha == 0.5);
}

/**
 * Alpha-aware rectangular interpolation in Oklab.
 *
 * `L`, `a`, and `b` are multiplied by endpoint alpha before interpolation and
 * divided by interpolated alpha when that alpha is nonzero.
 *
 * The weighting is an internal interpolation step and does not imply
 * compositing semantics or a persistent premultiplied Oklab representation.
 *
 * At interpolated alpha zero, division is skipped and the alpha-weighted
 * coordinates are retained. Hidden straight Oklab coordinates are therefore
 * not reconstructed, and raw endpoint identity is not guaranteed for a fully
 * transparent endpoint even at `t == 0` or `t == 1`.
 *
 * Neither `t` nor alpha is clamped or validated, and no conversion, clipping,
 * or gamut mapping occurs.
 */
Alpha!(Oklab!T) interpolate(T)(
    Alpha!(Oklab!T) first,
    Alpha!(Oklab!T) second,
    T t
)
@safe pure nothrow @nogc
{
    const T alpha =
        lerp(first.alpha, second.alpha, t);

    return Alpha!(Oklab!T)(
        Oklab!T(
            interpolateAlphaCoordinate(
                first.color.l,
                first.alpha,
                second.color.l,
                second.alpha,
                t,
                alpha
            ),
            interpolateAlphaCoordinate(
                first.color.a,
                first.alpha,
                second.color.a,
                second.alpha,
                t,
                alpha
            ),
            interpolateAlphaCoordinate(
                first.color.b,
                first.alpha,
                second.color.b,
                second.alpha,
                t,
                alpha
            )
        ),
        alpha
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.alpha : Alpha;
    import color.oklab : Oklabd;

    const value = interpolate(
        Alpha!Oklabd(
            Oklabd(0.25, 0.5, -0.5),
            0.25
        ),
        Alpha!Oklabd(
            Oklabd(0.75, -0.5, 0.5),
            0.75
        ),
        0.5
    );

    assert(value.color == Oklabd(0.625, -0.25, 0.25));
    assert(value.alpha == 0.5);
}

/**
 * Alpha-aware polar interpolation in OKLCH.
 *
 * Endpoint colors are first canonicalized to non-negative chroma, matching the
 * non-alpha polar interpolation contract.
 *
 * `L` and `C` participate in interpolation-specific alpha weighting. Hue does
 * not: it remains an angular coordinate governed only by the explicit
 * `HuePath`.
 *
 * Therefore a transparent endpoint cannot leak hidden lightness or chroma into
 * a visible result, while its hue may still participate in the selected hue
 * trajectory. Hue is never numerically multiplied by alpha.
 *
 * Exact achromatic hue borrowing follows the ordinary OKLCH interpolation
 * semantics: when exactly one canonicalized endpoint has `C == 0`, its
 * interpolation hue is borrowed from the chromatic endpoint. No hidden
 * near-achromatic epsilon is applied.
 *
 * At interpolated alpha zero, `L` and `C` remain in their interpolated weighted
 * form rather than being divided by zero. Hidden straight `L` and `C` are not
 * reconstructed, so raw endpoint identity is not guaranteed for a fully
 * transparent endpoint even at `t == 0` or `t == 1`. Hue remains independently
 * interpolated.
 *
 * Neither `t` nor alpha is clamped or validated. No color-space conversion,
 * clipping, or gamut mapping is performed.
 */
Alpha!(Oklch!T) interpolate(T)(
    Alpha!(Oklch!T) first,
    Alpha!(Oklch!T) second,
    T t,
    HuePath path
)
@safe pure nothrow @nogc
{
    first.color = first.color.canonicalized;
    second.color = second.color.canonicalized;

    OklabHue!T firstHue = first.color.h;
    OklabHue!T secondHue = second.color.h;

    if (first.color.c == cast(T)0 &&
        second.color.c != cast(T)0)
    {
        firstHue = secondHue;
    }
    else if (second.color.c == cast(T)0 &&
             first.color.c != cast(T)0)
    {
        secondHue = firstHue;
    }

    const OklabHue!T hue =
        interpolateHue(
            firstHue,
            secondHue,
            t,
            path
        );

    const T alpha =
        lerp(first.alpha, second.alpha, t);

    return Alpha!(Oklch!T)(
        Oklch!T(
            interpolateAlphaCoordinate(
                first.color.l,
                first.alpha,
                second.color.l,
                second.alpha,
                t,
                alpha
            ),
            interpolateAlphaCoordinate(
                first.color.c,
                first.alpha,
                second.color.c,
                second.alpha,
                t,
                alpha
            ),
            hue
        ),
        alpha
    );
}

///
@safe pure nothrow @nogc unittest
{
    import color.alpha : Alpha;
    import color.oklch :
        OklabHued,
        Oklchd;

    const value = interpolate(
        Alpha!Oklchd(
            Oklchd(
                0.4,
                0.2,
                OklabHued.fromDegrees(30.0)
            ),
            0.0
        ),
        Alpha!Oklchd(
            Oklchd(
                0.8,
                0.2,
                OklabHued.fromDegrees(210.0)
            ),
            1.0
        ),
        0.5,
        HuePath.shorter
    );

    assert(value.color.l == 0.8);
    assert(value.color.c == 0.2);
    assert(value.color.h.rawDegrees == 120.0);
    assert(value.alpha == 0.5);
}

version (unittest)
{
    private import color.alpha :
        Premultiplied;

    private import color.rgb :
        SRgbf,
        SRgbd,
        LinearSRgbf,
        LinearSRgbd;

    private import color.xyz :
        XyzD65f;

    private import color.oklab :
        Oklabf,
        Oklabd;

    private import color.oklch :
        Oklchf,
        Oklchd,
        OklabHuef,
        OklabHued;

    // Low-level interpolation never converts between color spaces.
    static assert(!__traits(compiles,
        interpolate(
            SRgbf(0, 0, 0),
            LinearSRgbf(1, 1, 1),
            0.5f
        )
    ));

    static assert(!__traits(compiles,
        interpolate(
            Oklabf(0.5f, 0, 0),
            LinearSRgbf(0.5f, 0, 0),
            0.5f
        )
    ));

    // OKLCH requires an explicit hue-path policy.
    static assert(!__traits(compiles,
        interpolate(
            Oklchf(
                0.5f,
                0.2f,
                OklabHuef.fromDegrees(30.0f)
            ),
            Oklchf(
                0.7f,
                0.1f,
                OklabHuef.fromDegrees(60.0f)
            ),
            0.5f
        )
    ));

    // XYZ interpolation was not part of the validated R0.7 rectangular set.
    static assert(!__traits(compiles,
        interpolate(
            XyzD65f(0.1f, 0.2f, 0.3f),
            XyzD65f(0.4f, 0.5f, 0.6f),
            0.5f
        )
    ));

    // Matching color operands must also use the same scalar type.
    static assert(!__traits(compiles,
        interpolate(
            SRgbf(0, 0, 0),
            SRgbd(1, 1, 1),
            0.5
        )
    ));

    // CTFE endpoint and identity properties.
    enum linearFirst =
        LinearSRgbd(0.0, 0.25, 0.5);

    enum linearSecond =
        LinearSRgbd(1.0, 0.75, 1.0);

    static assert(
        interpolate(
            linearFirst,
            linearSecond,
            0.0
        ) == linearFirst
    );

    static assert(
        interpolate(
            linearFirst,
            linearSecond,
            1.0
        ) == linearSecond
    );

    static assert(
        interpolate(
            linearFirst,
            linearFirst,
            0.375
        ) == linearFirst
    );

    // The low-level factor is deliberately unclamped.
    enum zero =
        LinearSRgbd(0, 0, 0);

    enum one =
        LinearSRgbd(1, 1, 1);

    static assert(
        interpolate(zero, one, -0.25) ==
        LinearSRgbd(-0.25, -0.25, -0.25)
    );

    static assert(
        interpolate(zero, one, 1.25) ==
        LinearSRgbd(1.25, 1.25, 1.25)
    );

    // Extended-range values survive interpolation without clipping.
    enum extendedFirst =
        LinearSRgbd(-0.25, 0.25, 1.25);

    enum extendedSecond =
        LinearSRgbd(1.25, 0.75, -0.25);

    enum extendedMidpoint =
        interpolate(
            extendedFirst,
            extendedSecond,
            0.5
        );

    static assert(
        extendedMidpoint ==
        LinearSRgbd(0.5, 0.5, 0.5)
    );

    // Encoded sRGB remains encoded-space interpolation.
    enum encodedMidpoint =
        interpolate(
            SRgbd(0.0, 0.25, 0.5),
            SRgbd(1.0, 0.75, 1.0),
            0.5
        );

    static assert(
        encodedMidpoint ==
        SRgbd(0.5, 0.5, 0.75)
    );

    // Oklab is rectangular and requires no hue policy.
    enum labMidpoint =
        interpolate(
            Oklabd(0.25, -0.25, 0.5),
            Oklabd(0.75, 0.25, -0.5),
            0.5
        );

    static assert(
        labMidpoint ==
        Oklabd(0.5, 0.0, 0.0)
    );

    // Exercise the float path at CTFE as well.
    enum floatMidpoint =
        interpolate(
            LinearSRgbf(0.0f, 0.25f, 0.5f),
            LinearSRgbf(1.0f, 0.75f, 1.0f),
            0.5f
        );

    static assert(
        floatMidpoint ==
        LinearSRgbf(0.5f, 0.5f, 0.75f)
    );

    // Polar interpolation requires matching scalar types.
    static assert(!__traits(compiles,
        interpolate(
            Oklchf(
                0.5f,
                0.25f,
                OklabHuef.fromDegrees(350.0f)
            ),
            Oklchd(
                0.5,
                0.25,
                OklabHued.fromDegrees(10.0)
            ),
            0.5,
            HuePath.shorter
        )
    ));

    enum hue350 = Oklchd(
        0.5,
        0.25,
        OklabHued.fromDegrees(350.0)
    );

    enum hue10 = Oklchd(
        0.5,
        0.25,
        OklabHued.fromDegrees(10.0)
    );

    // CSS-style path selection across the 0-degree boundary.
    static assert(
        interpolate(
            hue350,
            hue10,
            0.5,
            HuePath.shorter
        ).h.rawDegrees == 360.0
    );

    static assert(
        interpolate(
            hue350,
            hue10,
            0.5,
            HuePath.longer
        ).h.rawDegrees == 180.0
    );

    static assert(
        interpolate(
            hue350,
            hue10,
            0.5,
            HuePath.increasing
        ).h.rawDegrees == 360.0
    );

    static assert(
        interpolate(
            hue350,
            hue10,
            0.5,
            HuePath.decreasing
        ).h.rawDegrees == 180.0
    );

    // Equal normalized directions remain path-dependent.
    enum hue30 = Oklchd(
        0.5,
        0.25,
        OklabHued.fromDegrees(30.0)
    );

    enum hue390 = Oklchd(
        0.5,
        0.25,
        OklabHued.fromDegrees(390.0)
    );

    // Directional policies cover the complementary 300-degree routes.
    enum hue90 = Oklchd(
        0.5,
        0.25,
        OklabHued.fromDegrees(90.0)
    );

    static assert(
        interpolate(
            hue90,
            hue30,
            0.5,
            HuePath.increasing
        ).h.rawDegrees == 240.0
    );

    static assert(
        interpolate(
            hue30,
            hue90,
            0.5,
            HuePath.decreasing
        ).h.rawDegrees == 240.0
    );

    static assert(
        interpolate(
            hue30,
            hue390,
            0.5,
            HuePath.shorter
        ).h.rawDegrees == 30.0
    );

    static assert(
        interpolate(
            hue30,
            hue390,
            0.5,
            HuePath.longer
        ).h.rawDegrees == 210.0
    );

    static assert(
        interpolate(
            hue30,
            hue390,
            0.5,
            HuePath.increasing
        ).h.rawDegrees == 30.0
    );

    static assert(
        interpolate(
            hue30,
            hue390,
            0.5,
            HuePath.decreasing
        ).h.rawDegrees == 30.0
    );

    // Exact 180-degree ties are deterministic in both endpoint orders.
    enum hue210 = Oklchd(
        0.5,
        0.25,
        OklabHued.fromDegrees(210.0)
    );

    static assert(
        interpolate(
            hue30,
            hue210,
            0.5,
            HuePath.shorter
        ).h.rawDegrees == 120.0
    );

    static assert(
        interpolate(
            hue30,
            hue210,
            0.5,
            HuePath.longer
        ).h.rawDegrees == 120.0
    );

    static assert(
        interpolate(
            hue210,
            hue30,
            0.5,
            HuePath.shorter
        ).h.rawDegrees == 120.0
    );

    static assert(
        interpolate(
            hue210,
            hue30,
            0.5,
            HuePath.longer
        ).h.rawDegrees == 120.0
    );

    // An exact achromatic endpoint borrows the chromatic endpoint hue.
    enum achromaticFirst = interpolate(
        Oklchd(
            0.25,
            0.0,
            OklabHued.fromDegrees(10.0)
        ),
        Oklchd(
            0.75,
            0.25,
            OklabHued.fromDegrees(200.0)
        ),
        0.5,
        HuePath.shorter
    );

    static assert(
        achromaticFirst.h.rawDegrees == 200.0
    );

    enum achromaticSecond = interpolate(
        Oklchd(
            0.25,
            0.25,
            OklabHued.fromDegrees(200.0)
        ),
        Oklchd(
            0.75,
            0.0,
            OklabHued.fromDegrees(10.0)
        ),
        0.5,
        HuePath.shorter
    );

    static assert(
        achromaticSecond.h.rawDegrees == 200.0
    );

    // With two exactly achromatic endpoints, neither stored hue is borrowed.
    // The explicitly selected path still determines the numeric hue result.
    enum bothAchromatic = interpolate(
        Oklchd(
            0.25,
            0.0,
            OklabHued.fromDegrees(350.0)
        ),
        Oklchd(
            0.75,
            0.0,
            OklabHued.fromDegrees(10.0)
        ),
        0.5,
        HuePath.shorter
    );

    static assert(bothAchromatic.c == 0.0);
    static assert(
        bothAchromatic.h.rawDegrees == 360.0
    );

    // Near-zero chroma is not silently classified as achromatic.
    enum nearAchromatic = interpolate(
        Oklchd(
            0.25,
            1e-12,
            OklabHued.fromDegrees(10.0)
        ),
        Oklchd(
            0.75,
            0.25,
            OklabHued.fromDegrees(200.0)
        ),
        0.5,
        HuePath.shorter
    );

    static assert(
        nearAchromatic.h.rawDegrees == 285.0
    );

    // Equivalent negative-chroma input is canonicalized for the polar path.
    enum negativeChroma = interpolate(
        Oklchd(
            0.5,
            -0.25,
            OklabHued.fromDegrees(30.0)
        ),
        Oklchd(
            0.5,
            0.25,
            OklabHued.fromDegrees(210.0)
        ),
        0.5,
        HuePath.shorter
    );

    static assert(negativeChroma.c == 0.25);
    static assert(
        negativeChroma.h.rawDegrees == 210.0
    );

    // Polar interpolation preserves the general unclamped-t policy.
    static assert(
        interpolate(
            hue350,
            hue10,
            1.5,
            HuePath.shorter
        ).h.rawDegrees == 380.0
    );

    // Exercise the float polar path during CTFE.
    enum floatPolar = interpolate(
        Oklchf(
            0.5f,
            0.25f,
            OklabHuef.fromDegrees(350.0f)
        ),
        Oklchf(
            0.5f,
            0.25f,
            OklabHuef.fromDegrees(10.0f)
        ),
        0.5f,
        HuePath.shorter
    );

    static assert(
        floatPolar.h.rawDegrees == 360.0f
    );

    // Alpha-aware interpolation remains restricted to the R0.7-validated
    // interpolation spaces.
    static assert(!__traits(compiles,
        interpolate(
            Alpha!XyzD65f(
                XyzD65f(0.1f, 0.2f, 0.3f),
                0.5f
            ),
            Alpha!XyzD65f(
                XyzD65f(0.4f, 0.5f, 0.6f),
                0.5f
            ),
            0.5f
        )
    ));

    // Alpha-wrapped endpoints still may not silently cross color spaces.
    static assert(!__traits(compiles,
        interpolate(
            Alpha!SRgbf(
                SRgbf(1, 0, 0),
                1
            ),
            Alpha!LinearSRgbf(
                LinearSRgbf(0, 0, 1),
                1
            ),
            0.5f
        )
    ));

    // Scalar types must match across both endpoints and the factor.
    static assert(!__traits(compiles,
        interpolate(
            Alpha!LinearSRgbf(
                LinearSRgbf(1, 0, 0),
                1
            ),
            Alpha!LinearSRgbd(
                LinearSRgbd(0, 0, 1),
                1
            ),
            0.5
        )
    ));

    // Alpha-aware OKLCH retains the explicit HuePath requirement.
    static assert(!__traits(compiles,
        interpolate(
            Alpha!Oklchd(
                Oklchd(
                    0.5,
                    0.2,
                    OklabHued.fromDegrees(30.0)
                ),
                1.0
            ),
            Alpha!Oklchd(
                Oklchd(
                    0.5,
                    0.2,
                    OklabHued.fromDegrees(90.0)
                ),
                1.0
            ),
            0.5
        )
    ));

    // Persistent compositing-premultiplied values are not interpolation input.
    static assert(!__traits(compiles,
        interpolate(
            Premultiplied!LinearSRgbd(
                LinearSRgbd(0.5, 0, 0),
                0.5
            ),
            Premultiplied!LinearSRgbd(
                LinearSRgbd(0, 0, 0.5),
                0.5
            ),
            0.5
        )
    ));

    // Opaque red -> transparent blue: hidden transparent blue must not leak.
    enum alphaOpaqueRed = Alpha!LinearSRgbd(
        LinearSRgbd(1, 0, 0),
        1
    );

    enum alphaTransparentBlue = Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 1),
        0
    );

    enum alphaRedBlueMid = interpolate(
        alphaOpaqueRed,
        alphaTransparentBlue,
        0.5
    );

    static assert(
        alphaRedBlueMid ==
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            0.5
        )
    );

    // Reverse direction gives the corresponding visible blue contribution.
    enum alphaTransparentRed = Alpha!LinearSRgbd(
        LinearSRgbd(1, 0, 0),
        0
    );

    enum alphaOpaqueBlue = Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 1),
        1
    );

    enum alphaReverseMid = interpolate(
        alphaTransparentRed,
        alphaOpaqueBlue,
        0.5
    );

    static assert(
        alphaReverseMid ==
        Alpha!LinearSRgbd(
            LinearSRgbd(0, 0, 1),
            0.5
        )
    );

    // General fractional-alpha weighting.
    enum alphaFractional = interpolate(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            0.25
        ),
        Alpha!LinearSRgbd(
            LinearSRgbd(0, 0, 1),
            0.75
        ),
        0.5
    );

    static assert(
        alphaFractional ==
        Alpha!LinearSRgbd(
            LinearSRgbd(0.25, 0, 0.75),
            0.5
        )
    );

    // The same alpha weighting applies in encoded sRGB coordinates.
    enum alphaEncoded = interpolate(
        Alpha!SRgbd(
            SRgbd(1, 0, 0),
            0.25
        ),
        Alpha!SRgbd(
            SRgbd(0, 0, 1),
            0.75
        ),
        0.5
    );

    static assert(
        alphaEncoded ==
        Alpha!SRgbd(
            SRgbd(0.25, 0, 0.75),
            0.5
        )
    );

    // All rectangular coordinates participate in Oklab weighting.
    enum alphaLab = interpolate(
        Alpha!Oklabd(
            Oklabd(0.25, 0.5, -0.5),
            0.25
        ),
        Alpha!Oklabd(
            Oklabd(0.75, -0.5, 0.5),
            0.75
        ),
        0.5
    );

    static assert(
        alphaLab ==
        Alpha!Oklabd(
            Oklabd(0.625, -0.25, 0.25),
            0.5
        )
    );

    // With both endpoint alphas at zero, hidden rectangular color collapses.
    enum alphaZeroRect = interpolate(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 2, 3),
            0
        ),
        Alpha!LinearSRgbd(
            LinearSRgbd(-1, -2, -3),
            0
        ),
        0.5
    );

    static assert(
        alphaZeroRect ==
        Alpha!LinearSRgbd(
            LinearSRgbd(0, 0, 0),
            0
        )
    );

    // Alpha-aware interpolation does not preserve hidden straight color at a
    // fully transparent endpoint, even when t selects that endpoint exactly.
    enum alphaTransparentEndpoint = interpolate(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 2, 3),
            0
        ),
        Alpha!LinearSRgbd(
            LinearSRgbd(4, 5, 6),
            1
        ),
        0.0
    );

    static assert(
        alphaTransparentEndpoint ==
        Alpha!LinearSRgbd(
            LinearSRgbd(0, 0, 0),
            0
        )
    );

    // If unclamped extrapolation lands exactly at alpha zero, division is
    // still skipped and the weighted coordinates remain deterministic.
    enum alphaExtrapolatedZero = interpolate(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            0.25
        ),
        Alpha!LinearSRgbd(
            LinearSRgbd(0, 0, 1),
            0.75
        ),
        -0.5
    );

    static assert(alphaExtrapolatedZero.alpha == 0);
    static assert(
        alphaExtrapolatedZero.color ==
        LinearSRgbd(0.375, 0, -0.375)
    );

    // Neither t nor alpha is silently clamped.
    enum alphaExtended = interpolate(
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            0.25
        ),
        Alpha!LinearSRgbd(
            LinearSRgbd(1, 0, 0),
            0.75
        ),
        2.0
    );

    static assert(alphaExtended.alpha == 1.25);
    static assert(alphaExtended.color == LinearSRgbd(1, 0, 0));
    static assert(!alphaExtended.isValidAlpha);

    // Polar alpha weighting applies only to L and C. Hue remains angular.
    enum alphaPolarMid = interpolate(
        Alpha!Oklchd(
            Oklchd(
                0.4,
                0.2,
                OklabHued.fromDegrees(30.0)
            ),
            0
        ),
        Alpha!Oklchd(
            Oklchd(
                0.8,
                0.2,
                OklabHued.fromDegrees(210.0)
            ),
            1
        ),
        0.5,
        HuePath.shorter
    );

    static assert(alphaPolarMid.alpha == 0.5);
    static assert(alphaPolarMid.color.l == 0.8);
    static assert(alphaPolarMid.color.c == 0.2);
    static assert(
        alphaPolarMid.color.h.rawDegrees == 120.0
    );

    // At zero alpha, L and C remain weighted while hue remains independently
    // interpolated.
    enum alphaZeroPolar = interpolate(
        Alpha!Oklchd(
            Oklchd(
                0.4,
                0.2,
                OklabHued.fromDegrees(30.0)
            ),
            0
        ),
        Alpha!Oklchd(
            Oklchd(
                0.8,
                0.3,
                OklabHued.fromDegrees(90.0)
            ),
            0
        ),
        0.5,
        HuePath.shorter
    );

    static assert(alphaZeroPolar.alpha == 0);
    static assert(alphaZeroPolar.color.l == 0);
    static assert(alphaZeroPolar.color.c == 0);
    static assert(
        alphaZeroPolar.color.h.rawDegrees == 60.0
    );

    // At a transparent polar endpoint, hidden L/C collapse through
    // interpolation weighting while hue remains an independent angle.
    enum alphaTransparentPolarEndpoint = interpolate(
        Alpha!Oklchd(
            Oklchd(
                0.4,
                0.2,
                OklabHued.fromDegrees(30.0)
            ),
            0
        ),
        Alpha!Oklchd(
            Oklchd(
                0.8,
                0.3,
                OklabHued.fromDegrees(90.0)
            ),
            1
        ),
        0.0,
        HuePath.shorter
    );

    static assert(alphaTransparentPolarEndpoint.alpha == 0);
    static assert(alphaTransparentPolarEndpoint.color.l == 0);
    static assert(alphaTransparentPolarEndpoint.color.c == 0);
    static assert(
        alphaTransparentPolarEndpoint.color.h.rawDegrees == 30.0
    );

    // Exact achromatic hue borrowing remains part of alpha-aware polar
    // interpolation as well.
    enum alphaAchromatic = interpolate(
        Alpha!Oklchd(
            Oklchd(
                0.4,
                0,
                OklabHued.fromDegrees(10.0)
            ),
            1
        ),
        Alpha!Oklchd(
            Oklchd(
                0.8,
                0.2,
                OklabHued.fromDegrees(200.0)
            ),
            1
        ),
        0.5,
        HuePath.shorter
    );

    static assert(
        alphaAchromatic.color.h.rawDegrees == 200.0
    );

    // With two exactly achromatic endpoints, neither hue is borrowed.
    enum alphaBothAchromatic = interpolate(
        Alpha!Oklchd(
            Oklchd(
                0.4,
                0,
                OklabHued.fromDegrees(350.0)
            ),
            1
        ),
        Alpha!Oklchd(
            Oklchd(
                0.8,
                0,
                OklabHued.fromDegrees(10.0)
            ),
            1
        ),
        0.5,
        HuePath.shorter
    );

    static assert(alphaBothAchromatic.color.c == 0);
    static assert(
        alphaBothAchromatic.color.h.rawDegrees == 360.0
    );

    // Near-zero chroma is not silently classified as exactly achromatic.
    enum alphaNearAchromatic = interpolate(
        Alpha!Oklchd(
            Oklchd(
                0.4,
                1e-12,
                OklabHued.fromDegrees(10.0)
            ),
            1
        ),
        Alpha!Oklchd(
            Oklchd(
                0.8,
                0.2,
                OklabHued.fromDegrees(200.0)
            ),
            1
        ),
        0.5,
        HuePath.shorter
    );

    static assert(
        alphaNearAchromatic.color.h.rawDegrees == 285.0
    );

    // Negative chroma is canonicalized before polar alpha interpolation.
    enum alphaNegativeChroma = interpolate(
        Alpha!Oklchd(
            Oklchd(
                0.5,
                -0.25,
                OklabHued.fromDegrees(30.0)
            ),
            0.5
        ),
        Alpha!Oklchd(
            Oklchd(
                0.5,
                0.25,
                OklabHued.fromDegrees(210.0)
            ),
            0.5
        ),
        0.5,
        HuePath.shorter
    );

    static assert(alphaNegativeChroma.color.c == 0.25);
    static assert(
        alphaNegativeChroma.color.h.rawDegrees == 210.0
    );

    // Exercise alpha-aware float interpolation during CTFE.
    enum alphaFloat = interpolate(
        Alpha!Oklchf(
            Oklchf(
                0.5f,
                0.25f,
                OklabHuef.fromDegrees(350.0f)
            ),
            0.0f
        ),
        Alpha!Oklchf(
            Oklchf(
                0.5f,
                0.25f,
                OklabHuef.fromDegrees(10.0f)
            ),
            1.0f
        ),
        0.5f,
        HuePath.shorter
    );

    static assert(alphaFloat.alpha == 0.5f);
    static assert(alphaFloat.color.l == 0.5f);
    static assert(alphaFloat.color.c == 0.25f);
    static assert(
        alphaFloat.color.h.rawDegrees == 360.0f
    );
}
