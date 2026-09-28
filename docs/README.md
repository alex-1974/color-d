# color-d documentation

This directory separates **user documentation** from **research and evidence**.

Start here:

- [Tutorial: getting started](tutorial/getting-started.md)
- [How-to: convert and adjust colors](how-to/convert-and-adjust.md)
- [How-to: alpha and compositing](how-to/alpha-and-compositing.md)
- [How-to: interpolation and gamut mapping](how-to/interpolate-and-map-gamut.md)
- [How-to: WCAG measurements and tone families](how-to/wcag-and-tones.md)
- [Concepts: color model](concepts/color-model.md)
- [Concepts: extended values and `.init`](concepts/extended-values-and-init.md)
- [Concepts: error and validation model](concepts/error-model.md)
- [Glossary](glossary.md)
- [Accuracy and validation](accuracy-and-validation.md)
- [Architecture](architecture.md)
- [Performance](performance.md)
- [Documentation publication](pages-publication.md)
- [Architecture decision records](adr/)

The user documentation above is intentionally self-contained. A reader should
not need research logs to discover how to use the library.

Detailed research/evidence is engineering material, not consumer-package
documentation. Historical material is still present in this repository during
the migration tracked by #107, but it is export-ignored and is being separated
from the production repository. See [../RESEARCH.md](../RESEARCH.md) for the
repository roles and migration rule.

Accepted architectural decisions and the technical specification remain
maintainer material in the GitHub repository; they are not shipped as part of
the lean consumer archive.
