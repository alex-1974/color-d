module public_api_root_surface;

import color;

// The curated root must expose every accepted v0.1 public value family.
static assert(is(SRgbf));
static assert(is(SRgbd));
static assert(is(LinearSRgbf));
static assert(is(LinearSRgbd));
static assert(is(XyzD65f));
static assert(is(XyzD65d));
static assert(is(Oklabf));
static assert(is(Oklabd));
static assert(is(OklabHuef));
static assert(is(OklabHued));
static assert(is(Oklchf));
static assert(is(Oklchd));
static assert(is(Alpha!SRgbd));
static assert(is(Premultiplied!LinearSRgbd));
static assert(is(Wcag2Measurement!double));
static assert(is(typeof(HuePath.shorter) == HuePath));

/*
 * Compile every accepted operation through the root import and use UFCS where
 * a semantic subject exists. This is intentionally compile-contract evidence,
 * not a numerical reference test.
 */
void acceptedRootAndUfcsSurface()
@safe pure nothrow @nogc
{
    const encoded =
        SRgbd(0.82, 0.25, 0.12);

    const linear =
        encoded.toLinear;

    const xyz =
        linear.toXyzD65;

    const lab =
        xyz.toOklab;

    auto lch =
        lab.toOklch;

    lch =
        lch
        .withLightness(0.70)
        .withChroma(0.16)
        .withHue(
            OklabHued.fromDegrees(40.0)
        );

    const storedHue =
        lch.h.rawDegrees;

    const positiveHue =
        lch.h.positiveDegrees;

    const signedHue =
        lch.h.signedDegrees;

    const hueRadians =
        lch.h.radians;

    const bool achromatic =
        lch.isAchromatic;

    const bool nearAchromatic =
        lch.isNearAchromatic(0.20);

    const canonical =
        lch.canonicalized;

    const labBack =
        lch.toOklab;

    const xyzBack =
        labBack.toXyzD65;

    const linearBack =
        xyzBack.toLinearSRgb;

    const encodedBack =
        linearBack.toSRgb;

    const bool gamutState =
        encodedBack.inGamut;

    const clipped =
        SRgbd(-0.1, 0.5, 1.1).clip;

    const localMapped =
        lch.gamutMapLocalMindeToLinearSRgb;

    const rayMapped =
        lch.gamutMapRayTraceToLinearSRgb;

    const straight =
        Alpha!LinearSRgbd(
            linear,
            0.5
        );

    const bool straightAlphaValid =
        straight.isValidAlpha;

    const premultiplied =
        straight.premultiply;

    const bool premultipliedAlphaValid =
        premultiplied.isValidAlpha;

    const straightBack =
        premultiplied.unpremultiply;

    const composed =
        premultiplied.sourceOver(
            premultiplied
        );

    const rectangular =
        encoded.interpolate(
            encodedBack,
            0.5
        );

    const polar =
        lch.interpolate(
            Oklchd(
                0.60,
                0.10,
                OklabHued.fromDegrees(100.0)
            ),
            0.5,
            HuePath.shorter
        );

    const alphaInterpolated =
        straight.interpolate(
            straightBack,
            0.5
        );

    const luminance =
        encoded.wcag2RelativeLuminance;

    const contrast =
        encoded.wcag2ContrastRatio(
            SRgbd(1.0, 1.0, 1.0)
        );

    const luminanceValue =
        luminance.value;

    const contrastValue =
        contrast.value;

    const difference =
        lab.deltaEOK(
            labBack
        );

    // The ordered endpoints have no unique mathematical "object", but the
    // first endpoint remains a natural UFCS subject and the template cardinality
    // stays explicit.
    const schedule =
        (0.0).linearSchedule!5(1.0);

    const double[3] lightnesses =
        [0.20, 0.50, 0.80];

    const double[3] chromas =
        [0.04, 0.10, 0.06];

    Oklchd[3] staticTones;

    lch.tonesAtLightnessAndChromaInto(
        lightnesses,
        chromas,
        staticTones
    );

    Oklchd[3] runtimeTones;

    const bool runtimeBatchOk =
        lch.tryTonesAtLightnessAndChromaInto(
            lightnesses[],
            chromas[],
            runtimeTones[]
        );

    // Alpha-preserving gamut mapping uses the same semantic subject position.
    const alphaLch =
        Alpha!Oklchd(
            lch,
            0.5
        );

    const alphaLocal =
        alphaLch.gamutMapLocalMindeToLinearSRgb;

    const alphaRay =
        alphaLch.gamutMapRayTraceToLinearSRgb;

    // Keep all values live enough for compile-time semantic checking.
    assert(storedHue == storedHue || storedHue != storedHue);
    assert(positiveHue == positiveHue || positiveHue != positiveHue);
    assert(signedHue == signedHue || signedHue != signedHue);
    assert(hueRadians == hueRadians || hueRadians != hueRadians);
    assert(achromatic || !achromatic);
    assert(nearAchromatic || !nearAchromatic);
    assert(canonical.l == canonical.l || canonical.l != canonical.l);
    assert(straightAlphaValid);
    assert(premultipliedAlphaValid);
    assert(luminanceValue == luminanceValue || luminanceValue != luminanceValue);
    assert(contrastValue == contrastValue || contrastValue != contrastValue);
    assert(gamutState || !gamutState);
    assert(clipped.r == clipped.r || clipped.r != clipped.r);
    assert(localMapped.r == localMapped.r || localMapped.r != localMapped.r);
    assert(rayMapped.r == rayMapped.r || rayMapped.r != rayMapped.r);
    assert(composed.alpha == composed.alpha || composed.alpha != composed.alpha);
    assert(rectangular.r == rectangular.r || rectangular.r != rectangular.r);
    assert(polar.l == polar.l || polar.l != polar.l);
    assert(alphaInterpolated.alpha == alphaInterpolated.alpha ||
           alphaInterpolated.alpha != alphaInterpolated.alpha);
    assert(luminance.valid || !luminance.valid);
    assert(contrast.valid || !contrast.valid);
    assert(difference == difference || difference != difference);
    assert(schedule.length == 5);
    assert(runtimeBatchOk);
    assert(alphaLocal.alpha == 0.5);
    assert(alphaRay.alpha == 0.5);
}

