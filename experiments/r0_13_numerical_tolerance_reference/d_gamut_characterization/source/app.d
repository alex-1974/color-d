module app;

import r0_8_gamut_fixture :
    LinearSRgb,
    OklabHue,
    Oklch,
    SRgb,
    clipToSrgb,
    inSrgbGamut,
    isColorScalar;

import std.math : nextDown, nextUp;
import std.math.traits : isIdentical, isNaN;
import std.stdio : writefln, writeln;

import d2_local_minde : runD2;
import d3_ray_trace : runD3;
import d4_mapping_semantics : runD4;


private void runD1For(T)(string scalarName)
if (isColorScalar!T)
{
    writeln();
    writeln(
        "=== D1 GAMUT CLASSIFICATION / POLICY / CLIP (",
        scalarName,
        ") ==="
    );

    const T zero = cast(T)0;
    const T one = cast(T)1;
    const T belowZero = nextDown(zero);
    const T aboveOne = nextUp(one);

    const auto black = LinearSRgb!T(zero, zero, zero);
    const auto white = LinearSRgb!T(one, one, one);
    const auto interior = LinearSRgb!T(
        cast(T)0.25,
        cast(T)0.5,
        cast(T)0.75
    );
    const auto below = LinearSRgb!T(
        belowZero,
        cast(T)0.5,
        cast(T)0.5
    );
    const auto above = LinearSRgb!T(
        aboveOne,
        cast(T)0.5,
        cast(T)0.5
    );

    writefln(
        "D1-CLASSIFY-%s-linear-strict = black:%s white:%s interior:%s next-below-zero:%s next-above-one:%s nan:%s posinf:%s neginf:%s",
        scalarName,
        black.inSrgbGamut,
        white.inSrgbGamut,
        interior.inSrgbGamut,
        below.inSrgbGamut,
        above.inSrgbGamut,
        LinearSRgb!T(T.nan, cast(T)0.5, cast(T)0.5)
            .inSrgbGamut,
        LinearSRgb!T(T.infinity, cast(T)0.5, cast(T)0.5)
            .inSrgbGamut,
        LinearSRgb!T(-T.infinity, cast(T)0.5, cast(T)0.5)
            .inSrgbGamut
    );

    writefln(
        "D1-CLASSIFY-%s-encoded-strict = black:%s white:%s interior:%s next-below-zero:%s next-above-one:%s",
        scalarName,
        SRgb!T(zero, zero, zero).inSrgbGamut,
        SRgb!T(one, one, one).inSrgbGamut,
        SRgb!T(
            cast(T)0.25,
            cast(T)0.5,
            cast(T)0.75
        ).inSrgbGamut,
        SRgb!T(
            belowZero,
            cast(T)0.5,
            cast(T)0.5
        ).inSrgbGamut,
        SRgb!T(
            aboveOne,
            cast(T)0.5,
            cast(T)0.5
        ).inSrgbGamut
    );

    const T policyEpsilon = cast(T)8 * T.epsilon;
    const T beyondLow = -cast(T)2 * policyEpsilon;
    const T beyondHigh =
        one + cast(T)2 * policyEpsilon;

    writefln(
        "D1-POLICY-%s-explicit-epsilon = epsilon=% .21g next-low:%s next-high:%s beyond-low:%s beyond-high:%s negative-epsilon-same:%s zero-epsilon-matches-strict:%s",
        scalarName,
        cast(real)policyEpsilon,
        below.inSrgbGamut(policyEpsilon),
        above.inSrgbGamut(policyEpsilon),
        LinearSRgb!T(
            beyondLow,
            cast(T)0.5,
            cast(T)0.5
        ).inSrgbGamut(policyEpsilon),
        LinearSRgb!T(
            beyondHigh,
            cast(T)0.5,
            cast(T)0.5
        ).inSrgbGamut(policyEpsilon),
        below.inSrgbGamut(-policyEpsilon) ==
            below.inSrgbGamut(policyEpsilon),
        below.inSrgbGamut(cast(T)0) ==
            below.inSrgbGamut
    );

    const auto clippedInterior =
        interior.clipToSrgb;

    const auto clippedMixed =
        LinearSRgb!T(
            cast(T)-0.25,
            cast(T)0.5,
            cast(T)1.25
        ).clipToSrgb;

    const auto clippedTwice =
        clippedMixed.clipToSrgb;

    writefln(
        "D1-EXACT-%s-clip = interior:%s low-zero:%s middle-preserved:%s high-one:%s idempotent:%s",
        scalarName,
        clippedInterior == interior,
        clippedMixed.r == zero,
        clippedMixed.g == cast(T)0.5,
        clippedMixed.b == one,
        clippedTwice == clippedMixed
    );

    const T negativeZero = -cast(T)0.0;
    const auto clippedNegativeZero =
        LinearSRgb!T(
            negativeZero,
            cast(T)0.5,
            cast(T)0.5
        ).clipToSrgb;

    writefln(
        "D1-EXACT-%s-signed-zero = negative-zero-preserved:%s",
        scalarName,
        isIdentical(
            clippedNegativeZero.r,
            negativeZero
        )
    );

    const auto clippedNaN =
        LinearSRgb!T(
            T.nan,
            cast(T)0.5,
            cast(T)0.5
        ).clipToSrgb;

    const auto clippedPosInf =
        LinearSRgb!T(
            T.infinity,
            cast(T)0.5,
            cast(T)0.5
        ).clipToSrgb;

    const auto clippedNegInf =
        LinearSRgb!T(
            -T.infinity,
            cast(T)0.5,
            cast(T)0.5
        ).clipToSrgb;

    writefln(
        "D1-CLASSIFY-%s-clip-nonfinite = nan-preserved:%s posinf-preserved:%s neginf-preserved:%s nan-in-gamut:%s posinf-in-gamut:%s neginf-in-gamut:%s",
        scalarName,
        isNaN(clippedNaN.r),
        clippedPosInf.r == T.infinity,
        clippedNegInf.r == -T.infinity,
        clippedNaN.inSrgbGamut,
        clippedPosInf.inSrgbGamut,
        clippedNegInf.inSrgbGamut
    );

    const auto neutral =
        Oklch!T(
            cast(T)0.5,
            cast(T)0,
            OklabHue!T(cast(T)30)
        );

    const auto highChroma =
        Oklch!T(
            cast(T)0.65,
            cast(T)0.35,
            OklabHue!T(cast(T)25)
        );

    writefln(
        "D1-DERIVED-%s-oklch-membership = neutral:%s high-chroma:%s",
        scalarName,
        neutral.inSrgbGamut,
        highChroma.inSrgbGamut
    );
}


enum ctfeStrictBlack =
    LinearSRgb!double(0, 0, 0).inSrgbGamut;

enum ctfeStrictBelow =
    LinearSRgb!double(-0.01, 0.5, 0.5)
        .inSrgbGamut;

enum ctfeClip =
    LinearSRgb!double(-0.25, 0.5, 1.25)
        .clipToSrgb;

static assert(ctfeStrictBlack);
static assert(!ctfeStrictBelow);
static assert(ctfeClip.r == 0.0);
static assert(ctfeClip.g == 0.5);
static assert(ctfeClip.b == 1.0);


void main()
{
    writeln(
        "=== color-d R0.13-D gamut characterization ==="
    );

    runD1For!float("float");
    runD1For!double("double");

    runD2();
    runD3();
    runD4();
}
