module app;

import std.stdio : writeln;

template ColorScalar(T)
{
    enum ColorScalar = is(T == float) || is(T == double);
}

struct SRgb(T)
if (ColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}

struct LinearSRgb(T)
if (ColorScalar!T)
{
    alias Scalar = T;

    T r;
    T g;
    T b;
}

struct Oklab(T)
if (ColorScalar!T)
{
    alias Scalar = T;

    T l;
    T a;
    T b;
}

struct OklabHue(T)
if (ColorScalar!T)
{
    alias Scalar = T;

    T degrees;

    @safe pure nothrow @nogc
    static OklabHue fromDegrees(T degrees)
    {
        return OklabHue(degrees);
    }

    @safe pure nothrow @nogc
    T rawDegrees() const
    {
        return degrees;
    }

    @safe pure nothrow @nogc
    T positiveDegrees() const
    {
        T value = degrees % cast(T) 360;

        if (value < cast(T) 0)
            value += cast(T) 360;

        if (value >= cast(T) 360)
            value -= cast(T) 360;

        return value;
    }
}

struct Oklch(T)
if (ColorScalar!T)
{
    alias Scalar = T;

    T l;
    T c;
    OklabHue!T h;

    @safe pure nothrow @nogc
    bool isAchromatic() const
    {
        return c == cast(T) 0;
    }

    @safe pure nothrow @nogc
    bool isNearAchromatic(T epsilon) const
    {
        T magnitude = c < cast(T) 0 ? -c : c;
        return magnitude <= epsilon;
    }
}

struct Alpha(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}

enum HuePath : ubyte
{
    shorter,
    longer,
    increasing,
    decreasing
}

struct HueEndpoints(T)
if (ColorScalar!T)
{
    T first;
    T second;
}

alias SRgbf       = SRgb!float;
alias SRgbd       = SRgb!double;
alias LinearSRgbf = LinearSRgb!float;
alias LinearSRgbd = LinearSRgb!double;
alias Oklabf      = Oklab!float;
alias Oklabd      = Oklab!double;
alias Oklchf      = Oklch!float;
alias Oklchd      = Oklch!double;
alias OklabHuef   = OklabHue!float;
alias OklabHued   = OklabHue!double;

@safe pure nothrow @nogc
T scalarAbs(T)(T value)
if (ColorScalar!T)
{
    return value < cast(T) 0 ? -value : value;
}

@safe pure nothrow @nogc
bool approx(T)(T a, T b, T epsilon)
if (ColorScalar!T)
{
    return scalarAbs(a - b) <= epsilon;
}

@safe pure nothrow @nogc
T lerp(T)(T a, T b, T t)
if (ColorScalar!T)
{
    return a + (b - a) * t;
}

@safe pure nothrow @nogc
SRgb!T interpolate(T)(SRgb!T a, SRgb!T b, T t)
if (ColorScalar!T)
{
    return SRgb!T(
        lerp(a.r, b.r, t),
        lerp(a.g, b.g, t),
        lerp(a.b, b.b, t)
    );
}

@safe pure nothrow @nogc
LinearSRgb!T interpolate(T)(
    LinearSRgb!T a,
    LinearSRgb!T b,
    T t)
if (ColorScalar!T)
{
    return LinearSRgb!T(
        lerp(a.r, b.r, t),
        lerp(a.g, b.g, t),
        lerp(a.b, b.b, t)
    );
}

@safe pure nothrow @nogc
Oklab!T interpolate(T)(Oklab!T a, Oklab!T b, T t)
if (ColorScalar!T)
{
    return Oklab!T(
        lerp(a.l, b.l, t),
        lerp(a.a, b.a, t),
        lerp(a.b, b.b, t)
    );
}

/*
 * CSS-compatible hue fix-up.
 *
 * The inputs are first reduced to their positive [0, 360) views.
 * The returned values are deliberately allowed outside that range so
 * interpolation can preserve the selected trajectory.
 */
@safe pure nothrow @nogc
HueEndpoints!T adjustedHueEndpoints(T)(
    OklabHue!T first,
    OklabHue!T second,
    HuePath path)
