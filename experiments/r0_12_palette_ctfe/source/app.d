module app;

import gamut = r0_8_gamut_fixture;

import std.math : hypot;
import std.stdio : writefln, writeln;
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
void composeRawFamilyInto(T, size_t N)(
    ref Oklch!T[N] result,
    ref const(Oklch!T) seed,
    ref const(T[N]) lightnesses,
    ref const(T[N]) chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
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
}


Oklch!T[N] composeRawFamily(T, size_t N)(
    Oklch!T seed,
    const T[N] lightnesses,
    const T[N] chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    Oklch!T[N] result;

    composeRawFamilyInto!(T, N)(
        result,
        seed,
        lightnesses,
        chromas
    );

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
void composeRawPaletteInto(T, size_t F, size_t N)(
    ref Oklch!T[N][F] result,
    ref const(Oklch!T[F]) seeds,
    ref const(T[N][F]) lightnesses,
    ref const(T[N][F]) chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        composeRawFamilyInto!(T, N)(
            result[f],
            seeds[f],
            lightnesses[f],
            chromas[f]
        );
    }
}


Oklch!T[N][F] composeRawPalette(T, size_t F, size_t N)(
    const Oklch!T[F] seeds,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    Oklch!T[N][F] result;

    composeRawPaletteInto!(T, F, N)(
        result,
        seeds,
        lightnesses,
        chromas
    );

    return result;
}


// ==========================================================================
// Explicit gamut mapping
// ==========================================================================

void mapFamilyRayTraceInto(T, size_t N)(
    ref MapResult!T[N] result,
    ref const(Oklch!T[N]) raw
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (i; 0 .. N)
    {
        result[i] =
            gamut.gamutMapRayTrace(raw[i]);
    }
}


MapResult!T[N] mapFamilyRayTrace(T, size_t N)(
    const Oklch!T[N] raw
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    MapResult!T[N] result;

    mapFamilyRayTraceInto!(T, N)(
        result,
        raw
    );

    return result;
}


void mapPaletteRayTraceInto(T, size_t F, size_t N)(
    ref MapResult!T[N][F] result,
    ref const(Oklch!T[N][F]) raw
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        mapFamilyRayTraceInto!(T, N)(
            result[f],
            raw[f]
        );
    }
}


MapResult!T[N][F] mapPaletteRayTrace(T, size_t F, size_t N)(
    const Oklch!T[N][F] raw
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    MapResult!T[N][F] result;

    mapPaletteRayTraceInto!(T, F, N)(
        result,
        raw
    );

    return result;
}


// ==========================================================================
// Explicit target-space conversion
// ==========================================================================

void encodeMappedFamilyInto(T, size_t N)(
    ref SRgb!T[N] result,
    ref const(MapResult!T[N]) mapped
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (i; 0 .. N)
    {
        result[i] =
            gamut.toSRgb(mapped[i].color);
    }
}


SRgb!T[N] encodeMappedFamily(T, size_t N)(
    const MapResult!T[N] mapped
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    SRgb!T[N] result;

    encodeMappedFamilyInto!(T, N)(
        result,
        mapped
    );

    return result;
}


void encodeMappedPaletteInto(T, size_t F, size_t N)(
    ref SRgb!T[N][F] result,
    ref const(MapResult!T[N][F]) mapped
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (f; 0 .. F)
    {
        encodeMappedFamilyInto!(T, N)(
            result[f],
            mapped[f]
        );
    }
}


SRgb!T[N][F] encodeMappedPalette(T, size_t F, size_t N)(
    const MapResult!T[N][F] mapped
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    SRgb!T[N][F] result;

    encodeMappedPaletteInto!(T, F, N)(
        result,
        mapped
    );

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
// R0.12-C — representation and CTFE
// ==========================================================================

/*
 * Consumer-local aggregate.
 *
 * This struct does not introduce palette semantics. It merely groups the
 * three representations needed by this experiment:
 *
 *     raw OKLCH
 *     mapped linear sRGB
 *     encoded sRGB
 *
 * R0.12-C tests whether ordinary D value aggregation is sufficient without a
 * color-d-owned Palette container.
 */
struct PaletteBundle(T, size_t F, size_t N)
if (isColorScalar!T)
{
    Oklch!T[N][F] raw;
    MapResult!T[N][F] mapped;
    SRgb!T[N][F] encoded;
}


void buildPaletteBundleInto(T, size_t F, size_t N)(
    ref PaletteBundle!(T, F, N) result,
    ref const(Oklch!T[F]) seeds,
    ref const(T[N][F]) lightnesses,
    ref const(T[N][F]) chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    composeRawPaletteInto!(T, F, N)(
        result.raw,
        seeds,
        lightnesses,
        chromas
    );

    mapPaletteRayTraceInto!(T, F, N)(
        result.mapped,
        result.raw
    );

    encodeMappedPaletteInto!(T, F, N)(
        result.encoded,
        result.mapped
    );
}


/*
 * Value-returning wrapper retained for CTFE and comparison research.
 *
 * Runtime construction for the supported compiler baseline uses
 * buildPaletteBundleInto so nested static arrays do not cross the
 * older DMD ABI by value.
 */
PaletteBundle!(T, F, N) buildPaletteBundle(
    T,
    size_t F,
    size_t N
)(
    const Oklch!T[F] seeds,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    PaletteBundle!(T, F, N) result;

    buildPaletteBundleInto!(T, F, N)(
        result,
        seeds,
        lightnesses,
        chromas
    );

    return result;
}


/*
 * Representative compile-time-known dimensions.
 */
enum size_t phaseCFamilies = 3;
enum size_t phaseCTones = 5;


Oklch!T[phaseCFamilies] phaseCSeeds(T)()
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
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
}


