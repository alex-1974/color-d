# color-d / imagery-d Responsibility Boundary

**Status:** Accepted R0 architecture contract
**Date:** 2026-09-25
**Tracking:** color-d #1; imagery-d #3

## Purpose

This document records the `color-d` side of the durable responsibility and
integration boundary with `imagery-d`.

It is reciprocal to:

- `alex-1974/imagery-d` `docs/research/m1-color-d-boundary.md`;
- imagery-d ADR 0002, which accepts the image-semantic core and the independent
  `color-d` boundary.

This contract fixes ownership. It does **not** freeze the final `color-d`
public API names or require `imagery-d` to depend on pre-production code.

## Dependency direction

```text
color-d
   ↑
imagery-d
   ↑
image sources / codecs / products / applications
```

`color-d` has no dependency on `imagery-d`, `raster-d`, image codecs, raster
layout, caching, source pipelines or rendering frameworks.

`imagery-d` may depend on `color-d` once a concrete image operation needs a
production `color-d` capability.

## Core boundary

The shortest durable statement is:

> `imagery-d` owns the semantic binding between raster channels and image
> colour meaning; `color-d` owns general colour-value mathematics once those
> channels are represented as colour values.

Equivalently:

```text
raster samples
    |
    | imagery-d identifies/binds semantic channels
    v
image colour tuple
    |
    | materialize a supported color-d value
    v
typed colour value
    |
    | color-d mathematics
    v
typed colour result
    |
    | imagery-d writes/propagates into image/raster domain
    v
image result
```

## color-d owns

`color-d` owns general colour mathematics and value semantics:

- statically distinct colour-space value types;
- encoded versus linear-light RGB distinction;
- explicit colour-space conversion mathematics;
- Oklab / OKLCH semantics;
- straight-alpha mathematical values;
- statically distinct premultiplied mathematical representation;
- linear-light source-over compositing mathematics;
- colour interpolation semantics and hue-path policy;
- gamut testing, clipping and gamut mapping;
- relative luminance and contrast mathematics;
- perceptual colour difference;
- generic tone-scale / palette primitives;
- packed colour-value/storage types such as `SRgb8` / `SRgba8` if retained by
  the R0.14 v0.1 scope.

`color-d` does not attach image meaning to a memory layout.

## imagery-d owns

`imagery-d` owns image-domain binding and execution:

- which raster planes/channels participate in colour;
- component order and channel-to-colour binding;
- image pixel-format and layout description;
- image colour-encoding/profile metadata;
- identification of an alpha channel;
- stored alpha association: straight, premultiplied or unknown;
- distinction between alpha, masks, validity and NoData;
- preservation of non-colour channels;
- application of colour operations over raster regions / ROIs / streams;
- propagation and preservation of image metadata;
- source/cache/pipeline behavior;
- materialization of heterogeneous image products into common-grid processing
  views;
- explicit resampling or sample-type conversion when required.

## Packed colour values versus image layout

`SRgb8` / `SRgba8`, if promoted in v0.1, are `color-d` colour values with
defined component semantics and compact storage.

They are **not**:

- an image pixel-format enum;
- an interleaving rule;
- a row-stride rule;
- a channel-binding descriptor;
- proof that a raster's first three/four channels are RGB(A).

Therefore both can be valid imagery representations:

```text
RasterView!ubyte + explicit RGB channel binding

RasterView!SRgb8 + explicit image semantics
```

Choosing between them is an imagery/storage decision. `color-d` does not force
a physical image representation.

## Minimum binding before constructing a color-d value

Before image samples can be interpreted as a `color-d` value, the image layer
must know enough semantics to make the construction unambiguous.

For an RGB path this includes at least:

- which channels are R, G and B;
- their component order;
- the supported colour encoding/space being asserted;
- the sample-to-colour-value interpretation required by that encoding;
- whether an alpha channel participates;
- if alpha participates, whether the image data are straight or premultiplied.

Layout alone is insufficient. Channel count alone is insufficient. Names alone
are insufficient.

ICC/profile metadata may be preserved even when current `color-d` cannot
interpret it. Unsupported metadata must not be discarded merely because no
current colour transform consumes it.

## Alpha, masks and NoData

These remain separate concepts.

```text
alpha
    compositing / coverage semantics

mask / validity
    whether image data are usable for an operation

NoData
    image-domain missing-data semantics
```

`imagery-d` owns which channel or sidecar carries those meanings.

`color-d` owns only the mathematical semantics of alpha-bearing colour values
and compositing.

A validity mask or NoData sentinel must never become alpha implicitly.

## Straight and premultiplied transitions

`imagery-d` owns when an image pipeline needs to change association state.
`color-d` owns the explicit mathematics for the corresponding colour value.

Validated `color-d` research requires linear-light premultiplication for the
low-level source-over compositor.

A nonlinear colour-space transformation must not treat premultiplied channel
values as though they were straight encoded colour components.

Conceptually, when such a transformation is required:

```text
image metadata says premultiplied
        ↓
materialize the supported premultiplied colour value
        ↓
explicitly recover straight colour where mathematically defined
        ↓
perform explicit colour-space conversion
        ↓
re-establish the required association in the appropriate working space
        ↓
return result to imagery-d
```

At alpha zero, hidden straight RGB lost by premultiplication is not recoverable;
the image layer must not invent it.

## Colour conversion boundary

`color-d` owns the transform:

