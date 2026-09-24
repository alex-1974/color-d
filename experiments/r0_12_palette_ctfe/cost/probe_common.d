module probe_common;

import r0_8_gamut_fixture : gamutMapRayTrace, toSRgb;
import r0_8_gamut_fixture : OklabHue, Oklch, MapResult, SRgb;

alias OklchT(T) = Oklch!T;
alias HueT(T) = OklabHue!T;
alias MapResultT(T) = MapResult!T;
alias SRgbT(T) = SRgb!T;


struct ProbeBundle(T, size_t F, size_t N)
{
    OklchT!T[N][F] raw;
    MapResultT!T[N][F] mapped;
    SRgbT!T[N][F] encoded;
}


OklchT!T[F] makeSeeds(T, size_t F)()
@safe pure nothrow @nogc
{
    OklchT!T[F] result;

    foreach (f; 0 .. F)
    {
        const T hue =
            cast(T)(
                20 +
                ((f * 47) % 320)
            );

        result[f] =
            OklchT!T(
                cast(T)0.5,
                cast(T)0.20,
                HueT!T(hue)
            );
    }

    return result;
}


T[N][F] makeLightnesses(T, size_t F, size_t N)()
@safe pure nothrow @nogc
{
    T[N][F] result;

    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            static if (N == 1)
            {
                result[f][i] =
                    cast(T)0.5;
            }
            else
            {
                result[f][i] =
                    cast(T)0.10 +
                    cast(T)0.80 *
                    cast(T)i /
                    cast(T)(N - 1);
            }
        }
    }

    return result;
}


T[N][F] makeChromas(T, size_t F, size_t N)()
@safe pure nothrow @nogc
{
    T[N][F] result;

    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            result[f][i] =
                cast(T)0.24503;
        }
    }

    return result;
}


OklchT!T[N][F] composeRaw(
    T,
    size_t F,
    size_t N
)(
    const OklchT!T[F] seeds,
    const T[N][F] lightnesses,
    const T[N][F] chromas
)
@safe pure nothrow @nogc
{
    OklchT!T[N][F] result;

    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            result[f][i] =
                OklchT!T(
                    lightnesses[f][i],
                    chromas[f][i],
                    seeds[f].h
                );
        }
    }

    return result;
}


MapResultT!T[N][F] mapPalette(
    T,
    size_t F,
    size_t N
)(
    const OklchT!T[N][F] raw
)
@safe pure nothrow @nogc
{
    MapResultT!T[N][F] result;

    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            result[f][i] =
                gamutMapRayTrace!T(
                    raw[f][i]
                );
        }
    }

    return result;
}


SRgbT!T[N][F] encodePalette(
    T,
    size_t F,
    size_t N
)(
    const MapResultT!T[N][F] mapped
)
@safe pure nothrow @nogc
{
    SRgbT!T[N][F] result;

    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            result[f][i] =
                toSRgb!T(
                    mapped[f][i].color
                );
        }
    }

    return result;
}


ProbeBundle!(T, F, N) buildProbe(
    T,
    size_t F,
    size_t N
)()
@safe pure nothrow @nogc
{
    const auto seeds =
        makeSeeds!(T, F)();

    const auto lightnesses =
        makeLightnesses!(T, F, N)();

    const auto chromas =
        makeChromas!(T, F, N)();

    ProbeBundle!(T, F, N) result;

    result.raw =
        composeRaw!(T, F, N)(
            seeds,
            lightnesses,
            chromas
        );

    result.mapped =
        mapPalette!(T, F, N)(
            result.raw
        );

    result.encoded =
        encodePalette!(T, F, N)(
            result.mapped
        );

    return result;
}


bool allMappingsSuccessful(
    T,
    size_t F,
    size_t N
)(
    const MapResultT!T[N][F] mapped
)
@safe pure nothrow @nogc
{
    foreach (f; 0 .. F)
    {
        foreach (i; 0 .. N)
        {
            if (!mapped[f][i].success)
                return false;
        }
    }

    return true;
}
