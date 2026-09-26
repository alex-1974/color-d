module color.interpolate;

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

version (unittest)
{
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
}
