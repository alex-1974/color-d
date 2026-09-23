# R0.9 Research — Relative Luminance and Contrast Semantics

**Project:** `color-d`
**Status:** Research / pre-experiment design
**Date:** 2026-09-23
**Branch:** `research/r0_9-luminance-contrast`
**Base HEAD:** `2783c1bf51205647e865feb3fde73ee31522985a`

## 1. Purpose

R0.9 investigates the semantics, numerical behavior, API boundary and
implementation requirements for relative luminance and contrast in `color-d`.

The work starts after the validated R0.8 gamut-semantics block.

R0.9 must not merely copy one contrast formula into the library. It must
establish which operations belong in the mathematical core, which are
standards-specific policy, which input domains are valid, how alpha is handled,
and how the existing linear-sRGB / XYZ-D65 model interacts with WCAG 2.2.

No public API is frozen by this document.

---

## 2. Inherited color-d decisions

R0.9 inherits the validated architecture from R0.1 through R0.8.

Relevant constraints include:

- color spaces are encoded in types;
- encoded sRGB and linear sRGB are distinct types;
- conversion is explicit;
- extended / out-of-gamut computational values are permitted;
- ordinary conversions do not silently clip or gamut-map;
- NaN and infinity are not silently repaired;
- `float` and `double` remain supported scalar types;
- CTFE is a first-class requirement where practical;
- alpha is represented explicitly;
- premultiplied and straight-alpha representations are distinct;
- compositing is performed in linear light;
- policy-heavy operations should not be hidden inside ordinary conversions;
- consumer requirements should drive later API stabilization.

R0.9 must preserve these rules.

---

## 3. Existing technical-spec direction

The current technical specification already states that:

- relative luminance is derived from linearized sRGB;
- encoded sRGB components must not be inserted directly into the luminance
  formula;
- the initial contrast API may implement WCAG 2.x contrast ratios;
- future accessibility metrics should be separate explicit algorithms rather
  than silently changing the meaning of an existing operation.

R0.9 should validate, refine or revise that direction.

---

## 4. Standards status as of 2026-09-23

### 4.1 WCAG 2.2

WCAG 2.2 is the current stable W3C Recommendation in this research scope.

The latest Recommendation publication is dated 2024-12-12.

For sRGB, WCAG 2.2 defines relative luminance using:

```text
L = 0.2126 R + 0.7152 G + 0.0722 B
```

where each encoded sRGB component is decoded with:

```text
if C_sRGB <= 0.04045:
    C = C_sRGB / 12.92
else:
    C = ((C_sRGB + 0.055) / 1.055) ^ 2.4
```

For two luminances `L1 >= L2`, WCAG 2 contrast ratio is:

```text
(L1 + 0.05) / (L2 + 0.05)
```

For valid sRGB colors this ranges from:

```text
1 : 1
```

to:

```text
21 : 1
```

The older sRGB breakpoint `0.03928` was replaced by `0.04045`; W3C notes that
the practical effect for WCAG calculations is negligible, but `color-d`
should use the current definition.

### 4.2 WCAG 3

WCAG 3 remains an in-progress Working Draft.

The 2026-09-10 Working Draft explicitly states that the contrast algorithm is
still to be determined.

Therefore R0.9 must not treat any current WCAG-3 contrast proposal as a stable
replacement for WCAG 2.2.

### 4.3 APCA and future contrast models

APCA is relevant research context because it has influenced modern contrast
discussion and previous WCAG-3 work.

However, R0.9 should not promote APCA to a normative initial `color-d` API
solely because it is modern or perceptual.

APCA / future WCAG-3 contrast should remain an explicitly named future metric
unless and until:

- a stable standard or concrete consumer requirement exists;
- semantics and reference vectors are independently researched;
- the API can coexist without redefining WCAG-2 behavior.

---

## 5. A critical terminology problem

"Relative luminance" can refer to more than one closely related operation.

R0.9 must distinguish at least:

1. WCAG-2 relative luminance for sRGB;
2. the Y component of an XYZ-D65 conversion;
3. a generic linear-RGB weighted luminance-like quantity;
4. physical photometric luminance, which `color-d` does not know without
   display / scene calibration.

These must not be silently conflated.

---

## 6. WCAG coefficients versus color-d XYZ coefficients

This is a central R0.9 research question.

WCAG 2.2 uses rounded sRGB luminance coefficients:

```text
0.2126
0.7152
0.0722
```

The validated R0.3 linear-sRGB -> XYZ-D65 conversion uses the more precise
CSS Color 4 rational matrix.

Its Y row is:

```text
87098 / 409605
175762 / 245763
12673 / 175545
```

which evaluates approximately to:

```text
0.21263900587151036
0.7151686787677559
0.07219231536073371
```

Therefore:

```text
WCAG2 relative luminance
```

