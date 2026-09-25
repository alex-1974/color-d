module reference_values;

import std.math : pow;

real magnitude(real value) { return value < 0 ? -value : value; }
real signOf(real value) { return value < 0 ? -1.0L : 1.0L; }

real srgbToLinearReference(real encoded)
{
    const real a = magnitude(encoded);
    if (a <= 0.04045L) return encoded / 12.92L;
    return signOf(encoded) * pow((a + 0.055L) / 1.055L, 2.4L);
}

real linearToSrgbReference(real linear)
{
    const real a = magnitude(linear);
    if (a <= 0.0031308L) return linear * 12.92L;
    return signOf(linear) * (1.055L * pow(a, 1.0L / 2.4L) - 0.055L);
}

alias Matrix3 = real[3][3];

real determinant(Matrix3 m)
{
    return
        m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
      - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
      + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
}

Matrix3 invert(Matrix3 m)
{
    const real d = determinant(m);
    return [
        [(m[1][1]*m[2][2]-m[1][2]*m[2][1])/d,
         (m[0][2]*m[2][1]-m[0][1]*m[2][2])/d,
         (m[0][1]*m[1][2]-m[0][2]*m[1][1])/d],
        [(m[1][2]*m[2][0]-m[1][0]*m[2][2])/d,
         (m[0][0]*m[2][2]-m[0][2]*m[2][0])/d,
         (m[0][2]*m[1][0]-m[0][0]*m[1][2])/d],
        [(m[1][0]*m[2][1]-m[1][1]*m[2][0])/d,
         (m[0][1]*m[2][0]-m[0][0]*m[2][1])/d,
         (m[0][0]*m[1][1]-m[0][1]*m[1][0])/d]
    ];
}

real[3] multiply(Matrix3 m, real[3] v)
{
    return [
        m[0][0]*v[0] + m[0][1]*v[1] + m[0][2]*v[2],
        m[1][0]*v[0] + m[1][1]*v[1] + m[1][2]*v[2],
        m[2][0]*v[0] + m[2][1]*v[1] + m[2][2]*v[2]
    ];
}

Matrix3 deriveLinearRgbToXyzReference()
{
    // ICC sRGB registry / IEC 61966-2-1 colorimetry.
    enum real xr=0.64L, yr=0.33L, xg=0.30L, yg=0.60L;
    enum real xb=0.15L, yb=0.06L, xw=0.3127L, yw=0.3290L;

    const real[3] r = [xr/yr, 1.0L, (1.0L-xr-yr)/yr];
    const real[3] g = [xg/yg, 1.0L, (1.0L-xg-yg)/yg];
    const real[3] b = [xb/yb, 1.0L, (1.0L-xb-yb)/yb];
    const Matrix3 primaries = [
        [r[0], g[0], b[0]],
        [r[1], g[1], b[1]],
        [r[2], g[2], b[2]]
    ];
    const real[3] white = [xw/yw, 1.0L, (1.0L-xw-yw)/yw];
    const real[3] scale = multiply(invert(primaries), white);

    return [
        [r[0]*scale[0], g[0]*scale[1], b[0]*scale[2]],
        [r[1]*scale[0], g[1]*scale[1], b[1]*scale[2]],
        [r[2]*scale[0], g[2]*scale[1], b[2]*scale[2]]
    ];
}

real q(long n, long d)
{
    return cast(real)n / cast(real)d;
}

Matrix3 cssLinearRgbToXyzReference()
{
    return [
        [q(506752,1228815), q(87881,245763), q(12673,70218)],
        [q(87098,409605), q(175762,245763), q(12673,175545)],
        [q(7918,409605), q(87881,737289), q(1001167,1053270)]
    ];
}

Matrix3 cssXyzToLinearRgbReference()
{
    return [
        [q(12831,3959), q(-329,214), q(-1974,3959)],
        [q(-851781,878810), q(1648619,878810), q(36519,878810)],
        [q(705,12673), q(-2585,12673), q(705,667)]
    ];
}

real[3] linearRgbToXyzReference(real r, real g, real b)
{
    return multiply(deriveLinearRgbToXyzReference(), [r, g, b]);
}

real[3] xyzToLinearRgbReference(real x, real y, real z)
{
    return multiply(invert(deriveLinearRgbToXyzReference()), [x, y, z]);
}

real cubeRootReference(real value)
{
    if (value == 0.0L) return value;
    const real a = magnitude(value);
    const real root = pow(a, 1.0L / 3.0L);
    return value < 0.0L ? -root : root;
}

real[3] cssXyzToOklabReference(real x, real y, real z)
{
    const real l = 0.8190224379967030L*x + 0.3619062600528904L*y - 0.1288737815209879L*z;
    const real m = 0.0329836539323885L*x + 0.9292868615863434L*y + 0.0361446663506424L*z;
    const real s = 0.0481771893596242L*x + 0.2642395317527308L*y + 0.6335478284694309L*z;
    const real lp = cubeRootReference(l), mp = cubeRootReference(m), sp = cubeRootReference(s);
    return [
        0.2104542683093140L*lp + 0.7936177747023054L*mp - 0.0040720430116193L*sp,
        1.9779985324311684L*lp - 2.4285922420485799L*mp + 0.4505937096174110L*sp,
        0.0259040424655478L*lp + 0.7827717124575296L*mp - 0.8086757549230774L*sp
    ];
}

real[3] cssOklabToXyzReference(real lLab, real aLab, real bLab)
{
    const real lp = lLab + 0.3963377773761749L*aLab + 0.2158037573099136L*bLab;
    const real mp = lLab - 0.1055613458156586L*aLab - 0.0638541728258133L*bLab;
    const real sp = lLab - 0.0894841775298119L*aLab - 1.2914855480194092L*bLab;
    const real l = lp*lp*lp, m = mp*mp*mp, s = sp*sp*sp;
    return [
        1.2268798758459243L*l - 0.5578149944602171L*m + 0.2813910456659647L*s,
       -0.0405757452148008L*l + 1.1122868032803170L*m - 0.0717110580655164L*s,
       -0.0763729366746601L*l - 0.4214933324022432L*m + 1.5869240198367816L*s
    ];
}

real[3] ottossonLinearRgbToOklabReference(real r, real g, real b)
{
    const real l = 0.4122214708L*r + 0.5363325363L*g + 0.0514459929L*b;
    const real m = 0.2119034982L*r + 0.6806995451L*g + 0.1073969566L*b;
    const real s = 0.0883024619L*r + 0.2817188376L*g + 0.6299787005L*b;
    const real lp = cubeRootReference(l), mp = cubeRootReference(m), sp = cubeRootReference(s);
    return [
        0.2104542553L*lp + 0.7936177850L*mp - 0.0040720468L*sp,
        1.9779984951L*lp - 2.4285922050L*mp + 0.4505937099L*sp,
        0.0259040371L*lp + 0.7827717662L*mp - 0.8086757660L*sp
    ];
}
