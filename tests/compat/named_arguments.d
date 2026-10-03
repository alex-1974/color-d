module named_arguments;

import color;
import std.traits : Unqual;

void main()
{
    const encodedA = SRgbd(0.10, 0.20, 0.30);
    const encodedB = SRgbd(0.70, 0.80, 0.90);

    SRgb8 packedRgb = SRgb8.init;

    const bool parsedRgb =
        tryParseSRgb8Hex(
            text: "#247ac4",
            output: packedRgb
        );

    static assert(is(Unqual!(typeof(parsedRgb)) == bool));

    const normalizedPacked =
        packedRgb.toSRgb!double();

    SRgb8 storedRgb;

    const bool stored =
        tryToSRgb8(
            value: normalizedPacked,
            output: storedRgb
        );

    assert(stored);

    const linearForCie =
        encodedA.toLinear;

    const xyzForCie =
        linearForCie.toXyzD65;

    const cieLab =
        toCieLabD50(
            xyz: xyzForCie
        );

    const xyzFromCie =
        toXyzD65(
            lab: cieLab
        );

    const cie76 =
        deltaE76(
            lhs: cieLab,
            rhs: cieLab
        );

    const cie2000 =
        deltaE2000(
            lhs: cieLab,
            rhs: cieLab
        );

    const chromaLimit =
        maxChromaInSRgb(
            lightness: 0.50,
            hue: OklabHued.fromDegrees(40.0)
        );

    const simulated =
        machado2009(
            color: linearForCie,
            deficiency: RedGreenCvdDeficiency.protan,
            severity: 0.50
        );

    PreparedMachado2009!double preparedMachado;

    const bool prepared =
        tryPrepareMachado2009(
            deficiency: RedGreenCvdDeficiency.protan,
            severity: 0.50,
            prepared: preparedMachado
        );

    static assert(is(Unqual!(typeof(cieLab)) == CieLabD50d));
    static assert(is(Unqual!(typeof(xyzFromCie)) == XyzD65d));
    static assert(is(Unqual!(typeof(cie76)) == double));
    static assert(is(Unqual!(typeof(cie2000)) == double));
    static assert(is(Unqual!(typeof(chromaLimit)) == SRgbChromaLimit!double));
    static assert(is(Unqual!(typeof(simulated)) == LinearSRgbd));
    assert(prepared);

    const encodedMid =
        interpolate(
            first: encodedA,
            second: encodedB,
            t: 0.5
        );

    static assert(is(Unqual!(typeof(encodedMid)) == SRgbd));

    const polarA =
        Oklchd(
            0.50,
            0.12,
            OklabHued.fromDegrees(350.0)
        );

    const polarB =
        Oklchd(
            0.70,
            0.18,
            OklabHued.fromDegrees(10.0)
        );

    const polarMid =
        interpolate(
            first: polarA,
            second: polarB,
            t: 0.5,
            path: HuePath.shorter
        );

    static assert(is(Unqual!(typeof(polarMid)) == Oklchd));

    const mapped =
        gamutMapRayTraceToLinearSRgb(
            color: polarMid
        );

    static assert(is(Unqual!(typeof(mapped)) == LinearSRgbd));

    const contrast =
        wcag2ContrastRatio(
            first: encodedA,
            second: encodedB
        );

    static assert(is(Unqual!(typeof(contrast)) == Wcag2Measurement!double));

    enum schedule =
        linearSchedule!3(
            start: 0.20,
            end: 0.80
        );

    static assert(schedule.length == 3);

    double[2] lightnesses = [0.25, 0.75];
    double[2] chromas = [0.05, 0.15];
    Oklchd[2] output;

    const bool ok =
        tryTonesAtLightnessAndChromaInto(
            seed: polarA,
            lightnesses: lightnesses[],
            chromas: chromas[],
            output: output[]
        );

    assert(ok);
}
