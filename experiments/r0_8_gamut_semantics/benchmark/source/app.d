module app;

import std.math :
    atan2,
    cos,
    PI,
    pow,
    sin,
    sqrt;

import std.stdio : writeln;
import core.time : MonoTime;
import std.traits : Unqual;


enum bool isColorScalar(T) =
    is(Unqual!T == float) || is(Unqual!T == double);


// ==========================================================================
// Value types
// ==========================================================================

struct SRgb(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}

struct LinearSRgb(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}

struct XyzD65(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T x;
    T y;
    T z;
}

struct Oklab(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T a;
    T b;
}

struct OklabHue(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T degrees;
}

struct Oklch(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T c;
    OklabHue!T h;
}

struct Alpha(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}

struct MapResult(T)
if (isColorScalar!T)
{
    LinearSRgb!T color;
    uint iterations;
    bool success;
}

struct RayIntersection(T)
if (isColorScalar!T)
{
    LinearSRgb!T color;
    bool found;
}


alias SRgbf       = SRgb!float;
alias SRgbd       = SRgb!double;
alias LinearSRgbf = LinearSRgb!float;
alias LinearSRgbd = LinearSRgb!double;
alias XyzD65f     = XyzD65!float;
alias XyzD65d     = XyzD65!double;
alias Oklabf      = Oklab!float;
alias Oklabd      = Oklab!double;
alias Oklchf      = Oklch!float;
alias Oklchd      = Oklch!double;
alias OklabHuef   = OklabHue!float;
alias OklabHued   = OklabHue!double;


// ==========================================================================
// Scalar helpers
// ==========================================================================

@safe pure nothrow @nogc
Unqual!T magnitude(T)(T value)
if (isColorScalar!T)
{
    return value < cast(T)0 ? -value : value;
}

@safe pure nothrow @nogc
Unqual!T minimum(T)(T a, T b)
if (isColorScalar!T)
{
    return a < b ? a : b;
}

@safe pure nothrow @nogc
Unqual!T maximum(T)(T a, T b)
if (isColorScalar!T)
{
    return a > b ? a : b;
}

@safe pure nothrow @nogc
bool isFiniteScalar(T)(T value)
if (isColorScalar!T)
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}

@safe pure nothrow @nogc
bool approxEqual(T)(
    T actual,
    T expected,
    T absoluteTolerance,
    T relativeTolerance)
if (isColorScalar!T)
{
    const T diff = magnitude(actual - expected);

    if (diff <= absoluteTolerance)
        return true;

    const T aa = magnitude(actual);
    const T ae = magnitude(expected);

    const T scale = aa > ae ? aa : ae;

    return diff <= relativeTolerance * scale;
}

@safe pure nothrow @nogc
Unqual!T clampFiniteUnit(T)(T value)
if (isColorScalar!T)
{
    /*
     * Non-finite values are deliberately not repaired.
     */
    if (!isFiniteScalar(value))
        return value;

    if (value < cast(T)0)
        return cast(T)0;

    if (value > cast(T)1)
        return cast(T)1;

    return value;
}

@safe pure nothrow @nogc
Unqual!T q(T)(long numerator, long denominator)
if (isColorScalar!T)
{
    return cast(T)numerator / cast(T)denominator;
}

@safe pure nothrow @nogc
Unqual!T cube(T)(T value)
if (isColorScalar!T)
{
    return value * value * value;
}

@safe pure nothrow @nogc
Unqual!T cubeRoot(T)(T value)
if (isColorScalar!T)
{
    if (value == cast(T)0)
        return value;

    const T av =
        value < cast(T)0
            ? -value
            : value;

    const T result = cast(T)pow(
        av,
        cast(T)(1.0L / 3.0L));

    return value < cast(T)0
        ? -result
        : result;
}

@safe pure nothrow @nogc
Unqual!T degreesToRadians(T)(T degrees)
if (isColorScalar!T)
{
    return degrees * cast(T)(PI / 180.0L);
}

@safe pure nothrow @nogc
Unqual!T radiansToDegrees(T)(T radians)
if (isColorScalar!T)
{
    return radians * cast(T)(180.0L / PI);
}

@safe pure nothrow @nogc
Unqual!T normalizePositiveDegrees(T)(T degrees)
if (isColorScalar!T)
{
    T result = degrees % cast(T)360;

    if (result < cast(T)0)
        result += cast(T)360;

    if (result >= cast(T)360)
        result -= cast(T)360;

    return result == cast(T)0
        ? cast(T)0
        : result;
}


// ==========================================================================
// sRGB transfer
// ==========================================================================

@safe pure nothrow @nogc
T decodeSrgbChannel(T)(T encoded)
if (isColorScalar!T)
{
    const T a = magnitude(encoded);

    if (a <= cast(T)0.04045)
        return encoded / cast(T)12.92;

    const T decoded = cast(T)pow(
        (a + cast(T)0.055) / cast(T)1.055,
        cast(T)2.4);

    return encoded < cast(T)0
        ? -decoded
        : decoded;
}

@safe pure nothrow @nogc
T encodeSrgbChannel(T)(T linear)
if (isColorScalar!T)
{
    const T a = magnitude(linear);

    if (a <= cast(T)0.0031308)
        return linear * cast(T)12.92;

    const T encoded =
        cast(T)1.055 *
        cast(T)pow(
            a,
            cast(T)(1.0L / 2.4L)) -
        cast(T)0.055;

    return linear < cast(T)0
        ? -encoded
        : encoded;
}

@safe pure nothrow @nogc
LinearSRgb!T toLinearSRgb(T)(SRgb!T rgb)
if (isColorScalar!T)
{
    return LinearSRgb!T(
        decodeSrgbChannel(rgb.r),
        decodeSrgbChannel(rgb.g),
        decodeSrgbChannel(rgb.b));
}

@safe pure nothrow @nogc
SRgb!T toSRgb(T)(LinearSRgb!T rgb)
if (isColorScalar!T)
{
    return SRgb!T(
        encodeSrgbChannel(rgb.r),
        encodeSrgbChannel(rgb.g),
        encodeSrgbChannel(rgb.b));
}


// ==========================================================================
// Linear sRGB <-> XYZ D65
// ==========================================================================

@safe pure nothrow @nogc
XyzD65!T toXyzD65(T)(LinearSRgb!T rgb)
if (isColorScalar!T)
{
    return XyzD65!T(
        q!T(506752, 1228815) * rgb.r +
        q!T(87881,   245763) * rgb.g +
        q!T(12673,    70218) * rgb.b,

        q!T(87098,   409605) * rgb.r +
        q!T(175762,  245763) * rgb.g +
        q!T(12673,   175545) * rgb.b,

        q!T(7918,    409605) * rgb.r +
        q!T(87881,   737289) * rgb.g +
        q!T(1001167, 1053270) * rgb.b);
}

