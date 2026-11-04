/++ Explicit YCbCr values and conversion to encoded or linear-light sRGB.

 This module owns value-level color mathematics only. It does not own image
 planes, chroma upsampling, byte decoding, or codec metadata. Samples are
 normalized code values and the matrix/range policy is always explicit.
+/
module color.ycbcr;

private import color.rgb : SRgb, SRgbd, LinearSRgb;

enum YCbCrMatrix { bt601, bt709 }
enum YCbCrRange { full, video }

struct YCbCrPolicy(YCbCrMatrix matrixValue, YCbCrRange rangeValue)
{
    enum matrix = matrixValue;
    enum range = rangeValue;
}

alias Bt601Full = YCbCrPolicy!(YCbCrMatrix.bt601, YCbCrRange.full);
alias Bt601Video = YCbCrPolicy!(YCbCrMatrix.bt601, YCbCrRange.video);
alias Bt709Full = YCbCrPolicy!(YCbCrMatrix.bt709, YCbCrRange.full);
alias Bt709Video = YCbCrPolicy!(YCbCrMatrix.bt709, YCbCrRange.video);

/** Normalized YCbCr samples under an explicit matrix/range policy. */
struct YCbCr(T, Policy)
if ((is(T == float) || is(T == double)) &&
    (is(Policy == Bt601Full) || is(Policy == Bt601Video) ||
     is(Policy == Bt709Full) || is(Policy == Bt709Video)))
{
    alias Scalar = T;
    T y;
    T cb;
    T cr;
}

alias YCbCrf(Policy) = YCbCr!(float, Policy);
alias YCbCrd(Policy) = YCbCr!(double, Policy);

private T normalizeLuma(T, Policy)(T value) @safe pure nothrow @nogc
{
    static if (Policy.range == YCbCrRange.video)
        return (value - cast(T)(16.0 / 255.0)) * cast(T)(255.0 / 219.0);
    else
        return value;
}

private T normalizeChroma(T, Policy)(T value) @safe pure nothrow @nogc
{
    static if (Policy.range == YCbCrRange.video)
        return (value - cast(T)(128.0 / 255.0)) * cast(T)(255.0 / 224.0);
    else
        return value - cast(T)0.5;
}

/** Converts explicit YCbCr samples to encoded sRGB without clipping. */
SRgb!T toSRgb(T, Policy)(YCbCr!(T, Policy) value)
@safe pure nothrow @nogc
{
    const T y = normalizeLuma!(T, Policy)(value.y);
    const T cb = normalizeChroma!(T, Policy)(value.cb);
    const T cr = normalizeChroma!(T, Policy)(value.cr);

    static if (Policy.matrix == YCbCrMatrix.bt709)
        return SRgb!T(y + cast(T)1.5748 * cr,
            y - cast(T)0.187324 * cb - cast(T)0.468124 * cr,
            y + cast(T)1.8556 * cb);
    else
        return SRgb!T(y + cast(T)1.402 * cr,
            y - cast(T)0.344136 * cb - cast(T)0.714136 * cr,
            y + cast(T)1.772 * cb);
}

/// Converts explicit YCbCr samples to linear-light sRGB.
LinearSRgb!T toLinearSRgb(T, Policy)(YCbCr!(T, Policy) value)
@safe pure nothrow @nogc
{
    return toSRgb(value).toLinear;
}

@safe pure nothrow @nogc unittest
{
    assert(YCbCr!(double, Bt601Full)(0.0, 0.5, 0.5).toSRgb ==
        SRgbd(0.0, 0.0, 0.0));
    assert(YCbCr!(double, Bt601Full)(1.0, 0.5, 0.5).toSRgb ==
        SRgbd(1.0, 1.0, 1.0));
    assert(YCbCr!(double, Bt709Video)(16.0 / 255.0, 128.0 / 255.0,
        128.0 / 255.0).toSRgb == SRgbd(0.0, 0.0, 0.0));
}

static assert(!__traits(compiles, YCbCr!int(Bt601Full)));
