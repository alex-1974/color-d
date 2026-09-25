module d2_local_minde;

import r0_8_gamut_fixture :
    LinearSRgb,
    OklabHue,
    Oklch,
    gamutMapLocalMinde,
    inSrgbGamut,
    isColorScalar,
    toOklab,
    toOklch,
    toLinearSRgb;

import std.math.algebraic : hypot;
import std.stdio : writefln, writeln;


private struct Lcg
{
    ulong state;

    uint next() @safe pure nothrow @nogc
    {
        state =
            state * 6364136223846793005UL +
            1442695040888963407UL;

        return cast(uint)(state >> 32);
    }

    double unit() @safe pure nothrow @nogc
    {
        return
            cast(double)next() /
            cast(double)uint.max;
    }
}


private double diagnosticDeltaEOK(
    LinearSRgb!double a,
    LinearSRgb!double b)
@safe pure nothrow @nogc
{
    const auto labA = a.toOklab;
    const auto labB = b.toOklab;

    const double dl = labA.l - labB.l;
    const double da = labA.a - labB.a;
    const double db = labA.b - labB.b;

    return hypot(dl, da, db);
}


private void reportSelected(T)(
    string scalarName,
    string caseName,
    Oklch!T input)
if (isColorScalar!T)
{
    const auto result =
        gamutMapLocalMinde(input);

    writefln(
        "D2-REGRESSION-%s-%s = r=% .21g g=% .21g b=% .21g iterations=%s success=%s in-gamut=%s",
        scalarName,
        caseName,
        cast(real)result.color.r,
        cast(real)result.color.g,
        cast(real)result.color.b,
        result.iterations,
        result.success,
        result.color.inSrgbGamut
    );
}


private void reportSemanticCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto nonFinite =
        gamutMapLocalMinde(
            Oklch!T(
                T.nan,
                cast(T)0.2,
                OklabHue!T(cast(T)30)
            )
        );

    const auto tooLight =
        gamutMapLocalMinde(
            Oklch!T(
                cast(T)1.2,
                cast(T)0.2,
                OklabHue!T(cast(T)30)
            )
        );

    const auto tooDark =
        gamutMapLocalMinde(
            Oklch!T(
                cast(T)-0.2,
                cast(T)0.2,
                OklabHue!T(cast(T)30)
            )
        );

    const auto inGamutInput =
        LinearSRgb!T(
            cast(T)0.2,
            cast(T)0.4,
            cast(T)0.6
        ).toOklch;

    const auto inGamutExpected =
        inGamutInput.toLinearSRgb;

    const auto inGamutResult =
        gamutMapLocalMinde(inGamutInput);

    const auto negativeChroma =
        gamutMapLocalMinde(
            Oklch!T(
                cast(T)0.65,
                cast(T)-0.35,
                OklabHue!T(cast(T)25)
            )
        );

    const auto canonicalChroma =
        gamutMapLocalMinde(
            Oklch!T(
                cast(T)0.65,
                cast(T)0.35,
                OklabHue!T(cast(T)205)
            )
        );

    writefln(
        "D2-EXACT-%s-boundary-fast-path = light-white:%s dark-black:%s light-iter0:%s dark-iter0:%s light-success:%s dark-success:%s",
        scalarName,
        tooLight.color == LinearSRgb!T(1, 1, 1),
        tooDark.color == LinearSRgb!T(0, 0, 0),
        tooLight.iterations == 0,
        tooDark.iterations == 0,
        tooLight.success,
        tooDark.success
    );

    writefln(
        "D2-EXACT-%s-in-gamut-fast-path = rgb-exact:%s iterations-zero:%s success:%s",
        scalarName,
        inGamutResult.color == inGamutExpected,
        inGamutResult.iterations == 0,
        inGamutResult.success
    );

    writefln(
        "D2-EXACT-%s-negative-chroma-canonicalization = color:%s iterations:%s success:%s",
        scalarName,
        negativeChroma.color == canonicalChroma.color,
        negativeChroma.iterations == canonicalChroma.iterations,
        negativeChroma.success == canonicalChroma.success
    );

    writefln(
        "D2-CLASSIFY-%s-nonfinite = success:%s iterations-zero:%s output-in-gamut:%s",
        scalarName,
        nonFinite.success,
        nonFinite.iterations == 0,
        nonFinite.color.inSrgbGamut
    );

    writefln(
        "D2-ALGORITHM-%s-local-minde = JND=% .21g chroma-search-epsilon=% .21g defensive-iteration-bound=%s",
        scalarName,
        cast(real)cast(T)0.02,
        cast(real)cast(T)0.0001,
        128
    );
}


