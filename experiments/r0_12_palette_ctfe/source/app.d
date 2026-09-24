module app;

import gamut = r0_8_gamut_fixture;

import std.math : hypot;
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
// R0.12-B — validation composition
// ==========================================================================

/*
 * Consumer-local positional references.
 *
 * These carry no semantic role such as "text", "background", "accent" or
 * "selected". They merely allow the caller to choose which two palette
 * positions participate in a measurement.
 */
struct ToneRef
{
    size_t family;
    size_t tone;
}


struct TonePair
{
    ToneRef first;
    ToneRef second;
}


/*
 * R0.9-compatible WCAG-domain predicate.
 *
 * Measurement remains distinct from domain diagnostics and from the caller's
 * acceptance threshold.
 */
bool isWcag2SrgbDomain(T)(
    SRgb!T color
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        gamut.isFinite!T(color) &&

        color.r >= cast(T)0 &&
        color.r <= cast(T)1 &&

        color.g >= cast(T)0 &&
        color.g <= cast(T)1 &&

        color.b >= cast(T)0 &&
        color.b <= cast(T)1;
}


bool allWcag2SrgbDomain(T, size_t F, size_t N)(
    const SRgb!T[N][F] palette
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (!isWcag2SrgbDomain!T(
                    palette[f][i]))
            {
                return false;
            }
        }
    }

    return true;
}


/*
 * Published WCAG-2 relative-luminance weights.
 *
 * R0.12-B reuses the R0.9 measurement semantics only for already validated
 * finite [0,1] encoded-sRGB palette colors.
 */
T wcag2RelativeLuminance(T)(
    SRgb!T color
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const auto linear =
        gamut.toLinearSRgb!T(color);

    return
        cast(T)0.2126 * linear.r +
        cast(T)0.7152 * linear.g +
        cast(T)0.0722 * linear.b;
}


T wcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const T la =
        wcag2RelativeLuminance!T(a);

    const T lb =
        wcag2RelativeLuminance!T(b);

    const T lighter =
        la >= lb ? la : lb;

    const T darker =
        la >= lb ? lb : la;

    return
        (lighter + cast(T)0.05) /
        (darker + cast(T)0.05);
}


/*
 * R0.10 deltaEOK semantics:
 *
 * same scalar type
 * same explicit Oklab space
 * Euclidean distance
 *
 * The tested palette colors are finite, but the guarded form preserves the
 * R0.10 special-value boundary rather than relying on raw hypot behavior.
 */
T deltaEOK(T)(
    gamut.Oklab!T lhs,
    gamut.Oklab!T rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const T dl = lhs.l - rhs.l;
    const T da = lhs.a - rhs.a;
    const T db = lhs.b - rhs.b;

    if (dl != dl ||
        da != da ||
        db != db)
    {
        return T.nan;
    }

    const T inf = T.infinity;

    const T adl =
        dl < cast(T)0 ? -dl : dl;

    const T ada =
        da < cast(T)0 ? -da : da;

    const T adb =
        db < cast(T)0 ? -db : db;

    if (adl == inf ||
        ada == inf ||
        adb == inf)
    {
        return inf;
    }

    return hypot(dl, da, db);
}


gamut.Oklab!T encodedToOklab(T)(
    SRgb!T color
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return gamut.toOklab!T(
        gamut.toLinearSRgb!T(color)
    );
}


/*
 * Pair-selected measurements.
 *
 * Pair selection belongs to the caller.
 */
T measureContrast(T, size_t F, size_t N)(
    const SRgb!T[N][F] palette,
    TonePair pair
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return wcag2ContrastRatio!T(
        palette[pair.first.family][pair.first.tone],
        palette[pair.second.family][pair.second.tone]
    );
}


T measureDeltaEOK(T, size_t F, size_t N)(
    const SRgb!T[N][F] palette,
    TonePair pair
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const auto a =
        encodedToOklab!T(
            palette[pair.first.family][pair.first.tone]
        );

    const auto b =
        encodedToOklab!T(
            palette[pair.second.family][pair.second.tone]
        );

    return deltaEOK!T(a, b);
}


