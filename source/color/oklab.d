module color.oklab;

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
