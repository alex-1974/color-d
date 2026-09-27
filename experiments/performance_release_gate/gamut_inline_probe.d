// Focused audit of the explicit pragma(inline, true) on the ordinary
// Ray Trace unit-RGB-cube intersection helper.
//
// Question:
// Does LDC 1.43 release code materially benefit from forcing this helper to
// inline, or does the optimizer already make the same decision without the
// source-level hint?
//
// Experiment code only. No production semantics are changed here.

module gamut_inline_probe;

import std.datetime.stopwatch : StopWatch;
import std.stdio : writefln, writeln;

enum validationSamples = 1_000_000;
enum benchCount = 8_192;
enum repetitions = 1_000;
enum rounds = 7;

private struct Rgb(T)
{
    T r;
    T g;
    T b;
}

private struct RayIntersection(T)
{
    Rgb!T color;
    bool found;
}

private bool isFiniteScalar(T)(T value)
@safe pure nothrow @nogc
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}

private T absoluteValue(T)(T value)
@safe pure nothrow @nogc
{
    return value < cast(T)0 ? -value : value;
}

private T minimum(T)(T first, T second)
@safe pure nothrow @nogc
{
    return first < second ? first : second;
}

private T maximum(T)(T first, T second)
@safe pure nothrow @nogc
{
    return first > second ? first : second;
}

private T rayEpsilon(T)()
@safe pure nothrow @nogc
{
    static if (is(T == float))
        return cast(T)1e-6;
    else
        return cast(T)1e-12;
}

private RayIntersection!T noRayIntersection(T)()
@safe pure nothrow @nogc
{
    return RayIntersection!T(Rgb!T.init, false);
}

private pragma(inline, true)
RayIntersection!T intersectForced(T)(
    Rgb!T start,
    Rgb!T end
)
@safe pure nothrow @nogc
{
    if (
        !isFiniteScalar(start.r) ||
        !isFiniteScalar(start.g) ||
        !isFiniteScalar(start.b) ||
        !isFiniteScalar(end.r) ||
        !isFiniteScalar(end.g) ||
        !isFiniteScalar(end.b)
    )
    {
        return noRayIntersection!T();
    }

    const T eps = rayEpsilon!T();

    T[3] a = [start.r, start.g, start.b];
    T[3] b = [end.r, end.g, end.b];
    T[3] direction;

    T tNear = -T.infinity;
    T tFar = T.infinity;

    foreach (i; 0 .. 3)
    {
        const T d = b[i] - a[i];

        if (!isFiniteScalar(d))
            return noRayIntersection!T();

        direction[i] = d;

        if (absoluteValue(d) > eps)
        {
            const T inverse = cast(T)1 / d;
            const T first = (cast(T)0 - a[i]) * inverse;
            const T second = (cast(T)1 - a[i]) * inverse;

            tNear = maximum(minimum(first, second), tNear);
            tFar = minimum(maximum(first, second), tFar);
        }
        else if (
            a[i] < cast(T)0 ||
            a[i] > cast(T)1
        )
        {
            return noRayIntersection!T();
        }
    }

    if (
        tNear > tFar ||
        tFar < cast(T)0
    )
    {
        return noRayIntersection!T();
    }

    if (tNear < cast(T)0)
        tNear = tFar;

    if (!isFiniteScalar(tNear))
        return noRayIntersection!T();

    return RayIntersection!T(
        Rgb!T(
            a[0] + direction[0] * tNear,
            a[1] + direction[1] * tNear,
            a[2] + direction[2] * tNear
        ),
        true
    );
}

private RayIntersection!T intersectDefault(T)(
    Rgb!T start,
    Rgb!T end
)
@safe pure nothrow @nogc
{
    if (
        !isFiniteScalar(start.r) ||
        !isFiniteScalar(start.g) ||
        !isFiniteScalar(start.b) ||
        !isFiniteScalar(end.r) ||
        !isFiniteScalar(end.g) ||
        !isFiniteScalar(end.b)
    )
    {
        return noRayIntersection!T();
    }

    const T eps = rayEpsilon!T();

    T[3] a = [start.r, start.g, start.b];
    T[3] b = [end.r, end.g, end.b];
    T[3] direction;

    T tNear = -T.infinity;
    T tFar = T.infinity;

    foreach (i; 0 .. 3)
    {
        const T d = b[i] - a[i];

        if (!isFiniteScalar(d))
            return noRayIntersection!T();

        direction[i] = d;

        if (absoluteValue(d) > eps)
        {
            const T inverse = cast(T)1 / d;
            const T first = (cast(T)0 - a[i]) * inverse;
            const T second = (cast(T)1 - a[i]) * inverse;

            tNear = maximum(minimum(first, second), tNear);
            tFar = minimum(maximum(first, second), tFar);
        }
        else if (
            a[i] < cast(T)0 ||
            a[i] > cast(T)1
        )
        {
            return noRayIntersection!T();
        }
    }

    if (
        tNear > tFar ||
        tFar < cast(T)0
    )
    {
        return noRayIntersection!T();
    }

    if (tNear < cast(T)0)
        tNear = tFar;

    if (!isFiniteScalar(tNear))
        return noRayIntersection!T();

    return RayIntersection!T(
        Rgb!T(
            a[0] + direction[0] * tNear,
            a[1] + direction[1] * tNear,
            a[2] + direction[2] * tNear
        ),
        true
    );
}

