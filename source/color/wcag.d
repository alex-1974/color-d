module color.wcag;

private import color.rgb :
    SRgb,
    LinearSRgb,
    toLinear;


/**
 * Result of a standards-facing WCAG 2 measurement.
 *
 * The representation occupies exactly one scalar value.
 *
 * A finite scalar represents a valid measurement. NaN represents invalid
 * input. Callers can therefore inspect `valid` without a separate status field,
 * while ignoring validity cannot turn invalid input into an ordinary plausible
 * measurement.
 *
 * Construction is intentionally controlled by this module. WCAG measurement
 * functions validate their input domain before creating a valid result.
 *
 * The natural floating-point `.init` state is NaN and is therefore invalid.
 */
struct Wcag2Measurement(T)
if (is(T == float) || is(T == double))
{
    /// Scalar type used by the measurement.
    alias Scalar = T;

    private T _value;

    /*
     * Suppress D's compiler-generated positional struct constructor.
     *
     * Module-private construction ensures that ordinary external consumers
     * cannot manufacture arbitrary supposedly valid WCAG measurements.
     * Production values are created only by color.wcag after domain
     * validation.
     */
    private this(T value)
    @safe pure nothrow @nogc
    {
        _value = value;
    }

    /// Measurement value. Invalid measurements return NaN here.
    @property T value() const
    @safe pure nothrow @nogc
    {
        return _value;
    }

    /// Whether this object contains a valid WCAG 2 measurement.
    @property bool valid() const
    @safe pure nothrow @nogc
    {
        return _value == _value;
    }
}


private Wcag2Measurement!T makeWcag2Measurement(T)(T value)
@safe pure nothrow @nogc
{
    return Wcag2Measurement!T(value);
}


private bool isWcag2Component(T)(T value)
@safe pure nothrow @nogc
{
    // Ordered comparison rejects NaN and both infinities as well as finite
    // values outside the normalized WCAG sRGB domain.
    return
        value >= cast(T)0 &&
        value <= cast(T)1;
}


private bool isWcag2Domain(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return
        isWcag2Component(color.r) &&
        isWcag2Component(color.g) &&
        isWcag2Component(color.b);
}


private bool isWcag2Domain(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return
        isWcag2Component(color.r) &&
        isWcag2Component(color.g) &&
        isWcag2Component(color.b);
}


private T relativeLuminanceUnchecked(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    // WCAG 2 deliberately uses its published coefficients rather than the
    // higher-precision XYZ-D65 Y-row coefficients used by colorimetric
    // conversion.
    return
        cast(T)0.2126 * color.r +
        cast(T)0.7152 * color.g +
        cast(T)0.0722 * color.b;
}


private T relativeLuminanceUnchecked(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return relativeLuminanceUnchecked(
        color.toLinear
    );
}


private T contrastFromLuminance(T)(T first, T second)
@safe pure nothrow @nogc
{
    const bool firstIsLighter =
        first >= second;

    const T lighter =
        firstIsLighter ? first : second;

    const T darker =
        firstIsLighter ? second : first;

    return
        (lighter + cast(T)0.05) /
        (darker  + cast(T)0.05);
}


/**
 * Measure WCAG 2 relative luminance from encoded sRGB.
 *
 * The input must contain finite normalized sRGB components in `[0, 1]`.
 * Invalid input produces an invalid `Wcag2Measurement` whose value is NaN.
 *
 * No clipping or gamut mapping is performed.
 *
 * This is the WCAG 2 standards-specific relative-luminance measurement. It is
 * deliberately distinct from the CIE XYZ-D65 Y coordinate.
 *
 * Alpha-bearing input is not accepted. Rendering/compositing must be resolved
 * explicitly before measurement.
 */
Wcag2Measurement!T wcag2RelativeLuminance(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    if (!isWcag2Domain(color))
        return makeWcag2Measurement(T.nan);

    return makeWcag2Measurement(
        relativeLuminanceUnchecked(color)
    );
}


/**
 * Measure WCAG 2 relative luminance from already-decoded linear-light sRGB.
 *
 * Components must be finite and in `[0, 1]`. This overload represents the
 * same WCAG sRGB measurement after the transfer-function decoding step has
 * already been performed explicitly.
 *
 * Invalid input produces an invalid `Wcag2Measurement`.
 *
 * No clipping, gamut mapping or alpha resolution is performed.
 */
