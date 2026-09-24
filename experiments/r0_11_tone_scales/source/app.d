module app;

import gamut = r0_8_gamut_fixture;

import core.stdc.stdio : printf;
import std.traits : isFloatingPoint, Unqual;


/*
 * R0.11-A research-only types.
 *
 * These intentionally remain local to the experiment. They model only the
 * pieces required to study primitive decomposition and do not establish
 * production module layout or public API.
 */

template isColorScalar(T)
{
    enum isColorScalar =
        isFloatingPoint!T &&
        (is(T == float) || is(T == double));
}


struct OklabHue(T)
if (isColorScalar!T)
{
    T degrees;

    static OklabHue fromDegrees(T value)
    @safe pure nothrow @nogc
    {
        /*
         * Preserve the represented hue exactly in phase A.
         *
         * Hue normalization/canonicalization already belongs to R0.5 and is
         * deliberately not mixed into this decomposition experiment.
         */
        return OklabHue(value);
    }
}


struct Oklch(T)
if (isColorScalar!T)
{
    T l;
    T c;
    OklabHue!T h;
}


alias Oklchf = Oklch!float;
alias Oklchd = Oklch!double;


/*
 * Candidate A.
 *
 * This function is deliberately trivial. One research question is whether
 * such an operation has any value beyond direct Oklch construction.
 */
Oklch!T rawTone(T)(
    T lightness,
    T chroma,
    OklabHue!T hue
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return Oklch!T(lightness, chroma, hue);
}


/*
 * Scalar composition probe.
 *
 * Replace only the OKLCH lightness coordinate.
 *
 * This operation has useful meaning independent of tone scales and mirrors
 * the perceptual-manipulation direction already present in the technical
 * specification.
 */
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


/*
 * Mechanical batch composition of withLightness.
 *
 * This probe exists to determine whether tone-scale generation introduces
 * mathematical semantics beyond repeatedly applying the scalar operation.
 */
Oklch!T[N] tonesByLightness(T, size_t N)(
    Oklch!T color,
    const T[N] lightnesses
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    Oklch!T[N] result;

    foreach (i; 0 .. N)
    {
        result[i] = withLightness(
            color,
            lightnesses[i]
        );
    }

    return result;
}


/*
 * Candidate B.
 *
 * Generate raw OKLCH tones at caller-supplied lightness positions while
 * preserving one explicit chroma and hue.
 *
 * No validation, clipping, gamut mapping, hue rotation or target-space
 * conversion is performed.
 */
Oklch!T[N] tonesAtLightnesses(T, size_t N)(
    T chroma,
    OklabHue!T hue,
    const T[N] lightnesses
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    Oklch!T[N] result;

    foreach (i; 0 .. N)
    {
        result[i] = rawTone(
            lightnesses[i],
            chroma,
            hue
        );
    }

    return result;
}


/*
 * Candidate C.
 *
 * Treat a complete Oklch value as a family seed.
 *
 * The implementation intentionally exposes the semantic question: only
 * seed.c and seed.h participate. seed.l does not.
 */
Oklch!T[N] tonesFromSeed(T, size_t N)(
    Oklch!T seed,
    const T[N] lightnesses
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return tonesAtLightnesses(
        seed.c,
        seed.h,
        lightnesses
    );
}


/*
 * Candidate D.
 *
 * Start with candidate C and then require one exact output element to equal
 * the complete seed.
 *
 * This intentionally demonstrates the semantic tension between:
 *
 *     exact schedule preservation
 *
 * and:
 *
 *     exact seed anchoring
 *
 * when lightnesses[anchorIndex] != seed.l.
 *
 * Phase A exercises valid anchor indices only. Bounds/error-policy design is
 * intentionally deferred.
 */
Oklch!T[N] anchoredTones(T, size_t N)(
    Oklch!T seed,
    size_t anchorIndex,
    const T[N] lightnesses
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    Oklch!T[N] result = tonesFromSeed(
        seed,
        lightnesses
    );

    result[anchorIndex] = seed;

    return result;
}


bool sameHue(T)(
    OklabHue!T lhs,
    OklabHue!T rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return lhs.degrees == rhs.degrees;
}


bool sameTone(T)(
    Oklch!T lhs,
    Oklch!T rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return
        lhs.l == rhs.l &&
        lhs.c == rhs.c &&
        sameHue(lhs.h, rhs.h);
}


bool sameScale(T, size_t N)(
    const Oklch!T[N] lhs,
    const Oklch!T[N] rhs
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (i; 0 .. N)
    {
        if (!sameTone(lhs[i], rhs[i]))
            return false;
    }

    return true;
}


bool schedulePreserved(T, size_t N)(
    const Oklch!T[N] tones,
    const T[N] lightnesses
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (i; 0 .. N)
    {
        if (tones[i].l != lightnesses[i])
            return false;
    }

    return true;
}


bool constantChroma(T, size_t N)(
    const Oklch!T[N] tones,
    T chroma
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (tone; tones)
    {
        if (tone.c != chroma)
            return false;
    }

    return true;
}


bool constantHue(T, size_t N)(
    const Oklch!T[N] tones,
    OklabHue!T hue
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (tone; tones)
    {
        if (!sameHue(tone.h, hue))
            return false;
    }

    return true;
}


/*
 * CTFE probes.
 *
 * Phase A uses exact component assignment only, so these properties should be
 * exact rather than tolerance-based.
 */

enum double[5] ctfeLightnesses =
[
    0.10,
    0.30,
    0.50,
    0.70,
    0.90
];

enum OklabHue!double ctfeHue =
    OklabHue!double.fromDegrees(250.0);

enum Oklchd ctfeSeed =
    Oklchd(0.50, 0.12, ctfeHue);

enum Oklchd ctfeOtherLightnessSeed =
    Oklchd(0.73, 0.12, ctfeHue);

enum auto ctfeA =
    rawTone(0.30, 0.12, ctfeHue);