private uint nextRandom(ref uint state)
@safe nothrow @nogc
{
    state =
        state * 1_664_525U +
        1_013_904_223U;

    return state;
}

private T unit(T)(ref uint state)
@safe nothrow @nogc
{
    const uint bits = nextRandom(state) & 0x00FF_FFFFU;
    return
        cast(T)bits /
        cast(T)0x00FF_FFFFU;
}

private Rgb!T generatedStart(T)(ref uint state)
@safe nothrow @nogc
{
    // Ray Trace anchors are normally in or close to the unit cube.
    return Rgb!T(
        unit!T(state),
        unit!T(state),
        unit!T(state)
    );
}

private Rgb!T generatedEnd(T)(ref uint state)
@safe nothrow @nogc
{
    // Exercise crossing rays, interior rays, misses, and extended endpoints.
    return Rgb!T(
        cast(T)-2 + cast(T)5 * unit!T(state),
        cast(T)-2 + cast(T)5 * unit!T(state),
        cast(T)-2 + cast(T)5 * unit!T(state)
    );
}

private bool equalResult(T)(
    RayIntersection!T first,
    RayIntersection!T second
)
@safe pure nothrow @nogc
{
    if (first.found != second.found)
        return false;

    if (!first.found)
        return true;

    return
        first.color.r == second.color.r &&
        first.color.g == second.color.g &&
        first.color.b == second.color.b;
}

private bool validate(T)(string scalarName)
{
    uint state = 0xC01D_0021U;

    foreach (_; 0 .. validationSamples)
    {
        const start = generatedStart!T(state);
        const end = generatedEnd!T(state);

        const forced = intersectForced(start, end);
        const normal = intersectDefault(start, end);

        if (!equalResult(forced, normal))
        {
            writeln(scalarName, " validation mismatch");
            return false;
        }
    }

    writeln(
        scalarName,
        " validation: samples=",
        validationSamples,
        " exact_mismatches=0"
    );

    return true;
}

private double timeForced(T)(
    const(Rgb!T)[] starts,
    const(Rgb!T)[] ends,
    ref T checksum,
    ref size_t foundCount
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (i; 0 .. starts.length)
        {
            const result =
                intersectForced(starts[i], ends[i]);

            if (result.found)
            {
                checksum +=
                    result.color.r +
                    result.color.g +
                    result.color.b;
                ++foundCount;
            }
        }
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(starts.length * repetitions);
}

private double timeDefault(T)(
    const(Rgb!T)[] starts,
    const(Rgb!T)[] ends,
    ref T checksum,
    ref size_t foundCount
)
{
    StopWatch sw;
    sw.start();

    foreach (_; 0 .. repetitions)
    {
        foreach (i; 0 .. starts.length)
        {
            const result =
                intersectDefault(starts[i], ends[i]);

            if (result.found)
            {
                checksum +=
                    result.color.r +
                    result.color.g +
                    result.color.b;
                ++foundCount;
            }
        }
    }

    sw.stop();

    return
        cast(double)sw.peek.total!"nsecs" /
        cast(double)(starts.length * repetitions);
}

private void benchmark(T)(string scalarName)
{
    Rgb!T[benchCount] starts;
    Rgb!T[benchCount] ends;

    uint state = 0xC01D_0022U;

    foreach (i; 0 .. benchCount)
    {
        starts[i] = generatedStart!T(state);
        ends[i] = generatedEnd!T(state);
    }

    T checksum = cast(T)0;
    size_t foundCount = 0;

    foreach (round; 0 .. rounds)
    {
        double forcedNs;
        double defaultNs;

        if ((round & 1) == 0)
        {
            forcedNs =
                timeForced(
                    starts[],
                    ends[],
                    checksum,
                    foundCount
                );
            defaultNs =
                timeDefault(
                    starts[],
                    ends[],
                    checksum,
                    foundCount
                );
        }
        else
        {
            defaultNs =
                timeDefault(
                    starts[],
                    ends[],
                    checksum,
                    foundCount
                );
            forcedNs =
                timeForced(
                    starts[],
                    ends[],
                    checksum,
                    foundCount
                );
        }

        writefln(
            "%s round %s: forced_inline=%.3f ns/intersection default=%.3f ns/intersection default_over_forced=%.4f",
            scalarName,
            round + 1,
            forcedNs,
            defaultNs,
            defaultNs / forcedNs
        );
    }

    writeln(
        scalarName,
        " checksum=",
        checksum,
        " found_count=",
        foundCount
    );
}

int main()
{
    writeln("=== color-d gamut inline-hint audit ===");

    if (!validate!double("double"))
        return 1;

    if (!validate!float("float"))
        return 1;

    benchmark!double("double");
    benchmark!float("float");

    return 0;
}
