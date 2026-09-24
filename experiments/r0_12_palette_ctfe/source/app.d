module app;

import gamut = r0_8_gamut_fixture;

import std.stdio : writeln;
import std.traits : isFloatingPoint, Unqual;


/*
 * R0.12-A — vertical composition and ownership boundary.
 *
 * All helpers in this file are research-local.
 *
 * They test whether a finite multi-family palette requires mathematical
 * semantics beyond ordinary composition of already validated primitives.
 *
 * No type or function in this experiment establishes production API.
 */


template isColorScalar(T)
{
    enum isColorScalar =
        isFloatingPoint!T &&
        (is(Unqual!T == float) || is(Unqual!T == double));
}


/*
 * Local research aliases for the extracted R0.8 fixture types.
 *
 * Keep the actual gamut operations module-qualified, but avoid carrying
 * qualified template-instance syntax through every R0.12 function-template
 * signature.
 *
 * These aliases do not create a second type world:
 *
 *     Oklch!T
 *
 * is exactly:
 *
 *     gamut.Oklch!(T)
 */
alias Oklch(T)     = gamut.Oklch!(T);
alias OklabHue(T)  = gamut.OklabHue!(T);
alias MapResult(T) = gamut.MapResult!(T);
alias SRgb(T)      = gamut.SRgb!(T);


// ==========================================================================
// Raw scalar composition
// ==========================================================================

Oklch!T withLightness(T)(
    Oklch!T color,
    T lightness
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    color.l = lightness;
    return color;
}


Oklch!T withChroma(T)(
    Oklch!T color,
    T chroma
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    color.c = chroma;
    return color;
}


/*
 * One raw family.
 *
 * The lightness and chroma schedules are authoritative.
 * The seed contributes only the stored hue after the two component
 * replacements.
 *
 * No clipping or gamut mapping occurs.
 */
Oklch!T[N] composeRawFamily(T, size_t N)(
    Oklch!T seed,
    const T[N] lightnesses,
    const T[N] chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    Oklch!T[N] result;

    foreach (i; 0 .. N)
    {
        result[i] =
            withChroma!T(
                withLightness!T(
                    seed,
                    lightnesses[i]
                ),
                chromas[i]
            );
    }

    return result;
}


/*
 * Mechanical multi-family batching candidate.
 *
 * Research question:
 *
 * Does this operation add semantics beyond repeatedly calling
 * composeRawFamily?
 */
Oklch!T[N][F] composeRawPalette(T, size_t F, size_t N)(
    const Oklch!T[F] seeds,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    Oklch!T[N][F] result;

    foreach (f; 0 .. F)
    {
        result[f] = composeRawFamily!(T, N)(
            seeds[f],
            lightnesses[f],
            chromas[f]
        );
    }

    return result;
}


// ==========================================================================
// Explicit gamut mapping
// ==========================================================================

MapResult!T[N] mapFamilyRayTrace(T, size_t N)(
    const Oklch!T[N] raw
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    MapResult!T[N] result;

    foreach (i; 0 .. N)
    {
        /*
         * Deliberately module-qualified.
         *
         * The mapper belongs to the extracted R0.8 fixture/type world.
         */
        result[i] =
            gamut.gamutMapRayTrace(raw[i]);
    }

    return result;
}


MapResult!T[N][F] mapPaletteRayTrace(T, size_t F, size_t N)(
    const Oklch!T[N][F] raw
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    MapResult!T[N][F] result;

    foreach (f; 0 .. F)
    {
        result[f] =
            mapFamilyRayTrace!(T, N)(raw[f]);
    }

    return result;
}


// ==========================================================================
// Explicit target-space conversion
// ==========================================================================

SRgb!T[N] encodeMappedFamily(T, size_t N)(
    const MapResult!T[N] mapped
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    SRgb!T[N] result;

    foreach (i; 0 .. N)
    {
        result[i] =
            gamut.toSRgb(mapped[i].color);
    }

    return result;
}


SRgb!T[N][F] encodeMappedPalette(T, size_t F, size_t N)(
    const MapResult!T[N][F] mapped
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    SRgb!T[N][F] result;

    foreach (f; 0 .. F)
    {
        result[f] =
            encodeMappedFamily!(T, N)(mapped[f]);
    }

    return result;
}


// ==========================================================================
// Exact structural comparison helpers
//
// The comparisons below are intentionally exact where both sides execute the
// identical deterministic operation graph from identical inputs.
//
// R0.12-A does not introduce a numerical-tolerance policy.
// ==========================================================================

