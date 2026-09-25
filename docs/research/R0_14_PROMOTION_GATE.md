# R0.14 — v0.1 scope and R0→R1 promotion gate

Status: proposed R0 synthesis for issue #10.

This document consumes the validated R0 evidence and defines the intended
production-promotion boundary. Research prototypes remain evidence rather than
production code to copy mechanically.

## 1. Promotion principle

v0.1 should contain the smallest coherent public surface that is both:

1. justified by validated R0 evidence; and
2. relevant to the first real consumers.

A symbol appearing in an early technical-spec candidate list is not by itself
sufficient evidence for promotion.

R0.14 therefore distinguishes:

- **accepted** — part of the intended v0.1 production scope;
- **deferred** — not required for v0.1 and promoted later only with concrete
  evidence or consumer need;
- **rejected as an abstraction** — research found that a proposed abstraction
  is not justified, even though its lower-level component operations may be
  accepted.

## 2. Accepted v0.1 color-value core

Promote:

```text
SRgb!T
LinearSRgb!T
XyzD65!T
Oklab!T
Oklch!T
```

with `T` restricted to:

```text
float
double
```

The public type system continues to distinguish encoded and linear RGB and all
other color spaces.

Accepted convenience aliases should cover the promoted computational types for
both scalar widths, for example:

```d
SRgbf / SRgbd
LinearSRgbf / LinearSRgbd
XyzD65f / XyzD65d
Oklabf / Oklabd
Oklchf / Oklchd
```

`real` is not part of the initial scalar contract. This avoids making the
public numerical/performance contract depend on platform-specific extended
precision.

## 3. Deliberately deferred color/storage types

The following early v0.1 candidates are **deferred**:

```text
SRgb8
SRgba8
Hsl!T
Hsv!T
```

### 3.1 SRgb8 / SRgba8

The imagery boundary establishes that packed color-value types, if promoted,
belong in `color-d`, while pixel format, layout and channel binding belong in
`imagery-d`.

R0 did not, however, validate a production quantization/storage contract for
these packed types. Their inclusion is therefore not required merely because
ownership is settled.

They may be reconsidered after a concrete imagery or editor consumer requires
packed color values and can validate:

- quantization and rounding semantics;
- conversion boundaries;
- alpha/storage semantics;
- interaction with renderer or image APIs.

### 3.2 HSL / HSV

HSL and HSV were present in the early technical specification for legacy/UI
interoperability and conventional color-picker workflows.

The executable R0 research did not promote or validate them as part of the
modern mathematical core, and the first identified consumers are centered on
sRGB, linear-light RGB and Oklab/OKLCH workflows.

They are therefore deferred until a concrete CSS/UI/picker consumer requires
them.

This is a deliberate reduction from the earlier §37 candidate list.

## 4. Accepted conversions and value semantics

Promote explicit, allocation-free conversions among the accepted computational
spaces where the R0 chain establishes them.

Color-space transitions remain visible in source and are not implicit
constructors or generic casts.

UFCS is supported when it is only syntax for the same unambiguous operation,
for example:

```d
encoded.toLinear
linear.toXyzD65
xyz.toOklab
lab.toOklch
```

UFCS must not hide policy choices such as clipping, gamut mapping, hue path,
background selection or accessibility thresholds.

Computational colors preserve finite extended values. They do not automatically
clamp to nominal display ranges.

NaN and infinities remain visible unless a specifically named operation has a
defined special-value contract.

## 5. .init policy

Promoted computational value types shall not redefine `.init` to mean black,
transparent black or another valid color.

The natural floating-point `.init` state is intentionally non-finite and
therefore visibly invalid/uninitialized for semantic use.

This avoids turning default initialization into an implicit color policy.

Operations that require finite/domain-valid input apply their own explicit
contract rather than relying on a globally valid default color.

## 6. Accepted alpha and compositing scope

Promote:

- orthogonal straight-alpha color representation;
- a statically distinct premultiplied representation;
- explicit premultiply/unpremultiply operations;
- reference source-over compositing in premultiplied linear-light sRGB.

Straight and premultiplied states must not be silently interchangeable.

The low-level compositor does not accept encoded sRGB or polar/perceptual color
values as if they were premultiplied linear-light RGB.

Zero-alpha premultiplication may lose hidden straight RGB; this remains an
explicit consequence of the representation.

## 7. Accepted interpolation scope

Promote:

- same-space rectangular interpolation for validated matching color types;
- explicit OKLCH polar interpolation;
- `HuePath` with shorter/longer/increasing/decreasing choices;
- validated alpha-aware interpolation semantics.

