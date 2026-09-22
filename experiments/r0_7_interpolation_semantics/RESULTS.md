# R0.7 Results — Interpolation Semantics

**Project:** `color-d`  
**Stage:** R0.7  
**Status:** PASS  
**Research:** `docs/research/R0_7_INTERPOLATION_SEMANTICS.md`  
**Experiment:** `experiments/r0_7_interpolation_semantics/`

## 1. Summary

R0.7 validates the proposed interpolation architecture for `color-d`.

The experiment passed with:

- DMD debug build;
- LDC release build.

Both compiler runs produced the same displayed results.

The experiment validates:

- explicit same-space interpolation;
- rectangular interpolation for typed color spaces;
- unclamped interpolation factors and extrapolation;
- preservation of extended-range values;
- CSS-style polar hue paths;
- separation of normalized/path-based hue interpolation from raw hue interpolation;
- exact-achromatic hue handling without a hidden epsilon;
- canonicalization of negative chroma before polar interpolation;
- alpha-aware interpolation through interpolation-specific premultiplication;
- distinct rectangular and polar alpha behavior;
- zero-alpha handling without division by zero;
- `float` and `double`;
- CTFE;
- compile-negative rejection of mismatched color spaces;
- compile-negative requirement for an explicit OKLCH hue path in the tested API.

No production API is frozen by this experiment.

---

## 2. Initial compile correction

The first DMD and LDC builds exposed one experiment-code error.

The function:

```d
Oklch!T canonicalized(Oklch!T color)
if (ColorScalar!T)
```

incorrectly used `T` without declaring the function as a template.

It was corrected to:

```d
Oklch!T canonicalized(T)(Oklch!T color)
if (ColorScalar!T)
```

After this correction both compilers built and executed the experiment successfully.

This was an experiment implementation error, not a failure of the researched interpolation model.

---

## 3. Layout

Observed layouts:

```text
SRgbf:          12
SRgbd:          24

OklabHuef:       4
OklabHued:       8

Oklchf:         12
Oklchd:         24

Alpha!Oklchf:   16
Alpha!Oklchd:   32
```

The hue wrapper therefore introduces no storage overhead beyond its scalar.

`Alpha!Oklch` retains the expected compact value layout.

---

## 4. Rectangular interpolation

Test:

```text
A = LinearSRgb(-0.2, 0.2, 1.2)
B = LinearSRgb( 1.4, 0.8,-0.2)
t = 0.5
```

Observed:

```text
LinearSRgb(0.6, 0.5, 0.5)
```

This confirms ordinary component-wise interpolation for rectangular color spaces.

No clipping occurred despite extended-range endpoint values.

### Result

PASS.

Rectangular same-space interpolation can be represented as scalar interpolation of the corresponding coordinates.

---

## 5. Extrapolation

Observed:

```text
0 -> 1, t=-0.25
    -> -0.25

0 -> 1, t=1.25
    -> 1.25
```

For the RGB vector:

```text
t=-0.25:
LinearSRgb(-0.25, -0.25, -0.25)

t=1.25:
LinearSRgb(1.25, 1.25, 1.25)
```

### Result

PASS.

The low-level mathematical interpolation primitive does not need to clamp `t` to `[0,1]`.

This naturally provides extrapolation and is consistent with the existing `color-d` policy of separating mathematical operations from clipping policy.

A higher-level consumer may constrain `t` if required.

---

## 6. Extended-range preservation

R0.7 confirms the existing `color-d` extended-range policy.

Interpolation does not implicitly:

- clamp RGB components;
- gamut-map;
- normalize display values.

Intermediate and final mathematical results may remain:

```text
< 0
> 1
```

### Result

PASS.

Gamut testing, clipping and gamut mapping remain separate operations.

---

## 7. Hue path: 350° -> 10°

At:

```text
t = 0.5
```

observed:

```text
shorter:
    raw      = 360°
    positive = 0°

longer:
    raw      = 180°
    positive = 180°

increasing:
    raw      = 360°
    positive = 0°

decreasing:
    raw      = 180°
    positive = 180°
```

