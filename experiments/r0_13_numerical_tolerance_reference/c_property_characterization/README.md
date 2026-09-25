# R0.13-C — Property characterization

**Status:** EXPERIMENT
**Parent:** R0.13 — Numerical tolerance and reference policy
**Document revision:** 0.3
**Date:** 2026-09-25
**GitHub:** #9

This harness characterizes the R0.13-C operation families without selecting a
universal epsilon or freezing production acceptance thresholds.

Implemented blocks:

```text
C1 — Oklab <-> OKLCH / hue
C2 — alpha / premultiplication / source-over
```

Later C blocks will cover interpolation, WCAG measurement and `deltaEOK` in
separate source modules.

## C1 questions

C1 separates:

```text
EXACT
    exact-achromatic semantics
    direct component preservation where algebraically guaranteed

REFERENCE
    chroma magnitude
    non-achromatic hue
    polar -> Cartesian coordinates

DERIVED
    Cartesian -> polar -> Cartesian round trip

RANGE
    large finite Cartesian coordinates
    normal and subnormal tiny Cartesian coordinates

POLICY
    near-achromatic classification remains outside this numerical comparator
```

Diagnostics record absolute, relative and ULP differences where those metrics
are meaningful. Hue additionally uses circular angular error so equivalent
angles near the 0/360-degree seam are not treated as hundreds of degrees apart.

No diagnostic quantity is itself an acceptance threshold.

## 2D `hypot` compatibility

R0.5 used:

```text
sqrt(a*a + b*b)
```

for OKLCH chroma. That source form can overflow or underflow in intermediates
for finite inputs.

The natural replacement is two-argument `hypot(a, b)`, but the supported
frontend/Phobos 2.111 baseline has a known tiny-operand correctness defect in
that overload.

C1 therefore copies the narrow compatibility strategy validated by
`euclid-core-d` issue #4 and merged in commit:

```text
c9fd4b2f5eca46a4d0170b0de915b8e1481380a9
```

The copied research-local helper:

- applies the workaround only when `__VERSION__ == 2111`;
- intercepts the affected negligible-component case with an underflow-safe
  magnitude-ratio comparison;
- delegates directly to Phobos `hypot` from frontend 2.112 onward;
- preserves the euclid-core-d special-value ordering used by the validated
  helper.

`color-d` does **not** take a dependency on `euclid-core-d` for this experiment.
The code is copied because the numerical compatibility rule is applicable, not
because geometry Core is a color-library dependency.

The helper remains research infrastructure until R0.13/R1 decides the final
production ownership and spelling.

## Reference path

C1 does not use the copied `hypot` compatibility helper as its own numerical
oracle.

The reference chroma path uses a separately implemented scaled two-dimensional
norm evaluated in D `real`. This avoids the legacy squared-sum overflow/
underflow mechanism and keeps the candidate and reference mechanisms distinct.

Angle and inverse-transform references are also evaluated in `real`.

D `real` is only a local higher-precision diagnostic when it is wider than
`double`; it is not portable arbitrary precision and is not treated as ground
truth.

## C1 observed results

C1 has been run in debug builds on the current x86_64 Linux research host with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.0 and LLVM 19.1.7.

These runs are exploratory R0.13-C evidence. They do not replace the controlled
runtime/CTFE, Debug/Release or compiler-version portability matrix assigned to
R0.13-E.

### Exact and axis observations

For both scalar types and both tested compilers, exact achromatic input
`a == 0 && b == 0` preserved `L` and produced exact `C == 0` and `h == 0`.
The selected positive/negative a/b axis probes also produced the expected
0/90/180/270-degree directions without observed error.

These are candidate exact-contract observations. C1 does not generalize them to
arbitrary non-axis conversion results.

### Chroma range finding

The legacy R0.5 chroma expression `sqrt(a*a + b*b)` failed the declared finite
extended-domain goal in both `float` and `double`:

- a large finite pair overflowed to infinity;
- the smallest positive subnormal on one axis underflowed to zero.

The compatibility `metricHypot` candidate preserved a finite large-pair result
and preserved the smallest positive subnormal exactly. For a pair of smallest
subnormals, the wider-`real` mathematical reference lies between target-type
values but correctly rounds back to the smallest target-type subnormal.

