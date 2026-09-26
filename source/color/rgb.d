module color.rgb;

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