### Interpretation

`shorter` and `increasing` select:

```text
350 -> 370
```

while `longer` and `decreasing` use the complementary decreasing route.

The raw representation preserves the selected angular trajectory.

Normalization remains an explicit view.

### Result

PASS.

---

## 8. Raw/unbounded hue versus path-adjusted hue

Input:

```text
30° -> 390°
```

The endpoints have the same normalized direction but different raw angular values.

Observed midpoint:

```text
shorter:    30°
longer:     210°
increasing: 30°
decreasing: 30°
raw:        210°
```

### Interpretation

This confirms that two different concepts are required:

1. interpolation of hue directions according to a path policy;
2. interpolation of the raw stored angular displacement.

For `shorter`, normalization makes the endpoints directionally identical.

For raw interpolation:

```text
30 -> 390
```

preserves the complete revolution and therefore gives:

```text
210°
```

at the midpoint.

### Result

PASS.

The R0.5 decision to retain raw/unbounded hue contains useful information for interpolation.

`raw` should remain distinguishable from CSS-style path selection.

R0.7 does not yet require that `raw` become a fifth `HuePath` enum member.

A separate primitive remains a strong design candidate.

---

## 9. Equal normalized hue with `longer`

For:

```text
30° -> 390°
```

the `longer` policy produced:

```text
210°
```

at the midpoint.

This represents the full complementary revolution required by the tested CSS-style longer-path behavior.

### Result

PASS.

Equal normalized directions are not universally equivalent to zero angular motion; the selected hue policy matters.

---

## 10. Exact 180° tie

Input:

```text
30° -> 210°
```

Observed midpoint:

```text
shorter: 120°
longer:  120°
```

The exact 180-degree difference remained unchanged by both tested fix-up rules.

### Result

PASS.

The implementation handles the exact tie deterministically rather than through an arbitrary floating-point epsilon.

---

## 11. Exact achromatic endpoint

Test:

```text
A:
    L = 0.4
    C = 0
    h = 10°

B:
    L = 0.8
    C = 0.2
    h = 200°
```

Observed midpoint:

```text
Oklch(
    L = 0.6,
    C = 0.1,
    h = 200°
)
```

The exact achromatic endpoint borrowed the hue of the chromatic endpoint for interpolation purposes.

### Result

PASS.

This avoids an artificial hue sweep caused solely by a numerically stored but mathematically powerless hue.

The stored input value itself does not need modification.

---

## 12. Near-achromatic endpoint

Test:

```text
C = 1e-12
```

instead of exact zero.

Observed midpoint hue:

```text
285°
```

rather than:

```text
200°
```

### Result

PASS.

The core does not silently treat very small chroma as achromatic.

This supports the R0.5/R0.7 design rule:

```text
C == 0
```

may receive exact mathematical handling.

Near-achromatic classification requires an explicit caller- or policy-supplied epsilon.

No hidden global epsilon should be introduced.

---

## 13. Negative chroma

Equivalent endpoint representations were tested using:

```text
C = -0.2, h = 30°
```

and its canonical equivalent:

```text
C = 0.2, h = 210°
```

### Canonicalized interpolation

Observed:

```text
Oklch(
    L = 0.6,
    C = 0.2,
    h = 210°
)
```

### Uncanonicalized interpolation

Observed:

```text
Oklch(
    L = 0.6,
    C = 0,
    h = 120°
)
```

### Interpretation

Direct interpolation of non-canonical negative chroma can cross zero chroma and produce a polar trajectory unrelated to the canonical represented color.

Canonicalizing the endpoints first avoids this artifact.

### Result

PASS for the canonicalization hypothesis.

Strong design direction:

> Polar interpolation should operate on canonical non-negative chroma/hue endpoint representations.

Negative chroma may remain representable as an intermediate computational value elsewhere, but should not silently define a different polar interpolation path for an equivalent color.

---

## 14. Straight versus alpha-aware rectangular interpolation

Test:

```text
opaque red
    ->
transparent blue
```

at:

```text
t = 0.5
```

### Naive straight interpolation

Observed:

