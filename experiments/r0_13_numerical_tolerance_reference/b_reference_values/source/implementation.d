module implementation;

import std.math : pow;

T magnitude(T)(T value) { return value < 0 ? -value : value; }
T signOf(T)(T value) { return value < 0 ? cast(T)-1 : cast(T)1; }

T srgbToLinear(T)(T encoded)
{
    const T a = magnitude(encoded);
    if (a <= cast(T)0.04045) return encoded / cast(T)12.92;
    return signOf(encoded) * cast(T)pow((a + cast(T)0.055) / cast(T)1.055, cast(T)2.4);
}

T linearToSrgb(T)(T linear)
{
    const T a = magnitude(linear);
    if (a <= cast(T)0.0031308) return linear * cast(T)12.92;
    return signOf(linear) * (cast(T)1.055 * cast(T)pow(a, cast(T)(1.0 / 2.4)) - cast(T)0.055);
}

T q(T)(long n, long d) { return cast(T)n / cast(T)d; }

T[3] linearRgbToXyz(T)(T r, T g, T b)
{
    return [
        q!T(506752,1228815)*r + q!T(87881,245763)*g + q!T(12673,70218)*b,
        q!T(87098,409605)*r + q!T(175762,245763)*g + q!T(12673,175545)*b,
        q!T(7918,409605)*r + q!T(87881,737289)*g + q!T(1001167,1053270)*b
    ];
}

T[3] xyzToLinearRgb(T)(T x, T y, T z)
{
    return [
        q!T(12831,3959)*x + q!T(-329,214)*y + q!T(-1974,3959)*z,
        q!T(-851781,878810)*x + q!T(1648619,878810)*y + q!T(36519,878810)*z,
        q!T(705,12673)*x + q!T(-2585,12673)*y + q!T(705,667)*z
    ];
}

T cube(T)(T value) { return value * value * value; }

T cubeRoot(T)(T value)
{
    if (value == 0) return value;
    const T a = magnitude(value);
    const T root = cast(T)pow(a, cast(T)(1.0L / 3.0L));
    return value < 0 ? -root : root;
}

T[3] xyzToOklab(T)(T x, T y, T z)
{
    const T l = cast(T)0.8190224379967030*x + cast(T)0.3619062600528904*y - cast(T)0.1288737815209879*z;
    const T m = cast(T)0.0329836539323885*x + cast(T)0.9292868615863434*y + cast(T)0.0361446663506424*z;
    const T s = cast(T)0.0481771893596242*x + cast(T)0.2642395317527308*y + cast(T)0.6335478284694309*z;
    const T lp = cubeRoot(l), mp = cubeRoot(m), sp = cubeRoot(s);
    return [
        cast(T)0.2104542683093140*lp + cast(T)0.7936177747023054*mp - cast(T)0.0040720430116193*sp,
        cast(T)1.9779985324311684*lp - cast(T)2.4285922420485799*mp + cast(T)0.4505937096174110*sp,
        cast(T)0.0259040424655478*lp + cast(T)0.7827717124575296*mp - cast(T)0.8086757549230774*sp
    ];
}

T[3] oklabToXyz(T)(T lLab, T aLab, T bLab)
{
    const T lp = lLab + cast(T)0.3963377773761749*aLab + cast(T)0.2158037573099136*bLab;
    const T mp = lLab - cast(T)0.1055613458156586*aLab - cast(T)0.0638541728258133*bLab;
    const T sp = lLab - cast(T)0.0894841775298119*aLab - cast(T)1.2914855480194092*bLab;
    const T l = cube(lp), m = cube(mp), s = cube(sp);
    return [
        cast(T)1.2268798758459243*l - cast(T)0.5578149944602171*m + cast(T)0.2813910456659647*s,
       -cast(T)0.0405757452148008*l + cast(T)1.1122868032803170*m - cast(T)0.0717110580655164*s,
       -cast(T)0.0763729366746601*l - cast(T)0.4214933324022432*m + cast(T)1.5869240198367816*s
    ];
}
