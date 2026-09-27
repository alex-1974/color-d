# color-d

`color-d` is a small, type-safe, allocation-free modern color mathematics
library for D.

Development API documentation: https://alex-1974.github.io/color-d/dev/

The library is intended to provide explicit color-space types, correct
linear-light operations, perceptual color workflows, alpha compositing,
interpolation, gamut handling, contrast analysis, and palette primitives.

Primary initial consumers are:

- the D OSM/geospatial editor;
- `imagery-d`;
- GUI and rendering code in the `d-geospatial-workspace`.

## When to use color-d

Use `color-d` when a D program needs explicit color-space mathematics rather
than framework-specific styling objects. Typical use cases include typed
sRGB/XYZ/Oklab/OKLCH conversion, linear-light alpha compositing, perceptual
interpolation, explicit sRGB gamut handling, WCAG 2 measurements, and
compile-time construction of fixed color data.

The library deliberately does not own application theme roles, OSM semantics,
renderer policy, image-wide rendering intent, or GUI-framework tokens.

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

## Support and compatibility

The current pre-1.0 development matrix is:

| Toolchain | Tested configuration |
|---|---|
| DMD | 2.113.0 on Ubuntu 24.04 x86-64 |
| LDC | 1.43.0 on Ubuntu 24.04 x86-64 |

No older minimum D frontend is currently promised. Passing on an older compiler
does not by itself establish supported compatibility. DMD and LDC are both
correctness targets; LDC is the current release-performance reference compiler.

The public API is still pre-1.0 and consumer-correctable during R4. Source
compatibility may therefore change before v0.1.0 when real consumer integration
demonstrates a materially better contract.

Current public mathematical operations are value-based, `@nogc`, and do not
perform hidden allocation. Batch tone construction writes into caller-owned
storage. The library creates no worker threads and owns no scheduler; callers
remain responsible for parallel execution.

## Quick start

The normal computational path keeps each color-space transition explicit:

```d
import color;

void main()
{
    const encoded = SRgbd(0.82, 0.25, 0.12);

    const perceptual =
        encoded
        .toLinear
        .toXyzD65
        .toOklab
        .toOklch;

    const adjusted =
        perceptual
        .withLightness(0.70)
        .withChroma(0.16);

    const displayLinear =
        adjusted.gamutMapRayTraceToLinearSRgb();

    assert(displayLinear.inGamut);

    const display = displayLinear.toSRgb;
    assert(display.r == display.r);
}
```

No step above performs implicit clipping, gamut mapping, alpha resolution, or
color-space conversion. Application-specific theme and styling policy remains
outside `color-d`.

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
| R0.8 | Gamut detection, clipping and perceptual gamut mapping | PASS |
| R0.9 | WCAG-2 relative luminance and contrast semantics | PASS |
| R0.10 | Oklab `deltaEOK` semantics and numerical robustness | PASS |
| R0.11 | OKLCH tone-scale semantics, CTFE and representation | PASS |
| R0.12 | Compile-time palette construction and validation | PASS |
| R0.13 | Numerical tolerance and reference policy | PASS |
| R0.14 | v0.1 scope and R0→R1 promotion decision | ACCEPTED |

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
- [`R0.8 gamut-semantics results`](experiments/r0_8_gamut_semantics/RESULTS.md)
- [`R0.9 luminance / contrast results`](experiments/r0_9_luminance_contrast/RESULTS.md)
- [`R0.10 deltaEOK results`](experiments/r0_10_delta_e_ok/RESULTS.md)
- [`R0.11 tone-scale results`](experiments/r0_11_tone_scales/RESULTS.md)
- [`R0.14 promotion gate`](docs/research/R0_14_PROMOTION_GATE.md)

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

## Documentation

Start with the [documentation index](docs/README.md).

For users:

- [Getting started](docs/tutorial/getting-started.md)
- [How-to guides](docs/how-to/)
- [Concepts](docs/concepts/)
- [Glossary](docs/glossary.md)
- [Accuracy and validation](docs/accuracy-and-validation.md)
- [Architecture](docs/architecture.md)
- [Performance](docs/performance.md)

For engineering rationale and evidence:

- [Architecture decision records](docs/adr/)
- [Technical specification](docs/spec/TECHNICAL_SPEC.md)
- [Research documents](docs/research/)
- [Executable experiments](experiments/)
- [Repository design principles](DESIGN_PRINCIPLES.md)
- [Roadmap](ROADMAP.md)

## Project status

R0 research and architecture are complete, and **R1 — mathematical core
production API** is complete as of 2026-09-26. The promoted production core now
covers the accepted float/double value types, explicit conversion chain, sRGB
transfer functions, strict sRGB gamut diagnostics and explicit hard clipping.

The integrated R1 exit audit is recorded in
[`docs/research/R1_CLOSEOUT.md`](docs/research/R1_CLOSEOUT.md).

R2 alpha/interpolation production work is also complete and recorded in
[`docs/research/R2_CLOSEOUT.md`](docs/research/R2_CLOSEOUT.md).

R3 perceptual utilities are complete and recorded in
[`docs/research/R3_CLOSEOUT.md`](docs/research/R3_CLOSEOUT.md). The accepted
R1–R3 production feature scope for v0.1 is now closed.

R4 real-consumer validation is the active phase. The public API remains
pre-1.0 and consumer-correctable: feature scope is closed, but API corrections
remain allowed where imagery-d or the OSM editor theme/style layer exposes
real integration friction.

The accepted v0.1 production scope is intentionally smaller than the early
candidate list. In particular, `SRgb8` / `SRgba8` and HSL/HSV are deferred
until concrete consumer evidence justifies them.

The current first-release target is:

```text
v0.1.0 — First public release
```

Production and stabilization sequence:

```text
R1  mathematical core
R2  alpha and interpolation
R3  perceptual utilities
R4  real consumer validation
    - imagery-d
    - OSM editor theme/style
↓
v0.1.0 release hardening and publication
```

R1--R3 have promoted the accepted validated R0 semantics into deliberate
production modules. R4 consumer validation remains mandatory before release
stabilization, and the pre-1.0 API may still be corrected when real consumer
use reveals friction.

Initial R4 consumers are:

- `imagery-d`;
- the OSM editor theme/style layer.

No public API is stable yet. Pre-1.0 API corrections remain expected where
production implementation or real consumers demonstrate a better design.

Public API documentation, tests, CTFE coverage and documented `unittest`
examples are developed together with the production API rather than postponed
to release cleanup.

See the [documentation index](docs/README.md), [ROADMAP.md](ROADMAP.md), and
the development DDox API documentation linked at the top of this README.

The public documentation publication model is described in
[docs/pages-publication.md](docs/pages-publication.md).
