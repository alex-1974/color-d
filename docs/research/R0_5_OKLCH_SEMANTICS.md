# R0.5 Research — OKLCH and Hue Semantics

**Project:** `color-d`  
**Status:** Research / pre-experiment design  
**Date:** 2026-09-22  
**Branch:** `research/r0_5-oklch-semantics`

## 1. Purpose

R0.5 investigates the semantic model required for:

```text
Oklab!T <-> Oklch!T
```

The mathematical conversion itself is simple.

The difficult questions concern the public representation and behavior of:

- hue;
- chroma;
- achromatic colors;
- angle normalization;
- polar interpolation;
- negative chroma;
- missing or powerless hue.

These decisions should be researched before implementation because they may
affect the long-term `color-d` API more strongly than the conversion matrices
validated in R0.1 through R0.4.

---

# 2. Mathematical basis

OKLCH is the cylindrical representation of Oklab.

Given:

```text
Oklab(L, a, b)
```

the corresponding cylindrical coordinates are:

```text
C = sqrt(a² + b²)

h = atan2(b, a)
```

and the inverse is:

```text
a = C * cos(h)
b = C * sin(h)
```

The coordinate transformation itself introduces no new colorimetry.

The semantic questions arise because hue is circular and becomes ineffective
when chroma is zero or sufficiently close to zero.

---

# 3. Hue orientation

For OKLCH:

```text
  0°  -> positive a axis
 90°  -> positive b axis
180°  -> negative a axis
270°  -> negative b axis
```

Thus:

```text
a = C * cos(h)
b = C * sin(h)
```

when `h` is converted to radians for the trigonometric operations.

This orientation is consistent with the current CSS Color 4 definition of
OkLCh.

---

# 4. Degrees versus radians

## 4.1 Standards and ecosystem evidence

CSS exposes hue in degrees conceptually, while also accepting CSS angle
syntax.

Rust `palette` represents `OklabHue<T>` in degrees for floating-point scalar
types.

It provides explicit conversion to and from radians when needed.

## 4.2 color-d implications

The public/default hue unit should therefore be **degrees**.

Reasons:

- CSS interoperability;
- existing color-library convention;
- human readability;
- natural palette/theme authoring;
- future hue interpolation policies are conventionally described in degrees.

Radians remain the natural internal unit for:

```text
sin
cos
atan2
```

but should not determine the public representation.

### Current design direction

```text
public/storage unit: degrees
internal trig unit:  radians
```

---

# 5. Raw versus normalized hue

Hue is circular:

```text
0°
360°
720°
```

describe the same hue direction.

However, automatically normalizing every stored value can destroy useful
information.

Examples:

```text
20°
380°
740°
```

represent the same final direction but may encode different intended angular
paths.

This matters particularly for:

- animation;
- interpolation;
- explicit increasing/decreasing hue motion;
- debugging;
- round-tripping higher-level representations.

## 5.1 CSS behavior

CSS parsing normalizes a parsed `<hue>` to a canonical angular range.

Hue interpolation then adjusts angles according to the selected method:

- shorter;
- longer;
- increasing;
- decreasing.

The interpolation algorithm may temporarily add or subtract 360° to preserve
the selected path.

CSS parsing semantics therefore should not be confused with the internal
mathematical representation of a color library.

## 5.2 Rust palette behavior

Rust `palette` provides a useful separation:

- the hue object may retain its raw internal angle;
- raw degrees can be retrieved without normalization;
- normalized signed and positive views are available explicitly.

This avoids forcing normalization into storage.

## 5.3 color-d direction

`color-d` should investigate the same conceptual separation.

A hue value should not automatically normalize merely because it is stored.

Instead, normalization should be explicit.

Possible operations:

```d
hue.rawDegrees
hue.positiveDegrees   // [0, 360)
hue.signedDegrees     // (-180, 180]
```

Names remain provisional.

### Current design direction

**Preserve raw hue; normalize explicitly.**

---

