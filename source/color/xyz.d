/++
 CIE XYZ values referenced to D65 and conversions to and from linear-light sRGB.

 Use XYZ D65 as the connection space between linear-light sRGB and color spaces
 built on D65 tristimulus values. Conversions are explicit and do not clip or
 gamut-map extended values.
+/
module color.xyz;

private import color.rgb :
    LinearSRgb,
    LinearSRgbf,
    LinearSRgbd,
    SRgbf;

/**
 * Stores CIE XYZ tristimulus values referenced to D65.
 *
 * Use this type when a conversion or calculation needs XYZ D65 coordinates.
 * `T` must be `float` or `double`. Construction stores components
 * unchanged and does not clamp them to a display gamut.
 *
 * The natural `.init` value contains NaNs and is not a usable color.
 */

struct XyzD65(T)
if (is(T == float) || is(T == double))
{
    /// X tristimulus component.
    T x;

    /// Y tristimulus component.
    T y;

    /// Z tristimulus component.
    T z;

    /// Scalar component type.
    alias Scalar = T;
}

///
@safe pure nothrow @nogc unittest
{
    const xyz = XyzD65d(0.25, 0.50, 0.75);

    assert(xyz.x == 0.25);
    assert(xyz.y == 0.50);
    assert(xyz.z == 0.75);
}

/// XYZ D65 with `float` components.
alias XyzD65f = XyzD65!float;

/// XYZ D65 with `double` components.
alias XyzD65d = XyzD65!double;

private T ratio(T)(long numerator, long denominator)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return cast(T)numerator / cast(T)denominator;
}

private T magnitude(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return value < cast(T)0 ? -value : value;
}

private T maximum(T)(const T first, const T second)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return first > second ? first : second;
}

private bool finiteInfinityBounds(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        value > -T.infinity &&
        value < T.infinity;
}

private bool finiteXyz(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        finiteInfinityBounds(xyz.x) &&
        finiteInfinityBounds(xyz.y) &&
        finiteInfinityBounds(xyz.z);
}

/*
 * Package-internal direct inverse-matrix evaluator.
 *
 * This is intentionally not part of the public robust XYZ conversion contract.
 * color.gamut uses it for its R0.8-validated float mapping hot path, where the
 * mapper owns its own overflow handling. External callers must use
 * toLinearSRgb(), which retains the extreme-finite fallback.
 */
package(color) LinearSRgb!T toLinearSRgbDirect(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return LinearSRgb!T(
        ratio!T(12831,    3959)   * xyz.x +
        ratio!T(-329,      214)   * xyz.y +
        ratio!T(-1974,    3959)   * xyz.z,

        ratio!T(-851781, 878810)  * xyz.x +
        ratio!T(1648619, 878810)  * xyz.y +
        ratio!T(36519,   878810)  * xyz.z,

        ratio!T(705,      12673)  * xyz.x +
        ratio!T(-2585,    12673)  * xyz.y +
        ratio!T(705,        667)  * xyz.z
    );
}

private LinearSRgb!T toLinearSRgbScaledFinite(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T scale =
        maximum(
            magnitude(xyz.x),
            maximum(
                magnitude(xyz.y),
                magnitude(xyz.z)
            )
        );

    if (scale == cast(T)0)
        return LinearSRgb!T(
            cast(T)0,
            cast(T)0,
            cast(T)0
        );

    const T x = xyz.x / scale;
    const T y = xyz.y / scale;
    const T z = xyz.z / scale;

    return LinearSRgb!T(
        scale * (
            ratio!T(12831,    3959)   * x +
            ratio!T(-329,      214)   * y +
            ratio!T(-1974,    3959)   * z
        ),
        scale * (
            ratio!T(-851781, 878810)  * x +
            ratio!T(1648619, 878810)  * y +
            ratio!T(36519,   878810)  * z
        ),
        scale * (
            ratio!T(705,      12673)  * x +
            ratio!T(-2585,    12673)  * y +
            ratio!T(705,        667)  * z
        )
    );
}

private LinearSRgb!T toLinearSRgbDominantFactor(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    /*
     * Exact rational refactorization of the inverse matrix:
     *
     * R = (12831/3959) * (X - 37/78 Y - 2/13 Z)
     * G = (1648619/878810) * (Y - 2589/5011 X + 111/5011 Z)
     * B = (705/667) * (Z + 1/19 X - 11/57 Y)
     *
     * The absolute minor-coefficient sum in every parenthesis is below one.
     * This prevents the known product/partial-sum overflow pattern before the
     * dominant term is combined and then scaled.
     */
    const T redMinor =
       -ratio!T(37, 78) * xyz.y -
        ratio!T(2, 13) * xyz.z;

    const T greenMinor =
       -ratio!T(2589, 5011) * xyz.x +
        ratio!T(111, 5011) * xyz.z;

    const T blueMinor =
        ratio!T(1, 19) * xyz.x -
        ratio!T(11, 57) * xyz.y;

    return LinearSRgb!T(
        ratio!T(12831, 3959) *
            (redMinor + xyz.x),

        ratio!T(1648619, 878810) *
            (greenMinor + xyz.y),

        ratio!T(705, 667) *
            (blueMinor + xyz.z)
    );
}

