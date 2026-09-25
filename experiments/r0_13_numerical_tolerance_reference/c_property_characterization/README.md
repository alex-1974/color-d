# R0.13-C — Property characterization

**Status:** EXPERIMENT
**Parent:** R0.13 — Numerical tolerance and reference policy
**Document revision:** 0.9
**Date:** 2026-09-25
**GitHub:** #9

This harness characterizes the R0.13-C operation families without selecting a
universal epsilon or freezing production acceptance thresholds.

Implemented blocks:

```text
C1 — Oklab <-> OKLCH / hue
C2 — alpha / premultiplication / source-over
C3 — interpolation / hue paths / alpha-aware interpolation
C4 — WCAG 2 relative luminance / contrast
```

The remaining C block will cover `deltaEOK` in a separate source module.

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

The DMD and LDC runs both observed this loss. The half-magnitude channels
rounded to signed zero during premultiplication, while the unit channel
preserved the smallest positive subnormal. Unpremultiplication therefore
returned `(0, 1, -0)` instead of `(0.5, 1, -0.5)`.

This is a representational range limit, not ordinary round-trip noise and not a
reason to enlarge a generic tolerance. In particular, straight ->
premultiplied -> straight is not universally lossless even when alpha is
positive and valid.

### C2 observed results

C2 has been run in debug builds on the same x86_64 Linux research host with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.0 and LLVM 19.1.7.

After excluding compiler/build banners and the preceding C1 output, all 99 C2
output lines from the two runs were byte-identical.

For both scalar types and both tested compilers:

- the selected exact premultiplication, zero-alpha, hidden-color-collapse and
  source-over identity probes all held exactly;
- alpha classification accepted 0, 0.5 and 1 and rejected negative values,
  values above 1, NaN and infinity;
- ordinary premultiplication and unpremultiplication matched the target-type
  rounded wider-arithmetic reference exactly in the selected probes;
- the selected ordinary and extended premultiply -> unpremultiply round trips
  were exact in target type;
- extended-range source-over remained unclipped and differed from the wider
  reference by at most 1 ULP in the selected probes;
- source-over associativity was not bitwise exact: the selected float case
  differed by 1 ULP in one channel, and the selected double case differed by
  1 ULP in one channel and alpha;
- the smallest-positive-subnormal-alpha probe demonstrated deterministic
  target-type information loss before unpremultiplication.

The associativity observation belongs to `DERIVED`, not `EXACT`. The
tiny-alpha observation belongs to `RANGE`, not to a tolerance envelope.

The identical DMD/LDC C2 debug output is useful cross-compiler evidence but is
not promoted to a general portability guarantee. Controlled Debug/Release,
runtime/CTFE and compiler-version comparisons remain R0.13-E work.

No C2 observation freezes a production tolerance or public API.


## C3 questions

C3 carries the validated R0.7 interpolation semantics into the R0.13
comparison taxonomy. It deliberately separates semantic endpoint behavior from
the numerical properties of the scalar interpolation formula.

```text
EXACT
    selected dyadic scalar endpoints
    deterministic hue-path branch decisions
    exact 180-degree hue tie behavior
    exact C == 0 hue borrowing
    negative-chroma canonicalization on selected equivalent inputs
    alpha-aware hidden-color behavior on selected canonical inputs
    zero-alpha no-division structure

REFERENCE
    ordinary scalar interpolation against wider real arithmetic
    extrapolation against wider real arithmetic
    non-trivial hue interpolation after semantic endpoint adjustment

DERIVED
    alpha-aware rectangular interpolation after interpolation premultiplication
    polar interpolation after chroma canonicalization and hue adjustment

POLICY
    near-achromatic values remain distinct from exact C == 0
    no hidden chroma epsilon is introduced

RANGE
    finite opposite-sign endpoints near +/-T.max
    subtraction overflow in a + (b - a) * t
    endpoint failures caused by evaluating b - a before t is applied
```

### Legacy scalar form

R0.7 uses:

```text
a + (b - a) * t
```

This form has attractive ordinary behavior and preserves extrapolation, but it
does not provide a universal finite-input endpoint guarantee. If finite `a`
and `b` are far enough apart, `b - a` can overflow before multiplication by
`t`.

C3 therefore keeps two functions distinct:

- `legacyLerp`, which reproduces the R0.7 source form exactly;
- `endpointAwareLerp`, which adds only explicit `t == 0` and `t == 1`
  branches before delegating all other cases to the legacy form.

The endpoint-aware helper is a research probe, not a complete robust
interpolation algorithm. In particular, it intentionally does not claim to
solve interior overflow or extrapolation-range questions.

### Endpoint semantics versus numerical range

