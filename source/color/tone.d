module color.tone;

/**
 * Low-level scalar schedule primitives for OKLCH tone construction.
 *
 * This module generates raw scalar positions only. Applying those positions to
 * colors, shaping chroma, anchoring a seed, gamut mapping, and semantic palette
 * policy are separate operations.
 */

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
 * Generate an inclusive linear schedule between two finite scalar endpoints.
 *
 * The first and last elements are assigned exactly to `start` and `end`.
 * Interior values use arithmetic selected to avoid the finite
 * opposite-sign subtraction overflow found by the R0.11 research while
 * preserving exact constant schedules for equal endpoints.
 *
 * One operation supports ascending, descending, and constant schedules.
 * Values are not restricted to a display interval such as `[0, 1]`.
 *
 * `N` must be at least 2. A one-element generated inclusive interval has no
 * unique start/midpoint/end interpretation and is deliberately not part of
 * this API.
 *
 * Preconditions:
 *
 * - `start` is finite;
 * - `end` is finite.
 *
 * NaN and infinity are outside this generated-schedule contract. This function
 * is not a general interpolation primitive and defines no aesthetic curve
 * policy.
 *
 * Example:
 * ---
 * enum values = linearSchedule!5(0.0, 1.0);
 *
 * static assert(values[0] == 0.0);
 * static assert(values[1] == 0.25);
 * static assert(values[2] == 0.50);
 * static assert(values[3] == 0.75);
 * static assert(values[4] == 1.0);
 * ---
 */
T[N] linearSchedule(size_t N, T)(
    T start,
    T end
)
@safe pure nothrow @nogc
if (
    (is(T == float) || is(T == double)) &&
    N >= 2
)
{
    assert(
        isFiniteScheduleScalar(start) &&
        isFiniteScheduleScalar(end)
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
            interpolateFiniteSchedule(
                start,
                end,
                t
            );
    }

    return result;
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
