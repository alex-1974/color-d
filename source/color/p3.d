/++ Display-P3 encoded and linear-light values.

 Display-P3 uses the sRGB transfer curve with a wider D65 gamut. Conversions
 are explicit and preserve out-of-gamut values; no clipping or gamut mapping
 is performed.
+/
module color.p3;

private import color.rgb : SRgb, LinearSRgb, toLinear, toSRgb;
private import color.xyz : toLinearSRgb;
private import color.rgb;
private import color.xyz;
private import color.xyz : XyzD65;

struct DisplayP3(T) if (is(T == float) || is(T == double))
{
    T r;
    T g;
    T b;
    alias Scalar = T;
}

alias DisplayP3f = DisplayP3!float;
alias DisplayP3d = DisplayP3!double;

/// Converts encoded Display-P3 to linear Display-P3.
LinearDisplayP3!T toLinear(T)(DisplayP3!T value)
{
    const auto encoded = color.rgb.toLinear(SRgb!T(value.r, value.g, value.b));
    return LinearDisplayP3!T(encoded.r, encoded.g, encoded.b);
}

struct LinearDisplayP3(T) if (is(T == float) || is(T == double))
{
    T r;
    T g;
    T b;
    alias Scalar = T;
}

alias LinearDisplayP3f = LinearDisplayP3!float;
alias LinearDisplayP3d = LinearDisplayP3!double;

/// Converts linear Display-P3 to encoded Display-P3.
DisplayP3!T toDisplayP3(T)(LinearDisplayP3!T value)
{
    const auto encoded = LinearSRgb!T(value.r, value.g, value.b).toSRgb;
    return DisplayP3!T(encoded.r, encoded.g, encoded.b);
}

/// Converts linear Display-P3 to XYZ D65.
XyzD65!T toXyzD65(T)(LinearDisplayP3!T value)
@safe pure nothrow @nogc
{
    return XyzD65!T(
        cast(T)0.4865709486482162 * value.r + cast(T)0.26566769316909306 * value.g + cast(T)0.1982172852343625 * value.b,
        cast(T)0.2289745640697488 * value.r + cast(T)0.6917385218365064 * value.g + cast(T)0.079286914093745 * value.b,
        cast(T)0.04511338185890264 * value.g + cast(T)1.043944368900976 * value.b);
}

/// Converts XYZ D65 to linear Display-P3.
LinearDisplayP3!T toLinearDisplayP3(T)(XyzD65!T value)
@safe pure nothrow @nogc
{
    return LinearDisplayP3!T(
        cast(T)2.493496911941425 * value.x - cast(T)0.9313836179191239 * value.y - cast(T)0.40271078445071684 * value.z,
        -cast(T)0.8294889695615747 * value.x + cast(T)1.7626640603183463 * value.y + cast(T)0.023624685841943577 * value.z,
        cast(T)0.03584583024378447 * value.x - cast(T)0.07617238926804182 * value.y + cast(T)0.9568845240076872 * value.z);
}

/// Converts encoded Display-P3 to encoded sRGB through XYZ D65.
SRgb!T toSRgb(T)(DisplayP3!T value) @safe pure nothrow @nogc
{
    const auto encoded = color.xyz.toLinearSRgb(
        toXyzD65(color.p3.toLinear(value)));
    return SRgb!T(encoded.r, encoded.g, encoded.b);
}

/// Converts encoded sRGB to encoded Display-P3 through XYZ D65.
DisplayP3!T toDisplayP3(T)(SRgb!T value) @safe pure nothrow @nogc
{
    const auto linear = color.p3.toDisplayP3(
        toLinearDisplayP3(color.xyz.toXyzD65(color.rgb.toLinear(value))));
    return DisplayP3!T(linear.r, linear.g, linear.b);
}

@safe pure nothrow @nogc unittest
{
    const p3 = DisplayP3d(0.2, 0.4, 0.8);
    const encodedRoundTrip = p3.toLinear.toDisplayP3;
    assert(encodedRoundTrip.r > p3.r - 1e-14 && encodedRoundTrip.r < p3.r + 1e-14);
    assert(encodedRoundTrip.g > p3.g - 1e-14 && encodedRoundTrip.g < p3.g + 1e-14);
    assert(encodedRoundTrip.b > p3.b - 1e-14 && encodedRoundTrip.b < p3.b + 1e-14);
    const srgb = p3.toSRgb;
    assert(srgb.r == srgb.r && srgb.g == srgb.g && srgb.b == srgb.b);
}
