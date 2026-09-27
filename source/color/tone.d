/++
 Low-level schedules and batch operations for OKLCH tone construction.

 The module provides raw mathematical building blocks only. Gamut mapping, seed anchoring, aesthetic curves, and semantic palette roles remain caller policy.
+/
module color.tone;

import color.oklch : Oklch, OklabHue, withLightness, withChroma;

private bool isFiniteScheduleScalar(T)(T value)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}


private T interpolateFiniteSchedule(T)(
    T start,
    T end,
    T t
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
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


/**
 * Generates an inclusive linear schedule between two finite endpoints.
 *
 * The first and last elements are exactly `start` and `end`. Ascending,
 * descending, and constant schedules are supported. Values are not restricted
 * to a display interval such as `[0, 1]`.
 *
 * `N` must be at least 2. `start` and `end` must be finite; NaN and infinity
 * are outside this generated-schedule contract.
 *
 * Params:
 *     start = First schedule value.
 *     end = Last schedule value.
 *
 * Returns:
 *     A fixed-size inclusive schedule of `N` values.
 *
 * Preconditions:
 *     `start` and `end` are finite. This is a programmer precondition, not
 *     a recoverable validation channel.
 *
 * Allocation:
 *     Does not allocate.
 *
 * Complexity:
 *     O(N).
 */

T[N] linearSchedule(size_t N, T)(
    const T start,
    const T end
)
@safe pure nothrow @nogc
if (
    (is(T == float) || is(T == double)) &&
    N >= 2
)
{
    assert(
        isFiniteScheduleScalar!T(start) &&
        isFiniteScheduleScalar!T(end)
    );

    T[N] result;

    result[0] = start;
    result[N - 1] = end;

    foreach (i; 1 .. N - 1)
    {
        const T t =
            cast(T)i /
            cast(T)(N - 1);

        result[i] =
            interpolateFiniteSchedule!T(
                start,
                end,
                t
            );
    }

    return result;
}

///
@safe pure nothrow @nogc unittest
{
    enum values = linearSchedule!5(0.0, 1.0);

    static assert(values[0] == 0.0);
    static assert(values[1] == 0.25);
    static assert(values[2] == 0.50);
    static assert(values[3] == 0.75);
    static assert(values[4] == 1.0);
}

///
@safe pure nothrow @nogc unittest
{
    const double start = 0.20;
    const double end = 0.80;

    const values = linearSchedule!3(start, end);

    assert(values[0] == start);
    assert(values[1] == 0.50);
    assert(values[2] == end);
}


/**
 * Writes a raw OKLCH tone family into compile-time-sized caller storage.
 *
 * The lightness schedule, chroma schedule, and output have the same static
 * cardinality. Each element applies the supplied raw lightness and chroma to
 * the seed while preserving its stored hue. No clamping, canonicalization,
 * anchoring, gamut mapping, or semantic palette policy is applied.
 *
 * `N == 0` and `N == 1` are valid. Output is caller-owned.
 *
 * Params:
 *     seed = Source OKLCH color whose hue is preserved.
 *     lightnesses = Raw lightness schedule.
 *     chromas = Raw chroma schedule.
 *     output = Caller-owned output array.
 *
 * Allocation:
 *     Does not allocate; all output storage is supplied by the caller.
 *
 * Complexity:
 *     O(N).
 *
 * See_Also:
 *     tryTonesAtLightnessAndChromaInto
 */

void tonesAtLightnessAndChromaInto(T, size_t N)(
    Oklch!T seed,
    ref const T[N] lightnesses,
    ref const T[N] chromas,
    ref Oklch!T[N] output
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    /*
     * Do not casually convert this API to return Oklch!T[N] by value.
     *
     * .workspace/TOOLCHAIN_ISSUES.md TC-0001 records silent DMD wrong-code
     * for by-value static arrays of three-float structs through DMD 2.113.0.
     * The validated transport shape is ref const static-array inputs plus a
     * ref output.
     */
    foreach (i; 0 .. N)
    {
        output[i] =
            seed
            .withLightness(lightnesses[i])
            .withChroma(chromas[i]);
    }
}

///
@safe pure nothrow @nogc unittest
{
    const seed = Oklch!double(
        0.50,
        0.10,
        OklabHue!double.fromDegrees(210.0)
    );
    const double[3] lightnesses = [0.20, 0.50, 0.80];
    const double[3] chromas = [0.04, 0.10, 0.06];
    Oklch!double[3] tones;

    tonesAtLightnessAndChromaInto(
        seed,
        lightnesses,
        chromas,
        tones
    );

    assert(tones[0].l == 0.20);
    assert(tones[1].c == 0.10);
    assert(tones[2].h.rawDegrees == seed.h.rawDegrees);
}


private void tonesAtLightnessAndChromaIntoExact(T)(
    Oklch!T seed,
    const(T)[] lightnesses,
    const(T)[] chromas,
    Oklch!T[] output
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    foreach (i; 0 .. output.length)
    {
        output[i] =
            seed
            .withLightness(lightnesses[i])
            .withChroma(chromas[i]);
    }
}


/**
 * Writes a runtime-sized raw OKLCH tone family into caller-owned storage.
 *
 * The operation succeeds only when the lightness, chroma, and output slices
 * have equal length. On mismatch it returns `false` and performs no writes.
 * An empty input/output triple is a successful empty operation.
 *
 * No allocation, clamping, canonicalization, anchoring, gamut mapping, or
 * semantic palette policy is applied.
 *
 * Params:
 *     seed = Source OKLCH color whose hue is preserved.
 *     lightnesses = Raw lightness schedule.
 *     chromas = Raw chroma schedule.
 *     output = Caller-owned output slice.
 *
 * Returns:
 *     `true` on an exact length match; otherwise `false` with output unchanged.
 *
 * Allocation:
 *     Does not allocate; all output storage is supplied by the caller.
 *
 * Complexity:
 *     O(N) on success and O(1) when the slice lengths do not match.
 *
 * See_Also:
 *     tonesAtLightnessAndChromaInto
 */

bool tryTonesAtLightnessAndChromaInto(T)(
    Oklch!T seed,
    const(T)[] lightnesses,
    const(T)[] chromas,
    Oklch!T[] output
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    if (
        lightnesses.length != chromas.length ||
        lightnesses.length != output.length
    )
    {
        return false;
    }

    tonesAtLightnessAndChromaIntoExact(
        seed,
        lightnesses,
        chromas,
        output
    );

    return true;
}

///
@safe pure nothrow @nogc unittest
{
    const seed = Oklch!double(
        0.50,
        0.10,
        OklabHue!double.fromDegrees(210.0)
    );
    const double[] lightnesses = [0.25, 0.75];
    const double[] chromas = [0.05, 0.15];
    Oklch!double[2] output;

    assert(tryTonesAtLightnessAndChromaInto(
        seed,
        lightnesses,
        chromas,
        output[]
    ));
    assert(output[0].l == 0.25);
    assert(output[1].c == 0.15);
}


private bool staticToneBatchProbe(T, size_t N)(
    Oklch!T seed,
    ref const T[N] lightnesses,
    ref const T[N] chromas
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    Oklch!T[N] output;

    tonesAtLightnessAndChromaInto(
        seed,
        lightnesses,
        chromas,
        output
    );

    foreach (i; 0 .. N)
    {
        const scalar =
            seed
            .withLightness(lightnesses[i])
            .withChroma(chromas[i]);

        if (output[i] != scalar)
            return false;
    }

    return true;
}


private bool ctfeLargeToneBatchProbe(T)()
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    enum size_t N = 32;

    T[N] lightnesses;
    T[N] chromas;

    foreach (i; 0 .. N)
    {
        lightnesses[i] =
            cast(T)i /
            cast(T)(N - 1);

        chromas[i] =
            cast(T)0.02 +
            cast(T)i * cast(T)0.003;
    }

    const seed =
        Oklch!T(
            cast(T)0.50,
            cast(T)0.10,
            OklabHue!T.fromDegrees(
                cast(T)42.5
            )
        );

    Oklch!T[N] fixed;

    tonesAtLightnessAndChromaInto(
        seed,
        lightnesses,
        chromas,
        fixed
    );

    Oklch!T[N] output;

    if (!tryTonesAtLightnessAndChromaInto(
        seed,
        lightnesses[],
        chromas[],
        output[]
    ))
    {
        return false;
    }

    if (output != fixed)
        return false;

    foreach (i; 0 .. N)
    {
        const scalar =
            seed
            .withLightness(lightnesses[i])
            .withChroma(chromas[i]);

        if (fixed[i] != scalar)
            return false;
    }

    return true;
}