if (ColorScalar!T)
{
    T h1 = first.positiveDegrees();
    T h2 = second.positiveDegrees();
    T delta = h2 - h1;

    final switch (path)
    {
        case HuePath.shorter:
            /*
             * CSS:
             * delta must end in [-180, 180].
             *
             * Exact +/-180-degree ties are retained.
             */
            if (delta > cast(T) 180)
                h1 += cast(T) 360;
            else if (delta < cast(T) -180)
                h2 += cast(T) 360;
            break;

        case HuePath.longer:
            /*
             * CSS:
             * delta ends in (-360,-180] U [180,360).
             *
             * A zero difference takes a complete positive revolution.
             */
            if (delta > cast(T) 0 &&
                delta < cast(T) 180)
            {
                h1 += cast(T) 360;
            }
            else if (delta > cast(T) -180 &&
                     delta <= cast(T) 0)
            {
                h2 += cast(T) 360;
            }
            break;

        case HuePath.increasing:
            /*
             * CSS:
             * delta ends in [0,360).
             */
            if (h2 < h1)
                h2 += cast(T) 360;
            break;

        case HuePath.decreasing:
            /*
             * CSS:
             * delta ends in (-360,0].
             */
            if (h1 < h2)
                h1 += cast(T) 360;
            break;
    }

    return HueEndpoints!T(h1, h2);
}

@safe pure nothrow @nogc
OklabHue!T interpolateHue(T)(
    OklabHue!T first,
    OklabHue!T second,
    T t,
    HuePath path)
if (ColorScalar!T)
{
    auto adjusted = adjustedHueEndpoints(first, second, path);

    return OklabHue!T(
        lerp(adjusted.first, adjusted.second, t)
    );
}

/*
 * Raw hue interpolation deliberately preserves the stored angular
 * displacement rather than reducing the endpoints to [0,360).
 */
@safe pure nothrow @nogc
OklabHue!T interpolateHueRaw(T)(
    OklabHue!T first,
    OklabHue!T second,
    T t)
if (ColorScalar!T)
{
    return OklabHue!T(
        lerp(first.rawDegrees(), second.rawDegrees(), t)
    );
}

@safe pure nothrow @nogc
Oklch!T canonicalized(T)(Oklch!T color)
if (ColorScalar!T)
{
    if (color.c < cast(T) 0)
    {
        color.c = -color.c;
        color.h.degrees += cast(T) 180;
    }

    return color;
}

/*
 * Candidate polar interpolation:
 *
 * - canonicalize negative chroma first;
 * - exact C==0 borrows the chromatic endpoint hue;
 * - no hidden near-achromatic epsilon;
 * - hue-path fix-up is explicit;
 * - output hue is not forcibly normalized.
 */
@safe pure nothrow @nogc
Oklch!T interpolate(T)(
    Oklch!T first,
    Oklch!T second,
    T t,
    HuePath path)
if (ColorScalar!T)
{
    first = canonicalized(first);
    second = canonicalized(second);

    auto h1 = first.h;
    auto h2 = second.h;

    if (first.c == cast(T) 0 &&
        second.c != cast(T) 0)
    {
        h1 = h2;
    }
    else if (second.c == cast(T) 0 &&
             first.c != cast(T) 0)
    {
        h2 = h1;
    }

    return Oklch!T(
        lerp(first.l, second.l, t),
        lerp(first.c, second.c, t),
        interpolateHue(h1, h2, t, path)
    );
}

/*
 * Comparison helper for the negative-chroma research question.
 *
 * This deliberately does NOT canonicalize the inputs.
 */
@safe pure nothrow @nogc
Oklch!T interpolateUncanonicalized(T)(
    Oklch!T first,
    Oklch!T second,
    T t,
    HuePath path)
if (ColorScalar!T)
{
    return Oklch!T(
        lerp(first.l, second.l, t),
        lerp(first.c, second.c, t),
        interpolateHue(first.h, second.h, t, path)
    );
}

/*
 * Alpha-aware interpolation in rectangular spaces.
 *
 * This is interpolation premultiplication, not the R0.6 public candidate
 * compositing representation.
 */
