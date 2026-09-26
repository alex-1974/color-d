module color.rgb;

private import std.traits : Unqual;

/**
 * Encoded nonlinear sRGB color value.
 *
 * `T` is restricted to the v0.1 computational scalar set: `float` or
 * `double`.
 *
 * The components are mathematical values. Construction does not clamp them to
 * the nominal display gamut.
 */
struct SRgb(T)
if (is(T == float) || is(T == double))
{
    /// Scalar component type.
    alias Scalar = T;

    /// Red encoded-sRGB component.
    T r;

    /// Green encoded-sRGB component.
    T g;

    /// Blue encoded-sRGB component.
    T b;
}

/**
 * Linear-light sRGB color value.
 *
 * `T` is restricted to the v0.1 computational scalar set: `float` or
 * `double`.
 *
 * Encoded and linear-light sRGB are deliberately distinct types even though
 * they have the same component layout.
 */
struct LinearSRgb(T)
if (is(T == float) || is(T == double))
{
    /// Scalar component type.
    alias Scalar = T;

    /// Red linear-light component.
    T r;

    /// Green linear-light component.
    T g;

    /// Blue linear-light component.
    T b;
}

/// Encoded sRGB with `float` components.
alias SRgbf = SRgb!float;

/// Encoded sRGB with `double` components.
alias SRgbd = SRgb!double;

/// Linear-light sRGB with `float` components.
alias LinearSRgbf = LinearSRgb!float;

/// Linear-light sRGB with `double` components.
alias LinearSRgbd = LinearSRgb!double;


private T magnitude(T)(T value)
@safe pure nothrow @nogc
{
    return value < cast(T)0 ? -value : value;
}

private T signOf(T)(T value)
@safe pure nothrow @nogc
{
    return value < cast(T)0 ? cast(T)-1 : cast(T)1;
}

/*
 * Narrow LDC runtime optimization validated by the R0 performance gate.
 *
 * The intrinsic path is used only for the sRGB decode power with a positive
 * base and exponent 2.4. CTFE and non-LDC builds retain std.math.pow.
 */
private auto srgbDecodePow24(T)(T base)
@safe pure nothrow @nogc
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    import std.math : pow;

    alias U = Unqual!T;
    const U value = cast(U)base;

    if (__ctfe)
        return cast(U)pow(value, cast(U)2.4);

    version (LDC)
    {
        import ldc.intrinsics : llvm_pow;
        return llvm_pow!U(value, cast(U)2.4);
    }
    else
    {
        return cast(U)pow(value, cast(U)2.4);
    }
}

private T srgbToLinearComponent(T)(T encoded)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T absEncoded = magnitude(encoded);

    if (absEncoded <= cast(T)0.04045)
        return encoded / cast(T)12.92;

    const T base =
        (absEncoded + cast(T)0.055) /
        cast(T)1.055;

    return signOf(encoded) * srgbDecodePow24(base);
}

private T linearToSrgbComponent(T)(T linear)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    import std.math : pow;

    const T absLinear = magnitude(linear);

    if (absLinear <= cast(T)0.0031308)
        return linear * cast(T)12.92;

    const T exponent = cast(T)(1.0 / 2.4);

    const T encodedMagnitude =
        cast(T)1.055 *
        cast(T)pow(absLinear, exponent) -
        cast(T)0.055;

    return signOf(linear) * encodedMagnitude;
}

/**
 * Decode nonlinear sRGB into linear-light sRGB.
 *
 * The conversion is explicit, allocation-free and does not clamp extended
 * component values. Negative extended values use the sign-preserving extension
 * validated during R0.
 */
LinearSRgb!T toLinear(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        srgbToLinearComponent(color.r),
        srgbToLinearComponent(color.g),
        srgbToLinearComponent(color.b)
    );
}

/**
 * Encode linear-light sRGB into nonlinear sRGB.
 *
 * The conversion is explicit, allocation-free and does not clamp extended
 * component values. Negative extended values use the sign-preserving extension
 * validated during R0.
 */
SRgb!T toSRgb(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return SRgb!T(
        linearToSrgbComponent(color.r),
        linearToSrgbComponent(color.g),
        linearToSrgbComponent(color.b)
    );
}

@safe pure nothrow @nogc unittest
{
    const encoded = SRgbf(0.25f, 0.5f, 0.75f);
    const linear = LinearSRgbd(0.1, 0.2, 0.3);

    assert(encoded.r == 0.25f);
    assert(encoded.g == 0.5f);
    assert(encoded.b == 0.75f);

    assert(linear.r == 0.1);
    assert(linear.g == 0.2);
    assert(linear.b == 0.3);
}

static assert(is(SRgbf.Scalar == float));
static assert(is(SRgbd.Scalar == double));
static assert(is(LinearSRgbf.Scalar == float));
static assert(is(LinearSRgbd.Scalar == double));

static assert(!is(SRgbf == LinearSRgbf));
static assert(!is(SRgbd == LinearSRgbd));

static assert(!__traits(compiles, SRgb!ubyte));
static assert(!__traits(compiles, SRgb!int));
static assert(!__traits(compiles, SRgb!real));
static assert(!__traits(compiles, LinearSRgb!ubyte));
static assert(!__traits(compiles, LinearSRgb!int));
static assert(!__traits(compiles, LinearSRgb!real));

