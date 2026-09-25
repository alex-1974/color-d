module d4_mapping_semantics;

import r0_8_gamut_fixture :
    Alpha,
    LinearSRgb,
    OklabHue,
    Oklch,
    deltaEOK,
    gamutMapLocalMinde,
    gamutMapRayTrace,
    inSrgbGamut,
    isColorScalar,
    toOklab,
    toOklch,
    toLinearSRgb;

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


private double mappedDelta(T)(
    LinearSRgb!T a,
    LinearSRgb!T b)
if (isColorScalar!T)
{
    return cast(double)deltaEOK(
        a.toOklab,
        b.toOklab
    );
}


private void reportAlpha(T)(string scalarName)
if (isColorScalar!T)
{
    const auto input =
        Oklch!T(
            cast(T)0.65,
            cast(T)0.35,
            OklabHue!T(cast(T)25)
        );

    const T a0 = cast(T)0;
    const T a37 = cast(T)0.37;
    const T a1 = cast(T)1;

    const auto local0 =
        gamutMapLocalMinde(
            Alpha!(Oklch!T)(input, a0)
        );
    const auto local37 =
        gamutMapLocalMinde(
            Alpha!(Oklch!T)(input, a37)
        );
    const auto local1 =
        gamutMapLocalMinde(
            Alpha!(Oklch!T)(input, a1)
        );

    const auto ray0 =
        gamutMapRayTrace(
            Alpha!(Oklch!T)(input, a0)
        );
    const auto ray37 =
        gamutMapRayTrace(
            Alpha!(Oklch!T)(input, a37)
        );
    const auto ray1 =
        gamutMapRayTrace(
            Alpha!(Oklch!T)(input, a1)
        );

    writefln(
        "D4-EXACT-%s-alpha = local-a0:%s local-a037:%s local-a1:%s ray-a0:%s ray-a037:%s ray-a1:%s",
        scalarName,
        local0.alpha == a0,
        local37.alpha == a37,
        local1.alpha == a1,
        ray0.alpha == a0,
        ray37.alpha == a37,
        ray1.alpha == a1
    );
}


private void reportInGamutIdentity(T)(
    string scalarName,
    ulong seed)
if (isColorScalar!T)
{
    enum size_t sampleCount = 4096;

    Lcg rng = Lcg(seed);

    size_t localExactFailures = 0;
    size_t rayExactFailures = 0;

    size_t localSuccessFailures = 0;
    size_t raySuccessFailures = 0;

    size_t localNonZeroIterations = 0;
    size_t rayNonZeroIterations = 0;

    double localMaxOriginalDelta = 0;
    double rayMaxOriginalDelta = 0;

    foreach (_; 0 .. sampleCount)
    {
        const auto original =
            LinearSRgb!T(
                cast(T)(0.05 + rng.unit() * 0.90),
                cast(T)(0.05 + rng.unit() * 0.90),
                cast(T)(0.05 + rng.unit() * 0.90)
            );

        const auto input =
            original.toOklch;

        const auto expected =
            input.toLinearSRgb;

        // Stay on the intended in-gamut fast-path sample only.
        if (!input.inSrgbGamut)
            continue;

        const auto local =
            gamutMapLocalMinde(input);

        const auto ray =
            gamutMapRayTrace(input);

        if (local.color != expected)
            ++localExactFailures;

        if (ray.color != expected)
            ++rayExactFailures;

        if (!local.success)
            ++localSuccessFailures;

        if (!ray.success)
            ++raySuccessFailures;

        if (local.iterations != 0)
            ++localNonZeroIterations;

        if (ray.iterations != 0)
            ++rayNonZeroIterations;

        const double localDelta =
            mappedDelta(original, local.color);

        const double rayDelta =
            mappedDelta(original, ray.color);

        if (localDelta > localMaxOriginalDelta)
            localMaxOriginalDelta = localDelta;

        if (rayDelta > rayMaxOriginalDelta)
            rayMaxOriginalDelta = rayDelta;
    }

    writefln(
        "D4-DERIVED-%s-in-gamut-identity samples=%s local_exact_failures=%s ray_exact_failures=%s local_success_failures=%s ray_success_failures=%s local_nonzero_iterations=%s ray_nonzero_iterations=%s local_max_original_deltaEOK=% .6e ray_max_original_deltaEOK=% .6e",
        scalarName,
        sampleCount,
        localExactFailures,
        rayExactFailures,
        localSuccessFailures,
        raySuccessFailures,
        localNonZeroIterations,
        rayNonZeroIterations,
        localMaxOriginalDelta,
        rayMaxOriginalDelta
    );
}


