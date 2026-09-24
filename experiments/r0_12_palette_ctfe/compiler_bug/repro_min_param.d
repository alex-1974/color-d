module repro_min_param;

import std.stdio : writefln;

float readFloat1(const float[1] value)
{
    return value[0];
}

float readFloat11(const float[1][1] value)
{
    return value[0][0];
}

double readDouble1(const double[1] value)
{
    return value[0];
}

double readDouble11(const double[1][1] value)
{
    return value[0][0];
}

int main()
{
    float[1] f1 =
        [0.5f];

    float[1][1] f11 =
        [
            [0.5f]
        ];

    double[1] d1 =
        [0.5];

    double[1][1] d11 =
        [
            [0.5]
        ];

    const float rf1 =
        readFloat1(f1);

    const float rf11 =
        readFloat11(f11);

    const double rd1 =
        readDouble1(d1);

    const double rd11 =
        readDouble11(d11);

    const bool f1OK =
        rf1 == 0.5f;

    const bool f11OK =
        rf11 == 0.5f;

    const bool d1OK =
        rd1 == 0.5;

    const bool d11OK =
        rd11 == 0.5;

    writefln(
        "float[1]    %s %.17e\n",
        f1OK ? "PASS" : "FAIL",
        cast(double)rf1
    );

    writefln(
        "float[1][1] %s %.17e\n",
        f11OK ? "PASS" : "FAIL",
        cast(double)rf11
    );

    writefln(
        "double[1]   %s %.17e\n",
        d1OK ? "PASS" : "FAIL",
        rd1
    );

    writefln(
        "double[1][1] %s %.17e\n",
        d11OK ? "PASS" : "FAIL",
        rd11
    );

    return
        f1OK &&
        f11OK &&
        d1OK &&
        d11OK
            ? 0
            : 1;
}
