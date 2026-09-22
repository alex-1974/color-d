# R0.7 Research — Interpolation Semantics

**Project:** `color-d`  
**Status:** Research / pre-experiment design  
**Date:** 2026-09-22  
**Branch:** `research/r0_7-interpolation-semantics`

## 1. Purpose

R0.7 investigates interpolation semantics for `color-d`.

It builds directly on:

- R0.5 — OKLCH and hue semantics;
- R0.6 — alpha and premultiplied-alpha semantics.

The central questions are:

- how same-space interpolation should behave;
- how rectangular and polar color spaces differ;
- how hue paths should be represented;
- how raw/unbounded hue interacts with interpolation;
- how exact and near-achromatic colors should behave;
- how alpha-aware interpolation should work;
- how interpolation premultiplication differs from compositing
  premultiplication;
- whether interpolation should allow extrapolation;
- whether extended/out-of-gamut values remain unclipped;
- which operations can remain `@safe pure nothrow @nogc` and CTFE-capable.

No public API is frozen by R0.7.

---

# 2. Existing color-d direction

The technical specification already states that no single interpolation space
is universally correct.

Different spaces represent different semantics:

```text
SRgb
    encoded/gamma-domain interpolation

LinearSRgb
    linear-light RGB interpolation

Oklab
    rectangular perceptual interpolation

Oklch
    polar lightness/chroma/hue interpolation
```

The low-level operation should therefore act on values that are already in the
intended interpolation space.

Conceptually:

```d
interpolate(a, b, t)
```

should not silently convert between color spaces.

---

# 3. Explicit interpolation space

The caller should select interpolation semantics through the types supplied to
the operation.

For example:

```d
interpolate(
    LinearSRgb!double(...),
    LinearSRgb!double(...),
    0.5
);
```

means linear interpolation in linear-light sRGB.

Likewise:

```d
interpolate(
    Oklab!double(...),
    Oklab!double(...),
    0.5
);
```

means rectangular interpolation in Oklab.

A higher-level convenience API may later convert colors into an explicitly
selected interpolation space.

The low-level primitive should not do this implicitly.

---

# 4. Rectangular interpolation

For rectangular coordinates:

```text
A = (a1, a2, ... an)
B = (b1, b2, ... bn)
```

ordinary component interpolation is:

```text
result_i = ai + (bi - ai) * t
```

Equivalent form:

```text
result_i = (1 - t) * ai + t * bi
```

For R0.7, this should be tested first on:

```text
LinearSRgb!T
Oklab!T
```

The operation should preserve the type:

```text
LinearSRgb -> LinearSRgb
Oklab      -> Oklab
```

---

# 5. Encoded sRGB

Encoded sRGB is also mathematically interpolable component-wise.

However, its semantics are different from linear-light interpolation.

Therefore:

```d
interpolate(
    SRgb!T,
    SRgb!T,
    t
)
```

may be a valid low-level same-space operation.

It must not be described as physically linear light interpolation.

This distinction should remain explicit through the static type.

R0.7 should determine whether the generic rectangular primitive naturally
supports encoded `SRgb!T` without special cases.

---

# 6. No automatic clipping

Interpolation must not automatically clip component values to nominal display
ranges.

Examples such as:

```text
LinearSRgb(-0.2, 1.3, 0.5)
```

are valid computational colors.

Interpolation between extended-range colors should preserve the mathematical
result even when components remain below zero or above one.

Gamut testing, clipping and gamut mapping remain separate operations.

This follows the existing `color-d` extended-range policy.

---

# 7. Interpolation factor

The ordinary interpolation factor is:

```text
t
```

with the conventional interval:

```text
0 <= t <= 1
```

where:

```text
t = 0 -> first endpoint
t = 1 -> second endpoint
```

R0.7 should also investigate:

```text
t < 0
t > 1
```

as extrapolation.

## Current hypothesis

The low-level mathematical primitive should probably not clamp `t`.

Therefore:

```text
interpolate(a, b, -0.25)
interpolate(a, b, 1.25)
```

may remain well-defined extrapolation.

A higher-level consumer may impose a `[0, 1]` policy.

This matches the broader `color-d` principle of separating representation and
mathematical operations from policy-driven clipping.

The spike must validate whether this remains useful and unsurprising.

---

# 8. Endpoint properties

R0.7 should test:

```text
interpolate(a, b, 0) == a
interpolate(a, b, 1) == b
```

where exact floating-point equality is naturally expected.

