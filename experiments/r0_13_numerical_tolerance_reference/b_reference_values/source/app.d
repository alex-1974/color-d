module app;

import std.math : nextDown, nextUp;
import std.stdio : writeln, writefln;
import common;
import implementation;
import reference_values;

void observe(T)(string id, T actual, real reference)
{
    report(ScalarObservation!T(id, actual, reference));
}

void transferProbes(T)(string scalarName)
{
    writeln("\n[B1 transfer / ", scalarName, "]");

    const T decodeBoundary = cast(T)0.04045;
    const T encodeBoundary = cast(T)0.0031308;

    observe("B1-DECODE-" ~ scalarName ~ "-ZERO",
        srgbToLinear(cast(T)0), srgbToLinearReference(0.0L));
    observe("B1-DECODE-" ~ scalarName ~ "-BOUNDARY-BELOW",
        srgbToLinear(nextDown(decodeBoundary)),
        srgbToLinearReference(cast(real)nextDown(decodeBoundary)));
    observe("B1-DECODE-" ~ scalarName ~ "-BOUNDARY-AT",
        srgbToLinear(decodeBoundary),
        srgbToLinearReference(cast(real)decodeBoundary));
    observe("B1-DECODE-" ~ scalarName ~ "-BOUNDARY-ABOVE",
        srgbToLinear(nextUp(decodeBoundary)),
        srgbToLinearReference(cast(real)nextUp(decodeBoundary)));
    observe("B1-DECODE-" ~ scalarName ~ "-ORDINARY-018",
        srgbToLinear(cast(T)0.18), srgbToLinearReference(cast(real)cast(T)0.18));
    observe("B1-DECODE-" ~ scalarName ~ "-ORDINARY-050",
        srgbToLinear(cast(T)0.5), srgbToLinearReference(cast(real)cast(T)0.5));
    observe("B1-DECODE-" ~ scalarName ~ "-ONE",
        srgbToLinear(cast(T)1), srgbToLinearReference(1.0L));
    observe("B1-DECODE-" ~ scalarName ~ "-EXTENDED-NEG",
        srgbToLinear(cast(T)-0.5), srgbToLinearReference(cast(real)cast(T)-0.5));
    observe("B1-DECODE-" ~ scalarName ~ "-EXTENDED-HIGH",
        srgbToLinear(cast(T)1.25), srgbToLinearReference(cast(real)cast(T)1.25));

    observe("B1-ENCODE-" ~ scalarName ~ "-ZERO",
        linearToSrgb(cast(T)0), linearToSrgbReference(0.0L));
    observe("B1-ENCODE-" ~ scalarName ~ "-BOUNDARY-BELOW",
        linearToSrgb(nextDown(encodeBoundary)),
        linearToSrgbReference(cast(real)nextDown(encodeBoundary)));
    observe("B1-ENCODE-" ~ scalarName ~ "-BOUNDARY-AT",
        linearToSrgb(encodeBoundary),
        linearToSrgbReference(cast(real)encodeBoundary));
    observe("B1-ENCODE-" ~ scalarName ~ "-BOUNDARY-ABOVE",
        linearToSrgb(nextUp(encodeBoundary)),
        linearToSrgbReference(cast(real)nextUp(encodeBoundary)));
    observe("B1-ENCODE-" ~ scalarName ~ "-ORDINARY-018",
        linearToSrgb(cast(T)0.18), linearToSrgbReference(cast(real)cast(T)0.18));
    observe("B1-ENCODE-" ~ scalarName ~ "-ORDINARY-050",
        linearToSrgb(cast(T)0.5), linearToSrgbReference(cast(real)cast(T)0.5));
    observe("B1-ENCODE-" ~ scalarName ~ "-ONE",
        linearToSrgb(cast(T)1), linearToSrgbReference(1.0L));
    observe("B1-ENCODE-" ~ scalarName ~ "-EXTENDED-NEG",
        linearToSrgb(cast(T)-0.25), linearToSrgbReference(cast(real)cast(T)-0.25));
    observe("B1-ENCODE-" ~ scalarName ~ "-EXTENDED-HIGH",
        linearToSrgb(cast(T)1.25), linearToSrgbReference(cast(real)cast(T)1.25));

    enum string[7] roundTripLabels = [
        "ZERO", "BOUNDARY", "ORDINARY-018", "ORDINARY-050",
        "ONE", "EXTENDED-NEG", "EXTENDED-HIGH"
    ];
    const real[7] roundTripInputs = [
        0.0L, 0.04045L, 0.18L, 0.5L, 1.0L, -0.5L, 1.25L
    ];

    // Keep probe output order deterministic across compilers and runs.
    foreach (i, real x; roundTripInputs)
    {
        const T input = cast(T)x;
        const T roundTrip = linearToSrgb(srgbToLinear(input));
        observe("B1-ROUNDTRIP-" ~ scalarName ~ "-" ~ roundTripLabels[i],
            roundTrip, cast(real)input);
    }
}