@safe pure nothrow @nogc
LinearSRgb!T toLinearSRgb(T)(XyzD65!T xyz)
if (isColorScalar!T)
{
    return LinearSRgb!T(
        q!T(12831,    3959)  * xyz.x +
        q!T(-329,      214)  * xyz.y +
        q!T(-1974,    3959)  * xyz.z,

        q!T(-851781, 878810) * xyz.x +
        q!T(1648619, 878810) * xyz.y +
        q!T(36519,   878810) * xyz.z,

        q!T(705,     12673)  * xyz.x +
        q!T(-2585,   12673)  * xyz.y +
        q!T(705,       667)  * xyz.z);
}


// ==========================================================================
// XYZ D65 <-> Oklab
// ==========================================================================

@safe pure nothrow @nogc
Oklab!T toOklab(T)(XyzD65!T xyz)
if (isColorScalar!T)
{
    const T l =
        cast(T)0.8190224379967030 * xyz.x +
        cast(T)0.3619062600528904 * xyz.y -
        cast(T)0.1288737815209879 * xyz.z;

    const T m =
        cast(T)0.0329836539323885 * xyz.x +
        cast(T)0.9292868615863434 * xyz.y +
        cast(T)0.0361446663506424 * xyz.z;

    const T s =
        cast(T)0.0481771893596242 * xyz.x +
        cast(T)0.2642395317527308 * xyz.y +
        cast(T)0.6335478284694309 * xyz.z;

    const T lp = cubeRoot(l);
    const T mp = cubeRoot(m);
    const T sp = cubeRoot(s);

    return Oklab!T(
        cast(T)0.2104542683093140 * lp +
        cast(T)0.7936177747023054 * mp -
        cast(T)0.0040720430116193 * sp,

        cast(T)1.9779985324311684 * lp -
        cast(T)2.4285922420485799 * mp +
        cast(T)0.4505937096174110 * sp,

        cast(T)0.0259040424655478 * lp +
        cast(T)0.7827717124575296 * mp -
        cast(T)0.8086757549230774 * sp);
}

@safe pure nothrow @nogc
XyzD65!T toXyzD65(T)(Oklab!T lab)
if (isColorScalar!T)
{
    const T lp =
        lab.l +
        cast(T)0.3963377773761749 * lab.a +
        cast(T)0.2158037573099136 * lab.b;

    const T mp =
        lab.l -
        cast(T)0.1055613458156586 * lab.a -
        cast(T)0.0638541728258133 * lab.b;

    const T sp =
        lab.l -
        cast(T)0.0894841775298119 * lab.a -
        cast(T)1.2914855480194092 * lab.b;

    const T l = cube(lp);
    const T m = cube(mp);
    const T s = cube(sp);

    return XyzD65!T(
        cast(T)1.2268798758459243 * l -
        cast(T)0.5578149944602171 * m +
        cast(T)0.2813910456659647 * s,

       -cast(T)0.0405757452148008 * l +
        cast(T)1.1122868032803170 * m -
        cast(T)0.0717110580655164 * s,

       -cast(T)0.0763729366746601 * l -
        cast(T)0.4214933324022432 * m +
        cast(T)1.5869240198367816 * s);
}


// ==========================================================================
// Oklab <-> OKLCH
// ==========================================================================

@safe pure nothrow @nogc
Oklch!T toOklch(T)(Oklab!T lab)
if (isColorScalar!T)
{
    const T chroma = cast(T)sqrt(
        lab.a * lab.a +
        lab.b * lab.b);

    if (lab.a == cast(T)0 &&
        lab.b == cast(T)0)
    {
        return Oklch!T(
            lab.l,
            cast(T)0,
            OklabHue!T(cast(T)0));
    }

    const T radians =
        cast(T)atan2(lab.b, lab.a);

    return Oklch!T(
        lab.l,
        chroma,
        OklabHue!T(
            normalizePositiveDegrees(
                radiansToDegrees(radians))));
}

@safe pure nothrow @nogc
Oklab!T toOklab(T)(Oklch!T lch)
if (isColorScalar!T)
{
    const T radians =
        degreesToRadians(lch.h.degrees);

    return Oklab!T(
        lch.l,
        lch.c * cast(T)cos(radians),
        lch.c * cast(T)sin(radians));
}


// ==========================================================================
// Convenience conversion chain
// ==========================================================================

@safe pure nothrow @nogc
Oklab!T toOklab(T)(LinearSRgb!T rgb)
if (isColorScalar!T)
{
    return rgb.toXyzD65.toOklab;
}

@safe pure nothrow @nogc
LinearSRgb!T toLinearSRgb(T)(Oklab!T lab)
if (isColorScalar!T)
{
    return lab.toXyzD65.toLinearSRgb;
}

@safe pure nothrow @nogc
Oklch!T toOklch(T)(LinearSRgb!T rgb)
if (isColorScalar!T)
{
    return rgb.toOklab.toOklch;
}

@safe pure nothrow @nogc
LinearSRgb!T toLinearSRgb(T)(Oklch!T lch)
if (isColorScalar!T)
{
    return lch.toOklab.toLinearSRgb;
}


// ==========================================================================
// Finite checks
// ==========================================================================

@safe pure nothrow @nogc
bool isFinite(T)(LinearSRgb!T rgb)
if (isColorScalar!T)
{
    return
        isFiniteScalar(rgb.r) &&
        isFiniteScalar(rgb.g) &&
        isFiniteScalar(rgb.b);
}

@safe pure nothrow @nogc
bool isFinite(T)(SRgb!T rgb)
if (isColorScalar!T)
{
    return
        isFiniteScalar(rgb.r) &&
        isFiniteScalar(rgb.g) &&
        isFiniteScalar(rgb.b);
}

@safe pure nothrow @nogc
bool isFinite(T)(Oklch!T lch)
if (isColorScalar!T)
{
    return
        isFiniteScalar(lch.l) &&
        isFiniteScalar(lch.c) &&
        isFiniteScalar(lch.h.degrees);
}


// ==========================================================================
// Gamut detection
// ==========================================================================

@safe pure nothrow @nogc
bool inSrgbGamut(T)(LinearSRgb!T rgb)
if (isColorScalar!T)
{
    return
        rgb.isFinite &&
        rgb.r >= cast(T)0 &&
        rgb.r <= cast(T)1 &&
        rgb.g >= cast(T)0 &&
        rgb.g <= cast(T)1 &&
        rgb.b >= cast(T)0 &&
        rgb.b <= cast(T)1;
}

@safe pure nothrow @nogc
bool inSrgbGamut(T)(SRgb!T rgb)
if (isColorScalar!T)
{
    return
        rgb.isFinite &&
        rgb.r >= cast(T)0 &&
        rgb.r <= cast(T)1 &&
        rgb.g >= cast(T)0 &&
        rgb.g <= cast(T)1 &&
        rgb.b >= cast(T)0 &&
        rgb.b <= cast(T)1;
}

@safe pure nothrow @nogc
bool inSrgbGamut(T)(
    LinearSRgb!T rgb,
    T epsilon)