If the project wants `t == 0` and `t == 1` to be exact semantic contracts,
those contracts should be implemented structurally. A tolerance cannot repair
a NaN or infinity produced before the endpoint multiplier becomes effective.

Conversely, exact endpoint branches do not define the acceptable numerical
envelope for interior interpolation. C3 reports those categories separately.

### Hue and achromatic policy

C3 retains the R0.7 hue rules:

- `shorter`, `longer`, `increasing` and `decreasing` remain explicit;
- exact +/-180-degree ties are deterministic;
- exact `C == 0` may borrow the chromatic endpoint hue;
- near-achromatic non-zero chroma does not implicitly borrow hue;
- negative chroma is canonicalized before polar interpolation.

These are semantic or policy decisions, not floating-point tolerance results.

### C3 reference path

Scalar references widen the target-type inputs to D `real` before evaluating
the same interpolation equation. Hue references first apply the same semantic
hue-path endpoint selection, then evaluate the scalar interpolation in wider
arithmetic.

This is a wider-arithmetic reference, not an independent interpolation
specification oracle. As in C1 and C2, `real` remains local diagnostic
evidence rather than portable ground truth.

### C3 observed results

C3 has been run in debug builds on the same x86_64 Linux research host with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.0 and LLVM 19.1.7.

After excluding compiler/build banners and the preceding C1/C2 output, all 57
C3 output lines from the two runs were byte-identical.

For both scalar types and both tested compilers:

- the selected ordinary endpoint, hue-path, 180-degree-tie, equal-normalized-hue,
  exact-achromatic-borrowing, negative-chroma-canonicalization and alpha
  structural probes all produced the expected exact decisions;
- the near-achromatic non-zero chroma probe remained distinct from exact
  achromatic borrowing, confirming that this remains an explicit policy
  boundary rather than an implicit epsilon rule;
- ordinary scalar interpolation differed from the wider-arithmetic reference
  by 1 ULP in the selected float and double probes;
- the selected scalar extrapolation and hue reference probes rounded to the
  same target-type values as the wider reference;
- selected derived OKLCH interpolation differed by at most 1 ULP for float and
  rounded to the same target-type values for double;
- selected alpha-aware rectangular interpolation differed by at most 1 ULP for
  float and by at most 2 ULP for double.

The range probe exposed a structural failure of the legacy scalar form
`a + (b - a) * t` for finite opposite-sign endpoints `-T.max` and `T.max`:

- at `t == 0`, the legacy expression produced NaN instead of `a`;
- at `t == 1`, it produced positive infinity instead of `b`;
- at `t == 0.5`, it produced positive infinity instead of the finite
  mathematical midpoint zero.

The failure occurs because `b - a` overflows before multiplication by `t`.
It is therefore a range/algorithm issue, not an approximate-comparison issue.

The research-local `endpointAwareLerp` restored the two endpoint identities
exactly by handling `t == 0` and `t == 1` before evaluating the legacy form.
It deliberately did not claim to solve the interior-overflow case.

This yields two distinct R1 design questions:

1. whether exact endpoint semantics should be guaranteed structurally;
2. whether production interpolation must remain finite whenever the
   mathematical interpolation of finite endpoints is finite.

Those questions must not be collapsed into one numerical tolerance.

The identical DMD/LDC C3 debug output is useful cross-compiler evidence but is
not a general portability guarantee. Controlled Debug/Release, runtime/CTFE
and compiler-version comparisons remain R0.13-E work.

No C3 observation freezes a production tolerance, public interpolation spelling
or complete robust-lerp algorithm.


## C4 questions

C4 carries the validated R0.9 WCAG-2 luminance/contrast semantics into the
R0.13 comparison taxonomy.

```text
CLASSIFY
    finite encoded/linear sRGB components
    all components in [0, 1]

EXACT
    linear black luminance == 0
    linear white luminance == 1 on the selected published coefficients
    selected same-color contrast == 1
    contrast symmetry on selected valid inputs

REFERENCE
    normative black/white contrast value 21:1
    encoded-sRGB decode in wider real arithmetic
    WCAG relative luminance in wider real arithmetic
    contrast ratio in wider real arithmetic
    primary coefficients as published WCAG values

BOUNDARY
    nextDown / at / nextUp around encoded 0.04045
    reuse the R0.13-B transfer characterization rather than inventing a new
    transfer tolerance

DISTINCT
    WCAG relative luminance is not XYZ-D65 Y

REGRESSION
    the old R0.9 "independent direct WCAG reference path" is same-formula
    regression evidence, not an independent numerical oracle
```

### Exactness correction from the first C4 compile

The first DMD 2.111 compile rejected an exact CTFE assertion that the
black/white contrast result was bitwise equal to `21.0`, even though the
compiler diagnostic printed both operands as `21.0`.

