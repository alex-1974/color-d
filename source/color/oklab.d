module color.oklab;

private import color.xyz :
    XyzD65,
    XyzD65f,
    XyzD65d;

/**
 * Oklab color value.
 *
 * `T` is restricted to the v0.1 computational scalar set: `float` or
 * `double`.
 *
 * Components are mathematical values. Construction does not clamp or
 * canonicalize them.
 */
struct Oklab(T)
if (is(T == float) || is(T == double))
{
    /// Perceptual lightness component.
    T l;

    /// Green-red opponent component.
    T a;

    /// Blue-yellow opponent component.
    T b;

    /// Scalar component type.
    alias Scalar = T;
}

/// Oklab with `float` components.
alias Oklabf = Oklab!float;

/// Oklab with `double` components.
alias Oklabd = Oklab!double;

private T cube(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return value * value * value;
}

private T cubeRoot(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    import std.math : pow;

    // Oklab requires a real, sign-preserving cube root because extended
    // XYZ values can produce negative LMS intermediates. Returning zero
    // unchanged also preserves the sign of -0.0.
    if (value == cast(T)0)
        return value;

    const T absValue =
        value < cast(T)0
            ? -value
            : value;

    const T root = cast(T)pow(
        absValue,
        cast(T)(1.0L / 3.0L)
    );

    return value < cast(T)0
        ? -root
        : root;
}

/**
 * Convert CIE XYZ D65 to Oklab.
 *
 * The conversion uses the high-precision XYZ/LMS/Oklab coefficient route
 * validated during R0. Extended finite values are preserved; negative LMS
 * intermediates use a sign-preserving real cube root.
 */
Oklab!T toOklab(T)(XyzD65!T xyz)
@safe pure nothrow @nogc
{
    const T l =
        cast(T)0.8190224379967030 * xyz.x +
        cast(T)0.3619062600528904 * xyz.y -
        cast(T)0.1288737815209879 * xyz.z;

    const T m =
        cast(T)0.0329836539323885 * xyz.x +
        cast(T)0.9292868615863434 * xyz.y +
        cast(T)0.0361446663506424 * xyz.z;

    const T s =
        cast(T)0.0481771893596242 * xyz.x +
        cast(T)0.2642395317527308 * xyz.y +
        cast(T)0.6335478284694309 * xyz.z;

    const T lp = cubeRoot(l);
    const T mp = cubeRoot(m);
    const T sp = cubeRoot(s);

    return Oklab!T(
        cast(T)0.2104542683093140 * lp +
        cast(T)0.7936177747023054 * mp -
        cast(T)0.0040720430116193 * sp,

        cast(T)1.9779985324311684 * lp -
        cast(T)2.4285922420485799 * mp +
        cast(T)0.4505937096174110 * sp,

        cast(T)0.0259040424655478 * lp +
        cast(T)0.7827717124575296 * mp -
        cast(T)0.8086757549230774 * sp
    );
}

/**
 * Convert Oklab to CIE XYZ D65.
 *
 * The inverse conversion uses the coefficient route validated during R0.
 * It is allocation-free, CTFE-capable and does not clamp extended values.
 */
XyzD65!T toXyzD65(T)(Oklab!T lab)
@safe pure nothrow @nogc
{
    const T lp =
        lab.l +
        cast(T)0.3963377773761749 * lab.a +
        cast(T)0.2158037573099136 * lab.b;

    const T mp =
        lab.l -
        cast(T)0.1055613458156586 * lab.a -
        cast(T)0.0638541728258133 * lab.b;

    const T sp =
        lab.l -
        cast(T)0.0894841775298119 * lab.a -
        cast(T)1.2914855480194092 * lab.b;

    const T l = cube(lp);
    const T m = cube(mp);
    const T s = cube(sp);

    return XyzD65!T(
        cast(T)1.2268798758459243 * l -
        cast(T)0.5578149944602171 * m +
        cast(T)0.2813910456659647 * s,

       -cast(T)0.0405757452148008 * l +
        cast(T)1.1122868032803170 * m -
        cast(T)0.0717110580655164 * s,

       -cast(T)0.0763729366746601 * l -
        cast(T)0.4214933324022432 * m +
        cast(T)1.5869240198367816 * s
    );
}

@safe pure nothrow @nogc unittest
{
    const lab = Oklabd(0.627955, 0.224863, 0.125846);

    assert(lab.l == 0.627955);
    assert(lab.a == 0.224863);
    assert(lab.b == 0.125846);
}

static assert(is(Oklabf.Scalar == float));
static assert(is(Oklabd.Scalar == double));

static assert(!__traits(compiles, Oklab!ubyte));
static assert(!__traits(compiles, Oklab!int));
static assert(!__traits(compiles, Oklab!real));

static assert(!__traits(compiles, Oklabf.init.toOklab));
static assert(!__traits(compiles, XyzD65f.init.toXyzD65));