```text
color = (0.5, 0, 0.5)
alpha = 0.5
```

The fully transparent blue endpoint incorrectly contributes hidden color to the visible midpoint.

### Alpha-aware premultiplied interpolation

Observed:

```text
color = (1, 0, 0)
alpha = 0.5
```

### Result

PASS.

Alpha-aware interpolation must premultiply interpolation coordinates before interpolation.

This prevents hidden color behind zero alpha from leaking into visible intermediate results.

---

## 15. Interpolation premultiplication is distinct from compositing premultiplication

R0.6 validated:

```text
Premultiplied!(LinearSRgb!T)
```

for linear-light Porter-Duff compositing.

R0.7 demonstrates that interpolation premultiplication is broader and space-dependent.

For rectangular interpolation spaces, coordinates may be alpha-scaled as part of the interpolation algorithm.

For polar spaces, hue is excluded.

### Result

Strongly supports the R0.6/R0.7 distinction:

> Interpolation premultiplication is an algorithmic interpolation step and must not automatically reuse a universal `Premultiplied!Color` public type.

---

## 16. Alpha-aware polar interpolation

Test midpoint:

```text
A:
    L = 0.4
    C = 0.2
    h = 30°
    alpha = 0

B:
    L = 0.8
    C = 0.2
    h = 210°
    alpha = 1
```

Observed:

```text
alpha = 0.5

L = 0.8
C = 0.2
h = 120°
```

### Interpretation

`L` and `C` participate in alpha premultiplication.

Hue remains an angular interpolation coordinate and is not multiplied by alpha.

The transparent first endpoint therefore does not distort the visible `L` or `C` contribution, while hue-path semantics remain independently defined.

### Result

PASS.

Polar alpha-aware interpolation requires component-specific premultiplication semantics.

---

## 17. Zero interpolated alpha

Test:

```text
alpha 0 -> alpha 0
```

Observed:

```text
alpha = 0
L = 0
C = 0
h = 60°
```

No division by zero occurred.

Hue remained independently interpolated.

### Result

PASS.

For interpolation-specific premultiplication:

```text
if interpolated alpha == 0
```

the premultiplied non-hue coordinates remain undivided.

This behavior must remain conceptually separate from R0.6's general unpremultiplication operation for compositing values.

---

## 18. Hue is never alpha-premultiplied

The polar alpha experiment verifies that the hue coordinate remains angular.

The algorithm does not perform:

```text
h * alpha
```

### Result

PASS.

This is a fundamental semantic distinction between rectangular and polar interpolation.

A generic operation that blindly multiplies every scalar member of an arbitrary color structure by alpha would be incorrect.

---

## 19. `float` path

Observed:

```text
350° -> 10°, shorter, t=0.5
    -> raw 360°
```

with `float`.

### Result

PASS.

The tested semantics work for both:

```text
float
double
```

---

## 20. CTFE

The executable built successfully with all compile-time assertions enabled.

CTFE-covered behavior includes:

- rectangular interpolation;
- extended-range interpolation;
- extrapolation;
- hue-path fix-up;
- raw hue interpolation;
- equal normalized hues;
- 180-degree ties;
- exact-achromatic handling;
- near-achromatic distinction;
- alpha-aware rectangular interpolation;
- alpha-aware polar interpolation;
- zero-alpha handling;
- float path.

### Result

PASS.

Interpolation remains viable for compile-time use cases such as:

- tone generation;
- theme generation;
- palettes;
- static gradients;
- reference fixtures.

---

## 21. Compile-negative type contract

The experiment statically verifies that low-level interpolation does not accept mismatched spaces such as:

```text
SRgb
vs
LinearSRgb
```

or:

```text
Oklab
vs
Oklch
```

The tested OKLCH overload also requires an explicit `HuePath`.

Successful compilation of the complete program proves the negative `__traits(compiles)` assertions passed.

### Result

PASS.

No hidden color-space conversion is required for the low-level interpolation primitive.

---

## 22. Function attributes

The experiment targets core interpolation functions as:

```d
@safe
pure
nothrow
@nogc
```

