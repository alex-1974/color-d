module app;

import std.math :
    atan2,
    cos,
    PI,
    pow,
    sin,
    sqrt;

import std.stdio : writeln;
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

void main()
{
    writeln("=== R0.8 GAMUT SEMANTICS ===");

    writeln;
    writeln("=== LAYOUT ===");
    writeln("SRgbf:        ", SRgbf.sizeof);
    writeln("SRgbd:        ", SRgbd.sizeof);
    writeln("LinearSRgbf:  ", LinearSRgbf.sizeof);
    writeln("LinearSRgbd:  ", LinearSRgbd.sizeof);
    writeln("Oklchf:       ", Oklchf.sizeof);
    writeln("Oklchd:       ", Oklchd.sizeof);

    writeln;
    writeln("=== DETECTION ===");
    writeln("black strict:       ", strictBlack.inSrgbGamut);
    writeln("white strict:       ", strictWhite.inSrgbGamut);
    writeln("outside low:        ", strictOutsideLow.inSrgbGamut);
    writeln("outside high:       ", strictOutsideHigh.inSrgbGamut);
    writeln("tiny low strict:    ", tinyLow.inSrgbGamut);
    writeln("tiny low eps 1e-14: ", tinyLow.inSrgbGamut(1e-14));
    writeln("tiny high strict:   ", tinyHigh.inSrgbGamut);
    writeln("tiny high eps:      ", tinyHigh.inSrgbGamut(1e-14));

    writeln;
    writeln("=== NON-FINITE ===");
    writeln(
        "NaN gamut: ",
        LinearSRgbd(double.nan, 0.5, 0.5)
            .inSrgbGamut);

    writeln(
        "+Inf gamut: ",
        LinearSRgbd(double.infinity, 0.5, 0.5)
            .inSrgbGamut);

    writeln(
        "-Inf gamut: ",
        LinearSRgbd(-double.infinity, 0.5, 0.5)
            .inSrgbGamut);

    writeln;
    writeln("=== ENCODED / LINEAR EQUIVALENCE ===");
    writeln("encoded ordinary: ", encodedOrdinary.inSrgbGamut);
    writeln("linear ordinary:  ", linearOrdinary.inSrgbGamut);
    writeln("encoded outside:  ", encodedOutside.inSrgbGamut);
    writeln("linear outside:   ", linearOutside.inSrgbGamut);

    writeln;
    writeln("=== CLIPPING ===");
    writeln(
        "input:   ",
        LinearSRgbd(-0.2, 0.4, 1.3));
    writeln("clipped: ", clipped);
    writeln(
        "idempotent: ",
        clippedAgain == clipped);

    writeln;
    writeln("=== DELTA E OK ===");
    writeln("reference 0.1: ", deltaEOK(deA, deB));

    writeln;
    writeln("=== MAPPING ===");

    printMapping(
        "published yellow",
        yellow);

    writeln;

    printMapping(
        "high-chroma red",
        Oklchd(
            0.65,
            0.35,
            OklabHued(25)));

    writeln;

    printMapping(
        "high-chroma green",
        Oklchd(
            0.75,
            0.35,
            OklabHued(145)));

    writeln;

    printMapping(
        "high-chroma blue",
        Oklchd(
            0.55,
            0.35,
            OklabHued(265)));

    writeln;

    printMapping(
        "near white",
        Oklchd(
            0.97,
            0.15,
            OklabHued(40)));

    writeln;

    printMapping(
        "near black",
        Oklchd(
            0.08,
            0.12,
            OklabHued(300)));

    writeln;
    writeln("=== ALPHA ===");
    writeln("input alpha: ", alphaYellow.alpha);
    writeln("local alpha: ", alphaLocal.alpha);
    writeln("ray alpha:   ", alphaRay.alpha);

    writeln;
    writeln("=== ITERATION SUMMARY ===");
    writeln(
        "yellow local/ray: ",
        yellowLocal.iterations,
        " / ",
        yellowRay.iterations);

    writeln;
    writeln("=== FLOAT ===");
    writeln(
        "yellow ray float: ",
        yellowRayF.color,
        " iterations=",
        yellowRayF.iterations,
        " success=",
        yellowRayF.success);

    writeln;
    writeln("=== CTFE ===");
    writeln("static assertions passed if executable built");

    writeln;
    writeln("R0.8 runtime checks complete.");
}