private void reportSelectedCases()
{
    reportSelected!float(
        "float",
        "published-yellow",
        Oklch!float(
            0.96476f,
            0.24503f,
            OklabHue!float(110.23f)
        )
    );

    reportSelected!double(
        "double",
        "published-yellow",
        Oklch!double(
            0.96476,
            0.24503,
            OklabHue!double(110.23)
        )
    );

    foreach (caseName, l, c, h; [
        ["high-chroma-red",   "0.65", "0.35", "25"],
        ["high-chroma-green", "0.75", "0.35", "145"],
        ["high-chroma-blue",  "0.55", "0.35", "265"],
        ["near-white",        "0.97", "0.15", "40"],
        ["near-black",        "0.08", "0.12", "300"]
    ])
    {
        // The literal table is kept as text only to make the cases readable;
        // explicit typed calls below preserve compile-time type clarity.
    }

    reportSelected!float(
        "float",
        "high-chroma-red",
        Oklch!float(0.65f, 0.35f, OklabHue!float(25.0f))
    );
    reportSelected!double(
        "double",
        "high-chroma-red",
        Oklch!double(0.65, 0.35, OklabHue!double(25.0))
    );

    reportSelected!float(
        "float",
        "high-chroma-green",
        Oklch!float(0.75f, 0.35f, OklabHue!float(145.0f))
    );
    reportSelected!double(
        "double",
        "high-chroma-green",
        Oklch!double(0.75, 0.35, OklabHue!double(145.0))
    );

    reportSelected!float(
        "float",
        "high-chroma-blue",
        Oklch!float(0.55f, 0.35f, OklabHue!float(265.0f))
    );
    reportSelected!double(
        "double",
        "high-chroma-blue",
        Oklch!double(0.55, 0.35, OklabHue!double(265.0))
    );

    reportSelected!float(
        "float",
        "near-white",
        Oklch!float(0.97f, 0.15f, OklabHue!float(40.0f))
    );
    reportSelected!double(
        "double",
        "near-white",
        Oklch!double(0.97, 0.15, OklabHue!double(40.0))
    );

    reportSelected!float(
        "float",
        "near-black",
        Oklch!float(0.08f, 0.12f, OklabHue!float(300.0f))
    );
    reportSelected!double(
        "double",
        "near-black",
        Oklch!double(0.08, 0.12, OklabHue!double(300.0))
    );
}


