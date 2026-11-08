module app;

import color;

private bool near(double value, double expected, double tolerance = 1e-12)
@safe pure nothrow @nogc
{
    return value >= expected - tolerance && value <= expected + tolerance;
}

private void checkPolicy(Policy)(double y, double cb, double cr)
@safe pure nothrow @nogc
{
    const value = YCbCr!(double, Policy)(y, cb, cr);
    const encoded = value.toSRgb;
    const linear = toLinearSRgb!(double, Policy)(value);
    assert(near(encoded.r, encoded.r));
    assert(near(linear.r, linear.r));
}

static assert(__traits(compiles,
    YCbCr!(double, Bt601Full)(0.0, 0.5, 0.5).toSRgb));
static assert(__traits(compiles,
    YCbCr!(double, Bt709Full)(0.5, 0.5, 0.5).toSRgb));
static assert(__traits(compiles,
    YCbCr!(double, Bt709Video)(16.0 / 255.0, 128.0 / 255.0,
        128.0 / 255.0).toSRgbClamped));
static assert(!__traits(compiles, YCbCr!int(Bt601Full)));

void main()
{
    const black = YCbCr!(double, Bt601Full)(0.0, 0.5, 0.5).toSRgb;
    assert(black == SRgbd(0.0, 0.0, 0.0));

    const videoBlack = YCbCr!(double, Bt601Video)(16.0 / 255.0,
        128.0 / 255.0, 128.0 / 255.0).toSRgb;
    assert(videoBlack == SRgbd(0.0, 0.0, 0.0));

    const videoWhite = YCbCr!(double, Bt601Video)(235.0 / 255.0,
        128.0 / 255.0, 128.0 / 255.0).toSRgb;
    assert(videoWhite.r > 0.9999 && videoWhite.g > 0.9999
        && videoWhite.b > 0.9999);

    const gray = YCbCr!(double, Bt601Full)(0.5, 0.5, 0.5).toSRgb;
    assert(gray == SRgbd(0.5, 0.5, 0.5));

    const extended = YCbCr!(double, Bt709Full)(0.5, 1.0, 0.5).toSRgb;
    assert(extended.b > 1.0);
    assert(YCbCr!(double, Bt709Full)(0.5, 1.0, 0.5).toSRgbClamped.b == 1.0);

    checkPolicy!Bt601Full(0.5, 0.5, 0.5);
    checkPolicy!Bt601Video(128.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0);
    checkPolicy!Bt709Full(0.5, 0.5, 0.5);
    checkPolicy!Bt709Video(128.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0);

    const auto rgb = SRgbd(0.2, 0.4, 0.8);
    const auto encoded = rgb.toYCbCr!Bt709Video;
    const auto roundTrip = encoded.toSRgb;
    assert(near(roundTrip.r, rgb.r, 1e-6));
    assert(near(roundTrip.g, rgb.g, 1e-6));
    assert(near(roundTrip.b, rgb.b, 1e-6));

    const parsed = parseSRgb8Hex("#12AbF0");
    assert(parsed.hasValue);
    assert(parsed.value() == SRgb8(0x12, 0xAB, 0xF0));

    const invalid = parseSRgb8Hex("#12GGF0");
    assert(invalid.hasError);
    assert(invalid.error() == ColorParseError.invalidDigit);

    const stored = toSRgb8Result(SRgbd(0.2, 0.4, 0.8));
    assert(stored.hasValue);
    assert(stored.value() == SRgb8(51, 102, 204));

    const rejected = toSRgb8Result(SRgbd(1.2, 0.4, 0.8));
    assert(rejected.hasError);
    assert(rejected.error() == ColorStorageError.outOfRange);

    const prepared = prepareMachado2009(
        RedGreenCvdDeficiency.protan, 0.5);
    assert(prepared.hasValue);

    const invalidSeverity = prepareMachado2009(
        RedGreenCvdDeficiency.protan, 1.5);
    assert(invalidSeverity.hasError);
    assert(invalidSeverity.error() == CvdPreparationError.invalidSeverity);

    const bt2020 = SRgbd(0.2, 0.4, 0.8).toYCbCr!Bt2020Video;
    assert(near(bt2020.toSRgb.r, 0.2, 1e-3));
    const tenBit = YCbCr!(double, YCbCrPolicy!(YCbCrMatrix.bt2020,
        YCbCrRange.full, 10))(0.5, 0.5, 0.5).toYCbCrCode;
    assert(tenBit.hasValue && tenBit.value().y == 512);

    const hsl = rgb.toHsl;
    const hsv = rgb.toHsv;
    assert(near(hsl.toSRgb.r, rgb.r, 1e-12));
    assert(near(hsv.toSRgb.b, rgb.b, 1e-12));

    const p3 = DisplayP3d(0.2, 0.4, 0.8);
    const p3Linear = p3.toLinear;
    const p3RoundTrip = p3Linear.toDisplayP3;
    assert(near(p3RoundTrip.r, p3.r, 1e-12));
    assert(p3.toSRgb.r == p3.toSRgb.r);
}