It should also test:

```text
interpolate(a, a, t) == a
```

for representative finite `t`.

---

# 9. Oklab interpolation

Oklab is rectangular:

```text
L
a
b
```

so ordinary component-wise interpolation is sufficient.

No hue policy is required.

This makes Oklab the simpler perceptual interpolation space.

R0.7 should establish it as a reference against which OKLCH behavior can be
compared.

---

# 10. OKLCH interpolation

OKLCH has:

```text
L
C
h
```

where `h` is angular.

`L` and `C` can be interpolated linearly.

Hue requires a path decision.

Naive interpolation such as:

```text
350° -> 10°
```

must not automatically mean:

```text
350 -> 180 -> 10
```

when the intended path is the short 20° route through 0°.

Therefore OKLCH requires explicit hue-path semantics.

---

# 11. CSS hue paths

The current CSS model defines four hue interpolation methods:

```text
shorter
longer
increasing
decreasing
```

These should be investigated as the primary standardized policies.

Candidate `color-d` representation:

```d
enum HuePath
{
    shorter,
    longer,
    increasing,
    decreasing
}
```

Exact public naming remains provisional.

---

# 12. Shorter hue path

`shorter` selects the smaller angular distance between the two hues.

Example:

```text
350° -> 10°
```

should travel:

```text
350 -> 360/0 -> 10
```

for a total displacement of:

```text
+20°
```

not:

```text
-340°
```

Likewise:

```text
10° -> 350°
```

should normally travel:

```text
-20°
```

---

# 13. Longer hue path

`longer` selects the complementary angular path.

For:

```text
350° -> 10°
```

the longer path has a displacement of:

```text
-340°
```

instead of:

```text
+20°
```

This is useful for deliberate full-spectrum transitions.

---

# 14. Increasing hue path

`increasing` requires hue to move in the positive angular direction.

Examples:

```text
30° -> 90°
```

uses:

```text
+60°
```

while:

```text
350° -> 10°
```

uses:

```text
+20°
```

and:

```text
90° -> 30°
```

uses:

```text
+300°
```

---

# 15. Decreasing hue path

`decreasing` requires hue to move in the negative angular direction.

Examples:

```text
90° -> 30°
```

uses:

```text
-60°
```

while:

```text
10° -> 350°
```

uses:

```text
-20°
```

and:

```text
30° -> 90°
```

uses:

```text
-300°
```

---

# 16. The 180-degree ambiguity

When two normalized hues differ by exactly:

```text
180°
```

the shorter and longer arcs have equal magnitude.

Example:

```text
30° -> 210°
```

R0.7 must determine a deterministic direction consistent with the chosen
reference semantics.

This should not be left to accidental floating-point comparison behavior.

The experiment should include both endpoint orders:

```text
30 -> 210
210 -> 30
```

and verify deterministic results.

---

# 17. Equal hues

If normalized hue directions are equal:

```text
30° -> 30°
```

ordinary interpolation should remain at 30°.

However R0.5 permits raw/unbounded hue values.

Thus:

```text
30° -> 390°
```

creates an important distinction:

```text
same normalized direction
different raw angle
```

R0.7 must determine whether a standard `HuePath` operation should preserve the
extra revolution or intentionally normalize it away.

---

# 18. Raw hue interpolation

Color.js provides an additional `raw` hue interpolation mode.

Conceptually:

```text
30° -> 390°
```

with raw interpolation gives a full positive revolution.

The midpoint is:

```text
210°
```

rather than remaining near 30°.

This aligns with the R0.5 decision that raw/unbounded hue may preserve
revolution information while a value remains polar.

## Open design question

Should `color-d` represent this as:

```d
HuePath.raw
```

or should raw interpolation be a separate lower-level primitive?

Potential designs include:

```d
interpolateHueRaw(a, b, t)
```

or:

```d
enum HuePath
{
    raw,
    shorter,
    longer,
    increasing,
    decreasing
}
```

R0.7 should test both conceptual models before freezing an API.

---

# 19. Raw versus normalized hue

The distinction is:

```text
raw hue:
    preserves stored angular displacement

path-adjusted hue:
    chooses a semantic arc based on normalized direction
```

For example:

```text
start = 30°
end   = 390°
```

raw interpolation sees:

```text
delta = +360°
```

whereas `shorter` sees equivalent endpoint directions and may produce:

```text
delta = 0°
```

This distinction is intentional and must not be hidden.

---