is not numerically identical to:

```text
LinearSRgb.toXyzD65.y
```

for arbitrary colors.

The difference is small, but the semantics are different.

R0.9 must not implement WCAG 2 contrast by silently reusing XYZ Y unless the
experiment explicitly demonstrates and accepts that deviation.

---

## 7. Candidate conceptual split

A likely architecture is to distinguish:

```text
general colorimetric Y
```

from:

```text
WCAG-2 relative luminance
```

Possible concepts:

```d
auto xyz = linear.toXyzD65;
auto y = xyz.y;

auto l = wcag2RelativeLuminance(srgb);
```

or:

```d
auto y = relativeLuminance(linear);
auto l = wcag2RelativeLuminance(srgb);
```

The second form is potentially ambiguous because "relative luminance" is also
the exact WCAG terminology.

R0.9 must investigate naming before freezing anything.

---

## 8. Candidate naming questions

Possible names include:

```d
relativeLuminance
wcagRelativeLuminance
wcag2RelativeLuminance
linearSrgbLuminance
xyzY
wcagContrastRatio
wcag2ContrastRatio
contrastRatio
```

Questions:

- Is `relativeLuminance` sufficiently unambiguous in a general color library?
- Should the standards-specific operation carry `wcag2` in its name?
- Is `contrastRatio` future-proof if WCAG 3 adopts a different contrast model?
- Should a generic name be reserved until multiple contrast metrics exist?

R0.9 should prefer explicit naming over short naming if ambiguity would become
part of the public API.

---

## 9. Encoded sRGB semantics

For encoded sRGB input, WCAG-2 luminance must:

1. inspect each encoded component;
2. decode it using the current sRGB transfer function and breakpoint;
3. apply WCAG-2 luminance weights;
4. return the resulting scalar.

Conceptually:

```d
T wcag2RelativeLuminance(SRgb!T color);
```

The function must not apply:

- clipping;
- gamut mapping;
- alpha compositing;
- quantization;
- implicit conversion through unrelated color spaces.

Whether out-of-range encoded components are accepted is a separate domain
question.

---

## 10. Linear sRGB semantics

A linear-sRGB overload could avoid transfer decoding:

```d
T wcag2RelativeLuminance(LinearSRgb!T color);
```

using the WCAG weights directly.

This raises an architectural question:

Should the function accept any `LinearSRgb!T`, including extended values, or
only target-gamut values?

The mathematical weighted sum works for extended values.

The normative WCAG interpretation does not necessarily do so.

R0.9 should distinguish:

```text
mathematical computability
```

from:

```text
standards-valid WCAG evaluation domain
```

---

## 11. Extended-range problem

`color-d` deliberately permits values such as:

```d
LinearSRgb!double(1.2, -0.1, 0.5)
```

A direct weighted sum can produce values outside `[0, 1]`.

That is mathematically useful in a color pipeline.

However, the WCAG-2 definition describes relative luminance as normalized
between darkest black and lightest white for the sRGB evaluation domain.

If an extended value produces:

```text
L < 0
```

then inserting it into:

```text
(L1 + 0.05) / (L2 + 0.05)
```

may produce a non-WCAG result or even a denominator near zero.

Therefore R0.9 must test at least three possible policies.

### Policy A — unrestricted mathematical primitive

```d
relativeLuminance(LinearSRgb!T)
```

allows extended values.

A separate WCAG operation requires valid sRGB-domain input.

### Policy B — WCAG operation accepts extended values

The function mechanically evaluates the formula even outside the normative
domain.

This is simple but risks giving a standards-looking result that is not a
valid WCAG evaluation.

### Policy C — WCAG operation validates its domain

The WCAG function explicitly requires / diagnoses target-gamut finite colors.

This is semantically stronger but introduces API questions around failure
reporting and runtime checks.

R0.9 should compare these options.

---

## 12. Clipping must remain explicit

R0.8 established that clipping is distinct from conversion and gamut mapping.

R0.9 must preserve that rule.

A WCAG function must not silently transform:

```d
SRgb!T(1.1, 0.4, -0.1)
```

into:

```d
SRgb!T(1.0, 0.4, 0.0)
```

before measuring contrast.

If WCAG evaluation requires in-gamut values, the caller should either:

- provide them;
- explicitly clip;
- explicitly gamut-map;
- or receive a diagnostic / invalid-domain result.

The measurement operation must not hide policy.

---

## 13. NaN and infinity

Inherited numerical policy:

```text
NaN and infinity are not silently repaired.
```

R0.9 should determine the exact scalar behavior.

Possible options include:

### Propagation

```text
relativeLuminance(NaN-containing color) -> NaN
contrast involving NaN -> NaN
```

This is mathematically natural and allocation-free.

### Diagnostic wrapper

A standards-specific checked API might instead return an explicit status.