# 6. Bare scalar versus dedicated hue type

Three representations are plausible.

## Option A — bare scalar

```d
struct Oklch(T)
{
    T l;
    T c;
    T h;
}
```

Advantages:

- minimal;
- obvious memory layout;
- simplest implementation.

Disadvantages:

- unit is implicit;
- degrees and radians can be mixed accidentally;
- hue-specific operations have no natural type;
- generic scalar arithmetic may accidentally treat hue as linear.

---

## Option B — generic angle/hue wrapper

```d
struct Hue(T)
{
    T degrees;
}
```

Advantages:

- explicit unit;
- reusable across color spaces;
- likely zero storage overhead;
- natural location for wrapping and interpolation helpers.

Disadvantages:

- not all color-space hue concepts have identical semantic orientation;
- an HSL hue and Oklab hue may be mechanically interchangeable despite
  representing different cylindrical spaces.

---

## Option C — color-model-specific hue type

For example:

```d
struct OklabHue(T)
{
    T degrees;
}

struct Oklch(T)
{
    T l;
    T c;
    OklabHue!T h;
}
```

Advantages:

- strong semantic typing;
- explicit unit;
- prevents accidental cross-model hue substitution;
- natural place for normalization and angle conversion;
- follows a design already proven practical by Rust `palette`;
- should retain the same physical representation as one scalar if implemented
  as a simple value wrapper.

Disadvantages:

- additional public type;
- possible type proliferation when HSL/HSV are implemented.

### Current hypothesis

**Option C is the strongest candidate and should be tested experimentally.**

It should not yet be adopted as public API until R0.5 verifies:

- layout;
- ergonomics;
- CTFE;
- conversion code;
- interaction with interpolation.

---

# 7. Achromatic colors

For:

```text
C = 0
```

the hue angle has no effect on the represented Oklab coordinates.

Any hue gives:

```text
a = 0
b = 0
```

Thus hue is mathematically ineffective for an exactly achromatic OKLCH value.

---

# 8. Numerical near-achromatic colors

Floating-point conversion may produce:

```text
a ≈ 0
b ≈ 0
C ≈ very small positive value
```

instead of exact zero.

CSS addresses this using the concept of a **powerless component**.

When a conversion to a polar space produces sufficiently small chroma, hue
may be treated as powerless and represented as missing by CSS.

This behavior is useful for web color interpolation, but it combines several
concepts:

- floating-point tolerance;
- color conversion;
- CSS `none`;
- missing-component interpolation semantics.

These concepts should not automatically be built into the low-level
`color-d` value representation.

### Current design direction

The mathematical core should distinguish:

```text
exact achromatic:
    C == 0

near-achromatic:
    C <= caller/policy supplied epsilon
```

Potential APIs:

```d
color.isAchromatic
color.isNearAchromatic(epsilon)
```

Exact names remain provisional.

A CSS adapter may later apply the CSS-specific epsilon and missing-component
rules.

---

# 9. Missing hue

CSS supports a missing hue component, represented through its general
missing-component semantics.

This is important for operations such as interpolation between:

- an achromatic color;
- a chromatic color.

Instead of inventing an arbitrary hue for the achromatic endpoint, CSS can
carry forward the other hue.

That is useful behavior, but it does not imply that the mathematical
`Oklch!T` type itself must contain an optional hue.

Representing missing hue directly in the core would require mechanisms such
as:

```text
NaN
optional value
tagged value
extra state
```

Each would complicate the currently compact three-component value model.

### Current design direction

Do **not** add missing-component state to `Oklch!T` in R0.5.

The core should represent mathematical numeric OKLCH values.

Missing CSS components belong in a parsing/interpolation representation above
the mathematical core unless a later consumer demonstrates otherwise.

---

# 10. Canonical hue for exact zero chroma

The conversion:

```text
Oklab( L, 0, 0 )
    ->
Oklch( L, 0, ? )
```

still needs a numeric value if `Oklch!T` always stores a numeric hue.