# 20. Hue adjustment before interpolation

A useful implementation model is:

```text
1. inspect start and end hues
2. choose/adjust the end hue according to HuePath
3. interpolate ordinary scalar degrees
4. preserve raw result until explicit normalization is requested
```

For example:

```text
350 -> 10, shorter
```

may internally become:

```text
350 -> 370
```

Then ordinary interpolation at:

```text
t = 0.5
```

produces:

```text
360
```

The result may remain raw `360°`.

Its positive normalized view is:

```text
0°
```

This fits the R0.5 `OklabHue!T` model.

---

# 21. Do not normalize every interpolated hue

Automatic normalization of every intermediate result would discard useful path
information.

For animation or generated ramps:

```text
350
355
360
365
370
```

is often more informative than:

```text
350
355
0
5
10
```

Therefore the current hypothesis is:

> hue-path adjustment selects the path, while raw storage preserves the
> interpolated angular trajectory.

Normalized views remain explicit.

---

# 22. Achromatic OKLCH

For:

```text
C == 0
```

hue has no effect on the represented Cartesian color.

R0.5 deliberately retained a numeric hue rather than introducing an optional
or missing hue into the mathematical core.

Interpolation now requires a policy for such powerless numeric hue.

---

# 23. One achromatic endpoint

Consider:

```text
A = Oklch(L1, 0, h1)
B = Oklch(L2, C2, h2)
```

where:

```text
C2 > 0
```

Using the arbitrary stored `h1` to determine the interpolation path may create
an unintended hue sweep.

A more useful mathematical interpolation policy is likely:

```text
borrow the hue of the chromatic endpoint
```

before performing polar interpolation.

Conceptually:

```text
A.h := B.h
```

for interpolation purposes only.

The stored source value remains unchanged.

R0.7 should validate this behavior.

---

# 24. Two achromatic endpoints

If both endpoints have:

```text
C == 0
```

hue has no visible effect.

Possible deterministic policies include:

1. interpolate the stored numeric hues anyway;
2. preserve the first hue;
3. use a canonical zero hue.

The choice affects later interpolation if chroma becomes nonzero through other
operations.

## Current hypothesis

The low-level value model should remain deterministic without inventing
missing-component semantics.

R0.7 should test whether raw interpolation of the stored hues is preferable to
special canonicalization.

No final decision is made before the spike.

---

# 25. Near-achromatic colors

R0.5 distinguished:

```text
exact achromatic:
    C == 0

near-achromatic:
    |C| <= epsilon
```

The core must not silently classify near-zero chroma as achromatic using a
hidden epsilon.

Therefore R0.7 should distinguish:

```text
interpolate exact mathematical values
```

from an optional future policy such as:

```text
interpolate(..., achromaticEpsilon)
```

or a higher-level preprocessing step.

The initial low-level operation should probably special-case only exact
zero-chroma values.

---

# 26. Negative chroma

R0.5 showed that negative chroma can be represented as a non-canonical
computational value and canonicalized through:

```text
(-C, h) -> (C, h + 180°)
```

Interpolation raises another question:

Should raw negative-chroma OKLCH values be interpolated directly, or
canonicalized first?

## Current hypothesis

Polar interpolation should probably operate on canonical chroma/hue values.

Otherwise chroma crossing zero can make hue semantics difficult to interpret.

R0.7 should explicitly test:

```text
positive C -> positive C
negative C -> positive C
positive C -> negative C
```

and compare:

```text
raw interpolation
```

against:

```text
canonicalize endpoints first
```

This decision remains open.

---

# 27. Alpha-aware interpolation

R0.6 established that straight alpha and compositing premultiplication are
distinct concepts.

Interpolation adds a third operation:

```text
interpolation premultiplication
```

When alpha is present, naive interpolation of straight colors can allow hidden
RGB/color coordinates from transparent endpoints to influence visible
intermediate colors.

Therefore alpha-aware interpolation should generally use premultiplied color
coordinates.

---

# 28. Rectangular alpha interpolation

For a rectangular color:

```text
Color = (x, y, z)
alpha = a
```

the interpolation representation is:

```text
(x*a, y*a, z*a, a)
```

The two premultiplied endpoint vectors are then interpolated component-wise.

After interpolation:

```text
if alpha != 0:
    divide color coordinates by alpha
```

This applies naturally to:

```text
SRgb
LinearSRgb
Oklab
```

as interpolation mathematics.

