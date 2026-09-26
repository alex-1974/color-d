module color.gamut;

private import color.rgb :
    SRgb,
    SRgbf,
    SRgbd,
    LinearSRgb,
    LinearSRgbf,
    LinearSRgbd;

private bool isFiniteScalar(T)(T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}

private bool inUnitInterval(T)(T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        isFiniteScalar(value) &&
        value >= cast(T)0 &&
        value <= cast(T)1;
}

private T clampFiniteUnit(T)(T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    // Hard clipping must not make invalid numerical state look valid.
    if (!isFiniteScalar(value))
        return value;

    if (value < cast(T)0)
        return cast(T)0;

    if (value > cast(T)1)
        return cast(T)1;

    return value;
}

/**
 * Test strict membership in the sRGB target gamut.
 *
 * Encoded sRGB uses the geometric component domain [0, 1] for each channel.
 * Non-finite values are outside the gamut. No tolerance is implied.
 */
bool inGamut(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return
        inUnitInterval(color.r) &&
        inUnitInterval(color.g) &&
        inUnitInterval(color.b);
}

/**
 * Test strict membership in the sRGB target gamut.
 *
 * Linear-light sRGB uses the same geometric component domain [0, 1] for each
 * channel. Non-finite values are outside the gamut. No tolerance is implied.
 */
bool inGamut(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return
        inUnitInterval(color.r) &&
        inUnitInterval(color.g) &&
        inUnitInterval(color.b);
}

/**
 * Explicitly hard-clip encoded sRGB components to [0, 1].
 *
 * Finite components below zero become zero and components above one become
 * one. Finite in-range components are preserved. NaN and infinities remain
 * visible rather than being silently repaired.
 */
SRgb!T clip(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return SRgb!T(
        clampFiniteUnit(color.r),
        clampFiniteUnit(color.g),
        clampFiniteUnit(color.b)
    );
}

/**
 * Explicitly hard-clip linear-light sRGB components to [0, 1].
 *
 * Finite components below zero become zero and components above one become
 * one. Finite in-range components are preserved. NaN and infinities remain
 * visible rather than being silently repaired.
 */
LinearSRgb!T clip(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        clampFiniteUnit(color.r),
        clampFiniteUnit(color.g),
        clampFiniteUnit(color.b)
    );
}

version (unittest)
{
    private import color.oklab : Oklabf;
    private import color.oklch : Oklchf;

    // STRICT CLASSIFICATION: exact target-space geometry, no hidden epsilon.
    static assert(SRgbd(0.0, 0.0, 0.0).inGamut);
    static assert(SRgbd(1.0, 1.0, 1.0).inGamut);
    static assert(LinearSRgbd(0.0, 0.0, 0.0).inGamut);
    static assert(LinearSRgbd(1.0, 1.0, 1.0).inGamut);

    static assert(!SRgbd(-0.0001, 0.5, 0.5).inGamut);
    static assert(!SRgbd(1.0001, 0.5, 0.5).inGamut);
    static assert(!LinearSRgbd(-0.0001, 0.5, 0.5).inGamut);
    static assert(!LinearSRgbd(1.0001, 0.5, 0.5).inGamut);

    // Non-finite coordinates are outside the strict target gamut.
    static assert(!SRgbd(double.nan, 0.5, 0.5).inGamut);
    static assert(!SRgbd(double.infinity, 0.5, 0.5).inGamut);
    static assert(!SRgbd(-double.infinity, 0.5, 0.5).inGamut);

    static assert(!LinearSRgbf(float.nan, 0.5f, 0.5f).inGamut);
    static assert(!LinearSRgbf(float.infinity, 0.5f, 0.5f).inGamut);
    static assert(!LinearSRgbf(-float.infinity, 0.5f, 0.5f).inGamut);

    // EXACT: hard clipping saturates finite target coordinates.
    enum clippedLinear =
        LinearSRgbd(-0.2, 0.4, 1.3).clip;

    static assert(clippedLinear.r == 0.0);
    static assert(clippedLinear.g == 0.4);
    static assert(clippedLinear.b == 1.0);
    static assert(clippedLinear.inGamut);

    enum clippedEncoded =
        SRgbf(-0.2f, 0.4f, 1.3f).clip;

    static assert(clippedEncoded.r == 0.0f);
    static assert(clippedEncoded.g == 0.4f);
    static assert(clippedEncoded.b == 1.0f);
    static assert(clippedEncoded.inGamut);

    // EXACT: finite clipping is idempotent.
    static assert(clippedLinear.clip == clippedLinear);
    static assert(clippedEncoded.clip == clippedEncoded);

    // Non-finite state is deliberately not repaired by clipping.
    enum nonFinite =
        LinearSRgbd(
            double.nan,
            double.infinity,
            -double.infinity
        ).clip;

    static assert(nonFinite.r != nonFinite.r);
    static assert(nonFinite.g == double.infinity);
    static assert(nonFinite.b == -double.infinity);
    static assert(!nonFinite.inGamut);

    // Gamut operations are target-space operations in this R1 slice.
    static assert(!__traits(compiles, Oklabf.init.inGamut));
    static assert(!__traits(compiles, Oklchf.init.inGamut));
    static assert(!__traits(compiles, Oklabf.init.clip));
    static assert(!__traits(compiles, Oklchf.init.clip));
}

@safe pure nothrow @nogc unittest
{
    const inside = LinearSRgbd(0.2, 0.4, 0.6);
    const outside = LinearSRgbd(-0.2, 0.4, 1.3);

    assert(inside.inGamut);
    assert(inside.clip == inside);

    const clipped = outside.clip;
    assert(clipped == LinearSRgbd(0.0, 0.4, 1.0));
    assert(clipped.inGamut);
}