enum auto ctfeB =
    tonesAtLightnesses(
        0.12,
        ctfeHue,
        ctfeLightnesses
    );

enum auto ctfeC =
    tonesFromSeed(
        ctfeSeed,
        ctfeLightnesses
    );

enum auto ctfeC2 =
    tonesFromSeed(
        ctfeOtherLightnessSeed,
        ctfeLightnesses
    );

enum auto ctfeDMatching =
    anchoredTones(
        ctfeSeed,
        2,
        ctfeLightnesses
    );

enum auto ctfeWithLightness =
    withLightness(
        ctfeOtherLightnessSeed,
        0.30
    );

enum auto ctfeComposed =
    tonesByLightness(
        ctfeSeed,
        ctfeLightnesses
    );

enum Oklchd ctfeFamilyExemplar =
    Oklchd(
        -0.25,
        0.12,
        ctfeHue
    );

enum auto ctfeComposedFromExemplar =
    tonesByLightness(
        ctfeFamilyExemplar,
        ctfeLightnesses
    );

static assert(
    sameTone(
        ctfeWithLightness,
        Oklchd(
            0.30,
            ctfeOtherLightnessSeed.c,
            ctfeOtherLightnessSeed.h
        )
    )
);

static assert(
    sameScale(
        ctfeComposed,
        ctfeC
    )
);

static assert(
    sameScale(
        ctfeComposedFromExemplar,
        ctfeB
    )
);

static assert(
    sameTone(
        ctfeA,
        Oklchd(0.30, 0.12, ctfeHue)
    )
);

static assert(
    schedulePreserved(
        ctfeB,
        ctfeLightnesses
    )
);

static assert(
    constantChroma(
        ctfeB,
        0.12
    )
);

static assert(
    constantHue(
        ctfeB,
        ctfeHue
    )
);

static assert(
    sameScale(
        ctfeB,
        ctfeC
    )
);

/*
 * Demonstrates that candidate C ignores seed.l.
 */
static assert(
    sameScale(
        ctfeC,
        ctfeC2
    )
);

/*
 * Matching schedule and anchor can preserve both contracts.
 */
static assert(
    sameTone(
        ctfeDMatching[2],
        ctfeSeed
    )
);

static assert(
    schedulePreserved(
        ctfeDMatching,
        ctfeLightnesses
    )
);



// --------------------------------------------------------------------------
// R0.11-B — schedule semantics
// --------------------------------------------------------------------------

/*
 * Direct-difference linear schedule candidate.
 *
 * This is intentionally retained as a comparison candidate because
 *
 *     end - start
 *
 * can overflow for finite opposite-sign endpoints.
 *
 * Inclusive generated schedules are defined only for N >= 2 in this
 * candidate family.
 */
T[N] linearScheduleDirect(T, size_t N)(
    T start,
    T end
)
@safe pure nothrow @nogc
if (isColorScalar!T && N >= 2)
{
    T[N] result;

    result[0] = start;
    result[N - 1] = end;

    foreach (i; 1 .. N - 1)
    {
        const T t =
            cast(T)i /
            cast(T)(N - 1);

        result[i] =
            start +
            (end - start) * t;
    }

    return result;
}


/*
 * Weighted-endpoint candidate.
 *
 * Avoid forming the full endpoint difference:
 *
 *     (1 - t) * start + t * end
 *
 * Endpoints are assigned explicitly.
 */
T[N] linearScheduleWeighted(T, size_t N)(
    T start,
    T end
)
@safe pure nothrow @nogc
if (isColorScalar!T && N >= 2)
{
    T[N] result;

    result[0] = start;
    result[N - 1] = end;

    foreach (i; 1 .. N - 1)
    {
        const T t =
            cast(T)i /
            cast(T)(N - 1);

        result[i] =
            (cast(T)1 - t) * start +
            t * end;
    }

    return result;
}


/*
 * Deliberately competing N == 1 interpretations.
 *
 * Their purpose is to expose semantic ambiguity, not to propose three public
 * APIs.
 */

/*
 * Hybrid finite-range candidate.
 *
 * For same-sign endpoints, the difference cannot overflow merely because of
 * opposite signs, and the direct-difference form preserves important cases
 * such as start == end exactly.
 *
 * For strictly opposite-sign endpoints, avoid forming the potentially
 * overflowing full difference and use the weighted-endpoint form.
 *
 * This candidate is deliberately limited to the finite t-in-[0,1] schedule
 * problem studied by R0.11-B. It is not a general interpolation API.
 */
T interpolateScheduleHybrid(T)(
    T start,
    T end,
    T t
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    const bool oppositeSigns =
        (start < cast(T)0 && end > cast(T)0) ||
        (start > cast(T)0 && end < cast(T)0);

    if (oppositeSigns)
    {
        return
            (cast(T)1 - t) * start +
            t * end;
    }

    return
        start +
        (end - start) * t;
}


T[N] linearScheduleHybrid(T, size_t N)(
    T start,
    T end
)
@safe pure nothrow @nogc
if (isColorScalar!T && N >= 2)
{
    T[N] result;

    result[0] = start;
    result[N - 1] = end;

    foreach (i; 1 .. N - 1)
    {
        const T t =
            cast(T)i /
            cast(T)(N - 1);

        result[i] =
            interpolateScheduleHybrid(
                start,
                end,
                t
            );
    }

    return result;
}


T[1] singletonScheduleStart(T)(
    T start,
    T end
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    T[1] result;
    result[0] = start;
    return result;
}


T[1] singletonScheduleMidpoint(T)(
    T start,
    T end
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    T[1] result;

    result[0] =
        start / cast(T)2 +
        end / cast(T)2;

    return result;
}


T[1] singletonScheduleEnd(T)(
    T start,
    T end
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    T[1] result;
    result[0] = end;
    return result;
}


bool nondecreasing(T, size_t N)(
    const T[N] values
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    static if (N >= 2)
    {
        foreach (i; 1 .. N)
        {
            if (values[i] < values[i - 1])
                return false;
        }
    }

    return true;
}