void reportTriple(T)(
    string prefix,
    T[3] actual,
    real[3] reference,
    const string[3] components)
{
    foreach (c; 0 .. 3)
        observe(prefix ~ "-" ~ components[c], actual[c], reference[c]);
}

void xyzProbes(T)(string scalarName)
{
    writeln("\n[B2 linear sRGB <-> XYZ / ", scalarName, "]");

    enum string[3] xyzNames = ["X", "Y", "Z"];
    enum string[3] rgbNames = ["R", "G", "B"];

    const real[3][7] rgbSamples = [
        [0.0L, 0.0L, 0.0L],
        [1.0L, 0.0L, 0.0L],
        [0.0L, 1.0L, 0.0L],
        [0.0L, 0.0L, 1.0L],
        [1.0L, 1.0L, 1.0L],
        [0.18L, 0.42L, 0.73L],
        [-0.25L, 0.5L, 1.25L]
    ];
    enum string[7] rgbLabels = [
        "BLACK", "PRIMARY-R", "PRIMARY-G", "PRIMARY-B",
        "WHITE", "ORDINARY-01", "EXTENDED-01"
    ];

    foreach (i, s; rgbSamples)
    {
        const T r = cast(T)s[0];
        const T g = cast(T)s[1];
        const T b = cast(T)s[2];
        const actual = linearRgbToXyz(r, g, b);
        const reference = linearRgbToXyzReference(
            cast(real)r, cast(real)g, cast(real)b);

        reportTriple("B2-FORWARD-" ~ scalarName ~ "-" ~ rgbLabels[i],
            actual, reference, xyzNames);

        const back = xyzToLinearRgb(actual[0], actual[1], actual[2]);
        const real[3] original = [
            cast(real)r, cast(real)g, cast(real)b
        ];
        reportTriple("B2-ROUNDTRIP-" ~ scalarName ~ "-" ~ rgbLabels[i],
            back, original, rgbNames);
    }

    const real[3][4] xyzSamples = [
        [0.0L, 0.0L, 0.0L],
        [0.9504559270516717L, 1.0L, 1.0890577507598784L],
        [0.25L, 0.40L, 0.10L],
        [-0.10L, 0.50L, 1.20L]
    ];
    enum string[4] xyzLabels = [
        "BLACK", "D65-WHITE", "ORDINARY-01", "EXTENDED-01"
    ];

    foreach (i, s; xyzSamples)
    {
        const T x = cast(T)s[0];
        const T y = cast(T)s[1];
        const T z = cast(T)s[2];
        const actual = xyzToLinearRgb(x, y, z);
        const reference = xyzToLinearRgbReference(
            cast(real)x, cast(real)y, cast(real)z);

        reportTriple("B2-INVERSE-" ~ scalarName ~ "-" ~ xyzLabels[i],
            actual, reference, rgbNames);
    }
}

void matrixProvenanceDiagnostic()
{
    writeln("\n[B2 matrix provenance / derived IEC/ICC vs pinned CSS rational]");
    const Matrix3 derived = deriveLinearRgbToXyzReference();
    const Matrix3 css = cssLinearRgbToXyzReference();

    enum string[3] rows = ["X", "Y", "Z"];
    enum string[3] cols = ["R", "G", "B"];

    foreach (r; 0 .. 3)
        foreach (c; 0 .. 3)
            observe("B2-MATRIX-FORWARD-" ~ rows[r] ~ cols[c],
                derived[r][c], css[r][c]);

    const Matrix3 derivedInverse = invert(derived);
    const Matrix3 cssInverse = cssXyzToLinearRgbReference();

    foreach (r; 0 .. 3)
        foreach (c; 0 .. 3)
            observe("B2-MATRIX-INVERSE-" ~ cols[r] ~ rows[c],
                derivedInverse[r][c], cssInverse[r][c]);
}