bool sameRawTone(T)(
    Oklch!T lhs,
    Oklch!T rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        lhs.l == rhs.l &&
        lhs.c == rhs.c &&
        lhs.h.degrees == rhs.h.degrees;
}


bool sameRawPalette(T, size_t F, size_t N)(
    const Oklch!T[N][F] lhs,
    const Oklch!T[N][F] rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (!sameRawTone!T(
                    lhs[f][i],
                    rhs[f][i]))
            {
                return false;
            }
        }
    }

    return true;
}


bool sameMapResult(T)(
    MapResult!T lhs,
    MapResult!T rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        lhs.color.r == rhs.color.r &&
        lhs.color.g == rhs.color.g &&
        lhs.color.b == rhs.color.b &&
        lhs.iterations == rhs.iterations &&
        lhs.success == rhs.success;
}


bool sameMappedPalette(T, size_t F, size_t N)(
    const MapResult!T[N][F] lhs,
    const MapResult!T[N][F] rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (!sameMapResult!T(
                    lhs[f][i],
                    rhs[f][i]))
            {
                return false;
            }
        }
    }

    return true;
}


bool sameSrgb(T)(
    SRgb!T lhs,
    SRgb!T rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        lhs.r == rhs.r &&
        lhs.g == rhs.g &&
        lhs.b == rhs.b;
}


bool sameEncodedPalette(T, size_t F, size_t N)(
    const SRgb!T[N][F] lhs,
    const SRgb!T[N][F] rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (!sameSrgb!T(
                    lhs[f][i],
                    rhs[f][i]))
            {
                return false;
            }
        }
    }

    return true;
}


// ==========================================================================
// Structural predicates
// ==========================================================================

bool schedulesPreserved(T, size_t F, size_t N)(
    const Oklch!T[N][F] raw,
    const Oklch!T[F] seeds,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (raw[f][i].l != lightnesses[f][i])
                return false;

            if (raw[f][i].c != chromas[f][i])
                return false;

            if (raw[f][i].h.degrees !=
                seeds[f].h.degrees)
            {
                return false;
            }
        }
    }

    return true;
}


bool allMappingsSuccessful(T, size_t F, size_t N)(
    const MapResult!T[N][F] mapped
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (!mapped[f][i].success)
                return false;
        }
    }

    return true;
}


bool allMappedInGamut(T, size_t F, size_t N)(
    const MapResult!T[N][F] mapped
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (!gamut.inSrgbGamut(
                    mapped[f][i].color))
            {
                return false;
            }
        }
    }

    return true;
}


bool allEncodedInGamut(T, size_t F, size_t N)(
    const SRgb!T[N][F] encoded
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (!gamut.inSrgbGamut(
                    encoded[f][i]))
            {
                return false;
            }
        }
    }

    return true;
}


// ==========================================================================
// Test harness
// ==========================================================================

struct CheckTotals
{
    size_t pass;
    size_t fail;
}


void check(
    ref CheckTotals totals,
    bool condition,
    string label
)
{
    if (condition)
    {
        ++totals.pass;
        writeln("PASS  ", label);
    }
    else
    {
        ++totals.fail;
        writeln("FAIL  ", label);
    }
}