bool nonincreasing(T, size_t N)(
    const T[N] values
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    static if (N >= 2)
    {
        foreach (i; 1 .. N)
        {
            if (values[i] > values[i - 1])
                return false;
        }
    }

    return true;
}


bool finiteScalar(T)(T value)
@safe pure nothrow @nogc
if (isColorScalar!(Unqual!T))
{
    alias U = Unqual!T;

    const U unqualified = cast(U)value;

    return
        unqualified == unqualified &&
        unqualified != U.infinity &&
        unqualified != -U.infinity;
}


/*
 * Compile-time schedule probes.
 */

static assert(
    !__traits(
        compiles,
        linearScheduleWeighted!(double, 0)(
            0.0,
            1.0
        )
    )
);

static assert(
    !__traits(
        compiles,
        linearScheduleWeighted!(double, 1)(
            0.0,
            1.0
        )
    )
);

static assert(
    __traits(
        compiles,
        linearScheduleWeighted!(double, 2)(
            0.0,
            1.0
        )
    )
);

enum double[0] ctfeEmptyPositions = [];

enum Oklchd[0] ctfeEmptyScale =
    tonesByLightness(
        ctfeSeed,
        ctfeEmptyPositions
    );

static assert(ctfeEmptyScale.length == 0);

enum double[1] ctfeOnePosition =
[
    0.42
];

enum Oklchd[1] ctfeOneTone =
    tonesByLightness(
        ctfeSeed,
        ctfeOnePosition
    );

static assert(ctfeOneTone.length == 1);
static assert(ctfeOneTone[0].l == 0.42);
static assert(ctfeOneTone[0].c == ctfeSeed.c);
static assert(
    ctfeOneTone[0].h.degrees ==
    ctfeSeed.h.degrees
);

enum auto ctfeLinearTwo =
    linearScheduleWeighted!(double, 2)(
        0.20,
        0.80
    );

static assert(ctfeLinearTwo[0] == 0.20);
static assert(ctfeLinearTwo[1] == 0.80);

enum auto ctfeAscending =
    linearScheduleWeighted!(double, 5)(
        0.10,
        0.90
    );

static assert(nondecreasing(ctfeAscending));
static assert(ctfeAscending[0] == 0.10);
static assert(ctfeAscending[4] == 0.90);

enum auto ctfeDescending =
    linearScheduleWeighted!(double, 5)(
        0.90,
        0.10
    );

static assert(nonincreasing(ctfeDescending));
static assert(ctfeDescending[0] == 0.90);
static assert(ctfeDescending[4] == 0.10);


// --------------------------------------------------------------------------
// R0.11-C — chroma and hue policy
// --------------------------------------------------------------------------

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


Oklch!T withHue(T)(
    Oklch!T color,
    OklabHue!T hue
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    color.h = hue;
    return color;
}


Oklch!T[N] tonesAtLightnessAndChroma(T, size_t N)(
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
            withChroma(
                withLightness(
                    seed,
                    lightnesses[i]
                ),
                chromas[i]
            );
    }

    return result;
}


bool chromaSchedulePreserved(T, size_t N)(
    const Oklch!T[N] tones,
    const T[N] chromas
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    foreach (i; 0 .. N)
    {
        if (tones[i].c != chromas[i])
            return false;
    }

    return true;
}


/*
 * Compile-time R0.11-C probes.
 */

enum Oklchd ctfeChromaBase =
    Oklchd(
        0.55,
        0.12,
        OklabHue!double.fromDegrees(250.0)
    );

enum auto ctfeChangedChroma =
    withChroma(
        ctfeChromaBase,
        0.30
    );

static assert(ctfeChangedChroma.l == ctfeChromaBase.l);
static assert(ctfeChangedChroma.c == 0.30);
static assert(
    ctfeChangedChroma.h.degrees ==
    ctfeChromaBase.h.degrees
);

enum auto ctfeChangedHue =
    withHue(
        ctfeChromaBase,
        OklabHue!double.fromDegrees(725.0)
    );

static assert(ctfeChangedHue.l == ctfeChromaBase.l);
static assert(ctfeChangedHue.c == ctfeChromaBase.c);
static assert(ctfeChangedHue.h.degrees == 725.0);

enum auto ctfePowerless =
    withChroma(
        ctfeChromaBase,
        0.0
    );

static assert(ctfePowerless.c == 0.0);
static assert(
    ctfePowerless.h.degrees ==
    ctfeChromaBase.h.degrees
);

enum auto ctfeRestored =
    withChroma(
        ctfePowerless,
        ctfeChromaBase.c
    );

static assert(
    ctfeRestored.h.degrees ==
    ctfeChromaBase.h.degrees
);

enum double[5] ctfeCPositions =
[
    0.10,
    0.30,
    0.50,
    0.70,
    0.90
];

enum double[5] ctfeChromas =
[
    0.02,
    0.06,
    0.12,
    0.08,
    0.03
];

enum auto ctfeComponentScale =
    tonesAtLightnessAndChroma(
        ctfeChromaBase,
        ctfeCPositions,
        ctfeChromas
    );

static assert(
    schedulePreserved(
        ctfeComponentScale,
        ctfeCPositions
    )
);

static assert(
    chromaSchedulePreserved(
        ctfeComponentScale,
        ctfeChromas
    )
);

static assert(
    constantHue(
        ctfeComponentScale,
        ctfeChromaBase.h
    )
);


// --------------------------------------------------------------------------
// R0.11-D — explicit composition with validated R0.8 gamut semantics
// --------------------------------------------------------------------------

gamut.Oklch!T toR08Oklch(T)(
    Oklch!T color
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    return gamut.Oklch!T(
        color.l,
        color.c,
        gamut.OklabHue!T(
            color.h.degrees
        )
    );
}


gamut.MapResult!T[N] mapScaleLocalMinde(T, size_t N)(
    const Oklch!T[N] raw
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    gamut.MapResult!T[N] result;

    foreach (i; 0 .. N)
    {
        result[i] =
            gamut.gamutMapLocalMinde(
                toR08Oklch(raw[i])
            );
    }

    return result;
}


