// Benchmark-only probe for color-d #5.
//
// The only intended semantic implementation change relative to the original
// R0.9 benchmark is the floating-point power call used by sRGB decoding:
//
//     std.math.pow
//         -> core.stdc.math.pow / powf
//
// This is NOT production policy.  It exists to isolate the measured LDC
// performance gap caused by Phobos floating/floating pow routing through
// _powImpl(real, real).
//
// The wrapper deliberately does not claim pure: the C math binding may expose
// C-library floating environment / errno semantics.  Production architecture
// must be decided separately after numerical, CTFE and attribute validation.

module app;

import std.datetime.stopwatch : StopWatch, AutoStart;
import std.math : pow;
import core.stdc.math : cPow = pow, cPowf = powf;
import std.stdio : writeln;


enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


struct SRgb(T)
if (isColorScalar!T)
{
    T r;
    T g;
    T b;
}


struct LinearSRgb(T)
if (isColorScalar!T)
{
    T r;
    T g;
    T b;
}


struct Wcag2Measurement(T)
if (isColorScalar!T)
{
    T value;
    bool valid;
}


struct CompactWcag2Measurement(T)
if (isColorScalar!T)
{
    T value;

    @property bool valid() const
    @safe pure nothrow @nogc
    {
        return value == value;
    }
}

static assert(
    CompactWcag2Measurement!float.sizeof ==
    float.sizeof
);

static assert(
    CompactWcag2Measurement!double.sizeof ==
    double.sizeof
);


T magnitude(T)(T value)
@safe pure nothrow @nogc
{
    return value < 0 ? -value : value;
}


T signOf(T)(T value)
@safe pure nothrow @nogc
{
    return value < 0 ? cast(T)-1 : cast(T)1;
}


bool finiteValue(T)(T value)
@safe pure nothrow @nogc
{
    return
        value == value &&
        value <= T.max &&
        value >= -T.max;
}


bool isValidWcag2SrgbDomain(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return
        finiteValue(color.r) &&
        finiteValue(color.g) &&
        finiteValue(color.b) &&

        color.r >= cast(T)0 &&
        color.r <= cast(T)1 &&

        color.g >= cast(T)0 &&
        color.g <= cast(T)1 &&

        color.b >= cast(T)0 &&
        color.b <= cast(T)1;
}


bool isValidWcag2LinearSrgbDomain(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return
        finiteValue(color.r) &&
        finiteValue(color.g) &&
        finiteValue(color.b) &&

        color.r >= cast(T)0 &&
        color.r <= cast(T)1 &&

        color.g >= cast(T)0 &&
        color.g <= cast(T)1 &&

        color.b >= cast(T)0 &&
        color.b <= cast(T)1;
}


T libmPow(T)(T base, T exponent)
@trusted nothrow @nogc
if (isColorScalar!T)
{
    static if (is(T == double))
        return cPow(base, exponent);
    else
        return cPowf(base, exponent);
}


T srgbToLinearComponent(T)(T encoded)
@trusted nothrow @nogc
{
    const T absEncoded = magnitude(encoded);

    if (absEncoded <= cast(T)0.04045)
        return encoded / cast(T)12.92;

    const T base =
        (absEncoded + cast(T)0.055) /
        cast(T)1.055;

    return
        signOf(encoded) *
        libmPow!T(base, cast(T)2.4);
}


LinearSRgb!T toLinear(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        srgbToLinearComponent(color.r),
        srgbToLinearComponent(color.g),
        srgbToLinearComponent(color.b)
    );
}


T wcag2RelativeLuminance(T)(LinearSRgb!T color)
@safe pure nothrow @nogc
{
    return
        cast(T)0.2126 * color.r +
        cast(T)0.7152 * color.g +
        cast(T)0.0722 * color.b;
}


T wcag2RelativeLuminance(T)(SRgb!T color)
@safe pure nothrow @nogc
{
    return wcag2RelativeLuminance(
        color.toLinear
    );
}


T wcag2ContrastFromLuminance(T)(T a, T b)
@safe pure nothrow @nogc
{
    const bool aIsLighter = a >= b;

    const T lighter =
        aIsLighter ? a : b;

    const T darker =
        aIsLighter ? b : a;

    return
        (lighter + cast(T)0.05) /
        (darker + cast(T)0.05);
}


T wcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b
)
@safe pure nothrow @nogc
{
    return wcag2ContrastFromLuminance(
        wcag2RelativeLuminance(a),
        wcag2RelativeLuminance(b)
    );
}


pragma(inline, true)
Wcag2Measurement!T checkedWcag2RelativeLuminance(T)(
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2LinearSrgbDomain(color))
    {
        return Wcag2Measurement!T(
            T.nan,
            false
        );
    }

    return Wcag2Measurement!T(
        wcag2RelativeLuminance(color),
        true
    );
}


pragma(inline, true)
Wcag2Measurement!T checkedWcag2RelativeLuminance(T)(
    SRgb!T color
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2SrgbDomain(color))
    {
        return Wcag2Measurement!T(
            T.nan,
            false
        );
    }

    return Wcag2Measurement!T(
        wcag2RelativeLuminance(color),
        true
    );
}


pragma(inline, true)
Wcag2Measurement!T checkedWcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b
)
@safe pure nothrow @nogc
{
    if (
        !isValidWcag2SrgbDomain(a) ||
        !isValidWcag2SrgbDomain(b)
    )
    {
        return Wcag2Measurement!T(
            T.nan,
            false
        );
    }

    return Wcag2Measurement!T(
        wcag2ContrastRatio(a, b),
        true
    );
}


CompactWcag2Measurement!T
compactCheckedWcag2RelativeLuminance(T)(
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2LinearSrgbDomain(color))
    {
        return CompactWcag2Measurement!T(
            T.nan
        );
    }

    return CompactWcag2Measurement!T(
        wcag2RelativeLuminance(color)
    );
}


CompactWcag2Measurement!T
compactCheckedWcag2RelativeLuminance(T)(
    SRgb!T color
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2SrgbDomain(color))
    {
        return CompactWcag2Measurement!T(
            T.nan
        );
    }

    return CompactWcag2Measurement!T(
        wcag2RelativeLuminance(color)
    );
}


CompactWcag2Measurement!T
compactCheckedWcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b
)
@safe pure nothrow @nogc
{
    if (
        !isValidWcag2SrgbDomain(a) ||
        !isValidWcag2SrgbDomain(b)
    )
    {
        return CompactWcag2Measurement!T(
            T.nan
        );
    }

    return CompactWcag2Measurement!T(
        wcag2ContrastRatio(a, b)
    );
}


bool tryWcag2RelativeLuminance(T)(
    LinearSRgb!T color,
    ref T value
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2LinearSrgbDomain(color))
        return false;

    value = wcag2RelativeLuminance(color);
    return true;
}


// Diagnostic candidate:
//
// Same validation as the result-type function, but returns only T.
// NaN means invalid input.
//
// This exists only to isolate whether validation itself or the
// { value, valid } return representation causes code-generation cost.
T nanCheckedWcag2RelativeLuminance(T)(
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2LinearSrgbDomain(color))
        return T.nan;

    return wcag2RelativeLuminance(color);
}


bool tryWcag2RelativeLuminance(T)(
    SRgb!T color,
    ref T value
)
@safe pure nothrow @nogc
{
    if (!isValidWcag2SrgbDomain(color))
        return false;

    value = wcag2RelativeLuminance(color);
    return true;
}


uint nextRandom(ref uint state)
@safe nothrow @nogc
{
    state =
        state * 1664525U +
        1013904223U;

    return state;
}


T randomUnit(T)(ref uint state)
@safe nothrow @nogc
{
    const uint bits =
        nextRandom(state) & 0x00FF_FFFFU;

    return
        cast(T)bits /
        cast(T)0x00FF_FFFFU;
}


enum sampleCount = 8192;
enum repetitions = 1000;