A practical deterministic convention is:

```text
h = 0°
```

for exact:

```text
a == 0 && b == 0
```

This does not claim that the achromatic color physically possesses hue 0°.

It is merely the canonical numerical fallback of the mathematical
representation.

The hue remains ineffective because:

```text
C == 0
```

### Hypothesis for R0.5

Test:

```text
Oklab(L, 0, 0)
    ->
Oklch(L, 0, 0°)
```

while exposing achromaticity separately.

---

# 11. atan2 and near-zero values

For non-zero `a` or `b`, hue naturally derives from:

```text
atan2(b, a)
```

The exact `(0,0)` case should be handled explicitly rather than depending on
the implementation-specific appearance of `atan2(0,0)` in public semantics.

Proposed structure:

```text
if a == 0 && b == 0:
    C = 0
    h = 0°
else:
    C = hypot(a, b)
    h = atan2(b, a)
```

Near-zero but non-zero coordinates should initially remain mathematical
values rather than being silently snapped to achromatic.

Higher-level policies can canonicalize them if required.

---

# 12. Chroma sign

From Oklab:

```text
C = sqrt(a² + b²)
```

so conversion naturally produces:

```text
C >= 0
```

However, manually constructed or intermediate `Oklch!T` values could contain
negative chroma if the type is unrestricted.

Three policies were considered.

## Policy A — silently clamp

```text
C < 0 -> 0
```

Rejected as a core default.

It destroys information and violates the existing `color-d` principle that
mathematical conversions and construction should not silently clamp values.

CSS does clamp negative OkLCh chroma during CSS value resolution, but CSS
parsing behavior is not necessarily appropriate for the mathematical core.

---

## Policy B — forbid negative chroma

Possible approaches:

- constructor validation;
- assertion;
- checked result type.

This establishes a strong invariant but complicates a lightweight
allocation-free computational type.

It also differs from the existing extended-range philosophy used elsewhere
in `color-d`.

---

## Policy C — permit but treat as non-canonical

A negative chroma can be converted without loss:

```text
(L, -C, h)
    ≡
(L,  C, h + 180°)
```

because:

```text
(-C) cos(h) = C cos(h + 180°)
(-C) sin(h) = C sin(h + 180°)
```

This means negative chroma can be accepted as a computational value while a
separate canonicalization operation produces non-negative chroma.

### Current hypothesis

Policy C best matches the existing `color-d` design philosophy.

Potential semantics:

```text
raw Oklch:
    C may be negative

canonical Oklch:
    C >= 0
```

Potential explicit operation:

```d
color.canonicalized
```

which performs:

```text
if C < 0:
    C = -C
    h = h + 180°
```

without changing the represented Oklab color.

This should be tested in R0.5 rather than immediately frozen.

---

# 13. Hue interpolation

CSS defines four useful polar hue paths:

```text
shorter
longer
increasing
decreasing
```

These already match the direction anticipated by the `color-d` technical
specification.

A future API may therefore use something equivalent to:

```d
enum HuePath
{
    shorter,
    longer,
    increasing,
    decreasing
}
```

The interpolation algorithm should adjust endpoint angles according to the
selected path before ordinary scalar interpolation.

This is another reason not to automatically normalize hue storage after every
operation.

---

# 14. Hue normalization operations

R0.5 should investigate at least two explicit normalization forms.

## Positive

```text
[0°, 360°)
```

Examples:

```text
-30° -> 330°
360° ->   0°
390° ->  30°
```

## Signed

```text
(-180°, 180°]
```

Examples:

```text
270°  -> -90°
190°  -> -170°
-190° -> 170°
```

These are views/canonicalizations of the same circular direction.

Raw hue should remain separately accessible.

---

# 15. Lightness and chroma range policy

The same principle already established for RGB should continue.

`Oklab!T` and `Oklch!T` are computational types.

They should not implicitly enforce display-gamut constraints.

Thus values such as:

```text
L < 0
L > 1
large C
```

may exist as intermediate computational values.

Whether an individual operation has useful perceptual meaning for arbitrary
extreme values is a separate numerical question.

CSS parsed-value clamping must not silently become the generic mathematical
core policy.

---

# 16. Candidate representation for the experiment

R0.5 should test:

```d
struct OklabHue(T)
{
    T degrees;
}

struct Oklch(T)
{
    alias Scalar = T;

    T l;
    T c;
    OklabHue!T h;
}
```

Expected physical layout:

```text
Oklch!float  = 12 bytes
Oklch!double = 24 bytes
```

This must be verified on both DMD and LDC rather than assumed.

---

# 17. Candidate hue API

Names remain experimental, but the semantic surface should resemble:

```d
auto h = OklabHue!double.fromDegrees(390.0);

h.rawDegrees       // 390
h.positiveDegrees  // 30
h.signedDegrees    // 30

auto r = h.radians;
```

A negative example:

```d
auto h = OklabHue!double.fromDegrees(-30.0);

h.rawDegrees       // -30
h.positiveDegrees  // 330
h.signedDegrees    // -30
```

Construction should not silently normalize the raw representation.

---

# 18. Candidate conversion semantics

## Oklab -> OKLCH

Conceptually:

```text
C = hypot(a, b)

if a == 0 && b == 0:
    h = 0°
else:
    h = atan2(b, a) converted to degrees
```

Whether conversion output is normalized to `[0,360)` or retains the native
signed `atan2` result must be tested.

### Current preference

Conversion should probably produce a canonical positive hue:

```text
[0°, 360°)
```

because the input Oklab coordinates contain no information about previous
revolutions.

This does **not** require manually constructed `Oklch` values to normalize
their stored hue.

Thus:

```text
conversion output:
    canonical positive hue

raw construction:
    arbitrary finite hue
```

is a coherent model.

---

## OKLCH -> Oklab

Conceptually:

```text
radians = degrees * pi / 180

a = C * cos(radians)
b = C * sin(radians)
```

No hue normalization is mathematically required before `sin` and `cos`.

A negative chroma, if permitted, naturally produces the equivalent Cartesian
coordinates.

---

# 19. CTFE questions

R0.5 must experimentally verify on the current project toolchain:

- `sqrt`;
- `atan2`;
- `sin`;
- `cos`;
- degree/radian conversion;
- hue wrapping;
- exact achromatic handling;
- negative chroma canonicalization.

Target toolchains currently are:

```text
DMD 2.111.0
LDC 1.41.0
  DMD frontend 2.111.0
  LLVM 19.1.7
```

The desired conversion functions should remain:

```text
@safe
pure
nothrow
@nogc
CTFE-capable
```

where the underlying Phobos/runtime implementation permits this.

R0.4 demonstrated that standard-library mathematical functions must not be
assumed to satisfy these requirements merely from their conceptual role.

---

# 20. Proposed R0.5 experiment matrix

The implementation spike should cover at least:

## Layout

```text
OklabHue!float
OklabHue!double
Oklch!float
Oklch!double
```

## Primary axes

```text
Oklab(L, +C, 0) ->   0°
Oklab(L, 0, +C) ->  90°
Oklab(L, -C, 0) -> 180°
Oklab(L, 0, -C) -> 270°
```

## Achromatic

```text
Oklab(L, 0, 0)
```

Expected candidate result:

```text
Oklch(L, 0, 0°)
```

with achromatic state detectable independently.

## Arbitrary colors

Include:

- unit-primary-derived Oklab values from R0.4;
- ordinary reference color;
- extended-range reference color.

## Hue wrapping

Test:

```text
-720°
-390°
-360°
-30°
0°
30°
360°
390°
720°
```

## Negative chroma

Verify equivalence:

```text
Oklch(L, -C, h)
```

and:

```text
Oklch(L, C, h + 180°)
```

after conversion to Oklab.

## Round trip