```text
typed colour value A -> typed colour value B
```

`imagery-d` owns:

```text
which image channels form A
how samples are materialized as A
where/over which region conversion executes
how B is stored back into image/raster structures
what happens to unrelated channels and metadata
```

No colour conversion silently clips, resamples, reorders image channels or
changes NoData/validity semantics.

## Compositing boundary

`color-d` owns value-level source-over mathematics.

`imagery-d` owns image-level orchestration:

- selecting foreground/background image regions;
- aligning grids;
- resolving masks/validity/NoData;
- selecting/binding alpha channels;
- materializing supported colour values;
- storing the result;
- preserving image metadata and unrelated channels.

`color-d` must not acquire raster iteration, ROI, tile, streaming or image
lifetime responsibilities to make compositing convenient.

## Extended values and clipping

`color-d` preserves valid extended computational values and does not clip
implicitly.

`imagery-d` likewise must not assume floating-point image colour data are
bounded to `[0,1]` merely because they may later be displayed.

Clipping or gamut mapping is an explicit colour operation. Sample-type
conversion, quantization and image output encoding remain explicit imagery
operations around that mathematics.

## Concrete imagery-d consumer path

The following path is concrete enough to establish the integration contract
for R0 while leaving real-code validation to color-d #4:

### Common-grid sRGB image transform

Input:

- one common-grid `imagery-d` processing view;
- explicit R/G/B channel binding;
- image metadata declaring supported sRGB interpretation;
- optional explicit alpha binding and association;
- optional validity/NoData information;
- zero or more unrelated channels such as quality or spectral data.

Execution:

```text
imagery-d
    identifies RGB(+A) samples for one processing element
        ↓
    materializes SRgb!float or alpha-bearing equivalent
        ↓
color-d
    performs explicit sRGB -> linear-sRGB conversion
        ↓
    optionally performs an alpha/compositing operation in the
    mathematically required representation
        ↓
    returns a typed colour result
        ↓
imagery-d
    stores the selected colour result in the requested target representation
    while preserving unrelated channels, validity/NoData semantics and image
    metadata according to the image operation contract
```

This path demonstrates that the dependency boundary is sufficient without
making `color-d` image-aware.

color-d #4 will later validate an actual production operation through real
`imagery-d` code. #4 may refine call shapes, but it must not silently move the
ownership boundary.

## Responsibility matrix

| Concern | imagery-d | color-d |
|---|---|---|
| colour-space mathematical value | consumes/materializes | owns |
| encoded vs linear semantics | records/binds image interpretation | owns math/value semantics |
| pixel/raster layout | owns/consumes from raster-d | — |
| channel identity/order | owns | — |
| colour-component binding | owns | — |
| packed `SRgb8`/`SRgba8` value semantics | may store/consume | owns if promoted |
| pixel-format/layout descriptor | owns | — |
| image colour metadata | owns/preserves | interprets only supported value semantics |
| ICC/profile preservation | owns | not v0.1 colour-management scope |
| identify alpha channel | owns | — |
| straight/premultiplied image state | owns/preserves | owns mathematical value semantics |
| mask / validity / NoData | owns image meaning | — |
| colour conversion math | invokes over image data | owns |
| source-over math | orchestrates image execution | owns value-level math |
| interpolation math | orchestrates image execution | owns value-level math |
| gamut math | invokes | owns |
| clipping / mapping policy choice | image/application operation chooses explicitly | provides explicit operations |
| ROI / streaming / tiling | owns/consumes raster-d | — |
| unrelated channel preservation | owns | — |
| resampling | owns explicit image operation | — |
| source/cache pipeline | owns | — |

## Dependency timing

`imagery-d -> color-d` is architecturally permitted but not required merely to
represent image semantics.

The dependency is admitted when:

1. a concrete imagery operation needs a production `color-d` capability;
2. the required `color-d` surface has passed its production promotion gate;
3. the integration does not duplicate general colour math in `imagery-d`;
4. the integration does not introduce image/raster semantics into `color-d`.

Thus R0 ownership can close before R4 consumer implementation.

## Future wide-gamut/profile semantics

The same split continues beyond v0.1:

- `imagery-d` owns image-level declarations, profile identity and metadata
  preservation;
- `color-d` may later own additional mathematical colour spaces/transforms;
- a separate future colour-management layer may be required for full ICC
  workflows;
- unsupported metadata remains preservable without forcing premature math/API
  into `color-d`.

## Accepted invariants

1. `color-d` remains independent of image/raster representation.
2. Image layout never determines colour semantics by itself.
3. Image channel count never determines colour semantics by itself.
4. Alpha, mask, validity and NoData remain distinct.
5. Packed colour values do not define an image pixel format.
6. Colour conversion remains explicit.
7. Premultiplied data are not fed through nonlinear colour transforms as
   straight colour.
8. Extended values are not clipped implicitly.
9. Non-colour channels are owned/preserved by the image layer.
10. No implicit resampling or sample-type coercion is introduced by color-d.
11. `imagery-d` may preserve metadata that `color-d` cannot interpret.
12. Real consumer code in #4 validates usability but does not redefine
    ownership silently.

## Conclusion

The `color-d` and `imagery-d` architecture is mutually compatible.

The durable boundary is:

> Image semantics and execution stay in `imagery-d`; general colour-value
> mathematics stays in `color-d`.

This resolves color-d #1 without freezing the final public API or requiring an
immediate dependency.
