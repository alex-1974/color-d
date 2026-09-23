# R0.9 Results — Relative Luminance and Contrast Semantics

**Status:** PASS
**Date:** 2026-09-23
**Branch:** `research/r0_9-luminance-contrast`

## 1. Scope

R0.9 investigated:

- WCAG 2 relative luminance semantics;
- WCAG 2 contrast-ratio semantics;
- encoded-sRGB versus linear-sRGB computation;
- separation from XYZ-D65 Y;
- valid WCAG input domain;
- extended-range behavior;
- NaN and infinity;
- alpha/compositing boundaries;
- API failure representation;
- CTFE and D attributes;
- float / double behavior;
- DMD / LDC performance and generated code.

No public API is frozen by this experiment.

## 2. Compilers

Validated with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.

Both correctness implementations produced matching observable results.

## 3. WCAG reference invariants

Observed:

```text
black luminance       = 0
white luminance       = 1
black / white contrast = 21

red luminance   = 0.2126
green luminance = 0.7152
blue luminance  = 0.0722
```

The current WCAG sRGB transfer boundary was validated around:

```text
0.04044
0.04045
0.04046
```

The candidate route reusing the R0.2 sRGB decoder matched the independent
WCAG reference path exactly for the generated valid-domain samples:

```text
double max route delta = 0
float  max route delta = 0
```

Conclusion:

> The validated R0.2 sRGB transfer implementation can be reused for WCAG-2
> computation within the normative sRGB domain. A second transfer
> implementation is unnecessary.

## 4. WCAG relative luminance is not XYZ-D65 Y

For the reference encoded color:

```text
sRGB = (0.691, 0.139, 0.259)

WCAG  = 0.108763
XYZ.Y = 0.108779

delta = 1.60212e-05
```

Across 4096 deterministic valid-domain samples:

```text
double max |WCAG - XYZ.Y| = 3.81002e-05
float  max |WCAG - XYZ.Y| = 3.81321e-05
```

This is expected.

WCAG 2 uses its published coefficients:

```text
0.2126
0.7152
0.0722
```

while the validated color-d linear-sRGB / XYZ-D65 transform uses the more
precise CSS Color 4 matrix.

Conclusion:

> WCAG-2 relative luminance and XYZ-D65 Y are distinct operations and must not
> be silently aliased.

## 5. Valid WCAG-2 input domain

The experiment treats a valid WCAG-2 sRGB measurement input as:

```text
finite component values
and
0 <= component <= 1
```

for all three sRGB or linear-sRGB components.

Tested invalid classes:

```text
component < 0
component > 1
NaN
+Infinity
-Infinity
```

for both:

```text
SRgb!double
LinearSRgb!double
```

Observed:

```text
encoded invalid failures = 0
linear  invalid failures = 0
```

Conclusion:

> Standards-facing WCAG operations require explicit domain validation.

## 6. Extended-range behavior

color-d deliberately supports extended color values.

For an encoded negative component:

```text
sRGB = (-0.5, 0, 0)

valid WCAG domain       = false
color-d extended route  = -0.0455051
literal WCAG formula    = -0.00822755
```

The difference exists because R0.2 defines a sign-preserving extended sRGB
transfer outside the normal `[0,1]` domain, while WCAG does not define such an
extension.

For extended linear RGB:

```text
LinearSRgb(1.2, -0.1, 0.5)
raw weighted luminance = 0.2197
```

and an example with negative luminance produced:

```text
luminance = -0.07152
raw contrast vs white = -48.7918
```

Conclusion:

> Mathematical evaluation outside the WCAG domain must not be presented as a
> valid WCAG measurement.

No implicit clipping or gamut mapping is permitted.

## 7. Non-finite behavior

Unchecked arithmetic produced:

```text
NaN  luminance = NaN
+Inf luminance = +Inf
-Inf luminance = -Inf

contrast(NaN,  white) = NaN
contrast(+Inf, white) = +Inf
contrast(-Inf, white) = -0
```

