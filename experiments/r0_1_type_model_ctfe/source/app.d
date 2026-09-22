module app;

import std.stdio : writeln;

// Deliberately restrict the first experiment to float/double.
// Whether `real` belongs in the public API is a separate decision.
enum bool isColorScalar(T) =
    is(T == float) || is(T == double);


// --------------------------------------------------------------------------
// Candidate computational types
// --------------------------------------------------------------------------

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

struct Oklab(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T a;
    T b;
}

struct Oklch(T)
if (isColorScalar!T)
{
    alias Scalar = T;

    T l;
    T c;
    T h;
}


// --------------------------------------------------------------------------
// Candidate alpha model
// --------------------------------------------------------------------------

struct Alpha(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}

struct Premultiplied(Color)
{
    alias Scalar = Color.Scalar;

    Color color;
    Scalar alpha;
}


// --------------------------------------------------------------------------
// Aliases
// --------------------------------------------------------------------------

alias SRgbf       = SRgb!float;
alias SRgbd       = SRgb!double;

alias LinearSRgbf = LinearSRgb!float;
alias LinearSRgbd = LinearSRgb!double;

alias Oklabf      = Oklab!float;
alias Oklabd      = Oklab!double;

alias Oklchf      = Oklch!float;
alias Oklchd      = Oklch!double;


// --------------------------------------------------------------------------
// Small CTFE-capable operation
// --------------------------------------------------------------------------

Oklch!T withLightness(T)(Oklch!T color, T lightness)
@safe pure nothrow @nogc
{
    color.l = lightness;
    return color;
}


// --------------------------------------------------------------------------
// Minimal theme-generation model
// --------------------------------------------------------------------------

struct Theme
{
    Oklchf accent;
    Oklchf accentHover;
    Oklchf accentMuted;
}

Theme makeTheme(Oklchf seed)
@safe pure nothrow @nogc
{
    return Theme(
        seed,
        seed.withLightness(0.72f),
        seed.withLightness(0.88f)
    );
}


// --------------------------------------------------------------------------
// Type distinction
// --------------------------------------------------------------------------

static assert(!is(SRgbf == LinearSRgbf));
static assert(!is(SRgbf == Oklabf));
static assert(!is(Oklabf == Oklchf));


// --------------------------------------------------------------------------
// Expected compact CPU layout
//
// These assertions are intentionally part of the experiment.
// If a supported compiler/platform disagrees, we investigate instead of
// silently baking the assumptions into the public API.
// --------------------------------------------------------------------------

static assert(SRgbf.sizeof       == 3 * float.sizeof);
static assert(LinearSRgbf.sizeof == 3 * float.sizeof);
static assert(Oklabf.sizeof      == 3 * float.sizeof);
static assert(Oklchf.sizeof      == 3 * float.sizeof);

static assert(SRgbd.sizeof       == 3 * double.sizeof);
static assert(Oklchd.sizeof      == 3 * double.sizeof);

static assert(Alpha!SRgbf.sizeof ==
              4 * float.sizeof);

static assert(Premultiplied!LinearSRgbf.sizeof ==
              4 * float.sizeof);

static assert(Alpha!SRgbd.sizeof ==
              4 * double.sizeof);


// --------------------------------------------------------------------------
// CTFE tests
// --------------------------------------------------------------------------

enum seed = Oklchf(
    0.68f,
    0.16f,
    210.0f
);

enum ctfeTheme = makeTheme(seed);

static assert(ctfeTheme.accent.l == 0.68f);
static assert(ctfeTheme.accent.c == 0.16f);
static assert(ctfeTheme.accent.h == 210.0f);

static assert(ctfeTheme.accentHover.l == 0.72f);
static assert(ctfeTheme.accentMuted.l == 0.88f);

// Compile-time evaluated initializer with one stored runtime object.
static immutable Theme compiledTheme = makeTheme(seed);


// --------------------------------------------------------------------------
// Runtime inspection
// --------------------------------------------------------------------------

void main()
{
    writeln("=== color-d R0.1 type model / CTFE ===");
    writeln();

    writeln("SRgbf.sizeof                     = ", SRgbf.sizeof);
    writeln("SRgbf.alignof                    = ", SRgbf.alignof);
    writeln("SRgbd.sizeof                     = ", SRgbd.sizeof);
    writeln("SRgbd.alignof                    = ", SRgbd.alignof);

    writeln("Oklchf.sizeof                    = ", Oklchf.sizeof);
    writeln("Oklchd.sizeof                    = ", Oklchd.sizeof);

    writeln("Alpha!SRgbf.sizeof               = ", Alpha!SRgbf.sizeof);
    writeln("Alpha!SRgbd.sizeof               = ", Alpha!SRgbd.sizeof);

    writeln(
        "Premultiplied!LinearSRgbf.sizeof = ",
        Premultiplied!LinearSRgbf.sizeof
    );

    writeln();
    writeln("compile-time generated theme:");
    writeln("  accent       = ", compiledTheme.accent);
    writeln("  accentHover  = ", compiledTheme.accentHover);
    writeln("  accentMuted  = ", compiledTheme.accentMuted);
}