Wcag2Measurement!T wcag2RelativeLuminance(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    if (!isWcag2Domain(color))
        return makeWcag2Measurement(T.nan);

    return makeWcag2Measurement(
        relativeLuminanceUnchecked(color)
    );
}


/**
 * Measure the WCAG 2 contrast ratio between two encoded-sRGB colors.
 *
 * Both operands must contain finite normalized components in `[0, 1]`.
 * Invalid input produces an invalid `Wcag2Measurement`.
 *
 * The operation performs no clipping, gamut mapping, alpha compositing or
 * accessibility-threshold classification.
 */
Wcag2Measurement!T wcag2ContrastRatio(T)(
    SRgb!T first,
    SRgb!T second
)
@safe pure nothrow @nogc
{
    if (
        !isWcag2Domain(first) ||
        !isWcag2Domain(second)
    )
    {
        return makeWcag2Measurement(T.nan);
    }

    return makeWcag2Measurement(
        contrastFromLuminance(
            relativeLuminanceUnchecked(first),
            relativeLuminanceUnchecked(second)
        )
    );
}


/**
 * Measure the WCAG 2 contrast ratio between two already-decoded linear-light
 * sRGB colors.
 *
 * Both operands must contain finite components in `[0, 1]`.
 *
 * Invalid input produces an invalid `Wcag2Measurement`. No hidden conversion,
 * clipping, gamut mapping, alpha compositing or threshold policy is applied.
 */
Wcag2Measurement!T wcag2ContrastRatio(T)(
    LinearSRgb!T first,
    LinearSRgb!T second
)
@safe pure nothrow @nogc
{
    if (
        !isWcag2Domain(first) ||
        !isWcag2Domain(second)
    )
    {
        return makeWcag2Measurement(T.nan);
    }

    return makeWcag2Measurement(
        contrastFromLuminance(
            relativeLuminanceUnchecked(first),
            relativeLuminanceUnchecked(second)
        )
    );
}


///
@safe pure nothrow @nogc unittest
{
    import color.rgb : SRgbd;

    const black =
        wcag2RelativeLuminance(
            SRgbd(0, 0, 0)
        );

    const white =
        wcag2RelativeLuminance(
            SRgbd(1, 1, 1)
        );

    const contrast =
        wcag2ContrastRatio(
            SRgbd(0, 0, 0),
            SRgbd(1, 1, 1)
        );

    assert(black.valid);
    assert(black.value == 0);

    assert(white.valid);
    assert(white.value == 1);

    assert(contrast.valid);
    assert(
        contrast.value > 20.999999 &&
        contrast.value < 21.000001
    );
}


