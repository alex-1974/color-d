module repro_min_return;

import std.stdio : writefln;

struct S
{
    float a;
    float b;
    float c;
}

S[1][1] make()
{
    S[1][1] result;

    result[0][0] =
        S(
            0.5f,
            0.0f,
            725.0f
        );

    return result;
}

int main()
{
    const auto value =
        make();

    const bool ok =
        value[0][0].a == 0.5f &&
        value[0][0].b == 0.0f &&
        value[0][0].c == 725.0f;

    writefln(
        "return float[1][1]: %s a=%.17e b=%.17e c=%.17e",
        ok ? "PASS" : "FAIL",
        cast(double)value[0][0].a,
        cast(double)value[0][0].b,
        cast(double)value[0][0].c
    );

    return ok ? 0 : 1;
}