T[phaseCTones][phaseCFamilies] phaseCLightnesses(T)()
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
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
}


T[phaseCTones][phaseCFamilies] phaseCChromas(T)()
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
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
}


// --------------------------------------------------------------------------
// Manifest CTFE inputs
// --------------------------------------------------------------------------

enum phaseCSeedsF =
    phaseCSeeds!float();

enum phaseCLightnessesF =
    phaseCLightnesses!float();

enum phaseCChromasF =
    phaseCChromas!float();

enum phaseCSeedsD =
    phaseCSeeds!double();

enum phaseCLightnessesD =
    phaseCLightnesses!double();

enum phaseCChromasD =
    phaseCChromas!double();


// --------------------------------------------------------------------------
// Complete CTFE construction through the same ordinary function
// --------------------------------------------------------------------------

enum phaseCBundleF =
    buildPaletteBundle!(
        float,
        phaseCFamilies,
        phaseCTones
    )(
        phaseCSeedsF,
        phaseCLightnessesF,
        phaseCChromasF
    );

enum phaseCBundleD =
    buildPaletteBundle!(
        double,
        phaseCFamilies,
        phaseCTones
    )(
        phaseCSeedsD,
        phaseCLightnessesD,
        phaseCChromasD
    );


// --------------------------------------------------------------------------
// Compile-time validation
// --------------------------------------------------------------------------

enum TonePair phaseCEndpointPair =
    TonePair(
        ToneRef(2, 0),
        ToneRef(2, 4)
    );


static assert(
    allMappingsSuccessful!(
        float,
        phaseCFamilies,
        phaseCTones
    )(phaseCBundleF.mapped)
);

static assert(
    allMappedInGamut!(
        float,
        phaseCFamilies,
        phaseCTones
    )(phaseCBundleF.mapped)
);

static assert(
    allEncodedInGamut!(
        float,
        phaseCFamilies,
        phaseCTones
    )(phaseCBundleF.encoded)
);

static assert(
    allWcag2SrgbDomain!(
        float,
        phaseCFamilies,
        phaseCTones
    )(phaseCBundleF.encoded)
);

static assert(
    nondecreasingLightness!(
        float,
        phaseCTones
    )(phaseCBundleF.raw[2])
);


enum phaseCContrastF =
    measureContrast!(
        float,
        phaseCFamilies,
        phaseCTones
    )(
        phaseCBundleF.encoded,
        phaseCEndpointPair
    );

enum phaseCDistanceF =
    measureDeltaEOK!(
        float,
        phaseCFamilies,
        phaseCTones
    )(
        phaseCBundleF.encoded,
        phaseCEndpointPair
    );

static assert(
    phaseCContrastF >= 4.5f
);

static assert(
    !(phaseCContrastF >= 18.0f)
);

static assert(
    phaseCDistanceF >= 0.5f
);

static assert(
    !(phaseCDistanceF >= 0.9f)
);


static assert(
    allMappingsSuccessful!(
        double,
        phaseCFamilies,
        phaseCTones
    )(phaseCBundleD.mapped)
);

static assert(
    allMappedInGamut!(
        double,
        phaseCFamilies,
        phaseCTones
    )(phaseCBundleD.mapped)
);

static assert(
    allEncodedInGamut!(
        double,
        phaseCFamilies,
        phaseCTones
    )(phaseCBundleD.encoded)
);

static assert(
    allWcag2SrgbDomain!(
        double,
        phaseCFamilies,
        phaseCTones
    )(phaseCBundleD.encoded)
);

static assert(
    nondecreasingLightness!(
        double,
        phaseCTones
    )(phaseCBundleD.raw[2])
);


enum phaseCContrastD =
    measureContrast!(
        double,
        phaseCFamilies,
        phaseCTones
    )(
        phaseCBundleD.encoded,
        phaseCEndpointPair
    );