gamut.MapResult!T[N] mapScaleRayTrace(T, size_t N)(
    const Oklch!T[N] raw
)
@safe pure nothrow @nogc
if (isColorScalar!T)
{
    gamut.MapResult!T[N] result;

    foreach (i; 0 .. N)
    {
        result[i] =
            gamut.gamutMapRayTrace(
                toR08Oklch(raw[i])
            );
    }

    return result;
}


/*
 * Compile-time R0.11-D composition probes.
 *
 * Element 0 is achromatic and expected to be inside sRGB.
 * Element 1 is the published high-chroma yellow already exercised by R0.8
 * and expected to be outside sRGB before mapping.
 */

enum double[2] ctfeDLightness =
[
    0.50,
    0.96476
];

enum double[2] ctfeDChroma =
[
    0.0,
    0.24503
];

enum Oklchd ctfeDSeed =
    Oklchd(
        0.50,
        0.0,
        OklabHue!double.fromDegrees(110.23)
    );

enum auto ctfeDRaw =
    tonesAtLightnessAndChroma(
        ctfeDSeed,
        ctfeDLightness,
        ctfeDChroma
    );

static assert(is(typeof(ctfeDRaw) == Oklchd[2]));

static assert(
    gamut.inSrgbGamut(
        toR08Oklch(ctfeDRaw[0])
    )
);

static assert(
    !gamut.inSrgbGamut(
        toR08Oklch(ctfeDRaw[1])
    )
);

enum auto ctfeDLocal =
    mapScaleLocalMinde(ctfeDRaw);

enum auto ctfeDRay =
    mapScaleRayTrace(ctfeDRaw);

static assert(ctfeDLocal.length == ctfeDRaw.length);
static assert(ctfeDRay.length == ctfeDRaw.length);

static assert(ctfeDLocal[0].success);
static assert(ctfeDRay[0].success);

static assert(ctfeDLocal[0].iterations == 0);
static assert(ctfeDRay[0].iterations == 0);

static assert(ctfeDLocal[1].success);
static assert(ctfeDRay[1].success);

static assert(gamut.inSrgbGamut(
        ctfeDLocal[1].color
    ));
static assert(gamut.inSrgbGamut(
        ctfeDRay[1].color
    ));

struct TestState
{
    size_t passed;
    size_t failed;
}


void check(
    ref TestState state,
    bool condition,
    const(char)* label
)
{
    if (condition)
    {
        ++state.passed;
        printf("PASS  %s\n", label);
    }
    else
    {
        ++state.failed;
        printf("FAIL  %s\n", label);
    }
}


void runScalarTests(T)(
    ref TestState state,
    const(char)* scalarName
)
if (isColorScalar!T)
{
    printf("\n=== %s ===\n", scalarName);

    const OklabHue!T hue =
        OklabHue!T.fromDegrees(cast(T)250);

    const T[5] levels =
    [
        cast(T)0.10,
        cast(T)0.30,
        cast(T)0.50,
        cast(T)0.70,
        cast(T)0.90
    ];

    const Oklch!T seed =
        Oklch!T(
            cast(T)0.50,
            cast(T)0.12,
            hue
        );

    const Oklch!T seedDifferentL =
        Oklch!T(
            cast(T)0.73,
            cast(T)0.12,
            hue
        );

    /*
     * A — direct construction equivalence.
     */
    const auto a =
        rawTone(
            cast(T)0.30,
            cast(T)0.12,
            hue
        );

    check(
        state,
        sameTone(
            a,
            Oklch!T(
                cast(T)0.30,
                cast(T)0.12,
                hue
            )
        ),
        "A rawTone == direct Oklch construction"
    );

    /*
     * B — explicit schedule, constant chroma/hue.
     */
    const auto b =
        tonesAtLightnesses(
            cast(T)0.12,
            hue,
            levels
        );

    check(
        state,
        schedulePreserved(b, levels),
        "B preserves explicit lightness schedule"
    );

    check(
        state,
        constantChroma(
            b,
            cast(T)0.12
        ),
        "B preserves requested chroma"
    );

    check(
        state,
        constantHue(
            b,
            hue
        ),
        "B preserves requested hue"
    );

    /*
     * C — seed convenience.
     */
    const auto c =
        tonesFromSeed(
            seed,
            levels
        );

    const auto cDifferentL =
        tonesFromSeed(
            seedDifferentL,
            levels
        );

    check(
        state,
        sameScale(b, c),
        "C(seed) == B(seed.c, seed.h)"
    );

    check(
        state,
        sameScale(c, cDifferentL),
        "C ignores seed lightness"
    );

    /*
     * Scalar composition probe.
     *
     * withLightness has a complete scalar meaning independent of scale
     * generation: replace L, preserve C and H.
     */
    const auto adjusted =
        withLightness(
            seedDifferentL,
            cast(T)0.30
        );

    check(
        state,
        adjusted.l == cast(T)0.30 &&
        adjusted.c == seedDifferentL.c &&
        sameHue(
            adjusted.h,
            seedDifferentL.h
        ),
        "withLightness replaces only L"
    );

    /*
     * Candidate C is exactly repeated withLightness(seed, L[i]).
     */
    const auto composed =
        tonesByLightness(
            seed,
            levels
        );

    check(
        state,
        sameScale(
            composed,
            c
        ),
        "C == repeated withLightness(seed, L[i])"
    );

    /*
     * Candidate B is also exactly expressible by repeated withLightness on
     * any exemplar carrying the requested chroma and hue. Its original
     * lightness has no effect on the generated scale.
     */
    const Oklch!T familyExemplar =
        Oklch!T(
            cast(T)-0.25,
            cast(T)0.12,
            hue
        );

    const auto composedFromExemplar =
        tonesByLightness(
            familyExemplar,
            levels
        );

    check(
        state,
        sameScale(
            composedFromExemplar,
            b
        ),
        "B == repeated withLightness on same C/H exemplar"
    );

    /*
     * D — exact anchor with a matching schedule.
     */
    const auto dMatching =
        anchoredTones(
            seed,
            2,
            levels
        );

    check(
        state,
        sameTone(
            dMatching[2],
            seed
        ),
        "D matching schedule preserves exact seed anchor"
    );

    check(
        state,
        schedulePreserved(
            dMatching,
            levels
        ),
        "D matching schedule also preserves schedule"
    );

    /*
     * D — exact anchor with a mismatching schedule.
     *
     * The schedule requests L=0.30 at index 1 while the seed requires L=0.50.
     * Exact anchoring therefore necessarily breaks exact schedule
     * preservation.
     */
    const auto dMismatch =
        anchoredTones(
            seed,
            1,
            levels
        );

    check(
        state,
        sameTone(
            dMismatch[1],
            seed
        ),
        "D mismatching schedule preserves exact seed anchor"
    );

    check(
        state,
        dMismatch[1].l != levels[1],
        "D mismatching anchor necessarily changes requested L"
    );

    check(
        state,
        !schedulePreserved(
            dMismatch,
            levels
        ),
        "D cannot preserve mismatching anchor and schedule simultaneously"
    );
}



