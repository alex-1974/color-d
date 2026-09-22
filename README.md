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