R0.9 should avoid inventing a heavy result type unless a concrete need exists.

The experiment should at least confirm that no implementation accidentally
converts non-finite input into an apparently valid finite contrast value.

---

## 14. WCAG-2 contrast ratio semantics

For finite valid-domain relative luminances:

```text
L1 = max(a, b)
L2 = min(a, b)

ratio = (L1 + 0.05) / (L2 + 0.05)
```

Important algebraic properties:

```text
contrast(a, a) == 1
contrast(a, b) == contrast(b, a)
contrast(black, white) == 21
ratio >= 1
ratio <= 21
```

The last two bounds only hold for valid `[0,1]` WCAG luminance inputs.

R0.9 should not assert those bounds for unrestricted extended values.

---

## 15. Contrast ratio is a measurement, not a pass/fail policy

WCAG includes thresholds such as:

```text
4.5 : 1
3.0 : 1
7.0 : 1
```

but whether a threshold applies depends on context such as:

- text versus non-text graphical content;
- text size;
- text weight;
- conformance level;
- user-interface semantics;
- exceptions.

Those concepts are not intrinsic properties of two colors.

Therefore the initial `color-d` core should likely provide:

```text
the measured ratio
```

rather than:

```text
passesAA(...)
passesAAA(...)
isAccessible(...)
```

R0.9 should validate this boundary.

Higher-level accessibility / theme code can apply contextual thresholds.

---

## 16. Alpha and rendered color

Contrast is evaluated on rendered appearance, not on an uncomposited straight
alpha foreground tuple.

For example:

```d
Alpha!(SRgb!double)(foreground, 0.5)
```

does not have a single WCAG contrast against an unspecified background.

The actual rendered foreground depends on the background.

This suggests an initial core contract:

```text
WCAG contrast accepts opaque / resolved colors
```

rather than silently compositing alpha.

A convenience operation could later accept:

```text
foreground
background
```

and resolve the foreground before contrast measurement, but this becomes
complex when:

- both foreground and background are translucent;
- there are multiple backing layers;
- compositing color space matters;
- the caller already has rendered output.

R0.9 should prefer a clear primitive boundary.

---

## 17. Alpha compositing order

If an alpha-aware contrast helper is explored, the correct conceptual order is:

```text
encoded input
    ->
decode to linear sRGB
    ->
linear-light alpha compositing
    ->
resolved linear sRGB
    ->
WCAG relative luminance
    ->
contrast ratio
```

It must not:

```text
compute luminance of foreground
then interpolate luminance by alpha
```

unless that equivalence is explicitly derived for the exact operation.

Nor should it composite encoded sRGB components directly.

R0.6 compositing semantics should be reused rather than redefined.

---

## 18. Premultiplied input

A premultiplied color is a compositing representation.

It should not be treated as an ordinary straight RGB color for WCAG
measurement.

Possible policy:

```text
contrast operations do not directly accept Premultiplied!Color
```

unless the type is first resolved / unpremultiplied or composited into an
opaque result through an explicit operation.

Compile-negative tests may be appropriate if the future public type system can
encode this exclusion naturally.

---

## 19. Wide-gamut boundary

R0.9 is initially sRGB-centered.

Display-P3 and Rec.2020 are deferred.

Important distinction:

```text
WCAG 2.2 formula
```

is defined for sRGB in the current reference material.

A future wide-gamut accessibility metric may require:

- conversion into sRGB;
- conversion into XYZ;
- a different standard-defined procedure;
- a future WCAG-3 algorithm.

R0.9 must not invent a generic wide-gamut contrast policy.

The initial API should not pretend that all RGB spaces can use identical
coefficients.

---

## 20. XYZ Y is still useful

The existence of a WCAG-specific metric does not reduce the value of XYZ Y.

`XyzD65!T.y` already represents the colorimetric Y coordinate resulting from
the validated linear-sRGB -> XYZ-D65 conversion.

Consumers may need this quantity for:

- color science;
- future wide-gamut transforms;
- scientific visualization;
- other perceptual or appearance models.

R0.9 should preserve the conceptual separation:

```text
XYZ Y
```

versus:

```text
WCAG-2 relative luminance
```

even if both are numerically close for sRGB.

---

## 21. Difference between WCAG weights and XYZ Y

The experiment should quantify:

```text
abs(wcag2RelativeLuminance(linear) - linear.toXyzD65.y)
```

over representative and generated samples.

Required examples:

```text
black
white
red
green
blue
middle gray
random in-gamut values
extended values
```

This is not to choose a "better" formula.

It is to demonstrate that the operations have different standards semantics
and should not be accidentally aliased.

---

## 22. White and black invariants

For valid sRGB:

```text
black -> 0
white -> 1
```

For WCAG contrast:

```text
black vs black -> 1
white vs white -> 1
black vs white -> 21
white vs black -> 21
```

These should be exact or extremely tight CTFE/runtime invariants depending on
the arithmetic type.

---

## 23. Primary-color reference values

For encoded unit primaries after decoding:

```text
red   -> 0.2126
green -> 0.7152
blue  -> 0.0722
```

for the WCAG-specific operation.

This is intentionally different from the precise XYZ-D65 Y values validated
in R0.3.

The experiment should protect that distinction explicitly.

---

## 24. Transfer-function boundary vectors

R0.9 must test values around the current WCAG breakpoint:

```text
0.04045
```

including at least:

```text
0
0.04044
0.04045
0.04046
1
```

The experiment should compare:

```text
SRgb -> WCAG luminance
```

against:

```text
SRgb.toLinear -> WCAG luminance from LinearSRgb
```

Both routes should agree within a scalar-specific tolerance.

---

## 25. Existing transfer semantics versus WCAG definition

R0.2 validated the library's sRGB transfer semantics for extended values.

R0.9 should determine whether the existing transfer function can be reused
directly for WCAG-2 encoded input.

Questions:

- Does the existing candidate use the exact same breakpoint?
- Does it use a sign-preserving extension outside `[0,1]`?
- If so, is that extension acceptable for a WCAG-specific function?
- Should normative WCAG-domain validation happen before transfer decoding?

The implementation should maximize reuse without erasing standards
boundaries.

---

## 26. API candidate A — standards-explicit

```d
T wcag2RelativeLuminance(T)(SRgb!T color);

T wcag2RelativeLuminance(T)(LinearSRgb!T color);

T wcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b);
```

Advantages:

- future-proof naming;
- clearly standards-specific;
- no ambiguity if WCAG 3 adopts a different model.

Disadvantages:

- longer API names;
- may feel unnecessarily specific for the most common contrast formula.

---

## 27. API candidate B — generic common names

```d
T relativeLuminance(T)(SRgb!T color);

T relativeLuminance(T)(LinearSRgb!T color);

T contrastRatio(T)(
    SRgb!T a,
    SRgb!T b);
```

Advantages:

- concise;
- familiar terminology.

Disadvantages:

- risks conflating WCAG relative luminance with XYZ Y;
- future WCAG-3 or other metrics could make `contrastRatio` ambiguous;
- changing semantics later would be unacceptable.

---

## 28. API candidate C — mixed model

```d
T relativeLuminance(T)(LinearSRgb!T color);

T wcag2RelativeLuminance(T)(SRgb!T color);

T wcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b);
```

This distinguishes a general linear-light scalar from a standards-specific
measurement.

However, the meaning of the generic `relativeLuminance(LinearSRgb)` must be
precisely defined.

R0.9 should not adopt this merely to save characters.

---

## 29. Likely initial recommendation

The current research direction should prefer explicit WCAG naming until the
experiment proves that a shorter generic name is unambiguous.

A strong candidate is:

```d
wcag2RelativeLuminance
wcag2ContrastRatio
```

with XYZ Y remaining available through:

```d
toXyzD65.y
```

This is a hypothesis, not a final decision.

---

## 30. Result type

For valid finite input, the natural result is the scalar type:

```d
float
double
```

Potential signatures:

```d
T wcag2RelativeLuminance(T)(SRgb!T color)
if (isColorScalar!T);

T wcag2ContrastRatio(T)(
    SRgb!T a,
    SRgb!T b)
if (isColorScalar!T);
```

R0.9 should avoid introducing a wrapper type solely for one dimensionless
ratio unless experiment evidence demonstrates a concrete safety benefit.

---

## 31. Mixed scalar types

Should this compile?

```d
wcag2ContrastRatio(
    SRgb!float(...),
    SRgb!double(...));
```

Existing `color-d` direction favors explicit, predictable scalar typing.

Possible rules:

- require identical scalar types;
- provide explicit conversion before comparison;
- infer a common scalar type.

R0.9 should follow the broader library policy rather than create a special
contrast-only coercion rule.

A compile-negative test for mixed scalar types may be appropriate.

---

## 32. CTFE

Required CTFE candidates:

```d
enum black = SRgbd(0, 0, 0);
enum white = SRgbd(1, 1, 1);

enum blackL = wcag2RelativeLuminance(black);
enum whiteL = wcag2RelativeLuminance(white);

static assert(blackL == 0);
static assert(whiteL == 1);

enum bw = wcag2ContrastRatio(black, white);
static assert(...);
```

The experiment must verify both DMD and LDC.

No runtime-only implementation should be accepted if ordinary arithmetic and
the already validated transfer helpers support CTFE.

---

## 33. Attributes

Target attributes for scalar primitives:

```d
@safe
pure
nothrow
@nogc
```

The operations should require:

- no allocation;
- no mutable global state;
- no lookup table for WCAG 2;
- no exception path.

The experiment should confirm attributes with both compilers.

---

## 34. Numerical tolerance

R0.9 should contribute evidence to the later library-wide numerical tolerance
policy without pretending to close the entire subject.

Important categories:

### Exact identities

Potentially exact:

```text
black luminance = 0
white luminance = 1
same-color contrast = 1
black/white contrast = 21
```

Whether exact equality is valid should be tested separately for float and
double.

### Formula-route agreement

Comparing:

```text
encoded route
```

with:

```text
explicit decode -> linear route
```

may need a small scalar-specific tolerance.

### External reference values

Reference vectors may require tolerances due to decimal representation and
published rounding.

R0.9 should record tolerance reasons per assertion rather than adopt one
universal epsilon.

---

## 35. No epsilon in semantic comparisons by default

Contrast ordering:

```text
lighter = max(L_a, L_b)
```

should not require an epsilon.

If luminances compare equal, the ratio is naturally 1.

A numerical epsilon must not silently change which color is treated as
lighter.

This follows the broader R0.8 distinction between mathematical semantics and
numerical tolerance policy.

---

## 36. Performance expectations

The operations are likely cheap compared with gamut mapping.

Expected hot-path work:

### Linear input

```text
3 multiplies
2 additions
min/max or compare
contrast arithmetic
```

### Encoded input

Additional transfer decoding per component.

No benchmark-driven optimization should be added until baseline codegen is
observed.

R0.9 should still inspect:

- basic LDC generated code;
- DMD/LDC runtime sanity;
- whether the three weighted terms compile efficiently;
- whether function composition prevents useful inlining.

This should remain proportionate to the cost of the operation.

---

## 37. SIMD / batch processing

Do not design a SIMD API in R0.9.

`imagery-d` may eventually compute luminance for large pixel batches, but the
first responsibility of `color-d` is the scalar mathematical contract.

If a concrete image consumer later requires batch throughput, benchmark
evidence can motivate:

- vectorized loops;
- SoA representations;
- SIMD helpers;
- consumer-side batching.

No speculative public SIMD surface should be added now.

---

## 38. Reference vectors

The correctness experiment should include at least:

### Encoded sRGB

```text
black
white
red
green
blue
50% encoded gray
several arbitrary in-gamut colors
transfer-boundary colors
```

### Linear sRGB

```text
black
white
primaries
middle linear gray
extended positive values
negative values
NaN
+Inf
-Inf
```

### Contrast pairs

```text
black / white
black / black
white / white
gray / gray
black / gray
white / gray
arbitrary color pairs
reversed pair order
```

---

## 39. External reference strategy

Reference data should come from authoritative or independent sources where
possible.

Primary standards source:

- W3C WCAG 2.2.

Independent calculation may use:

- a small experiment-local formula implemented directly from the W3C
  definition;
- trusted independent color libraries or calculators only as secondary
  cross-checks.

The experiment should not use the production candidate as its own only oracle.

---

## 40. Contrast symmetry

Required property:

```text
contrast(a, b) == contrast(b, a)
```

for valid finite inputs.

This should be tested over generated samples, not merely one pair.

The implementation should structurally enforce symmetry through luminance
ordering rather than depend on test data.

---

## 41. Identity property

Required property:

```text
contrast(a, a) == 1
```

for valid finite sRGB colors.

Generated tests should include:

- dark colors;
- bright colors;
- primaries;
- random colors;
- float and double.

---

## 42. Monotonic cases

For fixed dark luminance `D`, contrast should increase as valid light
luminance increases.

For fixed light luminance `L`, contrast should increase as valid dark
luminance decreases.

The experiment can test representative monotonic sequences.

This is useful for detecting formula/order mistakes.

---

## 43. Alpha experiment

R0.9 should include a small alpha study even if alpha-aware contrast is
deferred.

Example:

```text
50% black foreground
over white background
```

Resolve through the validated R0.6 linear-light compositing path.

Then compare:

```text
contrast(resolved foreground, white)
```

against naive alternatives.

This demonstrates why unresolved alpha cannot have one standalone contrast
ratio.

The result should inform documentation even if no alpha overload is promoted.

---

## 44. Encoded versus linear alpha caveat

A common incorrect implementation composites encoded sRGB and then computes
WCAG luminance.

R0.6 already establishes linear-light compositing.

R0.9 should preserve that architectural rule.

If a future convenience function performs compositing for contrast, it must
reuse the correct compositing model rather than create an accessibility-only
shortcut.

---

## 45. Threshold policy boundary

The following should probably remain outside the initial mathematical
primitive:

```text
AA
AAA
large text
normal text
non-text controls
focus indicators
font-size thresholds
font-weight thresholds
```

Reasons:

- they are contextual policy;
- they can evolve independently of the color formula;
- application/theme layers know semantic role and typography;
- `color-d` should remain useful outside web accessibility.

R0.9 should record this boundary explicitly.

---

## 46. Potential accessibility layer

A future higher-level library or theme module could implement concepts such as:

```d
meetsWcag2TextMinimum(...)
meetsWcag2LargeTextMinimum(...)
meetsWcag2NonTextMinimum(...)
```

Such code would consume:

```d
wcag2ContrastRatio(...)
```

from `color-d`.

This separation keeps mathematical measurement reusable and policy contextual.

---

## 47. Relation to editor themes

Concrete editor/theme consumers may use contrast measurements for:

- text on panels;
- selected-object overlays;
- warning icons;
- topology error markers;
- map labels;
- focus/hover/selection states;
- high-contrast mode.

However, the editor also uses adaptive map overlays where simple WCAG-2
contrast may not capture all visibility requirements.

Therefore `color-d` should provide the metric, not claim that one ratio solves
all map-visibility problems.

---

## 48. Relation to imagery-d

`imagery-d` may eventually need luminance-like computations for:

- visualization;
- normalization;
- diagnostics;
- masks;
- image statistics.

Those are not necessarily WCAG operations.

Therefore the distinction between:

```text
XYZ Y / linear colorimetric values
```

and:

```text
WCAG-2 relative luminance
```

is especially important for workspace architecture.

---

## 49. Experiment structure

Proposed experiment directory:

```text
experiments/r0_9_luminance_contrast/
├── README.md
├── dub.sdl
└── source/
    └── app.d
```

Do not create `RESULTS.md` until DMD and LDC runs have actually been observed.

---

## 50. Candidate experiment-local types

Reuse minimal validated concepts from prior R0 experiments:

```d
SRgb!T
LinearSRgb!T
XyzD65!T
Alpha!Color
Premultiplied!Color
```

The experiment should copy only what it needs.

It must not depend on speculative production modules that do not yet exist.

---

## 51. Candidate experiment functions

At minimum:

```d
wcag2RelativeLuminance(SRgb!T)
wcag2RelativeLuminance(LinearSRgb!T)

wcag2ContrastRatio(SRgb!T, SRgb!T)
wcag2ContrastRatio(LinearSRgb!T, LinearSRgb!T)
```

Additional experiment-only helpers may include:

```d
isValidWcag2SrgbInput(...)
referenceWcag2RelativeLuminance(...)
referenceWcag2ContrastRatio(...)
```

Whether validation helpers become public API is not decided here.

---

## 52. Compare direct versus conversion-based implementation

The experiment should compare at least:

### Direct encoded implementation

```text
decode channels
apply WCAG weights
```

### Reuse linear conversion

```text
SRgb.toLinear
then apply WCAG weights
```

The preferred implementation should avoid duplicate transfer-function logic if
reuse preserves exact semantics and attributes.

---

## 53. Do not implement WCAG via XYZ Y

The experiment should intentionally include a comparator:

```text
linear.toXyzD65.y
```

but only to quantify the difference.

It should not be treated as the WCAG oracle.

This protects against an attractive but semantically incorrect shortcut.

---

## 54. Generated sample tests

Use deterministic generated samples.

Suggested classes:

```text
4096 in-gamut encoded sRGB colors
4096 in-gamut linear sRGB colors
selected extended-range values
```

Properties:

```text
encoded path ≈ decoded-linear path
contrast symmetry
identity ratio = 1
valid-domain ratio in [1, 21]
finite valid input -> finite result
```

Extended inputs should be evaluated separately from normative-domain
properties.

---

## 55. float and double

Both scalar types must be exercised.

Questions:

- Are reference values representable closely enough for exact invariants?
- Does the transfer breakpoint behave consistently?
- What tolerance is necessary for route agreement?
- Does `float` materially improve throughput?
- Is there any reason to specialize coefficients by scalar type?

The expected answer is probably no specialization beyond normal casts, but
R0.9 should measure rather than assume.

---

## 56. Coefficient representation

Potential implementation forms:

```d
cast(T)0.2126
cast(T)0.7152
cast(T)0.0722
```

or decimal literals inferred in `T`.

Unlike R0.3 CSS matrix coefficients, WCAG publishes decimal coefficients
directly.

R0.9 should implement the standard as written rather than replace the
coefficients with the more precise XYZ matrix.

---

## 57. Breakpoint representation

WCAG uses:

```text
0.04045
```

The implementation should ensure comparison is performed in `T`.

For example:

```d
const T cutoff = cast(T)0.04045;
```

The experiment should inspect behavior at adjacent representable `float`
values if necessary.

---

## 58. Contrast offset representation

WCAG uses:

```text
0.05
```

Again, this should be represented directly in the scalar type.