enum phaseCDistanceD =
    measureDeltaEOK!(
        double,
        phaseCFamilies,
        phaseCTones
    )(
        phaseCBundleD.encoded,
        phaseCEndpointPair
    );

static assert(
    phaseCContrastD >= 4.5
);

static assert(
    !(phaseCContrastD >= 18.0)
);

static assert(
    phaseCDistanceD >= 0.5
);

static assert(
    !(phaseCDistanceD >= 0.9)
);


// --------------------------------------------------------------------------
// Representation shape
// --------------------------------------------------------------------------

static assert(
    phaseCBundleF.raw.length ==
        phaseCFamilies
);

static assert(
    phaseCBundleF.raw[0].length ==
        phaseCTones
);

static assert(
    phaseCBundleD.encoded.length ==
        phaseCFamilies
);

static assert(
    phaseCBundleD.encoded[0].length ==
        phaseCTones
);


// --------------------------------------------------------------------------
// static immutable storage
//
// These initializers invoke the same ordinary build function. At module
// scope they must be statically initializable; no separate CTFE API exists.
// --------------------------------------------------------------------------

static immutable PaletteBundle!(
    float,
    phaseCFamilies,
    phaseCTones
) phaseCStoredF =
    buildPaletteBundle!(
        float,
        phaseCFamilies,
        phaseCTones
    )(
        phaseCSeedsF,
        phaseCLightnessesF,
        phaseCChromasF
    );


static immutable PaletteBundle!(
    double,
    phaseCFamilies,
    phaseCTones
) phaseCStoredD =
    buildPaletteBundle!(
        double,
        phaseCFamilies,
        phaseCTones
    )(
        phaseCSeedsD,
        phaseCLightnessesD,
        phaseCChromasD
    );


// --------------------------------------------------------------------------
// Runtime / CTFE numerical diagnostics
// --------------------------------------------------------------------------

T absoluteDifference(T)(
    T a,
    T b
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const T d = a - b;

    return d < cast(T)0
        ? -d
        : d;
}


void updateMaximum(T)(
    ref T current,
    T candidate
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    if (candidate > current)
        current = candidate;
}


/*
 * Development diagnostic only.
 *
 * Exact comparison is intentional here. We are trying to identify the
 * numerical boundary at which runtime and CTFE cease to be bit-for-bit
 * equivalent. No tolerance policy is introduced by this helper.
 */