void runPhaseA(T)(
    ref CheckTotals totals,
    string scalarName
)
if (isColorScalar!T)
{
    enum size_t F = 3;
    enum size_t N = 5;

    /*
     * The seeds deliberately contain no semantic names.
     *
     * Family 1 includes the already R0.8-validated CSS high-chroma yellow
     * example at tone index 3:
     *
     *   OKLCH(0.96476, 0.24503, 110.23 degrees)
     *
     * That gives R0.12-A one independently established out-of-gamut case.
     */
    Oklch!T[F] seeds =
    [
        Oklch!T(
            cast(T)0.55,
            cast(T)0.12,
            OklabHue!T(cast(T)250.0)),

        Oklch!T(
            cast(T)0.70,
            cast(T)0.20,
            OklabHue!T(cast(T)110.23)),

        Oklch!T(
            cast(T)0.50,
            cast(T)0.00,
            OklabHue!T(cast(T)-45.0))
    ];

    T[N][F] lightnesses =
    [
        [
            cast(T)0.15,
            cast(T)0.35,
            cast(T)0.55,
            cast(T)0.75,
            cast(T)0.90
        ],
        [
            cast(T)0.20,
            cast(T)0.50,
            cast(T)0.80,
            cast(T)0.96476,
            cast(T)0.99
        ],
        [
            cast(T)0.10,
            cast(T)0.30,
            cast(T)0.50,
            cast(T)0.70,
            cast(T)0.90
        ]
    ];

    T[N][F] chromas =
    [
        [
            cast(T)0.06,
            cast(T)0.10,
            cast(T)0.12,
            cast(T)0.10,
            cast(T)0.06
        ],
        [
            cast(T)0.10,
            cast(T)0.18,
            cast(T)0.22,
            cast(T)0.24503,
            cast(T)0.10
        ],
        [
            cast(T)0.00,
            cast(T)0.00,
            cast(T)0.00,
            cast(T)0.00,
            cast(T)0.00
        ]
    ];

    writeln();
    writeln("=== R0.12-A ", scalarName, " ===");

    /*
     * Baseline: manually compose each independent family.
     */
    Oklch!T[N][F] rawManual;

    foreach (f; 0 .. F)
    {
        rawManual[f] =
            composeRawFamily!(T, N)(
                seeds[f],
                lightnesses[f],
                chromas[f]
            );
    }

    /*
     * Candidate convenience: one mechanical multi-family batch.
     */
    const auto rawBatch =
        composeRawPalette!(T, F, N)(
            seeds,
            lightnesses,
            chromas
        );

    check(
        totals,
        sameRawPalette!(T, F, N)(
            rawManual,
            rawBatch
        ),
        scalarName ~
            ": palette batch equals repeated family composition"
    );

    check(
        totals,
        schedulesPreserved!(T, F, N)(
            rawBatch,
            seeds,
            lightnesses,
            chromas
        ),
        scalarName ~
            ": raw L/C schedules and stored hues are exact"
    );

    /*
     * Explicitly verify the inherited R0.8 high-chroma-yellow case.
     */
    check(
        totals,
        !gamut.inSrgbGamut(
            rawBatch[1][3]
        ),
        scalarName ~
            ": known high-chroma yellow remains out of sRGB gamut"
    );

    /*
     * Keep a copy to prove that mapping produces separate output rather than
     * rewriting the raw palette.
     */
    const auto rawBeforeMapping =
        rawBatch;

    MapResult!T[N][F] mappedManual;

    foreach (f; 0 .. F)
    {
        mappedManual[f] =
            mapFamilyRayTrace!(T, N)(
                rawManual[f]
            );
    }

    const auto mappedBatch =
        mapPaletteRayTrace!(T, F, N)(
            rawBatch
        );

    check(
        totals,
        sameMappedPalette!(T, F, N)(
            mappedManual,
            mappedBatch
        ),
        scalarName ~
            ": palette mapping batch equals repeated family mapping"
    );

    check(
        totals,
        sameRawPalette!(T, F, N)(
            rawBatch,
            rawBeforeMapping
        ),
        scalarName ~
            ": explicit mapping leaves raw palette unchanged"
    );

    check(
        totals,
        allMappingsSuccessful!(T, F, N)(mappedBatch),
        scalarName ~
            ": all explicit Ray Trace mappings report success"
    );

    check(
        totals,
        allMappedInGamut!(T, F, N)(mappedBatch),
        scalarName ~
            ": all mapped linear-sRGB tones are in gamut"
    );

    /*
     * Target-space conversion remains a distinct explicit phase.
     */
    SRgb!T[N][F] encodedManual;

    foreach (f; 0 .. F)
    {
        encodedManual[f] =
            encodeMappedFamily!(T, N)(
                mappedManual[f]
            );
    }

    const auto encodedBatch =
        encodeMappedPalette!(T, F, N)(
            mappedBatch
        );

    check(
        totals,
        sameEncodedPalette!(T, F, N)(
            encodedManual,
            encodedBatch
        ),
        scalarName ~
            ": target-space batch equals repeated family conversion"
    );

    check(
        totals,
        allEncodedInGamut!(T, F, N)(encodedBatch),
        scalarName ~
            ": explicitly encoded sRGB palette is in gamut"
    );
}


int main()
{
    CheckTotals totals;

    runPhaseA!float(
        totals,
        "float"
    );

    runPhaseA!double(
        totals,
        "double"
    );

    writeln();
    writeln(
        "R0.12-A: ",
        totals.pass,
        " PASS, ",
        totals.fail,
        " FAIL"
    );

    return totals.fail == 0
        ? 0
        : 1;
}
