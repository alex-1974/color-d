/++ Explicit YCbCr values and conversion to encoded or linear-light sRGB.

 This module owns value-level color mathematics only. It does not own image
 planes, chroma upsampling, byte decoding, or codec metadata. Samples are
 normalized code values in the nominal domain [0, 1], and the matrix/range
 policy is always explicit. Integer code values must be normalized by the
 caller using the actual bit depth and code range; this API intentionally does
 not interpret untyped byte buffers.

 For full range, Y is interpreted as [0, 1] and Cb/Cr are centered at 0.5.
 For video range, the 8-bit-equivalent code points are used: Y=16/255 maps to
 zero and Y=235/255 maps to one; Cb/Cr=128/255 maps to zero and the nominal
 chroma excursion is 224 code values. Values outside those nominal ranges are
 preserved as extended values.

 `toSRgb` returns encoded sRGB values and does not clip, gamut-map, round, or
 quantize. `toSRgbClamped` is the explicit opt-in operation for clipping each
 finite RGB component to [0, 1]; non-finite components remain unchanged.
 `toLinearSRgb` applies the existing sRGB transfer decode. NaN and infinity
 follow the scalar type's IEEE arithmetic and are not repaired.
 Integer sample and integer output semantics are intentionally unsupported.
+/
module color.ycbcr;

private import color.rgb : SRgb, SRgbd, LinearSRgb;
private import std.math : abs, isNaN;

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

/** Normalized YCbCr samples under an explicit matrix/range policy.

 The result of conversion is an encoded RGB triplet, not linear light.
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

@safe pure nothrow @nogc unittest
{
    assert(YCbCr!(double, Bt601Full)(0.0, 0.5, 0.5).toSRgb ==
        SRgbd(0.0, 0.0, 0.0));
    assert(YCbCr!(double, Bt601Full)(1.0, 0.5, 0.5).toSRgb ==
        SRgbd(1.0, 1.0, 1.0));
    assert(YCbCr!(double, Bt709Video)(16.0 / 255.0, 128.0 / 255.0,
        128.0 / 255.0).toSRgb == SRgbd(0.0, 0.0, 0.0));

    const auto white = YCbCr!(double, Bt601Video)(235.0 / 255.0,
        128.0 / 255.0, 128.0 / 255.0).toSRgb;
    assert(white.r > 0.9999 && white.g > 0.9999 && white.b > 0.9999);
    const auto gray = YCbCr!(double, Bt601Full)(0.5, 0.5, 0.5).toSRgb;
    assert(gray.r == 0.5 && gray.g == 0.5 && gray.b == 0.5);

    // Chroma excursions remain extended; this boundary does not clip.
    const auto extended = YCbCr!(double, Bt601Full)(0.5, 1.0, 0.5).toSRgb;
    assert(extended.b > 1.0);
    const auto clipped = YCbCr!(double, Bt601Full)(0.5, 1.0, 0.5)
        .toSRgbClamped;
    assert(clipped.b == 1.0 && clipped.r >= 0.0 && clipped.g >= 0.0);

    // BT.601 reference equations, full range: Y=0.5, Cb=0.5, Cr=1.0.
    // The expected result is (1.202, 0.142932, 0.5) using the documented
    // coefficients, and is intentionally retained outside the unit cube.
    const auto reference = YCbCr!(double, Bt601Full)(0.5, 0.5, 1.0).toSRgb;
    assert(reference.r >= 1.2 && reference.r < 1.203);
    assert(reference.g >= 0.14 && reference.g < 0.1439);
    assert(reference.b == 0.5);

    // Full-range and video-range policies are intentionally distinct types.
    const auto fullBlack = YCbCr!(double, Bt601Full)(16.0 / 255.0,
        128.0 / 255.0, 128.0 / 255.0).toSRgb;
    assert(fullBlack.r != 0.0 || fullBlack.g != 0.0 || fullBlack.b != 0.0);

    // Special values remain visible; no hidden repair policy is applied.
    const auto nanResult = YCbCr!(double, Bt601Full)(double.nan, 0.5,
        0.5).toSRgb;
    assert(isNaN(nanResult.r) && isNaN(nanResult.g) && isNaN(nanResult.b));
    const auto infinityResult = YCbCr!(double, Bt601Full)(double.infinity,
        0.5, 0.5).toSRgb;
    assert(infinityResult.r == double.infinity);
}

static assert(!__traits(compiles, YCbCr!int(Bt601Full)));
static assert(!__traits(compiles, YCbCr!(ubyte, Bt601Full)));