Whether encoded sRGB premultiplied interpolation is desirable is a semantic
choice of interpolation space, not a compositing claim.

---

# 29. Polar alpha interpolation

For OKLCH:

```text
L
C
h
alpha
```

alpha premultiplication should affect:

```text
L
C
```

but not:

```text
h
```

Conceptually:

```text
(L * alpha, C * alpha, h, alpha)
```

The hue path is first made meaningful independently of alpha and then the
appropriate coordinates are interpolated.

This is fundamentally different from multiplying every stored scalar by
alpha.

---

# 30. Interpolation premultiplication is not the R0.6 compositing type

R0.6 validated:

```d
Premultiplied!(LinearSRgb!T)
```

as the reference representation for Porter-Duff compositing.

R0.7 must not automatically reuse:

```d
Premultiplied!Color
```

as a universal interpolation representation.

Reasons:

- Oklch hue is not alpha-scaled;
- encoded sRGB may be a legitimate interpolation space but not the reference
  compositing space;
- Oklab interpolation may premultiply all coordinates;
- interpolation premultiplication may be purely an implementation stage rather
  than a durable public value type.

## Strong hypothesis

Interpolation-specific premultiplication should initially remain internal to
the interpolation operation.

---

# 31. Transparent hidden color

R0.6 demonstrated:

```text
straight red, alpha 0
straight blue, alpha 0
```

retain different hidden colors.

For interpolation, premultiplication should prevent those hidden colors from
incorrectly affecting intermediate visible colors.

R0.7 should explicitly test:

```text
opaque red -> transparent blue
```

and compare:

```text
straight component interpolation
```

against:

```text
premultiplied interpolation
```

The latter should be the alpha-aware reference result.

---

# 32. Zero interpolated alpha

When interpolated alpha is exactly zero, dividing by alpha is impossible.

A deterministic policy is required.

CSS interpolation semantics keep the premultiplied components when alpha is
zero rather than dividing.

`color-d` should research whether this rule is the best mathematical behavior
for interpolation.

This must remain separate from R0.6 unpremultiplication for compositing values,
where canonical transparent black was chosen.

The two operations have different purposes and need not share identical
zero-alpha behavior.

---

# 33. Alpha endpoints

R0.7 should test at least:

```text
1 -> 1
1 -> 0
0 -> 1
0 -> 0
0.25 -> 0.75
```

for both rectangular and polar color interpolation.

---

# 34. Hue plus transparency

A critical polar case is:

```text
A:
    L = ...
    C = ...
    h = 30°
    alpha = 0

B:
    L = ...
    C = ...
    h = 210°
    alpha = 1
```

Hue should not be numerically multiplied by zero.

R0.7 should verify that:

```text
h = 30° * 0
```

never appears as an interpolation rule.

Hue-path semantics and alpha semantics remain orthogonal.

---

# 35. Missing components

CSS supports missing color components such as:

```text
none
```

and defines special carry-forward behavior during interpolation.

The current `color-d` mathematical types do not model missing components.

For example:

```d
Oklch!T
```

always stores numeric:

```text
L
C
h
```

R0.7 should not introduce optional/missing coordinates merely to copy CSS.

A future CSS parser/adapter can add these semantics above the mathematical
core.

---

# 36. Powerless components

CSS also defines cases where a component is mathematically powerless.

The important example for R0.7 is hue at zero chroma.

`color-d` can support the underlying mathematics without importing the whole
CSS missing-component model.

Thus the initial core distinction remains:

```text
stored numeric hue
+
knowledge that hue has no effect when C == 0
```

Interpolation may borrow a chromatic endpoint hue as an explicit mathematical
policy.

---

# 37. Interpolation and gamut

Interpolation and gamut mapping must remain independent.

The pipeline should conceptually be:

```text
select interpolation space
        ↓
convert endpoints explicitly if required
        ↓
interpolate
        ↓
obtain mathematical result
        ↓
optional explicit gamut test/map/clip later
```

Not:

```text
interpolate
        ↓
silently clamp each result
```

This is important for both imagery and theme generation.

---

# 38. CTFE

R0.7 should test interpolation during compile time.

Candidate compile-time use cases include:

```text
tone ramps
theme colors
semantic palettes
static gradients
validation fixtures
```

The core functions should target:

```text
@safe
pure
nothrow
@nogc
```

where feasible.

---

# 39. `float` and `double`

All core interpolation cases should be tested with:

```text
float
double
```

Tolerance policy should remain operation- and scalar-specific.

