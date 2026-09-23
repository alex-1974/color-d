# R0.10 — DeltaEOK semantics and reference coverage

**Status:** VALIDATED / PENDING INTEGRATION
**Issue:** https://github.com/alex-1974/color-d/issues/6

This document is the durable repository-side research contract for R0.10.

The GitHub issue is the coordination surface. This document governs the
experiment carried out on this branch.

No public API is frozen by R0.10.

---

## Goal

Validate the semantics, API boundary, numerical behavior and reference coverage
for `deltaEOK` before promotion into the production `color-d` API.

This is a research block. It does not freeze a public API.

## Standards / reference basis

Current CSS Color 4 defines ΔEOK as Euclidean distance in Oklab:

```text
ΔL = L1 - L2
Δa = a1 - a2
Δb = b1 - b2

ΔEOK = sqrt(ΔL² + Δa² + Δb²)
```

Current CSS Color 4 also describes a distinct ΔEOK2 metric.

R0.10 must therefore preserve algorithm identity:

- `deltaEOK` means Euclidean Oklab distance;
- a future `deltaEOK2`, if required, is a separate algorithm;
- do not introduce an ambiguous generic `deltaE()`.

The CSS color-difference section is informative/non-normative, so durable
color-d evidence should use multiple independent references.

## Research questions

### 1. Input-space contract

Primary hypothesis:

`deltaEOK` operates directly on `Oklab!T`.

Candidate shape:

```d
T deltaEOK(Oklab!T a, Oklab!T b);
```

with natural UFCS:

```d
auto d = a.deltaEOK(b);
```

Do not silently convert arbitrary color spaces inside `deltaEOK`.

A caller starting with sRGB, XYZ or OkLCh should explicitly convert to Oklab
unless later consumer evidence justifies a clearly named convenience API.

Research:

- mixed scalar types;
- `float` versus `double`;
- compile-negative mismatched-space behavior.

### 2. Extended Oklab values

Unlike WCAG-2 measurement, ΔEOK is ordinary Euclidean mathematics and does not
inherently require an sRGB-style `[0,1]` domain contract.

Test:

- L outside `[0,1]`;
- large positive/negative a and b;
- out-of-gamut Oklab coordinates.

Primary hypothesis:

> Finite extended Oklab coordinates remain valid mathematical inputs and are
> not clipped, gamut-mapped or rejected merely because they lie outside a
> display gamut.

### 3. Non-finite values

Test explicitly:

```text
NaN
+Infinity
-Infinity
```

color-d must not silently repair non-finite values.

Determine whether ordinary IEEE propagation is sufficient or whether any
checked diagnostic has a concrete consumer justification.

Do not automatically copy the R0.9 WCAG checked-result policy; this is a
different semantic problem.

### 4. Alpha boundary

ΔEOK is defined over Oklab coordinates, not alpha.

Primary hypothesis:

- `Alpha!(Oklab!T)` is not accepted directly;
- premultiplied values are not accepted directly;
- transparent colors require an explicit rendering/background policy before
  ordinary perceptual color difference is meaningful.

No hidden compositing background.

### 5. Mathematical properties

Validate for both `float` and `double`:

- identity: `deltaEOK(a, a) == 0`;
- symmetry: `deltaEOK(a, b) == deltaEOK(b, a)`;
- non-negativity for finite inputs;
- axis-aligned analytical vectors;
- generated finite extended-domain samples;
- triangle inequality within numerical tolerance.

The implementation operates directly in Oklab Cartesian coordinates.

Do not convert through OkLCh.

### 6. Reference vectors

Build durable reference coverage from independent sources.

Include:

- trivial analytical vectors;
- W3C/CSS examples where usable;
- independently computed high-precision vectors;
- colors already used by R0.4, R0.5 and R0.8 where useful for cross-block
  consistency.

Record expected values and operation-specific tolerances.

### 7. JND / policy boundary

CSS Color 4 uses approximately:

```text
ΔEOK = 0.02
```

as a just-noticeable-difference threshold in its gamut-mapping discussion.

This is policy/context, not part of the distance function.

`deltaEOK` must not silently classify:

