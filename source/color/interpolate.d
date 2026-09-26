module color.interpolate;

private import color.rgb :
    SRgb,
    LinearSRgb;

private import color.oklab :
    Oklab;

private T lerp(T)(
    T first,
    T second,
    T t
)
@safe pure nothrow @nogc
{
    return first + (second - first) * t;
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
        OklabHuef;

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

    // OKLCH belongs to the later polar/HuePath slice.
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
}