@safe pure nothrow @nogc
Alpha!(LinearSRgb!T) interpolate(T)(
    Alpha!(LinearSRgb!T) first,
    Alpha!(LinearSRgb!T) second,
    T t)
if (ColorScalar!T)
{
    T alpha = lerp(first.alpha, second.alpha, t);

    T r = lerp(
        first.color.r * first.alpha,
        second.color.r * second.alpha,
        t);

    T g = lerp(
        first.color.g * first.alpha,
        second.color.g * second.alpha,
        t);

    T b = lerp(
        first.color.b * first.alpha,
        second.color.b * second.alpha,
        t);

    if (alpha != cast(T) 0)
    {
        r /= alpha;
        g /= alpha;
        b /= alpha;
    }

    return Alpha!(LinearSRgb!T)(
        LinearSRgb!T(r, g, b),
        alpha
    );
}

@safe pure nothrow @nogc
Alpha!(SRgb!T) interpolate(T)(
    Alpha!(SRgb!T) first,
    Alpha!(SRgb!T) second,
    T t)
if (ColorScalar!T)
{
    T alpha = lerp(first.alpha, second.alpha, t);

    T r = lerp(
        first.color.r * first.alpha,
        second.color.r * second.alpha,
        t);

    T g = lerp(
        first.color.g * first.alpha,
        second.color.g * second.alpha,
        t);

    T b = lerp(
        first.color.b * first.alpha,
        second.color.b * second.alpha,
        t);

    if (alpha != cast(T) 0)
    {
        r /= alpha;
        g /= alpha;
        b /= alpha;
    }

    return Alpha!(SRgb!T)(
        SRgb!T(r, g, b),
        alpha
    );
}

@safe pure nothrow @nogc
Alpha!(Oklab!T) interpolate(T)(
    Alpha!(Oklab!T) first,
    Alpha!(Oklab!T) second,
    T t)
if (ColorScalar!T)
{
    T alpha = lerp(first.alpha, second.alpha, t);

    T l = lerp(
        first.color.l * first.alpha,
        second.color.l * second.alpha,
        t);

    T a = lerp(
        first.color.a * first.alpha,
        second.color.a * second.alpha,
        t);

    T b = lerp(
        first.color.b * first.alpha,
        second.color.b * second.alpha,
        t);

    if (alpha != cast(T) 0)
    {
        l /= alpha;
        a /= alpha;
        b /= alpha;
    }

    return Alpha!(Oklab!T)(
        Oklab!T(l, a, b),
        alpha
    );
}

/*
 * Alpha-aware OKLCH interpolation.
 *
 * L and C are premultiplied.
 * Hue is deliberately NOT premultiplied.
 */
@safe pure nothrow @nogc
Alpha!(Oklch!T) interpolate(T)(
    Alpha!(Oklch!T) first,
    Alpha!(Oklch!T) second,
    T t,
    HuePath path)
if (ColorScalar!T)
{
    first.color = canonicalized(first.color);
    second.color = canonicalized(second.color);

    auto h1 = first.color.h;
    auto h2 = second.color.h;

    if (first.color.c == cast(T) 0 &&
        second.color.c != cast(T) 0)
    {
        h1 = h2;
    }
    else if (second.color.c == cast(T) 0 &&
             first.color.c != cast(T) 0)
    {
        h2 = h1;
    }

    auto hue = interpolateHue(h1, h2, t, path);

    T alpha = lerp(first.alpha, second.alpha, t);

    T l = lerp(
        first.color.l * first.alpha,
        second.color.l * second.alpha,
        t);

    T c = lerp(
        first.color.c * first.alpha,
        second.color.c * second.alpha,
        t);

    /*
     * CSS interpolation rule:
     * if interpolated alpha is zero, do not divide.
     */
    if (alpha != cast(T) 0)
    {
        l /= alpha;
        c /= alpha;
    }

    return Alpha!(Oklch!T)(
        Oklch!T(l, c, hue),
        alpha
    );
}

/*
 * Deliberately incorrect straight-alpha interpolation used only for
 * demonstrating the hidden-color problem.
 */