Interpolation does not silently choose or convert into a different color space.

Interpolation-specific premultiplication remains distinct from the persistent
premultiplied compositing representation.

No generic policy-heavy "best interpolation" API is introduced for v0.1.

## 8. Accepted measurement scope

Promote:

- WCAG-2 sRGB relative luminance;
- WCAG-2 contrast ratio;
- Oklab `deltaEOK`.

WCAG-2 measurements retain their validated strict finite encoded-sRGB domain.
They are not aliases for general XYZ-D65 Y.

Unresolved alpha is not silently assigned a background.

For checked WCAG results, the compact scalar/NaN validity representation is the
preferred production direction from R0.9. A two-field `{T,bool}` result is not
preferred. Exact public type/function names remain an R3 API-review decision,
not an architectural reopening.

`deltaEOK` remains a direct Oklab distance measurement. It does not imply JND
classification, clipping, gamut mapping or hidden conversion.

No generic public `deltaE` name is introduced.

## 9. Accepted gamut scope

Promote:

- explicit `inGamut` diagnostics;
- explicit hard `clip`;
- explicit perceptual gamut mapping.

Clipping and perceptual mapping remain different operations.

Promote both validated perceptual mapping strategies as explicit initial
methods:

- Local MINDE — perceptual/reference-oriented;
- Ray Trace — bounded-cost/performance-oriented.

No default gamut mapper is frozen for v0.1.

Already-in-gamut values take the identity/fast path.

Per-color gamut mapping does not become image-wide rendering intent; spatial,
raster-wide and image metadata policy remain consumer responsibilities.

EdgeSeeker remains deferred.

## 10. Accepted tone-scale scope

Promote the validated low-level OKLCH tone-scale primitives:

- raw component replacement such as lightness/chroma/hue;
- explicit caller-supplied schedules;
- validated finite interval schedule generation;
- fixed-size array results for compile-time-known cardinality;
- caller-owned slice output for runtime-known cardinality;
- explicit composition with gamut mapping and measurement.

Do not promote:

- a semantic `Palette` type;
- a semantic `Theme` type;
- `PaletteBuilder`;
- `ThemeBuilder`;
- application roles such as accent/warning/selected/road.primary;
- a universal aesthetic tone curve;
- an implicit gamut mapper.

R0.12 found no evidence that such policy-heavy abstractions belong in
`color-d`.

## 11. Numerical and reference policy

The R0.13 property-specific numerical policy is accepted for production tests.

There is no universal library epsilon and no generic public `approxEqual`
utility.

Tests select among exact, classification, independent-reference, derived,
cross-execution and algorithm-specific contracts according to the property.

`float` and `double` are validated separately.

CTFE/runtime equality is not assumed blindly; it is a portability dimension
evaluated through the property's numerical contract.

## 12. Compiler and performance policy

For the initial production phase the explicitly validated compiler references
are:

```text
DMD 2.113.0
LDC 1.43.0 / LLVM 22.1.8
```

No older minimum frontend is promised by R0.14.

The exact published v0.1 support matrix is re-verified during release hardening
and may move to a newer compiler only through deliberate testing.

LDC is the release-performance reference compiler.

Release-critical hot paths are compared, where meaningful, with equivalent
optimized C++ using the same algorithm, scalar type, mathematical semantics,
deterministic inputs, machine and release-oriented flags.

A material unexplained LDC-versus-C++ gap is a release concern.

DMD remains a supported correctness/portability compiler and is not required to
match LDC performance where reproduced evidence isolates the remaining gap to
compiler/code-generation behavior.

Compiler-specific internal optimization is permitted only when:

- public semantics remain common;
- correctness tests remain common;
- CTFE behavior is preserved where promised;
- attributes remain valid;
- numerical behavior is separately validated;
- generated code and performance justify the specialization.

`-ffast-math` is not part of the default release-performance contract.

## 13. Initial production module surface

The earlier module sketch is revised to match validated responsibilities and
the reduced v0.1 scope.

Proposed supported public modules:

```text
source/color/
    package.d

    rgb.d
    xyz.d
    oklab.d
    oklch.d

    alpha.d
    composite.d
    interpolate.d

    gamut.d
    wcag.d
    difference.d
    tone.d
```

### Module ownership

`color.rgb`
: `SRgb!T`, `LinearSRgb!T`, scalar aliases and sRGB transfer conversion.

`color.xyz`
: `XyzD65!T` and accepted RGB/XYZ conversion surface.

