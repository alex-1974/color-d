# color-d Roadmap

## Current release target

The current planned first public release is:

```text
v0.1.0 — First public release
```

GitHub milestone `v0.1.0 — First public release` is the concrete release target.

The R0–R4 names below describe development phases and promotion/validation
gates leading to that release. They are not separate package releases.

Current sequence:

```text
R0  research and architecture closeout
 ↓
R1  mathematical core production API
 ↓
R2  alpha and interpolation
R3  perceptual utilities
 ↓
R4  real consumer validation
 ↓
v0.1.0 release hardening and publication
```

R2 and R3 may overlap where there is no technical dependency.

Detailed work, decisions and release gates are tracked in GitHub issues.
This roadmap records the durable direction and sequencing rather than
duplicating issue-level task lists.

## R0 — Research and architecture

Closeout phase; R0.14 is the final promotion decision.

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

R0.12 established compile-time palette construction and validation as ordinary
composition of the already validated color primitives rather than a new
policy-heavy palette engine.

Compile-time-known palette structure is adequately represented by ordinary
fixed-size arrays. Construction, explicit gamut mapping, target conversion and
measurement/validation remain separate operations, with acceptance policy owned
by the caller. No semantic `Palette`, `Theme`, `PaletteBuilder` or
`ThemeBuilder` abstraction is justified by the research evidence.

A DMD runtime code-generation/calling-boundary defect was reduced independently
during R0.12. For the tested runtime integration path, caller-owned `ref`
outputs plus `ref const` static-array inputs provide one common correct form
across DMD 2.111.0–2.113.0 and LDC 1.41.0–1.43.0. No compiler switch is
required for correctness by the current implementation; compiler-specific
paths remain permissible when separately justified by reproduced correctness
evidence or material measured performance.

R0.12 does not introduce a universal numerical tolerance. The measured
runtime-versus-CTFE floating-point differences remain input to R0.13.

No public palette API is frozen by R0.12.

R0.13 numerical/reference policy (#9) and the durable `color-d` / `imagery-d`
responsibility boundary (#1) are complete.

The performance baseline and targeted compiler/code-generation work in #5 is
complete. It established LDC as the v0.1 release-performance reference compiler,
validated equivalent native C++ baselines, isolated the Phobos
`pow(real, real)` hot-path bottleneck, and demonstrated a CTFE-preserving LDC
runtime path at C++-competitive performance.

R0.14 (#10) is the final synthesis gate. Its accepted promotion matrix:

- promotes the validated computational core
  `SRgb!T` / `LinearSRgb!T` / `XyzD65!T` / `Oklab!T` / `Oklch!T`
  for `float` and `double`;
- promotes the validated alpha/compositing, interpolation, WCAG-2,
  `deltaEOK`, explicit gamut and low-level OKLCH tone primitives;
- deliberately defers `SRgb8`, `SRgba8`, `Hsl!T` and `Hsv!T` from v0.1;
- rejects a policy-heavy semantic Palette/Theme/builder abstraction in
  `color-d`;
- defines the initial supported public module/import surface;
- carries forward the R0.13 numerical policy and #5 compiler/performance policy;
- requires both real-consumer gates #4 and #13 before v0.1 stabilization.

Once #10 and the R0 closeout umbrella #2 are closed, production promotion may
begin through R1--R3. Public API remains pre-1.0 and consumer-correctable until
the release gate.

## R1 — Mathematical core

Tracked by GitHub issue #3.

R1 promotes accepted R0 research into deliberate production modules and API.
Research experiment code is evidence, not production code to copy mechanically.

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

Tracked by GitHub issue #11.

Candidate scope:

- straight alpha representation
- premultiplied alpha representation
- linear-light source-over compositing
- same-space interpolation
- polar hue interpolation policy

## R3 — Perceptual utilities

Tracked by GitHub issue #12.

Candidate scope:

- WCAG-2 relative luminance
- WCAG-2 contrast ratio
- `deltaEOK`
- OKLCH tone scales
- perceptual gamut mapping

## R4 — First consumer integration

Consumer validation is tracked separately for the two initial real consumers:

- #4 — `imagery-d`;
- #13 — OSM editor theme/style layer.

The exact consumer paths must come from real application requirements rather
than synthetic API demonstrations.

Public API stabilization begins only after real consumer usage has exercised
the production surface and discovered friction has been resolved or
deliberately documented.

## v0.1.0 — Release hardening and publication

Tracked by GitHub issue #14 and milestone
`v0.1.0 — First public release`.

Release hardening follows completion of the accepted R1–R3 production scope
and both R4 consumer-validation paths.

The final gate covers:

- public root/direct-module surface audit;
- tested DMD/LDC support statement;
- clean production and consumer verification;
- README / CHANGELOG / release-note accuracy;
- one exact verified release commit;
- `v0.1.0` tag and published release.

Public Ddoc, tests and executable examples are not deferred to this phase;
they evolve with the production APIs that introduce them.

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