@safe pure nothrow @nogc
Alpha!(LinearSRgb!T) interpolateStraightAlpha(T)(
    Alpha!(LinearSRgb!T) first,
    Alpha!(LinearSRgb!T) second,
    T t)
if (ColorScalar!T)
{
    return Alpha!(LinearSRgb!T)(
        interpolate(first.color, second.color, t),
        lerp(first.alpha, second.alpha, t)
    );
}

static assert(SRgbf.sizeof == 12);
static assert(SRgbd.sizeof == 24);
static assert(OklabHuef.sizeof == 4);
static assert(OklabHued.sizeof == 8);
static assert(Oklchf.sizeof == 12);
static assert(Oklchd.sizeof == 24);
static assert(Alpha!Oklchf.sizeof == 16);
static assert(Alpha!Oklchd.sizeof == 32);

/*
 * Compile-negative same-space contract.
 */
static assert(!__traits(compiles,
    interpolate(
        SRgbd(0, 0, 0),
        LinearSRgbd(1, 1, 1),
        0.5)));

static assert(!__traits(compiles,
    interpolate(
        Oklabd(0, 0, 0),
        Oklchd(1, 0.2, OklabHued(30)),
        0.5)));

static assert(!__traits(compiles,
    interpolate(
        Oklchd(0.5, 0.2, OklabHued(30)),
        Oklchd(0.7, 0.2, OklabHued(90)),
        0.5)));

/*
 * CTFE rectangular interpolation.
 */
enum ctfeLinear = interpolate(
    LinearSRgbd(-0.2, 0.2, 1.2),
    LinearSRgbd(1.4, 0.8, -0.2),
    0.5);

static assert(approx(ctfeLinear.r, 0.6, 1e-12));
static assert(approx(ctfeLinear.g, 0.5, 1e-12));
static assert(approx(ctfeLinear.b, 0.5, 1e-12));

/*
 * Extrapolation is deliberately not clamped.
 */
enum ctfeExtrapolated = interpolate(
    LinearSRgbd(0, 0, 0),
    LinearSRgbd(1, 1, 1),
    1.25);

static assert(approx(ctfeExtrapolated.r, 1.25, 1e-12));

/*
 * CSS shorter path:
 * 350 -> 10 becomes 350 -> 370.
 */
enum ctfeShorter = interpolateHue(
    OklabHued(350),
    OklabHued(10),
    0.5,
    HuePath.shorter);

static assert(approx(ctfeShorter.rawDegrees(), 360.0, 1e-12));
static assert(approx(ctfeShorter.positiveDegrees(), 0.0, 1e-12));

/*
 * CSS longer path:
 * 350 -> 10 stays on the -340-degree route.
 */
enum ctfeLonger = interpolateHue(
    OklabHued(350),
    OklabHued(10),
    0.5,
    HuePath.longer);

static assert(approx(ctfeLonger.rawDegrees(), 180.0, 1e-12));

/*
 * Equal normalized hues:
 *
 * shorter     -> no revolution
 * longer      -> +360-degree revolution
 * increasing  -> no revolution
 * decreasing  -> no revolution
 */
enum equalShorter = interpolateHue(
    OklabHued(30),
    OklabHued(390),
    0.5,
    HuePath.shorter);

enum equalLonger = interpolateHue(
    OklabHued(30),
    OklabHued(390),
    0.5,
    HuePath.longer);

enum equalIncreasing = interpolateHue(
    OklabHued(30),
    OklabHued(390),
    0.5,
    HuePath.increasing);

enum equalDecreasing = interpolateHue(
    OklabHued(30),
    OklabHued(390),
    0.5,
    HuePath.decreasing);

enum equalRaw = interpolateHueRaw(
    OklabHued(30),
    OklabHued(390),
    0.5);

static assert(approx(equalShorter.rawDegrees(), 30.0, 1e-12));
static assert(approx(equalLonger.rawDegrees(), 210.0, 1e-12));
static assert(approx(equalIncreasing.rawDegrees(), 30.0, 1e-12));
static assert(approx(equalDecreasing.rawDegrees(), 30.0, 1e-12));
static assert(approx(equalRaw.rawDegrees(), 210.0, 1e-12));

