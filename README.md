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

## Installation with DUB

`color-d` has not published v0.1.0 yet, so there is currently no released
registry version to depend on. Pre-release consumers should make the source
they consume explicit.

For a local workspace checkout, use a path dependency:

```sdl
dependency "color-d" path="../color-d"
```

Adjust the path to the checked-out repository. This is the same dependency
shape exercised by the clean-package external DUB consumer in Fast CI.

For an external reproducible pre-release build, pin an exact reviewed Git
commit rather than a moving branch:

```sdl
dependency "color-d" \
    repository="git+https://github.com/alex-1974/color-d.git" \
    version="<commit-sha>"
```

Replace `<commit-sha>` with the exact color-d commit your project has
validated. DUB repository dependencies use the `version` field as the Git
commitish; a fixed commit avoids silently following later pre-1.0 API
corrections.

After v0.1.0 is deliberately released and its DUB-registry publication is
verified, the normal released dependency will be:

```sdl
dependency "color-d" version="~>0.1.0"
```

At that point `dub add color-d` may be used to add the latest registry
release. Until then, do not treat an unpublished registry version as part of
the supported installation contract.

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

The same quick-start source is compiled and executed from
[`tests/examples/readme_quickstart.d`](tests/examples/readme_quickstart.d) by
Fast CI so this documented call path cannot silently drift.

## Research and evidence

The public library is the maintained result of the R0–R4 research programme;
the research programme itself is **not** part of the consumer package.

Detailed experiments, compiler probes, benchmark drivers, rejected approaches,
and long-form evidence are being separated from the production repository under
the migration tracked by #107. Until that migration is verified, the historical
material remains in this repository under `docs/research/` and
`experiments/`, but both paths are excluded from release archives.

The maintained production contract lives in the source/Ddoc, user
documentation, tests, accepted ADRs, and release metadata. A consumer should
not need research history in order to understand or use the library.

See [RESEARCH.md](RESEARCH.md) for the repository roles and migration rule.

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

For maintainers:

- [Architecture decision records](docs/adr/)
- [Technical specification](docs/spec/TECHNICAL_SPEC.md)
- [Repository design principles](DESIGN_PRINCIPLES.md)
- [Roadmap](ROADMAP.md)
- [Research and evidence boundary](RESEARCH.md)

Detailed research/evidence is repository material, not consumer-package
documentation. See [RESEARCH.md](RESEARCH.md) for the current migration state.

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
