module repro_trigger_matrix;

import std.stdio : writefln, writeln;

struct Color(T)
{
    T l;
    T c;
    T h;
}


Color!T[N] makeFamily(T, size_t N)(
    const Color!T seed
)
@safe pure nothrow @nogc
{
    Color!T[N] result;

    foreach (i; 0 .. N)
    {
        result[i] =
            Color!T(
                cast(T)(0.5 + 0.01 * i),
                cast(T)(0.1 + 0.01 * i),
                seed.h
            );
    }

    return result;
}


/*
 * Candidate that reproduces the R0.12-E failure shape:
 * assign a returned inner static array as a whole.
 */
Color!T[N][F] makePaletteWhole(T, size_t F, size_t N)(
    const Color!T[F] seeds
)
@safe pure nothrow @nogc
{
    Color!T[N][F] result;

    foreach (f; 0 .. F)
    {
        result[f] =
            makeFamily!(T, N)(
                seeds[f]
            );
    }

    return result;
}


/*
 * Semantically equivalent construction without assigning an
 * entire returned inner static array.
 */
Color!T[N][F] makePaletteElementwise(T, size_t F, size_t N)(
    const Color!T[F] seeds
)
@safe pure nothrow @nogc
{
    Color!T[N][F] result;

    foreach (f; 0 .. F)
    {
        const auto family =
            makeFamily!(T, N)(
                seeds[f]
            );

        foreach (i; 0 .. N)
        {
            result[f][i] =
                family[i];
        }
    }

    return result;
}


bool expected(T)(
    const Color!T value,
    size_t i,
    T hue
)
@safe pure nothrow @nogc
{
    return
        value.l == cast(T)(0.5 + 0.01 * i) &&
        value.c == cast(T)(0.1 + 0.01 * i) &&
        value.h == hue;
}


bool testShape(
    T,
    size_t F,
    size_t N
)(
    string scalarName
)
{
    Color!T[F] seeds;

    foreach (f; 0 .. F)
    {
        seeds[f] =
            Color!T(
                cast(T)0.0,
                cast(T)0.0,
                cast(T)(100 + f)
            );
    }

    const auto whole =
        makePaletteWhole!(
            T,
            F,
            N
        )(seeds);

    const auto elementwise =
        makePaletteElementwise!(
            T,
            F,
            N
        )(seeds);

    bool wholeOK = true;
    bool elementwiseOK = true;

    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            wholeOK =
                wholeOK &&
                expected!T(
                    whole[f][i],
                    i,
                    seeds[f].h
                );

            elementwiseOK =
                elementwiseOK &&
                expected!T(
                    elementwise[f][i],
                    i,
                    seeds[f].h
                );
        }
    }

    writefln(
        "%-6s %sx%s  whole=%-4s  elementwise=%-4s",
        scalarName,
        F,
        N,
        wholeOK ? "PASS" : "FAIL",
        elementwiseOK ? "PASS" : "FAIL"
    );

    if (!wholeOK)
    {
        writefln(
            "  first whole value: L=%.17e C=%.17e H=%.17e",
            cast(double)whole[0][0].l,
            cast(double)whole[0][0].c,
            cast(double)whole[0][0].h
        );
    }

    if (!elementwiseOK)
    {
        writefln(
            "  first elementwise value: L=%.17e C=%.17e H=%.17e",
            cast(double)elementwise[0][0].l,
            cast(double)elementwise[0][0].c,
            cast(double)elementwise[0][0].h
        );
    }

    return wholeOK && elementwiseOK;
}


bool testScalar(T)(string scalarName)
{
    bool ok = true;

    ok = testShape!(T, 1, 1)(scalarName) && ok;
    ok = testShape!(T, 1, 2)(scalarName) && ok;
    ok = testShape!(T, 2, 1)(scalarName) && ok;
    ok = testShape!(T, 2, 2)(scalarName) && ok;
    ok = testShape!(T, 3, 5)(scalarName) && ok;

    return ok;
}


int main()
{
    writeln("shape matrix:");

    const bool f =
        testScalar!float("float");

    const bool d =
        testScalar!double("double");

    return f && d ? 0 : 1;
}
