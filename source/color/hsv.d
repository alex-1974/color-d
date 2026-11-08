/++
 HSV color values and conversion to and from encoded sRGB.

 HSV is provided for interoperability, color-pickers, and tools that express
 color by hue, saturation, and value/brightness. It is not a perceptual
 replacement for Oklab or OKLCH. Hue is stored in degrees; conversion
 normalizes complete revolutions and canonicalizes achromatic colors to hue 0.
+/
module color.hsv;

private import color.hsl : hslAbs, hslMax, hslMin, normalizeHslHue;
private import color.rgb : SRgb, SRgbd;

/** HSV values with hue in degrees and saturation/value as ratios. */
struct Hsv(T)
if (is(T == float) || is(T == double))
{
    /// Hue in degrees. It may be raw/unbounded before conversion.
    T h;

    /// Saturation ratio. The conventional range is [0, 1].
    T s;

    /// Value/brightness ratio. The conventional range is [0, 1].
    T v;

    /// Scalar component type.
    alias Scalar = T;
}
/// HSV with `float` components.
alias Hsvf = Hsv!float;

/// HSV with `double` components.
alias Hsvd = Hsv!double;

/// Converts encoded sRGB to HSV.
Hsv!T toHsv(T)(SRgb!T color)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T maximum = hslMax(color.r, hslMax(color.g, color.b));
    const T minimum = hslMin(color.r, hslMin(color.g, color.b));
    const T delta = maximum - minimum;

    if (delta == cast(T)0)
        return Hsv!T(cast(T)0, cast(T)0, maximum);

    const T saturation = maximum == cast(T)0
        ? cast(T)0
        : delta / maximum;

    T hue;
    if (maximum == color.r)
        hue = cast(T)60 * ((color.g - color.b) / delta);
    else if (maximum == color.g)
        hue = cast(T)60 * (((color.b - color.r) / delta) + cast(T)2);
    else
        hue = cast(T)60 * (((color.r - color.g) / delta) + cast(T)4);

    return Hsv!T(normalizeHslHue(hue), saturation, maximum);
}

/// Converts HSV to encoded sRGB without clipping or gamut mapping.
SRgb!T toSRgb(T)(Hsv!T color)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T hue = normalizeHslHue(color.h) / cast(T)60;
    const T chroma = color.v * color.s;
    const T x = chroma *
        (cast(T)1 - hslAbs((hue % cast(T)2) - cast(T)1));
    const T match = color.v - chroma;

    T r;
    T g;
    T b;

    if (hue < cast(T)1)
    {
        r = chroma;
        g = x;
        b = cast(T)0;
    }
    else if (hue < cast(T)2)
    {
        r = x;
        g = chroma;
        b = cast(T)0;
    }
    else if (hue < cast(T)3)
    {
        r = cast(T)0;
        g = chroma;
        b = x;
    }
    else if (hue < cast(T)4)
    {
        r = cast(T)0;
        g = x;
        b = chroma;
    }
    else if (hue < cast(T)5)
    {
        r = x;
        g = cast(T)0;
        b = chroma;
    }
    else
    {
        r = chroma;
        g = cast(T)0;
        b = x;
    }

    return SRgb!T(r + match, g + match, b + match);
}

///
@safe pure nothrow @nogc unittest
{
    const red = SRgbd(1.0, 0.0, 0.0).toHsv;
    assert(red.h == 0.0);
    assert(red.s == 1.0);
    assert(red.v == 1.0);

    const gray = SRgbd(0.4, 0.4, 0.4).toHsv;
    assert(gray.h == 0.0);
    assert(gray.s == 0.0);
    assert(gray.v == 0.4);
}

///
@safe pure nothrow @nogc unittest
{
    const color = Hsvd(-240.0, 1.0, 1.0).toSRgb;
    assert(color.r == 0.0);
    assert(color.g == 1.0);
    assert(color.b == 0.0);
}
