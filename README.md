# color-d

`color-d` is a small, type-safe, allocation-free modern color mathematics
library for D.

Stable API documentation: https://alex-1974.github.io/color-d/

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
interpolation, explicit sRGB gamut handling, model-specific color-vision-deficiency transformations, WCAG 2 measurements, and
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

The v0.2.0 release is qualified against DMD 2.112.1 and 2.113.0 plus LDC
1.42.0 and 1.43.0 on Ubuntu 24.04 x86-64. DMD 2.112.0, DMD 2.111.0,
and LDC 1.41.0 are diagnostic points rather than supported release compilers.

Fast CI uses the current pair, DMD 2.113.0 and LDC 1.43.0. Broader compatibility
qualification is kept separate from the daily development gate. DMD and LDC are
both correctness targets; LDC is the current release-performance reference
compiler.

See [Compiler matrix](docs/compiler-matrix.md) for exact-version policy,
reproducible local commands, and compiler-specific evidence.

The public API remains pre-1.0, so later 0.x releases may still make breaking
changes when justified and documented. R4 real-consumer validation completed
without requiring a provider-side API correction for v0.1.0.

## Installation with DUB

`v0.2.0` is the current released package. For normal use, add it as a DUB
dependency:

```sdl
dependency "color-d" version="~>0.2.0"
```

For a local workspace checkout, a path dependency remains valid:

```sdl
dependency "color-d" path="../color-d"
```

For an external Git dependency pinned to the released source:

```sdl
dependency "color-d" \
    repository="git+https://github.com/alex-1974/color-d.git" \
    version="v0.2.0"
```

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

A compact provenance pointer remains in [RESEARCH.md](https://github.com/alex-1974/color-d/blob/develop/RESEARCH.md); the detailed
migration/evidence record lives with the research corpus.

Current public mathematical operations are value-based, `@nogc`, and do not
perform hidden allocation. Batch tone construction and prepared CVD
transformations write into caller-owned storage. Repeated CVD work can prepare
the selected model/deficiency (and Machado severity) once, then reuse the
prepared value for single colors or allocation-free batches. The library
creates no worker threads and owns no scheduler; callers remain responsible
for parallel execution.

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

The v0.1 core is the maintained result of the R0–R4 research programme.
The v0.2 gamut-boundary, CIE/Delta-E, and CVD additions were promoted through
their own R5–R7 validation tracks. Research evidence itself is **not** part of
the consumer package.

Detailed experiments, compiler probes, benchmark drivers, rejected approaches,
and long-form evidence live in
[color-d-research](https://github.com/alex-1974/color-d-research). They are not
part of the production repository or consumer package.

The maintained production contract lives in the source/Ddoc, user
documentation, tests, accepted ADRs, and release metadata. A consumer should
not need research history in order to understand or use the library.

Repository-level research provenance is summarized in
[RESEARCH.md](https://github.com/alex-1974/color-d/blob/develop/RESEARCH.md).

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

**v0.2.0 was released on 2026-10-03** and is the current published package.
It follows v0.1.1 with practical storage/interop and the promoted generic
color-math capabilities qualified for the Dunia consumer.

The R0 research/architecture programme and R1–R4 production, utility, and
real-consumer validation phases are complete. Those phase names now describe
historical development of v0.1.0 rather than current release work. Both R4
consumers — `imagery-d` and Dunia's theme/style layer — exercised the public
API without requiring a provider-side API correction.

**v0.2.0 — Practical Color Storage and Interop** is released. Its frozen
scope adds packed sRGB/RGBA storage and compact hexadecimal interop, plus the
independently validated gamut-boundary, CIELAB/Delta-E, and CVD primitives
required by the Dunia consumer.

HSL/HSV, wider-gamut spaces, general CSS Color parsing, and policy-heavy
palette/theme abstractions remain outside the committed v0.2.0 scope.

The library remains pre-1.0, so later 0.x releases may still make
well-justified, documented breaking changes.