Hue-path selection itself should preferably use deterministic comparisons and
not depend on an arbitrary global epsilon.

---

# 40. Compile-negative checks

R0.7 should investigate compile-time rejection of semantically ambiguous calls.

Examples:

```text
interpolate(
    SRgb,
    LinearSRgb,
    t
)
```

should not compile as a low-level same-space operation.

Likewise:

```text
interpolate(
    Oklab,
    Oklch,
    t
)
```

should not compile.

OKLCH interpolation may require a hue policy overload or a documented default.

Compile-negative tests should verify that type mismatch cannot trigger hidden
conversion.

---

# 41. Default hue path

CSS uses:

```text
shorter
```

as the default hue interpolation policy.

This is also the most common general-purpose expectation.

## Current hypothesis

If `color-d` offers:

```d
interpolate(
    Oklch!T a,
    Oklch!T b,
    T t
)
```

without an explicit hue policy, it may use:

```text
shorter
```

However an equally defensible API is to require explicit:

```d
interpolate(a, b, t, HuePath.shorter)
```

at the low level.

R0.7 should compare ergonomics and misuse resistance before selecting one.

---

# 42. Candidate low-level API shapes

Rectangular:

```d
interpolate(a, b, t)
```

Polar:

```d
interpolate(a, b, t, HuePath.shorter)
```

Possible hue primitive:

```d
interpolateHue(a, b, t, path)
```

Possible raw primitive:

```d
interpolateHueRaw(a, b, t)
```

Alpha-aware:

```d
interpolate(
    Alpha!Color a,
    Alpha!Color b,
    t
)
```

Exact naming and overload structure remain provisional.

---

# 43. Candidate implementation layers

A useful internal decomposition may be:

```text
scalar lerp
    ↓
rectangular color interpolation
    ↓
hue adjustment
    ↓
polar interpolation
    ↓
alpha-aware interpolation
```

This keeps each semantic step independently testable.

Potential conceptual helpers:

```d
lerpScalar
hueDelta
adjustHueForPath
interpolateHue
interpolateRectangular
interpolatePolar
interpolateAlpha
```

These are research names only.

---

# 44. Reference test vectors

R0.7 should include deterministic vectors for:

## Rectangular

```text
0 -> 1
-0.2 -> 1.4
```

at:

```text
t = 0
0.25
0.5
0.75
1
```

## Hue shorter

```text
350 -> 10
10 -> 350
30 -> 90
```

## Hue longer

```text
350 -> 10
10 -> 350
```

## Hue increasing

```text
350 -> 10
90 -> 30
```

## Hue decreasing

```text
10 -> 350
30 -> 90
```

## Tie

```text
30 -> 210
210 -> 30
```

## Raw

```text
30 -> 390
390 -> 30
-30 -> 330
```

## Achromatic

```text
C=0 -> C>0
C>0 -> C=0
C=0 -> C=0
```

## Alpha

```text
opaque -> opaque
opaque -> transparent
transparent -> opaque
partial -> partial
```

---

# 45. Properties to test

R0.7 should test mathematical properties where appropriate.

For ordinary rectangular interpolation:

```text
interpolate(a, b, 0) = a
interpolate(a, b, 1) = b
interpolate(a, a, t) = a
```

Reversal property:

```text
interpolate(a, b, t)
≈
interpolate(b, a, 1 - t)
```

This may depend on hue-path semantics for polar spaces and therefore must be
tested per policy rather than assumed universally.

---

# 46. Path reversal

Hue paths have interesting reversal behavior.

For example:

```text
shorter
```

should normally reverse naturally when endpoint order is reversed.

However:

```text
increasing
```

does not simply become the same geometric trajectory under endpoint reversal.

Its reversed counterpart corresponds to:

```text
decreasing
```

R0.7 should document these relationships explicitly.

---

# 47. Raw hue information loss

Conversion:

```text
Oklch -> Oklab -> Oklch
```

necessarily loses extra hue revolutions.

Therefore raw interpolation should only promise to preserve stored revolution
information while values remain in the polar representation.

This is consistent with R0.5.

No API should imply that revolution history survives arbitrary color-space
conversion.

---

# 48. Consumer relevance

Interpolation is directly relevant to:

## imagery-d

Potential future uses:

- opacity transitions;
- image visualization ramps;
- blending/transition stages;
- color transform previews.

`imagery-d` should consume the mathematical interpolation semantics rather
than define its own general color interpolation.

