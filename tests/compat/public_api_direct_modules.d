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
static import color.cvd;

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

    const brettel =
        color.cvd.brettel1997Dichromat(
            linear,
            color.cvd.CvdDeficiency.protan
        );

    const vienot =
        color.cvd.vienot1999Dichromat(
            linear,
            color.cvd.RedGreenCvdDeficiency.deutan
        );

    const machado =
        color.cvd.machado2009(
            linear,
            color.cvd.RedGreenCvdDeficiency.protan,
            0.5
        );

    const preparedBrettel =
        color.cvd.prepareBrettel1997Dichromat!double(
            color.cvd.CvdDeficiency.protan
        );

    const preparedVienot =
        color.cvd.prepareVienot1999Dichromat!double(
            color.cvd.RedGreenCvdDeficiency.deutan
        );

    color.cvd.PreparedMachado2009!double preparedMachado;

    const bool machadoPrepared =
        color.cvd.tryPrepareMachado2009(
            color.cvd.RedGreenCvdDeficiency.protan,
            0.5,
            preparedMachado
        );

    const preparedBrettelColor =
        preparedBrettel.apply(linear);

    const preparedVienotColor =
        preparedVienot.apply(linear);

    const preparedMachadoColor =
        preparedMachado.apply(linear);

    const color.rgb.LinearSRgbd[2] cvdInput =
    [
        linear,
        backLinear
    ];

    color.rgb.LinearSRgbd[2] cvdOutput;

    preparedBrettel.applyInto(
        cvdInput,
        cvdOutput
    );

    const bool cvdBatchOk =
        preparedVienot.tryApplyInto(
            cvdInput[],
            cvdOutput[]
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
    assert(brettel.r == brettel.r || brettel.r != brettel.r);
    assert(vienot.g == vienot.g || vienot.g != vienot.g);
    assert(machado.b == machado.b || machado.b != machado.b);
    assert(machadoPrepared);
    assert(preparedBrettelColor.r == preparedBrettelColor.r ||
           preparedBrettelColor.r != preparedBrettelColor.r);
    assert(preparedVienotColor.g == preparedVienotColor.g ||
           preparedVienotColor.g != preparedVienotColor.g);
    assert(preparedMachadoColor.b == preparedMachadoColor.b ||
           preparedMachadoColor.b != preparedMachadoColor.b);
    assert(cvdBatchOk);
    assert(luminance.valid || !luminance.valid);
    assert(contrast.valid || !contrast.valid);
    assert(difference == difference || difference != difference);
    assert(schedule.length == 5);
    assert(batchOk);
}

/*
 * Normal direct imports must not re-export their implementation dependencies
 * into the caller's unqualified namespace. D permits explicit module
 * qualification for names known through an imported module; that technical
 * reachability is not the public-import contract being tested here.
 *
 * Local imports keep each check isolated while the top-level static imports
 * above remain qualified-only.
 */
void xyzDoesNotReexportRgb()
{
    import color.xyz;

    static assert(!__traits(compiles,
        LinearSRgbd.init
    ));
}

void oklabDoesNotReexportXyz()
{
    import color.oklab;

    static assert(!__traits(compiles,
        XyzD65d.init
    ));
}

void oklchDoesNotReexportOklab()
{
    import color.oklch;

    static assert(!__traits(compiles,
        Oklabd.init
    ));
}

void alphaDoesNotReexportColorDependencies()
{
    import color.alpha;

    static assert(!__traits(compiles,
        Oklchd.init
    ));
}

void compositeDoesNotReexportAlpha()
{
    import color.composite;
    import color.rgb;

    static assert(!__traits(compiles,
        Premultiplied!LinearSRgbd.init
    ));
}

void interpolateDoesNotReexportColorDependencies()
{
    import color.interpolate;

    static assert(!__traits(compiles,
        Oklch!double.init
    ));
}

void gamutDoesNotReexportColorDependencies()
{
    import color.gamut;

    static assert(!__traits(compiles,
        Oklch!double.init
    ));
}

void wcagDoesNotReexportRgb()
{
    import color.wcag;

    static assert(!__traits(compiles,
        SRgb!double.init
    ));
}

void differenceDoesNotReexportOklab()
{
    import color.difference;

    static assert(!__traits(compiles,
        Oklabd.init
    ));
}

void toneDoesNotReexportOklch()
{
    import color.tone;

    static assert(!__traits(compiles,
        Oklch!double.init
    ));
}


void cvdDoesNotReexportRgb()
{
    import color.cvd;

    static assert(!__traits(compiles,
        LinearSRgbd.init
    ));
}
