module public_api_direct_modules;

static import color.rgb;
static import color.xyz;
static import color.oklab;
static import color.oklch;
static import color.alpha;
static import color.composite;
static import color.interpolate;
static import color.gamut;
static import color.wcag;
static import color.difference;
static import color.tone;

/*
 * Every documented direct module remains independently addressable. Calls use
 * qualified module names so this probe does not depend on the curated root.
 */
void acceptedDirectModuleSurface()
@safe pure nothrow @nogc
{
    const encoded =
        color.rgb.SRgbd(
            0.82,
            0.25,
            0.12
        );

    const linear =
        color.rgb.toLinear(
            encoded
        );

    const xyz =
        color.xyz.toXyzD65(
            linear
        );

    const lab =
        color.oklab.toOklab(
            xyz
        );

    auto lch =
        color.oklch.toOklch(
            lab
        );

    lch =
        color.oklch.withLightness(
            lch,
            0.70
        );

    lch =
        color.oklch.withChroma(
            lch,
            0.16
        );

    lch =
        color.oklch.withHue(
            lch,
            color.oklch.OklabHued.fromDegrees(
                40.0
            )
        );

    const backLab =
        color.oklch.toOklab(
            lch
        );

    const backXyz =
        color.oklab.toXyzD65(
            backLab
        );

    const backLinear =
        color.xyz.toLinearSRgb(
            backXyz
        );

    const backEncoded =
        color.rgb.toSRgb(
            backLinear
        );

    const straight =
        color.alpha.Alpha!(
            color.rgb.LinearSRgbd
        )(
            linear,
            0.5
        );

    const premultiplied =
        color.alpha.premultiply(
            straight
        );

    const straightBack =
        color.alpha.unpremultiply(
            premultiplied
        );

    const composed =
        color.composite.sourceOver(
            premultiplied,
            premultiplied
        );

    const rectangular =
        color.interpolate.interpolate(
            encoded,
            backEncoded,
            0.5
        );

    const polar =
        color.interpolate.interpolate(
            lch,
            color.oklch.Oklchd(
                0.60,
                0.10,
                color.oklch.OklabHued.fromDegrees(
                    100.0
                )
            ),
            0.5,
            color.interpolate.HuePath.shorter
        );

    const bool inGamut =
        color.gamut.inGamut(
            backLinear
        );

    const clipped =
        color.gamut.clip(
            color.rgb.SRgbd(
                -0.1,
                0.5,
                1.1
            )
        );

    const localMapped =
        color.gamut.gamutMapLocalMindeToLinearSRgb(
            lch
        );

    const rayMapped =
        color.gamut.gamutMapRayTraceToLinearSRgb(
            lch
        );

    const luminance =
        color.wcag.wcag2RelativeLuminance(
            encoded
        );

    const contrast =
        color.wcag.wcag2ContrastRatio(
            encoded,
            color.rgb.SRgbd(
                1.0,
                1.0,
                1.0
            )
        );

    const difference =
        color.difference.deltaEOK(
            lab,
            backLab
        );

    const schedule =
        color.tone.linearSchedule!5(
            0.0,
            1.0
        );

    const double[3] lightnesses =
        [0.20, 0.50, 0.80];

    const double[3] chromas =
        [0.04, 0.10, 0.06];

    color.oklch.Oklchd[3] tones;

    color.tone.tonesAtLightnessAndChromaInto(
        lch,
        lightnesses,
        chromas,
        tones
    );

    color.oklch.Oklchd[3] runtimeTones;

    const bool batchOk =
        color.tone.tryTonesAtLightnessAndChromaInto(
            lch,
            lightnesses[],
            chromas[],
            runtimeTones[]
        );

    assert(straightBack.alpha == 0.5);
    assert(composed.alpha == composed.alpha || composed.alpha != composed.alpha);
    assert(rectangular.r == rectangular.r || rectangular.r != rectangular.r);
    assert(polar.l == polar.l || polar.l != polar.l);
    assert(inGamut || !inGamut);
    assert(clipped.r == clipped.r || clipped.r != clipped.r);
    assert(localMapped.r == localMapped.r || localMapped.r != localMapped.r);
    assert(rayMapped.r == rayMapped.r || rayMapped.r != rayMapped.r);
    assert(luminance.valid || !luminance.valid);
    assert(contrast.valid || !contrast.valid);
    assert(difference == difference || difference != difference);
    assert(schedule.length == 5);
    assert(batchOk);
}

/*
 * Supported direct modules must not become accidental transitive facades.
 * Dependency types/functions remain owned by their documented modules.
 */
static assert(!__traits(compiles,
    color.xyz.SRgbd(
        0.1,
        0.2,
        0.3
    )
));
static assert(!__traits(compiles,
    color.oklab.XyzD65d(
        0.1,
        0.2,
        0.3
    )
));
static assert(!__traits(compiles,
    color.oklch.Oklabd(
        0.5,
        0.1,
        0.0
    )
));
static assert(!__traits(compiles,
    color.alpha.Oklchd(
        0.5,
        0.1,
        color.oklch.OklabHued.fromDegrees(
            30.0
        )
    )
));
static assert(!__traits(compiles,
    color.composite.Premultiplied!(
        color.rgb.LinearSRgbd
    ).init
));
static assert(!__traits(compiles,
    color.interpolate.Oklchd(
        0.5,
        0.1,
        color.oklch.OklabHued.fromDegrees(
            30.0
        )
    )
));
static assert(!__traits(compiles,
    color.gamut.Oklchd(
        0.5,
        0.1,
        color.oklch.OklabHued.fromDegrees(
            30.0
        )
    )
));
static assert(!__traits(compiles,
    color.wcag.SRgbd(
        0.1,
        0.2,
        0.3
    )
));
static assert(!__traits(compiles,
    color.difference.Oklabd(
        0.5,
        0.1,
        0.0
    )
));
static assert(!__traits(compiles,
    color.tone.Oklch!double.init
));
static assert(!__traits(compiles,
    color.tone.withLightness
));