/*
 * Exact +/-180 ties remain unchanged by both shorter and longer.
 */
enum tieShort = interpolateHue(
    OklabHued(30),
    OklabHued(210),
    0.5,
    HuePath.shorter);

enum tieLong = interpolateHue(
    OklabHued(30),
    OklabHued(210),
    0.5,
    HuePath.longer);

static assert(approx(tieShort.rawDegrees(), 120.0, 1e-12));
static assert(approx(tieLong.rawDegrees(), 120.0, 1e-12));

/*
 * Exact achromatic endpoint borrows the chromatic hue.
 */
enum achromaticMix = interpolate(
    Oklchd(0.4, 0.0, OklabHued(10)),
    Oklchd(0.8, 0.2, OklabHued(200)),
    0.5,
    HuePath.shorter);

static assert(approx(achromaticMix.h.rawDegrees(), 200.0, 1e-12));

/*
 * Near-achromatic is NOT implicitly treated as achromatic.
 */
enum nearAchromaticMix = interpolate(
    Oklchd(0.4, 1e-12, OklabHued(10)),
    Oklchd(0.8, 0.2, OklabHued(200)),
    0.5,
    HuePath.shorter);

static assert(!approx(
    nearAchromaticMix.h.rawDegrees(),
    200.0,
    1e-9));

/*
 * Alpha-aware rectangular interpolation.
 *
 * Opaque red -> transparent blue stays red in its visible RGB contribution
 * at the midpoint.
 */
enum alphaRect = interpolate(
    Alpha!LinearSRgbd(
        LinearSRgbd(1, 0, 0),
        1),
    Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 1),
        0),
    0.5);

static assert(approx(alphaRect.alpha, 0.5, 1e-12));
static assert(approx(alphaRect.color.r, 1.0, 1e-12));
static assert(approx(alphaRect.color.g, 0.0, 1e-12));
static assert(approx(alphaRect.color.b, 0.0, 1e-12));

/*
 * Polar alpha:
 *
 * hue remains an angular interpolation coordinate and is not multiplied by
 * alpha.
 */
enum alphaPolar = interpolate(
    Alpha!Oklchd(
        Oklchd(0.4, 0.2, OklabHued(30)),
        0),
    Alpha!Oklchd(
        Oklchd(0.8, 0.2, OklabHued(210)),
        1),
    0.5,
    HuePath.shorter);

static assert(approx(alphaPolar.alpha, 0.5, 1e-12));
static assert(approx(alphaPolar.color.l, 0.8, 1e-12));
static assert(approx(alphaPolar.color.c, 0.2, 1e-12));
static assert(approx(alphaPolar.color.h.rawDegrees(), 120.0, 1e-12));

/*
 * Zero-alpha interpolation does not divide by zero.
 */
enum zeroAlphaPolar = interpolate(
    Alpha!Oklchd(
        Oklchd(0.4, 0.2, OklabHued(30)),
        0),
    Alpha!Oklchd(
        Oklchd(0.8, 0.3, OklabHued(90)),
        0),
    0.5,
    HuePath.shorter);

static assert(zeroAlphaPolar.alpha == 0);
static assert(zeroAlphaPolar.color.l == 0);
static assert(zeroAlphaPolar.color.c == 0);
static assert(approx(
    zeroAlphaPolar.color.h.rawDegrees(),
    60.0,
    1e-12));

/*
 * Float path.
 */
enum floatHue = interpolateHue(
    OklabHuef(350.0f),
    OklabHuef(10.0f),
    0.5f,
    HuePath.shorter);

static assert(approx(
    floatHue.rawDegrees(),
    360.0f,
    1e-5f));