No rationalization or alternative flare constant should be introduced.

The purpose is standards compliance, not re-derivation of the historical
formula.

---

## 59. Exact black-white ratio

For:

```text
L_black = 0
L_white = 1
```

the formula gives:

```text
(1 + 0.05) / (0 + 0.05) = 21
```

The experiment should test whether both `float` and `double` produce exactly
`21` under the chosen representation.

If float rounding prevents exact equality, use a documented tolerance.

---

## 60. Non-finite contrast behavior

Tests should include:

```text
NaN luminance
+Inf luminance
-Inf luminance
```

The experiment should record actual IEEE behavior and ensure no branch
accidentally turns those values into a plausible ordinary ratio.

A public checked API can be considered later if consumer evidence requires
one.

---

## 61. Negative luminance from extended RGB

Construct extended linear RGB values producing:

```text
L < 0
```

Then evaluate the raw formula experimentally.

Do not label the result "valid WCAG contrast".

This test exists to demonstrate why domain semantics matter.

---

## 62. Values above one

Likewise test extended colors producing:

```text
L > 1
```

The raw arithmetic remains defined, but the result falls outside ordinary
WCAG-2 assumptions.

This should help decide whether a checked standards-specific API is useful.

---

## 63. Candidate domain API

Possible future checked form:

```d
struct Wcag2ContrastResult(T)
{
    T ratio;
    bool validInput;
}
```

or:

```d
bool isWcag2SrgbDomain(Color);
```

R0.9 should resist adding such a type unless the experiment demonstrates that
unchecked scalar results are too easy to misuse.

A separate diagnostic helper may be simpler.

---

## 64. Compile-negative tests

Potential negative cases:

```text
WCAG contrast on Oklab directly
WCAG contrast on Oklch directly
WCAG contrast on XyzD65 directly
WCAG contrast on Premultiplied color directly
mixed float/double inputs, if scalar equality is required
```

The type system should encourage explicit conversion rather than infer policy.

---

## 65. No implicit wide-space conversion

This should not compile merely because a conversion exists:

```d
wcag2ContrastRatio(
    Oklab!double(...),
    Oklab!double(...));
```

The caller should explicitly decide how the color reaches the sRGB evaluation
domain.

This mirrors `color-d`'s explicit conversion philosophy.

---

## 66. Reference implementation independence

The experiment should contain a small straightforward W3C formula reference
implementation.

Optimized or reused implementation paths should be compared to it.

This is especially important if the candidate reuses:

```text
SRgb.toLinear
```

because a common bug in the shared transfer path could otherwise go
undetected.

---

## 67. Expected DMD/LDC checks

Both compilers should verify:

- build success;
- runtime reference values;
- CTFE assertions;
- attributes;
- float and double;
- deterministic generated properties;
- no hidden allocation.

If generated code is inspected, LDC native output should be the primary
optimization reference, as in R0.8.

---

## 68. Performance scope

R0.9 performance work should remain smaller than R0.8 unless evidence reveals
a problem.

Minimum:

- benchmark encoded luminance;
- benchmark linear luminance;
- benchmark contrast pair;
- inspect LDC generated code for unnecessary function calls or libm overhead.

No `pow` should remain in a linear-input luminance hot path.

Encoded input may reuse the validated sRGB transfer implementation.

---

## 69. Consumer-sensitive caching

Theme systems may compute contrast during theme construction rather than per
frame.

Therefore even a moderately expensive encoded transfer is unlikely to be a
render-loop blocker for style tokens.

Image-domain consumers may have different throughput requirements.

R0.9 should not optimize the scalar API around an assumed per-pixel workload
without `imagery-d` evidence.

---

## 70. WCAG 3 research boundary

R0.9 should document current WCAG-3 status but not implement its contrast
algorithm because no final algorithm exists in the current Working Draft.

The research conclusion should explicitly state:

```text
WCAG 3 / APCA-like future metrics must use separate names and semantics.
```

A future R-block may investigate them when standards or consumers justify it.

---

## 71. Hypotheses to test

R0.9 should test the following hypotheses.

1. WCAG-2 luminance is distinct from XYZ-D65 Y.
2. Encoded sRGB must be transfer-decoded before luminance weighting.
3. Existing validated sRGB decoding can be reused without semantic drift.
4. Linear-sRGB WCAG luminance requires only the published WCAG weights.
5. Black maps to zero.
6. White maps to one.
7. Unit primaries map to the three published WCAG weights.
8. Black/white contrast is 21.
9. Same-color contrast is 1.
10. Contrast is symmetric.
11. Valid-domain contrast lies in `[1,21]`.
12. Extended values can violate ordinary WCAG-domain assumptions.
13. Clipping must not happen implicitly.
14. NaN/Inf are not silently repaired.
15. Alpha must be resolved against a background before ordinary contrast
    evaluation.