- equal / different;
- perceptible / imperceptible;
- pass / fail.

If a named JND helper is ever useful, justify it separately.

### 8. ΔEOK2 boundary

Current CSS Color 4 describes ΔEOK2 separately from ΔEOK.

R0.10 should record that distinction and ensure the initial naming leaves room
for a future explicit:

```d
deltaEOK2
```

Do not implement ΔEOK2 without a concrete research or consumer requirement.

### 9. CTFE / UFCS / attributes

The candidate should verify, where supported:

```d
@safe
pure
nothrow
@nogc
```

CTFE is a first-class requirement for the normal mathematical API.

Validate with `static assert`.

UFCS should work naturally for the accepted same-space function form.

Do not create a separate CTFE-specific API.

### 10. Performance / implementation shape

The direct formula is small, but `sqrt` may dominate the arithmetic.

Do not optimize speculatively.

Questions:

- does ordinary `sqrt(ΔL² + Δa² + Δb²)` produce appropriate code?
- is `hypot` materially or numerically preferable?
- is a squared-distance API actually required by any consumer?

Do not add `deltaEOKSquared` without consumer evidence.

Use DMD 2.111 / LDC 1.41 as the historical performance baseline if a runtime
benchmark is justified.

Coordinate broader compiler retesting with issue #5.

## Experiment shape

```text
docs/research/R0_10_DELTA_E_OK.md

experiments/r0_10_delta_e_ok/
    README.md
    dub.sdl
    source/app.d
    RESULTS.md
```

`RESULTS.md` is created only after observed runs.

Validate with:

```text
DMD 2.111.0
LDC 1.41.0
float
double
Debug
Release
CTFE
```

## Initial hypotheses

1. ΔEOK is exactly Euclidean distance in Oklab.
2. The core function accepts `Oklab!T` and performs no hidden conversion.
3. Finite extended Oklab coordinates remain valid inputs.
4. No clipping or gamut mapping occurs.
5. Alpha is outside the primitive input contract.
6. Non-finite values are not silently repaired.
7. JND 0.02 is policy, not part of `deltaEOK`.
8. ΔEOK2 is a distinct future algorithm.
9. The normal API supports runtime use, CTFE and UFCS.
10. No generic ambiguous `deltaE()` enters the initial API.

## Validated conclusions

The executable experiment in:

```text
experiments/r0_10_delta_e_ok/
```

was validated with:

```text
DMD 2.111.0
LDC 1.41.0
float
double
Debug
Release
CTFE
```

The experiment commit is:

```text
7474e65 research: validate R0.10 deltaEOK semantics
```

All four final compiler/build configurations pass.

### Input and API boundary

The validated primitive operates directly on same-scalar Oklab values:

```d
deltaEOK(Oklab!T lhs, Oklab!T rhs)
```

The research supports:

- `float` and `double`;
- identical scalar types for both operands;
- natural UFCS use;
- `@safe`;
- `pure`;
- `nothrow`;
- `@nogc`;
- CTFE.

No implicit conversion from another color space belongs inside `deltaEOK`.

The initial API must not introduce an ambiguous generic `deltaE()`.

Public API promotion remains an R1 task.

### Mathematical semantics

`deltaEOK` remains the ordinary Euclidean distance in Oklab Cartesian
coordinates.

The validated operation does not:

- convert through OkLCh;
- clip;
- gamut-map;
- normalize to a display gamut;
- classify perceptibility;
- apply a JND threshold.

Finite extended Oklab coordinates remain valid mathematical inputs.

### Numerical implementation decision

The straightforward source formulation:

```text
sqrt(dL*dL + da*da + db*db)
```

is rejected as the production implementation candidate.

The experiment demonstrated compiler/build-dependent finite-range behavior.

For the selected extreme one-axis probes:

- DMD debug overflowed large finite values and underflowed `T.min_normal`;
- LDC debug did the same;
- LDC release did the same;
- DMD release happened to preserve those particular values.

Therefore the direct squared-sum source expression does not provide a robust
portable contract for the declared finite extended domain.

### Raw Phobos hypot