void diagnoseBundleDifference(
    T,
    size_t F,
    size_t N
)(
    const PaletteBundle!(T, F, N) lhs,
    const PaletteBundle!(T, F, N) rhs,
    string label
)
if (isColorScalar!T)
{
    size_t rawToneMismatches = 0;
    size_t mappedToneMismatches = 0;
    size_t encodedToneMismatches = 0;
    size_t metadataMismatches = 0;

    T maxRawDifference = cast(T)0;
    T maxMappedDifference = cast(T)0;
    T maxEncodedDifference = cast(T)0;

    bool printedFirstRaw = false;
    bool printedFirstMapped = false;
    bool printedFirstEncoded = false;
    bool printedFirstMetadata = false;

    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            const auto lr = lhs.raw[f][i];
            const auto rr = rhs.raw[f][i];

            const T rawDL =
                absoluteDifference!T(
                    lr.l,
                    rr.l
                );

            const T rawDC =
                absoluteDifference!T(
                    lr.c,
                    rr.c
                );

            const T rawDH =
                absoluteDifference!T(
                    lr.h.degrees,
                    rr.h.degrees
                );

            updateMaximum!T(
                maxRawDifference,
                rawDL
            );

            updateMaximum!T(
                maxRawDifference,
                rawDC
            );

            updateMaximum!T(
                maxRawDifference,
                rawDH
            );

            if (rawDL != cast(T)0 ||
                rawDC != cast(T)0 ||
                rawDH != cast(T)0)
            {
                ++rawToneMismatches;

                if (!printedFirstRaw)
                {
                    printedFirstRaw = true;

                    writefln(
                        "DIAG  %s first raw mismatch: family=%s tone=%s "
                        ~ "dL=%.17e dC=%.17e dH=%.17e",
                        label,
                        f,
                        i,
                        cast(double)rawDL,
                        cast(double)rawDC,
                        cast(double)rawDH
                    );
                }
            }

            const auto lm = lhs.mapped[f][i];
            const auto rm = rhs.mapped[f][i];

            if (lm.iterations != rm.iterations ||
                lm.success != rm.success)
            {
                ++metadataMismatches;

                if (!printedFirstMetadata)
                {
                    printedFirstMetadata = true;

                    writefln(
                        "DIAG  %s first metadata mismatch: family=%s tone=%s "
                        ~ "iterations=%s/%s success=%s/%s",
                        label,
                        f,
                        i,
                        lm.iterations,
                        rm.iterations,
                        lm.success,
                        rm.success
                    );
                }
            }

            const T mappedDR =
                absoluteDifference!T(
                    lm.color.r,
                    rm.color.r
                );

            const T mappedDG =
                absoluteDifference!T(
                    lm.color.g,
                    rm.color.g
                );

            const T mappedDB =
                absoluteDifference!T(
                    lm.color.b,
                    rm.color.b
                );

            updateMaximum!T(
                maxMappedDifference,
                mappedDR
            );

            updateMaximum!T(
                maxMappedDifference,
                mappedDG
            );

            updateMaximum!T(
                maxMappedDifference,
                mappedDB
            );

            if (mappedDR != cast(T)0 ||
                mappedDG != cast(T)0 ||
                mappedDB != cast(T)0)
            {
                ++mappedToneMismatches;

                if (!printedFirstMapped)
                {
                    printedFirstMapped = true;

                    writefln(
                        "DIAG  %s first mapped mismatch: family=%s tone=%s "
                        ~ "dr=%.17e dg=%.17e db=%.17e",
                        label,
                        f,
                        i,
                        cast(double)mappedDR,
                        cast(double)mappedDG,
                        cast(double)mappedDB
                    );

                    writefln(
                        "DIAG  %s mapped lhs=(%.17e, %.17e, %.17e)",
                        label,
                        cast(double)lm.color.r,
                        cast(double)lm.color.g,
                        cast(double)lm.color.b
                    );

                    writefln(
                        "DIAG  %s mapped rhs=(%.17e, %.17e, %.17e)",
                        label,
                        cast(double)rm.color.r,
                        cast(double)rm.color.g,
                        cast(double)rm.color.b
                    );
                }
            }

            const auto le = lhs.encoded[f][i];
            const auto re = rhs.encoded[f][i];

            const T encodedDR =
                absoluteDifference!T(
                    le.r,
                    re.r
                );

            const T encodedDG =
                absoluteDifference!T(
                    le.g,
                    re.g
                );

            const T encodedDB =
                absoluteDifference!T(
                    le.b,
                    re.b
                );

            updateMaximum!T(
                maxEncodedDifference,
                encodedDR
            );

            updateMaximum!T(
                maxEncodedDifference,
                encodedDG
            );

            updateMaximum!T(
                maxEncodedDifference,
                encodedDB
            );

            if (encodedDR != cast(T)0 ||
                encodedDG != cast(T)0 ||
                encodedDB != cast(T)0)
            {
                ++encodedToneMismatches;

                if (!printedFirstEncoded)
                {
                    printedFirstEncoded = true;

                    writefln(
                        "DIAG  %s first encoded mismatch: family=%s tone=%s "
                        ~ "dr=%.17e dg=%.17e db=%.17e",
                        label,
                        f,
                        i,
                        cast(double)encodedDR,
                        cast(double)encodedDG,
                        cast(double)encodedDB
                    );

                    writefln(
                        "DIAG  %s encoded lhs=(%.17e, %.17e, %.17e)",
                        label,
                        cast(double)le.r,
                        cast(double)le.g,
                        cast(double)le.b
                    );

                    writefln(
                        "DIAG  %s encoded rhs=(%.17e, %.17e, %.17e)",
                        label,
                        cast(double)re.r,
                        cast(double)re.g,
                        cast(double)re.b
                    );
                }
            }
        }
    }

    writefln(
        "DIAG  %s summary: raw=%s mapped=%s encoded=%s metadata=%s",
        label,
        rawToneMismatches,
        mappedToneMismatches,
        encodedToneMismatches,
        metadataMismatches
    );

    writefln(
        "DIAG  %s maxima: raw=%.17e mapped=%.17e encoded=%.17e",
        label,
        cast(double)maxRawDifference,
        cast(double)maxMappedDifference,
        cast(double)maxEncodedDifference
    );
}



// --------------------------------------------------------------------------
// Runtime / CTFE agreement
// --------------------------------------------------------------------------

bool sameMappingMetadata(T, size_t F, size_t N)(
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
            if (lhs[f][i].iterations != rhs[f][i].iterations ||
                lhs[f][i].success != rhs[f][i].success)
            {
                return false;
            }
        }
    }

    return true;
}


/*
 * R0.12-C does not introduce a numerical tolerance.
 *
 * Development diagnostics established that mapped and encoded floating-point
 * components can differ between runtime and CTFE while:
 *
 *     raw values remain exact,
 *     Ray Trace metadata remains exact,
 *     validation classifications remain the same.
 *
 * Exact numeric CTFE/runtime tolerance policy belongs to R0.13.
 */
