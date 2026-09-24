module repro_abi_matrix;

import std.stdio : writefln, writeln;

struct Color(T)
{
    T l;
    T c;
    T h;
}


Color!T[1][1] ret0(T)()
@safe pure nothrow @nogc
{
    Color!T[1][1] result;

    result[0][0] =
        Color!T(
            cast(T)0.5,
            cast(T)0.0,
            cast(T)725.0
        );

    return result;
}


Color!T[1][1] retSeed(T)(
    const Color!T[1] seeds
)
@safe pure nothrow @nogc
{
    Color!T[1][1] result;

    result[0][0] =
        Color!T(
            cast(T)0.5,
            cast(T)0.0,
            seeds[0].h
        );

    return result;
}


Color!T[1][1] retSeedL(T)(
    const Color!T[1] seeds,
    const T[1][1] lightnesses
)
@safe pure nothrow @nogc
{
    Color!T[1][1] result;

    result[0][0] =
        Color!T(
            lightnesses[0][0],
            cast(T)0.0,
            seeds[0].h
        );

    return result;
}


Color!T[1][1] retSeedLC(T)(
    const Color!T[1] seeds,
    const T[1][1] lightnesses,
    const T[1][1] chromas
)
@safe pure nothrow @nogc
{
    Color!T[1][1] result;

    result[0][0] =
        Color!T(
            lightnesses[0][0],
            chromas[0][0],
            seeds[0].h
        );

    return result;
}


/*
 * Same three-argument ABI shape, but values do not depend on arguments.
 * If this fails too, argument use is irrelevant and the signature itself
 * participates in the trigger.
 */
Color!T[1][1] retSeedLCIgnored(T)(
    const Color!T[1] seeds,
    const T[1][1] lightnesses,
    const T[1][1] chromas
)
@safe pure nothrow @nogc
{
    Color!T[1][1] result;

    result[0][0] =
        Color!T(
            cast(T)0.5,
            cast(T)0.0,
            cast(T)725.0
        );

    return result;
}


/*
 * Same three parameters, but a one-dimensional return.
 * The existing experiments indicate this return shape is healthy.
 */
Color!T[1] retFamilySeedLC(T)(
    const Color!T[1] seeds,
    const T[1][1] lightnesses,
    const T[1][1] chromas
)
@safe pure nothrow @nogc
{
    Color!T[1] result;

    result[0] =
        Color!T(
            lightnesses[0][0],
            chromas[0][0],
            seeds[0].h
        );

    return result;
}


bool testScalar(T)(string scalarName)
{
    Color!T[1] seeds =
    [
        Color!T(
            cast(T)0.5,
            cast(T)0.0,
            cast(T)725.0
        )
    ];

    T[1][1] lightnesses =
    [
        [cast(T)0.5]
    ];

    T[1][1] chromas =
    [
        [cast(T)0.0]
    ];

    bool ok = true;

    const auto r0 =
        ret0!T();

    const bool r0OK =
        r0[0][0].l == cast(T)0.5 &&
        r0[0][0].c == cast(T)0.0 &&
        r0[0][0].h == cast(T)725.0;

    writefln(
        "%-6s %-18s %-4s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        "ret0",
        r0OK ? "PASS" : "FAIL",
        cast(double)r0[0][0].l,
        cast(double)r0[0][0].c,
        cast(double)r0[0][0].h
    );

    ok = ok && r0OK;


    const auto rSeed =
        retSeed!T(
            seeds
        );

    const bool rSeedOK =
        rSeed[0][0].l == cast(T)0.5 &&
        rSeed[0][0].c == cast(T)0.0 &&
        rSeed[0][0].h == cast(T)725.0;

    writefln(
        "%-6s %-18s %-4s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        "retSeed",
        rSeedOK ? "PASS" : "FAIL",
        cast(double)rSeed[0][0].l,
        cast(double)rSeed[0][0].c,
        cast(double)rSeed[0][0].h
    );

    ok = ok && rSeedOK;


    const auto rSeedL =
        retSeedL!T(
            seeds,
            lightnesses
        );

    const bool rSeedLOK =
        rSeedL[0][0].l == cast(T)0.5 &&
        rSeedL[0][0].c == cast(T)0.0 &&
        rSeedL[0][0].h == cast(T)725.0;

    writefln(
        "%-6s %-18s %-4s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        "retSeedL",
        rSeedLOK ? "PASS" : "FAIL",
        cast(double)rSeedL[0][0].l,
        cast(double)rSeedL[0][0].c,
        cast(double)rSeedL[0][0].h
    );

    ok = ok && rSeedLOK;


    const auto rSeedLC =
        retSeedLC!T(
            seeds,
            lightnesses,
            chromas
        );

    const bool rSeedLCOK =
        rSeedLC[0][0].l == cast(T)0.5 &&
        rSeedLC[0][0].c == cast(T)0.0 &&
        rSeedLC[0][0].h == cast(T)725.0;

    writefln(
        "%-6s %-18s %-4s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        "retSeedLC",
        rSeedLCOK ? "PASS" : "FAIL",
        cast(double)rSeedLC[0][0].l,
        cast(double)rSeedLC[0][0].c,
        cast(double)rSeedLC[0][0].h
    );

    ok = ok && rSeedLCOK;


    const auto rIgnored =
        retSeedLCIgnored!T(
            seeds,
            lightnesses,
            chromas
        );

    const bool rIgnoredOK =
        rIgnored[0][0].l == cast(T)0.5 &&
        rIgnored[0][0].c == cast(T)0.0 &&
        rIgnored[0][0].h == cast(T)725.0;

    writefln(
        "%-6s %-18s %-4s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        "retSeedLCIgnored",
        rIgnoredOK ? "PASS" : "FAIL",
        cast(double)rIgnored[0][0].l,
        cast(double)rIgnored[0][0].c,
        cast(double)rIgnored[0][0].h
    );

    ok = ok && rIgnoredOK;


    const auto rFamily =
        retFamilySeedLC!T(
            seeds,
            lightnesses,
            chromas
        );

    const bool rFamilyOK =
        rFamily[0].l == cast(T)0.5 &&
        rFamily[0].c == cast(T)0.0 &&
        rFamily[0].h == cast(T)725.0;

    writefln(
        "%-6s %-18s %-4s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        "retFamilySeedLC",
        rFamilyOK ? "PASS" : "FAIL",
        cast(double)rFamily[0].l,
        cast(double)rFamily[0].c,
        cast(double)rFamily[0].h
    );

    ok = ok && rFamilyOK;

    return ok;
}


int main()
{
    writeln("ABI trigger matrix:");

    const bool f =
        testScalar!float("float");

    const bool d =
        testScalar!double("double");

    return f && d ? 0 : 1;
}
