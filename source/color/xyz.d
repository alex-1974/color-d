module color.xyz;

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
