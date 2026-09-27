# Changelog

All notable user-visible changes to `color-d` are recorded here.

The project is pre-1.0. Until the first published release, changes accumulate
under **Unreleased**.

## Unreleased

### Added

- typed computational color spaces for encoded sRGB, linear-light sRGB, XYZ D65,
  Oklab, and OKLCH using `float` or `double`;
- explicit conversion chain between the promoted computational spaces;
- straight-alpha and premultiplied-alpha value types;
- linear-light source-over compositing;
- rectangular and OKLCH polar interpolation with explicit `HuePath`;
- strict sRGB gamut diagnostics, hard clipping, and explicit Local MINDE / Ray
  Trace gamut mapping;
- WCAG 2.2 relative luminance and contrast measurements;
- Oklab `deltaEOK`;
- low-level OKLCH component, schedule, and tone-family primitives;
- CTFE coverage for deterministic core operations where supported;
- public DDox documentation and user-oriented guides.

### Changed

- current public feature scope is closed for v0.1 and is in R4 real-consumer
  validation;
- the tested pre-1.0 toolchain matrix is DMD 2.113.0 and LDC 1.43.0 on
  Ubuntu 24.04 x86-64;
- no older minimum D frontend is currently promised.

### Deferred

- packed `SRgb8` / `SRgba8` values;
- HSL / HSV;
- Display-P3, Rec.2020, CIELAB/LCh, CIEDE2000, Okhsl/Okhsv;
- CSS parsing/serialization, named colors, HDR, ICC/CMYK, and policy-heavy
  Palette/Theme abstractions.

[Unreleased]: https://github.com/alex-1974/color-d/compare/main...develop
