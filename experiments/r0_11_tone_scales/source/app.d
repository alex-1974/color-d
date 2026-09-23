module app;

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


void main()
{
    printf("color-d R0.11-A — primitive decomposition\n");

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
