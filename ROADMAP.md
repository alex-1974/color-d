# color-d Roadmap

## Current release line

**v0.1.1 — Documentation and Maintenance** was published on 2026-09-29 and
remains the current published package.

The frozen release candidate is:

```text
v0.2.0 — Practical Color Storage and Interop
```

Feature freeze, the consumer-driven promotion work, the public API audit, and
the v0.2.0 API freeze are complete. No new feature or public API enters this
release line. Remaining work is release qualification, documentation,
packaging, publication, and fixes that preserve the frozen contract.

The v0.2.0 scope is:

- compact encoded-sRGB storage with `SRgb8`;
- compact encoded-sRGB plus straight-alpha storage with `SRgba8`;
- explicit checked conversion between packed storage and `SRgb!T`, including
  documented quantization and range behavior without implicit clipping;
- compact full-byte hexadecimal sRGB/RGBA parsing and serialization without a
  general CSS parser;
- deterministic sRGB gamut-boundary measurement with `maxChromaInSRgb` and
  `SRgbChromaLimit`;
- explicit D50 CIELAB conversion plus Delta E 1976 and CIEDE2000;
- model-specific Brettel 1997, Viénot 1999, and Machado 2009 CVD transforms,
  including prepared allocation-free repeated-work forms;
- real-consumer validation with Dunia/editor and imagery workflows;
- the normal documentation, compiler, package, and release qualification gates.

The release does **not** introduce a second floating-point RGBA computational
model. Existing alpha and premultiplied-alpha semantics remain authoritative.

HSL/HSV, semantic Theme/Palette objects, general CSS Color parsing, wide-gamut
spaces, and other candidate families remain outside the committed v0.2.0 scope.

Detailed v0.2.0 work is tracked by GitHub milestone `v0.2.0`.

## v0.2.0 consumer-driven color-math promotion

**Status: COMPLETE before API freeze.**

The three Dunia-driven research-and-promotion gates produced bounded generic
color-d capabilities:

- sRGB gamut-boundary measurement through `maxChromaInSRgb` and
  `SRgbChromaLimit`;
- `CieLabD50`, explicit XYZ D65 ↔ CIELAB D50 conversion, Delta E 1976, and
  CIEDE2000; CIELCh and automatic metric/policy selection remain deferred;
- Brettel 1997 protan/deutan/tritan transforms, Viénot 1999 protan/deutan
  transforms, and Machado 2009 protan/deutan severity, with prepared repeated
  application where justified.

Each promoted family has independent validation and consumer-shaped evidence.
Application thresholds, semantic theme roles, OSM meaning, accessibility
classification, and helpers such as `isColorBlindSafe()` remain consumer
policy.

## Investigation candidates after v0.1

The following are research and design candidates, not release commitments.
They should be promoted only when consumer evidence establishes both their
value and the correct `color-d` boundary.

### Common color-library surface

- HSL / HSV: establish hue semantics for achromatic colors, extended-value
  behavior, conversion paths, CTFE behavior, interpolation expectations, and
  concrete consumer demand before promotion.
- CSS Color parsing and serialization beyond the compact hexadecimal v0.2.0
  boundary, including `rgb()`, `hsl()`, `oklab()`, and `oklch()`.
- Display-P3 and later Rec.2020 where real wide-gamut consumers justify them.
- Okhsl / Okhsv if perceptual picker/editing workflows demonstrate an advantage.
- named colors only if a standards/configuration consumer requires the data and
  ownership boundary is clear.

### Theme, palette, and editor primitives

The accepted architecture remains that `color-d` owns reusable color
mathematics, not application theme roles or OSM semantics. Research should
therefore ask which generic primitives are missing rather than introducing a
policy-heavy `Theme`, `Palette`, `ThemeBuilder`, or `PaletteBuilder`.

Investigate:

- compile-time construction and validation of fixed GUI theme data from ordinary
  D values and fixed-size arrays;
- reusable contrast- and perceptual-distance-based candidate selection;
- foreground/background distinguishability primitives for adaptive overlays;
- N-step gradients and fixed-cardinality palette generation where these are
  more than composition of existing interpolation/tone operations;
- Light, Dark, and High-Contrast consumer validation in the Dunia/OSM editor;
- how established theme systems derive and validate colors, without importing
  their framework-specific policy into `color-d`.

### Accessibility and analysis

The generic CVD transformations required by Dunia theme validation are
promoted in v0.2.0. Consumer-owned accessibility thresholds and policy remain
outside color-d.

- APCA and emerging accessibility measurements, with standards maturity and
  provenance checked before public API adoption;
- scientific and categorical palette analysis/generation where a generic
  mathematical contract can be established.

### Rendering and interchange

- GPU/renderer-friendly interop and whether existing value/static-array forms
  already suffice before adding new public representation types;
- blend modes beyond source-over, separating color mathematics from renderer
  policy;
- HDR color models and transfer functions;
- ICC / CMYK and color-management boundaries.

These candidates intentionally have no promised release version or priority.
Research may reject a candidate, keep it consumer-local, or promote only a
smaller reusable primitive.

## Historical v0.1.0 development path