version (unittest)
{
    private import color.alpha :
        Alpha;

    private import color.oklab :
        Oklabd;

    private import color.rgb :
        SRgbf,
        SRgbd,
        LinearSRgbf,
        LinearSRgbd;

    private import color.xyz :
        XyzD65d,
        toXyzD65;

    private import std.math :
        pow;


    static assert(
        Wcag2Measurement!float.sizeof ==
        float.sizeof
    );

    static assert(
        Wcag2Measurement!double.sizeof ==
        double.sizeof
    );


    // Natural .init is deliberately invalid.
    enum initD =
        Wcag2Measurement!double.init;

    static assert(!initD.valid);
    static assert(initD.value != initD.value);


    // CTFE reference invariants.
    enum blackD =
        wcag2RelativeLuminance(
            SRgbd(0, 0, 0)
        );

    enum whiteD =
        wcag2RelativeLuminance(
            SRgbd(1, 1, 1)
        );

    static assert(blackD.valid);
    static assert(blackD.value == 0);

    static assert(whiteD.valid);
    static assert(whiteD.value == 1);


    enum redLinearD =
        wcag2RelativeLuminance(
            LinearSRgbd(1, 0, 0)
        );

    enum greenLinearD =
        wcag2RelativeLuminance(
            LinearSRgbd(0, 1, 0)
        );

    enum blueLinearD =
        wcag2RelativeLuminance(
            LinearSRgbd(0, 0, 1)
        );

    static assert(redLinearD.valid);
    static assert(greenLinearD.valid);
    static assert(blueLinearD.valid);

    static assert(redLinearD.value == 0.2126);
    static assert(greenLinearD.value == 0.7152);
    static assert(blueLinearD.value == 0.0722);


    enum blackWhiteD =
        wcag2ContrastRatio(
            SRgbd(0, 0, 0),
            SRgbd(1, 1, 1)
        );

    static assert(blackWhiteD.valid);

    static assert(
        blackWhiteD.value > 20.999999999 &&
        blackWhiteD.value < 21.000000001
    );


    // Contrast is symmetric and equal colors have ratio 1.
    enum sameD =
        wcag2ContrastRatio(
            SRgbd(0.25, 0.5, 0.75),
            SRgbd(0.25, 0.5, 0.75)
        );

    enum orderAB =
        wcag2ContrastRatio(
            SRgbd(0.1, 0.2, 0.3),
            SRgbd(0.7, 0.8, 0.9)
        );

    enum orderBA =
        wcag2ContrastRatio(
            SRgbd(0.7, 0.8, 0.9),
            SRgbd(0.1, 0.2, 0.3)
        );

    static assert(sameD.valid);
    static assert(sameD.value == 1);

    static assert(orderAB.valid);
    static assert(orderBA.valid);
    static assert(orderAB.value == orderBA.value);


    // Invalid finite domain.
    enum belowD =
        wcag2RelativeLuminance(
            SRgbd(-0.0001, 0.5, 0.5)
        );

    enum aboveD =
        wcag2RelativeLuminance(
            SRgbd(1.0001, 0.5, 0.5)
        );

    static assert(!belowD.valid);
    static assert(belowD.value != belowD.value);

    static assert(!aboveD.valid);
    static assert(aboveD.value != aboveD.value);


    // Non-finite encoded domain.
    enum nanD =
        wcag2RelativeLuminance(
            SRgbd(double.nan, 0.5, 0.5)
        );

    enum posInfD =
        wcag2RelativeLuminance(
            SRgbd(double.infinity, 0.5, 0.5)
        );

    enum negInfD =
        wcag2RelativeLuminance(
            SRgbd(-double.infinity, 0.5, 0.5)
        );

    static assert(!nanD.valid);
    static assert(!posInfD.valid);
    static assert(!negInfD.valid);


    // Linear-light input has the same strict normalized domain.
    enum belowLinearD =
        wcag2RelativeLuminance(
            LinearSRgbd(-0.0001, 0.5, 0.5)
        );

    enum aboveLinearD =
        wcag2RelativeLuminance(
            LinearSRgbd(1.0001, 0.5, 0.5)
        );

    enum nanLinearD =
        wcag2RelativeLuminance(
            LinearSRgbd(double.nan, 0.5, 0.5)
        );

    enum posInfLinearD =
        wcag2RelativeLuminance(
            LinearSRgbd(double.infinity, 0.5, 0.5)
        );

    enum negInfLinearD =
        wcag2RelativeLuminance(
            LinearSRgbd(-double.infinity, 0.5, 0.5)
        );

    static assert(!belowLinearD.valid);
    static assert(!aboveLinearD.valid);
    static assert(!nanLinearD.valid);
    static assert(!posInfLinearD.valid);
    static assert(!negInfLinearD.valid);


    // Invalid contrast input invalidates the whole measurement.
    enum invalidContrastD =
        wcag2ContrastRatio(
            SRgbd(0, 0, 0),
            SRgbd(1.01, 1, 1)
        );

    static assert(!invalidContrastD.valid);


    // Scalar and color-space boundaries.
    static assert(!__traits(compiles,
        wcag2ContrastRatio(
            SRgbf(0, 0, 0),
            SRgbd(1, 1, 1)
        )
    ));

    static assert(!__traits(compiles,
        wcag2ContrastRatio(
            SRgbd(0, 0, 0),
            LinearSRgbd(1, 1, 1)
        )
    ));

    static assert(!__traits(compiles,
        wcag2RelativeLuminance(
            Oklabd(0, 0, 0)
        )
    ));

    static assert(!__traits(compiles,
        wcag2RelativeLuminance(
            XyzD65d(0, 0, 0)
        )
    ));

    static assert(!__traits(compiles,
        wcag2RelativeLuminance(
            Alpha!SRgbd(
                SRgbd(0, 0, 0),
                1
            )
        )
    ));


    private T referenceDecode(T)(T encoded)
    @safe pure nothrow @nogc
    {
        if (encoded <= cast(T)0.04045)
            return encoded / cast(T)12.92;

        return cast(T)pow(
            (encoded + cast(T)0.055) /
                cast(T)1.055,
            cast(T)2.4
        );
    }


    private T referenceRelativeLuminance(T)(SRgb!T color)
    @safe pure nothrow @nogc
    {
        return
            cast(T)0.2126 * referenceDecode(color.r) +
            cast(T)0.7152 * referenceDecode(color.g) +
            cast(T)0.0722 * referenceDecode(color.b);
    }


    private T absValue(T)(const T value)
    @safe pure nothrow @nogc
    {
        return
            value < cast(T)0 ?
            -value :
            value;
    }


    private struct WcagTestLcg
    {
        uint state;

        uint next()
        @safe pure nothrow @nogc
        {
            state =
                state * 1664525U +
                1013904223U;

            return state;
        }

        T unit(T)()
        @safe pure nothrow @nogc
        {
            const uint bits =
                next() & 0x00FF_FFFFU;

            return
                cast(T)bits /
                cast(T)0x00FF_FFFFU;
        }
    }


    private bool approxEqual(T)(
        const T actual,
        const T expected,
        const T absoluteTolerance,
        const T relativeTolerance
    )
    @safe pure nothrow @nogc
    {
        const T diff =
            absValue(actual - expected);

        if (diff <= absoluteTolerance)
            return true;

        const T absActual =
            absValue(actual);

        const T absExpected =
            absValue(expected);

        const T scale =
            absActual > absExpected ?
            absActual :
            absExpected;

        return
            diff <=
            relativeTolerance * scale;
    }


    private T propertyAbsoluteTolerance(T)()
    @safe pure nothrow @nogc
    {
        static if (is(T == float))
            return cast(T)2e-6;
        else
            return cast(T)2e-14;
    }


    private T propertyRelativeTolerance(T)()
    @safe pure nothrow @nogc
    {
        static if (is(T == float))
            return cast(T)2e-6;
        else
            return cast(T)2e-14;
    }


    private bool finiteValue(T)(const T value)
    @safe pure nothrow @nogc
    {
        return
            value == value &&
            value <= T.max &&
            value >= -T.max;
    }


    private T referenceContrastRatio(T)(
        SRgb!T first,
        SRgb!T second
    )
    @safe pure nothrow @nogc
    {
        const T firstLuminance =
            referenceRelativeLuminance(first);

        const T secondLuminance =
            referenceRelativeLuminance(second);

        const bool firstIsLighter =
            firstLuminance >=
            secondLuminance;

        const T lighter =
            firstIsLighter ?
            firstLuminance :
            secondLuminance;

        const T darker =
            firstIsLighter ?
            secondLuminance :
            firstLuminance;

        return
            (lighter + cast(T)0.05) /
            (darker  + cast(T)0.05);
    }


    private void verifyGeneratedProperties(T)(
        size_t samples
    )
    @safe pure nothrow @nogc
    {
        const T absoluteTolerance =
            propertyAbsoluteTolerance!T();

        const T relativeTolerance =
            propertyRelativeTolerance!T();

        WcagTestLcg rng =
            WcagTestLcg(
                0xC01D_0009U
            );

        foreach (_; 0 .. samples)
        {
            const SRgb!T first =
                SRgb!T(
                    rng.unit!T(),
                    rng.unit!T(),
                    rng.unit!T()
                );

            const SRgb!T second =
                SRgb!T(
                    rng.unit!T(),
                    rng.unit!T(),
                    rng.unit!T()
                );


            // Independent encoded-sRGB luminance reference.
            const auto measuredLuminance =
                wcag2RelativeLuminance(first);

            assert(measuredLuminance.valid);

            const T referenceLuminance =
                referenceRelativeLuminance(first);

            assert(
                approxEqual(
                    measuredLuminance.value,
                    referenceLuminance,
                    absoluteTolerance,
                    relativeTolerance
                )
            );


            // Public contrast result.
            const auto forward =
                wcag2ContrastRatio(
                    first,
                    second
                );

            const auto reverse =
                wcag2ContrastRatio(
                    second,
                    first
                );

            const auto identity =
                wcag2ContrastRatio(
                    first,
                    first
                );

            assert(forward.valid);
            assert(reverse.valid);
            assert(identity.valid);


            // R0.9 contrast properties.
            assert(
                approxEqual(
                    forward.value,
                    reverse.value,
                    absoluteTolerance,
                    relativeTolerance
                )
            );

            assert(
                approxEqual(
                    identity.value,
                    cast(T)1,
                    absoluteTolerance,
                    relativeTolerance
                )
            );

            assert(
                finiteValue(
                    forward.value
                )
            );

            assert(
                forward.value >=
                cast(T)1 -
                absoluteTolerance
            );

            assert(
                forward.value <=
                cast(T)21 +
                absoluteTolerance
            );


            // Stronger production regression: reconstruct contrast from the
            // independent reference-decode luminance route.
            const T referenceContrast =
                referenceContrastRatio(
                    first,
                    second
                );

            assert(
                approxEqual(
                    forward.value,
                    referenceContrast,
                    absoluteTolerance,
                    relativeTolerance
                )
            );
        }
    }


    private void verifyInvalidDomains()
    @safe pure nothrow @nogc
    {
        const SRgbd[5] invalidEncoded = [
            SRgbd(-0.000001, 0.5, 0.5),
            SRgbd(1.000001, 0.5, 0.5),
            SRgbd(double.nan, 0.5, 0.5),
            SRgbd(double.infinity, 0.5, 0.5),
            SRgbd(-double.infinity, 0.5, 0.5)
        ];

        const LinearSRgbd[5] invalidLinear = [
            LinearSRgbd(-0.000001, 0.5, 0.5),
            LinearSRgbd(1.000001, 0.5, 0.5),
            LinearSRgbd(double.nan, 0.5, 0.5),
            LinearSRgbd(double.infinity, 0.5, 0.5),
            LinearSRgbd(-double.infinity, 0.5, 0.5)
        ];

        const SRgbd encodedWhite =
            SRgbd(1, 1, 1);

        const LinearSRgbd linearWhite =
            LinearSRgbd(1, 1, 1);

        foreach (color; invalidEncoded)
        {
            const auto luminance =
                wcag2RelativeLuminance(color);

            const auto contrast =
                wcag2ContrastRatio(
                    color,
                    encodedWhite
                );

            assert(!luminance.valid);
            assert(
                luminance.value !=
                luminance.value
            );

            assert(!contrast.valid);
            assert(
                contrast.value !=
                contrast.value
            );
        }

        foreach (color; invalidLinear)
        {
            const auto luminance =
                wcag2RelativeLuminance(color);

            const auto contrast =
                wcag2ContrastRatio(
                    color,
                    linearWhite
                );

            assert(!luminance.valid);
            assert(
                luminance.value !=
                luminance.value
            );

            assert(!contrast.valid);
            assert(
                contrast.value !=
                contrast.value
            );
        }
    }


    // R0.9 transfer-function boundary regression.
    enum boundary004044 =
        wcag2RelativeLuminance(
            SRgbd(
                0.04044,
                0.04044,
                0.04044
            )
        );

    enum boundary004045 =
        wcag2RelativeLuminance(
            SRgbd(
                0.04045,
                0.04045,
                0.04045
            )
        );

    enum boundary004046 =
        wcag2RelativeLuminance(
            SRgbd(
                0.04046,
                0.04046,
                0.04046
            )
        );

    static assert(boundary004044.valid);
    static assert(boundary004045.valid);
    static assert(boundary004046.valid);

    static assert(
        approxEqual(
            boundary004044.value,
            referenceRelativeLuminance(
                SRgbd(
                    0.04044,
                    0.04044,
                    0.04044
                )
            ),
            1e-15,
            1e-14
        )
    );

    static assert(
        approxEqual(
            boundary004045.value,
            referenceRelativeLuminance(
                SRgbd(
                    0.04045,
                    0.04045,
                    0.04045
                )
            ),
            1e-15,
            1e-14
        )
    );

    static assert(
        approxEqual(
            boundary004046.value,
            referenceRelativeLuminance(
                SRgbd(
                    0.04046,
                    0.04046,
                    0.04046
                )
            ),
            1e-15,
            1e-14
        )
    );


    // WCAG relative luminance deliberately remains distinct from XYZ-D65 Y.
    enum distinctionColor =
        SRgbd(
            0.691,
            0.139,
            0.259
        );

    enum distinctionWcag =
        wcag2RelativeLuminance(
            distinctionColor
        );

    enum distinctionXyz =
        distinctionColor
            .toLinear
            .toXyzD65;

    static assert(distinctionWcag.valid);

    static assert(
        absValue(
            distinctionWcag.value -
            distinctionXyz.y
        ) > 1e-6
    );
}


@safe pure nothrow @nogc unittest
{
    // R0.9 used 4096 deterministic generated cases for each scalar type.
    verifyGeneratedProperties!float(4096);
    verifyGeneratedProperties!double(4096);

    // R0.9 explicitly exercised all five invalid-domain classes for both
    // encoded and linear-light sRGB.
    verifyInvalidDomains();
}
