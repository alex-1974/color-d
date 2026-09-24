module app;

import std.stdio : writeln;
import r0_8_gamut_fixture;


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
