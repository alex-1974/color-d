# Research COLOR-LIB 01

**Project:** `color-d`  
**Status:** Baseline research  
**Date:** 2026-09-22  
**Related specification:** `docs/spec/TECHNICAL_SPEC.md`

## 1. Purpose

This document records the research that led to the initial architecture and scope of `color-d`.

It is intentionally different from the technical specification:

- the specification defines the intended project behavior;
- this document records evidence, alternatives, existing implementations, conclusions, and unresolved questions;
- executable experiments under `experiments/` provide implementation evidence for individual architectural hypotheses.

The research is motivated by concrete consumers in the `d-geospatial-workspace`, primarily:

- the planned OSM/geospatial editor;
- `imagery-d`;
- future GUI and rendering layers.

The required functionality includes:

- semantic GUI and map colors;
- perceptual tone and shade generation;
- adaptive contrast;
- correct alpha compositing;
- explicit linear-light operations;
- perceptual interpolation;
- compile-time generation of built-in themes;
- compact representations suitable for rendering infrastructure.

The research question is therefore not merely whether D can represent RGB values.

It is:

> What architecture is appropriate for a modern, type-safe, allocation-free color mathematics library in D?

---

# 2. Initial working hypothesis

The initial hypothesis was that a standalone library is justified if all of the following are true:

1. multiple concrete consumers require the same color mathematics;
2. existing D solutions do not provide the desired modern architecture;
3. correct encoded/linear RGB semantics should be enforced by the type system;
4. Oklab and OKLCH should be first-class working spaces;
5. allocation-free value types can provide both correctness and rendering-oriented performance;
6. D CTFE can be used for palette and theme generation;
7. gamut, interpolation, alpha and range behavior can be made explicit rather than implicit.

Research to date supports this hypothesis.

---

# 3. D ecosystem audit

## 3.1 `std.experimental.color`

An important correction from the initial investigation is that `std.experimental.color` was never part of released Phobos.

A historical Phobos pull request, **dlang/phobos PR #2845 — “Added std.experimental.color”**, was opened in 2015.

The pull request was:

- extensively reviewed;
- eventually closed in 2017;
- not merged.

The current Phobos `std/experimental` tree does not contain a color package.

### Consequence

There is no current Phobos color API that `color-d` needs to preserve or extend.

The historical proposal remains valuable as prior D-specific design work.

---

## 3.2 `TurkeyMan/color`

Repository:

`TurkeyMan/color`

Description:

> Development for std.color

The repository describes itself as the development version of the proposed `std.experimental.color`.

Its DUB package is named `color` and declares the Boost license.

The README lists support for:

- XYZ;
- xyY;
- RGB;
- sRGB;
- gamma and linear RGB;
- custom RGB primaries;
- custom white points;
- custom compression/transfer behavior;
- HSV;
- HSL;
- HSI;
- HCY;
- HWB;
- HCG;
- Lab;
- LCh.

It also provides conversion between the supported spaces.

### Important strengths

The project demonstrates that sophisticated color mathematics can be expressed successfully in D.

Particularly relevant ideas include:

- strongly structured color types;
- generic component types;
- normalized integer representations;
- packed RGB representations;
- reusable RGB color-space descriptions;
- white-point handling;
- chromatic adaptation;
- conversion routing between color spaces;
- allocation-free computation;
- extensive use of `pure`, `nothrow`, `@safe`, and `@nogc`.

The historical package therefore represents substantial engineering work rather than a trivial RGB utility.

### Differences from `color-d`

Its API and architecture reflect an older design generation.

Among the differences relevant to `color-d`:

- conversion can be exposed through `opCast`;
- Oklab and OKLCH are not central types;
- the design predates the present CSS/Oklab ecosystem;
- current project requirements call for an especially strict distinction between encoded and linear RGB;
- `color-d` wants color-space changes to remain explicit at call sites;
- CTFE theme generation is a concrete consumer requirement;
- gamut mapping is intended as an explicit modern policy layer.

### Research conclusion

`TurkeyMan/color` should be treated as the **primary D implementation reference**.