/*
 * Structural lightness predicates.
 *
 * No epsilon is introduced: the raw explicit schedule is authoritative.
 */
bool nondecreasingLightness(T, size_t N)(
    const Oklch!T[N] family
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    static if (N < 2)
    {
        return true;
    }
    else
    {
        foreach (i; 1 .. N)
        {
            if (family[i].l < family[i - 1].l)
                return false;
        }

        return true;
    }
}


bool nonincreasingLightness(T, size_t N)(
    const Oklch!T[N] family
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    static if (N < 2)
    {
        return true;
    }
    else
    {
        foreach (i; 1 .. N)
        {
            if (family[i].l > family[i - 1].l)
                return false;
        }

        return true;
    }
}


/*
 * Deliberately aggregate bool candidate.
 *
 * Thresholds and comparison pairs are still caller-provided, so this function
 * does not invent a universal policy.
 *
 * However, the bool result loses which independent condition failed.
 *
 * R0.12-B compares this shape against direct measurement plus explicit caller
 * acceptance.
 */
struct ExampleValidationPolicy(T)
if (isColorScalar!T)
{
    TonePair contrastPair;
    T minimumContrast;

    TonePair distancePair;
    T minimumDeltaEOK;

    size_t nondecreasingFamily;
}


bool validatePaletteAggregate(T, size_t F, size_t N)(
    const Oklch!T[N][F] raw,
    const SRgb!T[N][F] encoded,
    ExampleValidationPolicy!T policy
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    if (!allWcag2SrgbDomain!(T, F, N)(encoded))
        return false;

    if (measureContrast!(T, F, N)(
            encoded,
            policy.contrastPair) <
        policy.minimumContrast)
    {
        return false;
    }

    if (measureDeltaEOK!(T, F, N)(
            encoded,
            policy.distancePair) <
        policy.minimumDeltaEOK)
    {
        return false;
    }

    if (!nondecreasingLightness!(T, N)(
            raw[policy.nondecreasingFamily]))
    {
        return false;
    }

    return true;
}


