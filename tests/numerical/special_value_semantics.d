module special_value_semantics;

import color;
import std.stdio : writefln, writeln;

private bool finite(T)(T value)
{
    return
        value == value &&
        value != T.infinity &&
        value != -T.infinity;
}

private bool positiveZero(T)(T value)
{
    return
        value == cast(T)0 &&
        cast(T)1 / value == T.infinity;
}

private bool auditOklabToOklchRange(T)(string scalar)
{
    enum T halfMax =
        T.max / cast(T)2;

    enum ctfeNearMax =
        Oklab!T(
            cast(T)0.5,
            halfMax,
            halfMax
        ).toOklch;

    enum ctfeSmall =
        Oklab!T(
            cast(T)0.5,
            T.min_normal,
            cast(T)0
        ).toOklch;

    enum ctfeZero =
        Oklab!T(
            cast(T)0.5,
            -cast(T)0,
            cast(T)0
        ).toOklch;

    Oklab!T runtimeNearMaxInput =
        Oklab!T(
            cast(T)0.5,
            halfMax,
            halfMax
        );

    Oklab!T runtimeSmallInput =
        Oklab!T(
            cast(T)0.5,
            T.min_normal,
            cast(T)0
        );

    Oklab!T runtimeZeroInput =
        Oklab!T(
            cast(T)0.5,
            -cast(T)0,
            cast(T)0
        );

    const runtimeNearMax =
        runtimeNearMaxInput.toOklch;

    const runtimeSmall =
        runtimeSmallInput.toOklch;

    const runtimeZero =
        runtimeZeroInput.toOklch;

    writefln(
        "%s near-max: ctfe-c=% .21g finite=%s runtime-c=% .21g finite=%s",
        scalar,
        cast(real)ctfeNearMax.c,
        finite(ctfeNearMax.c),
        cast(real)runtimeNearMax.c,
        finite(runtimeNearMax.c)
    );

    writefln(
        "%s min-normal: ctfe-c=% .21g exact=%s runtime-c=% .21g exact=%s",
        scalar,
        cast(real)ctfeSmall.c,
        ctfeSmall.c == T.min_normal,
        cast(real)runtimeSmall.c,
        runtimeSmall.c == T.min_normal
    );

    writefln(
        "%s signed-zero: ctfe-c=+0:%s ctfe-h=+0:%s runtime-c=+0:%s runtime-h=+0:%s",
        scalar,
        positiveZero(ctfeZero.c),
        positiveZero(ctfeZero.h.rawDegrees),
        positiveZero(runtimeZero.c),
        positiveZero(runtimeZero.h.rawDegrees)
    );

    return
        finite(ctfeNearMax.c) &&
        ctfeNearMax.c > halfMax &&
        finite(runtimeNearMax.c) &&
        runtimeNearMax.c > halfMax &&
        ctfeSmall.c == T.min_normal &&
        runtimeSmall.c == T.min_normal &&
        positiveZero(ctfeZero.c) &&
        positiveZero(ctfeZero.h.rawDegrees) &&
        positiveZero(runtimeZero.c) &&
        positiveZero(runtimeZero.h.rawDegrees);
}

int main()
{
    writeln("=== color-d public special-value audit ===");

    const bool floatOk =
        auditOklabToOklchRange!float("float");

    const bool doubleOk =
        auditOklabToOklchRange!double("double");

    return
        floatOk && doubleOk
            ? 0
            : 1;
}