void checkPhaseCAgreement(
    T,
    size_t F,
    size_t N
)(
    ref CheckTotals totals,
    string scalarName,
    const PaletteBundle!(T, F, N) runtimeBundle,
    const PaletteBundle!(T, F, N) ctfeBundle,
    const PaletteBundle!(T, F, N) storedBundle
)
if (isColorScalar!T)
{
    check(
        totals,
        sameRawPalette!(T, F, N)(
            runtimeBundle.raw,
            ctfeBundle.raw
        ),
        scalarName ~
            ": runtime raw palette equals CTFE raw palette exactly"
    );

    check(
        totals,
        sameMappingMetadata!(T, F, N)(
            runtimeBundle.mapped,
            ctfeBundle.mapped
        ),
        scalarName ~
            ": runtime and CTFE Ray Trace metadata agree exactly"
    );

    check(
        totals,
        allMappingsSuccessful!(T, F, N)(
            runtimeBundle.mapped
        ) ==
        allMappingsSuccessful!(T, F, N)(
            ctfeBundle.mapped
        ),
        scalarName ~
            ": runtime and CTFE mapping-success classification agrees"
    );

    check(
        totals,
        allMappedInGamut!(T, F, N)(
            runtimeBundle.mapped
        ) ==
        allMappedInGamut!(T, F, N)(
            ctfeBundle.mapped
        ),
        scalarName ~
            ": runtime and CTFE mapped-gamut classification agrees"
    );

    check(
        totals,
        allEncodedInGamut!(T, F, N)(
            runtimeBundle.encoded
        ) ==
        allEncodedInGamut!(T, F, N)(
            ctfeBundle.encoded
        ),
        scalarName ~
            ": runtime and CTFE encoded-gamut classification agrees"
    );

    check(
        totals,
        allWcag2SrgbDomain!(T, F, N)(
            runtimeBundle.encoded
        ) ==
        allWcag2SrgbDomain!(T, F, N)(
            ctfeBundle.encoded
        ),
        scalarName ~
            ": runtime and CTFE WCAG-domain classification agrees"
    );

    const T runtimeContrast =
        measureContrast!(T, F, N)(
            runtimeBundle.encoded,
            phaseCEndpointPair
        );

    const T ctfeContrast =
        measureContrast!(T, F, N)(
            ctfeBundle.encoded,
            phaseCEndpointPair
        );

    const bool contrastPolicyAgreement =
        (runtimeContrast >= cast(T)4.5) ==
            (ctfeContrast >= cast(T)4.5) &&
        (runtimeContrast >= cast(T)18.0) ==
            (ctfeContrast >= cast(T)18.0);

    check(
        totals,
        contrastPolicyAgreement,
        scalarName ~
            ": runtime and CTFE contrast-policy outcomes agree"
    );

    const T runtimeDistance =
        measureDeltaEOK!(T, F, N)(
            runtimeBundle.encoded,
            phaseCEndpointPair
        );

    const T ctfeDistance =
        measureDeltaEOK!(T, F, N)(
            ctfeBundle.encoded,
            phaseCEndpointPair
        );

    const bool distancePolicyAgreement =
        (runtimeDistance >= cast(T)0.5) ==
            (ctfeDistance >= cast(T)0.5) &&
        (runtimeDistance >= cast(T)0.9) ==
            (ctfeDistance >= cast(T)0.9);

    check(
        totals,
        distancePolicyAgreement,
        scalarName ~
            ": runtime and CTFE deltaEOK-policy outcomes agree"
    );

    check(
        totals,
        sameRawPalette!(T, F, N)(
            ctfeBundle.raw,
            storedBundle.raw
        ),
        scalarName ~
            ": enum CTFE and static immutable raw palettes are exact"
    );

    check(
        totals,
        sameMappedPalette!(T, F, N)(
            ctfeBundle.mapped,
            storedBundle.mapped
        ),
        scalarName ~
            ": enum CTFE and static immutable mapped palettes are exact"
    );

    check(
        totals,
        sameEncodedPalette!(T, F, N)(
            ctfeBundle.encoded,
            storedBundle.encoded
        ),
        scalarName ~
            ": enum CTFE and static immutable encoded palettes are exact"
    );
}