void runScheduleTests(T)(
    ref TestState state,
    const(char)* scalarName
)
if (isColorScalar!T)
{
    printf(
        "\n=== R0.11-B schedule / %s ===\n",
        scalarName
    );

    const OklabHue!T hue =
        OklabHue!T.fromDegrees(
            cast(T)250
        );

    const Oklch!T seed =
        Oklch!T(
            cast(T)0.55,
            cast(T)0.12,
            hue
        );

    /*
     * Explicit schedules already carry their own cardinality semantics.
     */
    const T[0] emptyPositions = [];

    const auto emptyScale =
        tonesByLightness(
            seed,
            emptyPositions
        );

    check(
        state,
        emptyScale.length == 0,
        "explicit N=0 schedule produces empty scale"
    );

    const T[1] onePosition =
    [
        cast(T)0.42
    ];

    const auto oneTone =
        tonesByLightness(
            seed,
            onePosition
        );

    check(
        state,
        oneTone.length == 1 &&
        oneTone[0].l == cast(T)0.42 &&
        oneTone[0].c == seed.c &&
        sameHue(
            oneTone[0].h,
            seed.h
        ),
        "explicit N=1 position is unambiguous"
    );

    /*
     * Generated inclusive schedule with N=2 is exactly the two endpoints.
     */
    const auto two =
        linearScheduleWeighted!(T, 2)(
            cast(T)0.20,
            cast(T)0.80
        );

    check(
        state,
        two[0] == cast(T)0.20 &&
        two[1] == cast(T)0.80,
        "generated N=2 schedule preserves both endpoints"
    );

    /*
     * N=1 has multiple defensible interpretations.
     */
    const auto singletonStart =
        singletonScheduleStart(
            cast(T)0.20,
            cast(T)0.80
        );

    const auto singletonMidpoint =
        singletonScheduleMidpoint(
            cast(T)0.20,
            cast(T)0.80
        );

    const auto singletonEnd =
        singletonScheduleEnd(
            cast(T)0.20,
            cast(T)0.80
        );

    check(
        state,
        singletonStart[0] != singletonMidpoint[0] &&
        singletonMidpoint[0] != singletonEnd[0] &&
        singletonStart[0] != singletonEnd[0],
        "generated N=1 has distinct start/midpoint/end policies"
    );

    /*
     * Normal ascending and descending schedules.
     */
    const auto ascending =
        linearScheduleWeighted!(T, 5)(
            cast(T)0.10,
            cast(T)0.90
        );

    check(
        state,
        ascending[0] == cast(T)0.10 &&
        ascending[4] == cast(T)0.90,
        "ascending schedule preserves exact endpoints"
    );

    check(
        state,
        nondecreasing(ascending),
        "ascending schedule is nondecreasing"
    );

    const auto descending =
        linearScheduleWeighted!(T, 5)(
            cast(T)0.90,
            cast(T)0.10
        );

    check(
        state,
        descending[0] == cast(T)0.90 &&
        descending[4] == cast(T)0.10,
        "descending schedule preserves exact endpoints"
    );

    check(
        state,
        nonincreasing(descending),
        "descending schedule is nonincreasing"
    );

    /*
     * Finite extended range.
     */
    const auto extended =
        linearScheduleWeighted!(T, 5)(
            cast(T)-0.50,
            cast(T)1.50
        );

    check(
        state,
        extended[0] == cast(T)-0.50 &&
        extended[4] == cast(T)1.50 &&
        nondecreasing(extended),
        "finite extended endpoints remain raw mathematical values"
    );

    /*
     * Numerical range probe.
     *
     * Both endpoints are finite, but the full difference overflows:
     *
     *     (-0.75 * T.max) - (+0.75 * T.max)
     *
     * The mathematically expected center is zero.
     */
    const T largePositive =
        T.max * cast(T)0.75;

    const T largeNegative =
        -T.max * cast(T)0.75;

    check(
        state,
        finiteScalar(largePositive) &&
        finiteScalar(largeNegative),
        "range probe endpoints are finite"
    );

    const auto directLarge =
        linearScheduleDirect!(T, 3)(
            largePositive,
            largeNegative
        );

    const auto weightedLarge =
        linearScheduleWeighted!(T, 3)(
            largePositive,
            largeNegative
        );

    check(
        state,
        !finiteScalar(directLarge[1]),
        "direct-difference formula loses finite midpoint"
    );

    check(
        state,
        finiteScalar(weightedLarge[1]),
        "weighted-endpoint formula preserves finite midpoint"
    );

    check(
        state,
        weightedLarge[1] == cast(T)0,
        "weighted opposite-sign midpoint is exactly zero"
    );

    check(
        state,
        weightedLarge[0] == largePositive &&
        weightedLarge[2] == largeNegative,
        "weighted range probe preserves exact endpoints"
    );


    /*
     * Weighted-form idempotence probe.
     *
     * For equal endpoints, every generated value should mathematically equal
     * that endpoint exactly. The weighted formula performs unnecessary
     * multiply/add operations and may lose that property.
     */
    const T equalLarge =
        T.max * cast(T)0.10;

    const auto weightedEqual =
        linearScheduleWeighted!(T, 11)(
            equalLarge,
            equalLarge
        );

    const auto directEqual =
        linearScheduleDirect!(T, 11)(
            equalLarge,
            equalLarge
        );

    const auto hybridEqual =
        linearScheduleHybrid!(T, 11)(
            equalLarge,
            equalLarge
        );

    bool weightedEqualExact = true;
    bool directEqualExact = true;
    bool hybridEqualExact = true;

    foreach (value; weightedEqual)
    {
        if (value != equalLarge)
            weightedEqualExact = false;
    }

    foreach (value; directEqual)
    {
        if (value != equalLarge)
            directEqualExact = false;
    }

    foreach (value; hybridEqual)
    {
        if (value != equalLarge)
            hybridEqualExact = false;
    }

    check(
        state,
        directEqualExact,
        "direct formula preserves equal-endpoint constant schedule"
    );

    check(
        state,
        hybridEqualExact,
        "hybrid formula preserves equal-endpoint constant schedule"
    );

    /*
     * Do not prescribe the result here before observing the compiler.
     *
     * We report whether the weighted form is exact rather than requiring it
     * to fail. A compiler is allowed to optimize the algebra differently.
     */
    if (weightedEqualExact)
        printf("OBS   weighted equal-endpoint exact: YES\n");
    else
        printf("OBS   weighted equal-endpoint exact: NO\n");

    /*
     * Same-sign large endpoints do not require the opposite-sign workaround.
     */
    const T sameSignStart =
        T.max * cast(T)0.75;

    const T sameSignEnd =
        T.max * cast(T)0.50;

    const auto hybridSameSign =
        linearScheduleHybrid!(T, 5)(
            sameSignStart,
            sameSignEnd
        );

    check(
        state,
        finiteScalar(hybridSameSign[1]) &&
        finiteScalar(hybridSameSign[2]) &&
        finiteScalar(hybridSameSign[3]),
        "hybrid same-sign large interior values remain finite"
    );

    check(
        state,
        nonincreasing(hybridSameSign),
        "hybrid same-sign large schedule is nonincreasing"
    );

    /*
     * Opposite-sign case must retain the finite-range advantage already
     * observed for the weighted candidate.
     */
    const auto hybridOpposite =
        linearScheduleHybrid!(T, 3)(
            largePositive,
            largeNegative
        );

    check(
        state,
        finiteScalar(hybridOpposite[1]),
        "hybrid opposite-sign midpoint remains finite"
    );

    check(
        state,
        hybridOpposite[1] == cast(T)0,
        "hybrid symmetric opposite-sign midpoint is exactly zero"
    );

    check(
        state,
        hybridOpposite[0] == largePositive &&
        hybridOpposite[2] == largeNegative,
        "hybrid preserves exact opposite-sign endpoints"
    );


    /*
     * Representative finite-domain property sweep.
     *
     * Reference semantics:
     *
     * - exact endpoints are already enforced by linearScheduleHybrid;
     * - every interior result for finite endpoints must remain finite;
     * - the schedule must be monotonic in the endpoint direction;
     * - every result must remain inside the closed endpoint interval;
     * - equal endpoints must produce an exact constant schedule.
     *
     * This is a deterministic representative sweep, not an exhaustive proof.
     */
    const T[11] representativeEndpoints =
    [
        -T.max * cast(T)0.75,
        cast(T)-2,
        cast(T)-1,
        -T.min_normal,
        cast(T)-0.0,
        cast(T)0,
        T.min_normal,
        cast(T)0.25,
        cast(T)1,
        cast(T)2,
        T.max * cast(T)0.75
    ];

    bool sweepFinite = true;
    bool sweepMonotonic = true;
    bool sweepBounded = true;
    bool sweepEndpoints = true;
    bool sweepEqualExact = true;

    foreach (start; representativeEndpoints)
    {
        foreach (end; representativeEndpoints)
        {
            const auto schedule =
                linearScheduleHybrid!(T, 17)(
                    start,
                    end
                );

            if (schedule[0] != start ||
                schedule[16] != end)
            {
                sweepEndpoints = false;
            }

            if (start < end)
            {
                if (!nondecreasing(schedule))
                    sweepMonotonic = false;
            }
            else if (start > end)
            {
                if (!nonincreasing(schedule))
                    sweepMonotonic = false;
            }

            foreach (value; schedule)
            {
                if (!finiteScalar(value))
                    sweepFinite = false;

                const T lower =
                    start < end ? start : end;

                const T upper =
                    start < end ? end : start;

                if (value < lower || value > upper)
                    sweepBounded = false;

                if (start == end && value != start)
                    sweepEqualExact = false;
            }
        }
    }

    check(
        state,
        sweepFinite,
        "hybrid representative sweep remains finite"
    );

    check(
        state,
        sweepMonotonic,
        "hybrid representative sweep remains monotonic"
    );

    check(
        state,
        sweepBounded,
        "hybrid representative sweep remains within endpoints"
    );

    check(
        state,
        sweepEndpoints,
        "hybrid representative sweep preserves exact endpoints"
    );

    check(
        state,
        sweepEqualExact,
        "hybrid representative equal endpoints remain exact"
    );

    /*
     * Composition with phase A.
     */
    const auto generatedPositions =
        linearScheduleWeighted!(T, 5)(
            cast(T)0.10,
            cast(T)0.90
        );

    const auto generatedScale =
        tonesByLightness(
            seed,
            generatedPositions
        );

    check(
        state,
        schedulePreserved(
            generatedScale,
            generatedPositions
        ) &&
        constantChroma(
            generatedScale,
            seed.c
        ) &&
        constantHue(
            generatedScale,
            seed.h
        ),
        "generated schedule composes mechanically with phase A"
    );
}



