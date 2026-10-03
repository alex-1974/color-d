/++
 CIE 1976 L*a*b* values referenced to D50.

 The reference white is part of the type. Conversion from the library's XYZ D65
 connection space explicitly applies the linear Bradford D65/D50 adaptation.
 No clipping or gamut mapping is performed.
+/
module color.cielab;

private import color.xyz : XyzD65;
private import std.math : cbrt, pow;

/** CIE 1976 L*a*b* coordinates referenced to D50. */
struct CieLabD50(T)
if (is(T == float) || is(T == double))
{
    /// CIE 1976 lightness coordinate L*.
    T l;
    /// CIE 1976 opponent coordinate a*.
    T a;
    /// CIE 1976 opponent coordinate b*.
    T b;
    /// Scalar component type.
    alias Scalar = T;
}

///
@safe pure nothrow @nogc unittest
{
    const lab = CieLabD50d(50.0, 2.5, -4.0);

    assert(lab.l == 50.0);
    assert(lab.a == 2.5);
    assert(lab.b == -4.0);
}

/// CIE Lab D50 with float components.
alias CieLabD50f = CieLabD50!float;

/// CIE Lab D50 with double components.
alias CieLabD50d = CieLabD50!double;

private T labCubeRoot(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    /*
     * Use Phobos cbrt at runtime for its direct cube-root semantics and keep
     * the source-available power form only for CTFE. Current Phobos cbrt
     * reaches a C symbol during CTFE, so the compiler cannot evaluate it
     * there. Returning zero first also preserves signed zero.
     */
    if (value == cast(T)0)
        return value;

    if (!__ctfe)
        return cbrt(value);

    const T magnitude = value < cast(T)0 ? -value : value;
    const T root = cast(T)pow(
        magnitude,
        cast(T)(1.0L / 3.0L)
    );

    return value < cast(T)0 ? -root : root;
}

private T labF(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    enum T epsilon = cast(T)(216.0L / 24389.0L);
    enum T kappa = cast(T)(24389.0L / 27.0L);

    return value > epsilon
        ? labCubeRoot(value)
        : (kappa * value + cast(T)16) / cast(T)116;
}

private T labFInverse(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    enum T epsilon = cast(T)(216.0L / 24389.0L);
    enum T kappa = cast(T)(24389.0L / 27.0L);
    const T cube = value * value * value;

    return cube > epsilon
        ? cube
        : (cast(T)116 * value - cast(T)16) / kappa;
}

private XyzD65!T d65ToD50(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return XyzD65!T(
        cast(T)1.0479297925449969 * xyz.x +
        cast(T)0.022946870601609652 * xyz.y -
        cast(T)0.05019226628920524 * xyz.z,

        cast(T)0.02962780877005599 * xyz.x +
        cast(T)0.9904344267538799 * xyz.y -
        cast(T)0.017073799063418826 * xyz.z,

        -cast(T)0.009243040646204504 * xyz.x +
        cast(T)0.015055191490298152 * xyz.y +
        cast(T)0.7518742814281371 * xyz.z
    );
}

private XyzD65!T d50ToD65(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return XyzD65!T(
        cast(T)0.955473421488075 * xyz.x -
        cast(T)0.02309845494876471 * xyz.y +
        cast(T)0.06325924320057072 * xyz.z,

        -cast(T)0.0283697093338637 * xyz.x +
        cast(T)1.0099953980813041 * xyz.y +
        cast(T)0.021041441191917323 * xyz.z,

        cast(T)0.012314014864481998 * xyz.x -
        cast(T)0.020507649298898964 * xyz.y +
        cast(T)1.330365926242124 * xyz.z
    );
}

/**
 * Converts XYZ D65 to CIE 1976 L*a*b* referenced to D50.
 *
 * The D65 -> D50 linear Bradford adaptation is explicit in this conversion.
 * Extended mathematical values are preserved; no clipping or gamut mapping
 * occurs.
 *
 * Params:
 *     xyz = CIE XYZ value referenced to D65.
 *
 * Returns:
 *     CIELAB coordinates referenced to D50.
 *
 * Standards:
 *     ISO/CIE 11664-4:2019. D65/D50 adaptation follows the published CSS
 *     Color 4 implementation reference.
 */