void runPhaseB(T)(
    ref CheckTotals totals,
    string scalarName
)
if (isColorScalar!T)
{
    enum size_t F = 3;
    enum size_t N = 5;

    /*
     * Same role-free representative palette shape as phase A.
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

    const auto raw =
        composeRawPalette!(T, F, N)(
            seeds,
            lightnesses,
            chromas
        );

    const auto mapped =
        mapPaletteRayTrace!(T, F, N)(
            raw
        );

    const auto encoded =
        encodeMappedPalette!(T, F, N)(
            mapped
        );

    /*
     * Caller-selected comparisons.
     *
     * Family 2 is achromatic and has raw L values from 0.10 to 0.90.
     * No semantic meaning is attached to those positions.
     */
    enum TonePair sameTonePair =
        TonePair(
            ToneRef(2, 2),
            ToneRef(2, 2)
        );

    enum TonePair endpointPair =
        TonePair(
            ToneRef(2, 0),
            ToneRef(2, 4)
        );

    const T sameContrast =
        measureContrast!(T, F, N)(
            encoded,
            sameTonePair
        );

    const T endpointContrast =
        measureContrast!(T, F, N)(
            encoded,
            endpointPair
        );

    const T sameDistance =
        measureDeltaEOK!(T, F, N)(
            encoded,
            sameTonePair
        );

    const T endpointDistance =
        measureDeltaEOK!(T, F, N)(
            encoded,
            endpointPair
        );

    writeln();
    writeln("=== R0.12-B ", scalarName, " ===");
    writeln(
        "MEASURE  endpoint contrast = ",
        endpointContrast
    );
    writeln(
        "MEASURE  endpoint deltaEOK = ",
        endpointDistance
    );

    check(
        totals,
        allWcag2SrgbDomain!(T, F, N)(encoded),
        scalarName ~
            ": all encoded palette colors satisfy WCAG sRGB domain"
    );

    check(
        totals,
        sameContrast == cast(T)1,
        scalarName ~
            ": caller-selected same-tone contrast is exactly 1"
    );

    check(
        totals,
        endpointContrast > cast(T)1,
        scalarName ~
            ": caller-selected endpoint contrast is greater than 1"
    );

    /*
     * These are sample caller policies, not color-d defaults.
     */
    check(
        totals,
        endpointContrast >= cast(T)4.5,
        scalarName ~
            ": caller minimum contrast 4.5 accepts selected endpoints"
    );

    check(
        totals,
        !(endpointContrast >= cast(T)18.0),
        scalarName ~
            ": caller minimum contrast 18 rejects selected endpoints"
    );

    check(
        totals,
        sameDistance == cast(T)0,
        scalarName ~
            ": caller-selected same-tone deltaEOK is exactly 0"
    );

    check(
        totals,
        endpointDistance > cast(T)0,
        scalarName ~
            ": caller-selected endpoint deltaEOK is greater than 0"
    );

    check(
        totals,
        endpointDistance >= cast(T)0.5,
        scalarName ~
            ": caller minimum deltaEOK 0.5 accepts selected endpoints"
    );

    check(
        totals,
        !(endpointDistance >= cast(T)0.9),
        scalarName ~
            ": caller minimum deltaEOK 0.9 rejects selected endpoints"
    );

    check(
        totals,
        nondecreasingLightness!(T, N)(raw[2]),
        scalarName ~
            ": caller-selected family is nondecreasing in raw lightness"
    );

    check(
        totals,
        !nonincreasingLightness!(T, N)(raw[2]),
        scalarName ~
            ": same ascending family does not satisfy descending policy"
    );

    const ExampleValidationPolicy!T passingPolicy =
        ExampleValidationPolicy!T(
            endpointPair,
            cast(T)4.5,

            endpointPair,
            cast(T)0.5,

            2
        );

    const ExampleValidationPolicy!T failingContrastPolicy =
        ExampleValidationPolicy!T(
            endpointPair,
            cast(T)18.0,

            endpointPair,
            cast(T)0.5,

            2
        );

    const ExampleValidationPolicy!T failingDistancePolicy =
        ExampleValidationPolicy!T(
            endpointPair,
            cast(T)4.5,

            endpointPair,
            cast(T)0.9,

            2
        );

    check(
        totals,
        validatePaletteAggregate!(T, F, N)(
            raw,
            encoded,
            passingPolicy
        ),
        scalarName ~
            ": aggregate bool accepts passing caller policy"
    );

    check(
        totals,
        !validatePaletteAggregate!(T, F, N)(
            raw,
            encoded,
            failingContrastPolicy
        ),
        scalarName ~
            ": aggregate bool rejects caller contrast failure"
    );

    check(
        totals,
        !validatePaletteAggregate!(T, F, N)(
            raw,
            encoded,
            failingDistancePolicy
        ),
        scalarName ~
            ": aggregate bool rejects caller distance failure"
    );

    /*
     * The two aggregate failures have the same bool representation.
     *
     * The explicit measurements above retain the distinguishing information:
     *
     *     endpointContrast
     *     endpointDistance
     *
     * This is the architectural distinction under study.
     */
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
    CheckTotals phaseA;

    runPhaseA!float(
        phaseA,
        "float"
    );

    runPhaseA!double(
        phaseA,
        "double"
    );

    writeln();
    writeln(
        "R0.12-A: ",
        phaseA.pass,
        " PASS, ",
        phaseA.fail,
        " FAIL"
    );

    CheckTotals phaseB;

    runPhaseB!float(
        phaseB,
        "float"
    );

    runPhaseB!double(
        phaseB,
        "double"
    );

    writeln();
    writeln(
        "R0.12-B: ",
        phaseB.pass,
        " PASS, ",
        phaseB.fail,
        " FAIL"
    );

    return
        phaseA.fail == 0 &&
        phaseB.fail == 0
            ? 0
            : 1;
}