void runChromaHueTests(T)(
    ref TestState state,
    const(char)* scalarName
)
if (isColorScalar!T)
{
    printf(
        "\n=== R0.11-C chroma/hue / %s ===\n",
        scalarName
    );

    const OklabHue!T hue =
        OklabHue!T.fromDegrees(
            cast(T)250
        );

    const Oklch!T seed =
        Oklch!T(
            cast(T)0.55,
            cast(T)0.12,
            hue
        );

    const auto changedChroma =
        withChroma(
            seed,
            cast(T)0.30
        );

    check(
        state,
        changedChroma.l == seed.l &&
        changedChroma.c == cast(T)0.30 &&
        sameHue(
            changedChroma.h,
            seed.h
        ),
        "withChroma replaces only C"
    );

    const OklabHue!T rawHue =
        OklabHue!T.fromDegrees(
            cast(T)725
        );

    const auto changedHue =
        withHue(
            seed,
            rawHue
        );

    check(
        state,
        changedHue.l == seed.l &&
        changedHue.c == seed.c &&
        sameHue(
            changedHue.h,
            rawHue
        ),
        "withHue replaces only H"
    );

    const T[5] lightnesses =
    [
        cast(T)0.10,
        cast(T)0.30,
        cast(T)0.50,
        cast(T)0.70,
        cast(T)0.90
    ];

    const T[5] chromas =
    [
        cast(T)0.02,
        cast(T)0.06,
        cast(T)0.12,
        cast(T)0.08,
        cast(T)0.03
    ];

    const auto componentScale =
        tonesAtLightnessAndChroma(
            seed,
            lightnesses,
            chromas
        );

    check(
        state,
        schedulePreserved(
            componentScale,
            lightnesses
        ),
        "explicit component scale preserves L schedule"
    );

    check(
        state,
        chromaSchedulePreserved(
            componentScale,
            chromas
        ),
        "explicit component scale preserves C schedule"
    );

    check(
        state,
        constantHue(
            componentScale,
            seed.h
        ),
        "explicit component scale preserves seed hue"
    );

    bool scalarCompositionExact = true;

    foreach (i; 0 .. lightnesses.length)
    {
        const auto expected =
            withChroma(
                withLightness(
                    seed,
                    lightnesses[i]
                ),
                chromas[i]
            );

        if (!sameTone(
            componentScale[i],
            expected
        ))
        {
            scalarCompositionExact = false;
        }
    }

    check(
        state,
        scalarCompositionExact,
        "component scale equals repeated scalar composition"
    );

    const T[5] constantChromas =
    [
        seed.c,
        seed.c,
        seed.c,
        seed.c,
        seed.c
    ];

    const auto explicitConstant =
        tonesAtLightnessAndChroma(
            seed,
            lightnesses,
            constantChromas
        );

    const auto phaseAConstant =
        tonesByLightness(
            seed,
            lightnesses
        );

    check(
        state,
        sameScale(
            explicitConstant,
            phaseAConstant
        ),
        "constant chroma is an explicit constant C schedule"
    );

    const auto generatedChromas =
        linearScheduleHybrid!(T, 5)(
            cast(T)0.02,
            cast(T)0.10
        );

    const auto generatedChromaScale =
        tonesAtLightnessAndChroma(
            seed,
            lightnesses,
            generatedChromas
        );

    check(
        state,
        chromaSchedulePreserved(
            generatedChromaScale,
            generatedChromas
        ) &&
        schedulePreserved(
            generatedChromaScale,
            lightnesses
        ) &&
        constantHue(
            generatedChromaScale,
            seed.h
        ),
        "generated scalar schedule composes mechanically as chroma"
    );

    const auto powerless =
        withChroma(
            seed,
            cast(T)0
        );

    check(
        state,
        powerless.c == cast(T)0 &&
        sameHue(
            powerless.h,
            seed.h
        ),
        "zero chroma preserves stored powerless hue"
    );

    const auto restored =
        withChroma(
            powerless,
            seed.c
        );

    check(
        state,
        restored.c == seed.c &&
        sameHue(
            restored.h,
            seed.h
        ),
        "restoring chroma preserves previously stored hue"
    );

    const Oklch!T powerlessOtherHue =
        Oklch!T(
            seed.l,
            cast(T)0,
            OklabHue!T.fromDegrees(
                cast(T)40
            )
        );

    check(
        state,
        powerless.h.degrees !=
            powerlessOtherHue.h.degrees,
        "powerless hues remain representationally distinct"
    );

    check(
        state,
        changedHue.h.degrees == cast(T)725,
        "raw hue replacement does not normalize"
    );

    const auto negativeChroma =
        withChroma(
            seed,
            cast(T)-0.10
        );

    check(
        state,
        negativeChroma.c == cast(T)-0.10 &&
        sameHue(
            negativeChroma.h,
            seed.h
        ),
        "raw negative chroma is not implicitly canonicalized"
    );
}