The project should inspect and reuse suitable mathematical or structural ideas rather than blindly redesign everything.

It should not, however, inherit the historical API merely for compatibility.

---

# 4. AuburnSounds `colors`

Repository:

`AuburnSounds/colors`

This is a more recent D project focused on CSS-style color parsing and interchange.

The project uses the Boost Software License 1.0.

Its README describes the project as a work in progress and currently states that only sRGB is supported.

Current features include:

- CSS color parsing;
- `rgb()` / `rgba()`;
- `hsl()` / `hsla()`;
- RGBA8 output;
- RGBA16 output;
- floating-point RGBA output;
- `nothrow`;
- `@nogc`;
- `@safe`.

### Architectural model

AuburnSounds uses a **monomorphic `Color` tagged union** as an interchange representation.

The color space is represented at runtime rather than exclusively through a static D type.

This is appropriate for use cases such as:

- parsing arbitrary CSS colors;
- serialization;
- generic interchange;
- runtime-selected color spaces.

### Comparison with `color-d`

For a mathematical core, `color-d` currently prefers:

```text
SRgb!T
LinearSRgb!T
XyzD65!T
Oklab!T
Oklch!T
```

rather than one tagged runtime `Color`.

These two approaches are not mutually exclusive.

A future parsing/interchange layer could use a dynamic representation while converting into statically typed `color-d` values for mathematical work.

### Research conclusion

A CSS parser should not be implemented prematurely in the `color-d` mathematical core.

AuburnSounds `colors` is an important reference for future CSS interoperability and may represent a useful complementary architecture rather than a competitor that should simply be replaced.

---

# 5. `arsd.color`

Repository:

`adamdruppe/arsd`

Module:

`arsd.color`

`arsd.color` is a mature practical implementation used together with graphics and GUI functionality.

It includes functionality related to:

- colors;
- alpha;
- premultiplication;
- CSS representation;
- pixmaps;
- image and drawing infrastructure;
- Oklab-related functionality.

### Strength

It provides valuable evidence from a real long-lived graphics ecosystem.

It is therefore useful for finding:

- practical API requirements;
- rendering assumptions;
- historical implementation traps;
- interactions between colors and image code.

### Architectural mismatch

`arsd.color` does not attempt to be a narrowly scoped standalone color-mathematics foundation.

The module mixes concerns that `color-d` intends to separate.

The source also contains comments indicating places where gamma/color correctness remains a concern.

### Toolchain consideration

The repository explicitly states that since 1 January 2024 it targets the OpenD programming language.

It no longer promises supported compatibility with the standard D language/toolchain.

### Research conclusion

`arsd.color` is a valuable **consumer and implementation reference**, but is not an appropriate direct base for `color-d`.

---

# 6. D ecosystem conclusion

The D ecosystem contains meaningful prior work, but no currently identified library simultaneously provides the intended combination of:

- static color-space identity;
- explicit encoded versus linear RGB;
- Oklab/OKLCH-centered workflows;
- modern gamut policy;
- orthogonal alpha typing;
- compile-time palette/theme generation;
- narrow mathematical scope;
- conventional DMD/LDC support;
- current `d-geospatial-workspace` engineering requirements.

A new standalone library is therefore justified.

The new implementation should nevertheless reuse knowledge and, where appropriate and license-compatible, implementation techniques from existing D work.

---

# 7. Rust `palette`

Rust `palette` is currently the strongest external reference for the **type model**.

Relevant characteristics include:

- separate concrete color-space types;
- generic scalar types;
- Oklab;
- OKLCH;
- linear RGB;
- encoded RGB;
- XYZ;
- HSL/HSV;
- compile-time-known color-space semantics;
- C-compatible layout on relevant value types.

For example, `Oklab<T>` is represented as a three-component typed value.

## 7.1 Alpha

The particularly relevant design is the generic:

```text
Alpha<Color, T>
```

rather than duplicating every color-space type into separate opaque and alpha-bearing structures.

Rust `palette` also provides a distinct premultiplied-alpha representation.

### Architectural implication

