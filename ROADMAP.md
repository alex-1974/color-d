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
- validate gamut detection, clipping and perceptual gamut mapping semantics;
- establish numerical reference vectors and tolerances;
- inspect generated code and basic performance characteristics, including consumer-relevant hot paths.

No public API is frozen during R0.

### Validated research through R0.8

Completed research blocks:

- R0.1 — static color-space type model and layout;
- R0.2 — extended sRGB transfer semantics and CTFE;
- R0.3 — linear sRGB / XYZ D65 conversion;
- R0.4 — XYZ D65 / Oklab conversion;
- R0.5 — OKLCH and hue semantics;
- R0.6 — alpha, premultiplication and linear-light compositing;
- R0.7 — interpolation and hue-path semantics;
- R0.8 — gamut detection, clipping and perceptual gamut-mapping semantics.

R0.8 additionally established initial performance and generated-code evidence
for Local MINDE and Ray Trace gamut mapping. Ray Trace is the stronger
bounded-cost / hot-path candidate on the measured system, while Local MINDE
remains a perceptual/reference candidate. No public default mapper is frozen.

Remaining R0 work includes:

- relative luminance and contrast semantics;
- full `deltaEOK` policy and reference coverage;
- tone-scale generation;
- compile-time palette/theme generation and validation;
- library-wide numerical tolerance policy;
- remaining basic performance/code-generation checks where justified;
- define the consumer-validation gate required before API stabilization.

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
