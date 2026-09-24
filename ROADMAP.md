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

### Validated research through R0.11

Completed research blocks:

- R0.1 — static color-space type model and layout;
- R0.2 — extended sRGB transfer semantics and CTFE;
- R0.3 — linear sRGB / XYZ D65 conversion;
- R0.4 — XYZ D65 / Oklab conversion;
- R0.5 — OKLCH and hue semantics;
- R0.6 — alpha, premultiplication and linear-light compositing;
- R0.7 — interpolation and hue-path semantics;
- R0.8 — gamut detection, clipping and perceptual gamut-mapping semantics;
- R0.9 — WCAG-2 relative-luminance and contrast semantics, domain validation
  and checked-result representation;
- R0.10 — Oklab `deltaEOK` semantics, numerical robustness, special-value
  behavior and reference coverage;
- R0.11 — OKLCH tone-scale primitive decomposition, finite schedule semantics,
  chroma/hue policy, explicit gamut composition, allocation-free
  representation, CTFE and edge-case properties.

R0.8 additionally established initial performance and generated-code evidence
for Local MINDE and Ray Trace gamut mapping. Ray Trace is the stronger
bounded-cost / hot-path candidate on the measured system, while Local MINDE
remains a perceptual/reference candidate. No public default mapper is frozen.

R0.9 established that WCAG-2 relative luminance is distinct from XYZ-D65 Y,
that standards-facing WCAG measurements require finite `[0,1]` sRGB-domain
input, and that unresolved alpha must be resolved before contrast measurement.

R0.9 also compared checked-result representations. A compact scalar result
using NaN as the invalid state is the preferred research candidate. A
two-field `{T,bool}` result showed a substantial DMD 2.111 `double`
code-generation regression and is not preferred. `try(..., ref T)` remains a
valid alternative. No public WCAG API or result type is frozen.

R0.10 established `deltaEOK` as direct same-scalar Euclidean distance in
Oklab, with no hidden conversion, clipping, gamut mapping, alpha resolution or
JND classification. Finite extended Oklab values remain valid inputs.

For the future production implementation, guarded three-argument Phobos
`hypot` is the preferred research candidate: color-d explicitly handles NaN
and infinity before delegating the finite Euclidean norm to `hypot`. The
straightforward squared-sum implementation is not sufficiently robust across
the tested compiler/build configurations, while a custom scaled norm remains a
validated fallback/reference implementation. No public API is frozen.

R0.11 established tone-scale generation as composition of explicit low-level
operations rather than one policy-heavy universal generator. Raw OKLCH
lightness/chroma/hue values remain authoritative; there is no implicit
clamping, chroma canonicalization, hue normalization or gamut mapping.

Finite generated schedules have explicit schedule semantics. Matching raw
anchors remain exact naturally; a mismatching requested schedule is not
silently repaired to preserve the seed.

For representation, compile-time-known cardinality is adequately represented
by `Oklch!T[N]`, while runtime-known cardinality can use caller-owned
`Oklch!T[]`. No custom tone-scale container is currently justified.

The tested raw component operations preserve NaN and infinity rather than
silently repairing them. Generated non-finite schedule arithmetic remains
deliberately unspecified, and non-finite gamut-mapping behavior was not
contracted.

No public tone-scale API name, default gamut mapper or universal numerical
epsilon is frozen by R0.11.

Remaining R0 work includes:

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

- WCAG-2 relative luminance
- WCAG-2 contrast ratio
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
