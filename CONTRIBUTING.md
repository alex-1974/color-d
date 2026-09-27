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

## Numerical changes

Do not introduce a library-wide epsilon. Follow the property-specific numerical
policy in [docs/accuracy-and-validation.md](docs/accuracy-and-validation.md).

Numerically significant algorithm changes should preserve provenance and
validation evidence. Performance changes must not weaken public semantics.

## Safety

Public APIs should remain `@safe` where reasonably possible. New
`@trusted` code requires a narrow scope and a concise safety justification.

## Research

Research evidence may live under `docs/research/` and `experiments/`.
Research is not automatically production scope. Promotion into the public API
requires an explicit decision and verification.
