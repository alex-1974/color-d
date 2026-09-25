module common;

import std.conv : bitCast;
import std.math : fabs, isNaN;
import std.traits : Unqual;
import std.stdio : writefln;

struct ScalarObservation(T)
{
    string id;
    T actual;
    real reference;
}

real absoluteError(T)(T actual, real reference)
{
    return fabs(cast(real) actual - reference);
}

real relativeError(T)(T actual, real reference)
{
    const real absRef = fabs(reference);
    if (absRef == 0.0L)
        return real.nan;
    return absoluteError(actual, reference) / absRef;
}

ulong ulpDistance(T)(T actual, real reference)
if (is(Unqual!T == float) || is(Unqual!T == double))
{
    alias U = Unqual!T;
    const U rounded = cast(U)reference;
    if (isNaN(actual) || isNaN(rounded))
        return ulong.max;
    if (actual == rounded)
        return 0;

    static if (is(U == float))
    {
        const uint aBits = bitCast!uint(cast(U)actual);
        const uint bBits = bitCast!uint(rounded);
        const uint ka = (aBits & 0x8000_0000U)
            ? (~aBits + 1U) : (aBits | 0x8000_0000U);
        const uint kb = (bBits & 0x8000_0000U)
            ? (~bBits + 1U) : (bBits | 0x8000_0000U);
        return ka >= kb ? cast(ulong)(ka - kb) : cast(ulong)(kb - ka);
    }
    else
    {
        const ulong aBits = bitCast!ulong(cast(U)actual);
        const ulong bBits = bitCast!ulong(rounded);
        const ulong ka = (aBits & 0x8000_0000_0000_0000UL)
            ? (~aBits + 1UL) : (aBits | 0x8000_0000_0000_0000UL);
        const ulong kb = (bBits & 0x8000_0000_0000_0000UL)
            ? (~bBits + 1UL) : (bBits | 0x8000_0000_0000_0000UL);
        return ka >= kb ? ka - kb : kb - ka;
    }
}

void report(T)(ScalarObservation!T o)
{
    static if (is(Unqual!T == float) || is(Unqual!T == double))
    {
        writefln("%-46s actual=% .17g reference=% .21g abs=% .6e rel=% .6e ulp=%s",
            o.id, o.actual, o.reference, absoluteError(o.actual, o.reference),
            relativeError(o.actual, o.reference),
            ulpDistance(o.actual, o.reference));
    }
    else
    {
        writefln("%-46s actual=% .21g reference=% .21g abs=% .6e rel=% .6e",
            o.id, o.actual, o.reference, absoluteError(o.actual, o.reference),
            relativeError(o.actual, o.reference));
    }
}
