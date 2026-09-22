# color-d

`color-d` is a small, type-safe, allocation-free modern color mathematics
library for D.

The library is intended to provide explicit color-space types, correct
linear-light operations, perceptual color workflows, alpha compositing,
interpolation, gamut handling, contrast analysis, and palette primitives.

Primary initial consumers are:

- the D OSM/geospatial editor;
- `imagery-d`;
- GUI and rendering code in the `d-geospatial-workspace`.

## Design direction

Core principles:

- color space is part of the type;
- encoded sRGB and linear-light sRGB are distinct types;
- color-space conversions are explicit;
- storage and computation representations are separate;
- Oklab and OKLCH are first-class perceptual spaces;
- out-of-gamut intermediate values are preserved;
- clipping and gamut mapping are explicit;
- straight and premultiplied alpha are distinct concepts;
- core mathematics should be allocation-free;
- `@safe`, `pure`, `nothrow`, and `@nogc` are preferred where applicable;
- deterministic core operations should support CTFE where technically possible.

## Validated research

The initial architecture has been exercised through executable research
spikes:

| Stage | Topic | Status |
|---|---|---|
| R0.1 | Type model and CTFE | PASS |
| R0.2 | sRGB <-> linear sRGB | PASS |
| R0.3 | linear sRGB <-> XYZ D65 | PASS |
| R0.4 | XYZ D65 <-> Oklab | PASS |
| R0.5 | Oklab <-> OKLCH and hue semantics | PASS |
| R0.6 | Alpha, premultiplied alpha and linear-light source-over | PASS |
| R0.7 | Interpolation and OKLCH hue-path semantics | PASS |

The currently validated computational chain is:

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

The research spikes validate, among other things:

- distinct statically typed color spaces;
- generic `float` and `double` computation;
- compact value layouts;
- allocation-free scalar conversion mathematics;
- CTFE across the tested conversion chain;
- preservation of extended/out-of-gamut intermediate values;
- explicit OKLCH hue semantics;
- raw/unbounded hue storage with explicit normalization.

Detailed executable results are available under
[`experiments/`](experiments/).

In particular:

- [`R0.4 XYZ D65 / Oklab results`](experiments/r0_4_xyz_oklab/RESULTS.md)
- [`R0.5 OKLCH / hue semantics results`](experiments/r0_5_oklch_semantics/RESULTS.md)
- [`R0.6 alpha / compositing results`](experiments/r0_6_alpha_semantics/RESULTS.md)
- [`R0.7 interpolation results`](experiments/r0_7_interpolation_semantics/RESULTS.md)

## Workspace role

This repository is the authoritative source for color mathematics and
color-space semantics in the `d-geospatial-workspace`.

Other workspace projects should consume or reference `color-d` rather than
developing parallel color-math implementations.

The intended dependency direction is:

```text
color-d
   ↑
imagery-d
   ↑
rendering / styling / editor code
```

Application-specific theme semantics remain outside this library.

In particular:

- `imagery-d` may depend on `color-d`;
- `color-d` must not depend on `imagery-d`;
- OSM-specific styling does not belong in `color-d`;
- GUI-framework-specific theme tokens do not belong in `color-d`;
- renderer- or GPU-specific integration belongs in consumer layers unless a
  generic mathematical abstraction is demonstrated to belong here.

## Architecture references

Start with:

- [`docs/spec/TECHNICAL_SPEC.md`](docs/spec/TECHNICAL_SPEC.md) — current
  research-derived technical specification;
- [`DESIGN_PRINCIPLES.md`](DESIGN_PRINCIPLES.md) — design constraints and
  engineering principles;
- [`docs/research/COLOR_LIB_01.md`](docs/research/COLOR_LIB_01.md) — initial
  ecosystem and architecture research;
- [`docs/research/R0_5_OKLCH_SEMANTICS.md`](docs/research/R0_5_OKLCH_SEMANTICS.md)
  — detailed OKLCH and hue-semantics research;
- [`ROADMAP.md`](ROADMAP.md) — current development direction.

## Project status

Research and architecture phase.

No public API is stable yet.

See:

- `docs/spec/TECHNICAL_SPEC.md`
- `docs/research/`
- `docs/adr/`
- `docs/design/`

Implementation will begin only after the initial architecture spikes have
validated the type model, conversion API, alpha model, CTFE behavior, and
gamut policy.
