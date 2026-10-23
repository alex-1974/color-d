/++
 HSL color values and conversion to and from encoded sRGB.

 HSL is provided for interoperability, color-pickers, CSS-like input, and
 familiar lightness/saturation editing. It is not a perceptual replacement
 for Oklab or OKLCH. Hue is stored in degrees; conversion normalizes complete
 revolutions to the canonical [0, 360$(RPAREN) interval and canonicalizes achromatic
 colors to hue 0.
+/
module color.hsl;

private import color.rgb : SRgb, SRgbd;

package T hslAbs(T)(const T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return value < cast(T)0 ? -value : value;
}
package T hslMin(T)(const T first, const T second)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return first < second ? first : second;
}

package T hslMax(T)(const T first, const T second)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return first > second ? first : second;
}

package T normalizeHslHue(T)(T degrees)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    T result = degrees % cast(T)360;

    if (result < cast(T)0)
        result += cast(T)360;

    if (result >= cast(T)360)
        result -= cast(T)360;

    return result == cast(T)0 ? cast(T)0 : result;
}

/** HSL values with hue in degrees and saturation/lightness as ratios. */
struct Hsl(T)
if (is(T == float) || is(T == double))
{
    /// Hue in degrees. It may be raw/unbounded before conversion.
    T h;

    /// Saturation ratio. The conventional range is [0, 1].
    T s;

    /// Lightness ratio. The conventional range is [0, 1].
    T l;

    /// Scalar component type.
    alias Scalar = T;
}

/// HSL with `float` components.
alias Hslf = Hsl!float;

/// HSL with `double` components.
alias Hsld = Hsl!double;

/// Converts encoded sRGB to HSL.
Hsl!T toHsl(T)(SRgb!T color)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T maximum = hslMax(color.r, hslMax(color.g, color.b));
    const T minimum = hslMin(color.r, hslMin(color.g, color.b));
    const T delta = maximum - minimum;
    const T lightness = (maximum + minimum) / cast(T)2;

    if (delta == cast(T)0)
        return Hsl!T(cast(T)0, cast(T)0, lightness);

    const T saturation = delta /
        (cast(T)1 - hslAbs(cast(T)2 * lightness - cast(T)1));

    T hue;
    if (maximum == color.r)
        hue = cast(T)60 * ((color.g - color.b) / delta);
    else if (maximum == color.g)
        hue = cast(T)60 * (((color.b - color.r) / delta) + cast(T)2);
    else
        hue = cast(T)60 * (((color.r - color.g) / delta) + cast(T)4);

    return Hsl!T(normalizeHslHue(hue), saturation, lightness);
}

/// Converts HSL to encoded sRGB without clipping or gamut mapping.
SRgb!T toSRgb(T)(Hsl!T color)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T hue = normalizeHslHue(color.h) / cast(T)60;
    const T chroma =
        (cast(T)1 - hslAbs(cast(T)2 * color.l - cast(T)1)) * color.s;
    const T x = chroma *
        (cast(T)1 - hslAbs((hue % cast(T)2) - cast(T)1));
    const T match = color.l - chroma / cast(T)2;

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
    const red = SRgbd(1.0, 0.0, 0.0).toHsl;
    assert(red.h == 0.0);
    assert(red.s == 1.0);
    assert(red.l == 0.5);

    const gray = SRgbd(0.4, 0.4, 0.4).toHsl;
    assert(gray.h == 0.0);
    assert(gray.s == 0.0);
    assert(gray.l == 0.4);
}

///
@safe pure nothrow @nogc unittest
{
    const color = Hsld(360.0 + 120.0, 1.0, 0.5).toSRgb;
    assert(color.r == 0.0);
    assert(color.g == 1.0);
    assert(color.b == 0.0);
}