void runPhaseC(T)(
    ref CheckTotals totals,
    string scalarName
)
if (isColorScalar!T)
{
    const auto seeds =
        phaseCSeeds!T();

    const auto lightnesses =
        phaseCLightnesses!T();

    const auto chromas =
        phaseCChromas!T();

    PaletteBundle!(
        T,
        phaseCFamilies,
        phaseCTones
    ) runtimeBundle;

    buildPaletteBundleInto!(
        T,
        phaseCFamilies,
        phaseCTones
    )(
        runtimeBundle,
        seeds,
        lightnesses,
        chromas
    );

    writeln();
    writeln("=== R0.12-C ", scalarName, " ===");

    static if (is(T == float))
    {
        diagnoseBundleDifference!(
            T,
            phaseCFamilies,
            phaseCTones
        )(
            runtimeBundle,
            phaseCBundleF,
            "float runtime vs enum CTFE"
        );

        diagnoseBundleDifference!(
            T,
            phaseCFamilies,
            phaseCTones
        )(
            phaseCBundleF,
            phaseCStoredF,
            "float enum CTFE vs static immutable"
        );

        checkPhaseCAgreement!(
            T,
            phaseCFamilies,
            phaseCTones
        )(
            totals,
            scalarName,
            runtimeBundle,
            phaseCBundleF,
            phaseCStoredF
        );
    }
    else
    {
        diagnoseBundleDifference!(
            T,
            phaseCFamilies,
            phaseCTones
        )(
            runtimeBundle,
            phaseCBundleD,
            "double runtime vs enum CTFE"
        );

        diagnoseBundleDifference!(
            T,
            phaseCFamilies,
            phaseCTones
        )(
            phaseCBundleD,
            phaseCStoredD,
            "double enum CTFE vs static immutable"
        );

        checkPhaseCAgreement!(
            T,
            phaseCFamilies,
            phaseCTones
        )(
            totals,
            scalarName,
            runtimeBundle,
            phaseCBundleD,
            phaseCStoredD
        );
    }
}


// ==========================================================================
// R0.12-E — integration and edge properties
// ==========================================================================

bool sameRawFamily(T, size_t N)(
    const Oklch!T[N] lhs,
    const Oklch!T[N] rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (i; 0 .. N)
    {
        if (!sameRawTone!T(
                lhs[i],
                rhs[i]))
        {
            return false;
        }
    }

    return true;
}


bool sameMappedFamily(T, size_t N)(
    const MapResult!T[N] lhs,
    const MapResult!T[N] rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (i; 0 .. N)
    {
        if (!sameMapResult!T(
                lhs[i],
                rhs[i]))
        {
            return false;
        }
    }

    return true;
}


bool sameEncodedFamily(T, size_t N)(
    const SRgb!T[N] lhs,
    const SRgb!T[N] rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (i; 0 .. N)
    {
        if (!sameSrgb!T(
                lhs[i],
                rhs[i]))
        {
            return false;
        }
    }

    return true;
}


