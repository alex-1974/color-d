module repro_nested_hue;

import std.stdio : writefln, writeln;

struct Hue(T)
{
    T degrees;
}

struct Color(T)
{
    T l;
    T c;
    Hue!T h;
}

Color!T[N] makeFamily(T, size_t N)(
    const Color!T seed,
    const T[N] lightnesses,
    const T[N] chromas
)
@safe pure nothrow @nogc
{
    Color!T[N] result;

    foreach (i; 0 .. N)
    {
        result[i] =
            Color!T(
                lightnesses[i],
                chromas[i],
                seed.h
            );
    }

    return result;
}

Color!T[N][F] makePalette(T, size_t F, size_t N)(
    const Color!T[F] seeds,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
@safe pure nothrow @nogc
{
    Color!T[N][F] result;

    foreach (f; 0 .. F)
    {
        result[f] =
            makeFamily!(T, N)(
                seeds[f],
                lightnesses[f],
                chromas[f]
            );
    }

    return result;
}

bool test(T)(string name)
{
    enum size_t F = 1;
    enum size_t N = 1;

    Color!T[F] seeds =
    [
        Color!T(
            cast(T)0.5,
            cast(T)0.0,
            Hue!T(cast(T)725.0)
        )
    ];

    T[N][F] lightnesses =
    [
        [cast(T)0.5]
    ];

    T[N][F] chromas =
    [
        [cast(T)0.0]
    ];

    const auto family =
        makeFamily!(T, N)(
            seeds[0],
            lightnesses[0],
            chromas[0]
        );

    const auto palette =
        makePalette!(T, F, N)(
            seeds,
            lightnesses,
            chromas
        );

    writefln(
        "%s family : L=%.17e C=%.17e H=%.17e",
        name,
        cast(double)family[0].l,
        cast(double)family[0].c,
        cast(double)family[0].h.degrees
    );

    writefln(
        "%s palette: L=%.17e C=%.17e H=%.17e",
        name,
        cast(double)palette[0][0].l,
        cast(double)palette[0][0].c,
        cast(double)palette[0][0].h.degrees
    );

    return
        family[0].l == cast(T)0.5 &&
        family[0].c == cast(T)0.0 &&
        family[0].h.degrees == cast(T)725.0 &&
        palette[0][0].l == cast(T)0.5 &&
        palette[0][0].c == cast(T)0.0 &&
        palette[0][0].h.degrees == cast(T)725.0;
}

int main()
{
    const bool f = test!float("float");
    const bool d = test!double("double");

    writeln(
        "nested result: ",
        f && d ? "PASS" : "FAIL"
    );

    return f && d ? 0 : 1;
}