private void reportGeneratedPaired()
{
    enum size_t sampleCount = 4096;

    Lcg rng =
        Lcg(0xC010_D013_2026_0020UL);

    size_t accepted = 0;

    size_t floatSuccessFailures = 0;
    size_t doubleSuccessFailures = 0;

    size_t floatGamutFailures = 0;
    size_t doubleGamutFailures = 0;

    size_t iterationDifferences = 0;

    uint maxFloatIterations = 0;
    uint maxDoubleIterations = 0;

    double maxRgbAbsDifference = 0;
    double maxDeltaEOK = 0;

    while (accepted < sampleCount)
    {
        const double l =
            0.05 +
            rng.unit() * 0.90;

        const double c =
            0.22 +
            rng.unit() * 0.24;

        const double h =
            rng.unit() * 360.0;

        const auto inputD =
            Oklch!double(
                l,
                c,
                OklabHue!double(h)
            );

        const auto inputF =
            Oklch!float(
                cast(float)l,
                cast(float)c,
                OklabHue!float(
                    cast(float)h)
            );

        if (inputD.inSrgbGamut ||
            inputF.inSrgbGamut)
        {
            continue;
        }

        const auto resultD =
            gamutMapLocalMinde(inputD);

        const auto resultF =
            gamutMapLocalMinde(inputF);

        if (!resultD.success)
            ++doubleSuccessFailures;

        if (!resultF.success)
            ++floatSuccessFailures;

        if (!resultD.color.inSrgbGamut)
            ++doubleGamutFailures;

        if (!resultF.color.inSrgbGamut)
            ++floatGamutFailures;

        if (resultD.iterations !=
            resultF.iterations)
        {
            ++iterationDifferences;
        }

        if (resultD.iterations >
            maxDoubleIterations)
        {
            maxDoubleIterations =
                resultD.iterations;
        }

        if (resultF.iterations >
            maxFloatIterations)
        {
            maxFloatIterations =
                resultF.iterations;
        }

        const double fr =
            cast(double)resultF.color.r;

        const double fg =
            cast(double)resultF.color.g;

        const double fb =
            cast(double)resultF.color.b;

        double rgbDiff =
            fr > resultD.color.r
                ? fr - resultD.color.r
                : resultD.color.r - fr;

        const double gDiff =
            fg > resultD.color.g
                ? fg - resultD.color.g
                : resultD.color.g - fg;

        const double bDiff =
            fb > resultD.color.b
                ? fb - resultD.color.b
                : resultD.color.b - fb;

        if (gDiff > rgbDiff)
            rgbDiff = gDiff;

        if (bDiff > rgbDiff)
            rgbDiff = bDiff;

        if (rgbDiff > maxRgbAbsDifference)
            maxRgbAbsDifference = rgbDiff;

        const double de =
            diagnosticDeltaEOK(
                LinearSRgb!double(fr, fg, fb),
                resultD.color
            );

        if (de > maxDeltaEOK)
            maxDeltaEOK = de;

        ++accepted;
    }

    writefln(
        "D2-DERIVED-paired-properties samples=%s float_success_failures=%s double_success_failures=%s float_gamut_failures=%s double_gamut_failures=%s iteration_differences=%s max_float_iterations=%s max_double_iterations=%s max_rgb_abs_difference=% .6e max_deltaEOK=% .6e",
        sampleCount,
        floatSuccessFailures,
        doubleSuccessFailures,
        floatGamutFailures,
        doubleGamutFailures,
        iterationDifferences,
        maxFloatIterations,
        maxDoubleIterations,
        maxRgbAbsDifference,
        maxDeltaEOK
    );
}


enum ctfeLocalWhite =
    gamutMapLocalMinde(
        Oklch!double(
            1.2,
            0.2,
            OklabHue!double(30)
        )
    );

enum ctfeLocalBlack =
    gamutMapLocalMinde(
        Oklch!double(
            -0.2,
            0.2,
            OklabHue!double(30)
        )
    );

static assert(
    ctfeLocalWhite.color ==
    LinearSRgb!double(1, 1, 1)
);

static assert(
    ctfeLocalBlack.color ==
    LinearSRgb!double(0, 0, 0)
);

static assert(ctfeLocalWhite.iterations == 0);
static assert(ctfeLocalBlack.iterations == 0);
static assert(ctfeLocalWhite.success);
static assert(ctfeLocalBlack.success);


void runD2()
{
    writeln();

    writeln(
        "=== D2 LOCAL MINDE CHARACTERIZATION ==="
    );

    reportSemanticCases!float("float");
    reportSemanticCases!double("double");

    reportSelectedCases();
    reportGeneratedPaired();
}
