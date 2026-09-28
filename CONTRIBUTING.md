# Contributing to color-d

`color-d` follows the `d-geospatial-workspace` engineering and Git/GitHub
workflow.

## Branches

Normal work starts from and targets `develop`.

Use short-lived topic branches such as:

```text
feat/*
fix/*
docs/*
perf/*
refactor/*
test/*
validation/*
ci/*
build/*
```

`main` is release-oriented and is not the normal development branch.

## Issues and pull requests

Tracked work should have a GitHub issue. Pull requests normally target
`develop` and use Conventional Commit titles, for example:

```text
docs(api): document failure-state semantics
fix(gamut): preserve boundary classification
perf(rgb): remove avoidable transfer overhead
```

Use `Closes #N` when the PR fully resolves an issue and `Refs #N` when it
only contributes to it.

## Required checks

Before opening or merging a normal PR:

```bash
dub test --compiler=dmd --build=debug --force
dub test --compiler=dmd --build=release --force
dub test --compiler=ldc2 --build=debug --force
dub test --compiler=ldc2 --build=release --force
```

The repository Fast CI also checks DDox, CTFE/runtime behavior, and external
public-import contracts.

## Public API changes

Public behavior should arrive together with:

- useful Ddoc;
- documented `unittest` examples where the API benefits from one;
- semantic/unit/regression tests;
- compile-negative tests when illegal source is part of the contract;
- CHANGELOG entries when user-visible;
- benchmark evidence when performance-relevant.

Documentation claims about CTFE, failure state, allocation, numerical accuracy,
or language attributes are treated as contracts and should have executable
evidence where practical.

## Documentation standard

Documentation is part of the public API. The detailed maintainer checklist is in
[docs/maintainer/documentation-style.md](docs/maintainer/documentation-style.md).

Write for the reader who needs to solve a color problem, not for the author who
already knows the implementation. The style should follow the practical
discipline associated with clear technical prose: prefer simplicity, concrete
language, active verbs, short paragraphs, and enough context to understand
*why* a distinction matters before listing its mechanics.

### User documentation

A useful page normally proceeds in this order:

1. state the problem or decision the reader faces;
2. give the common path in a small example;
3. explain the important semantic distinction;
4. state failure/range/allocation behavior that changes how the API is used;
5. link to deeper numerical or architectural material only when needed.

Do not lead a getting-started page with research history, compiler defects, or
edge-case tables. Those belong in maintenance/evidence documentation unless the
reader must know them to use the API correctly.

Prefer one idea per paragraph. Remove words that do not change meaning. Prefer
"convert encoded sRGB to linear light before compositing" over abstract prose
that hides the action.

### Ddoc / DDox

Public modules and non-trivial public declarations should have Ddoc that is
useful when read directly in DDox.

Use named Ddoc sections when they improve scanning, for example:

```text
Semantics:
Common_Path:
Range:
Failure:
Allocation:
Compile_Time:
Standards:
See_Also:
```

Do not create sections mechanically when a short declaration needs only one
sentence.

Public callables should document caller-visible behavior before implementation
detail. Include `Params:`, `Returns:`, preconditions/failure state, units or
ranges, allocation, and provenance only where relevant.

### Executable examples

A compact public example should normally be a **documented unittest** directly
after the declaration it demonstrates:

```d
///
@safe pure nothrow @nogc unittest
{
    const encoded = SRgbd(0.5, 0.25, 0.0);
    const linear = encoded.toLinear;

    assert(linear.r > encoded.r * encoded.r);
}
```

The leading `///` is deliberate: Ddoc/DDox includes that unittest in the
declaration's example section, while CI compiles and runs the same code.

Examples are teaching code, not exhaustive regression suites. Keep them small,
name values by meaning, and comment the semantic reason for a non-obvious step.
Put numerical corpora, toolchain canaries, and edge-case regression machinery
in ordinary unittests or dedicated test/evidence code so the generated API
documentation remains readable.

### Documentation and research are different products

User documentation explains how to use the maintained library. Research
evidence explains why a design/implementation was accepted. Do not make a
consumer read research logs to discover the normal API path.

## Numerical changes

Do not introduce a library-wide epsilon. Follow the property-specific numerical
policy in [docs/accuracy-and-validation.md](docs/accuracy-and-validation.md).

Numerically significant algorithm changes should preserve provenance and
validation evidence. Performance changes must not weaken public semantics.

## Safety

Public APIs should remain `@safe` where reasonably possible. New
`@trusted` code requires a narrow scope and a concise safety justification.

## Research

Research is not automatically production scope.

The target repository model separates detailed experiments/evidence from the
production repository; see [RESEARCH.md](RESEARCH.md) and #107. During the
migration, historical evidence remains under `docs/research/` and
`experiments/`, but it is excluded from consumer archives.

Do not delete research material from this repository until the external copy
and provenance have been verified. Promotion into the public API still requires
an explicit production decision, maintained tests, and user-facing
documentation.
