module repro_generic_into;

import std.stdio : writefln;

struct Color(T)
{
    T l;
    T c;
    T h;
}

struct Bundle(T, size_t F, size_t N)
{
    Color!T[N][F] raw;
    Color!T[N][F] mapped;
    Color!T[N][F] encoded;
}

void makePaletteInto(
    T,
    size_t F,
    size_t N
)(
    ref Color!T[N][F] result,
    const T[F] hues,
    const T[N][F] lightnesses,
    const T[N][F] chromas
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

void makeBundleInto(
    T,
    size_t F,
    size_t N
)(
    ref Bundle!(T, F, N) result,
    const T[F] hues,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
{
    makePaletteInto!(T, F, N)(
        result.raw,
        hues,
        lightnesses,
        chromas
    );

    foreach (f; 0 .. F)
    {
        foreach (n; 0 .. N)
        {
            result.mapped[f][n] =
                result.raw[f][n];

            result.encoded[f][n] =
                result.raw[f][n];
        }
    }
}

/*
 * CTFE construction uses exactly the same mutation kernels.
 * The aggregate return is consumed at compile time only.
 */
Bundle!(T, F, N) makeBundleCtfe(
    T,
    size_t F,
    size_t N
)(
    const T[F] hues,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
{
    Bundle!(T, F, N) result;

    makeBundleInto!(T, F, N)(
        result,
        hues,
        lightnesses,
        chromas
    );

    return result;
}

bool correct(T)(
    const T l,
    const T c,
    const T h
)
{
    return
        l == cast(T)0.5 &&
        c == cast(T)0.0 &&
        h == cast(T)725.0;
}

/*
 * CTFE — float
 */
enum float[1] floatHues =
    [725.0f];

enum float[1][1] floatLightnesses =
    [[0.5f]];

enum float[1][1] floatChromas =
    [[0.0f]];

enum floatCtfe =
    makeBundleCtfe!(float, 1, 1)(
        floatHues,
        floatLightnesses,
        floatChromas
    );

static assert(
    floatCtfe.raw[0][0].l == 0.5f &&
    floatCtfe.raw[0][0].c == 0.0f &&
    floatCtfe.raw[0][0].h == 725.0f
);

static assert(
    floatCtfe.mapped[0][0].l ==
        floatCtfe.raw[0][0].l &&
    floatCtfe.mapped[0][0].c ==
        floatCtfe.raw[0][0].c &&
    floatCtfe.mapped[0][0].h ==
        floatCtfe.raw[0][0].h
);

static assert(
    floatCtfe.encoded[0][0].l ==
        floatCtfe.raw[0][0].l &&
    floatCtfe.encoded[0][0].c ==
        floatCtfe.raw[0][0].c &&
    floatCtfe.encoded[0][0].h ==
        floatCtfe.raw[0][0].h
);

static immutable Bundle!(float, 1, 1) floatStatic =
    floatCtfe;

static assert(
    floatStatic.raw[0][0].l == 0.5f &&
    floatStatic.raw[0][0].c == 0.0f &&
    floatStatic.raw[0][0].h == 725.0f
);

/*
 * CTFE — double
 */
enum double[1] doubleHues =
    [725.0];

enum double[1][1] doubleLightnesses =
    [[0.5]];

enum double[1][1] doubleChromas =
    [[0.0]];

enum doubleCtfe =
    makeBundleCtfe!(double, 1, 1)(
        doubleHues,
        doubleLightnesses,
        doubleChromas
    );

static assert(
    doubleCtfe.raw[0][0].l == 0.5 &&
    doubleCtfe.raw[0][0].c == 0.0 &&
    doubleCtfe.raw[0][0].h == 725.0
);

static assert(
    doubleCtfe.mapped[0][0].l ==
        doubleCtfe.raw[0][0].l &&
    doubleCtfe.mapped[0][0].c ==
        doubleCtfe.raw[0][0].c &&
    doubleCtfe.mapped[0][0].h ==
        doubleCtfe.raw[0][0].h
);

static assert(
    doubleCtfe.encoded[0][0].l ==
        doubleCtfe.raw[0][0].l &&
    doubleCtfe.encoded[0][0].c ==
        doubleCtfe.raw[0][0].c &&
    doubleCtfe.encoded[0][0].h ==
        doubleCtfe.raw[0][0].h
);

static immutable Bundle!(double, 1, 1) doubleStatic =
    doubleCtfe;

static assert(
    doubleStatic.raw[0][0].l == 0.5 &&
    doubleStatic.raw[0][0].c == 0.0 &&
    doubleStatic.raw[0][0].h == 725.0
);

bool testScalar(T)(
    const char[] scalarName
)
{
    T[1] hues =
        [cast(T)725.0];

    T[1][1] lightnesses =
        [[cast(T)0.5]];

    T[1][1] chromas =
        [[cast(T)0.0]];

    Color!T[1][1] palette;

    makePaletteInto!(T, 1, 1)(
        palette,
        hues,
        lightnesses,
        chromas
    );

    Bundle!(T, 1, 1) bundle;

    makeBundleInto!(T, 1, 1)(
        bundle,
        hues,
        lightnesses,
        chromas
    );

    const bool paletteOK =
        correct(
            palette[0][0].l,
            palette[0][0].c,
            palette[0][0].h
        );

    const bool rawOK =
        correct(
            bundle.raw[0][0].l,
            bundle.raw[0][0].c,
            bundle.raw[0][0].h
        );

    const bool mappedOK =
        bundle.mapped[0][0].l ==
            bundle.raw[0][0].l &&
        bundle.mapped[0][0].c ==
            bundle.raw[0][0].c &&
        bundle.mapped[0][0].h ==
            bundle.raw[0][0].h;

    const bool encodedOK =
        bundle.encoded[0][0].l ==
            bundle.raw[0][0].l &&
        bundle.encoded[0][0].c ==
            bundle.raw[0][0].c &&
        bundle.encoded[0][0].h ==
            bundle.raw[0][0].h;

    writefln(
        "%s palette-into %s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        paletteOK ? "PASS" : "FAIL",
        cast(double)palette[0][0].l,
        cast(double)palette[0][0].c,
        cast(double)palette[0][0].h
    );

    writefln(
        "%s bundle-into  %s  L=%.17e C=%.17e H=%.17e",
        scalarName,
        rawOK ? "PASS" : "FAIL",
        cast(double)bundle.raw[0][0].l,
        cast(double)bundle.raw[0][0].c,
        cast(double)bundle.raw[0][0].h
    );

    writefln(
        "%s members      %s",
        scalarName,
        mappedOK && encodedOK
            ? "PASS"
            : "FAIL"
    );

    return
        paletteOK &&
        rawOK &&
        mappedOK &&
        encodedOK;
}

int main()
{
    writefln(
        "generic caller-owned compatibility:"
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
