module app;

import r0_8_gamut_fixture :
    Alpha,
    LinearSRgb,
    Oklab,
    OklabHue,
    Oklch,
    SRgb,
    XyzD65,
    decodeSrgbChannel,
    deltaEOK,
    encodeSrgbChannel,
    gamutMapLocalMinde,
    gamutMapRayTrace,
    inSrgbGamut,
    isColorScalar,
    toLinearSRgb,
    toOklab,
    toOklch,
    toSRgb,
    toXyzD65;

import std.stdio : writefln, writeln;


struct Snapshot(T)
if (isColorScalar!T)
{
    T decodedOrdinary;
    T decodedBoundary;
    T encodedOrdinary;
    T encodedBoundary;

    XyzD65!T xyz;
    Oklab!T lab;
    Oklch!T lch;

    T delta;

    LinearSRgb!T localColor;
    uint localIterations;
    bool localSuccess;
    bool localInGamut;

    LinearSRgb!T rayColor;
    uint rayIterations;
    bool raySuccess;
    bool rayInGamut;

    LinearSRgb!T rayProbeColor;
    uint rayProbeIterations;
    bool rayProbeSuccess;
    bool rayProbeInGamut;

    SRgb!T encodedRay;

    T localAlpha;
    T rayAlpha;
}


Snapshot!T buildSnapshot(T)()
if (isColorScalar!T)
{
    Snapshot!T result;

    result.decodedOrdinary =
        decodeSrgbChannel(cast(T)0.42);

    result.decodedBoundary =
        decodeSrgbChannel(cast(T)0.04045);

    result.encodedOrdinary =
        encodeSrgbChannel(cast(T)0.18);

    result.encodedBoundary =
        encodeSrgbChannel(cast(T)0.0031308);

    const auto rgb =
        LinearSRgb!T(
            cast(T)0.2,
            cast(T)0.4,
            cast(T)0.6
        );

    result.xyz =
        rgb.toXyzD65;

    result.lab =
        result.xyz.toOklab;

    result.lch =
        result.lab.toOklch;

    result.delta =
        deltaEOK(
            result.lab,
            Oklab!T(
                cast(T)0.61,
                cast(T)0.08,
                cast(T)-0.13
            )
        );

    const auto yellow =
        Oklch!T(
            cast(T)0.96476,
            cast(T)0.24503,
            OklabHue!T(cast(T)110.23)
        );

    const auto local =
        gamutMapLocalMinde(yellow);

    result.localColor =
        local.color;
    result.localIterations =
        local.iterations;
    result.localSuccess =
        local.success;
    result.localInGamut =
        local.color.inSrgbGamut;

    const auto ray =
        gamutMapRayTrace(yellow);

    result.rayColor =
        ray.color;
    result.rayIterations =
        ray.iterations;
    result.raySuccess =
        ray.success;
    result.rayInGamut =
        ray.color.inSrgbGamut;

    const auto rayProbe =
        gamutMapRayTrace(
            Oklch!T(
                cast(T)0.88228511810302734375L,
                cast(T)0.343281686305999755859L,
                OklabHue!T(
                    cast(T)19.4710636138916015625L
                )
            )
        );

    result.rayProbeColor =
        rayProbe.color;
    result.rayProbeIterations =
        rayProbe.iterations;
    result.rayProbeSuccess =
        rayProbe.success;
    result.rayProbeInGamut =
        rayProbe.color.inSrgbGamut;

    result.encodedRay =
        ray.color.toSRgb;

    const T alpha =
        cast(T)0.37;

    result.localAlpha =
        gamutMapLocalMinde(
            Alpha!(Oklch!T)(
                yellow,
                alpha
            )
        ).alpha;

    result.rayAlpha =
        gamutMapRayTrace(
            Alpha!(Oklch!T)(
                yellow,
                alpha
            )
        ).alpha;

    return result;
}


T absDiff(T)(T a, T b)
if (isColorScalar!T)
{
    return a >= b
        ? a - b
        : b - a;
}


void reportValue(T)(
    string scalarName,
    string name,
    T runtimeValue,
    T ctfeValue)
if (isColorScalar!T)
{
    writefln(
        "E1-CROSS-%s-%s = exact:%s runtime=% .21g ctfe=% .21g abs=% .6e",
        scalarName,
        name,
        runtimeValue == ctfeValue,
        cast(real)runtimeValue,
        cast(real)ctfeValue,
        cast(double)absDiff(
            runtimeValue,
            ctfeValue
        )
    );
}


void reportRgb(T)(
    string scalarName,
    string name,
    LinearSRgb!T runtimeValue,
    LinearSRgb!T ctfeValue)