void main()
{
    writeln("=== R0.7 INTERPOLATION SEMANTICS ===");

    writeln;
    writeln("=== LAYOUT ===");
    writeln("SRgbf:          ", SRgbf.sizeof);
    writeln("SRgbd:          ", SRgbd.sizeof);
    writeln("OklabHuef:      ", OklabHuef.sizeof);
    writeln("OklabHued:      ", OklabHued.sizeof);
    writeln("Oklchf:         ", Oklchf.sizeof);
    writeln("Oklchd:         ", Oklchd.sizeof);
    writeln("Alpha Oklchf:   ", Alpha!Oklchf.sizeof);
    writeln("Alpha Oklchd:   ", Alpha!Oklchd.sizeof);

    writeln;
    writeln("=== RECTANGULAR / EXTENDED RANGE ===");

    auto extended = interpolate(
        LinearSRgbd(-0.2, 0.2, 1.2),
        LinearSRgbd(1.4, 0.8, -0.2),
        0.5);

    writeln("midpoint:       ", extended);

    auto below = interpolate(
        LinearSRgbd(0, 0, 0),
        LinearSRgbd(1, 1, 1),
        -0.25);

    auto above = interpolate(
        LinearSRgbd(0, 0, 0),
        LinearSRgbd(1, 1, 1),
        1.25);

    writeln("t=-0.25:        ", below);
    writeln("t= 1.25:        ", above);

    writeln;
    writeln("=== HUE PATHS 350 -> 10 ===");

    foreach (path;
        [HuePath.shorter,
         HuePath.longer,
         HuePath.increasing,
         HuePath.decreasing])
    {
        auto hue = interpolateHue(
            OklabHued(350),
            OklabHued(10),
            0.5,
            path);

        writeln(
            path,
            ": raw=",
            hue.rawDegrees(),
            " positive=",
            hue.positiveDegrees());
    }

    writeln;
    writeln("=== EQUAL NORMALIZED HUES 30 -> 390 ===");
    writeln("shorter:    ", equalShorter);
    writeln("longer:     ", equalLonger);
    writeln("increasing: ", equalIncreasing);
    writeln("decreasing: ", equalDecreasing);
    writeln("raw:        ", equalRaw);

    writeln;
    writeln("=== 180-DEGREE TIE ===");
    writeln("shorter 30 -> 210: ", tieShort);
    writeln("longer  30 -> 210: ", tieLong);

    writeln;
    writeln("=== ACHROMATIC ===");
    writeln("exact C=0:         ", achromaticMix);
    writeln("near C=1e-12:      ", nearAchromaticMix);

    writeln;
    writeln("=== NEGATIVE CHROMA ===");

    auto negative = Oklchd(
        0.6,
        -0.2,
        OklabHued(30));

    auto equivalent = Oklchd(
        0.6,
        0.2,
        OklabHued(210));

    auto canonicalMix = interpolate(
        negative,
        equivalent,
        0.5,
        HuePath.shorter);

    auto rawChromaMix = interpolateUncanonicalized(
        negative,
        equivalent,
        0.5,
        HuePath.shorter);

    writeln("canonicalized:     ", canonicalMix);
    writeln("uncanonicalized:   ", rawChromaMix);

    writeln;
    writeln("=== ALPHA RECTANGULAR ===");

    auto opaqueRed = Alpha!LinearSRgbd(
        LinearSRgbd(1, 0, 0),
        1);

    auto transparentBlue = Alpha!LinearSRgbd(
        LinearSRgbd(0, 0, 1),
        0);

    auto straightWrong = interpolateStraightAlpha(
        opaqueRed,
        transparentBlue,
        0.5);

    auto premultCorrect = interpolate(
        opaqueRed,
        transparentBlue,
        0.5);

    writeln("straight:          ", straightWrong);
    writeln("premultiplied:     ", premultCorrect);

    writeln;
    writeln("=== ALPHA POLAR ===");
    writeln("midpoint:          ", alphaPolar);
    writeln("zero-alpha:        ", zeroAlphaPolar);

    writeln;
    writeln("=== FLOAT PATH ===");
    writeln("350 -> 10 shorter: ", floatHue);

    writeln;
    writeln("=== COMPILE-TIME CONTRACT ===");
    writeln("mismatched spaces rejected: yes");
    writeln("OKLCH path required:        yes");
    writeln("CTFE assertions:            pass if executable built");

    writeln;
    writeln("R0.7 runtime checks complete.");
}
