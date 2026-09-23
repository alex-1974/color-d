# R0.10 — DeltaEOK semantics and reference coverage

**Status:** RESEARCH / BEFORE EXPERIMENT
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