void runGamutCompositionTests(T)(
    ref TestState state,
    const(char)* scalarName
)
if (isColorScalar!T)
{
    printf(
        "\n=== R0.11-D gamut composition / %s ===\n",
        scalarName
    );

    /*
     * Construct one known in-gamut tone and the published R0.8 high-chroma
     * yellow in the same raw R0.11 family.
     */
    const T[2] lightnesses =
    [
        cast(T)0.50,
        cast(T)0.96476
    ];

    const T[2] chromas =
    [
        cast(T)0,
        cast(T)0.24503
    ];

    const Oklch!T seed =
        Oklch!T(
            cast(T)0.50,
            cast(T)0,
            OklabHue!T.fromDegrees(
                cast(T)110.23
            )
        );

    const auto raw =
        tonesAtLightnessAndChroma(
            seed,
            lightnesses,
            chromas
        );

    const auto rawBeforeMapping = raw;

    const bool firstInGamut =
        gamut.inSrgbGamut(
            toR08Oklch(raw[0])
        );

    const bool secondInGamut =
        gamut.inSrgbGamut(
            toR08Oklch(raw[1])
        );

    check(
        state,
        firstInGamut &&
        !secondInGamut,
        "raw family may contain both in-gamut and out-of-gamut tones"
    );

    const auto local =
        mapScaleLocalMinde(raw);

    const auto ray =
        mapScaleRayTrace(raw);

    check(
        state,
        raw == rawBeforeMapping,
        "explicit mapping does not mutate raw tone family"
    );

    check(
        state,
        local.length == raw.length &&
        ray.length == raw.length,
        "mapping preserves family cardinality"
    );

    check(
        state,
        local[0].success &&
        ray[0].success &&
        local[0].iterations == 0 &&
        ray[0].iterations == 0,
        "in-gamut tone uses mapper identity fast path"
    );

    const auto directInGamutRgb =
        gamut.toLinearSRgb(
            toR08Oklch(raw[0])
        );

    check(
        state,
        local[0].color == directInGamutRgb &&
        ray[0].color == directInGamutRgb,
        "in-gamut mapped target equals ordinary target conversion"
    );

    check(
        state,
        local[1].success &&
        ray[1].success &&
        gamut.inSrgbGamut(
            local[1].color
        ) &&
        gamut.inSrgbGamut(
            ray[1].color
        ),
        "out-of-gamut tone maps successfully with both R0.8 methods"
    );

    check(
        state,
        local[1].color != ray[1].color,
        "mapping methods may produce distinct valid target colors"
    );

    bool localPointwiseExact = true;
    bool rayPointwiseExact = true;

    foreach (i; 0 .. raw.length)
    {
        const auto r08 =
            toR08Oklch(raw[i]);

        const auto directLocal =
            gamut.gamutMapLocalMinde(r08);

        const auto directRay =
            gamut.gamutMapRayTrace(r08);

        if (local[i] != directLocal)
            localPointwiseExact = false;

        if (ray[i] != directRay)
            rayPointwiseExact = false;
    }

    check(
        state,
        localPointwiseExact,
        "Local MINDE scale mapping equals independent point-wise mapping"
    );

    check(
        state,
        rayPointwiseExact,
        "Ray Trace scale mapping equals independent point-wise mapping"
    );

    check(
        state,
        schedulePreserved(
            raw,
            lightnesses
        ) &&
        chromaSchedulePreserved(
            raw,
            chromas
        ) &&
        constantHue(
            raw,
            seed.h
        ),
        "raw L/C/H schedule remains authoritative after target mapping"
    );

    check(
        state,
        !gamut.inSrgbGamut(
            toR08Oklch(raw[1])
        ) &&
        gamut.inSrgbGamut(
            local[1].color
        ) &&
        gamut.inSrgbGamut(
            ray[1].color
        ),
        "out-of-gamut raw anchor cannot remain exact target color"
    );

    /*
     * R0.8 defines L <= 0 as destination black and L >= 1 as destination
     * white. Distinct raw tones may therefore collapse after mapping.
     */
    const Oklch!T[4] extremes =
    [
        Oklch!T(
            cast(T)-0.20,
            cast(T)0.10,
            seed.h
        ),
        Oklch!T(
            cast(T)-0.10,
            cast(T)0.30,
            seed.h
        ),
        Oklch!T(
            cast(T)1.10,
            cast(T)0.10,
            seed.h
        ),
        Oklch!T(
            cast(T)1.20,
            cast(T)0.30,
            seed.h
        )
    ];

    const auto extremeLocal =
        mapScaleLocalMinde(extremes);

    const auto extremeRay =
        mapScaleRayTrace(extremes);

    const gamut.LinearSRgb!T black =
        gamut.LinearSRgb!T(
            cast(T)0,
            cast(T)0,
            cast(T)0
        );

    const gamut.LinearSRgb!T white =
        gamut.LinearSRgb!T(
            cast(T)1,
            cast(T)1,
            cast(T)1
        );

    check(
        state,
        extremeLocal[0].color == black &&
        extremeLocal[1].color == black &&
        extremeLocal[2].color == white &&
        extremeLocal[3].color == white &&
        extremeRay[0].color == black &&
        extremeRay[1].color == black &&
        extremeRay[2].color == white &&
        extremeRay[3].color == white,
        "lightness extremes may collapse to target black or white"
    );

    check(
        state,
        extremes[0].c != extremes[1].c &&
        extremes[2].c != extremes[3].c &&
        extremeLocal[0].color == extremeLocal[1].color &&
        extremeLocal[2].color == extremeLocal[3].color,
        "mapped family need not preserve raw uniqueness or component spacing"
    );
}


void main()
{
    printf("color-d R0.11 — tone-scale research\n");

    version (LDC)
        printf("compiler family: LDC\n");
    else version (DigitalMars)
        printf("compiler family: DMD\n");
    else
        printf("compiler family: unknown\n");

    printf(
        "D language version: %ld\n",
        cast(long)__VERSION__
    );

    TestState state;

    runScalarTests!float(
        state,
        "float"
    );

    runScalarTests!double(
        state,
        "double"
    );

    runScheduleTests!float(
        state,
        "float"
    );

    runScheduleTests!double(
        state,
        "double"
    );

    runChromaHueTests!float(
        state,
        "float"
    );

    runChromaHueTests!double(
        state,
        "double"
    );

    runGamutCompositionTests!float(
        state,
        "float"
    );

    runGamutCompositionTests!double(
        state,
        "double"
    );

    printf(
        "\nSUMMARY passed=%zu failed=%zu\n",
        state.passed,
        state.failed
    );

    if (state.failed != 0)
    {
        /*
         * Keep the process result visibly failing without introducing
         * exception-based test infrastructure into this research executable.
         */
        assert(0, "R0.11-A experiment failed");
    }
}