/**
 * Converts linear-light sRGB to CIE XYZ D65.
 *
 * Use this conversion when an operation needs XYZ D65 coordinates. Extended
 * values are transformed without gamut clipping. As with ordinary
 * floating-point matrix arithmetic, extreme magnitudes can produce non-finite
 * results.
 *
 * Params:
 *     rgb = Linear-light sRGB value to convert.
 *
 * Returns:
 *     The corresponding CIE XYZ D65 value.
 *
 * Standards:
 *     Uses the high-precision sRGB/D65 linear transformation represented by
 *     the W3C CSS Color Module Level 4 reference matrix.
 *
 * See_Also:
 *     toLinearSRgb
 */

XyzD65!T toXyzD65(T)(LinearSRgb!T rgb)
@safe pure nothrow @nogc
{
    return XyzD65!T(
        ratio!T(506752, 1228815) * rgb.r +
        ratio!T(87881,   245763) * rgb.g +
        ratio!T(12673,    70218) * rgb.b,

        ratio!T(87098,   409605) * rgb.r +
        ratio!T(175762,  245763) * rgb.g +
        ratio!T(12673,   175545) * rgb.b,

        ratio!T(7918,    409605) * rgb.r +
        ratio!T(87881,   737289) * rgb.g +
        ratio!T(1001167, 1053270) * rgb.b
    );
}

///
@safe pure nothrow @nogc unittest
{
    import std.math : fabs;

    const rgb = LinearSRgbd(0.25, 0.50, 0.75);
    const roundTrip = rgb.toXyzD65.toLinearSRgb;

    assert(fabs(roundTrip.r - rgb.r) < 1e-12);
    assert(fabs(roundTrip.g - rgb.g) < 1e-12);
    assert(fabs(roundTrip.b - rgb.b) < 1e-12);
}

/**
 * Converts CIE XYZ D65 to linear-light sRGB.
 *
 * Use this conversion when XYZ D65 data must enter linear-light sRGB
 * calculations. Extended values are transformed without gamut clipping.
 * Finite extreme inputs are handled defensively to avoid avoidable
 * intermediate overflow; the result is not promised to be bit-identical to a
 * particular matrix-evaluation order.
 *
 * Params:
 *     xyz = CIE XYZ D65 value to convert.
 *
 * Returns:
 *     The corresponding linear-light sRGB value.
 *
 * Standards:
 *     Uses the inverse of the high-precision sRGB/D65 transformation
 *     represented by the W3C CSS Color Module Level 4 reference matrix.
 *
 * See_Also:
 *     toXyzD65
 */

