module color.xyz;

private import color.rgb :
    LinearSRgb,
    LinearSRgbf,
    LinearSRgbd,
    SRgbf;

/**
 * CIE XYZ color value using the D65 reference white.
 *
 * `T` is restricted to the v0.1 computational scalar set: `float` or
 * `double`.
 *
 * XYZ components are mathematical values and are not implicitly clamped to a
 * display-gamut range.
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

/**
 * Convert linear-light sRGB to CIE XYZ D65.
 *
 * The matrix uses the rational sRGB/D65 coefficients validated during R0.
 * The operation is allocation-free, CTFE-capable and does not clip extended
 * finite values.
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

/**
 * Convert CIE XYZ D65 to linear-light sRGB.
 *
 * The inverse matrix uses the rational coefficients validated during R0.
 * The operation is allocation-free, CTFE-capable and does not clip extended
 * finite values.
 */
LinearSRgb!T toLinearSRgb(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
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

unittest
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