if (isColorScalar!T)
{
    if (!rgb.isFinite)
        return false;

    const T e =
        epsilon < cast(T)0
            ? -epsilon
            : epsilon;

    return
        rgb.r >= -e &&
        rgb.r <= cast(T)1 + e &&
        rgb.g >= -e &&
        rgb.g <= cast(T)1 + e &&
        rgb.b >= -e &&
        rgb.b <= cast(T)1 + e;
}

@safe pure nothrow @nogc
bool inSrgbGamut(T)(Oklch!T lch)
if (isColorScalar!T)
{
    if (!lch.isFinite)
        return false;

    return lch.toLinearSRgb.inSrgbGamut;
}


// ==========================================================================
// Clipping
// ==========================================================================

@safe pure nothrow @nogc
LinearSRgb!T clipToSrgb(T)(LinearSRgb!T rgb)
if (isColorScalar!T)
{
    return LinearSRgb!T(
        clampFiniteUnit(rgb.r),
        clampFiniteUnit(rgb.g),
        clampFiniteUnit(rgb.b));
}

@safe pure nothrow @nogc
SRgb!T clipToSrgb(T)(SRgb!T rgb)
if (isColorScalar!T)
{
    return SRgb!T(
        clampFiniteUnit(rgb.r),
        clampFiniteUnit(rgb.g),
        clampFiniteUnit(rgb.b));
}

@safe pure nothrow @nogc
LinearSRgb!T clipToSrgb(T)(Oklch!T lch)
if (isColorScalar!T)
{
    return lch.toLinearSRgb.clipToSrgb;
}

@safe pure nothrow @nogc
Alpha!(LinearSRgb!T) clipToSrgb(T)(
    Alpha!(LinearSRgb!T) value)
if (isColorScalar!T)
{
    return Alpha!(LinearSRgb!T)(
        value.color.clipToSrgb,
        value.alpha);
}


// ==========================================================================
// deltaEOK
// ==========================================================================

@safe pure nothrow @nogc
T deltaEOK(T)(Oklab!T a, Oklab!T b)
if (isColorScalar!T)
{
    const T dl = a.l - b.l;
    const T da = a.a - b.a;
    const T db = a.b - b.b;

    return cast(T)sqrt(
        dl * dl +
        da * da +
        db * db);
}

@safe pure nothrow @nogc
T clippedDeltaEOK(T)(Oklch!T current)
if (isColorScalar!T)
{
    const auto clipped = current.clipToSrgb;

    return deltaEOK(
        current.toOklab,
        clipped.toOklab);
}


// ==========================================================================
// CSS Local-MINDE
// ==========================================================================

@safe pure nothrow @nogc
MapResult!T gamutMapLocalMinde(T)(Oklch!T origin)
if (isColorScalar!T)
{
    if (!origin.isFinite)
    {
        return MapResult!T(
            origin.toLinearSRgb,
            0,
            false);
    }

    /*
     * Canonicalize negative chroma.
     */
    if (origin.c < cast(T)0)
    {
        origin.c = -origin.c;
        origin.h.degrees += cast(T)180;
    }

    if (origin.l >= cast(T)1)
    {
        return MapResult!T(
            LinearSRgb!T(1, 1, 1),
            0,
            true);
    }

    if (origin.l <= cast(T)0)
    {
        return MapResult!T(
            LinearSRgb!T(0, 0, 0),
            0,
            true);
    }

    if (origin.inSrgbGamut)
    {
        return MapResult!T(
            origin.toLinearSRgb,
            0,
            true);
    }

    enum T JND = cast(T)0.02;
    enum T epsilon = cast(T)0.0001;

    Oklch!T current = origin;

    LinearSRgb!T clipped =
        current.clipToSrgb;

    T difference =
        deltaEOK(
            clipped.toOklab,
            current.toOklab);

    if (difference < JND)
    {
        return MapResult!T(
            clipped,
            0,
            true);
    }

    T low = cast(T)0;
    T high = origin.c;

    bool lowInGamut = true;

    uint iterations = 0;

    while (high - low > epsilon)
    {
        ++iterations;

        const T chroma =
            (low + high) / cast(T)2;

        current.c = chroma;

        if (lowInGamut &&
            current.inSrgbGamut)
        {
            low = chroma;
            continue;
        }

        clipped = current.clipToSrgb;

        difference =
            deltaEOK(
                clipped.toOklab,
                current.toOklab);

        if (difference < JND)
        {
            if (JND - difference < epsilon)
            {
                return MapResult!T(
                    clipped,
                    iterations,
                    true);
            }

            lowInGamut = false;
            low = chroma;
        }
        else
        {
            high = chroma;
        }

        /*
         * Defensive experiment bound only.
         *
         * With finite ordinary colors and the CSS epsilon this should
         * never become relevant.
         */
        if (iterations > 128)
        {
            return MapResult!T(
                clipped,
                iterations,
                false);
        }
    }

    return MapResult!T(
        clipped,
        iterations,
        true);
}


// ==========================================================================
// Ray/cube intersection
// ==========================================================================

@safe pure nothrow @nogc
T rayEpsilon(T)()
if (isColorScalar!T)
{
    static if (is(T == float))
        return cast(T)1e-6;
    else
        return cast(T)1e-12;
}

@safe pure nothrow @nogc
bool insideInterior(T)(
    LinearSRgb!T rgb,
    T low,
    T high)
if (isColorScalar!T)
{
    return
        rgb.isFinite &&
        rgb.r >= low &&
        rgb.r <= high &&
        rgb.g >= low &&
        rgb.g <= high &&
        rgb.b >= low &&
        rgb.b <= high;
}

@safe pure nothrow @nogc
pragma(inline, true)
RayIntersection!T intersectUnitRgbCube(T)(
    LinearSRgb!T start,
    LinearSRgb!T end)
if (isColorScalar!T)
{
    if (!start.isFinite ||
        !end.isFinite)
    {
        return RayIntersection!T(
            LinearSRgb!T.init,
            false);
    }

    const T eps = rayEpsilon!T;

    T[3] a = [
        start.r,
        start.g,
        start.b
    ];

    T[3] b = [
        end.r,
        end.g,
        end.b
    ];

    T[3] direction;

    T tNear = -T.infinity;
    T tFar = T.infinity;

    foreach (i; 0 .. 3)
    {
        const T d = b[i] - a[i];

        direction[i] = d;

        if (magnitude(d) > eps)
        {
            const T invD =
                cast(T)1 / d;

            const T t1 =
                (cast(T)0 - a[i]) * invD;

            const T t2 =
                (cast(T)1 - a[i]) * invD;

            tNear = maximum(
                minimum(t1, t2),
                tNear);

            tFar = minimum(
                maximum(t1, t2),
                tFar);
        }
        else if (
            a[i] < cast(T)0 ||
            a[i] > cast(T)1)
        {
            return RayIntersection!T(
                LinearSRgb!T.init,
                false);
        }
    }

    if (tNear > tFar ||
        tFar < cast(T)0)
    {
        return RayIntersection!T(
            LinearSRgb!T.init,
            false);
    }

    if (tNear < cast(T)0)
        tNear = tFar;

    if (!isFiniteScalar(tNear))
    {
        return RayIntersection!T(
            LinearSRgb!T.init,
            false);
    }

    return RayIntersection!T(
        LinearSRgb!T(
            a[0] + direction[0] * tNear,
            a[1] + direction[1] * tNear,
            a[2] + direction[2] * tNear),
        true);
}


