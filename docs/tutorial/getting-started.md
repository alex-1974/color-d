# Getting started

`color-d` is a color-mathematics library for D. It does not try to be a
theme system, image format, renderer, or GUI toolkit.

Its main job is simpler: keep the mathematical meaning of a color visible while
you work with it.

That matters because these values are not interchangeable:

- encoded sRGB is convenient for storage and display;
- linear-light sRGB is the right domain for light mixing and compositing;
- Oklab and OKLCH are useful for perceptual adjustments;
- an out-of-gamut intermediate value is not the same thing as an invalid color.

The types in `color-d` make those distinctions explicit.

## Import the supported API

Most programs should start with:

```d
import color;
```

This root module exposes the complete supported public API.

You may import a documented module such as `color.rgb` or `color.oklch`
directly when you deliberately want a narrower import surface.

## Start with the color you actually have

Suppose an application receives ordinary encoded sRGB channel values:

```d
const encoded = SRgbd(0.82, 0.25, 0.12);
```

`SRgbd` stores three `double` components. `SRgbf` is the corresponding
`float` type.

Construction does not clamp values to the interval from 0 to 1. These are
mathematical color values, not packed bytes.

## Convert before doing perceptual work

Encoded sRGB is nonlinear. If you want to move into a perceptual color space,
make each conversion visible:

```d
const perceptual =
    encoded
    .toLinear
    .toXyzD65
    .toOklab
    .toOklch;
```

The types now tell the story:

```text
SRgbd
    -> LinearSRgbd
    -> XyzD65d
    -> Oklabd
    -> Oklchd
```

None of these conversions clips the color or silently maps it into a display
gamut.

That is intentional. A perceptual edit often needs intermediate values that are
outside the final sRGB gamut.

## Adjust a color in OKLCH

OKLCH separates lightness, chroma, and hue. For many UI and palette operations,
that makes the intended edit easier to express.

For example:

```d
const adjusted =
    perceptual
    .withLightness(0.70)
    .withChroma(0.16);
```

These are raw component replacements.

They do not:

- clamp lightness;
- force chroma to a nominal range;
- normalize hue;
- clip RGB;
- perform gamut mapping.

That keeps mathematical editing separate from output policy.

## Choose gamut policy explicitly

The adjusted color may not fit inside the sRGB cube.

You can ask:

```d
const linear = adjusted.toOklab.toXyzD65.toLinearSRgb;
const alreadyFits = linear.inGamut;
```

When you need a displayable result, choose the operation deliberately.

Ray Trace mapping:

```d
const displayLinear =
    adjusted.gamutMapRayTraceToLinearSRgb;

assert(displayLinear.inGamut);
```

Local MINDE mapping is a separate explicit algorithm. Hard clipping is also a
separate operation.

There is no default perceptual mapper because those choices are policy, not
mere conversion.

## Encode only when the consumer needs encoded sRGB

After the linear-light result is inside the target gamut:

```d
const display = displayLinear.toSRgb;
```

Now `display` is encoded sRGB again.

A useful rule is:

> decode before light-space mathematics; encode for an encoded-sRGB consumer.

## Extended values are visible

`color-d` does not silently repair every unusual floating-point value.

NaN, infinity, negative components, and values above 1 may be meaningful to a
numerical pipeline or may indicate a problem in your application. The library
keeps them visible unless the operation's contract says otherwise.

Likewise, `.init` for floating color types is not implicit black. The natural
floating-point initialization contains NaNs and is therefore detectably
uninitialized.

For the exact rules, see
[Extended values and `.init`](../concepts/extended-values-and-init.md).

## Composite in linear light

Do not source-over composite ordinary encoded sRGB values directly.

The intended shape is:

```text
encoded sRGB
    -> linear-light sRGB
    -> alpha/compositing operation
    -> encoded sRGB when needed
```

Straight and premultiplied alpha are distinct public concepts. Their
conversions are explicit so that association state does not become hidden
metadata.

See [Alpha and compositing](../how-to/alpha-and-compositing.md).

## Interpolate in the space you mean

Interpolation is also space-dependent.

Rectangular interpolation and OKLCH interpolation are different operations.
OKLCH interpolation additionally requires a hue-path choice when direction
around the hue circle matters.

The library does not silently select a perceptual space or hue policy for you.

See [Interpolation and gamut mapping](../how-to/interpolate-and-map-gamut.md).

## The same API can run at compile time

Deterministic core operations are designed to use the same API during CTFE when
the supported D toolchain permits it.

For example:

```d
enum accent =
    Oklchd(
        0.70,
        0.30,
        OklabHued.fromDegrees(40.0)
    )
    .gamutMapRayTraceToLinearSRgb;

static assert(accent.inGamut);
```

This is useful for fixed built-in color data.

Do not assume that every transcendental intermediate must be bit-identical
between CTFE and runtime. Use the documented numerical contract of the
operation.

See [Accuracy and validation](../accuracy-and-validation.md).

## What color-d deliberately does not decide

A color library should not become an application policy engine.

`color-d` therefore does not decide:

- which semantic theme roles your application has;
- which contrast threshold your product requires;
- how a renderer draws selected geometry;
- which OSM feature gets which style;
- how an image is tone-mapped as a whole;
- which gamut mapper your product should prefer by default.

It supplies the mathematical operations. The consumer supplies the policy.

## A complete small path

Putting the common pieces together:

```d
import color;

void main()
{
    const encoded = SRgbd(0.82, 0.25, 0.12);

    const edited =
        encoded
        .toLinear
        .toXyzD65
        .toOklab
        .toOklch
        .withLightness(0.70)
        .withChroma(0.16);

    const displayLinear =
        edited.gamutMapRayTraceToLinearSRgb;

    assert(displayLinear.inGamut);

    const display = displayLinear.toSRgb;

    // The result remains an ordinary value type.
    assert(display.r == display.r);
}
```

The same path is kept executable in repository tests so the tutorial cannot
silently drift away from the public API.

## Where to go next

For task-oriented use:

- [Convert and adjust colors](../how-to/convert-and-adjust.md)
- [Alpha and compositing](../how-to/alpha-and-compositing.md)
- [Interpolation and gamut mapping](../how-to/interpolate-and-map-gamut.md)
- [WCAG measurements and tone families](../how-to/wcag-and-tones.md)

For the mental model:

- [Color model](../concepts/color-model.md)
- [Extended values and `.init`](../concepts/extended-values-and-init.md)
- [Error and validation model](../concepts/error-model.md)
- [Glossary](../glossary.md)

For exact API signatures and executable examples, use the generated DDox
documentation.
