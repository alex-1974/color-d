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

The public API is still pre-1.0. R4 real-consumer validation is complete and
did not demonstrate an API correction requirement. Until v0.1.0 is published,
the accepted feature scope remains frozen and changes are limited to release
hardening, reproduced defect fixes, validation/documentation, and confirmed
toolchain or performance corrections.

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

## Release package, repository, and research

These are deliberately different products.

The **consumer release** contains the library source, DUB metadata, licence,
README/CHANGELOG, and concise user-facing documentation. It excludes tests, CI,
repository tooling, ADR/spec material, detailed research, experiments, and
benchmark evidence.

The **GitHub production repository** additionally contains the material needed
to maintain and release the library: tests, CI, contribution files, accepted
architecture decisions, and release engineering.

Detailed experiments and long-form evidence live in the dedicated
[color-d-research](https://github.com/alex-1974/color-d-research) companion
repository. The verified split keeps the production repository and normal DUB
tag downloads lean while preserving the complete research corpus and its
provenance.

The migration record and compact research pointer remain maintainer material in
the production repository.

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

Fast CI compiles and executes the same quick-start path so this documented
call sequence cannot silently drift.

## Research and evidence

The public library is the maintained result of the R0–R4 research programme;
the research programme itself is **not** part of the consumer package.

Detailed experiments, compiler probes, benchmark drivers, rejected approaches,
and long-form evidence live in
[color-d-research](https://github.com/alex-1974/color-d-research). They are not
part of the production repository or consumer package.

The maintained production contract lives in the source/Ddoc, user
documentation, tests, accepted ADRs, and release metadata. A consumer should
not need research history in order to understand or use the library.

Repository-level research provenance is summarized in
[RESEARCH.md](RESEARCH.md).

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

Maintainer architecture, ADRs, roadmap, release engineering, and research
provenance live in the production GitHub repository and are intentionally not
part of the consumer archive:

<https://github.com/alex-1974/color-d>

## Project status

R0 research and architecture are complete, and **R1 — mathematical core
production API** is complete as of 2026-09-26. The promoted production core now
covers the accepted float/double value types, explicit conversion chain, sRGB
transfer functions, strict sRGB gamut diagnostics and explicit hard clipping.

R1 mathematical core, R2 alpha/interpolation, and R3 perceptual utilities are
complete. The accepted R1–R3 production feature scope for v0.1 is now closed.
Detailed closeout evidence is maintainer material in the production repository.

R4 real-consumer validation is complete. Both initial independent consumers
used the public API successfully without requiring a provider-side API
correction:

- `imagery-d` validated typed encoded/linear sRGB transfer inside a real
  region/layout-neutral image-processing path;
- Dunia, the OSM editor application, validated CTFE/runtime theme construction,
  explicit gamut policy, WCAG contrast, `deltaEOK`, and runtime selection
  among precomputed candidates.

The v0.1 feature scope remains frozen through release hardening and publication.

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
production modules. R4 consumer validation is complete, so v0.1 is now in release hardening and
publication. No feature-scope reopening or API correction was required by the
accepted consumer evidence.

Validated R4 consumers are:

- `imagery-d`;
- Dunia's editor theme/style layer.

No public API is stable yet. Until v0.1.0 is published, only release-hardening
changes and evidence-backed corrections to the accepted contract are in scope.

Public API documentation, tests, CTFE coverage and documented `unittest`
examples are developed together with the production API rather than postponed
to release cleanup.

See the [documentation index](docs/README.md) and the development DDox API
documentation linked at the top of this README. Release planning and
publication engineering remain repository-only maintainer material.