// ==========================================================================
// CSS Ray Trace
// ==========================================================================

@safe pure nothrow @nogc
MapResult!T gamutMapRayTrace(T)(Oklch!T origin)
if (isColorScalar!T)
{
    if (!origin.isFinite)
    {
        return MapResult!T(
            origin.toLinearSRgb,
            0,
            false);
    }

    if (origin.c < cast(T)0)
    {
        origin.c = -origin.c;
        origin.h.degrees += cast(T)180;
    }

    if (origin.l >= cast(T)1)
    {
        return MapResult!T(
            LinearSRgb!T(1, 1, 1),
            0,
            true);
    }

    if (origin.l <= cast(T)0)
    {
        return MapResult!T(
            LinearSRgb!T(0, 0, 0),
            0,
            true);
    }

    const T originalLightness =
        origin.l;

    const T originalHue =
        origin.h.degrees;

    LinearSRgb!T anchor =
        Oklch!T(
            originalLightness,
            cast(T)0,
            OklabHue!T(originalHue))
        .toLinearSRgb;

    LinearSRgb!T originRgb =
        origin.toLinearSRgb;

    uint iterations = 0;
    bool success = true;

    if (!originRgb.inSrgbGamut)
    {
        const T eps =
            rayEpsilon!T;

        const T low =
            cast(T)0 + eps;

        const T high =
            cast(T)1 - eps;

        LinearSRgb!T last =
            originRgb;

        foreach (i; 0 .. 4)
        {
            ++iterations;

            if (i > 0)
            {
                Oklch!T current =
                    originRgb.toOklch;

                current.l =
                    originalLightness;

                current.h.degrees =
                    originalHue;

                originRgb =
                    current.toLinearSRgb;
            }

            const auto intersection =
                intersectUnitRgbCube(
                    anchor,
                    originRgb);

            if (!intersection.found)
            {
                originRgb = last;
                success = false;
                break;
            }

            if (i > 0 &&
                originRgb.insideInterior(
                    low,
                    high))
            {
                anchor = originRgb;
            }

            originRgb =
                intersection.color;

            last =
                intersection.color;
        }
    }

    return MapResult!T(
        originRgb.clipToSrgb,
        iterations,
        success);
}


// ==========================================================================
// Alpha-preserving mapping helpers
// ==========================================================================

@safe pure nothrow @nogc
Alpha!(LinearSRgb!T) gamutMapLocalMinde(T)(
    Alpha!(Oklch!T) value)
if (isColorScalar!T)
{
    return Alpha!(LinearSRgb!T)(
        gamutMapLocalMinde(value.color).color,
        value.alpha);
}

@safe pure nothrow @nogc
Alpha!(LinearSRgb!T) gamutMapRayTrace(T)(
    Alpha!(Oklch!T) value)
if (isColorScalar!T)
{
    return Alpha!(LinearSRgb!T)(
        gamutMapRayTrace(value.color).color,
        value.alpha);
}


// ==========================================================================
// CTFE / invariants
// ==========================================================================

static assert(SRgbf.sizeof == 12);
static assert(SRgbd.sizeof == 24);
static assert(LinearSRgbf.sizeof == 12);
static assert(LinearSRgbd.sizeof == 24);
static assert(Oklchf.sizeof == 12);
static assert(Oklchd.sizeof == 24);


/*
 * Strict target-space detection.
 */
enum strictBlack =
    LinearSRgbd(0, 0, 0);

enum strictWhite =
    LinearSRgbd(1, 1, 1);

enum strictOutsideLow =
    LinearSRgbd(-0.01, 0.5, 0.5);

enum strictOutsideHigh =
    LinearSRgbd(1.01, 0.5, 0.5);

static assert(strictBlack.inSrgbGamut);
static assert(strictWhite.inSrgbGamut);
static assert(!strictOutsideLow.inSrgbGamut);
static assert(!strictOutsideHigh.inSrgbGamut);


/*
 * Strict versus numerical tolerance.
 */
enum tinyLow =
    LinearSRgbd(-1e-15, 0.5, 0.5);

enum tinyHigh =
    LinearSRgbd(
        1.0 + 1e-15,
        0.5,
        0.5);

static assert(!tinyLow.inSrgbGamut);
static assert(!tinyHigh.inSrgbGamut);

static assert(
    tinyLow.inSrgbGamut(1e-14));

static assert(
    tinyHigh.inSrgbGamut(1e-14));


/*
 * Encoded and linear sRGB describe the same target gamut.
 */
enum encodedOrdinary =
    SRgbd(0.2, 0.5, 0.8);

enum linearOrdinary =
    encodedOrdinary.toLinearSRgb;

static assert(encodedOrdinary.inSrgbGamut);
static assert(linearOrdinary.inSrgbGamut);

enum encodedOutside =
    SRgbd(1.1, 0.5, 0.5);

enum linearOutside =
    encodedOutside.toLinearSRgb;

static assert(!encodedOutside.inSrgbGamut);
static assert(!linearOutside.inSrgbGamut);


/*
 * Clipping.
 */
enum clipped =
    LinearSRgbd(-0.2, 0.4, 1.3)
    .clipToSrgb;

static assert(clipped.r == 0);
static assert(clipped.g == 0.4);
static assert(clipped.b == 1);
static assert(clipped.inSrgbGamut);

enum clippedAgain =
    clipped.clipToSrgb;

static assert(clippedAgain == clipped);


/*
 * deltaEOK Euclidean metric.
 */
enum deA =
    Oklabd(0.5, 0.1, -0.1);

enum deB =
    Oklabd(0.6, 0.1, -0.1);

static assert(approxEqual(
    deltaEOK(deA, deB),
    0.1,
    1e-14,
    1e-14));


/*
 * Already in-gamut mapping is identity.
 */
enum ordinaryRgb =
    LinearSRgbd(0.2, 0.4, 0.6);

enum ordinaryLch =
    ordinaryRgb.toOklch;

enum ordinaryLocal =
    gamutMapLocalMinde(ordinaryLch);

enum ordinaryRay =
    gamutMapRayTrace(ordinaryLch);

static assert(ordinaryLocal.success);
static assert(ordinaryRay.success);
static assert(ordinaryLocal.iterations == 0);
static assert(ordinaryRay.iterations == 0);

static assert(approxEqual(
    ordinaryLocal.color.r,
    ordinaryRgb.r,
    1e-12,
    1e-12));

static assert(approxEqual(
    ordinaryRay.color.b,
    ordinaryRgb.b,
    1e-12,
    1e-12));