if (isColorScalar!T)
{
    T maxDiff =
        absDiff(
            runtimeValue.r,
            ctfeValue.r
        );

    const T dg =
        absDiff(
            runtimeValue.g,
            ctfeValue.g
        );

    const T db =
        absDiff(
            runtimeValue.b,
            ctfeValue.b
        );

    if (dg > maxDiff)
        maxDiff = dg;

    if (db > maxDiff)
        maxDiff = db;

    writefln(
        "E1-CROSS-%s-%s = exact:%s max-abs=% .6e runtime=(% .21g,% .21g,% .21g) ctfe=(% .21g,% .21g,% .21g)",
        scalarName,
        name,
        runtimeValue == ctfeValue,
        cast(double)maxDiff,
        cast(real)runtimeValue.r,
        cast(real)runtimeValue.g,
        cast(real)runtimeValue.b,
        cast(real)ctfeValue.r,
        cast(real)ctfeValue.g,
        cast(real)ctfeValue.b
    );
}


void reportXyz(T)(
    string scalarName,
    XyzD65!T runtimeValue,
    XyzD65!T ctfeValue)
if (isColorScalar!T)
{
    T maxDiff =
        absDiff(
            runtimeValue.x,
            ctfeValue.x
        );

    const T dy =
        absDiff(
            runtimeValue.y,
            ctfeValue.y
        );

    const T dz =
        absDiff(
            runtimeValue.z,
            ctfeValue.z
        );

    if (dy > maxDiff)
        maxDiff = dy;

    if (dz > maxDiff)
        maxDiff = dz;

    writefln(
        "E1-CROSS-%s-xyz = exact:%s max-abs=% .6e runtime=(% .21g,% .21g,% .21g) ctfe=(% .21g,% .21g,% .21g)",
        scalarName,
        runtimeValue == ctfeValue,
        cast(double)maxDiff,
        cast(real)runtimeValue.x,
        cast(real)runtimeValue.y,
        cast(real)runtimeValue.z,
        cast(real)ctfeValue.x,
        cast(real)ctfeValue.y,
        cast(real)ctfeValue.z
    );
}


void reportLab(T)(
    string scalarName,
    Oklab!T runtimeValue,
    Oklab!T ctfeValue)
if (isColorScalar!T)
{
    T maxDiff =
        absDiff(
            runtimeValue.l,
            ctfeValue.l
        );

    const T da =
        absDiff(
            runtimeValue.a,
            ctfeValue.a
        );

    const T db =
        absDiff(
            runtimeValue.b,
            ctfeValue.b
        );

    if (da > maxDiff)
        maxDiff = da;

    if (db > maxDiff)
        maxDiff = db;

    writefln(
        "E1-CROSS-%s-oklab = exact:%s max-abs=% .6e runtime=(% .21g,% .21g,% .21g) ctfe=(% .21g,% .21g,% .21g)",
        scalarName,
        runtimeValue == ctfeValue,
        cast(double)maxDiff,
        cast(real)runtimeValue.l,
        cast(real)runtimeValue.a,
        cast(real)runtimeValue.b,
        cast(real)ctfeValue.l,
        cast(real)ctfeValue.a,
        cast(real)ctfeValue.b
    );
}


void reportLch(T)(
    string scalarName,
    Oklch!T runtimeValue,
    Oklch!T ctfeValue)
if (isColorScalar!T)
{
    T maxDiff =
        absDiff(
            runtimeValue.l,
            ctfeValue.l
        );

    const T dc =
        absDiff(
            runtimeValue.c,
            ctfeValue.c
        );

    const T dh =
        absDiff(
            runtimeValue.h.degrees,
            ctfeValue.h.degrees
        );

    if (dc > maxDiff)
        maxDiff = dc;

    if (dh > maxDiff)
        maxDiff = dh;

    writefln(
        "E1-CROSS-%s-oklch = exact:%s max-abs=% .6e runtime=(% .21g,% .21g,% .21g) ctfe=(% .21g,% .21g,% .21g)",
        scalarName,
        runtimeValue == ctfeValue,
        cast(double)maxDiff,
        cast(real)runtimeValue.l,
        cast(real)runtimeValue.c,
        cast(real)runtimeValue.h.degrees,
        cast(real)ctfeValue.l,
        cast(real)ctfeValue.c,
        cast(real)ctfeValue.h.degrees
    );
}


void reportEncoded(T)(
    string scalarName,
    SRgb!T runtimeValue,
    SRgb!T ctfeValue)
if (isColorScalar!T)
{
    T maxDiff =
        absDiff(
            runtimeValue.r,
            ctfeValue.r
        );

    const T dg =
        absDiff(
            runtimeValue.g,
            ctfeValue.g
        );

    const T db =
        absDiff(
            runtimeValue.b,
            ctfeValue.b
        );

    if (dg > maxDiff)
        maxDiff = dg;

    if (db > maxDiff)
        maxDiff = db;

    writefln(
        "E1-CROSS-%s-encoded-ray = exact:%s max-abs=% .6e runtime=(% .21g,% .21g,% .21g) ctfe=(% .21g,% .21g,% .21g)",
        scalarName,
        runtimeValue == ctfeValue,
        cast(double)maxDiff,
        cast(real)runtimeValue.r,
        cast(real)runtimeValue.g,
        cast(real)runtimeValue.b,
        cast(real)ctfeValue.r,
        cast(real)ctfeValue.g,
        cast(real)ctfeValue.b
    );
}