This is evidence against the legacy squared-sum source form. It supports the
frontend-2.111-compatible two-argument `hypot` route as the current production
direction, without freezing a public helper name or tolerance.

### Ordinary and extended numerical observations

For the selected ordinary and extended probes, direct chroma/hue reference
errors and Cartesian round-trip errors remained at ordinary floating-point
scale. The observed double round-trip envelope reached 3 ULP in the selected
extended case.

The current DMD and LDC debug outputs were identical for all `float` rows and
for all critical range rows. Three ordinary `double` rows differed:

- ordinary chroma: DMD landed on the target-type-rounded wider reference while
  LDC was 1 ULP away;
- ordinary round-trip `a`: DMD was 1 ULP from the original value while LDC was
  exact;
- ordinary round-trip `b`: DMD was 1 ULP from the original value while LDC was
  exact.

This is useful evidence that a smaller direct-reference error does not imply a
smaller composed round-trip error. `REFERENCE` and `DERIVED` envelopes must
therefore remain distinct.

### Diagnostic interpretation

The ULP diagnostic compares the observed target-type value with the wider
`real` reference rounded to that target type. Output therefore uses the label
`ulp_to_rounded_ref`.

Consequently, non-zero absolute or relative error against the wider reference
can coexist with `ulp_to_rounded_ref=0`. This is expected when the observed
`float` or `double` is the correctly rounded target-type value.

No C1 observation is promoted to a production tolerance constant at this
stage.

## C2 questions

C2 carries the validated R0.6 alpha architecture into the R0.13 comparison
taxonomy. It keeps straight alpha and premultiplied linear-light sRGB distinct
and characterizes only the numerical properties needed by that architecture.

```text
EXACT
    alpha == 1 premultiplication on selected finite values
    explicit alpha == 0 unpremultiplication branch
    zero-alpha hidden-color collapse on selected finite positive colors
    canonical transparent-source identity
    selected finite opaque-source identity
    canonical transparent-destination identity

CLASSIFY
    alpha validity in [0, 1]
    rejection of finite out-of-range values, NaN and infinity

REFERENCE
    premultiply in wider real arithmetic
    unpremultiply in wider real arithmetic
    premultiplied Porter-Duff source-over in wider real arithmetic

DERIVED
    straight -> premultiplied -> straight round trip
    source-over associativity, left grouping versus right grouping

RANGE
    smallest-positive-subnormal alpha
    target-type underflow during premultiplication
    information loss after unpremultiplication
```

The exact identity probes are deliberately scoped to selected finite values and
canonical transparent premultiplied black where required. C2 does not claim a
bitwise signed-zero contract.

### C2 reference path

The C2 reference functions evaluate the same defining alpha/compositing
equations in D `real` after widening the target-type inputs.

This is a **wider-arithmetic reference**, not an independent formula oracle.
Its purpose is to separate ordinary target-type rounding from semantic and
range failures.

For `sourceOver`, the reference starts from the already-premultiplied
target-type inputs. That isolates the arithmetic of the low-level compositing
primitive from any rounding introduced by the preceding premultiplication.

As in C1, `real` is local diagnostic evidence only when it is wider than
`double`.

### Tiny-alpha range probe

R0.6 established the intentional non-injectivity of premultiplication at
exactly zero alpha. C2 also probes the smallest positive subnormal alpha.

The selected straight channels are:

```text
(0.5, 1.0, -0.5)
```

At that alpha, multiplication of the half-magnitude channels can round to zero
even though alpha itself is non-zero and valid. The following
unpremultiplication can therefore no longer reconstruct those original
channels.

If observed, this is a representational range limit, not ordinary round-trip
noise and not a reason to enlarge a generic tolerance.

C2 remains observational until the local DMD/LDC runs are recorded. No
production tolerance or public API is frozen by adding this harness.

## Characterization rule

The harness is observational first.

A legacy implementation producing overflow, underflow or a desired-contract
mismatch is a research result, not a reason to widen a generic tolerance.
Likewise, the maximum observed error is not automatically promoted into a test
threshold.
