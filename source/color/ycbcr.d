/++
 Explicit YCbCr values and conversion to encoded and linear-light sRGB.

 YCbCr is a value-level color representation. This module deliberately does
 not own image planes, chroma upsampling, byte decoding, or codec metadata.
 Samples are normalized code values in the nominal domain [0, 1]; callers must
 select the matrix, range, and bit-depth policy explicitly.

 Full range uses Y in [0, 1] and Cb/Cr centered at 0.5. Video range uses the
 legal code interval scaled to the selected bit depth. Extended values are
 preserved by scalar conversion.

 `toSRgb` returns encoded (nonlinear) sRGB and performs no clipping, rounding,
 or quantization. `toSRgbClamped` is the explicit clipping operation for
 callers that need [0, 1] output. `toLinearSRgb` applies the existing sRGB
 transfer decode. NaN and infinity are propagated by scalar IEEE arithmetic.
+/
module color.ycbcr;

private import color.rgb : SRgb, SRgbd, LinearSRgb, toLinear;
private import color.rgb;
private import color.result : ColorResult;
private import std.math : isNaN;

/// Matrix coefficients used by a YCbCr policy.
enum YCbCrMatrix
{
    /// ITU-R BT.601 / SMPTE 170M coefficients.
    bt601,
    /// ITU-R BT.709 coefficients.
    bt709,
    /// ITU-R BT.2020 non-constant-luminance coefficients.
    bt2020
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
struct YCbCrPolicy(YCbCrMatrix matrixValue, YCbCrRange rangeValue,
    uint bitDepthValue = 8)
{
    enum matrix = matrixValue;
    enum range = rangeValue;
    enum bitDepth = bitDepthValue;
}

/// Common explicit policies.
alias Bt601Full = YCbCrPolicy!(YCbCrMatrix.bt601, YCbCrRange.full);
alias Bt601Video = YCbCrPolicy!(YCbCrMatrix.bt601, YCbCrRange.video);
alias Bt709Full = YCbCrPolicy!(YCbCrMatrix.bt709, YCbCrRange.full);
alias Bt709Video = YCbCrPolicy!(YCbCrMatrix.bt709, YCbCrRange.video);
alias Bt2020Full = YCbCrPolicy!(YCbCrMatrix.bt2020, YCbCrRange.full);
alias Bt2020Video = YCbCrPolicy!(YCbCrMatrix.bt2020, YCbCrRange.video);

/// Errors returned when normalized YCbCr values are quantized to code values.
enum YCbCrQuantizationError : ubyte
{
    nonFinite,
    outOfRange
}

/// Packed three-channel code values for a YCbCr policy.
struct QuantizedYCbCr(Policy)
{
    ushort y;
    ushort cb;
    ushort cr;
}

private uint ycbcrMaxCode(Policy)() @safe pure nothrow @nogc
{
    return (1u << Policy.bitDepth) - 1;
}

///
/// Policy contract:
///
/// `Bt601Full` and `Bt709Full` interpret normalized Y as [0, 1], with neutral
/// Cb/Cr at 0.5. `Bt601Video` and `Bt709Video` interpret normalized 8-bit code
/// values using Y=16/255..235/255 and Cb/Cr=16/255..240/255, with neutral
/// chroma at 128/255. The BT.601 coefficients are (1.402, 0.344136, 0.714136,
/// 1.772); BT.709 uses (1.5748, 0.187324, 0.468124, 1.8556).
///
/// The matrix result is encoded sRGB. Use `toLinearSRgb` for linear-light
/// values. No policy is inferred and no integer rounding occurs here.
///

/** Normalized YCbCr samples under an explicit `Policy`.
 *
 * The components are mathematical normalized code values, not bytes. For
 * video range, Y=16/255 and Cb/Cr=128/255 are the nominal black/neutral codes.
 * Construction preserves extended values and performs no clipping.
 */
struct YCbCr(T, Policy)
if ((is(T == float) || is(T == double)) && Policy.bitDepth >= 8 &&
    Policy.bitDepth <= 16)
{
    alias Scalar = T;
    T y;
    T cb;
    T cr;
}

alias YCbCrf(Policy) = YCbCr!(float, Policy);
alias YCbCrd(Policy) = YCbCr!(double, Policy);

/// Decodes integer YCbCr code values into normalized scalar samples.
YCbCr!(T, Policy) toNormalizedYCbCr(T, Policy)(QuantizedYCbCr!Policy value)
@safe pure nothrow @nogc
{
    const T scale = cast(T)ycbcrMaxCode!Policy;
    return YCbCr!(T, Policy)(value.y / scale, value.cb / scale,
        value.cr / scale);
}

private ushort quantizeYCbCr(T)(T value, uint maxCode)
@safe pure nothrow @nogc
{
    return cast(ushort)(value * cast(T)maxCode + cast(T)0.5);
}

/// Quantizes normalized YCbCr samples to the policy's 8--16 bit code values.
ColorResult!(QuantizedYCbCr!Policy, YCbCrQuantizationError)
toQuantizedYCbCr(T, Policy)(YCbCr!(T, Policy) value)
@safe pure nothrow @nogc
{
    if (isNaN(value.y) || isNaN(value.cb) || isNaN(value.cr))
        return ColorResult!(QuantizedYCbCr!Policy,
            YCbCrQuantizationError).failure(
                YCbCrQuantizationError.nonFinite);
    if (value.y < 0 || value.y > 1 || value.cb < 0 || value.cb > 1
        || value.cr < 0 || value.cr > 1)
        return ColorResult!(QuantizedYCbCr!Policy,
            YCbCrQuantizationError).failure(
                YCbCrQuantizationError.outOfRange);

    const auto maxCode = ycbcrMaxCode!Policy;
    return ColorResult!(QuantizedYCbCr!Policy,
        YCbCrQuantizationError).success(QuantizedYCbCr!Policy(
            quantizeYCbCr(value.y, maxCode),
            quantizeYCbCr(value.cb, maxCode),
            quantizeYCbCr(value.cr, maxCode)));
}

private T normalizeLuma(T, Policy)(T value)
@safe pure nothrow @nogc
{
    static if (Policy.range == YCbCrRange.video)
        return (value - cast(T)(16.0 / ((1u << Policy.bitDepth) - 1)))
            * cast(T)(((1u << Policy.bitDepth) - 1)
                / cast(double)(219u << (Policy.bitDepth - 8)));
    else
        return value;
}

private T normalizeChroma(T, Policy)(T value)
@safe pure nothrow @nogc
{
    static if (Policy.range == YCbCrRange.video)
        return (value - cast(T)(128.0 / ((1u << Policy.bitDepth) - 1)))
            * cast(T)(((1u << Policy.bitDepth) - 1)
                / cast(double)(224u << (Policy.bitDepth - 8)));
    else
        return value - cast(T)0.5;
}

private T encodeLuma(T, Policy)(T value)
@safe pure nothrow @nogc
{
    static if (Policy.range == YCbCrRange.video)
        return value * cast(T)(cast(double)(219u << (Policy.bitDepth - 8))
                / ((1u << Policy.bitDepth) - 1))
            + cast(T)(16.0 / ((1u << Policy.bitDepth) - 1));
    else
        return value;
}

private T encodeChroma(T, Policy)(T value)
@safe pure nothrow @nogc
{
    static if (Policy.range == YCbCrRange.video)
        return value * cast(T)(cast(double)(224u << (Policy.bitDepth - 8))
                / ((1u << Policy.bitDepth) - 1))
            + cast(T)(128.0 / ((1u << Policy.bitDepth) - 1));
    else
        return value + cast(T)0.5;
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
    else static if (Policy.matrix == YCbCrMatrix.bt2020)
    {
        return SRgb!T(
            y + cast(T)1.4746 * cr,
            y - cast(T)0.164553 * cb - cast(T)0.571353 * cr,
            y + cast(T)1.8814 * cb
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

/** Converts encoded sRGB to normalized YCbCr samples under `Policy`.
 *
 * The input is encoded (nonlinear) sRGB, not linear-light sRGB. The result is
 * normalized code values: full range uses neutral chroma at 0.5, while video
 * range uses the 8-bit-equivalent code positions 16..235 and 16..240. No
 * clipping, rounding, or byte quantization is performed.
 */
YCbCr!(T, Policy) toYCbCr(Policy, T)(SRgb!T value)
@safe pure nothrow @nogc
{
    T y;
    T cb;
    T cr;

    static if (Policy.matrix == YCbCrMatrix.bt709)
    {
        y = cast(T)0.2126 * value.r + cast(T)0.7152 * value.g
            + cast(T)0.0722 * value.b;
        cb = (value.b - y) / cast(T)1.8556;
        cr = (value.r - y) / cast(T)1.5748;
    }
    else static if (Policy.matrix == YCbCrMatrix.bt2020)
    {
        y = cast(T)0.262 * value.r + cast(T)0.678 * value.g
            + cast(T)0.059 * value.b;
        cb = (value.b - y) / cast(T)1.8814;
        cr = (value.r - y) / cast(T)1.4746;
    }
    else
    {
        y = cast(T)0.299 * value.r + cast(T)0.587 * value.g
            + cast(T)0.114 * value.b;
        cb = (value.b - y) / cast(T)1.772;
        cr = (value.r - y) / cast(T)1.402;
    }

    return YCbCr!(T, Policy)(
        encodeLuma!(T, Policy)(y),
        encodeChroma!(T, Policy)(cb),
        encodeChroma!(T, Policy)(cr)
    );
}

private T clampUnit(T)(T value) @safe pure nothrow @nogc
{
    if (value < cast(T)0)
        return cast(T)0;
    if (value > cast(T)1)
        return cast(T)1;
    return value;
}

/// Converts to encoded sRGB and explicitly clips finite components to [0, 1].
SRgb!T toSRgbClamped(T, Policy)(YCbCr!(T, Policy) value)
@safe pure nothrow @nogc
{
    const auto rgb = toSRgb(value);
    return SRgb!T(clampUnit(rgb.r), clampUnit(rgb.g), clampUnit(rgb.b));
}

/// Converts explicit YCbCr samples to linear-light sRGB.
LinearSRgb!T toLinearSRgb(T, Policy)(YCbCr!(T, Policy) value)
@safe pure nothrow @nogc
{
    return toSRgb(value).toLinear;
}

/// Converts linear-light sRGB to normalized YCbCr using the sRGB transfer curve.
YCbCr!(T, Policy) toYCbCr(Policy, T)(LinearSRgb!T value)
@safe pure nothrow @nogc
{
    return toYCbCr!Policy(color.rgb.toSRgb(value));
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

    const auto videoWhite = YCbCr!(double, Bt601Video)(235.0 / 255.0,
        128.0 / 255.0, 128.0 / 255.0).toSRgb;
    assert(videoWhite.r > 0.9999 && videoWhite.g > 0.9999
        && videoWhite.b > 0.9999);
    const auto extended = YCbCr!(double, Bt601Full)(0.5, 1.0, 0.5).toSRgb;
    assert(extended.b > 1.0);
    assert(YCbCr!(double, Bt601Full)(0.5, 1.0, 0.5).toSRgbClamped.b == 1.0);

    // BT.601 reference equations: Y=0.5, Cb=0.5, Cr=1.0.
    const auto reference = YCbCr!(double, Bt601Full)(0.5, 0.5, 1.0).toSRgb;
    assert(reference.r >= 1.2 && reference.r < 1.203);
    assert(reference.g >= 0.14 && reference.g < 0.1439);
    assert(reference.b == 0.5);

    const auto nanResult = YCbCr!(double, Bt601Full)(double.nan, 0.5,
        0.5).toSRgb;
    assert(isNaN(nanResult.r) && isNaN(nanResult.g) && isNaN(nanResult.b));

    const auto roundTrip = SRgbd(0.2, 0.4, 0.8).toYCbCr!Bt601Full.toSRgb;
    assert(roundTrip.r > 0.199999 && roundTrip.r < 0.200001);
    assert(roundTrip.g > 0.399999 && roundTrip.g < 0.400001);
    assert(roundTrip.b > 0.799999 && roundTrip.b < 0.800001);

    const auto videoRoundTrip =
        SRgbd(0.2, 0.4, 0.8).toYCbCr!Bt709Video.toSRgb;
    assert(videoRoundTrip.r > 0.199999 && videoRoundTrip.r < 0.200001);
    assert(videoRoundTrip.g > 0.399999 && videoRoundTrip.g < 0.400001);
    assert(videoRoundTrip.b > 0.799999 && videoRoundTrip.b < 0.800001);

    const auto bt2020RoundTrip =
        SRgbd(0.2, 0.4, 0.8).toYCbCr!Bt2020Full.toSRgb;
    assert(bt2020RoundTrip.r > 0.199 && bt2020RoundTrip.r < 0.201);
    assert(bt2020RoundTrip.g > 0.399 && bt2020RoundTrip.g < 0.401);
    assert(bt2020RoundTrip.b > 0.799 && bt2020RoundTrip.b < 0.801);

    const auto originalLinear = SRgbd(0.2, 0.4, 0.8).toLinear;
    const auto linearRoundTrip = originalLinear.toYCbCr!Bt709Full.toLinearSRgb;
    assert(linearRoundTrip.r > originalLinear.r - 1e-4
        && linearRoundTrip.r < originalLinear.r + 1e-4);
    assert(linearRoundTrip.g > originalLinear.g - 1e-4
        && linearRoundTrip.g < originalLinear.g + 1e-4);
    assert(linearRoundTrip.b > originalLinear.b - 1e-4
        && linearRoundTrip.b < originalLinear.b + 1e-4);

    const auto code = YCbCr!(double, Bt709Video)(16.0 / 255.0,
        128.0 / 255.0, 128.0 / 255.0).toQuantizedYCbCr;
    assert(code.hasValue);
    assert(code.value().y == 16 && code.value().cb == 128
        && code.value().cr == 128);
    const auto normalized =
        code.value().toNormalizedYCbCr!double;
    assert(normalized.y == 16.0 / 255.0);
    assert(normalized.cb == 128.0 / 255.0);
    assert(normalized.cr == 128.0 / 255.0);
    const auto tenBit = YCbCr!(double, YCbCrPolicy!(YCbCrMatrix.bt2020,
        YCbCrRange.full, 10))(0.5, 0.5, 0.5).toQuantizedYCbCr;
    assert(tenBit.hasValue && tenBit.value().y == 512);
}

static assert(!__traits(compiles, YCbCr!int(Bt601Full)));
static assert(!__traits(compiles, toSRgb(SRgb!float.init)));