This strongly supports investigating:

```d
Alpha!Color
Premultiplied!Color
```

or equivalent D types.

The R0.1 experiment has since demonstrated that such a wrapper is compact in D as well.

## 7.2 Out-of-range conversion

`palette` also distinguishes between ordinary conversions and fallible/range-aware conversion.

Its fallible conversion model can report that a result lies outside the defined range while preserving the computed unclamped value.

### Architectural implication

This supports separation of:

```text
conversion
gamut/range test
clipping
gamut mapping
```

instead of treating conversion as implicit normalization.

---

# 8. Color.js

Color.js is a strong implementation reference for modern web color mathematics.

Relevant areas include:

- broad modern color-space support;
- interpolation;
- Delta-E methods;
- gamut detection;
- gamut mapping;
- CSS-oriented behavior.

It is especially useful as an independent numerical oracle during development.

### Research conclusion

Color.js should be used primarily as:

- an implementation comparison;
- a reference for test vectors and behavior;
- evidence of practical modern color workflows.

It should not define the `color-d` API.

Where Color.js documentation and the current CSS specification differ, the current normative specification should take precedence for standards behavior.

---

# 9. Oklab and OKLCH

Björn Ottosson introduced Oklab as a perceptual color space intended to behave well for image-processing tasks such as:

- perceived-lightness operations;
- saturation/chroma manipulation;
- smooth interpolation.

The reference implementation provides direct linear-sRGB/Oklab conversion formulas.

The published matrices were updated in 2021 using higher-precision sRGB/D65 values.

The reference implementation is deliberately simple and suitable for translation to other languages.

### Architectural significance

Oklab satisfies several concrete `color-d` consumer requirements:

- perceptual interpolation;
- perceptual color difference;
- manipulation of perceived lightness;
- palette generation.

OKLCH adds a polar representation useful for:

- tone scales;
- controlled chroma;
- hue preservation;
- semantic palette generation;
- gamut mapping.

### Research conclusion

Oklab and OKLCH should be first-class public spaces, not optional peripheral extensions.

---

# 10. CSS Color Module Level 4

The current CSS Color Level 4 specification is one of the most useful modern architectural references.

It defines or uses, among others:

- sRGB;
- linear-light sRGB;
- XYZ;
- Lab/LCh;
- Oklab/OKLCH;
- Display-P3;
- additional RGB spaces;
- explicit interpolation spaces;
- premultiplied-alpha interpolation;
- gamut mapping.

## 10.1 Extended RGB values

The CSS reference algorithms use extended transfer functions.

For sRGB:

- negative values are preserved through a reflected/sign-preserving transfer function;
- values are not conceptually limited to `[0,1]` during mathematical conversion.

### Architectural implication

Computational:

```text
SRgb!T
LinearSRgb!T
```

must not inherently clamp their values.

This distinction is essential:

```text
toSRgb()
```

is a conversion.

It is not:

```text
clip()
```

and it is not:

```text
gamutMap()
```

---

# 11. Gamut mapping

The current CSS Color Level 4 specification describes three SDR RGB gamut-mapping algorithms:

1. Binary Search with Local MINDE;
2. EdgeSeeker;
3. Ray Trace.

All three aim primarily at constant-lightness, constant-hue chroma reduction in OKLCH.

### Architectural implication

The `color-d` API should not encode one gamut algorithm into the meaning of an ordinary color conversion.

Instead, gamut mapping should be an explicit policy operation.

Potential model:

```text
inGamut()
clip()
gamutMap(method)
```

### Candidate for investigation

Ray Trace is particularly interesting for the intended GUI/editor use because it is designed as a fast geometric approach without requiring a large external lookup table.

This is currently a **research candidate**, not an accepted public-API commitment.

---

# 12. Alpha and interpolation

CSS Color 4 distinguishes alpha interpolation behavior carefully.

For non-opaque colors, interpolation operates on premultiplied values.

For rectangular color spaces, color components are premultiplied.

For cylindrical/polar spaces, the hue angle itself is not premultiplied.

### Architectural implication

