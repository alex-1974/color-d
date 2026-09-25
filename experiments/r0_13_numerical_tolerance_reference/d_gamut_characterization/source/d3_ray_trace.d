module d3_ray_trace;

import r0_8_gamut_fixture :
    LinearSRgb,
    OklabHue,
    Oklch,
    gamutMapRayTrace,
    inSrgbGamut,
    isColorScalar,
    rayEpsilon,
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


private void reportSemanticCases(T)(string scalarName)
if (isColorScalar!T)
{
    const auto nonFinite =
        gamutMapRayTrace(
            Oklch!T(
                T.nan,
                cast(T)0.2,
                OklabHue!T(cast(T)30)
            )
        );

    const auto tooLight =
        gamutMapRayTrace(
            Oklch!T(
                cast(T)1.2,
                cast(T)0.2,
                OklabHue!T(cast(T)30)
            )
        );

    const auto tooDark =
        gamutMapRayTrace(
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
        gamutMapRayTrace(inGamutInput);

    const auto negativeChroma =
        gamutMapRayTrace(
            Oklch!T(
                cast(T)0.65,
                cast(T)-0.35,
                OklabHue!T(cast(T)25)
            )
        );

    const auto canonicalChroma =
        gamutMapRayTrace(
            Oklch!T(
                cast(T)0.65,
                cast(T)0.35,
                OklabHue!T(cast(T)205)
            )
        );

    writefln(
        "D3-EXACT-%s-boundary-fast-path = light-white:%s dark-black:%s light-iter0:%s dark-iter0:%s light-success:%s dark-success:%s",
        scalarName,
        tooLight.color == LinearSRgb!T(1, 1, 1),
        tooDark.color == LinearSRgb!T(0, 0, 0),
        tooLight.iterations == 0,
        tooDark.iterations == 0,
        tooLight.success,
        tooDark.success
    );

    writefln(
        "D3-EXACT-%s-in-gamut-fast-path = rgb-exact:%s iterations-zero:%s success:%s",
        scalarName,
        inGamutResult.color == inGamutExpected,
        inGamutResult.iterations == 0,
        inGamutResult.success
    );

    writefln(
        "D3-EXACT-%s-negative-chroma-canonicalization = color:%s iterations:%s success:%s",
        scalarName,
        negativeChroma.color == canonicalChroma.color,
        negativeChroma.iterations == canonicalChroma.iterations,
        negativeChroma.success == canonicalChroma.success
    );

    writefln(
        "D3-CLASSIFY-%s-nonfinite = success:%s iterations-zero:%s output-in-gamut:%s",
        scalarName,
        nonFinite.success,
        nonFinite.iterations == 0,
        nonFinite.color.inSrgbGamut
    );

    writefln(
        "D3-ALGORITHM-%s-ray-trace = ray-epsilon=% .21g fixed-iteration-budget=%s",
        scalarName,
        cast(real)rayEpsilon!T,
        4
    );
}


private void reportSelected(T)(
    string scalarName,
    string caseName,
    Oklch!T input)
if (isColorScalar!T)
{
    const auto result =
        gamutMapRayTrace(input);

    writefln(
        "D3-REGRESSION-%s-%s = r=% .21g g=% .21g b=% .21g iterations=%s success=%s in-gamut=%s",
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
        Lcg(0xC010_D013_2026_0030UL);

    size_t accepted = 0;

    size_t floatSuccessFailures = 0;
    size_t doubleSuccessFailures = 0;

    size_t floatGamutFailures = 0;
    size_t doubleGamutFailures = 0;

    size_t floatBudgetViolations = 0;
    size_t doubleBudgetViolations = 0;
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
            gamutMapRayTrace(inputD);

        const auto resultF =
            gamutMapRayTrace(inputF);

        if (!resultD.success)
            ++doubleSuccessFailures;

        if (!resultF.success)
        {
            ++floatSuccessFailures;

            if (floatSuccessFailures <= 8)
            {
                const auto inputRgbF =
                    inputF.toLinearSRgb;

                writefln(
                    "D3-FAILURE-float-%s = input-l=% .21g input-c=% .21g input-h=% .21g input-r=% .21g input-g=% .21g input-b=% .21g result-r=% .21g result-g=% .21g result-b=% .21g iterations=%s in-gamut=%s double-success=%s double-r=% .21g double-g=% .21g double-b=% .21g",
                    floatSuccessFailures,
                    cast(real)inputF.l,
                    cast(real)inputF.c,
                    cast(real)inputF.h.degrees,
                    cast(real)inputRgbF.r,
                    cast(real)inputRgbF.g,
                    cast(real)inputRgbF.b,
                    cast(real)resultF.color.r,
                    cast(real)resultF.color.g,
                    cast(real)resultF.color.b,
                    resultF.iterations,
                    resultF.color.inSrgbGamut,
                    resultD.success,
                    cast(real)resultD.color.r,
                    cast(real)resultD.color.g,
                    cast(real)resultD.color.b
                );
            }
        }

        if (!resultD.color.inSrgbGamut)
            ++doubleGamutFailures;

        if (!resultF.color.inSrgbGamut)
            ++floatGamutFailures;

        if (resultD.iterations > 4)
            ++doubleBudgetViolations;

        if (resultF.iterations > 4)
            ++floatBudgetViolations;

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
        "D3-DERIVED-paired-properties samples=%s float_success_failures=%s double_success_failures=%s float_gamut_failures=%s double_gamut_failures=%s float_budget_violations=%s double_budget_violations=%s iteration_differences=%s max_float_iterations=%s max_double_iterations=%s max_rgb_abs_difference=% .6e max_deltaEOK=% .6e",
        sampleCount,
        floatSuccessFailures,
        doubleSuccessFailures,
        floatGamutFailures,
        doubleGamutFailures,
        floatBudgetViolations,
        doubleBudgetViolations,
        iterationDifferences,
        maxFloatIterations,
        maxDoubleIterations,
        maxRgbAbsDifference,
        maxDeltaEOK
    );
}


enum ctfeRayWhite =
    gamutMapRayTrace(
        Oklch!double(
            1.2,
            0.2,
            OklabHue!double(30)
        )
    );

enum ctfeRayBlack =
    gamutMapRayTrace(
        Oklch!double(
            -0.2,
            0.2,
            OklabHue!double(30)
        )
    );

static assert(
    ctfeRayWhite.color ==
    LinearSRgb!double(1, 1, 1)
);

static assert(
    ctfeRayBlack.color ==
    LinearSRgb!double(0, 0, 0)
);

static assert(ctfeRayWhite.iterations == 0);
static assert(ctfeRayBlack.iterations == 0);
static assert(ctfeRayWhite.success);
static assert(ctfeRayBlack.success);


void runD3()
{
    writeln();

    writeln(
        "=== D3 RAY TRACE CHARACTERIZATION ==="
    );

    reportSemanticCases!float("float");
    reportSemanticCases!double("double");

    reportSelectedCases();
    reportGeneratedPaired();
}
