module repro_boxed_generic;

import std.stdio : writefln;

struct Color(T)
{
    T l;
    T c;
    T h;
}

struct PaletteBox(T, size_t F, size_t N)
{
    Color!T[N][F] value;
}

struct Bundle(T, size_t F, size_t N)
{
    Color!T[N][F] raw;
    Color!T[N][F] mapped;
    Color!T[N][F] encoded;
}

Color!T[N][F] makeBare(
    T,
    size_t F,
    size_t N
)(
    const T[F] hues,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
{
    Color!T[N][F] result;

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

    return result;
}

void makeFamilyInto(
    T,
    size_t N
)(
    ref Color!T[N] result,
    const T hue,
    const T[N] lightnesses,
    const T[N] chromas
)
{
    foreach (n; 0 .. N)
    {
        result[n] =
            Color!T(
                lightnesses[n],
                chromas[n],
                hue
            );
    }
}

PaletteBox!(T, F, N) makeBoxed(
    T,
    size_t F,
    size_t N
)(
    const T[F] hues,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
{
    PaletteBox!(T, F, N) result;

    foreach (f; 0 .. F)
    {
        makeFamilyInto!(T, N)(
            result.value[f],
            hues[f],
            lightnesses[f],
            chromas[f]
        );
    }

    return result;
}

Bundle!(T, F, N) makeBundle(
    T,
    size_t F,
    size_t N
)(
    const T[F] hues,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
{
    const boxed =
        makeBoxed!(T, F, N)(
            hues,
            lightnesses,
            chromas
        );

    Bundle!(T, F, N) result;

    result.raw = boxed.value;
    result.mapped = boxed.value;
    result.encoded = boxed.value;

    return result;
}

bool correct(T)(const T l, const T c, const T h)
{
    return
        l == cast(T)0.5 &&
        c == cast(T)0.0 &&
        h == cast(T)725.0;
}


/*
 * CTFE validation.
 */

enum float[1] floatHues =
    [725.0f];

enum float[1][1] floatLightnesses =
    [[0.5f]];

enum float[1][1] floatChromas =
    [[0.0f]];

enum floatBox =
    makeBoxed!(float, 1, 1)(
        floatHues,
        floatLightnesses,
        floatChromas
    );

enum floatBundle =
    makeBundle!(float, 1, 1)(
        floatHues,
        floatLightnesses,
        floatChromas
    );

static assert(
    floatBox.value[0][0].l == 0.5f
);

static assert(
    floatBox.value[0][0].c == 0.0f
);

static assert(
    floatBox.value[0][0].h == 725.0f
);

static assert(
    floatBundle.raw[0][0].l == 0.5f
);

static assert(
    floatBundle.raw[0][0].c == 0.0f
);

static assert(
    floatBundle.raw[0][0].h == 725.0f
);


enum double[1] doubleHues =
    [725.0];

enum double[1][1] doubleLightnesses =
    [[0.5]];

enum double[1][1] doubleChromas =
    [[0.0]];

enum doubleBox =
    makeBoxed!(double, 1, 1)(
        doubleHues,
        doubleLightnesses,
        doubleChromas
    );

enum doubleBundle =
    makeBundle!(double, 1, 1)(
        doubleHues,
        doubleLightnesses,
        doubleChromas
    );

static assert(
    doubleBox.value[0][0].l == 0.5
);

static assert(
    doubleBox.value[0][0].c == 0.0
);

static assert(
    doubleBox.value[0][0].h == 725.0
);

static assert(
    doubleBundle.raw[0][0].l == 0.5
);

static assert(
    doubleBundle.raw[0][0].c == 0.0
);

static assert(
    doubleBundle.raw[0][0].h == 725.0
);


void testScalar(T)(
    const char[] scalarName
)
{
    T[1] hues =
        [cast(T)725.0];

    T[1][1] lightnesses =
        [[cast(T)0.5]];

    T[1][1] chromas =
        [[cast(T)0.0]];

    const bare =
        makeBare!(T, 1, 1)(
            hues,
            lightnesses,
            chromas
        );

    const boxed =
        makeBoxed!(T, 1, 1)(
            hues,
            lightnesses,
            chromas
        );

    const bundle =
        makeBundle!(T, 1, 1)(
            hues,
            lightnesses,
            chromas
        );

    const bool bareOK =
        correct(
            bare[0][0].l,
            bare[0][0].c,
            bare[0][0].h
        );

    const bool boxedOK =
        correct(
            boxed.value[0][0].l,
            boxed.value[0][0].c,
            boxed.value[0][0].h
        );

    const bool bundleOK =
        correct(
            bundle.raw[0][0].l,
            bundle.raw[0][0].c,
            bundle.raw[0][0].h
        );

    writefln(
        "%s bare   %s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        bareOK ? "PASS" : "FAIL",
        cast(double)bare[0][0].l,
        cast(double)bare[0][0].c,
        cast(double)bare[0][0].h
    );

    writefln(
        "%s boxed  %s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        boxedOK ? "PASS" : "FAIL",
        cast(double)boxed.value[0][0].l,
        cast(double)boxed.value[0][0].c,
        cast(double)boxed.value[0][0].h
    );

    writefln(
        "%s bundle %s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        bundleOK ? "PASS" : "FAIL",
        cast(double)bundle.raw[0][0].l,
        cast(double)bundle.raw[0][0].c,
        cast(double)bundle.raw[0][0].h
    );

    assert(boxedOK);
    assert(bundleOK);
}

int main()
{
    writefln("generic boxed-return compatibility:");

    testScalar!float("float ");
    testScalar!double("double");

    return 0;
}