private void reportOutOfGamutMapping()
{
    enum size_t sampleCount = 4096;

    Lcg rng =
        Lcg(0xC010_D013_2026_0040UL);

    size_t accepted = 0;

    size_t localFloatSecondNonZero = 0;
    size_t localDoubleSecondNonZero = 0;
    size_t rayFloatSecondNonZero = 0;
    size_t rayDoubleSecondNonZero = 0;

    size_t localFloatSecondGamutFailures = 0;
    size_t localDoubleSecondGamutFailures = 0;
    size_t rayFloatSecondGamutFailures = 0;
    size_t rayDoubleSecondGamutFailures = 0;

    size_t localFloatExactIdempotent = 0;
    size_t localDoubleExactIdempotent = 0;
    size_t rayFloatExactIdempotent = 0;
    size_t rayDoubleExactIdempotent = 0;

    size_t localRayFloatExactEqual = 0;
    size_t localRayDoubleExactEqual = 0;

    double localFloatMaxIdempotenceDelta = 0;
    double localDoubleMaxIdempotenceDelta = 0;
    double rayFloatMaxIdempotenceDelta = 0;
    double rayDoubleMaxIdempotenceDelta = 0;

    double floatMaxCrossMethodDelta = 0;
    double doubleMaxCrossMethodDelta = 0;

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
                OklabHue!float(cast(float)h)
            );

        if (inputD.inSrgbGamut ||
            inputF.inSrgbGamut)
        {
            continue;
        }

        const auto localD =
            gamutMapLocalMinde(inputD);

        const auto localF =
            gamutMapLocalMinde(inputF);

        const auto rayD =
            gamutMapRayTrace(inputD);

        const auto rayF =
            gamutMapRayTrace(inputF);

        const auto localD2 =
            gamutMapLocalMinde(
                localD.color.toOklch
            );

        const auto localF2 =
            gamutMapLocalMinde(
                localF.color.toOklch
            );

        const auto rayD2 =
            gamutMapRayTrace(
                rayD.color.toOklch
            );

        const auto rayF2 =
            gamutMapRayTrace(
                rayF.color.toOklch
            );

        if (localD2.iterations != 0)
            ++localDoubleSecondNonZero;

        if (localF2.iterations != 0)
            ++localFloatSecondNonZero;

        if (rayD2.iterations != 0)
            ++rayDoubleSecondNonZero;

        if (rayF2.iterations != 0)
            ++rayFloatSecondNonZero;

        if (!localD2.color.inSrgbGamut)
            ++localDoubleSecondGamutFailures;

        if (!localF2.color.inSrgbGamut)
            ++localFloatSecondGamutFailures;

        if (!rayD2.color.inSrgbGamut)
            ++rayDoubleSecondGamutFailures;

        if (!rayF2.color.inSrgbGamut)
            ++rayFloatSecondGamutFailures;

        if (localD2.color == localD.color)
            ++localDoubleExactIdempotent;

        if (localF2.color == localF.color)
            ++localFloatExactIdempotent;

        if (rayD2.color == rayD.color)
            ++rayDoubleExactIdempotent;

        if (rayF2.color == rayF.color)
            ++rayFloatExactIdempotent;

        if (localD.color == rayD.color)
            ++localRayDoubleExactEqual;

        if (localF.color == rayF.color)
            ++localRayFloatExactEqual;

        const double localDDelta =
            mappedDelta(
                localD.color,
                localD2.color
            );

        const double localFDelta =
            mappedDelta(
                localF.color,
                localF2.color
            );

        const double rayDDelta =
            mappedDelta(
                rayD.color,
                rayD2.color
            );

        const double rayFDelta =
            mappedDelta(
                rayF.color,
                rayF2.color
            );

        if (localDDelta >
            localDoubleMaxIdempotenceDelta)
        {
            localDoubleMaxIdempotenceDelta =
                localDDelta;
        }

        if (localFDelta >
            localFloatMaxIdempotenceDelta)
        {
            localFloatMaxIdempotenceDelta =
                localFDelta;
        }

        if (rayDDelta >
            rayDoubleMaxIdempotenceDelta)
        {
            rayDoubleMaxIdempotenceDelta =
                rayDDelta;
        }

        if (rayFDelta >
            rayFloatMaxIdempotenceDelta)
        {
            rayFloatMaxIdempotenceDelta =
                rayFDelta;
        }

        const double crossD =
            mappedDelta(
                localD.color,
                rayD.color
            );

        const double crossF =
            mappedDelta(
                localF.color,
                rayF.color
            );

        if (crossD > doubleMaxCrossMethodDelta)
            doubleMaxCrossMethodDelta = crossD;

        if (crossF > floatMaxCrossMethodDelta)
            floatMaxCrossMethodDelta = crossF;

        ++accepted;
    }

    writefln(
        "D4-DERIVED-float-idempotence samples=%s local_second_nonzero=%s ray_second_nonzero=%s local_second_gamut_failures=%s ray_second_gamut_failures=%s local_exact_idempotent=%s ray_exact_idempotent=%s local_max_deltaEOK=% .6e ray_max_deltaEOK=% .6e",
        sampleCount,
        localFloatSecondNonZero,
        rayFloatSecondNonZero,
        localFloatSecondGamutFailures,
        rayFloatSecondGamutFailures,
        localFloatExactIdempotent,
        rayFloatExactIdempotent,
        localFloatMaxIdempotenceDelta,
        rayFloatMaxIdempotenceDelta
    );

    writefln(
        "D4-DERIVED-double-idempotence samples=%s local_second_nonzero=%s ray_second_nonzero=%s local_second_gamut_failures=%s ray_second_gamut_failures=%s local_exact_idempotent=%s ray_exact_idempotent=%s local_max_deltaEOK=% .6e ray_max_deltaEOK=% .6e",
        sampleCount,
        localDoubleSecondNonZero,
        rayDoubleSecondNonZero,
        localDoubleSecondGamutFailures,
        rayDoubleSecondGamutFailures,
        localDoubleExactIdempotent,
        rayDoubleExactIdempotent,
        localDoubleMaxIdempotenceDelta,
        rayDoubleMaxIdempotenceDelta
    );

    writefln(
        "D4-DERIVED-cross-method samples=%s float_exact_equal=%s double_exact_equal=%s float_max_deltaEOK=% .6e double_max_deltaEOK=% .6e",
        sampleCount,
        localRayFloatExactEqual,
        localRayDoubleExactEqual,
        floatMaxCrossMethodDelta,
        doubleMaxCrossMethodDelta
    );
}


enum ctfeAlphaInput =
    Alpha!(Oklch!double)(
        Oklch!double(
            0.65,
            0.35,
            OklabHue!double(25)
        ),
        0.37
    );

enum ctfeAlphaLocal =
    gamutMapLocalMinde(ctfeAlphaInput);

enum ctfeAlphaRay =
    gamutMapRayTrace(ctfeAlphaInput);

static assert(ctfeAlphaLocal.alpha == 0.37);
static assert(ctfeAlphaRay.alpha == 0.37);


void runD4()
{
    writeln();
    writeln(
        "=== D4 MAPPING SEMANTICS CHARACTERIZATION ==="
    );

    reportAlpha!float("float");
    reportAlpha!double("double");

    reportInGamutIdentity!float(
        "float",
        0xC010_D013_2026_0041UL
    );

    reportInGamutIdentity!double(
        "double",
        0xC010_D013_2026_0042UL
    );

    reportOutOfGamutMapping();
}
