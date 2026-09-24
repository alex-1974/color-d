module repro_generic_ref_inputs;

import std.stdio : writefln;

struct Color(T)
{
    T l;
    T c;
    T h;
}

/*
 * Control:
 * generic scalar type, but no static-array inputs cross the ABI boundary.
 */
void makeScalarInto(T)(
    ref Color!T[1][1] result,
    const T hue,
    const T lightness,
    const T chroma
)
{
    result[0][0] =
        Color!T(
            lightness,
            chroma,
            hue
        );
}

/*
 * Candidate:
 * output AND all static-array inputs are passed by reference.
 */
void makeRefInputsInto(
    T,
    size_t F,
    size_t N
)(
    ref Color!T[N][F] result,
    ref const(T[F]) hues,
    ref const(T[N][F]) lightnesses,
    ref const(T[N][F]) chromas
)
{
    foreach (f; 0 .. F)
    {
        foreach (n; 0 .. N)
        {
            result[f][n] =
                Color!T(
                    lightnesses[f][n],
                    chromas[f][n],
                    hues[f]
                );
        }
    }
}

bool correct(T)(
    const Color!T value
)
{
    return
        value.l == cast(T)0.5 &&
        value.c == cast(T)0.0 &&
        value.h == cast(T)725.0;
}

bool testScalar(T)(
    const char[] scalarName
)
{
    bool ok = true;

    /*
     * First isolate the generic ref-output path using scalars only.
     */
    Color!T[1][1] scalarResult;

    makeScalarInto!T(
        scalarResult,
        cast(T)725.0,
        cast(T)0.5,
        cast(T)0.0
    );

    const bool scalarOK =
        correct(scalarResult[0][0]);

    writefln(
        "%s scalar-inputs %s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        scalarOK ? "PASS" : "FAIL",
        cast(double)scalarResult[0][0].l,
        cast(double)scalarResult[0][0].c,
        cast(double)scalarResult[0][0].h
    );

    ok = ok && scalarOK;

    /*
     * Now pass every static-array argument by ref const.
     */
    T[1] hues =
        [cast(T)725.0];

    T[1][1] lightnesses =
        [[cast(T)0.5]];

    T[1][1] chromas =
        [[cast(T)0.0]];

    Color!T[1][1] refResult;

    makeRefInputsInto!(T, 1, 1)(
        refResult,
        hues,
        lightnesses,
        chromas
    );

    const bool refInputsOK =
        correct(refResult[0][0]);

    writefln(
        "%s ref-inputs    %s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        refInputsOK ? "PASS" : "FAIL",
        cast(double)refResult[0][0].l,
        cast(double)refResult[0][0].c,
        cast(double)refResult[0][0].h
    );

    ok = ok && refInputsOK;

    return ok;
}

int main()
{
    writefln(
        "generic ABI input isolation:"
    );

    const bool floatOK =
        testScalar!float("float ");

    const bool doubleOK =
        testScalar!double("double");

    return
        floatOK && doubleOK
            ? 0
            : 1;
}