The `-Inf -> -0` contrast case is especially important: relying only on IEEE
propagation can turn an invalid input into an apparently finite scalar.

Conclusion:

> A standards-facing WCAG operation must validate its domain rather than rely
> solely on NaN / infinity propagation.

## 8. Alpha boundary

The experiment compared:

```text
50% black over white
```

resolved through linear-light source-over with a naive encoded 50% gray.

Observed:

```text
resolved linear RGB = (0.5, 0.5, 0.5)

resolved contrast           = 1.90909
naive encoded-gray contrast = 3.97665
```

Conclusion:

> Unresolved alpha does not possess one standalone WCAG contrast ratio.

The actual rendered color must be resolved before measurement.

color-d should not silently infer a background or perform hidden compositing
inside an ordinary WCAG measurement primitive.

## 9. Contrast properties

Generated valid-domain tests covered 4096 deterministic samples for both
`float` and `double`.

Validated:

- encoded candidate equals independent reference path;
- contrast is symmetric;
- identical colors produce ratio 1;
- valid-domain ratio remains within `[1,21]`;
- valid finite input produces finite output.

Observed:

```text
double failures = 0
float  failures = 0
```

## 10. API naming direction

The experiment supports standards-explicit naming.

Preferred research names:

```text
wcag2RelativeLuminance
wcag2ContrastRatio
```

rather than ambiguous generic names such as:

```text
relativeLuminance
contrastRatio
```

Reasons:

- WCAG relative luminance is distinct from XYZ Y;
- WCAG 3 does not currently define a final replacement contrast algorithm;
- future APCA / WCAG-3-style metrics should coexist under separate names.

No public names are frozen yet.

## 11. Threshold-policy boundary

R0.9 does not place policy such as:

```text
AA
AAA
large text
normal text
non-text UI
font size
font weight
```

inside the core color-math measurement.

Those decisions depend on application semantics and belong in a higher-level
accessibility / theme layer.

color-d should provide the scalar standards measurement.

## 12. Failure-representation candidates

Three checked API shapes were compared.

### 12.1 Assertion-only

Rejected as the sole public contract.

Assertions are useful for internal programmer invariants but do not provide a
stable standards-facing runtime-domain result.

### 12.2 `try(..., ref value)`

Validated candidate.

Properties:

- explicit success/failure;
- allocation-free;
- `@safe pure nothrow @nogc`;
- efficient under both DMD and LDC;
- failure leaves the caller's existing output value unchanged.

Disadvantage:

- mutable out parameter;
- weaker value-oriented ergonomics.

### 12.3 `{ value, valid }`

A two-field result type was functionally correct:

```text
float  sizeof = 8
double sizeof = 16
```

but showed a major DMD 2.111 performance pathology for `double`.

It is therefore rejected as the preferred representation.

### 12.4 Compact scalar result

A one-field result type was tested:

```text
CompactWcag2Measurement!float  sizeof = 4
CompactWcag2Measurement!double sizeof = 8
```

Encoding:

```text
finite scalar = valid measurement
NaN           = invalid measurement
```

with `.valid` derived from the scalar state.

This retained value semantics while avoiding the large DMD-double regression.

It is the preferred research candidate.

A future production type must preserve its invariant by controlling
construction; callers must not be able to manufacture arbitrary supposedly
valid measurements outside the defined result domain.

## 13. Performance

Microbenchmarks used:

```text
8192 samples
1000 repetitions
release builds
```

The final comparison used three repeated runs.

Approximate three-run means:

### DMD 2.111

```text
linear unchecked      8.69 ns
linear {T,bool}     165.62 ns
linear try            12.58 ns
linear NaN scalar     20.24 ns
linear compact        21.67 ns

encoded unchecked    203.84 ns
encoded {T,bool}     381.88 ns
encoded try          217.92 ns
encoded compact      217.72 ns

contrast {T,bool}    605.30 ns
contrast compact     435.93 ns
```

### LDC 1.41