void reportMappingMetadata(
    T
)(
    string scalarName,
    string name,
    uint runtimeIterations,
    bool runtimeSuccess,
    bool runtimeInGamut,
    uint ctfeIterations,
    bool ctfeSuccess,
    bool ctfeInGamut)
if (isColorScalar!T)
{
    writefln(
        "E1-CROSS-%s-%s-metadata = iterations-exact:%s success-exact:%s gamut-exact:%s runtime=(%s,%s,%s) ctfe=(%s,%s,%s)",
        scalarName,
        name,
        runtimeIterations == ctfeIterations,
        runtimeSuccess == ctfeSuccess,
        runtimeInGamut == ctfeInGamut,
        runtimeIterations,
        runtimeSuccess,
        runtimeInGamut,
        ctfeIterations,
        ctfeSuccess,
        ctfeInGamut
    );
}


void reportScalar(T)(string scalarName)
if (isColorScalar!T)
{
    enum Snapshot!T ctfe =
        buildSnapshot!T();

    const Snapshot!T runtime =
        buildSnapshot!T();

    reportValue(
        scalarName,
        "decode-ordinary",
        runtime.decodedOrdinary,
        ctfe.decodedOrdinary
    );

    reportValue(
        scalarName,
        "decode-boundary",
        runtime.decodedBoundary,
        ctfe.decodedBoundary
    );

    reportValue(
        scalarName,
        "encode-ordinary",
        runtime.encodedOrdinary,
        ctfe.encodedOrdinary
    );

    reportValue(
        scalarName,
        "encode-boundary",
        runtime.encodedBoundary,
        ctfe.encodedBoundary
    );

    reportXyz(
        scalarName,
        runtime.xyz,
        ctfe.xyz
    );

    reportLab(
        scalarName,
        runtime.lab,
        ctfe.lab
    );

    reportLch(
        scalarName,
        runtime.lch,
        ctfe.lch
    );

    reportValue(
        scalarName,
        "deltaEOK",
        runtime.delta,
        ctfe.delta
    );

    reportRgb(
        scalarName,
        "local-yellow",
        runtime.localColor,
        ctfe.localColor
    );

    reportMappingMetadata!T(
        scalarName,
        "local-yellow",
        runtime.localIterations,
        runtime.localSuccess,
        runtime.localInGamut,
        ctfe.localIterations,
        ctfe.localSuccess,
        ctfe.localInGamut
    );

    reportRgb(
        scalarName,
        "ray-yellow",
        runtime.rayColor,
        ctfe.rayColor
    );

    reportMappingMetadata!T(
        scalarName,
        "ray-yellow",
        runtime.rayIterations,
        runtime.raySuccess,
        runtime.rayInGamut,
        ctfe.rayIterations,
        ctfe.raySuccess,
        ctfe.rayInGamut
    );

    reportRgb(
        scalarName,
        "ray-known-probe",
        runtime.rayProbeColor,
        ctfe.rayProbeColor
    );

    reportMappingMetadata!T(
        scalarName,
        "ray-known-probe",
        runtime.rayProbeIterations,
        runtime.rayProbeSuccess,
        runtime.rayProbeInGamut,
        ctfe.rayProbeIterations,
        ctfe.rayProbeSuccess,
        ctfe.rayProbeInGamut
    );

    reportEncoded(
        scalarName,
        runtime.encodedRay,
        ctfe.encodedRay
    );

    writefln(
        "E1-EXACT-%s-alpha = local:%s ray:%s runtime-local=% .21g ctfe-local=% .21g runtime-ray=% .21g ctfe-ray=% .21g",
        scalarName,
        runtime.localAlpha == ctfe.localAlpha &&
            runtime.localAlpha == cast(T)0.37,
        runtime.rayAlpha == ctfe.rayAlpha &&
            runtime.rayAlpha == cast(T)0.37,
        cast(real)runtime.localAlpha,
        cast(real)ctfe.localAlpha,
        cast(real)runtime.rayAlpha,
        cast(real)ctfe.rayAlpha
    );
}


int main()
{
    writeln(
        "=== color-d R0.13-E cross-execution characterization ==="
    );

    writefln(
        "E1-ENV-d-version = %s",
        __VERSION__
    );

    version (LDC)
        writeln("E1-ENV-compiler-family = LDC");
    else version (DigitalMars)
        writeln("E1-ENV-compiler-family = DMD");
    else
        writeln("E1-ENV-compiler-family = OTHER");

    reportScalar!float("float");
    reportScalar!double("double");

    return 0;
}
