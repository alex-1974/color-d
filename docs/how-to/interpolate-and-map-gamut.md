# Interpolate and map gamut

## Choose the interpolation space with the type

```d
import color;

const a = Oklabd(0.40, 0.10, -0.05);
const b = Oklabd(0.80, -0.05, 0.10);

const middle = interpolate(a, b, 0.5);
```

The operation remains in Oklab. It does not silently convert to another space.

For OKLCH, hue-path policy is explicit:

```d
const first = Oklchd(0.6, 0.2, OklabHued.fromDegrees(350.0));
const second = Oklchd(0.6, 0.2, OklabHued.fromDegrees(10.0));

const middle =
    interpolate(first, second, 0.5, HuePath.shorter);
```

`HuePath` provides `shorter`, `longer`, `increasing`, and `decreasing`.
Its default D value is the valid policy `HuePath.shorter`.

## Keep interpolation and gamut policy separate

Interpolation may produce an out-of-sRGB result. Test or map it explicitly:

```d
const linear = middle.toOklab.toXyzD65.toLinearSRgb;

if (!linear.inGamut)
{
    const mapped = middle.gamutMapRayTraceToLinearSRgb();
    assert(mapped.inGamut);
}
```

Hard clipping is a separate target-space operation:

```d
const clipped = linear.clip;
```

Local MINDE is the perceptual/reference-oriented mapper; Ray Trace is the
bounded-cost mapper. Neither is the library-wide default.

The accepted gamut semantics originate in the R0.8 work documented in
[`research/R0_8_GAMUT_SEMANTICS.md`](../research/R0_8_GAMUT_SEMANTICS.md),
which evaluated the corresponding CSS Color 4 algorithms.