Three-argument Phobos `hypot` is numerically robust for the tested finite
range and supports CTFE on the tested baseline.

However, raw `hypot` is not accepted as the complete implementation because
its observed simple non-finite behavior does not match the R0.10 policy.

Across the final DMD/LDC debug/release matrix, the experiment observed:

```text
hypot(NaN, 0, 0)   -> not NaN
hypot(+Inf, 0, 0)  -> NaN
hypot(-Inf, 0, 0)  -> NaN
```

The library must not inherit those semantics accidentally.

### Preferred implementation candidate

The preferred R0.10 implementation direction is guarded three-argument
Phobos `hypot`.

Conceptually:

```d
const T dL = lhs.l - rhs.l;
const T da = lhs.a - rhs.a;
const T db = lhs.b - rhs.b;

if (isNaN(dL) || isNaN(da) || isNaN(db))
    return T.nan;

if (fabs(dL) == T.infinity ||
    fabs(da) == T.infinity ||
    fabs(db) == T.infinity)
{
    return T.infinity;
}

return hypot(dL, da, db);
```

This makes color-d's special-value semantics explicit while delegating the
finite robust Euclidean norm to Phobos.

### Non-finite policy

R0.10 validates the following ordering:

1. any NaN component difference -> NaN;
2. otherwise any infinite component difference -> positive infinity;
3. otherwise compute the finite Euclidean norm.

NaN therefore takes precedence when NaN and infinity coexist.

No checked-result wrapper is justified by this research.

### Scaled-norm fallback

A custom scaled three-dimensional norm was also validated.

It correctly preserved:

- large finite values;
- `T.min_normal`;
- ordinary analytical vectors;
- the required NaN/infinity semantics.

It remains a useful research/reference fallback.

It is not preferred while guarded Phobos `hypot` satisfies the same
requirements with less custom numerical machinery.

### Property validation

Each final compiler/build run evaluates 4096 deterministic generated cases
for each scalar type.

The validated properties are:

- identity;
- non-negativity;
- symmetry;
- agreement with the wider-precision reference route;
- triangle inequality.

All final runs report zero failures.

The largest observed normalized reference deviation is approximately:

```text
1.256 * T.epsilon * max(1, abs(reference))
```

The experiment uses:

```text
8 * T.epsilon * max(1, abs(reference))
```

as an operation-specific research tolerance.

This is not a general color-d tolerance policy.

### Alpha boundary

Alpha-bearing and premultiplied colors remain outside the direct primitive
contract.

A rendered/background-resolved color must be obtained explicitly before
ordinary perceptual color difference is measured.

There is no hidden compositing background.

### JND boundary

The CSS Color 4 approximately `0.02` ΔEOK just-noticeable-difference value is
contextual policy.

It is not embedded in `deltaEOK`.

The core operation returns a distance only and does not classify:

- equal versus different;
- perceptible versus imperceptible;
- pass versus fail.

### deltaEOK2 boundary

ΔEOK2 remains a distinct algorithm.

If future standards or consumer requirements justify it, it must use a
separate explicit name:

```d
deltaEOK2
```

R0.10 does not implement it.

### Squared-distance API

No consumer evidence justifies:

```d
deltaEOKSquared
```

R0.10 therefore does not recommend adding it.

### R0.10 decision

The R1 production candidate is:

```text
direct same-scalar Oklab inputs
        +
explicit NaN / infinity guards
        +
Phobos three-argument hypot for finite values
```

No public API is frozen by R0.10.

The research result is validated; repository integration and higher-level
documentation updates remain before R0.10 is fully closed.

---

## Exit criteria

R0.10 is complete when:

- formula/reference semantics are validated;
- input-space contract is explicit;
- extended and non-finite behavior is recorded;
- alpha boundary is explicit;
- float/double and CTFE behavior are validated;
- numerical tolerance is recorded;
- ΔEOK versus ΔEOK2 is documented;
- JND/policy boundary is documented;
- performance/codegen observations, if any, are evidence-based;
- results are merged to `main`;
- ROADMAP and TECHNICAL_SPEC conclusions are updated;
- no public API is frozen before consumer validation.
