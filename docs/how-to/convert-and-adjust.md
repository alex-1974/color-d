# Convert and adjust colors

Use this guide when you have a color value and need to move it between the
supported computational spaces or make a perceptual adjustment.

The main rule is simple: **convert explicitly, edit in the space whose
coordinates match the edit, and choose output policy separately.**

## Know which value you have

The supported computational chain is:

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

These types may all contain three floating-point components, but they do not
mean the same thing.

- `SRgb!T` is encoded/nonlinear sRGB.
- `LinearSRgb!T` is linear-light sRGB.
- `XyzD65!T` is CIE XYZ relative to D65.
- `Oklab!T` is rectangular perceptual color.
- `Oklch!T` is cylindrical Oklab: lightness, chroma, and hue.

## Convert through the explicit chain

For an encoded sRGB input:

```d
import color;

const encoded = SRgbd(0.4, 0.5, 0.6);

const linear = encoded.toLinear;
const xyz = linear.toXyzD65;
const lab = xyz.toOklab;
const lch = lab.toOklch;
```

The reverse path is equally explicit:

```d
const roundTrip =
    lch
    .toOklab
    .toXyzD65
    .toLinearSRgb
    .toSRgb;
```

A conversion changes representation. It does **not** choose clipping, gamut
mapping, interpolation, or application policy.

## Edit perceptual coordinates in OKLCH

OKLCH is often convenient when an edit is naturally described as
"lighter", "less chromatic", or "different hue".

```d
const changed =
    lch
    .withLightness(0.75)
    .withChroma(0.12)
    .withHue(OklabHued.fromDegrees(390.0));
```

These functions replace exactly one raw component.

They do not:

- clamp lightness;
- force chroma into a nominal interval;
- wrap raw hue;
- clip RGB;
- map the result into sRGB.

That separation is useful: a perceptual edit can temporarily leave the target
display gamut without losing the intended direction of the edit.

## Raw hue and canonical hue are different questions

`OklabHue!T` stores raw degrees. Complete revolutions are preserved.

For example, 390° can remain stored as 390°. Ask for a normalized view only
when you need one:

```d
const hue = OklabHued.fromDegrees(390.0);

assert(hue.rawDegrees == 390.0);
assert(hue.positiveDegrees == 30.0);
```

Likewise, an OKLCH value with negative chroma is not silently rewritten on
construction. Use `canonicalized` when you explicitly need the equivalent
non-negative-chroma representation.

## Do not confuse conversion with displayability

A mathematically valid conversion may produce linear-sRGB components outside
the unit cube.

```d
const linearCandidate =
    changed
    .toOklab
    .toXyzD65
    .toLinearSRgb;

if (!linearCandidate.inGamut)
{
    // Choose policy here; do not hide it inside conversion.
}
```

Use [Interpolation and gamut mapping](interpolate-and-map-gamut.md) when you
need to choose clipping or a perceptual mapper.

## Extended values remain visible

The computational types are not packed display pixels. Negative values,
components above one, and other extended floating-point values can appear
during calculation.

The operation that finally needs a bounded display result should own the
decision to clip or gamut-map it.

For the exact model, see:

- [Color model](../concepts/color-model.md)
- [Extended values and `.init`](../concepts/extended-values-and-init.md)
- [Accuracy and validation](../accuracy-and-validation.md)
