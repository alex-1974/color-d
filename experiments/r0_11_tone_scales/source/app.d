module app;

import core.stdc.stdio : printf;
import std.traits : isFloatingPoint;


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
