# Changelog

All notable user-visible changes to `color-d` are recorded here.

The project is pre-1.0. Changes planned for the next release accumulate under
**Unreleased**.

## Unreleased

- added `SRgb8`, an explicit three-byte encoded-sRGB storage value with stable R/G/B byte layout and no implicit computational conversion.
### Added

- explicit D50 CIELAB values with XYZ D65 conversion and linear Bradford
  adaptation;
- Delta E 1976 and CIEDE2000 measurements as separately named generic
  operations, without application thresholds or automatic metric selection;
- model-specific linear-sRGB color-vision-deficiency transforms for Brettel
  1997 dichromacy, Viénot 1999 protan/deutan simulation, and Machado 2009
  protan/deutan severity, without accessibility classification or implicit
  gamut policy.
- prepared CVD transforms for repeated work, with allocation-free
  fixed-cardinality `applyInto` and runtime-sized `tryApplyInto` batch forms;
  Machado severity interpolation can now be performed once per batch through
  the explicit `tryPrepareMachado2009` success channel.
- optimized CVD prepared-batch implementation shape with a centralized
  compiler-family capability gate: LDC snapshots small invariant transform
  state before hot loops, while DMD retains the established member-backed
  path; public API and numerical semantics are unchanged.
- optimized Machado 2009 scalar/preparation codegen by keeping runtime
  reference tables in the consumer scalar type; CTFE, public API, invalid
  severity behavior, interpolation arithmetic, and prepared-batch semantics
  are unchanged.

### Changed

- preparing v0.1.1 as a documentation and maintenance release with no intended
  public numerical-semantic or feature-family expansion;
- strengthened the documentation contract so every public callable has a
  directly associated executable documented-`unittest` example in source;
- rewrote public API reference text around caller intent, inputs, results, and
  visible semantics while keeping implementation rationale in source comments;
- expanded compile-time contract evidence across public overloads for
  `@safe`, `pure`, `nothrow`, and `@nogc` use;
- added a rendered-DDox site validation gate for stable pages and local links;
- clarified non-obvious numerical, compiler, and performance rationale in
  production source comments without changing implementation behavior;
- refreshed repository documentation for the released, DUB-resolvable v0.1.0
  state and the v0.1.1 maintenance scope.

## [0.1.0] - 2026-09-29

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

- Oklab → OKLCH chroma now preserves representable extreme finite magnitudes
  that could previously overflow to infinity or underflow to zero in runtime
  scalar arithmetic, while retaining the former ordinary-path rounding;
- XYZ D65 → Oklab now preserves representable finite results for extreme finite
  XYZ inputs that would otherwise overflow the direct LMS intermediate;
- XYZ D65 → linear-sRGB now avoids the validated extreme finite
  intermediate-overflow cases while retaining direct-path rounding for ordinary
  `float` inputs and using a more accurate dominant-factor evaluation for
  `double`;
- float Local MINDE and Ray Trace mapping retain their validated direct
  internal XYZ-to-linear-sRGB hot path while the public XYZ conversion keeps
  its extreme-finite fallback, recovering the pre-hardening mapping cost
  without changing retained mapper outputs;
- current public feature scope is closed for v0.1; R4 real-consumer validation
  completed successfully with `imagery-d` and the Dunia editor/theme consumer,
  with no provider-side API correction required;
- detailed research, experiments, benchmark evidence, and historical design
  material moved to the `color-d-research` companion repository so production
  GitHub/DUB tag downloads stay lean while provenance remains preserved;
- the tested pre-1.0 toolchain matrix is DMD 2.113.0 and LDC 1.43.0 on
  Ubuntu 24.04 x86-64;
- no older minimum D frontend is currently promised.

### Deferred

- packed `SRgb8` / `SRgba8` values;
- HSL / HSV;
- Display-P3, Rec.2020, CIELAB/LCh, CIEDE2000, Okhsl/Okhsv;
- CSS parsing/serialization, named colors, HDR, ICC/CMYK, and policy-heavy
  Palette/Theme abstractions.

[Unreleased]: https://github.com/alex-1974/color-d/compare/v0.1.0...develop
[0.1.0]: https://github.com/alex-1974/color-d/releases/tag/v0.1.0