void runBenchmark(T)(string scalarName)
if (isColorScalar!T)
{
    SRgb!T[sampleCount] encoded;
    LinearSRgb!T[sampleCount] linear;

    uint state = 0xC01D_0009U;

    foreach (i; 0 .. sampleCount)
    {
        encoded[i] = SRgb!T(
            randomUnit!T(state),
            randomUnit!T(state),
            randomUnit!T(state)
        );

        linear[i] = encoded[i].toLinear;
    }

    T checksum = cast(T)0;

    StopWatch sw;

    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; linear)
            checksum += wcag2RelativeLuminance(c);
    }

    sw.stop();

    const double linearUncheckedNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; linear)
        {
            const auto result =
                checkedWcag2RelativeLuminance(c);

            checksum += result.value;
        }
    }

    sw.stop();

    const double linearCheckedNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; encoded)
            checksum += wcag2RelativeLuminance(c);
    }

    sw.stop();

    const double encodedUncheckedNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; linear)
        {
            T value = cast(T)0;

            if (tryWcag2RelativeLuminance(c, value))
                checksum += value;
        }
    }

    sw.stop();

    const double linearTryNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; linear)
            checksum +=
                nanCheckedWcag2RelativeLuminance(c);
    }

    sw.stop();

    const double linearNanCheckedNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; encoded)
        {
            const auto result =
                checkedWcag2RelativeLuminance(c);

            checksum += result.value;
        }
    }

    sw.stop();

    const double encodedCheckedNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; encoded)
        {
            T value = cast(T)0;

            if (tryWcag2RelativeLuminance(c, value))
                checksum += value;
        }
    }

    sw.stop();

    const double encodedTryNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (i; 0 .. sampleCount - 1)
        {
            const auto result =
                checkedWcag2ContrastRatio(
                    encoded[i],
                    encoded[i + 1]
                );

            checksum += result.value;
        }
    }

    sw.stop();

    const double contrastCheckedNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)((sampleCount - 1) * repetitions);


    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; linear)
        {
            const auto result =
                compactCheckedWcag2RelativeLuminance(c);

            if (result.valid)
                checksum += result.value;
        }
    }

    sw.stop();

    const double linearCompactNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (c; encoded)
        {
            const auto result =
                compactCheckedWcag2RelativeLuminance(c);

            if (result.valid)
                checksum += result.value;
        }
    }

    sw.stop();

    const double encodedCompactNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(sampleCount * repetitions);

    sw.reset();
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (i; 0 .. sampleCount - 1)
        {
            const auto result =
                compactCheckedWcag2ContrastRatio(
                    encoded[i],
                    encoded[i + 1]
                );

            if (result.valid)
                checksum += result.value;
        }
    }

    sw.stop();

    const double contrastCompactNs =
        cast(double)sw.peek.total!"nsecs" /
        cast(double)((sampleCount - 1) * repetitions);

    writeln(
        scalarName,
        ": linear unchecked = ",
        linearUncheckedNs,
        " ns"
    );

    writeln(
        scalarName,
        ": linear checked   = ",
        linearCheckedNs,
        " ns"
    );

    writeln(
        scalarName,
        ": linear try       = ",
        linearTryNs,
        " ns"
    );

    writeln(
        scalarName,
        ": linear NaN-check = ",
        linearNanCheckedNs,
        " ns"
    );

    writeln(
        scalarName,
        ": encoded unchecked = ",
        encodedUncheckedNs,
        " ns"
    );

    writeln(
        scalarName,
        ": encoded checked   = ",
        encodedCheckedNs,
        " ns"
    );

    writeln(
        scalarName,
        ": encoded try       = ",
        encodedTryNs,
        " ns"
    );

    writeln(
        scalarName,
        ": contrast checked  = ",
        contrastCheckedNs,
        " ns"
    );

    writeln(
        scalarName,
        ": linear compact   = ",
        linearCompactNs,
        " ns"
    );

    writeln(
        scalarName,
        ": encoded compact  = ",
        encodedCompactNs,
        " ns"
    );

    writeln(
        scalarName,
        ": contrast compact = ",
        contrastCompactNs,
        " ns"
    );

    writeln(
        scalarName,
        ": compact sizeof   = ",
        CompactWcag2Measurement!T.sizeof
    );

    writeln(
        scalarName,
        ": checksum = ",
        checksum
    );
}


void main()
{
    writeln(
        "=== color-d R0.9 direct-libm pow probe ==="
    );

    runBenchmark!double("double");
    runBenchmark!float("float");
}
