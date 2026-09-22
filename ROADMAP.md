# color-d Roadmap

## R0 — Research and architecture

Current phase.

Goals:

- audit existing D color libraries;
- study modern reference implementations and standards;
- validate the static color-space type model;
- validate `float` / `double` generic representation;
- investigate storage versus computation types;
- prototype explicit conversion APIs;
- prototype alpha and premultiplied-alpha types;
- verify CTFE capabilities;
- prototype compile-time tone-scale generation;
- prototype compile-time GUI theme generation and validation;
- prototype gamut detection and perceptual gamut mapping;
- establish numerical reference vectors and tolerances;
- inspect generated code and basic performance characteristics.

No public API is frozen during R0.

## R1 — Mathematical core

Candidate scope:

- `SRgb8`
- `SRgba8`
- `SRgb!T`
- `LinearSRgb!T`
- `XyzD65!T`
- `Oklab!T`
- `Oklch!T`
- `Hsl!T`
- `Hsv!T`
- explicit color-space conversions
- gamut testing
- clipping
- CTFE/reference tests

## R2 — Alpha and interpolation

Candidate scope:

- straight alpha representation
- premultiplied alpha representation
- linear-light source-over compositing
- same-space interpolation
- polar hue interpolation policy

## R3 — Perceptual utilities

Candidate scope:

- relative luminance
- WCAG-style contrast ratio
- `deltaEOK`
- OKLCH tone scales
- perceptual gamut mapping

## R4 — First consumer integration

Exercise the API through concrete consumers:

- `imagery-d`
- OSM editor theme/style layer

Public API stabilization begins only after real consumer usage.

## Later

Only with concrete consumer requirements:

- Display-P3
- Rec.2020
- CIELAB / LCh
- CIEDE2000
- Okhsl / Okhsv
- CSS parsing/serialization
- scientific and categorical palettes
- color-vision-deficiency tooling
- HDR
- ICC / CMYK
