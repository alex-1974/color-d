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
}