Test:

```text
Oklab -> Oklch -> Oklab
```

for `float` and `double`.

Also test:

```text
Oklch -> Oklab -> Oklch
```

with the understanding that canonicalization may alter the raw hue
representation while preserving the represented color.

---

# 21. Distinction from CSS semantics

`color-d` should use CSS Color 4 as an important standards reference without
making the mathematical core identical to a CSS parser.

The distinction currently proposed is:

| Concern | `color-d` math core | CSS adapter/parser |
|---|---|---|
| hue storage | raw numeric hue | parsed CSS hue rules |
| default unit | degrees | CSS angle semantics |
| hue normalization | explicit | parsing normalization |
| exact C=0 | numeric hue remains present | hue may become missing |
| near-zero C | explicit epsilon policy | CSS powerless-component epsilon |
| missing hue | not in base `Oklch!T` | supported |
| negative C | possibly raw/non-canonical | clamped during CSS resolution |
| interpolation path | explicit algorithm | CSS-defined policies |

This separation prevents CSS-specific state from contaminating the small
mathematical value types.

---

# 22. Provisional conclusions

The research currently supports these hypotheses for the R0.5 implementation
spike:

1. OKLCH hue uses degrees as its public/default unit.
2. Radians are internal to trigonometric calculations.
3. Hue deserves a dedicated semantic wrapper.
4. `OklabHue!T` is currently a stronger candidate than bare `T`.
5. Raw hue should not normalize automatically on storage.
6. Explicit positive and signed normalization operations should exist.
7. Oklab -> OKLCH should produce a deterministic canonical hue.
8. Exact achromatic conversion should use `h = 0°` as a numeric fallback.
9. Achromaticity must remain separately detectable.
10. CSS missing-hue semantics should not be embedded in the base mathematical
    type.
11. Near-achromatic epsilon handling should be explicit/policy-driven.
12. Conversion from Oklab naturally produces non-negative chroma.
13. Negative manually constructed chroma should be investigated as a valid but
    non-canonical computational representation.
14. Negative-chroma canonicalization should preserve the represented color by
    adding 180° to hue.
15. Polar hue interpolation should support shorter, longer, increasing and
    decreasing paths.
16. R0.5 must verify all relevant trigonometric functions under CTFE on DMD
    and LDC before any API decision is accepted.

---

# 23. Decisions deliberately deferred

R0.5 research does not yet decide:

- final public spelling of `OklabHue`;
- whether another shared angle abstraction exists below hue types;
- whether HSL and HSV use distinct hue types;
- final method/property names;
- exact near-achromatic epsilon;
- NaN/Infinity behavior;
- whether negative chroma remains supported in the final public API;
- final interpolation API;
- serialization behavior;
- CSS parsing representation.

These require either the R0.5 implementation evidence or later concrete
consumers.

---

# 24. Source register

Research basis:

1. **W3C CSS Color Module Level 4**, Candidate Recommendation Draft,
   September 2026.
   Relevant topics:
   - OkLCh definition;
   - powerless components;
   - missing hue;
   - hue parsing;
   - polar hue interpolation;
   - shorter/longer/increasing/decreasing hue paths;
   - negative chroma handling in CSS values.

2. **Rust `palette` 0.7.7** documentation and source.
   Relevant topics:
   - `Oklch<T>`;
   - `OklabHue<T>`;
   - degrees as the floating-point hue unit;
   - raw versus normalized hue access;
   - positive and signed normalized views;
   - Cartesian/polar conversion structure.

3. Existing `color-d` research and executable results:
   - R0.1 type model and CTFE;
   - R0.2 encoded/linear sRGB;
   - R0.3 linear sRGB/XYZ D65;
   - R0.4 XYZ D65/Oklab.

---

# 25. Next step

After this research note is committed, create the executable experiment:

```text
experiments/r0_5_oklch_semantics/
```

The experiment should validate the hypotheses above before any of them are
promoted into an ADR or production module.