unittest
{
    assert(SRgbf.sizeof == 3 * float.sizeof);
    assert(SRgbd.sizeof == 3 * double.sizeof);
    assert(LinearSRgbf.sizeof == 3 * float.sizeof);
    assert(LinearSRgbd.sizeof == 3 * double.sizeof);

    // R0.14 deliberately keeps the natural floating-point .init state rather
    // than redefining default initialization as a valid color such as black.
    assert(SRgbf.init.r != SRgbf.init.r);
    assert(SRgbf.init.g != SRgbf.init.g);
    assert(SRgbf.init.b != SRgbf.init.b);

    assert(LinearSRgbd.init.r != LinearSRgbd.init.r);
    assert(LinearSRgbd.init.g != LinearSRgbd.init.g);
    assert(LinearSRgbd.init.b != LinearSRgbd.init.b);
}

static assert(!__traits(compiles, toLinear(LinearSRgbf.init)));
static assert(!__traits(compiles, toSRgb(SRgbf.init)));

version (unittest)
{
    private bool transferReferenceClose(T)(
        T actual,
        T expected,
        T absoluteTolerance,
        T relativeTolerance
    )
    @safe pure nothrow @nogc
    {
        const T diff = magnitude(actual - expected);
        if (diff <= absoluteTolerance)
            return true;

        const T absActual = magnitude(actual);
        const T absExpected = magnitude(expected);
        const T scale =
            absActual > absExpected ? absActual : absExpected;

        return diff <= relativeTolerance * scale;
    }

    // REFERENCE: sRGB transfer equation, double.
    static assert(transferReferenceClose(
        srgbToLinearComponent(0.5),
        0.21404114048223255,
        1e-15,
        1e-14
    ));

    static assert(transferReferenceClose(
        srgbToLinearComponent(-0.5),
        -0.21404114048223255,
        1e-15,
        1e-14
    ));

    static assert(transferReferenceClose(
        srgbToLinearComponent(1.2),
        1.5168374366863642,
        1e-14,
        1e-14
    ));

    // REFERENCE: exact branch boundary is intentionally probed directly.
    static assert(transferReferenceClose(
        srgbToLinearComponent(0.04045),
        0.0031308049535603713,
        1e-15,
        1e-14
    ));

    // REFERENCE: separate float characterization.
    static assert(transferReferenceClose(
        srgbToLinearComponent(0.5f),
        0.21404114f,
        1e-7f,
        1e-6f
    ));

    static assert(transferReferenceClose(
        srgbToLinearComponent(1.2f),
        1.5168374f,
        2e-7f,
        2e-6f
    ));

    // REFERENCE: inverse transfer.
    static assert(transferReferenceClose(
        linearToSrgbComponent(0.21404114048223255),
        0.5,
        1e-15,
        1e-14
    ));

    static assert(transferReferenceClose(
        linearToSrgbComponent(-0.21404114048223255),
        -0.5,
        1e-15,
        1e-14
    ));

    // CTFE + DERIVED round trip for an ordinary float color.
    enum encodedCtfe = SRgbf(0.691f, 0.139f, 0.259f);
    enum linearCtfe = encodedCtfe.toLinear;
    enum roundTripCtfe = linearCtfe.toSRgb;

    static assert(transferReferenceClose(
        roundTripCtfe.r,
        encodedCtfe.r,
        2e-7f,
        2e-6f
    ));
    static assert(transferReferenceClose(
        roundTripCtfe.g,
        encodedCtfe.g,
        2e-7f,
        2e-6f
    ));
    static assert(transferReferenceClose(
        roundTripCtfe.b,
        encodedCtfe.b,
        2e-7f,
        2e-6f
    ));

    // CTFE + DERIVED extended-range round trip.
    enum extendedCtfe = SRgbd(-0.5, 1.2, 0.5);
    enum extendedLinearCtfe = extendedCtfe.toLinear;
    enum extendedRoundTripCtfe = extendedLinearCtfe.toSRgb;

    static assert(extendedLinearCtfe.r < 0.0);
    static assert(extendedLinearCtfe.g > 1.0);
    static assert(transferReferenceClose(
        extendedRoundTripCtfe.r,
        extendedCtfe.r,
        1e-14,
        1e-14
    ));
    static assert(transferReferenceClose(
        extendedRoundTripCtfe.g,
        extendedCtfe.g,
        1e-14,
        1e-14
    ));

    @safe pure nothrow @nogc unittest
    {
        // EXACT structural zero behavior, including the linear branch.
        const black = SRgbd(0.0, 0.0, 0.0).toLinear;
        assert(black == LinearSRgbd(0.0, 0.0, 0.0));

        // Special values remain visible rather than being repaired.
        const specialEncoded = SRgbd(
            double.nan,
            double.infinity,
            -double.infinity
        );
        const specialLinear = specialEncoded.toLinear;

        assert(specialLinear.r != specialLinear.r);
        assert(specialLinear.g == double.infinity);
        assert(specialLinear.b == -double.infinity);

        const specialLinearInput = LinearSRgbd(
            double.nan,
            double.infinity,
            -double.infinity
        );
        const specialRoundTrip = specialLinearInput.toSRgb;

        assert(specialRoundTrip.r != specialRoundTrip.r);
        assert(specialRoundTrip.g == double.infinity);
        assert(specialRoundTrip.b == -double.infinity);
    }
}