private bool ctfeToneBatchMismatchProbe(T)()
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const seed =
        Oklch!T(
            cast(T)0.50,
            cast(T)0.10,
            OklabHue!T.fromDegrees(
                cast(T)30
            )
        );

    const sentinel =
        Oklch!T(
            cast(T)0.11,
            cast(T)0.22,
            OklabHue!T.fromDegrees(
                cast(T)333
            )
        );

    T[2] lightnesses =
    [
        cast(T)0.25,
        cast(T)0.75
    ];

    T[1] shortChromas =
    [
        cast(T)0.10
    ];

    Oklch!T[2] output =
    [
        sentinel,
        sentinel
    ];

    if (tryTonesAtLightnessAndChromaInto(
        seed,
        lightnesses[],
        shortChromas[],
        output[]
    ))
    {
        return false;
    }

    if (
        output[0] != sentinel ||
        output[1] != sentinel
    )
    {
        return false;
    }

    T[2] chromas =
    [
        cast(T)0.05,
        cast(T)0.15
    ];

    Oklch!T[1] shortOutput =
    [
        sentinel
    ];

    if (tryTonesAtLightnessAndChromaInto(
        seed,
        lightnesses[],
        chromas[],
        shortOutput[]
    ))
    {
        return false;
    }

    return shortOutput[0] == sentinel;
}