## OSM/editor styling

Potential uses:

- state transitions;
- hover/selection animation;
- adaptive style generation;
- semantic tone ramps;
- light/dark theme derivation.

Application semantics remain outside `color-d`.

---

# 49. Questions deliberately deferred

R0.7 does not yet decide:

- gradient container APIs;
- gradient stop storage;
- easing functions;
- spline interpolation;
- Bézier color interpolation;
- temporal animation APIs;
- CSS parsing;
- CSS `none` representation;
- dynamic color-space selection;
- gamut mapping during gradient generation;
- perceptual uniformity guarantees for arbitrary ramps;
- GPU interpolation;
- SIMD/batch interpolation.

These require separate evidence or consumers.

---

# 50. Strong hypotheses entering the spike

R0.7 should test the following as strong hypotheses:

1. Interpolation space must remain explicit.
2. Matching rectangular types can use ordinary component-wise interpolation.
3. Low-level interpolation should not silently convert color spaces.
4. Low-level interpolation should not automatically clip color values.
5. `t` should probably remain unclamped and therefore support extrapolation.
6. Oklab interpolation is rectangular.
7. OKLCH requires explicit hue-path semantics.
8. CSS-compatible hue paths should include:
   - shorter;
   - longer;
   - increasing;
   - decreasing.
9. R0.5 raw hue storage justifies investigating raw hue interpolation.
10. Hue adjustment should occur before scalar interpolation.
11. Interpolated raw hue need not be normalized automatically.
12. Exact zero-chroma endpoints require explicit hue treatment.
13. Near-achromatic behavior should not use a hidden epsilon.
14. Alpha-aware interpolation should use premultiplied coordinates.
15. Polar hue must not be multiplied by alpha.
16. Interpolation premultiplication should not automatically reuse the R0.6
    compositing representation.
17. Out-of-gamut/extended-range intermediate colors must survive interpolation.
18. Core interpolation should target CTFE and
    `@safe pure nothrow @nogc`.

---

# 51. Experiment plan

Create:

```text
experiments/r0_7_interpolation_semantics/
```

The spike should implement only enough type structure to test the research
questions.

It should include:

```text
dub.sdl
README.md
source/app.d
```

`RESULTS.md` must only be written after DMD and LDC runs have been observed.

The experiment should test:

- rectangular interpolation;
- Oklab interpolation;
- hue-delta/path adjustment;
- OKLCH interpolation;
- raw hue interpolation;
- exact achromatic cases;
- negative-chroma interaction;
- alpha-aware rectangular interpolation;
- alpha-aware OKLCH interpolation;
- zero-alpha behavior;
- extended-range values;
- extrapolation;
- float/double;
- CTFE;
- compile-negative mismatched-space calls.

---

# 52. Source register

Primary standards/reference sources:

1. **W3C CSS Color Module Level 4**
   - interpolation color spaces;
   - rectangular versus polar interpolation;
   - shorter/longer/increasing/decreasing hue paths;
   - alpha premultiplication rules;
   - polar hue exclusion from alpha premultiplication;
   - missing/powerless component model.

2. **Color.js**
   - explicit interpolation-space selection;
   - CSS-style hue paths;
   - additional raw hue mode;
   - explicit premultiplied interpolation option.

3. **Rust palette**
   - typed color spaces;
   - `OklabHue<T>`;
   - generic alpha attachment;
   - established same-space mixing concepts.

4. **Rust color**
   - explicit color-space layouts;
   - hue direction;
   - premultiplied and unpremultiplied interpolation structures.

5. Existing `color-d` research:
   - R0.1 through R0.6;
   - `docs/spec/TECHNICAL_SPEC.md`;
   - `docs/research/R0_5_OKLCH_SEMANTICS.md`;
   - `docs/research/R0_6_ALPHA_SEMANTICS.md`.

---

# 53. Conclusion

R0.7 should treat interpolation as an explicit mathematical operation in a
known color space.

The current preferred conceptual model is:

```text
rectangular spaces:
    component-wise interpolation

polar spaces:
    component interpolation
    +
    explicit hue-path adjustment

alpha:
    interpolation-specific premultiplication

gamut:
    preserved during interpolation
    and handled separately
```

The critical architectural distinction is:

> Premultiplication for interpolation is an algorithmic interpolation step,
> not automatically the same public representation as premultiplied alpha for
> Porter-Duff compositing.

R0.7 must validate that distinction experimentally before the production API
is designed.