/*
 * Published high-chroma yellow example from CSS gamut discussion.
 */
enum yellow =
    Oklchd(
        0.96476,
        0.24503,
        OklabHued(110.23));

static assert(!yellow.inSrgbGamut);

enum yellowLocal =
    gamutMapLocalMinde(yellow);

enum yellowRay =
    gamutMapRayTrace(yellow);

static assert(yellowLocal.success);
static assert(yellowRay.success);
static assert(yellowLocal.color.inSrgbGamut);
static assert(yellowRay.color.inSrgbGamut);


/*
 * Lightness extremes.
 */
enum tooLight =
    Oklchd(
        1.2,
        0.2,
        OklabHued(30));

enum tooDark =
    Oklchd(
        -0.2,
        0.2,
        OklabHued(30));

static assert(
    gamutMapLocalMinde(tooLight).color ==
    LinearSRgbd(1, 1, 1));

static assert(
    gamutMapRayTrace(tooDark).color ==
    LinearSRgbd(0, 0, 0));


/*
 * Approximate idempotence.
 */
enum localTwice =
    gamutMapLocalMinde(
        yellowLocal.color.toOklch);

enum rayTwice =
    gamutMapRayTrace(
        yellowRay.color.toOklch);

static assert(
    localTwice.color.inSrgbGamut);

static assert(
    rayTwice.color.inSrgbGamut);


/*
 * Alpha survives gamut mapping unchanged.
 */
enum alphaYellow =
    Alpha!Oklchd(
        yellow,
        0.37);

enum alphaLocal =
    gamutMapLocalMinde(alphaYellow);

enum alphaRay =
    gamutMapRayTrace(alphaYellow);

static assert(alphaLocal.alpha == 0.37);
static assert(alphaRay.alpha == 0.37);


/*
 * Float path.
 */
enum yellowF =
    Oklchf(
        0.96476f,
        0.24503f,
        OklabHuef(110.23f));

enum yellowRayF =
    gamutMapRayTrace(yellowF);

static assert(yellowRayF.success);
static assert(yellowRayF.color.inSrgbGamut);


// ==========================================================================
// Runtime inspection
// ==========================================================================

void printMapping(T)(
    string name,
    Oklch!T input)
if (isColorScalar!T)
{
    const auto inputRgb =
        input.toLinearSRgb;

    const auto local =
        gamutMapLocalMinde(input);

    const auto ray =
        gamutMapRayTrace(input);

    const auto localLch =
        local.color.toOklch;

    const auto rayLch =
        ray.color.toOklch;

    writeln(name);
    writeln("  input OKLCH:  ", input);
    writeln("  input linear: ", inputRgb);
    writeln(
        "  input gamut:  ",
        inputRgb.inSrgbGamut);

    writeln(
        "  local RGB:    ",
        local.color);

    writeln(
        "  local OKLCH:  ",
        localLch);

    writeln(
        "  local iter:   ",
        local.iterations,
        " success=",
        local.success);

    writeln(
        "  local dEOK:   ",
        deltaEOK(
            input.toOklab,
            local.color.toOklab));

    writeln(
        "  ray RGB:      ",
        ray.color);

    writeln(
        "  ray OKLCH:    ",
        rayLch);

    writeln(
        "  ray iter:     ",
        ray.iterations,
        " success=",
        ray.success);

    writeln(
        "  ray dEOK:     ",
        deltaEOK(
            input.toOklab,
            ray.color.toOklab));
}


// ==========================================================================
// Benchmark-only optimized candidates
//
// These are NOT production API candidates yet.
// They must first be checked against the reference implementation.
// ==========================================================================

@safe pure nothrow @nogc
Oklab!(Unqual!T) fixedHueLab(T)(
    T lightness,
    T chroma,
    T cosHue,
    T sinHue)
if (isColorScalar!T)
{
    alias U = Unqual!T;

    return Oklab!U(
        cast(U)lightness,
        cast(U)chroma * cast(U)cosHue,
        cast(U)chroma * cast(U)sinHue);
}


@safe pure nothrow @nogc
MapResult!T gamutMapLocalMindeCachedHue(T)(
    Oklch!T origin)
if (isColorScalar!T)
{
    if (!origin.isFinite)
    {
        return MapResult!T(
            origin.toLinearSRgb,
            0,
            false);
    }

    if (origin.c < cast(T)0)
    {
        origin.c = -origin.c;
        origin.h.degrees += cast(T)180;
    }

    if (origin.l >= cast(T)1)
    {
        return MapResult!T(
            LinearSRgb!T(1, 1, 1),
            0,
            true);
    }

    if (origin.l <= cast(T)0)
    {
        return MapResult!T(
            LinearSRgb!T(0, 0, 0),
            0,
            true);
    }

    const T radians =
        degreesToRadians(origin.h.degrees);

    const T cosHue =
        cast(T)cos(radians);

    const T sinHue =
        cast(T)sin(radians);

    Oklab!T currentLab =
        fixedHueLab(
            origin.l,
            origin.c,
            cosHue,
            sinHue);

    LinearSRgb!T currentRgb =
        currentLab.toLinearSRgb;

    if (currentRgb.inSrgbGamut)
    {
        return MapResult!T(
            currentRgb,
            0,
            true);
    }

    enum T JND = cast(T)0.02;
    enum T epsilon = cast(T)0.0001;

    LinearSRgb!T clipped =
        currentRgb.clipToSrgb;

    T difference =
        deltaEOK(
            clipped.toOklab,
            currentLab);

    if (difference < JND)
    {
        return MapResult!T(
            clipped,
            0,
            true);
    }

    T low = cast(T)0;
    T high = origin.c;

    bool lowInGamut = true;

    uint iterations = 0;

    while (high - low > epsilon)
    {
        ++iterations;

        const T chroma =
            (low + high) /
            cast(T)2;

        currentLab =
            fixedHueLab(
                origin.l,
                chroma,
                cosHue,
                sinHue);

        currentRgb =
            currentLab.toLinearSRgb;

        if (lowInGamut &&
            currentRgb.inSrgbGamut)
        {
            low = chroma;
            continue;
        }

        clipped =
            currentRgb.clipToSrgb;

        difference =
            deltaEOK(
                clipped.toOklab,
                currentLab);

        if (difference < JND)
        {
            if (JND - difference < epsilon)
            {
                return MapResult!T(
                    clipped,
                    iterations,
                    true);
            }

            lowInGamut = false;
            low = chroma;
        }
        else
        {
            high = chroma;
        }

        if (iterations > 128)
        {
            return MapResult!T(
                clipped,
                iterations,
                false);
        }
    }

    return MapResult!T(
        clipped,
        iterations,
        true);
}


@safe pure nothrow @nogc
MapResult!T gamutMapRayTraceNoAtan2(T)(
    Oklch!T origin)
