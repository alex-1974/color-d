/++
 Explicit YCbCr values and conversion to encoded and linear-light sRGB.

 YCbCr is a value-level color representation. This module deliberately does
 not own image planes, chroma upsampling, byte decoding, or codec metadata.
 Samples are normalized code values; callers must select the matrix and range
 policy explicitly.
+/
module color.ycbcr;

private import color.rgb : SRgb, SRgbd, LinearSRgb;

/// Matrix coefficients used by a YCbCr policy.
enum YCbCrMatrix
{
    /// ITU-R BT.601 / SMPTE 170M coefficients.
    bt601,
    /// ITU-R BT.709 coefficients.
    bt709
}

/// Interpretation of normalized YCbCr code values.
enum YCbCrRange
{
    /// Y and chroma use the complete normalized code range.
    full,
    /// Y uses codes 16..235 and chroma uses 16..240 (8-bit notation).
    video
}

/// Explicit conversion policy. No policy is inferred from the samples.
struct YCbCrPolicy(YCbCrMatrix matrixValue, YCbCrRange rangeValue)
{
    enum matrix = matrixValue;
    enum range = rangeValue;
}

/// Common explicit policies.
alias Bt601Full = YCbCrPolicy!(YCbCrMatrix.bt601, YCbCrRange.full);
alias Bt601Video = YCbCrPolicy!(YCbCrMatrix.bt601, YCbCrRange.video);
alias Bt709Full = YCbCrPolicy!(YCbCrMatrix.bt709, YCbCrRange.full);
alias Bt709Video = YCbCrPolicy!(YCbCrMatrix.bt709, YCbCrRange.video);

/** Normalized YCbCr samples under an explicit `Policy`.
 *
 * The components are mathematical normalized code values, not bytes. For
 * video range, Y=16/255 and Cb/Cr=128/255 are the nominal black/neutral codes.
 * Construction preserves extended values and performs no clipping.
 */
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

private T normalizeLuma(T, Policy)(T value)
@safe pure nothrow @nogc
{
    static if (Policy.range == YCbCrRange.video)
        return (value - cast(T)(16.0 / 255.0)) * cast(T)(255.0 / 219.0);
    else
        return value;
}

private T normalizeChroma(T, Policy)(T value)
@safe pure nothrow @nogc
{
    static if (Policy.range == YCbCrRange.video)
        return (value - cast(T)(128.0 / 255.0)) * cast(T)(255.0 / 224.0);
    else
        return value - cast(T)0.5;
}

/** Converts explicit YCbCr samples to encoded sRGB.
 *
 * The result is encoded sRGB because YCbCr's matrix conversion produces
 * nonlinear RGB code values. No clipping or gamut mapping is performed.
 */
SRgb!T toSRgb(T, Policy)(YCbCr!(T, Policy) value)
@safe pure nothrow @nogc
{
    const T y = normalizeLuma!(T, Policy)(value.y);
    const T cb = normalizeChroma!(T, Policy)(value.cb);
    const T cr = normalizeChroma!(T, Policy)(value.cr);

    static if (Policy.matrix == YCbCrMatrix.bt709)
    {
        return SRgb!T(
            y + cast(T)1.5748 * cr,
            y - cast(T)0.187324 * cb - cast(T)0.468124 * cr,
            y + cast(T)1.8556 * cb
        );
    }
    else
    {
        return SRgb!T(
            y + cast(T)1.402 * cr,
            y - cast(T)0.344136 * cb - cast(T)0.714136 * cr,
            y + cast(T)1.772 * cb
        );
    }
}

/// Converts explicit YCbCr samples to linear-light sRGB.
LinearSRgb!T toLinearSRgb(T, Policy)(YCbCr!(T, Policy) value)
@safe pure nothrow @nogc
{
    return toSRgb(value).toLinear;
}

@safe pure nothrow @nogc unittest
{
    const black = YCbCr!(double, Bt601Full)(0.0, 0.5, 0.5).toSRgb;
    assert(black == SRgbd(0.0, 0.0, 0.0));

    const white = YCbCr!(double, Bt601Full)(1.0, 0.5, 0.5).toSRgb;
    assert(white == SRgbd(1.0, 1.0, 1.0));

    const limitedBlack =
        YCbCr!(double, Bt709Video)(16.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0)
            .toSRgb;
    assert(limitedBlack == SRgbd(0.0, 0.0, 0.0));
}

static assert(!__traits(compiles, YCbCr!int(Bt601Full)));
static assert(!__traits(compiles, toSRgb(SRgb!float.init)));
