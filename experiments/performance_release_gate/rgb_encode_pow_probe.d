// Focused R4 audit probe for the sRGB linear -> encoded transfer power path.
//
// Question:
// Does the same LDC llvm_pow route already validated for sRGB decoding also
// remove the Phobos floating/floating pow bottleneck for the reciprocal-2.4
// encoding exponent without weakening numerical semantics?
//
// This is experiment code, not production policy.

module srgb_encode_pow_probe;

import ldc.intrinsics : llvm_pow;
import std.conv : bitCast;
import std.datetime.stopwatch : AutoStart, StopWatch;
import std.math : isNaN, pow;
import std.stdio : writefln, writeln;

enum sampleCount = 1_000_000;
enum benchCount = 8_192;
enum repetitions = 500;
enum rounds = 5;

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

private T phobosPowInv24(T)(T base)
@safe pure nothrow @nogc
{
    return cast(T)pow(base, cast(T)(1.0L / 2.4L));
}

private T ldcPowInv24(T)(T base)
@safe pure nothrow @nogc
{
    if (__ctfe)
        return phobosPowInv24(base);

    return llvm_pow!T(base, cast(T)(1.0L / 2.4L));
}

private T encodePhobos(T)(T linear)
@safe pure nothrow @nogc
{
    const T absLinear = magnitude(linear);

    if (absLinear <= cast(T)0.0031308)
        return linear * cast(T)12.92;

    const T encodedMagnitude =
        cast(T)1.055 *
        phobosPowInv24(absLinear) -
        cast(T)0.055;

    return signOf(linear) * encodedMagnitude;
}

private T encodeLdc(T)(T linear)
@safe pure nothrow @nogc
{
    const T absLinear = magnitude(linear);

    if (absLinear <= cast(T)0.0031308)
        return linear * cast(T)12.92;

    const T encodedMagnitude =
        cast(T)1.055 *
        ldcPowInv24(absLinear) -
        cast(T)0.055;

    return signOf(linear) * encodedMagnitude;
}

private uint nextRandom(ref uint state)
@safe nothrow @nogc
{
    state =
        state * 1_664_525U +
        1_013_904_223U;

    return state;
}

private T generatedInput(T)(ref uint state)
@safe nothrow @nogc
{
    const uint bits = nextRandom(state) & 0x00FF_FFFFU;
    const T unit =
        cast(T)bits /
        cast(T)0x00FF_FFFFU;

    // Exercise both signs and an extended finite range well beyond [0, 1].
    return cast(T)-4 + cast(T)8 * unit;
}

private ulong orderedBits(double value)
@safe pure nothrow @nogc
{
    const ulong bits = bitCast!ulong(value);
    return (bits & (1UL << 63)) != 0
        ? ~bits
        : bits | (1UL << 63);
}

private uint orderedBits(float value)
@safe pure nothrow @nogc
{
    const uint bits = bitCast!uint(value);
    return (bits & (1U << 31)) != 0
        ? ~bits
        : bits | (1U << 31);
}

private ulong ulpDistance(double a, double b)
@safe pure nothrow @nogc
{
    const ulong x = orderedBits(a);
    const ulong y = orderedBits(b);
    return x >= y ? x - y : y - x;
}

private uint ulpDistance(float a, float b)
@safe pure nothrow @nogc
{
    const uint x = orderedBits(a);
    const uint y = orderedBits(b);
    return x >= y ? x - y : y - x;
}

private bool sameSpecialClass(T)(T a, T b)
@safe pure nothrow @nogc
{
    if (isNaN(a) || isNaN(b))
        return isNaN(a) && isNaN(b);

    if (a == T.infinity || a == -T.infinity ||
        b == T.infinity || b == -T.infinity)
    {
        return a == b;
    }

    if (a == cast(T)0 && b == cast(T)0)
    {
        return
            bitCast!(static if (is(T == float)) uint else ulong)(a) ==
            bitCast!(static if (is(T == float)) uint else ulong)(b);
    }

    return true;
}

private bool validate(T)(string scalarName)
{
    uint state = 0xC01D_0017U;
    ulong maxUlp = 0;
    size_t finiteMismatches = 0;

    foreach (_; 0 .. sampleCount)
    {
        const T input = generatedInput!T(state);
        const T reference = encodePhobos(input);
        const T candidate = encodeLdc(input);

        if (reference == reference && candidate == candidate &&
            reference != T.infinity && reference != -T.infinity &&
            candidate != T.infinity && candidate != -T.infinity)
        {
            const ulong distance = cast(ulong)ulpDistance(reference, candidate);
            if (distance > maxUlp)
                maxUlp = distance;

            if (distance > 1)
                ++finiteMismatches;
        }
        else if (!sameSpecialClass(reference, candidate))
        {
            ++finiteMismatches;
        }
    }

    const T[9] specials = [
        cast(T)0.0,
        -cast(T)0.0,
        cast(T)0.0031308,
        -cast(T)0.0031308,
        cast(T)1,
        cast(T)-1,
        T.infinity,
        -T.infinity,
        T.nan
    ];

    size_t specialMismatches = 0;
    foreach (input; specials)
    {
        const T reference = encodePhobos(input);
        const T candidate = encodeLdc(input);

        if (!sameSpecialClass(reference, candidate))
            ++specialMismatches;
    }

    writefln(
        "%s numerical: samples=%s max_ulp=%s finite_over_1ulp=%s special_mismatches=%s",
        scalarName,
        sampleCount,
        maxUlp,
        finiteMismatches,
        specialMismatches
    );

    return finiteMismatches == 0 && specialMismatches == 0;
}

private double timePhobos(T)(const(T)[] values, ref T checksum)
{
    StopWatch sw(AutoStart.yes);

    foreach (_; 0 .. repetitions)
    {
        foreach (value; values)
            checksum += encodePhobos(value);
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * repetitions);
}

private double timeLdc(T)(const(T)[] values, ref T checksum)
{
    StopWatch sw(AutoStart.yes);

    foreach (_; 0 .. repetitions)
    {
        foreach (value; values)
            checksum += encodeLdc(value);
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(values.length * repetitions);
}

private void benchmark(T)(string scalarName)
{
    T[benchCount] values;
    uint state = 0xC01D_0018U;

    foreach (ref value; values)
        value = generatedInput!T(state);

    T checksum = cast(T)0;

    foreach (round; 0 .. rounds)
    {
        double phobosNs;
        double ldcNs;

        // Balance order across rounds to reduce systematic order bias.
        if ((round & 1) == 0)
        {
            phobosNs = timePhobos(values[], checksum);
            ldcNs = timeLdc(values[], checksum);
        }
        else
        {
            ldcNs = timeLdc(values[], checksum);
            phobosNs = timePhobos(values[], checksum);
        }

        writefln(
            "%s round %s: phobos=%.3f ns/component ldc_llvm=%.3f ns/component ratio=%.3f",
            scalarName,
            round + 1,
            phobosNs,
            ldcNs,
            phobosNs / ldcNs
        );
    }

    writeln(scalarName, " checksum=", checksum);
}

enum ctfeProbe = encodeLdc!double(0.25);
static assert(ctfeProbe == encodePhobos!double(0.25));

void main()
{
    writeln("=== color-d sRGB encode pow audit ===");

    if (!validate!double("double"))
        assert(0, "double numerical validation failed");

    if (!validate!float("float"))
        assert(0, "float numerical validation failed");

    benchmark!double("double");
    benchmark!float("float");
}