if (isColorScalar!T)
{
    if (!origin.isFinite)
    {
        return MapResult!T(
            origin.toLinearSRgb,
            0,
            false);
    }

    if (origin.c < cast(T)0)
    {
        origin.c = -origin.c;
        origin.h.degrees += cast(T)180;
    }

    if (origin.l >= cast(T)1)
    {
        return MapResult!T(
            LinearSRgb!T(1, 1, 1),
            0,
            true);
    }

    if (origin.l <= cast(T)0)
    {
        return MapResult!T(
            LinearSRgb!T(0, 0, 0),
            0,
            true);
    }

    const T originalLightness =
        origin.l;

    const T radians =
        degreesToRadians(
            origin.h.degrees);

    const T cosHue =
        cast(T)cos(radians);

    const T sinHue =
        cast(T)sin(radians);

    LinearSRgb!T anchor =
        fixedHueLab(
            originalLightness,
            cast(T)0,
            cosHue,
            sinHue)
        .toLinearSRgb;

    LinearSRgb!T originRgb =
        fixedHueLab(
            originalLightness,
            origin.c,
            cosHue,
            sinHue)
        .toLinearSRgb;

    uint iterations = 0;
    bool success = true;

    if (!originRgb.inSrgbGamut)
    {
        const T eps =
            rayEpsilon!T;

        const T low =
            cast(T)0 + eps;

        const T high =
            cast(T)1 - eps;

        LinearSRgb!T last =
            originRgb;

        foreach (i; 0 .. 4)
        {
            ++iterations;

            if (i > 0)
            {
                /*
                 * Reference implementation:
                 *
                 *   LinearRGB -> Oklab -> OKLCH
                 *   replace L/h
                 *   OKLCH -> Oklab -> LinearRGB
                 *
                 * Only chroma from the intermediate color is required.
                 * Avoid atan2 entirely.
                 */
                const Oklab!T currentLab =
                    originRgb.toOklab;

                const T chroma =
                    cast(T)sqrt(
                        currentLab.a * currentLab.a +
                        currentLab.b * currentLab.b);

                originRgb =
                    fixedHueLab(
                        originalLightness,
                        chroma,
                        cosHue,
                        sinHue)
                    .toLinearSRgb;
            }

            const auto intersection =
                intersectUnitRgbCube(
                    anchor,
                    originRgb);

            if (!intersection.found)
            {
                originRgb = last;
                success = false;
                break;
            }

            if (i > 0 &&
                originRgb.insideInterior(
                    low,
                    high))
            {
                anchor =
                    originRgb;
            }

            originRgb =
                intersection.color;

            last =
                intersection.color;
        }
    }

    return MapResult!T(
        originRgb.clipToSrgb,
        iterations,
        success);
}


// ==========================================================================
// Deterministic benchmark dataset
// ==========================================================================

struct Lcg
{
    ulong state;

    @safe pure nothrow @nogc
    uint next()
    {
        state =
            state * 6364136223846793005UL +
            1442695040888963407UL;

        return cast(uint)(state >> 32);
    }

    @safe pure nothrow @nogc
    double unit()
    {
        return
            cast(double)next() /
            cast(double)uint.max;
    }
}


Oklchd[] makeOutOfGamutSamples(
    size_t count)
{
    auto result =
        new Oklchd[count];

    Lcg rng =
        Lcg(0xC010_D008_2026_0008UL);

    size_t n = 0;

    while (n < count)
    {
        const double l =
            0.05 +
            rng.unit() * 0.90;

        const double c =
            0.22 +
            rng.unit() * 0.24;

        const double h =
            rng.unit() * 360.0;

        const candidate =
            Oklchd(
                l,
                c,
                OklabHued(h));

        if (!candidate.inSrgbGamut)
            result[n++] = candidate;
    }

    return result;
}


LinearSRgbd[] makeLinearSamples(
    size_t count)
{
    auto result =
        new LinearSRgbd[count];

    Lcg rng =
        Lcg(0xC010_D008_2026_0009UL);

    foreach (ref value; result)
    {
        value =
            LinearSRgbd(
                rng.unit() * 1.4 - 0.2,
                rng.unit() * 1.4 - 0.2,
                rng.unit() * 1.4 - 0.2);
    }

    return result;
}


// ==========================================================================
// Semantic equivalence check for optimized candidates
// ==========================================================================

void validateOptimizedCandidates(
    const Oklchd[] samples)
{
    double localMaxDelta = 0;
    double rayMaxDelta = 0;

    size_t localFailures = 0;
    size_t rayFailures = 0;

    foreach (sample; samples)
    {
        const baselineLocal =
            gamutMapLocalMinde(sample);

        const fastLocal =
            gamutMapLocalMindeCachedHue(sample);

        if (!baselineLocal.success ||
            !fastLocal.success ||
            !baselineLocal.color.inSrgbGamut ||
            !fastLocal.color.inSrgbGamut)
        {
            ++localFailures;
        }

        const localDelta =
            deltaEOK(
                baselineLocal.color.toOklab,
                fastLocal.color.toOklab);

        if (localDelta > localMaxDelta)
            localMaxDelta = localDelta;


        const baselineRay =
            gamutMapRayTrace(sample);

        const fastRay =
            gamutMapRayTraceNoAtan2(sample);

        if (!baselineRay.success ||
            !fastRay.success ||
            !baselineRay.color.inSrgbGamut ||
            !fastRay.color.inSrgbGamut)
        {
            ++rayFailures;
        }

        const rayDelta =
            deltaEOK(
                baselineRay.color.toOklab,
                fastRay.color.toOklab);

        if (rayDelta > rayMaxDelta)
            rayMaxDelta = rayDelta;
    }

    writeln("=== OPTIMIZATION VALIDATION ===");
    writeln(
        "samples:              ",
        samples.length);

    writeln(
        "Local max deltaEOK:   ",
        localMaxDelta);

    writeln(
        "Local failures:       ",
        localFailures);

    writeln(
        "Ray max deltaEOK:     ",
        rayMaxDelta);

    writeln(
        "Ray failures:         ",
        rayFailures);

    writeln();
}


// ==========================================================================
// Benchmark timing
// ==========================================================================

double elapsedNs(
    MonoTime start,
    MonoTime finish)
{
    return cast(double)(
        (finish - start)
            .total!"nsecs");
}


void printRate(
    string name,
    ulong operations,
    double nanoseconds,
    double checksum)
{
    const double nsPerColor =
        nanoseconds /
        cast(double)operations;

    const double colorsPerSecond =
        1_000_000_000.0 /
        nsPerColor;

    writeln(name);
    writeln(
        "  operations: ",
        operations);

    writeln(
        "  ns/color:   ",
        nsPerColor);

    writeln(
        "  colors/s:   ",
        colorsPerSecond);

    writeln(
        "  checksum:   ",
        checksum);
}