16. Premultiplied color must not be interpreted directly as ordinary RGB.
17. WCAG threshold pass/fail policy belongs above the color-math primitive.
18. `float` and `double` can share one generic implementation.
19. Core functions can remain `@safe pure nothrow @nogc`.
20. Core calculations can run at CTFE.
21. WCAG 3 should remain deferred because its contrast algorithm is not final.
22. A standards-explicit name may be safer than generic `contrastRatio`.

---

## 72. Decisions R0.9 must make

The experiment should end with explicit answers to:

1. What does `relativeLuminance` mean in `color-d`?
2. Is the public operation named generically or `wcag2...`?
3. Does a linear-sRGB overload exist?
4. Are extended values accepted mathematically?
5. Does the WCAG-specific API validate in-gamut input?
6. What happens for NaN/Inf?
7. Are alpha inputs rejected / unsupported directly?
8. Are pass/fail thresholds outside `color-d`?
9. Which exact reference vectors and tolerances are retained?
10. Which operations enter the future R1/R3 production scope?

---

## 73. Explicit non-goals

R0.9 does not attempt to finalize:

- WCAG 3 contrast;
- APCA;
- HDR contrast;
- display-calibrated physical luminance;
- environmental / ambient-light modeling;
- color-vision-deficiency simulation;
- typography-specific accessibility rules;
- automatic AA/AAA policy decisions;
- wide-gamut accessibility formulas;
- image-local adaptive contrast;
- tone mapping;
- image histogram contrast;
- local-contrast enhancement.

---

## 74. Workspace boundary

`color-d` should own:

- scalar sRGB luminance math;
- explicit WCAG-2 contrast measurement if validated;
- standards-specific scalar reference behavior.

Theme / editor layers should own:

- semantic role;
- typography;
- AA/AAA policy;
- UI-state requirements;
- adaptive map-overlay visibility policy.

`imagery-d` should own:

- image traversal;
- batch pixel operations;
- image statistics;
- spatial / local contrast algorithms;
- image-domain rendering decisions.

---

## 75. Proposed experiment sequence

### R0.9-A — formula and type semantics

Implement:

```text
encoded luminance
linear luminance
WCAG contrast
```

Verify:

```text
DMD
LDC
CTFE
attributes
```

### R0.9-B — standards/domain behavior

Test:

```text
breakpoint
extended range
NaN/Inf
alpha boundary
XYZ-Y difference
```

### R0.9-C — generated properties

Test thousands of deterministic colors for:

```text
route agreement
symmetry
identity
valid range
```

### R0.9-D — basic performance/codegen

Measure:

```text
encoded luminance
linear luminance
contrast
float vs double
```

Inspect LDC native assembly only if useful.

---

## 76. Proposed result gate

R0.9 passes when:

- the standards basis is documented;
- WCAG-2 luminance and XYZ Y are explicitly distinguished;
- encoded and linear paths are validated;
- contrast properties are verified;
- extended-domain semantics are documented;
- alpha boundary is explicit;
- DMD and LDC agree within justified tolerances;
- CTFE works;
- attributes are validated;
- naming/API direction is recorded;
- WCAG 3/APCA are explicitly deferred rather than accidentally implied.

---

## 77. References

Primary W3C sources:

- WCAG 2.2 Recommendation:
  https://www.w3.org/TR/WCAG22/

- WCAG 2.2 relative-luminance definition / Understanding material:
  https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum
  https://www.w3.org/WAI/WCAG21/Understanding/relative-luminance.html

- WCAG 2.2 non-text contrast:
  https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast

- WCAG 3 current Working Draft:
  https://www.w3.org/TR/wcag-3.0/

- WCAG 3 introduction / draft status:
  https://www.w3.org/WAI/standards-guidelines/wcag/wcag3-intro/

- WCAG 3 draft text-contrast support:
  https://www.w3.org/WAI/WCAG3/informative/text-and-wording/text-appearance/text-contrast-sufficient-minimum/

Project evidence:

- `docs/spec/TECHNICAL_SPEC.md`
- `ROADMAP.md`
- `experiments/r0_2_srgb_transfer_ctfe/`
- `experiments/r0_3_linear_rgb_xyz/`
- `experiments/r0_6_alpha_compositing/`
- `experiments/r0_8_gamut_semantics/`

---

## 78. Research direction

The strongest current direction is:

```text
colorimetric XYZ Y
    remains available through XYZ-D65

WCAG-2 relative luminance
    standards-specific sRGB measurement

WCAG-2 contrast ratio
    standards-specific pair measurement

WCAG thresholds
    higher-level semantic policy

WCAG 3 / APCA
    separate future research
```

The experiment should now determine the precise API names, input-domain
contract and numerical policy.

No public API is frozen until those hypotheses are validated.