Two concepts must not be conflated:

1. alpha compositing;
2. interpolation of colors that happen to have alpha.

A generic premultiplied representation is useful, but individual algorithms still require color-space-specific semantics.

A universal naive “RGBA interpolation” operation should therefore be avoided.

---

# 13. Interpolation space

No single interpolation space is correct for every purpose.

Research supports distinguishing at least:

- encoded sRGB for compatibility behavior;
- linear-light RGB for physical/light-like arithmetic;
- Oklab for perceptually smoother interpolation;
- OKLCH where polar hue/chroma semantics are useful.

### Architectural implication

A low-level operation can naturally interpolate two values of the same type:

```text
interpolate(a, b, t)
```

The selected color-space type then makes the semantics explicit.

Higher-level convenience functions may be added later.

---

# 14. HSL and HSV

HSL and HSV remain useful despite not being perceptually uniform.

Concrete uses include:

- CSS interoperability;
- familiar color-picker interfaces;
- legacy workflows.

They should not be used internally as the preferred basis for:

- perceptual tone scales;
- theme generation;
- perceptual lightening/darkening;
- perceptually uniform interpolation.

### Research conclusion

Both remain useful public utility spaces, but Oklab/OKLCH form the perceptual core.

---

# 15. XYZ

XYZ D65 is useful as more than a hidden implementation detail.

It provides a common connection point for:

- sRGB;
- Oklab;
- future Display-P3;
- future Rec.2020;
- standards test vectors;
- scientific interoperability.

### Research conclusion

`XyzD65!T` should remain a candidate public core type.

R0.3 will experimentally validate its representation and conversion path.

---

# 16. CIELAB and LCh

CIELAB/LCh remain standards-relevant and are implemented by historical D color work as well as modern web color systems.

However, supporting them properly introduces additional concerns, including D50 workflows and chromatic adaptation.

No current first consumer requires these capabilities.

### Research conclusion

CIELAB/LCh should not drive the initial implementation.

The architecture must leave room for them, but they remain deferred until a concrete consumer or interoperability requirement appears.

---

# 17. CTFE as an architectural capability

A key project-specific requirement is the ability to generate built-in GUI themes during compilation.

Potential compile-time work includes:

```text
semantic seed colors
    ↓
OKLCH tone generation
    ↓
chroma policy
    ↓
gamut mapping
    ↓
contrast analysis
    ↓
state variants
    ↓
final packed/linear representations
```

This can allow Light, Dark and High-Contrast themes to become static immutable data rather than runtime-generated structures.

CTFE is therefore not merely a micro-optimization.

It enables:

- declarative theme definitions;
- compile-time palette generation;
- compile-time validation;
- zero theme-generation startup cost;
- deterministic built-in theme data.

---

# 18. Experimental evidence: R0.1

Experiment:

`experiments/r0_1_type_model_ctfe`

Status:

**PASS**

Tested with:

- DMD debug build;
- LDC release build;
- x86_64.

Observed layouts:

| Type | Size | Alignment |
|---|---:|---:|
| `SRgb!float` | 12 | 4 |
| `SRgb!double` | 24 | 8 |
| `Oklch!float` | 12 | 4 |
| `Oklch!double` | 24 | 8 |
| `Alpha!(SRgb!float)` | 16 | — |
| `Alpha!(SRgb!double)` | 32 | — |
| `Premultiplied!(LinearSRgb!float)` | 16 | — |

The experiment demonstrated:

- distinct color-space value types are practical;
- generic `float`/`double` structures are practical;
- no unexpected storage overhead was observed for simple three-component types;
- generic alpha wrapping is compact;
- a distinct premultiplied type is practical;
- `@safe pure nothrow @nogc` functions can participate in CTFE;
- a complete compound theme structure can be generated at compile time.

### Research implication

The proposed static type model and CTFE strategy are technically viable on both tested compilers.

---

# 19. Experimental evidence: R0.2

Experiment:

`experiments/r0_2_srgb_transfer_ctfe`

Status:

**PASS**

Tested with:

- DMD debug build;
- LDC release build;
- x86_64.

The experiment implemented encoded sRGB ↔ linear-light sRGB using the extended sign-preserving transfer functions.

Observed examples:

```text
-0.5
    → -0.214041...
    → -0.5

0.5
    → 0.214041...
    → 0.5

1.2
    → 1.516837...
    → 1.2
```

The standard transfer boundary was also exercised.

The experiment demonstrated:

- real color mathematics works at CTFE;
- `std.math.pow` works in the tested CTFE paths;
- negative computational RGB values can be preserved;
- values above `1` can be preserved;
- conversion does not require implicit clipping;
- `float` and `double` implementations are practical;
- tested round trips succeed on DMD and LDC.

### Research implication

The extended computational RGB model is not merely theoretical.

It has now been demonstrated in D with the intended compiler/toolchain model.

---

# 20. Current architecture supported by research

The accumulated evidence currently supports the following direction:

```text
Storage
────────────────────
SRgb8
SRgba8


Computational
────────────────────
SRgb!T
LinearSRgb!T
XyzD65!T
Oklab!T
Oklch!T
Hsl!T
Hsv!T


Orthogonal concerns
────────────────────
Alpha!Color
Premultiplied!Color
```

with:

- explicit conversions;
- no implicit color-space casts;
- no automatic clamp during mathematical conversion;
- explicit gamut operations;
- correct linear-light compositing;
- perceptual operations centered on Oklab/OKLCH;
- CTFE support as a tested execution mode.

This remains an architecture under research, not yet a frozen public API.

---

# 21. Initial v0.1 direction

Research currently supports investigating the following as the initial core:

- `SRgb8`;
- `SRgba8`;
- `SRgb!T`;
- `LinearSRgb!T`;
- `XyzD65!T`;
- `Oklab!T`;
- `Oklch!T`;
- `Hsl!T`;
- `Hsv!T`;
- explicit conversions;
- alpha wrapper;
- premultiplied-alpha representation;
- source-over compositing in linear light;
- relative luminance;
- WCAG-style contrast ratio;
- interpolation;
- hue interpolation policy;
- `deltaEOK`;
- gamut testing;
- explicit clipping;
- an initial perceptual gamut-mapping implementation;
- OKLCH tone-scale primitives;
- CTFE tests.

This list remains subject to validation through the R0 research series.

---

# 22. Deferred functionality

The following should not be implemented merely for completeness:

- Display-P3;
- Rec.2020;
- CIELAB/LCh;
- CIEDE2000;
- Okhsl/Okhsv;
- CSS parsing/serialization;
- named colors;
- HDR;
- ICC processing;
- CMYK;
- printer color management;
- color-vision-deficiency tooling;
- scientific palette collections;
- GPU API adapters.

They should be added only when supported by concrete consumers or standards requirements.

---

# 23. Open research questions

The following questions remain unresolved.

## Type/API model

- final names of public types;
- final aliases;
- whether `real` is supported;
- constructor and validation policy;
- component naming conventions;
- UFCS versus free-function balance;
- exact conversion API.

## Alpha

- final `Alpha` representation;
- final premultiplied type;
- whether alpha scalar type must match the color scalar;
- interaction between alpha and storage formats;
- exact compositing API.

## Angles and polar color spaces

- raw scalar degrees versus a dedicated hue type;
- normalization policy;
- behavior of undefined hue at zero chroma;
- negative chroma construction policy.

## Numerical behavior

- precise `float` tolerances;
- precise `double` tolerances;
- NaN policy;
- infinity policy;
- exact boundary-testing policy;
- cross-compiler numerical comparison.

## Gamut

- public target-gamut representation;
- first perceptual gamut-mapping algorithm;
- suitability of CSS Ray Trace for the initial implementation;
- clipping API;
- treatment of very large extended values.

## CTFE

- CTFE behavior of the complete XYZ/Oklab/OKLCH path;
- trigonometric operations required by OKLCH;
- cost of compile-time gamut mapping;
- compile-time generation of larger tone tables;
- build-time impact of full theme generation.

## Performance