The first public release followed this sequence:

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
v0.1.0 release hardening and publication — COMPLETE
```

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

**Status: COMPLETE — 2026-09-26.**

R1 promoted accepted R0 research into deliberate production modules and API.
The production contract is the maintained source/Ddoc, tests, accepted ADRs,
and the scope recorded below. Historical closeout evidence remains research
material; see [RESEARCH.md](RESEARCH.md).

Research experiment code remains evidence, not production code to copy
mechanically.

Accepted v0.1 scope:

- `SRgb!T`
- `LinearSRgb!T`
- `XyzD65!T`
- `Oklab!T`
- `Oklch!T`
- `T = float | double`
- explicit color-space conversions
- gamut testing
- explicit hard clipping
- supported root/direct-module import surface
- CTFE/reference/compile-negative tests

The earlier packed `SRgb8` / `SRgba8` and HSL/HSV candidates are not part of
R1 for v0.1; R0.14 deliberately defers them.

## R2 — Alpha and interpolation

Status: **COMPLETE**

Tracked by GitHub issue #11.

The production contract is the maintained source/Ddoc, tests, accepted ADRs,
and the scope recorded below. Historical R2 closeout evidence remains research
material; see [RESEARCH.md](RESEARCH.md).

Accepted v0.1 scope:

- straight alpha representation
- statically distinct premultiplied representation
- explicit premultiply / unpremultiply
- linear-light source-over compositing
- same-space interpolation
- OKLCH polar interpolation
- explicit `HuePath`
- validated alpha-aware interpolation

## R3 — Perceptual utilities

Tracked by GitHub issue #12.

**Status: COMPLETE — 2026-09-27.**

Completed production slices:

- R3.1 — Oklab `deltaEOK`;
- R3.2 — WCAG-2 relative luminance and contrast measurement;
- R3.3 — explicit Local MINDE and Ray Trace perceptual sRGB gamut mapping;
- R3.4 — raw OKLCH `withLightness`, `withChroma`, and `withHue`
  component operations;
- R3.5 — inclusive finite scalar `linearSchedule!N(start, end)`
  generation in `color.tone`;
- R3.6 — static-cardinality and runtime caller-owned raw tone-family batch
  forms.

The production contract is the maintained source/Ddoc, tests, accepted ADRs,
and the scope recorded below. Historical R3 closeout evidence remains research
material; see [RESEARCH.md](RESEARCH.md).

The gamut-mapping API has no default mapper; algorithm selection remains
explicit.

The accepted R1–R3 v0.1 production feature scope is now closed. API freeze is
later: R4 consumer validation may still justify pre-1.0 corrections to the
promoted surface.

## R4 — First consumer integration

**Status: COMPLETE — 2026-09-28. v0.1.0 RELEASED.**

The accepted R1–R3 production feature scope was frozen for v0.1.0. R4
validated that frozen surface through two real consumers. Neither consumer
demonstrated a need to reopen feature scope or correct the public API.

The v0.1 feature freeze ended with publication of v0.1.0. New work now follows
the normal post-release `develop` workflow; deferred feature families remain
outside v0.1.0 and require their own evidence and planning before adoption.

The durable freeze policy and exception process are recorded in
[`docs/maintainer/v0.1-feature-freeze.md`](docs/maintainer/v0.1-feature-freeze.md).

Consumer validation completed through two independent real consumers:

- #4 — `imagery-d`: encoded/linear sRGB transfer inside real region-based
  image processing, including layout/ROI and allocation-free integration;
- #13 — Dunia editor theme/style: CTFE/runtime theme construction, explicit
  gamut mapping, WCAG contrast, `deltaEOK`, and runtime background-dependent
  selection from prepared candidates.

Both consumer gates closed without a provider-side API correction. Release
hardening may therefore proceed without reopening the v0.1 feature scope.

## v0.1.0 — Release hardening and publication

Tracked by GitHub issue #14 and milestone
`v0.1.0`.

**Status: COMPLETE — v0.1.0 RELEASED.**

The v0.1.0 feature scope remained frozen through release hardening and
publication. That freeze ended with v0.1.0; its historical policy is retained in
[`docs/maintainer/v0.1-feature-freeze.md`](docs/maintainer/v0.1-feature-freeze.md).

Release hardening follows completion of the accepted R1–R3 production scope
and both R4 consumer-validation paths.

The completed release gate covered:

- public root/direct-module surface audit;
- tested DMD/LDC support statement;
- clean production and consumer verification;
- README / CHANGELOG / release-note accuracy;
- one exact verified release commit;
- `v0.1.0` tag and published release.

Public Ddoc, tests and executable examples are not deferred to this phase;
they evolve with the production APIs that introduce them.

## Post-v0.1 candidate backlog

The following are **deferred candidates**, not committed roadmap items and not
part of the v0.1.0 release scope.

They may be reconsidered only when concrete consumer requirements justify
their cost and library-boundary impact. Their order below is not a priority
ranking, and inclusion in this list does not imply a planned release version.

- HSL / HSV
- Display-P3
- Rec.2020
- CIELCh
- Okhsl / Okhsv
- CSS parsing/serialization beyond the v0.2 full-byte hexadecimal surface
- scientific and categorical palettes
- additional CVD models or policy only when independently justified
- HDR
- ICC / CMYK