The successful builds and CTFE execution support this implementation direction for the tested scalar algorithms.

### Result

PASS for the experiment scope.

---

## 23. Compiler agreement

Observed DMD debug and LDC release output was identical for the displayed test vectors.

Both builds ended with:

```text
mismatched spaces rejected: yes
OKLCH path required:        yes
CTFE assertions:            pass if executable built

R0.7 runtime checks complete.
```

### Result

PASS.

No compiler-specific semantic difference was observed in the tested behavior.

---

# 24. Validated architectural conclusions

R0.7 supports the following design direction.

## 24.1 Explicit space

Interpolation occurs in the color space represented by the supplied types.

The low-level operation does not silently choose or convert to a different interpolation space.

## 24.2 Rectangular interpolation

Rectangular spaces can use ordinary component interpolation.

This applies naturally to candidates such as:

```text
SRgb
LinearSRgb
Oklab
```

Their semantics still differ because the coordinates represent different spaces.

## 24.3 Polar interpolation

OKLCH additionally requires hue-path semantics.

The tested standardized policies are:

```text
shorter
longer
increasing
decreasing
```

## 24.4 Raw hue

Raw/unbounded hue interpolation is meaningfully distinct from normalized hue-path interpolation.

The distinction should remain expressible.

## 24.5 Achromatic handling

Exact:

```text
C == 0
```

may receive special hue handling.

Near-zero chroma should not use an implicit epsilon.

## 24.6 Negative chroma

Canonicalizing negative chroma before polar interpolation avoids artificial zero-chroma crossings between equivalent color representations.

## 24.7 Alpha

Alpha-aware interpolation should use interpolation-specific premultiplication.

For rectangular spaces, all interpolation coordinates may participate.

For polar OKLCH:

```text
L -> premultiplied
C -> premultiplied
h -> NOT premultiplied
```

## 24.8 Compositing separation

Interpolation premultiplication must remain distinct from the R0.6 Porter-Duff compositing representation.

## 24.9 Extended range

Interpolation does not imply clipping or gamut mapping.

## 24.10 Extrapolation

There is no mathematical requirement for the low-level primitive to clamp `t`.

Unclamped interpolation/extrapolation remains a strong candidate.

---

# 25. Open API questions

The experiment does not yet freeze:

- whether OKLCH interpolation always requires an explicit `HuePath`;
- whether `shorter` receives a convenience default;
- whether raw hue interpolation is:
  - `HuePath.raw`,
  - a separate function,
  - or a lower-level scalar-angle primitive;
- exact public names for hue adjustment helpers;
- whether all rectangular spaces share one generic interpolation implementation;
- how canonicalization is exposed in the production API;
- whether exact-achromatic hue borrowing belongs directly in `interpolate` or an explicit polar policy;
- whether alpha-aware interpolation uses overloads on `Alpha!Color` or a separate operation name;
- zero-alpha output representation details in a future public API;
- interpolation behavior for future color spaces.

These should be decided during production API synthesis rather than inferred from experiment-local code structure.

---

# 26. Deferred topics

R0.7 does not validate:

- CSS `none` / missing components;
- CSS parser behavior;
- hidden near-achromatic epsilon;
- gradient containers;
- easing functions;
- spline or Bézier interpolation;
- gamut mapping;
- GPU interpolation;
- SIMD/batch interpolation;
- Display-P3;
- Rec.2020;
- HDR;
- animation framework semantics.

These remain separate research or consumer-driven topics.

---

# 27. Final status

```text
R0.7 — Interpolation Semantics

DMD debug:     PASS
LDC release:   PASS
CTFE:          PASS
float:         PASS
double:        PASS
type safety:   PASS
extended range: PASS
extrapolation: PASS
hue paths:     PASS
raw hue:       PASS
achromatic:    PASS
negative C canonicalization hypothesis: PASS
alpha rectangular: PASS
alpha polar:   PASS
zero alpha:    PASS
```

R0.7 provides sufficient experimental evidence to treat same-space interpolation and polar OKLCH hue-path semantics as validated R0 research.

The implementation remains experimental.

No public `color-d` API is frozen.