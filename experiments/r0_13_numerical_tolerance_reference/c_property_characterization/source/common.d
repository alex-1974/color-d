module common;

import std.conv : bitCast;
import std.math.traits : isNaN;
import std.stdio : writefln;
import std.traits : Unqual, isFloatingPoint;
import std.math.algebraic : hypot;

/**
 * Two-argument hypot compatibility helper copied/adapted from
 * euclid-core-d commit c9fd4b2f5eca46a4d0170b0de915b8e1481380a9.
 *
 * Phobos/frontend 2.111 has a tiny-operand correctness defect in the
 * two-argument overload. Starting with 2.112, Phobos is authoritative again.
 */
T metricHypot(T)(const T x, const T y) @safe pure nothrow @nogc
if (isFloatingPoint!T)
{
    static if (__VERSION__ == 2111)
    {
        import core.math : fabs;
        import std.math.traits : isNaN;

        T u = fabs(x);
        T v = fabs(y);

        if (!(u >= v))
        {
            v = u;
            u = fabs(y);

            if (u == T.infinity)
                return u;
            if (v == T.infinity)
                return v;
            if (u.isNaN || v.isNaN)
                return T.nan;
        }

        /*
         * Use the ratio form instead of u * epsilon > v. For the smallest
         * subnormal, u * epsilon can itself underflow to zero, while v / u
         * remains usable for the affected negligible-component decision.
         */
        if (u != 0 && v / u < T.epsilon)
            return u;
    }

    return hypot(x, y);
}

private ulong orderedKey(T)(T value) @trusted pure nothrow @nogc
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    alias U = Unqual!T;
    U unqualifiedValue = cast(U)value;

    static if (is(U == float))
    {
        enum uint sign = 0x8000_0000u;
        const uint bits = bitCast!uint(unqualifiedValue);
        const uint key = (bits & sign) != 0
            ? (~bits + 1u)
            : (bits | sign);
        return cast(ulong)key;
    }
    else
    {
        enum ulong sign = 0x8000_0000_0000_0000UL;
        const ulong bits = bitCast!ulong(unqualifiedValue);
        return (bits & sign) != 0
            ? (~bits + 1UL)
            : (bits | sign);
    }
}

ulong ulpDistance(T)(T actual, real reference) @safe pure nothrow @nogc
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    alias U = Unqual!T;
    const U rounded = cast(U)reference;

    if (actual.isNaN || rounded.isNaN)
        return ulong.max;

    // Treat +0 and -0 as zero ULP apart for ordinary numerical diagnostics.
    if (actual == rounded)
        return 0;

    const ulong a = orderedKey(actual);
    const ulong b = orderedKey(rounded);
    return a >= b ? a - b : b - a;
}

real absoluteError(T)(T actual, real reference) @safe pure nothrow @nogc
if (isFloatingPoint!(Unqual!T))
{
    import core.math : fabs;
    return fabs(cast(real)actual - reference);
}

real relativeError(T)(T actual, real reference) @safe pure nothrow @nogc
if (isFloatingPoint!(Unqual!T))
{
    import core.math : fabs;

    if (reference == 0)
        return real.nan;

    return fabs(cast(real)actual - reference) / fabs(reference);
}

real circularDegreesError(real actual, real reference)
@safe pure nothrow @nogc
{
    import core.math : fabs;

    if (actual.isNaN || reference.isNaN)
        return real.nan;

    real delta = fabs(actual - reference);

    // C1 reports canonical directions, so a compact reduction is sufficient.
    while (delta >= 360.0L)
        delta -= 360.0L;

    return delta > 180.0L ? 360.0L - delta : delta;
}

void reportScalar(T)(string label, T actual, real reference)
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    writefln(
        "%-44s actual=% .21g reference=% .21g abs=% .6e rel=% .6e ulp_to_rounded_ref=%s",
        label,
        cast(real)actual,
        reference,
        absoluteError(actual, reference),
        relativeError(actual, reference),
        ulpDistance(actual, reference)
    );
}

void reportAngle(T)(string label, T actual, real reference)
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    writefln(
        "%-44s actual=% .21g reference=% .21g circular_deg=% .6e ulp_to_rounded_ref=%s",
        label,
        cast(real)actual,
        reference,
        circularDegreesError(cast(real)actual, reference),
        ulpDistance(actual, reference)
    );
}