@safe pure nothrow @nogc unittest
{
    const seedD =
        Oklch!double(
            0.50,
            0.10,
            OklabHue!double.fromDegrees(
                725.0
            )
        );

    const double[0] emptyD = [];
    Oklch!double[0] emptyTonesD;

    tonesAtLightnessAndChromaInto(
        seedD,
        emptyD,
        emptyD,
        emptyTonesD
    );

    assert(emptyTonesD.length == 0);

    const double[1] oneLightnessD = [0.42];
    const double[1] oneChromaD = [-0.25];
    Oklch!double[1] oneToneD;

    tonesAtLightnessAndChromaInto(
        seedD,
        oneLightnessD,
        oneChromaD,
        oneToneD
    );

    assert(oneToneD.length == 1);
    assert(oneToneD[0].l == 0.42);
    assert(oneToneD[0].c == -0.25);
    assert(
        oneToneD[0].h.rawDegrees ==
        seedD.h.rawDegrees
    );

    const lightnessesD =
        linearSchedule!5(
            -0.25,
            1.25
        );

    const double[5] chromasD =
    [
        -0.10,
        0.0,
        0.05,
        0.20,
        0.40
    ];

    Oklch!double[5] fixedD;

    tonesAtLightnessAndChromaInto(
        seedD,
        lightnessesD,
        chromasD,
        fixedD
    );

    foreach (i; 0 .. fixedD.length)
    {
        assert(
            fixedD[i].l ==
            lightnessesD[i]
        );
        assert(
            fixedD[i].c ==
            chromasD[i]
        );
        assert(
            fixedD[i].h.rawDegrees ==
            seedD.h.rawDegrees
        );
    }

    assert(
        staticToneBatchProbe(
            seedD,
            lightnessesD,
            chromasD
        )
    );

    static assert(ctfeLargeToneBatchProbe!float());
    static assert(ctfeLargeToneBatchProbe!double());
    static assert(ctfeToneBatchMismatchProbe!float());
    static assert(ctfeToneBatchMismatchProbe!double());

    Oklch!double[5] runtimeOutputD;

    assert(
        tryTonesAtLightnessAndChromaInto(
            seedD,
            lightnessesD[],
            chromasD[],
            runtimeOutputD[]
        )
    );

    assert(runtimeOutputD == fixedD);

    Oklch!double[0] emptyOutputD;

    assert(
        tryTonesAtLightnessAndChromaInto(
            seedD,
            emptyD[],
            emptyD[],
            emptyOutputD[]
        )
    );
}


@safe pure nothrow @nogc unittest
{
    const seed =
        Oklch!double(
            0.50,
            0.10,
            OklabHue!double.fromDegrees(
                -390.0
            )
        );

    const sentinel =
        Oklch!double(
            0.11,
            0.22,
            OklabHue!double.fromDegrees(
                333.0
            )
        );

    const double[2] lightnesses =
    [
        0.25,
        0.75
    ];

    const double[1] shortChromas =
    [
        0.10
    ];

    Oklch!double[2] output =
    [
        sentinel,
        sentinel
    ];

    assert(
        !tryTonesAtLightnessAndChromaInto(
            seed,
            lightnesses[],
            shortChromas[],
            output[]
        )
    );

    assert(output[0] == sentinel);
    assert(output[1] == sentinel);

    const double[2] chromas =
    [
        0.05,
        0.15
    ];

    Oklch!double[1] shortOutput =
    [
        sentinel
    ];

    assert(
        !tryTonesAtLightnessAndChromaInto(
            seed,
            lightnesses[],
            chromas[],
            shortOutput[]
        )
    );

    assert(shortOutput[0] == sentinel);
}