That is precisely the distinction R0.13 is intended to expose: a normative
mathematical/reference value of 21:1 does not by itself justify an `EXACT`
floating-point comparison. C4 therefore keeps same-color ratio 1 and selected
symmetry in the exact bucket, but moves black/white 21:1 to `REFERENCE` and
reports its numerical distance explicitly.

No tolerance was introduced to make the compile-time assertion pass.

### Reference provenance

WCAG relative luminance is a standards-defined computation. C4 therefore
distinguishes the normative formula from numerical independence.

The wider-arithmetic C4 reference widens the target-type input to D `real`
before applying the WCAG sRGB decode and the published weights
`0.2126/0.7152/0.0722`. This is useful for characterizing target-type rounding,
but it is still the same defining formula.

R0.9 also contained a separately spelled "direct WCAG reference" implementation.
Because that route used the same transfer constants, branch and published
weights, C4 reclassifies it as same-formula regression evidence. Exact agreement
between those two spellings cannot establish an independent tolerance envelope.

### Transfer boundary

C4 does not reopen R0.13-B1. The encoded threshold probes use
`nextDown(0.04045)`, target-type `0.04045`, and `nextUp(0.04045)` so WCAG
luminance can be observed across the same rounded sRGB decode boundary.

The B1 finding remains authoritative for the transfer primitive itself:
ordinary floating-point drift and the rounded-threshold structural behavior
must not be collapsed into one generic epsilon.

### WCAG versus XYZ Y

The WCAG published luminance coefficients remain intentionally distinct from
the more precise linear-sRGB -> XYZ-D65 matrix used elsewhere in color-d.
C4 reports that difference as a semantic distinction, not as an error against
one preferred value.

### Domain and alpha boundary

The standards-facing measurement domain remains finite sRGB or linear-sRGB
components in `[0, 1]`. Extended color-d values are valid color mathematics
but are not valid WCAG measurements.

Unresolved alpha remains outside the ordinary WCAG measurement primitive.
Compositing/alpha semantics were characterized in C2; C4 assumes the color to
be measured has already been resolved.

### C4 observed results

C4 has been run in debug builds on the same x86_64 Linux research host with:

- DMD 2.111.0;
- LDC 1.41.0 using DMD frontend 2.111.0 and LLVM 19.1.7.

After excluding compiler/build banners and the preceding C1-C3 output, the C4
runtime output from the two runs was byte-identical.

For both scalar types and both tested compilers:

- domain classification accepted the selected finite encoded/linear values in
  [0,1] and rejected below-range, above-range, NaN and infinity probes;
- selected linear black and white luminance identities held exactly;
- selected same-color contrast and contrast symmetry held exactly;
- the old R0.9 separately spelled WCAG route remained exactly equal to the
  candidate route, confirming its classification as same-formula regression
  rather than an independent oracle;
- WCAG relative luminance remained observably distinct from XYZ-D65 Y by about
  1.60212e-05 for the selected ordinary encoded color.

The selected black/white contrast result illustrates why the normative 21:1
value belongs to `REFERENCE`, not universally to `EXACT`:

- `float` produced about 20.99999809, one ULP from target-rounded 21;
- `double` produced exact 21 at runtime on both tested compilers.

Ordinary encoded WCAG probes reached 1 ULP for float and 4 ULP for double in
the selected cases. The selected ordinary contrast probe reached 3 ULP for
float and 2 ULP for double. These are observations, not promoted thresholds.

The encoded transfer-boundary luminance probes showed the same selected
ULP-to-rounded-reference pattern for both scalar types:

```text
below   0 ULP
at      1 ULP
above   3 ULP
```

This is downstream evidence of the already-characterized R0.13-B1 transfer
boundary. It does not justify a separate or larger generic WCAG tolerance.

### CTFE/runtime follow-up

Before black/white 21:1 was reclassified from `EXACT` to `REFERENCE`, DMD
2.111 rejected a compile-time assertion equivalent to:

```d
static assert(ctfeContrast == 21.0);
```

even though the later DMD runtime probe of the same `double` computation
reported exact 21 with zero ULP distance to the wider reference.

That observation is retained as concrete motivation for R0.13-E
runtime-versus-CTFE characterization. C4 does not infer its mechanism and does
not turn it into a WCAG tolerance rule.

The identical DMD/LDC C4 runtime output is useful cross-compiler evidence but
is not a general portability guarantee. Controlled Debug/Release,
runtime/CTFE and compiler-version comparisons remain R0.13-E work.

No C4 observation freezes a production tolerance or final public WCAG API.

## Characterization rule

The harness is observational first.

A legacy implementation producing overflow, underflow or a desired-contract
mismatch is a research result, not a reason to widen a generic tolerance.
Likewise, the maximum observed error is not automatically promoted into a test
threshold.
