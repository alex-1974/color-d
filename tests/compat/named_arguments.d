module named_arguments;

import color;

void main()
{
    const encodedA = SRgbd(0.10, 0.20, 0.30);
    const encodedB = SRgbd(0.70, 0.80, 0.90);

    const encodedMid =
        interpolate(
            first: encodedA,
            second: encodedB,
            t: 0.5
        );

    static assert(is(typeof(encodedMid) == SRgbd));

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

    static assert(is(typeof(polarMid) == Oklchd));

    const mapped =
        gamutMapRayTraceToLinearSRgb(
            color: polarMid
        );

    static assert(is(typeof(mapped) == LinearSRgbd));

    const contrast =
        wcag2ContrastRatio(
            first: encodedA,
            second: encodedB
        );

    static assert(is(typeof(contrast) == Wcag2Measurement!double));

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