/*
 * Implementation mechanisms must not leak through the curated root import.
 * Each name below exists in production source but is intentionally private or
 * package-internal.
 */
static assert(!__traits(compiles,
    srgbToLinearComponent(0.5)
));
static assert(!__traits(compiles,
    linearToSrgbComponent(0.5)
));
static assert(!__traits(compiles,
    toLinearSRgbDirect(
        XyzD65d(0.1, 0.2, 0.3)
    )
));
static assert(!__traits(compiles,
    cubeRoot(8.0)
));
static assert(!__traits(compiles,
    normalizePositiveDegrees(390.0)
));
static assert(!__traits(compiles,
    oklabChromaMagnitude(0.1, 0.2)
));
static assert(!__traits(compiles,
    isSupportedAlphaColor!SRgbd
));
static assert(!__traits(compiles,
    HueEndpoints!double.init
));
static assert(!__traits(compiles,
    lerp(0.0, 1.0, 0.5)
));
static assert(!__traits(compiles,
    interpolateHue(
        OklabHued.fromDegrees(0.0),
        OklabHued.fromDegrees(90.0),
        0.5,
        HuePath.shorter
    )
));
static assert(!__traits(compiles,
    RayIntersection!double.init
));
static assert(!__traits(compiles,
    intersectUnitRgbCube(
        LinearSRgbd(0.0, 0.0, 0.0),
        LinearSRgbd(1.0, 1.0, 1.0)
    )
));
static assert(!__traits(compiles,
    gamutMapLocalMindeImpl(
        Oklchd(
            0.5,
            0.2,
            OklabHued.fromDegrees(30.0)
        )
    )
));
static assert(!__traits(compiles,
    makeWcag2Measurement(0.5)
));
static assert(!__traits(compiles,
    relativeLuminanceUnchecked(
        SRgbd(0.1, 0.2, 0.3)
    )
));
static assert(!__traits(compiles,
    isFiniteScheduleScalar(0.5)
));
static assert(!__traits(compiles,
    interpolateFiniteSchedule(0.0, 1.0, 0.5)
));
static assert(!__traits(compiles,
    tonesAtLightnessAndChromaIntoExact(
        Oklchd(
            0.5,
            0.1,
            OklabHued.fromDegrees(30.0)
        ),
        [0.2, 0.8],
        [0.1, 0.1],
        [
            Oklchd.init,
            Oklchd.init
        ]
    )
));

/*
 * The initial API intentionally has no generic/default shortcuts that would
 * compete with the explicit semantic operations.
 */
static assert(!__traits(compiles,
    SRgbd(0.1, 0.2, 0.3).toOklab
));
static assert(!__traits(compiles,
    gamutMap(
        Oklchd(
            0.5,
            0.2,
            OklabHued.fromDegrees(30.0)
        )
    )
));
static assert(!__traits(compiles,
    deltaE(
        Oklabd(0.5, 0.1, 0.0),
        Oklabd(0.6, 0.1, 0.0)
    )
));
static assert(!__traits(compiles,
    relativeLuminance(
        SRgbd(0.1, 0.2, 0.3)
    )
));
static assert(!__traits(compiles,
    contrastRatio(
        SRgbd(0.1, 0.2, 0.3),
        SRgbd(1.0, 1.0, 1.0)
    )
));