CieLabD50!T toCieLabD50(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const auto d50 = d65ToD50(xyz);

    enum T xn = cast(T)(0.3457L / 0.3585L);
    enum T yn = cast(T)1;
    enum T zn = cast(T)((1.0L - 0.3457L - 0.3585L) / 0.3585L);

    const T fx = labF(d50.x / xn);
    const T fy = labF(d50.y / yn);
    const T fz = labF(d50.z / zn);

    return CieLabD50!T(
        cast(T)116 * fy - cast(T)16,
        cast(T)500 * (fx - fy),
        cast(T)200 * (fy - fz)
    );
}

///
@safe pure nothrow @nogc unittest
{
    const white = XyzD65d(
        0.9504559270516717,
        1.0,
        1.0890577507598784
    ).toCieLabD50;

    assert(white.l > 99.999999 && white.l < 100.000001);
    assert(white.a > -0.00001 && white.a < 0.00001);
    assert(white.b > -0.00001 && white.b < 0.00001);
}

/**
 * Converts CIE 1976 L*a*b* D50 coordinates to XYZ D65.
 *
 * The D50 -> D65 linear Bradford adaptation is explicit in this conversion.
 *
 * Params:
 *     lab = CIELAB coordinates referenced to D50.
 *
 * Returns:
 *     CIE XYZ coordinates referenced to D65.
 */
XyzD65!T toXyzD65(T)(CieLabD50!T lab)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    enum T xn = cast(T)(0.3457L / 0.3585L);
    enum T yn = cast(T)1;
    enum T zn = cast(T)((1.0L - 0.3457L - 0.3585L) / 0.3585L);

    const T fy = (lab.l + cast(T)16) / cast(T)116;
    const T fx = fy + lab.a / cast(T)500;
    const T fz = fy - lab.b / cast(T)200;

    return d50ToD65(XyzD65!T(
        xn * labFInverse(fx),
        yn * labFInverse(fy),
        zn * labFInverse(fz)
    ));
}

///
@safe pure nothrow @nogc unittest
{
    const source = XyzD65d(
        0.21661,
        0.14602,
        0.59452
    );

    const back = source.toCieLabD50.toXyzD65;

    assert(back.x > 0.2165 && back.x < 0.2168);
    assert(back.y > 0.1459 && back.y < 0.1462);
    assert(back.z > 0.5943 && back.z < 0.5948);
}

@safe pure nothrow @nogc unittest
{
    const lab = XyzD65d(
        0.21661,
        0.14602,
        0.59452
    ).toCieLabD50;

    assert(lab.l > 44.35 && lab.l < 44.37);
    assert(lab.a > 36.03 && lab.a < 36.07);
    assert(lab.b > -59.01 && lab.b < -58.97);
}

@safe pure nothrow @nogc unittest
{
    enum source = XyzD65d(0.21661, 0.14602, 0.59452);
    enum lab = source.toCieLabD50;
    enum back = lab.toXyzD65;

    static assert(lab.l == lab.l);
    static assert(lab.a == lab.a);
    static assert(lab.b == lab.b);
    static assert(back.x == back.x);
    static assert(back.y == back.y);
    static assert(back.z == back.z);
}

static assert(is(CieLabD50f.Scalar == float));
static assert(is(CieLabD50d.Scalar == double));
static assert(!__traits(compiles, CieLabD50!ubyte));
static assert(!__traits(compiles, CieLabD50!int));
static assert(!__traits(compiles, CieLabD50!real));

@safe pure nothrow @nogc unittest
{
    assert(CieLabD50f.sizeof == 3 * float.sizeof);
    assert(CieLabD50d.sizeof == 3 * double.sizeof);
    assert(CieLabD50f.init.l != CieLabD50f.init.l);
    assert(CieLabD50d.init.l != CieLabD50d.init.l);
}
