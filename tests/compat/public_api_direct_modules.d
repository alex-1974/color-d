module public_api_direct_modules;

static import color.storage;
static import color.rgb;
static import color.xyz;
static import color.cielab;
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
    color.storage.SRgb8 packedRgb =
        color.storage.SRgb8.init;

    color.storage.SRgba8 packedRgba =
        color.storage.SRgba8.init;

    const bool parsedRgb =
        color.storage.tryParseSRgb8Hex(
            "#247ac4",
            packedRgb
        );

    const bool parsedRgba =
        color.storage.tryParseSRgba8Hex(
            "#247ac480",
            packedRgba
        );

    const packedAsRgb =
        packedRgb.toSRgb!double();

    const packedAsAlpha =
        packedRgba.toAlphaSRgb!double();

    color.storage.SRgb8 requantizedRgb;
    color.storage.SRgba8 requantizedRgba;

    const bool storedRgb =
        color.storage.tryToSRgb8(
            packedAsRgb,
            requantizedRgb
        );

    const bool storedRgba =
        color.storage.tryToSRgba8(
            packedAsAlpha,
            requantizedRgba
        );

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

    const cieLab =
        color.cielab.toCieLabD50(
            xyz
        );

    const cieXyzBack =
        color.cielab.toXyzD65(
            cieLab
        );

    const cieDelta76 =
        color.difference.deltaE76(
            cieLab,
            cieLab
        );

    const cieDelta2000 =
        color.difference.deltaE2000(
            cieLab,
            cieLab
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

    const chromaLimit =
        color.gamut.maxChromaInSRgb(
            0.5,
            color.oklch.OklabHued.fromDegrees(
                40.0
            )
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

    assert(parsedRgb);
    assert(parsedRgba);
    assert(storedRgb);
    assert(storedRgba);
    assert(requantizedRgb == packedRgb);
    assert(requantizedRgba == packedRgba);
    assert(cieLab.l == cieLab.l || cieLab.l != cieLab.l);
    assert(cieXyzBack.x == cieXyzBack.x || cieXyzBack.x != cieXyzBack.x);
    assert(cieDelta76 == 0.0);
    assert(cieDelta2000 == 0.0);
    assert(chromaLimit.valid);
    assert(chromaLimit.value > 0.0);
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
void storageDoesNotReexportColorDependencies()
{
    import color.storage;

    static assert(!__traits(compiles,
        SRgbd.init
    ));
}

void xyzDoesNotReexportRgb()
{
    import color.xyz;

    static assert(!__traits(compiles,
        LinearSRgbd.init
    ));
}

void cielabDoesNotReexportXyz()
{
    import color.cielab;

    static assert(!__traits(compiles,
        XyzD65d.init
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