void benchmarkDetection(
    const LinearSRgbd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            sink +=
                value.inSrgbGamut
                    ? 1.0
                    : 0.25;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "inSrgbGamut",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkClip(
    const LinearSRgbd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const mapped =
                value.clipToSrgb;

            sink +=
                mapped.r +
                mapped.g * 0.5 +
                mapped.b * 0.25;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "clipToSrgb",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkOklchToLinear(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const rgb =
                value.toLinearSRgb;

            sink +=
                rgb.r +
                rgb.g * 0.5 +
                rgb.b * 0.25;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Oklch -> LinearSRgb",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkLinearToOklch(
    const LinearSRgbd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const lch =
                value.toOklch;

            sink +=
                lch.l +
                lch.c * 0.5 +
                lch.h.degrees * 0.0001;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "LinearSRgb -> Oklch",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkLocalBaseline(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapLocalMinde(value);

            sink +=
                result.color.r +
                result.color.g * 0.5 +
                result.color.b * 0.25 +
                result.iterations * 0.00001;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Local MINDE baseline",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkLocalCached(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapLocalMindeCachedHue(value);

            sink +=
                result.color.r +
                result.color.g * 0.5 +
                result.color.b * 0.25 +
                result.iterations * 0.00001;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Local MINDE cached hue",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkRayBaseline(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapRayTrace(value);

            sink +=
                result.color.r +
                result.color.g * 0.5 +
                result.color.b * 0.25 +
                result.iterations * 0.00001;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Ray Trace baseline",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkRayNoAtan2(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapRayTraceNoAtan2(value);

            sink +=
                result.color.r +
                result.color.g * 0.5 +
                result.color.b * 0.25 +
                result.iterations * 0.00001;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Ray Trace no atan2",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


// ==========================================================================
// Benchmark main
// ==========================================================================
// ==========================================================================
// Additional datasets
// ==========================================================================

Oklchd[] makeInGamutSamples(
    size_t count)
{
    auto result =
        new Oklchd[count];

    Lcg rng =
        Lcg(0xC010_D008_2026_0010UL);

    size_t n = 0;

    while (n < count)
    {
        /*
         * Stay comfortably away from the cube boundary so this benchmark
         * measures the intended in-gamut fast path rather than FP noise.
         */
        const rgb =
            LinearSRgbd(
                0.05 + rng.unit() * 0.90,
                0.05 + rng.unit() * 0.90,
                0.05 + rng.unit() * 0.90);

        const candidate =
            rgb.toOklch;

        if (candidate.inSrgbGamut)
            result[n++] = candidate;
    }

    return result;
}


Oklchf[] makeOutOfGamutSamplesFloat(
    size_t count)
{
    auto result =
        new Oklchf[count];

    Lcg rng =
        Lcg(0xC010_D008_2026_0011UL);

    size_t n = 0;

    while (n < count)
    {
        const float l =
            cast(float)(
                0.05 +
                rng.unit() * 0.90);

        const float c =
            cast(float)(
                0.22 +
                rng.unit() * 0.24);

        const float h =
            cast(float)(
                rng.unit() * 360.0);

        const candidate =
            Oklchf(
                l,
                c,
                OklabHuef(h));

        if (!candidate.inSrgbGamut)
            result[n++] = candidate;
    }

    return result;
}


LinearSRgbf[] makeLinearSamplesFloat(
    size_t count)
{
    auto result =
        new LinearSRgbf[count];

    Lcg rng =
        Lcg(0xC010_D008_2026_0012UL);

    foreach (ref value; result)
    {
        value =
            LinearSRgbf(
                cast(float)(
                    rng.unit() * 1.4 - 0.2),
                cast(float)(
                    rng.unit() * 1.4 - 0.2),
                cast(float)(
                    rng.unit() * 1.4 - 0.2));
    }

    return result;
}


// ==========================================================================
// Paired float/double datasets
//
// Both scalar types receive the same conceptual input values. Out-of-gamut
// candidates are accepted only when both representations classify them as
// out of the sRGB gamut.
// ==========================================================================

struct PairedOklchSamples
{
    Oklchd[] doubles;
    Oklchf[] floats;
}

struct PairedLinearSamples
{
    LinearSRgbd[] doubles;
    LinearSRgbf[] floats;
}

PairedOklchSamples makePairedOutOfGamutSamples(
    size_t count)
{
    auto doubles =
        new Oklchd[count];

    auto floats =
        new Oklchf[count];

    Lcg rng =
        Lcg(0xC010_D008_2026_0020UL);

    size_t n = 0;

    while (n < count)
    {
        const double l =
            0.05 +
            rng.unit() * 0.90;

        const double c =
            0.22 +
            rng.unit() * 0.24;

        const double h =
            rng.unit() * 360.0;

        const candidateD =
            Oklchd(
                l,
                c,
                OklabHued(h));

        const candidateF =
            Oklchf(
                cast(float)l,
                cast(float)c,
                OklabHuef(
                    cast(float)h));

        if (!candidateD.inSrgbGamut &&
            !candidateF.inSrgbGamut)
        {
            doubles[n] =
                candidateD;

            floats[n] =
                candidateF;

            ++n;
        }
    }

    return PairedOklchSamples(
        doubles,
        floats);
}

PairedLinearSamples makePairedLinearSamples(
    size_t count)
{
    auto doubles =
        new LinearSRgbd[count];

    auto floats =
        new LinearSRgbf[count];

    Lcg rng =
        Lcg(0xC010_D008_2026_0021UL);

    foreach (i; 0 .. count)
    {
        const double r =
            rng.unit() * 1.4 - 0.2;

        const double g =
            rng.unit() * 1.4 - 0.2;

        const double b =
            rng.unit() * 1.4 - 0.2;

        doubles[i] =
            LinearSRgbd(r, g, b);

        floats[i] =
            LinearSRgbf(
                cast(float)r,
                cast(float)g,
                cast(float)b);
    }

    return PairedLinearSamples(
        doubles,
        floats);
}


// ==========================================================================
// Fast-path validation
// ==========================================================================

void validateFastPath(
    const Oklchd[] samples)
{
    size_t failures = 0;
    size_t nonZeroIterations = 0;

    double maxDelta = 0;

    foreach (sample; samples)
    {
        const localBaseline =
            gamutMapLocalMinde(sample);

        const localCached =
            gamutMapLocalMindeCachedHue(sample);

        const rayBaseline =
            gamutMapRayTrace(sample);

        const rayFast =
            gamutMapRayTraceNoAtan2(sample);

        if (!localBaseline.success ||
            !localCached.success ||
            !rayBaseline.success ||
            !rayFast.success)
        {
            ++failures;
        }

        if (localBaseline.iterations != 0 ||
            localCached.iterations != 0 ||
            rayBaseline.iterations != 0 ||
            rayFast.iterations != 0)
        {
            ++nonZeroIterations;
        }

        const original =
            sample.toOklab;

        const candidates = [
            localBaseline.color.toOklab,
            localCached.color.toOklab,
            rayBaseline.color.toOklab,
            rayFast.color.toOklab
        ];

        foreach (candidate; candidates)
        {
            const delta =
                deltaEOK(
                    original,
                    candidate);

            if (delta > maxDelta)
                maxDelta = delta;
        }
    }

    writeln("=== IN-GAMUT FAST-PATH VALIDATION ===");
    writeln("samples:              ", samples.length);
    writeln("failures:             ", failures);
    writeln("non-zero iterations:  ", nonZeroIterations);
    writeln("max deltaEOK:         ", maxDelta);
    writeln();
}


// ==========================================================================
// In-gamut mapping benchmarks
// ==========================================================================

void benchmarkLocalFastBaseline(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapLocalMinde(value);

            sink +=
                result.color.r +
                result.color.g * 0.5 +
                result.color.b * 0.25;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Local MINDE in-gamut baseline",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkLocalFastCached(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapLocalMindeCachedHue(value);

            sink +=
                result.color.r +
                result.color.g * 0.5 +
                result.color.b * 0.25;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Local MINDE in-gamut cached",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkRayFastBaseline(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapRayTrace(value);

            sink +=
                result.color.r +
                result.color.g * 0.5 +
                result.color.b * 0.25;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Ray Trace in-gamut baseline",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkRayFastOptimized(
    const Oklchd[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapRayTraceNoAtan2(value);

            sink +=
                result.color.r +
                result.color.g * 0.5 +
                result.color.b * 0.25;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Ray Trace in-gamut optimized",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


// ==========================================================================
// Float benchmarks
// ==========================================================================

void benchmarkOklchToLinearFloat(
    const Oklchf[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const rgb =
                value.toLinearSRgb;

            sink +=
                cast(double)rgb.r +
                cast(double)rgb.g * 0.5 +
                cast(double)rgb.b * 0.25;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Oklch -> LinearSRgb [float]",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkLinearToOklchFloat(
    const LinearSRgbf[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const lch =
                value.toOklch;

            sink +=
                cast(double)lch.l +
                cast(double)lch.c * 0.5 +
                cast(double)lch.h.degrees * 0.0001;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "LinearSRgb -> Oklch [float]",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkLocalCachedFloat(
    const Oklchf[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapLocalMindeCachedHue(value);

            sink +=
                cast(double)result.color.r +
                cast(double)result.color.g * 0.5 +
                cast(double)result.color.b * 0.25 +
                cast(double)result.iterations * 0.00001;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Local MINDE cached hue [float]",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


void benchmarkRayOptimizedFloat(
    const Oklchf[] samples,
    uint rounds)
{
    double sink = 0;

    const start =
        MonoTime.currTime;

    foreach (_; 0 .. rounds)
    {
        foreach (value; samples)
        {
            const result =
                gamutMapRayTraceNoAtan2(value);

            sink +=
                cast(double)result.color.r +
                cast(double)result.color.g * 0.5 +
                cast(double)result.color.b * 0.25 +
                cast(double)result.iterations * 0.00001;
        }
    }

    const finish =
        MonoTime.currTime;

    printRate(
        "Ray Trace no atan2 [float]",
        cast(ulong)samples.length * rounds,
        elapsedNs(start, finish),
        sink);
}


// ==========================================================================
// Benchmark selector
// ==========================================================================

bool hasArgument(
    string[] args,
    string option)
{
    foreach (arg; args[1 .. $])
    {
        if (arg == option)
            return true;
    }

    return false;
}


bool selected(
    string[] args,
    string option)
{
    if (args.length <= 1)
        return true;

    foreach (arg; args[1 .. $])
    {
        if (arg == option)
            return true;
    }

    return false;
}


// ==========================================================================
// Benchmark main
// ==========================================================================

void main(string[] args)
{
    enum size_t sampleCount = 4096;

    const pairedOutOfGamut =
        makePairedOutOfGamutSamples(
            sampleCount);

    const pairedLinear =
        makePairedLinearSamples(
            sampleCount);

    const outOfGamut =
        pairedOutOfGamut.doubles;

    const outOfGamutF =
        pairedOutOfGamut.floats;

    const linear =
        pairedLinear.doubles;

    const linearF =
        pairedLinear.floats;

    const inGamut =
        makeInGamutSamples(
            sampleCount);

    const bool perfOnly =
        hasArgument(
            args,
            "--perf-only");

    if (!perfOnly)
    {
        validateOptimizedCandidates(
            outOfGamut);

        validateFastPath(
            inGamut);
    }

    const uint cheapRounds =
        perfOnly ? 20_000 : 2_000;

    const uint conversionRounds =
        perfOnly ? 2_000 : 200;

    const uint localRounds =
        perfOnly ? 300 : 30;

    const uint rayRounds =
        perfOnly ? 500 : 50;

    const uint fastRounds =
        perfOnly ? 3_000 : 300;

    writeln("=== R0.8 GAMUT BENCHMARK ===");
    writeln("samples per dataset: ", sampleCount);
    writeln();

    if (selected(args, "--bench=detect"))
    {
        benchmarkDetection(
            linear,
            cheapRounds);
        writeln();
    }

    if (selected(args, "--bench=clip"))
    {
        benchmarkClip(
            linear,
            cheapRounds);
        writeln();
    }

    if (selected(args, "--bench=convert-double"))
    {
        benchmarkOklchToLinear(
            outOfGamut,
            conversionRounds);

        writeln();

        benchmarkLinearToOklch(
            linear,
            conversionRounds);

        writeln();
    }

    if (selected(args, "--bench=convert-float"))
    {
        benchmarkOklchToLinearFloat(
            outOfGamutF,
            conversionRounds);

        writeln();

        benchmarkLinearToOklchFloat(
            linearF,
            conversionRounds);

        writeln();
    }

    if (selected(args, "--bench=local-baseline"))
    {
        benchmarkLocalBaseline(
            outOfGamut,
            localRounds);

        writeln();
    }

    if (selected(args, "--bench=local-cached"))
    {
        benchmarkLocalCached(
            outOfGamut,
            localRounds);

        writeln();
    }

    if (selected(args, "--bench=local-float"))
    {
        benchmarkLocalCachedFloat(
            outOfGamutF,
            localRounds);

        writeln();
    }

    if (selected(args, "--bench=ray-baseline"))
    {
        benchmarkRayBaseline(
            outOfGamut,
            rayRounds);

        writeln();
    }

    if (selected(args, "--bench=ray-optimized"))
    {
        benchmarkRayNoAtan2(
            outOfGamut,
            rayRounds);

        writeln();
    }

    if (selected(args, "--bench=ray-float"))
    {
        benchmarkRayOptimizedFloat(
            outOfGamutF,
            rayRounds);

        writeln();
    }

    if (selected(args, "--bench=fast-local"))
    {
        benchmarkLocalFastBaseline(
            inGamut,
            fastRounds);

        writeln();

        benchmarkLocalFastCached(
            inGamut,
            fastRounds);

        writeln();
    }

    if (selected(args, "--bench=fast-ray"))
    {
        benchmarkRayFastBaseline(
            inGamut,
            fastRounds);

        writeln();

        benchmarkRayFastOptimized(
            inGamut,
            fastRounds);

        writeln();
    }

    writeln("Benchmark complete.");
}
