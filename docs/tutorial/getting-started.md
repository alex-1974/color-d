# Getting started

`color-d` is a type-safe color mathematics library for D. Different color
spaces are different types, so conversions and policy choices remain visible.

## Import the supported API

For the complete supported surface:

```d
import color;
```

Direct imports of documented public modules such as `color.rgb`,
`color.oklch`, or `color.wcag` are also supported.

## Convert explicitly

```d
import color;

const encoded = SRgbd(0.82, 0.25, 0.12);

const perceptual =
    encoded
    .toLinear
    .toXyzD65
    .toOklab
    .toOklch;
```

The chain does not clip or gamut-map implicitly. Encoded and linear-light sRGB
are deliberately different types.

## Adjust in OKLCH

```d
const adjusted =
    perceptual
    .withLightness(0.70)
    .withChroma(0.16);
```

Raw OKLCH component operations do not silently normalize, clamp, or map to a
display gamut.

## Choose gamut policy explicitly

```d
const mapped =
    adjusted.gamutMapRayTraceToLinearSRgb();

assert(mapped.inGamut);

const display = mapped.toSRgb;
```

`clip`, Local MINDE mapping, and Ray Trace mapping are different operations.
There is no default perceptual mapper.

## Compile-time use

Deterministic core operations are designed to use the same public API at
runtime and during CTFE where the current D toolchain permits it.

```d
enum colorAtCompileTime =
    Oklchd(
        0.70,
        0.30,
        OklabHued.fromDegrees(40.0)
    )
    .gamutMapRayTraceToLinearSRgb();

static assert(colorAtCompileTime.inGamut);
```

For the numerical contract behind CTFE/runtime comparison, see
[Accuracy and validation](../accuracy-and-validation.md).