- generated code for scalar conversions;
- inlining behavior;
- auto-vectorization;
- array/batch operations;
- whether future SIMD/batch APIs should remain separate from scalar color types.

---

# 24. Next experiment

The next planned experiment is:

```text
R0.3 — Linear sRGB ↔ XYZ D65
```

The experiment should investigate:

- public `XyzD65!T` representation;
- current high-precision D65 matrices;
- `float` and `double`;
- extended-range preservation;
- reference values;
- round-trip error;
- CTFE;
- DMD/LDC agreement;
- allocation-free scalar implementation;
- generated code.

The intended progression is:

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

Each layer should be validated before the next is introduced.

---

# 25. Research rules going forward

Research for `color-d` should follow these rules:

1. distinguish standards requirements from implementation choices;
2. distinguish existing-library behavior from recommendations for `color-d`;
3. preserve links between conclusions and executable experiments;
4. test against more than one independent reference where practical;
5. test DMD and LDC;
6. test both runtime and CTFE paths where CTFE is part of the intended contract;
7. avoid freezing public API during R0;
8. avoid adding color spaces or algorithms without a concrete reason;
9. inspect historical D work before inventing D-specific mechanisms;
10. document rejected alternatives when they materially affect future design.

---

# 26. Source register

The following sources formed the initial research baseline.

## D ecosystem

**S1 — TurkeyMan/color**

GitHub repository, README, package metadata and source.

Relevant for:

- historical `std.experimental.color` development;
- D-specific generic color architecture;
- supported color spaces;
- Boost licensing;
- allocation-free implementation patterns.

**S2 — dlang/phobos PR #2845**

“Added std.experimental.color”.

Relevant for:

- historical Phobos proposal;
- review history;
- confirmation that the proposal was closed without merge.

Current `dlang/phobos/std/experimental` was also inspected to confirm that no color package is present.

**S3 — AuburnSounds/colors**

GitHub repository, README, package metadata and source.

Relevant for:

- current D CSS-color work;
- monomorphic/tagged `Color` architecture;
- CSS parsing;
- BSL-1.0 licensing;
- current WIP status.

**S4 — adamdruppe/arsd**

Repository README and `color.d`.

Relevant for:

- practical graphics/color usage;
- alpha/pixmap integration;
- Oklab-related implementation experience;
- current OpenD support policy.

## External libraries

**S5 — Rust `palette`**

Current crate documentation.

Relevant for:

- statically typed color spaces;
- generic scalar types;
- Oklab/OKLCH;
- `Alpha<Color, T>`;
- premultiplied alpha;
- range-aware conversion.

**S6 — Color.js**

Current documentation.

Relevant for:

- modern color-space implementation;
- interpolation;
- gamut mapping;
- independent numerical comparison.

## Standards and mathematical references

**S7 — W3C CSS Color Module Level 4**

Current W3C specification.

Relevant for:

- extended RGB transfer functions;
- linear versus encoded RGB;
- interpolation;
- Oklab/OKLCH;
- premultiplied-alpha interpolation;
- gamut mapping;
- wide-gamut architecture.

**S8 — Björn Ottosson, “A perceptual color space for image processing”**

Oklab definition and reference implementation.

Relevant for:

- Oklab motivation;
- conversion equations;
- reference matrices;
- intended perceptual properties;
- implementation validation.

---

# 27. Current research conclusion

The original project hypothesis remains supported.

A new `color-d` library is justified, but it should not ignore the substantial historical D work already available.

The strongest current design direction is:

> A small, statically typed, allocation-free color mathematics library whose types make color-space semantics explicit, whose conversions preserve mathematically useful extended values, whose physical operations use linear light, whose perceptual workflows are centered on Oklab/OKLCH, and whose deterministic core remains usable both at runtime and during CTFE.

R0.1 and R0.2 have already provided executable evidence that the fundamental D type model, compact representation, extended-range RGB behavior, and CTFE strategy are viable.

The public API remains intentionally unfrozen until the remaining architecture experiments have exercised the full initial conversion chain and at least one real consumer.