unittest
{
    assert(Oklabf.sizeof == 3 * float.sizeof);
    assert(Oklabd.sizeof == 3 * double.sizeof);

    // Preserve D's natural floating-point .init state. Default construction
    // does not silently create black or another valid Oklab color.
    assert(Oklabf.init.l != Oklabf.init.l);
    assert(Oklabf.init.a != Oklabf.init.a);
    assert(Oklabf.init.b != Oklabf.init.b);

    assert(Oklabd.init.l != Oklabd.init.l);
    assert(Oklabd.init.a != Oklabd.init.a);
    assert(Oklabd.init.b != Oklabd.init.b);
}

version (unittest)
{
    private T referenceMagnitude(T)(T value)
    @safe pure nothrow @nogc
    {
        return value < cast(T)0 ? -value : value;
    }

    private bool oklabReferenceClose(T)(
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

    // EXACT: sign-preserving real cube-root semantics.
    static assert(cubeRoot(0.0) == 0.0);
    enum positiveZeroRoot = cubeRoot(0.0);
    enum negativeZeroRoot = cubeRoot(-0.0);
    static assert(1.0 / positiveZeroRoot == double.infinity);
    static assert(1.0 / negativeZeroRoot == -double.infinity);

    static assert(oklabReferenceClose(
        cubeRoot(8.0),
        2.0,
        1e-15,
        1e-15
    ));
    static assert(oklabReferenceClose(
        cubeRoot(-8.0),
        -2.0,
        1e-15,
        1e-15
    ));

    // EXACT: structural black maps to structural zero in both directions.
    enum blackLab = XyzD65d(0.0, 0.0, 0.0).toOklab;
    static assert(blackLab.l == 0.0);
    static assert(blackLab.a == 0.0);
    static assert(blackLab.b == 0.0);

    enum blackXyz = Oklabd(0.0, 0.0, 0.0).toXyzD65;
    static assert(blackXyz.x == 0.0);
    static assert(blackXyz.y == 0.0);
    static assert(blackXyz.z == 0.0);

    // REFERENCE: normalized D65 white. Near-zero a/b are not promoted to
    // exact neutrality; they remain numerical reference comparisons.
    enum whiteLab =
        XyzD65d(
            0.9504559270516717,
            1.0,
            1.0890577507598784
        ).toOklab;

    static assert(oklabReferenceClose(
        whiteLab.l,
        1.0,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        whiteLab.a,
        0.0,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        whiteLab.b,
        0.0,
        1e-14,
        1e-14
    ));

    // REFERENCE: ordinary XYZ sample from the R0.13 same-route probe set.
    enum ordinaryXyz = XyzD65d(0.25, 0.40, 0.10);
    enum ordinaryLab = ordinaryXyz.toOklab;

    static assert(oklabReferenceClose(
        ordinaryLab.l,
        0.7207234602752662,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        ordinaryLab.a,
        -0.13366192420474987,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        ordinaryLab.b,
        0.1292464857821164,
        1e-14,
        1e-14
    ));

    // REFERENCE: extended XYZ with a negative LMS intermediate validates the
    // sign-preserving cube-root path rather than a positive-only pow route.
    enum extendedXyz = XyzD65d(-0.10, 0.50, 1.20);
    enum extendedLab = extendedXyz.toOklab;

    static assert(oklabReferenceClose(
        extendedLab.l,
        0.5476332271602543,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        extendedLab.a,
        -2.2555283416190295,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        extendedLab.b,
        -0.16380578172826832,
        1e-14,
        1e-14
    ));

    // REFERENCE: inverse ordinary Oklab sample.
    enum inverseLab = Oklabd(0.50, 0.10, -0.10);
    enum inverseXyz = inverseLab.toXyzD65;

    static assert(oklabReferenceClose(
        inverseXyz.x,
        0.16971083561578204,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        inverseXyz.y,
        0.11283676576528677,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        inverseXyz.z,
        0.31657712066548455,
        1e-14,
        1e-14
    ));

    // DERIVED: double XYZ round trip has a separate acceptance envelope.
    enum ordinaryBack = ordinaryLab.toXyzD65;
    static assert(oklabReferenceClose(
        ordinaryBack.x,
        ordinaryXyz.x,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        ordinaryBack.y,
        ordinaryXyz.y,
        1e-14,
        1e-14
    ));
    static assert(oklabReferenceClose(
        ordinaryBack.z,
        ordinaryXyz.z,
        1e-14,
        1e-14
    ));

    // DERIVED: float path is characterized independently.
    enum ordinaryXyzF = XyzD65f(0.25f, 0.40f, 0.10f);
    enum ordinaryLabF = ordinaryXyzF.toOklab;
    enum ordinaryBackF = ordinaryLabF.toXyzD65;

    static assert(oklabReferenceClose(
        ordinaryBackF.x,
        ordinaryXyzF.x,
        3e-6f,
        3e-6f
    ));
    static assert(oklabReferenceClose(
        ordinaryBackF.y,
        ordinaryXyzF.y,
        3e-6f,
        3e-6f
    ));
    static assert(oklabReferenceClose(
        ordinaryBackF.z,
        ordinaryXyzF.z,
        3e-6f,
        3e-6f
    ));
}
