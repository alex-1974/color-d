// Production toolchain canary for workspace issue TC-0001.
//
// DMD 2.113.0 still miscompiles this minimal by-value return shape on the
// validated Linux x86-64 toolchain, while the supported LDC line passes it.
// The full reduction history and control matrix remain research evidence.
// This copy exists so production CI does not depend on experiments/.
//
// If this program starts returning 0 under the supported DMD, re-evaluate the
// color-d workaround before removing either the workaround or this canary.

module tc0001_static_array_return_canary;

import std.stdio : writefln;

private struct Sample
{
    float a;
    float b;
    float c;
}

private Sample[1][1] makeSample()
{
    Sample[1][1] result;

    result[0][0] =
        Sample(
            0.5f,
            0.0f,
            725.0f
        );

    return result;
}

int main()
{
    const auto value =
        makeSample();

    const bool ok =
        value[0][0].a == 0.5f &&
        value[0][0].b == 0.0f &&
        value[0][0].c == 725.0f;

    writefln(
        "TC-0001 nested static-array return: %s a=%.17e b=%.17e c=%.17e",
        ok ? "PASS" : "FAIL",
        cast(double)value[0][0].a,
        cast(double)value[0][0].b,
        cast(double)value[0][0].c
    );

    return ok ? 0 : 1;
}