LinearSRgb!T toLinearSRgb(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
{
    static if (is(T == double))
    {
        return toLinearSRgbDominantFactor(xyz);
    }
    else
    {
        const LinearSRgb!T ordinary =
            toLinearSRgbDirect(xyz);

        if (
            finiteInfinityBounds(ordinary.r) &&
            finiteInfinityBounds(ordinary.g) &&
            finiteInfinityBounds(ordinary.b)
        )
        {
            return ordinary;
        }

        if (!finiteXyz(xyz))
            return ordinary;

        return toLinearSRgbScaledFinite(xyz);
    }
}

///
@safe pure nothrow @nogc unittest
{
    const black = XyzD65d(0.0, 0.0, 0.0).toLinearSRgb;

    assert(black == LinearSRgbd(0.0, 0.0, 0.0));
}

///
@safe pure nothrow @nogc unittest
{
    import std.math : fabs;

    const double factorX = -0.75;
    const double factorY = -0.75;
    const double factorZ = -1.0;

    const rgb =
        XyzD65d(
            factorX * double.max,
            factorY * double.max,
            factorZ * double.max
        ).toLinearSRgb;

    const double expectedR =
        ratio!double(12831, 3959) * factorX +
        ratio!double(-329, 214) * factorY +
        ratio!double(-1974, 3959) * factorZ;

    const double expectedG =
        ratio!double(-851781, 878810) * factorX +
        ratio!double(1648619, 878810) * factorY +
        ratio!double(36519, 878810) * factorZ;

    const double expectedB =
        ratio!double(705, 12673) * factorX +
        ratio!double(-2585, 12673) * factorY +
        ratio!double(705, 667) * factorZ;

    assert(finiteInfinityBounds(rgb.r));
    assert(finiteInfinityBounds(rgb.g));
    assert(finiteInfinityBounds(rgb.b));

    assert(fabs(rgb.r / double.max - expectedR) < 1e-14);
    assert(fabs(rgb.g / double.max - expectedG) < 1e-14);
    assert(fabs(rgb.b / double.max - expectedB) < 1e-14);
}

///
@safe pure nothrow @nogc unittest
{
    import std.math : fabs;

    const float factorX = -0.75f;
    const float factorY = -0.75f;
    const float factorZ = -1.0f;

    const rgb =
        XyzD65f(
            factorX * float.max,
            factorY * float.max,
            factorZ * float.max
        ).toLinearSRgb;

    const float expectedR =
        ratio!float(12831, 3959) * factorX +
        ratio!float(-329, 214) * factorY +
        ratio!float(-1974, 3959) * factorZ;

    const float expectedG =
        ratio!float(-851781, 878810) * factorX +
        ratio!float(1648619, 878810) * factorY +
        ratio!float(36519, 878810) * factorZ;

    const float expectedB =
        ratio!float(705, 12673) * factorX +
        ratio!float(-2585, 12673) * factorY +
        ratio!float(705, 667) * factorZ;

    assert(finiteInfinityBounds(rgb.r));
    assert(finiteInfinityBounds(rgb.g));
    assert(finiteInfinityBounds(rgb.b));

    assert(fabs(rgb.r / float.max - expectedR) < 2e-6f);
    assert(fabs(rgb.g / float.max - expectedG) < 2e-6f);
    assert(fabs(rgb.b / float.max - expectedB) < 2e-6f);
}


@safe pure nothrow @nogc unittest
{
    const xyz = XyzD65d(0.950456, 1.0, 1.08906);

    assert(xyz.x == 0.950456);
    assert(xyz.y == 1.0);
    assert(xyz.z == 1.08906);
}

static assert(is(XyzD65f.Scalar == float));
static assert(is(XyzD65d.Scalar == double));

static assert(!__traits(compiles, XyzD65!ubyte));
static assert(!__traits(compiles, XyzD65!int));
static assert(!__traits(compiles, XyzD65!real));

static assert(!__traits(compiles, SRgbf.init.toXyzD65));
static assert(!__traits(compiles, LinearSRgbf.init.toLinearSRgb));

@safe pure nothrow @nogc unittest
{
    assert(XyzD65f.sizeof == 3 * float.sizeof);
    assert(XyzD65d.sizeof == 3 * double.sizeof);

    // Keep D's natural floating-point .init state visible rather than
    // redefining default initialization as a valid XYZ color.
    assert(XyzD65f.init.x != XyzD65f.init.x);
    assert(XyzD65f.init.y != XyzD65f.init.y);
    assert(XyzD65f.init.z != XyzD65f.init.z);

    assert(XyzD65d.init.x != XyzD65d.init.x);
    assert(XyzD65d.init.y != XyzD65d.init.y);
    assert(XyzD65d.init.z != XyzD65d.init.z);
}

version (unittest)
{
    private T referenceMagnitude(T)(T value)
    @safe pure nothrow @nogc
    {
        return value < cast(T)0 ? -value : value;
    }

    private bool xyzReferenceClose(T)(
        T actual,
        T expected,
        T absoluteTolerance,
        T relativeTolerance
    )
    @safe pure nothrow @nogc
    {
        const T diff = referenceMagnitude(actual - expected);
        if (diff <= absoluteTolerance)
            return true;

        const T absActual = referenceMagnitude(actual);
        const T absExpected = referenceMagnitude(expected);
        const T scale =
            absActual > absExpected ? absActual : absExpected;

        return diff <= relativeTolerance * scale;
    }

    // EXACT: matrix multiplication maps structural black to structural zero.
    enum blackXyz = LinearSRgbd(0.0, 0.0, 0.0).toXyzD65;
    static assert(blackXyz.x == 0.0);
    static assert(blackXyz.y == 0.0);
    static assert(blackXyz.z == 0.0);

    enum blackLinear = XyzD65d(0.0, 0.0, 0.0).toLinearSRgb;
    static assert(blackLinear.r == 0.0);
    static assert(blackLinear.g == 0.0);
    static assert(blackLinear.b == 0.0);

    // REFERENCE: double unit primary protects matrix orientation and ordering.
    enum redXyz = LinearSRgbd(1.0, 0.0, 0.0).toXyzD65;
    static assert(xyzReferenceClose(
        redXyz.x,
        0.4123907992659595,
        1e-15,
        1e-14
    ));
    static assert(xyzReferenceClose(
        redXyz.y,
        0.21263900587151036,
        1e-15,
        1e-14
    ));
    static assert(xyzReferenceClose(
        redXyz.z,
        0.01933081871559185,
        1e-15,
        1e-14
    ));

    // REFERENCE: same primary characterized separately at float precision.
    enum redXyzF = LinearSRgbf(1.0f, 0.0f, 0.0f).toXyzD65;
    static assert(xyzReferenceClose(
        redXyzF.x,
        0.4123908f,
        2e-7f,
        2e-6f
    ));
    static assert(xyzReferenceClose(
        redXyzF.y,
        0.2126390f,
        2e-7f,
        2e-6f
    ));
    static assert(xyzReferenceClose(
        redXyzF.z,
        0.019330819f,
        2e-7f,
        2e-6f
    ));

    // REFERENCE: normalized D65 white has Y == 1.
    enum whiteXyz = LinearSRgbd(1.0, 1.0, 1.0).toXyzD65;
    enum double d65X = 0.3127 / 0.3290;
    enum double d65Z = (1.0 - 0.3127 - 0.3290) / 0.3290;

    static assert(xyzReferenceClose(
        whiteXyz.x,
        d65X,
        1e-15,
        1e-14
    ));
    static assert(xyzReferenceClose(
        whiteXyz.y,
        1.0,
        1e-15,
        1e-14
    ));
    static assert(xyzReferenceClose(
        whiteXyz.z,
        d65Z,
        1e-15,
        1e-14
    ));

    // DERIVED: ordinary double round trip has its own acceptance envelope.
    enum ordinary = LinearSRgbd(
        0.4352785666728059,
        0.017175850397231969,
        0.054553830782703643
    );
    enum ordinaryBack = ordinary.toXyzD65.toLinearSRgb;

    static assert(xyzReferenceClose(
        ordinaryBack.r,
        ordinary.r,
        1e-14,
        1e-14
    ));
    static assert(xyzReferenceClose(
        ordinaryBack.g,
        ordinary.g,
        1e-14,
        1e-14
    ));
    static assert(xyzReferenceClose(
        ordinaryBack.b,
        ordinary.b,
        1e-14,
        1e-14
    ));

    // REGRESSION: a retained extreme case whose direct inverse-matrix
    // evaluation previously became non-finite before cancellation.
    enum extremeLinearD =
        XyzD65d(
            -0.75 * double.max,
            -0.75 * double.max,
            -double.max
        ).toLinearSRgb;

    static assert(finiteInfinityBounds(extremeLinearD.r));
    static assert(finiteInfinityBounds(extremeLinearD.g));
    static assert(finiteInfinityBounds(extremeLinearD.b));

    enum extremeLinearF =
        XyzD65f(
            -0.75f * float.max,
            -0.75f * float.max,
            -float.max
        ).toLinearSRgb;

    static assert(finiteInfinityBounds(extremeLinearF.r));
    static assert(finiteInfinityBounds(extremeLinearF.g));
    static assert(finiteInfinityBounds(extremeLinearF.b));

    // REFERENCE + DERIVED: finite extended-range values are not clipped.
    enum extended = LinearSRgbd(-0.2, 1.3, 0.5);
    enum extendedXyz = extended.toXyzD65;
    enum extendedBack = extendedXyz.toLinearSRgb;

    static assert(xyzReferenceClose(
        extendedXyz.x,
        0.4726218755467666,
        1e-14,
        1e-14
    ));
    static assert(xyzReferenceClose(
        extendedXyz.y,
        0.9232876389041474,
        1e-14,
        1e-14
    ));
    static assert(xyzReferenceClose(
        extendedXyz.z,
        0.6263531261147257,
        1e-14,
        1e-14
    ));
    static assert(xyzReferenceClose(
        extendedBack.r,
        extended.r,
        1e-14,
        1e-14
    ));
    static assert(xyzReferenceClose(
        extendedBack.g,
        extended.g,
        1e-14,
        1e-14
    ));
    static assert(xyzReferenceClose(
        extendedBack.b,
        extended.b,
        1e-14,
        1e-14
    ));

    // DERIVED: float round trip is characterized independently.
    enum ordinaryF = LinearSRgbf(
        0.43527857f,
        0.01717585f,
        0.05455383f
    );
    enum ordinaryBackF = ordinaryF.toXyzD65.toLinearSRgb;

    static assert(xyzReferenceClose(
        ordinaryBackF.r,
        ordinaryF.r,
        2e-6f,
        2e-6f
    ));
    static assert(xyzReferenceClose(
        ordinaryBackF.g,
        ordinaryF.g,
        2e-6f,
        2e-6f
    ));
    static assert(xyzReferenceClose(
        ordinaryBackF.b,
        ordinaryF.b,
        2e-6f,
        2e-6f
    ));
}