`color.oklab`
: `Oklab!T` and accepted XYZ/Oklab conversion surface.

`color.oklch`
: `Oklch!T`, Oklab/OKLCH conversion and raw OKLCH component operations.

`color.alpha`
: straight-alpha and premultiplied value representations plus explicit
  representation transitions.

`color.composite`
: linear-light source-over reference compositing.

`color.interpolate`
: rectangular/polar interpolation and `HuePath`.

`color.gamut`
: gamut diagnostics, explicit clipping and explicit perceptual mapping.

`color.wcag`
: WCAG-2-specific luminance and contrast measurement.

`color.difference`
: explicit perceptual difference operations such as `deltaEOK`.

`color.tone`
: low-level OKLCH tone/schedule primitives.

No `palette.d`, `hsl.d` or `hsv.d` module is part of the initial public
surface.

Implementation-only helpers belong under an internal/package-private boundary
and are not supported direct imports.

## 14. Root and direct imports

`import color;` is the curated convenience entry point and re-exports the
accepted public v0.1 surface.

The directly supported public modules listed above are also valid documented
imports.

A declaration being technically importable from an implementation/helper module
does not make that module part of the supported public contract.

The root surface and direct-module surfaces must be tested independently before
release.

## 15. Naming conventions

Production naming follows:

- PascalCase for public value types and enums;
- lowerCamelCase for functions, properties and enum members;
- explicit semantic names for standards- or policy-specific operations;
- no implicit color-space conversion names;
- no generic names that hide materially different algorithms.

Representative examples:

```text
SRgb
LinearSRgb
XyzD65
Oklab
Oklch
HuePath

toLinear
toXyzD65
toOklab
toOklch

wcag2RelativeLuminance
deltaEOK
inGamut
clip
```

Exact production names may still receive ergonomic review during their owning
R1--R3 implementation issue, but that review may not reopen the accepted
semantics or silently introduce policy.

## 16. Compile-negative strategy

Use compile-negative tests for contracts the D type system is intended to
enforce.

Examples include:

- unsupported scalar types;
- accidental encoded/linear RGB interchange;
- cross-space interpolation without explicit conversion;
- encoded or perceptual values passed to the low-level linear-light
  compositor;
- straight/premultiplied interchange;
- inappropriate premultiplied values passed as ordinary target-space gamut
  coordinates;
- operations instantiated for unsupported color types.

Runtime/domain tests remain appropriate for value-state contracts such as:

- NaN/Inf classification;
- WCAG finite/range validity;
- gamut membership;
- alpha-domain validity where raw representation permits invalid values.

Do not force value-domain policy into the type system where the validated model
deliberately preserves extended mathematical values.

## 17. Consumer stabilization gate

R0 promotion allows R1--R3 production implementation to begin.

It does **not** make the API release-stable.

Before v0.1 publication, both real-consumer gates must close.

### imagery-d — #4

At least one concrete imagery operation must:

- bind image channels/metadata to an unambiguous typed color value;
- invoke a promoted color conversion and/or alpha operation;
- preserve the color-d / imagery-d ownership boundary;
- keep alpha distinct from masks, validity and NoData;
- remain practical for tiled/region-based execution;
- keep per-pixel mathematical work allocation-free;
- exercise supported external imports and call shapes.

Consumer-discovered API friction must be fixed or deliberately documented
before release stabilization.

### OSM editor theme/style — #13

At least one real theme/style path must exercise a meaningful subset of:

- typed colors and explicit conversion;
- OKLCH manipulation;
- tone-scale primitives;
- explicit gamut mapping;
- WCAG measurement;
- perceptual separation where useful;
- CTFE palette/style construction where useful;
- runtime adaptive styling where required.

OSM tags, semantic application roles, GUI-framework concepts, renderer policy
and background-adaptation strategy must remain outside `color-d`.

Again, public API/import friction discovered by the consumer is fixed or
deliberately recorded before release.

## 18. Promotion decision

R0 has produced sufficient architectural evidence for deliberate production
promotion.

Once this decision is merged and the R0 closeout issue is updated:

- #3 may begin the mathematical-core production API;
- #11 may promote the accepted alpha/interpolation scope once required core
  types exist;
- #12 may promote the accepted perceptual/measurement scope once required core
  types exist;
- #4 and #13 remain mandatory pre-release stabilization gates;
- #14 remains the final v0.1 release-hardening/publication gate.

No public API is considered stable merely because R0 closes.

The promotion decision authorizes implementation; real-consumer validation
still has authority to trigger pre-1.0 API correction before publication.