```text
linear unchecked      1.15 ns
linear {T,bool}       3.87 ns
linear try            2.79 ns
linear NaN scalar     3.54 ns
linear compact        3.31 ns

encoded unchecked    222.31 ns
encoded {T,bool}     227.21 ns
encoded try          222.25 ns
encoded compact      222.44 ns

contrast {T,bool}    449.05 ns
contrast compact     443.05 ns
```

The encoded path is dominated by sRGB transfer decoding.

For DMD, compact-result and `try` encoded performance are effectively in the
same range.

The compact contrast result is substantially cheaper than the two-field
result under DMD.

## 14. Explicit-inline experiment

`pragma(inline, true)` was applied to the two-field checked candidates.

Observed DMD-double linear performance remained approximately:

```text
~164 ns
```

rather than approaching the `try` or compact candidates.

Conclusion:

> Explicit inlining does not resolve the DMD 2.111 two-field-result pathology.

No production requirement for `pragma(inline, true)` is established by R0.9.

## 15. Generated-code audit

A DMD release binary was inspected with `nm` and `objdump`.

All candidate functions remained available as symbols.

Important call-site observation:

- `tryWcag2RelativeLuminance` had explicit benchmark call sites;
- checked contrast had explicit call sites;
- compact checked contrast had explicit call sites;
- the linear checked relative-luminance benchmark path did not show an
  explicit checked-relative-luminance call site;
- the compact linear checked relative-luminance benchmark path likewise did
  not show an explicit compact-relative-luminance call site.

Therefore the large DMD-double difference between the two relative-luminance
result representations cannot be explained simply as one function failing to
inline while the other succeeds.

The evidence instead points to generated-code / aggregate-representation
effects associated with the `{double,bool}` result shape in DMD 2.111.

This is compiler- and version-specific evidence, not a universal D ABI claim.

## 16. CTFE and attributes

The checked candidates were validated with compile-time evaluation.

Core candidate operations remain compatible with:

```d
@safe
pure
nothrow
@nogc
```

No allocation or exception path is required.

## 17. WCAG 3 / APCA

WCAG 3 remains outside the initial R0.9 implementation scope.

Its contrast model is not treated as a replacement for WCAG 2 in color-d.

Future algorithms should be independently researched and exposed under
separate explicit names.

## 18. Resulting architecture direction

R0.9 supports this separation:

```text
XYZ-D65 Y
    colorimetric coordinate

WCAG-2 relative luminance
    standards-specific sRGB measurement

WCAG-2 contrast ratio
    standards-specific pair measurement

unchecked arithmetic kernel
    internal implementation detail where useful

standards-facing measurement
    validates finite [0,1] domain

compact scalar measurement
    preferred result representation

try(ref)
    retained alternative if later consumer evidence favors it

alpha resolution
    explicit prior rendering/compositing concern

AA / AAA / UI semantic thresholds
    higher-level accessibility/theme policy

WCAG 3 / APCA
    separate future research
```

## 19. R0.9 conclusion

R0.9 passes.

Validated conclusions:

1. WCAG-2 relative luminance is distinct from XYZ-D65 Y.
2. R0.2 sRGB decoding can be reused exactly within the valid WCAG domain.
3. Valid standards-facing input is finite sRGB / linear-sRGB in `[0,1]`.
4. Extended values remain useful color-d mathematics but are not valid WCAG
   measurements.
5. No implicit clipping or gamut mapping occurs.
6. Non-finite values require explicit domain rejection for standards-facing
   measurements.
7. Alpha must be resolved before ordinary contrast measurement.
8. WCAG thresholds remain outside the core color-math primitive.
9. Standards-explicit names are preferred during research.
10. A two-field `{T,bool}` result is rejected because of observed DMD 2.111
    double code generation.
11. A compact scalar/NaN result is the preferred research candidate.
12. `try(..., ref T)` remains a valid performance-oriented alternative.
13. DMD and LDC correctness results agree.
14. CTFE and core no-allocation attributes are viable.
15. No public API is frozen until consumer validation.
