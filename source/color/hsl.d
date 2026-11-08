/++ HSL and HSV value conversions for encoded sRGB.

 Hues are turns in the interval [0, 1) on conversion output. Saturation,
 lightness, and value are normalized scalar components. Achromatic colors have
 a canonical hue of zero. Conversion is value-based and does not clamp input.
+/
module color.hsl;

private import color.rgb : SRgb, SRgbd;

struct Hsl(T) if (is(T == float) || is(T == double))
{
    T h;
    T s;
    T l;
}

struct Hsv(T) if (is(T == float) || is(T == double))
{
    T h;
    T s;
    T v;
}

alias Hslf = Hsl!float;
alias Hsld = Hsl!double;
alias Hsvf = Hsv!float;
alias Hsvd = Hsv!double;

private T hueWrap(T)(T h) @safe pure nothrow @nogc
{
    while (h < 0) h += 1;
    while (h >= 1) h -= 1;
    return h;
}

private T hueChannel(T)(T p, T q, T t) @safe pure nothrow @nogc
{
    t = hueWrap(t);
    if (t < cast(T)(1.0 / 6.0)) return p + (q - p) * 6 * t;
    if (t < cast(T)(1.0 / 2.0)) return q;
    if (t < cast(T)(2.0 / 3.0)) return p + (q - p) * (cast(T)(2.0 / 3.0) - t) * 6;
    return p;
}

/// Converts encoded sRGB to HSL. Hue is zero for achromatic colors.
Hsl!T toHsl(T)(SRgb!T value) @safe pure nothrow @nogc
{
    const T maxValue = value.r > value.g ? (value.r > value.b ? value.r : value.b)
        : (value.g > value.b ? value.g : value.b);
    const T minValue = value.r < value.g ? (value.r < value.b ? value.r : value.b)
        : (value.g < value.b ? value.g : value.b);
    const T d = maxValue - minValue;
    const T l = (maxValue + minValue) / 2;
    if (d == 0) return Hsl!T(0, 0, l);
    const T s = d / (1 - (l > 0.5 ? 2 * l - 1 : 1 - 2 * l));
    T h;
    if (maxValue == value.r) h = (value.g - value.b) / d + (value.g < value.b ? 6 : 0);
    else if (maxValue == value.g) h = (value.b - value.r) / d + 2;
    else h = (value.r - value.g) / d + 4;
    return Hsl!T(h / 6, s, l);
}

/// Converts HSL to encoded sRGB.
SRgb!T toSRgb(T)(Hsl!T value) @safe pure nothrow @nogc
{
    if (value.s == 0) return SRgb!T(value.l, value.l, value.l);
    const T q = value.l < 0.5 ? value.l * (1 + value.s)
        : value.l + value.s - value.l * value.s;
    const T p = 2 * value.l - q;
    return SRgb!T(hueChannel(p, q, value.h + cast(T)(1.0 / 3.0)),
        hueChannel(p, q, value.h), hueChannel(p, q, value.h - cast(T)(1.0 / 3.0)));
}

/// Converts encoded sRGB to HSV. Hue is zero for achromatic colors.
Hsv!T toHsv(T)(SRgb!T value) @safe pure nothrow @nogc
{
    const T maxValue = value.r > value.g ? (value.r > value.b ? value.r : value.b)
        : (value.g > value.b ? value.g : value.b);
    const T minValue = value.r < value.g ? (value.r < value.b ? value.r : value.b)
        : (value.g < value.b ? value.g : value.b);
    const T d = maxValue - minValue;
    if (d == 0) return Hsv!T(0, 0, maxValue);
    T h;
    if (maxValue == value.r) h = (value.g - value.b) / d + (value.g < value.b ? 6 : 0);
    else if (maxValue == value.g) h = (value.b - value.r) / d + 2;
    else h = (value.r - value.g) / d + 4;
    return Hsv!T(h / 6, d / maxValue, maxValue);
}

/// Converts HSV to encoded sRGB.
SRgb!T toSRgb(T)(Hsv!T value) @safe pure nothrow @nogc
{
    const T h = hueWrap(value.h) * 6;
    const uint sector = cast(uint)h;
    const T f = h - sector;
    const T p = value.v * (1 - value.s);
    const T q = value.v * (1 - value.s * f);
    const T t = value.v * (1 - value.s * (1 - f));
    final switch (sector % 6)
    {
        case 0: return SRgb!T(value.v, t, p);
        case 1: return SRgb!T(q, value.v, p);
        case 2: return SRgb!T(p, value.v, t);
        case 3: return SRgb!T(p, q, value.v);
        case 4: return SRgb!T(t, p, value.v);
        case 5: return SRgb!T(value.v, p, q);
    }
}

@safe pure nothrow @nogc unittest
{
    const rgb = SRgbd(0.2, 0.4, 0.8);
    const hsl = rgb.toHsl;
    const hsv = rgb.toHsv;
    const hslRoundTrip = hsl.toSRgb;
    const hsvRoundTrip = hsv.toSRgb;
    assert(hslRoundTrip.r > rgb.r - 1e-14 && hslRoundTrip.r < rgb.r + 1e-14);
    assert(hslRoundTrip.g > rgb.g - 1e-14 && hslRoundTrip.g < rgb.g + 1e-14);
    assert(hslRoundTrip.b > rgb.b - 1e-14 && hslRoundTrip.b < rgb.b + 1e-14);
    assert(hsvRoundTrip.r > rgb.r - 1e-14 && hsvRoundTrip.r < rgb.r + 1e-14);
    assert(hsvRoundTrip.g > rgb.g - 1e-14 && hsvRoundTrip.g < rgb.g + 1e-14);
    assert(hsvRoundTrip.b > rgb.b - 1e-14 && hsvRoundTrip.b < rgb.b + 1e-14);
    assert(SRgbd(0.4, 0.4, 0.4).toHsl.h == 0);
    assert(SRgbd(0.4, 0.4, 0.4).toHsv.h == 0);
}