@safe pure nothrow @nogc unittest
{
    const seed =
        Oklch!double(
            0.50,
            0.10,
            OklabHue!double.fromDegrees(
                double.infinity
            )
        );

    const double[3] lightnesses =
    [
        double.nan,
        -double.infinity,
        double.infinity
    ];

    const double[3] chromas =
    [
        double.nan,
        -double.infinity,
        double.infinity
    ];

    Oklch!double[3] tones;

    tonesAtLightnessAndChromaInto(
        seed,
        lightnesses,
        chromas,
        tones
    );

    assert(tones[0].l != tones[0].l);
    assert(tones[0].c != tones[0].c);
    assert(
        tones[0].h.rawDegrees ==
        double.infinity
    );

    assert(
        tones[1].l ==
        -double.infinity
    );
    assert(
        tones[1].c ==
        -double.infinity
    );
    assert(
        tones[1].h.rawDegrees ==
        double.infinity
    );

    assert(
        tones[2].l ==
        double.infinity
    );
    assert(
        tones[2].c ==
        double.infinity
    );
    assert(
        tones[2].h.rawDegrees ==
        double.infinity
    );
}


static assert(
    !__traits(
        compiles,
        linearSchedule!0(0.0, 1.0)
    )
);

static assert(
    !__traits(
        compiles,
        linearSchedule!1(0.0, 1.0)
    )
);

static assert(
    __traits(
        compiles,
        linearSchedule!2(0.0, 1.0)
    )
);

static assert(
    !__traits(
        compiles,
        linearSchedule!5(0, 1)
    )
);

static assert(
    !__traits(
        compiles,
        linearSchedule!5(0.0L, 1.0L)
    )
);


private bool scheduleProperties(T)(
    T start,
    T end
)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    enum size_t N = 17;

    const values =
        linearSchedule!N(
            start,
            end
        );

    if (values[0] != start)
        return false;

    if (values[N - 1] != end)
        return false;

    foreach (value; values)
    {
        if (!isFiniteScheduleScalar(value))
            return false;

        if (start <= end)
        {
            if (value < start || value > end)
                return false;
        }
        else
        {
            if (value > start || value < end)
                return false;
        }
    }

    foreach (i; 1 .. N)
    {
        if (start <= end)
        {
            if (values[i] < values[i - 1])
                return false;
        }
        else
        {
            if (values[i] > values[i - 1])
                return false;
        }
    }

    if (start == end)
    {
        foreach (value; values)
        {
            if (value != start)
                return false;
        }
    }

    return true;
}


private bool representativeFiniteScheduleGrid(T)()
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    const T[11] endpoints =
    [
        cast(T)(-0.75) * T.max,
        cast(T)-2,
        cast(T)-1,
        -T.min_normal,
        cast(T)-0.0,
        cast(T)0,
        T.min_normal,
        cast(T)0.25,
        cast(T)1,
        cast(T)2,
        cast(T)0.75 * T.max
    ];

    foreach (start; endpoints)
    {
        foreach (end; endpoints)
        {
            if (!scheduleProperties(start, end))
                return false;
        }
    }

    return true;
}


@safe pure nothrow @nogc unittest
{
    enum two =
        linearSchedule!2(
            0.20,
            0.80
        );

    static assert(two[0] == 0.20);
    static assert(two[1] == 0.80);

    enum ascending =
        linearSchedule!5(
            0.0,
            1.0
        );

    static assert(ascending[0] == 0.0);
    static assert(ascending[1] == 0.25);
    static assert(ascending[2] == 0.50);
    static assert(ascending[3] == 0.75);
    static assert(ascending[4] == 1.0);

    enum descending =
        linearSchedule!5(
            1.0,
            0.0
        );

    static assert(descending[0] == 1.0);
    static assert(descending[1] == 0.75);
    static assert(descending[2] == 0.50);
    static assert(descending[3] == 0.25);
    static assert(descending[4] == 0.0);

    enum constantValue =
        0.75 * double.max;

    enum constantSchedule =
        linearSchedule!11(
            constantValue,
            constantValue
        );

    static foreach (value; constantSchedule)
    {
        static assert(value == constantValue);
    }

    enum opposite =
        linearSchedule!3(
            0.75 * double.max,
            -0.75 * double.max
        );

    static assert(
        isFiniteScheduleScalar(
            opposite[1]
        )
    );
    static assert(opposite[1] == 0.0);

    enum extended =
        linearSchedule!5(
            -0.5,
            1.5
        );

    static assert(extended[0] == -0.5);
    static assert(extended[4] == 1.5);

    static assert(
        representativeFiniteScheduleGrid!float()
    );
    static assert(
        representativeFiniteScheduleGrid!double()
    );

    assert(
        representativeFiniteScheduleGrid!float()
    );
    assert(
        representativeFiniteScheduleGrid!double()
    );
}
