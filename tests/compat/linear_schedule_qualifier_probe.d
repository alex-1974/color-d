module linear_schedule_qualifier_probe;

import std.traits : Unqual;

private T[N] candidateConstParameter(size_t N, T)(
    const T start,
    const T end
)
if (
    (is(T == float) || is(T == double)) &&
    N >= 2
)
{
    T[N] result;
    result[0] = start;
    result[N - 1] = end;
    return result;
}

private Unqual!T[N] candidateUnqual(size_t N, T)(
    T start,
    T end
)
if (
    (is(Unqual!T == float) || is(Unqual!T == double)) &&
    N >= 2
)
{
    alias U = Unqual!T;

    U[N] result;
    result[0] = cast(U)start;
    result[N - 1] = cast(U)end;
    return result;
}

static assert(__traits(compiles, candidateConstParameter!5(0.0, 1.0)));
static assert(__traits(compiles, candidateConstParameter!5(0.0f, 1.0f)));

static assert(
    __traits(
        compiles,
        {
            const double start = 0.0;
            const double end = 1.0;
            const values = candidateConstParameter!5(start, end);
            static assert(is(typeof(values[0]) == const(double)));
        }
    )
);

static assert(
    __traits(
        compiles,
        {
            const float start = 0.0f;
            const float end = 1.0f;
            const values = candidateConstParameter!5(start, end);
            static assert(is(typeof(values[0]) == const(float)));
        }
    )
);

static assert(!__traits(compiles, candidateConstParameter!5(0, 1)));
static assert(!__traits(compiles, candidateConstParameter!5(0.0L, 1.0L)));

static assert(
    __traits(
        compiles,
        {
            const double start = 0.0;
            const double end = 1.0;
            const values = candidateUnqual!5(start, end);
            static assert(is(typeof(values[0]) == double));
        }
    )
);

static assert(
    __traits(
        compiles,
        {
            const float start = 0.0f;
            const float end = 1.0f;
            const values = candidateUnqual!5(start, end);
            static assert(is(typeof(values[0]) == float));
        }
    )
);

static assert(!__traits(compiles, candidateUnqual!5(0, 1)));
static assert(!__traits(compiles, candidateUnqual!5(0.0L, 1.0L)));

void main() {}