void runPhaseE(T)(
    ref CheckTotals totals,
    string scalarName
)
if (isColorScalar!T)
{
    // ----------------------------------------------------------------------
    // Smallest non-empty shape: 1 family × 1 tone
    // ----------------------------------------------------------------------

    enum size_t SF = 1;
    enum size_t SN = 1;

    Oklch!T[SF] singletonSeeds =
    [
        Oklch!T(
            cast(T)0.5,
            cast(T)0.0,
            OklabHue!T(cast(T)725.0))
    ];

    T[SN][SF] singletonLightnesses =
    [
        [
            cast(T)0.5
        ]
    ];

    T[SN][SF] singletonChromas =
    [
        [
            cast(T)0.0
        ]
    ];

    PaletteBundle!(T, SF, SN) singleton;

    buildPaletteBundleInto!(
        T,
        SF,
        SN
    )(
        singleton,
        singletonSeeds,
        singletonLightnesses,
        singletonChromas
    );

    const auto singletonAfterLightness =
        withLightness!T(
            singletonSeeds[0],
            singletonLightnesses[0][0]
        );

    const auto singletonAfterChroma =
        withChroma!T(
            singletonAfterLightness,
            singletonChromas[0][0]
        );

    const auto singletonDirectFamily =
        composeRawFamily!(
            T,
            SN
        )(
            singletonSeeds[0],
            singletonLightnesses[0],
            singletonChromas[0]
        );

    Oklch!T[SN][SF] singletonDirectPalette;

    composeRawPaletteInto!(
        T,
        SF,
        SN
    )(
        singletonDirectPalette,
        singletonSeeds,
        singletonLightnesses,
        singletonChromas
    );

    PaletteBundle!(T, SF, SN) singletonManual;

    singletonManual.raw =
        singletonDirectPalette;

    mapPaletteRayTraceInto!(
        T,
        SF,
        SN
    )(
        singletonManual.mapped,
        singletonManual.raw
    );

    encodeMappedPaletteInto!(
        T,
        SF,
        SN
    )(
        singletonManual.encoded,
        singletonManual.mapped
    );

    PaletteBundle!(T, SF, SN) singletonMutableReturn;

    buildPaletteBundleInto!(
        T,
        SF,
        SN
    )(
        singletonMutableReturn,
        singletonSeeds,
        singletonLightnesses,
        singletonChromas
    );

    writeln();
    writeln("=== R0.12-E ", scalarName, " ===");

    writefln(
        "DIAG  %s singleton input seed: L=%.17e C=%.17e H=%.17e",
        scalarName,
        cast(double)singletonSeeds[0].l,
        cast(double)singletonSeeds[0].c,
        cast(double)singletonSeeds[0].h.degrees
    );

    writefln(
        "DIAG  %s singleton schedules: L=%.17e C=%.17e",
        scalarName,
        cast(double)singletonLightnesses[0][0],
        cast(double)singletonChromas[0][0]
    );

    writefln(
        "DIAG  %s after withLightness: L=%.17e C=%.17e H=%.17e",
        scalarName,
        cast(double)singletonAfterLightness.l,
        cast(double)singletonAfterLightness.c,
        cast(double)singletonAfterLightness.h.degrees
    );

    writefln(
        "DIAG  %s after withChroma: L=%.17e C=%.17e H=%.17e",
        scalarName,
        cast(double)singletonAfterChroma.l,
        cast(double)singletonAfterChroma.c,
        cast(double)singletonAfterChroma.h.degrees
    );

    writefln(
        "DIAG  %s direct family raw: L=%.17e C=%.17e H=%.17e",
        scalarName,
        cast(double)singletonDirectFamily[0].l,
        cast(double)singletonDirectFamily[0].c,
        cast(double)singletonDirectFamily[0].h.degrees
    );

    writefln(
        "DIAG  %s direct palette raw: L=%.17e C=%.17e H=%.17e",
        scalarName,
        cast(double)singletonDirectPalette[0][0].l,
        cast(double)singletonDirectPalette[0][0].c,
        cast(double)singletonDirectPalette[0][0].h.degrees
    );

    writefln(
        "DIAG  %s manual bundle raw: L=%.17e C=%.17e H=%.17e",
        scalarName,
        cast(double)singletonManual.raw[0][0].l,
        cast(double)singletonManual.raw[0][0].c,
        cast(double)singletonManual.raw[0][0].h.degrees
    );

    writefln(
        "DIAG  %s repeated into bundle raw: L=%.17e C=%.17e H=%.17e",
        scalarName,
        cast(double)singletonMutableReturn.raw[0][0].l,
        cast(double)singletonMutableReturn.raw[0][0].c,
        cast(double)singletonMutableReturn.raw[0][0].h.degrees
    );

    writefln(
        "DIAG  %s singleton raw: L=%.17e C=%.17e H=%.17e",
        scalarName,
        cast(double)singleton.raw[0][0].l,
        cast(double)singleton.raw[0][0].c,
        cast(double)singleton.raw[0][0].h.degrees
    );

    check(
        totals,
        singleton.raw.length == SF &&
        singleton.raw[0].length == SN &&
        singleton.raw[0][0].l == cast(T)0.5 &&
        singleton.raw[0][0].c == cast(T)0.0 &&
        singleton.raw[0][0].h.degrees == cast(T)725.0,
        scalarName ~
            ": 1x1 raw palette preserves explicit components and hue"
    );

    check(
        totals,
        singleton.mapped[0][0].success &&
        singleton.mapped[0][0].iterations == 0,
        scalarName ~
            ": in-gamut singleton uses successful zero-iteration mapping path"
    );

    check(
        totals,
        allMappedInGamut!(
            T,
            SF,
            SN
        )(singleton.mapped) &&
        allEncodedInGamut!(
            T,
            SF,
            SN
        )(singleton.encoded),
        scalarName ~
            ": 1x1 mapped and encoded results are in gamut"
    );


    // ----------------------------------------------------------------------
    // Representative 3 × 5 integration palette
    // ----------------------------------------------------------------------

    enum size_t F = phaseCFamilies;
    enum size_t N = phaseCTones;

    const auto seeds =
        phaseCSeeds!T();

    const auto lightnesses =
        phaseCLightnesses!T();

    const auto chromas =
        phaseCChromas!T();

    PaletteBundle!(T, F, N) base;

    buildPaletteBundleInto!(
        T,
        F,
        N
    )(
        base,
        seeds,
        lightnesses,
        chromas
    );

    /*
     * The independently established high-chroma yellow is family 1, tone 3.
     *
     * Phase A established that the raw value is outside sRGB. Here we test
     * that integration through the full bundle actually takes an active
     * Ray Trace path rather than silently treating it as an in-gamut no-op.
     */
    check(
        totals,
        base.mapped[1][3].success &&
        base.mapped[1][3].iterations > 0,
        scalarName ~
            ": known out-of-gamut tone takes active successful mapping path"
    );


    // ----------------------------------------------------------------------
    // Family independence
    // ----------------------------------------------------------------------

    T[N][F] editedChromas =
        phaseCChromas!T();

    editedChromas[1][2] =
        cast(T)0.05;

    PaletteBundle!(T, F, N) edited;

    buildPaletteBundleInto!(
        T,
        F,
        N
    )(
        edited,
        seeds,
        lightnesses,
        editedChromas
    );

    check(
        totals,
        sameRawFamily!(T, N)(
            base.raw[0],
            edited.raw[0]
        ) &&
        sameRawFamily!(T, N)(
            base.raw[2],
            edited.raw[2]
        ),
        scalarName ~
            ": editing one family leaves other raw families exact"
    );

    check(
        totals,
        !sameRawFamily!(T, N)(
            base.raw[1],
            edited.raw[1]
        ),
        scalarName ~
            ": editing one family changes that raw family"
    );

    check(
        totals,
        sameMappedFamily!(T, N)(
            base.mapped[0],
            edited.mapped[0]
        ) &&
        sameMappedFamily!(T, N)(
            base.mapped[2],
            edited.mapped[2]
        ),
        scalarName ~
            ": editing one family leaves other mapped families exact"
    );

    check(
        totals,
        sameEncodedFamily!(T, N)(
            base.encoded[0],
            edited.encoded[0]
        ) &&
        sameEncodedFamily!(T, N)(
            base.encoded[2],
            edited.encoded[2]
        ),
        scalarName ~
            ": editing one family leaves other encoded families exact"
    );


    // ----------------------------------------------------------------------
    // Family permutation
    // ----------------------------------------------------------------------

    Oklch!T[F] permutedSeeds =
    [
        seeds[2],
        seeds[1],
        seeds[0]
    ];

    T[N][F] permutedLightnesses =
    [
        lightnesses[2],
        lightnesses[1],
        lightnesses[0]
    ];

    T[N][F] permutedChromas =
    [
        chromas[2],
        chromas[1],
        chromas[0]
    ];

    PaletteBundle!(T, F, N) permuted;

    buildPaletteBundleInto!(
        T,
        F,
        N
    )(
        permuted,
        permutedSeeds,
        permutedLightnesses,
        permutedChromas
    );

    check(
        totals,
        sameRawFamily!(T, N)(
            permuted.raw[0],
            base.raw[2]
        ) &&
        sameRawFamily!(T, N)(
            permuted.raw[1],
            base.raw[1]
        ) &&
        sameRawFamily!(T, N)(
            permuted.raw[2],
            base.raw[0]
        ),
        scalarName ~
            ": family permutation only permutes raw results"
    );

    check(
        totals,
        sameMappedFamily!(T, N)(
            permuted.mapped[0],
            base.mapped[2]
        ) &&
        sameMappedFamily!(T, N)(
            permuted.mapped[1],
            base.mapped[1]
        ) &&
        sameMappedFamily!(T, N)(
            permuted.mapped[2],
            base.mapped[0]
        ),
        scalarName ~
            ": family permutation only permutes mapped results"
    );

    check(
        totals,
        sameEncodedFamily!(T, N)(
            permuted.encoded[0],
            base.encoded[2]
        ) &&
        sameEncodedFamily!(T, N)(
            permuted.encoded[1],
            base.encoded[1]
        ) &&
        sameEncodedFamily!(T, N)(
            permuted.encoded[2],
            base.encoded[0]
        ),
        scalarName ~
            ": family permutation only permutes encoded results"
    );


    // ----------------------------------------------------------------------
    // Cross-family caller-selected validation pairs
    // ----------------------------------------------------------------------

    enum TonePair crossFamilyPair =
        TonePair(
            ToneRef(0, 0),
            ToneRef(2, 4)
        );

    const T measuredContrast =
        measureContrast!(
            T,
            F,
            N
        )(
            base.encoded,
            crossFamilyPair
        );

    const T directContrast =
        wcag2ContrastRatio!T(
            base.encoded[0][0],
            base.encoded[2][4]
        );

    check(
        totals,
        measuredContrast == directContrast,
        scalarName ~
            ": cross-family contrast pair equals direct measurement"
    );

    const T measuredDistance =
        measureDeltaEOK!(
            T,
            F,
            N
        )(
            base.encoded,
            crossFamilyPair
        );

    const T directDistance =
        deltaEOK!T(
            encodedToOklab!T(
                base.encoded[0][0]
            ),
            encodedToOklab!T(
                base.encoded[2][4]
            )
        );

    check(
        totals,
        measuredDistance == directDistance,
        scalarName ~
            ": cross-family deltaEOK pair equals direct measurement"
    );
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

    CheckTotals phaseC;

    runPhaseC!float(
        phaseC,
        "float"
    );

    runPhaseC!double(
        phaseC,
        "double"
    );

    writeln();
    writeln(
        "R0.12-C: ",
        phaseC.pass,
        " PASS, ",
        phaseC.fail,
        " FAIL"
    );

    CheckTotals phaseE;

    runPhaseE!float(
        phaseE,
        "float"
    );

    runPhaseE!double(
        phaseE,
        "double"
    );

    writeln();
    writeln(
        "R0.12-E: ",
        phaseE.pass,
        " PASS, ",
        phaseE.fail,
        " FAIL"
    );

    return
        phaseA.fail == 0 &&
        phaseB.fail == 0 &&
        phaseC.fail == 0 &&
        phaseE.fail == 0
            ? 0
            : 1;
}
