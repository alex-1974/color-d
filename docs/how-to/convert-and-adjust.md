# Convert and adjust colors

## Convert through supported spaces

The validated computational chain is:

```text
SRgb!T
    ⇅
LinearSRgb!T
    ⇅
XyzD65!T
    ⇅
Oklab!T
    ⇅
Oklch!T
```

with `T = float | double`.

Example:

```d
import color;

const encoded = SRgbd(0.4, 0.5, 0.6);
const linear = encoded.toLinear;
const xyz = linear.toXyzD65;
const lab = xyz.toOklab;
const lch = lab.toOklch;

const roundTrip = lch.toOklab.toXyzD65.toLinearSRgb.toSRgb;
```

Conversions preserve mathematically valid extended intermediate values. They
do not imply target-gamut membership.

## Replace raw OKLCH components

```d
const changed =
    lch
    .withLightness(0.75)
    .withChroma(0.12)
    .withHue(OklabHued.fromDegrees(390.0));
```

These operations replace only the named raw component. In particular, stored
hue remains raw and may preserve complete revolutions.

Use `canonicalized` only when you explicitly need the canonical non-negative
chroma representation.

See [Color model](../concepts/color-model.md) and
[Extended values and `.init`](../concepts/extended-values-and-init.md).
