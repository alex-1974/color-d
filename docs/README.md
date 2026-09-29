# color-d documentation

This directory contains the documentation that a package user needs to
understand and use color-d. It is shipped with the consumer archive.

The current released package is `v0.1.0`; current `develop` documentation also
contains documentation and maintenance improvements planned for `v0.1.1`.

## Start here

If this is your first time using color-d, follow this path:

1. [Tutorial: getting started](tutorial/getting-started.md)
2. [Concepts: color model](concepts/color-model.md)
3. [How-to: convert and adjust colors](how-to/convert-and-adjust.md)
4. [How-to: alpha and compositing](how-to/alpha-and-compositing.md)
5. [How-to: interpolation and gamut mapping](how-to/interpolate-and-map-gamut.md)
6. [How-to: WCAG measurements and tone families](how-to/wcag-and-tones.md)

## Understand the model

Use these pages when you need to understand why the API behaves the way it
does:

- [Extended values and `.init`](concepts/extended-values-and-init.md)
- [Error and validation model](concepts/error-model.md)
- [Glossary](glossary.md)
- [Architecture](architecture.md)

## Check numerical and performance expectations

- [Accuracy and validation](accuracy-and-validation.md)
- [Performance](performance.md)

## API reference

The generated DDox API reference is built from the same public declarations and
documented `unittest` examples that CI compiles and runs.

The repository homepage is:

<https://github.com/alex-1974/color-d>

## What is intentionally not in the consumer package

Research logs, experiment drivers, compiler reproducers, raw performance
evidence, repository CI, ADR history, release-engineering notes, and the full
technical specification are maintainer material. They are intentionally kept
out of the consumer archive.

A package user should not need research history to discover the normal API
path. If you are contributing to color-d, use the production GitHub repository
for maintainer and research pointers.