void oklabProbes(T)(string scalarName)
{
    writeln("\n[B3 XYZ <-> Oklab / ", scalarName, "]");

    enum string[3] xyzNames = ["X", "Y", "Z"];
    enum string[3] labNames = ["L", "A", "B"];

    const T zero = cast(T)0;
    const black = xyzToOklab(zero, zero, zero);
    writeln("B3-EXACT-", scalarName, "-BLACK-ZERO = ",
        black[0] == zero && black[1] == zero && black[2] == zero);

    const real[3][4] xyzSamples = [
        [0.9504559270516717L, 1.0L, 1.0890577507598784L],
        [0.25L, 0.40L, 0.10L],
        [-0.10L, 0.50L, 1.20L],
        [1.0L, -0.25L, 0.50L]
    ];
    enum string[4] xyzLabels = [
        "D65-WHITE", "ORDINARY-01", "EXTENDED-01", "EXTENDED-02"
    ];

    foreach (i, s; xyzSamples)
    {
        const T x = cast(T)s[0], y = cast(T)s[1], z = cast(T)s[2];
        const lab = xyzToOklab(x, y, z);
        const reference = cssXyzToOklabReference(
            cast(real)x, cast(real)y, cast(real)z);
        reportTriple("B3-FORWARD-" ~ scalarName ~ "-" ~ xyzLabels[i],
            lab, reference, labNames);

        const xyzBack = oklabToXyz(lab[0], lab[1], lab[2]);
        const real[3] xyzOriginal = [cast(real)x, cast(real)y, cast(real)z];
        reportTriple("B3-XYZ-ROUNDTRIP-" ~ scalarName ~ "-" ~ xyzLabels[i],
            xyzBack, xyzOriginal, xyzNames);
    }

    const real[3][3] labSamples = [
        [0.50L, 0.10L, -0.10L],
        [1.20L, -0.40L, 0.30L],
        [-0.25L, 0.20L, -0.35L]
    ];
    enum string[3] labLabels = ["ORDINARY-01", "EXTENDED-01", "EXTENDED-02"];

    foreach (i, s; labSamples)
    {
        const T l = cast(T)s[0], a = cast(T)s[1], b = cast(T)s[2];
        const xyz = oklabToXyz(l, a, b);
        const reference = cssOklabToXyzReference(
            cast(real)l, cast(real)a, cast(real)b);
        reportTriple("B3-INVERSE-" ~ scalarName ~ "-" ~ labLabels[i],
            xyz, reference, xyzNames);

        const labBack = xyzToOklab(xyz[0], xyz[1], xyz[2]);
        const real[3] labOriginal = [cast(real)l, cast(real)a, cast(real)b];
        reportTriple("B3-LAB-ROUNDTRIP-" ~ scalarName ~ "-" ~ labLabels[i],
            labBack, labOriginal, labNames);
    }

    const real[3][3] rgbSamples = [
        [1.0L, 0.0L, 0.0L],
        [0.4352785666728059L, 0.017175850397231969L, 0.054553830782703643L],
        [-0.2L, 1.3L, 0.5L]
    ];
    enum string[3] rgbLabels = ["PRIMARY-R", "ORDINARY-01", "EXTENDED-01"];

    foreach (i, s; rgbSamples)
    {
        const T r = cast(T)s[0], g = cast(T)s[1], b = cast(T)s[2];
        const xyz = linearRgbToXyz(r, g, b);
        const lab = xyzToOklab(xyz[0], xyz[1], xyz[2]);
        const direct = ottossonLinearRgbToOklabReference(
            cast(real)r, cast(real)g, cast(real)b);
        reportTriple("B3-RGB-DIRECT-" ~ scalarName ~ "-" ~ rgbLabels[i],
            lab, direct, labNames);
    }
}

void main()
{
    writeln("=== color-d R0.13-B reference-value characterization ===");
    writefln("float : sizeof=%s mant_dig=%s epsilon=%s",
        float.sizeof, float.mant_dig, float.epsilon);
    writefln("double: sizeof=%s mant_dig=%s epsilon=%s",
        double.sizeof, double.mant_dig, double.epsilon);
    writefln("real  : sizeof=%s mant_dig=%s epsilon=%s",
        real.sizeof, real.mant_dig, real.epsilon);
    writeln("real wider than double = ", real.mant_dig > double.mant_dig);

    transferProbes!float("float");
    transferProbes!double("double");
    matrixProvenanceDiagnostic();
    xyzProbes!float("float");
    xyzProbes!double("double");
    oklabProbes!float("float");
    oklabProbes!double("double");
}
