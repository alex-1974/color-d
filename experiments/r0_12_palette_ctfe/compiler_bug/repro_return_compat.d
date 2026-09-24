module repro_return_compat;

import std.stdio : writefln;

struct S
{
    float a;
    float b;
    float c;
}

alias A = S[1][1];

A makeByValue()
{
    A result;

    result[0][0] =
        S(
            0.5f,
            0.0f,
            725.0f
        );

    return result;
}

void makeByOut(out A result)
{
    result[0][0] =
        S(
            0.5f,
            0.0f,
            725.0f
        );
}

void makeByRef(ref A result)
{
    result[0][0] =
        S(
            0.5f,
            0.0f,
            725.0f
        );
}

struct Box
{
    A value;
}

Box makeBox()
{
    Box result;

    result.value[0][0] =
        S(
            0.5f,
            0.0f,
            725.0f
        );

    return result;
}

int main()
{
    const auto byValue =
        makeByValue();

    A byOut;
    makeByOut(byOut);

    A byRef;
    makeByRef(byRef);

    const auto boxed =
        makeBox();

    const bool byValueOK =
        byValue[0][0].a == 0.5f &&
        byValue[0][0].b == 0.0f &&
        byValue[0][0].c == 725.0f;

    const bool byOutOK =
        byOut[0][0].a == 0.5f &&
        byOut[0][0].b == 0.0f &&
        byOut[0][0].c == 725.0f;

    const bool byRefOK =
        byRef[0][0].a == 0.5f &&
        byRef[0][0].b == 0.0f &&
        byRef[0][0].c == 725.0f;

    const bool boxedOK =
        boxed.value[0][0].a == 0.5f &&
        boxed.value[0][0].b == 0.0f &&
        boxed.value[0][0].c == 725.0f;

    writefln(
        "by-value %s  a=%.17e b=%.17e c=%.17e",
        byValueOK ? "PASS" : "FAIL",
        cast(double)byValue[0][0].a,
        cast(double)byValue[0][0].b,
        cast(double)byValue[0][0].c
    );

    writefln(
        "out      %s  a=%.17e b=%.17e c=%.17e",
        byOutOK ? "PASS" : "FAIL",
        cast(double)byOut[0][0].a,
        cast(double)byOut[0][0].b,
        cast(double)byOut[0][0].c
    );

    writefln(
        "ref      %s  a=%.17e b=%.17e c=%.17e",
        byRefOK ? "PASS" : "FAIL",
        cast(double)byRef[0][0].a,
        cast(double)byRef[0][0].b,
        cast(double)byRef[0][0].c
    );

    writefln(
        "boxed    %s  a=%.17e b=%.17e c=%.17e",
        boxedOK ? "PASS" : "FAIL",
        cast(double)boxed.value[0][0].a,
        cast(double)boxed.value[0][0].b,
        cast(double)boxed.value[0][0].c
    );

    return
        byOutOK &&
        byRefOK
            ? 0
            : 1;
}
