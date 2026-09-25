# R0.13-A — Comparison taxonomy and reference inventory

**Status:** VALIDATED
**Parent:** R0.13 — Numerical tolerance and reference policy
**Document revision:** 0.2
**Date:** 2026-09-25
**GitHub:** #9

This document inventories the numerical-comparison decisions already present in
R0.2–R0.12.

It is evidence synthesis.

It does not establish new tolerance values.

---

# 1. Phase-A purpose

R0.13-A asks:

```text
what property is being tested?
        ↓
is that property exact, classificatory or numerical?
        ↓
what reference is used?
        ↓
how independent is that reference?
        ↓
what comparison rule was used historically?
        ↓
what must R0.13 validate or replace?
```

The existing research contains several different uses of the word or concept
"epsilon".

They must not be conflated.

---

# 2. Taxonomy refinement discovered by the inventory

The initial R0.13 contract proposed these comparison classes:

```text
A. exact equality
B. classification / domain predicates
C. independent reference-value comparison
D. derived / round-trip numerical comparison
E. cross-execution comparison
F. policy-driven approximate classification
```

R0.13-A identifies an additional category that is not itself a comparison
contract:

```text
G. algorithm-internal numerical threshold
   / convergence criterion
```

Examples include:

```text
Local MINDE search epsilon
Ray Trace numerical epsilon
iteration stopping threshold
JND-related mapping threshold
```

These values affect how an algorithm executes.

They are conceptually distinct from:

```text
test tolerance
reference tolerance
round-trip tolerance
boundary-classification policy
```

R0.13 must preserve that distinction.

---

# 3. Historical comparator forms

## 3.1 Shared abs-or-relative comparator

R0.2, R0.3, R0.4, R0.6, R0.8 and R0.9 contain variants of the same
research-local comparator:

```text
diff = abs(actual - expected)

pass if:
    diff <= absoluteTolerance

otherwise:
    scale = max(abs(actual), abs(expected))
    diff <= relativeTolerance * scale
```

This historical reuse is syntactic evidence only.

It does not establish that every property tested through the helper should use
the same comparison policy.

In particular, earlier experiments supplied different absolute and relative
values depending on the operation and scalar type.

---

## 3.2 Absolute-only comparator

R0.7 uses a simpler research helper:

```text
abs(a - b) <= epsilon
```

It was used for representative interpolation and hue-result checks.

This does not establish an absolute-only library policy.

---

## 3.3 R0.10 property tolerance

R0.10 uses an absolute property tolerance:

```text
double:
    1e-12

float:
    2e-5
```

This was explicitly research-local.

It was not presented as a library-wide numerical contract.

---

## 3.4 R0.10 reference tolerance

R0.10 separately compares the candidate deltaEOK result with a wider-precision
`real` reference route using:

```text
8 * T.epsilon * max(1, abs(reference))
```

This is structurally different from the R0.10 property tolerance.

The distinction is important:

```text
property tolerance
!=
reference-implementation tolerance
```

R0.13 must determine whether the epsilon-scaled form is numerically justified
for deltaEOK and whether it generalizes to any other operation class.

---

# 4. Operation/property inventory

## R0.2 — encoded sRGB ↔ linear sRGB

### Properties already exercised

```text
typed encoded/linear distinction
forward transfer
inverse transfer
branch threshold
ordinary finite values
negative extended values
greater-than-one extended values
float behavior
double behavior
forward/inverse round trip
CTFE execution
```

### Historical comparison

Reference values and round trips used the shared abs-or-relative comparator.

Representative provisional values include:

```text
double ordinary:
    abs 1e-15
    rel 1e-14

double selected extended cases:
    abs up to 1e-14
    rel 1e-14

float ordinary:
    abs 1e-7
    rel 1e-6

float selected extended / round-trip cases:
    abs 2e-7
    rel 2e-6
```

These are historical research thresholds.

They are not R0.13 recommendations.

### Reference provenance

The experiment refers to:

```text
standard sRGB transfer equations
CSS Color examples
```

The CSS examples are useful standards-facing regression values.

They are not, by themselves, the normative definition of sRGB colorimetry.

### R0.13 action

```text
R0.13-B
```

Must establish:

- authoritative formula/reference provenance;
- exact behavior, if any, at algebraically exact points;
- branch-boundary behavior;
- float error;
- double error;
- round-trip policy;
- runtime/CTFE policy.

---

## R0.3 — linear sRGB ↔ XYZ D65

### Properties already exercised

```text
black maps to exact zero XYZ
sRGB primaries
reference white
ordinary reference color
extended-range values
forward transform
inverse transform
float round trip
double round trip
CTFE
```

### Historical comparison

Most numerical reference and round-trip checks use the shared abs-or-relative
comparator.

Black is tested exactly as:

```text
X == 0
Y == 0
Z == 0
```

### Reference provenance

The implementation uses rational coefficients from CSS Color 4 sample
conversion code.

The experiment already records an important distinction:

```text
CSS sample code
    = useful reference implementation

CSS sample code
    != normative definition of sRGB colorimetry
```

### R0.13 action

```text
R0.13-B
```

Must determine:

- independent authority for the matrix/colorimetry;
- expected forward error;
- expected inverse error;
- round-trip amplification;
- float versus double behavior;
- whether any matrix-derived identities deserve exact comparison.

---

## R0.4 — XYZ D65 ↔ Oklab

### Exact properties already exercised

Examples include:

```text
cubeRoot(+0) == +0
signed-zero behavior is deliberate
black maps to exact Oklab zero
```

### Numerical properties

```text
XYZ → Oklab reference values
Oklab → XYZ reference values
ordinary round trip
extended-range round trip
float round trip
CTFE
comparison with direct linear-sRGB → Oklab path
```

These use approximate numerical comparison.

### Reference provenance

Two routes are present:

```text
CSS Color 4 XYZ/Oklab path

Björn Ottosson direct linear-sRGB ↔ Oklab path
```

The direct Ottosson path is deliberately used as a different comparison route
and is not assumed to be bit-identical to the CSS/XYZ route.

The canonical Oklab publication records updated matrices dated 2021-01-25,
derived from higher-precision sRGB/D65 values.

### R0.13 action

```text
R0.13-B
```

Must distinguish:

- exact special cases;
- reference-vector error;
- path-to-path disagreement;
- round-trip error;
- `float` versus `double`;
- transcendental/cube-root runtime versus CTFE behavior.

---

## R0.5 — Oklab ↔ OKLCH and achromatic semantics

### Exact semantic classification

Exact achromaticity is:

```text
c == 0
```

No epsilon is part of that predicate.

### Explicit approximate policy

Near-achromatic classification is separately expressed as:

```text
abs(c) <= callerSuppliedEpsilon
```

This is policy.

It does not redefine exact achromaticity.

### Exact representation properties

The research also preserves deliberate representation semantics such as:

```text
raw hue storage
negative-chroma canonicalization relationship
extra hue revolutions where representation permits them
```

Some of these are structural/exact properties rather than numerical
approximation questions.

### Numerical properties

Cartesian/polar conversion and ordinary round trips involve trigonometric and
square-root operations and have historically used approximate comparison.

### R0.13 action

```text
R0.13-C
```

Must keep separate:

```text
exact achromaticity
caller-defined near-achromaticity
representation equality
Cartesian/polar numerical agreement
hue equivalence modulo revolutions
```

A hue-equivalence rule must not be confused with ordinary scalar approximate
equality.

---

## R0.6 — alpha and compositing

### Exact properties already exercised

Examples include:

```text
alpha-domain validity
invalid NaN / infinity alpha classification
transparent/opaque identity cases where algebraically exact
type restrictions
```

### Numerical properties

```text
premultiply / unpremultiply
Porter-Duff source-over reference vectors
CTFE source-over
floating-point source-over associativity
```

The experiment uses the shared abs-or-relative scalar helper and composite
helpers built from it.

### Reference provenance

The experiment refers to W3C-style source-over cases.

The standards-level compositing model defines premultiplied source-over as:

```text
co = cs + cb * (1 - alpha_s)

alpha_o = alpha_s + alpha_b * (1 - alpha_s)
```

### R0.13 action

```text
R0.13-C
```

Must classify separately:

- exact alpha identities;
- normative source-over equations;
- reference vectors;
- premultiply/unpremultiply round trips;
- associativity error.

Associativity under floating-point arithmetic is a numerical property, not an
exact equality requirement.

---

## R0.7 — interpolation and hue paths

### Exact semantics

The research defines exact decisions for:

```text
exact achromatic endpoint handling
exact +/-180-degree hue ties
shorter / longer / increasing / decreasing policy
no hidden near-achromatic epsilon
```

Exact achromaticity again uses:

```text
c == 0
```

Near-achromatic classification remains explicit policy.

### Historical numerical comparison

Representative derived interpolation values were commonly checked with:

```text
abs(actual - expected) <= 1e-12
```

in the double-valued CTFE examples.

The fact that the resulting number was tested approximately does not imply that
the underlying path-selection semantic decision is approximate.

### Reference provenance

Current CSS Color 4 defines:

```text
shorter
longer
increasing
decreasing
```

hue interpolation methods.

### R0.13 action

```text
R0.13-C
```

Must distinguish:

```text
exact path-selection semantics
exact tie handling
derived interpolation arithmetic
hue-angle equivalence
caller-defined near-achromatic policy
```

---

## R0.8 — gamut semantics and gamut mapping

### Strict gamut membership

Strict linear-sRGB gamut membership is defined by exact finite checks and:

```text
0 <= r <= 1
0 <= g <= 1
0 <= b <= 1
```

A color slightly outside is therefore strictly outside.

### Explicit numerical boundary policy

A separate overload accepts caller-supplied epsilon and checks:

```text
-epsilon <= component <= 1 + epsilon
```

Negative epsilon is converted to its magnitude.

This is an explicit numerical-boundary policy.

It does not redefine strict gamut geometry.

### Exact properties

Examples include:

```text
clip component results in selected exact cases
clip idempotence
success metadata
zero-iteration metadata
alpha preservation
strict in/out classification
```

### Numerical mapping properties

Mapped colors and algorithm-to-reference comparisons are numerical properties.

### Algorithmic thresholds

R0.8 also contains values such as:

```text
Local MINDE epsilon = 0.0001
Ray Trace epsilon
iteration stopping criteria
JND-related conditions
```

These are algorithmic parameters.

They are not automatically:

```text
test tolerances
equality tolerances
gamut-boundary policy
```

### Reference provenance

Current CSS Color 4 describes three selectable gamut-mapping approaches:

```text
Binary Search with Local MINDE
EdgeSeeker
Ray Trace
```

The R0.8 research validated Local MINDE and Ray Trace candidates.

### R0.13 action

```text
R0.13-D
```

Must explicitly separate:

1. strict gamut geometry;
2. caller-requested boundary proximity;
3. algorithmic convergence thresholds;
4. reference-algorithm comparison tolerance;
5. exact mapping metadata.

---

## R0.9 — WCAG relative luminance and contrast

### Standards semantics

WCAG 2.2 defines sRGB relative luminance using:

```text
threshold:
    0.04045

weights:
    0.2126
    0.7152
    0.0722
```

The R0.9 experiment deliberately uses the published WCAG weights rather than
silently substituting the XYZ-D65 Y coefficients.

### Exact/domain properties

The experiment separately tests:

```text
valid WCAG domain
invalid WCAG domain
validity/status results
known identity/extreme cases
```

Some wrapper/status behavior is exact.

### Numerical properties

Candidate luminance values are compared with a direct WCAG reference path using
the shared abs-or-relative comparator.

The experiment also intentionally demonstrates that:

```text
WCAG luminance
!=
XYZ-D65 Y
```

for general colors despite their conceptual relationship.

### Reference provenance

WCAG 2.2 is the standards-facing authority for this operation.

Its current definition uses the `0.04045` threshold; the older `0.03928`
threshold is historical and must not silently re-enter the reference data.

### R0.13 action

```text
R0.13-C
```

Must establish:

- exact domain/status properties;
- standards-derived reference comparisons;
- branch-boundary tests;
- contrast identity/extreme cases;
- inherited transfer-function numerical error.

---

## R0.10 — deltaEOK

### Exact analytical cases

The research already demonstrates exact/simple cases including:

```text
distance(x, x) == 0
selected Pythagorean case == 13
special NaN/infinity semantics
```

Where the implementation and arithmetic establish exactness, these must not be
weakened into approximate checks.

### Property tolerance

Historical property tests used:

```text
double:
    1e-12

float:
    2e-5
```

as absolute test tolerances.

These are provisional R0.10 values.

### Higher-precision reference comparison

The experiment computes an independent implementation route in D `real` and
compares against:

```text
8 * T.epsilon * max(1, abs(reference))
```

The final observed worst normalized deviation was well below that provisional
bound.

### Reference independence

The `real` route is useful because it changes intermediate precision and is
implemented separately.

It is not an external standard.

Therefore it is:

```text
independent implementation reference
```

rather than:

```text
normative external reference
```

### R0.13 action

```text
R0.13-C
```

Must determine:

- which analytical properties remain exact;
- whether the `real` reference route remains suitable;
- whether epsilon-scaled error is the right model;
- whether ULP characterization adds useful evidence;
- whether the 8× margin is justified or merely conservative.

---

## R0.11 — tone scales

R0.11 provides strong evidence for the exact-comparison class.

Examples include:

```text
component assignment
stored hue preservation
fixed cardinality
exact endpoints
equal-endpoint constant schedules
matching raw anchors
family decomposition
caller-output versus static-array representation
```

These are intentionally tested by exact equality.

No numerical tolerance is required merely because the stored scalar type is
floating point.

### R0.13 action

```text
R0.13-A / R0.13-F
```

Preserve these as canonical examples of:

```text
floating-point value
+
exact semantic property
=
exact comparison
```

---

## R0.12 — palette / CTFE integration

### Exact cross-execution properties

R0.12 established exact equality for the tested:

```text
raw runtime palette ↔ CTFE raw palette
Ray Trace success metadata
Ray Trace iteration metadata
enum CTFE ↔ static immutable materialization
independent family preservation
```

### Non-exact cross-execution values

After floating-point gamut mapping and encoding, runtime and CTFE results were
not bit-for-bit equal.

Observed maximum absolute component differences included approximately:

```text
float:
    mapped   2.9206276e-06
    encoded  1.5497208e-06

double:
    mapped   1.332e-15
    encoded  8.882e-16
```

These are measurements.

They are not tolerance constants.

### R0.13 action

```text
R0.13-E
```

Must determine:

- error shape;
- absolute error;
- relative error where meaningful;
- ULP distance where meaningful;
- compiler/build variation;
- runtime/CTFE acceptance policy.

---

# 5. Reference provenance inventory

## 5.1 sRGB transfer/colorimetry

Current repository status:

```text
R0.2:
    standard transfer equations
    CSS examples

R0.3:
    CSS Color 4 rational conversion matrices
```

R0.13-A provenance decision:

```text
IEC 61966-2-1 defines the underlying sRGB colorimetry.

The pinned CSS Color 4 snapshot provides the reproducible high-precision
rational sRGB <-> XYZ D65 matrices used as the numerical matrix reference.

ICC registry material independently exposes the IEC-defined primaries,
D65 white point and transfer function for public verification.
```

CSS conversion code is therefore a standards-facing numerical reference and
independent implementation route; it does not replace IEC as the normative
authority for the sRGB color space.

Status:

```text
PROVENANCE RESOLVED IN R0.13-A
```

---

## 5.2 CSS Color Module Level 4

Pinned R0.13 snapshot:

```text
W3C Candidate Recommendation Draft
13 September 2026
https://www.w3.org/TR/2026/CRD-css-color-4-20260913/
```

This dated snapshot is used because CSS Color 4 continues to evolve.

It is relevant to:

```text
sRGB / XYZ conversion samples
Oklab conversion samples
hue interpolation
powerless-component semantics
color equivalence
gamut mapping
```

The snapshot contains an especially important R0.13 example:

```text
same color space:
    small implementation-defined epsilon

different color spaces:
    convert to Oklab
    standardized Oklab epsilon = 0.00001

OkLCh powerless hue after conversion:
    C <= 0.000004
```

These thresholds answer different CSS semantic questions.

They are not evidence for one generic color-d epsilon.

The same snapshot permits:

```text
Binary Search Gamut Mapping with Local MINDE
EdgeSeeker Gamut Mapping
Ray Trace Gamut Mapping
```

Status:

```text
NORMATIVE
DATED SNAPSHOT PINNED
SEMANTIC EPSILONS MUST REMAIN SCOPED
```

---

## 5.3 Oklab primary publication

Björn Ottosson's Oklab publication provides the direct linear-sRGB/Oklab
reference equations used by R0.4.

The publication records the matrices as updated on:

```text
2021-01-25
```

using higher-precision sRGB/D65 values.

Status:

```text
PRIMARY
```

R0.13-B should pin the exact coefficients used.

---

## 5.4 W3C Compositing and Blending

The W3C Compositing and Blending specification defines simple alpha
compositing and source-over equations, including the premultiplied form.

Status:

```text
NORMATIVE
```

R0.13-C should replace vague "W3C-style vector" provenance with an exact
source/formula reference where practical.

---

## 5.5 WCAG 2.2

WCAG 2.2 directly defines the sRGB relative-luminance equation used by R0.9.

Current formula:

```text
threshold = 0.04045

L =
    0.2126 * R +
    0.7152 * G +
    0.0722 * B
```

Status:

```text
NORMATIVE
```

---

## 5.6 R0.10 wider-precision reference

The `real` deltaEOK implementation is:

```text
independently implemented
higher intermediate precision
internal to the experiment
```

It is not an external authority.

Status:

```text
INDEPENDENT_IMPLEMENTATION
NOT EXTERNAL AUTHORITY
```

---

## 5.7 R0.12 runtime/CTFE comparison

Runtime and CTFE execute the same mathematical implementation under different
evaluation environments.

Therefore runtime-versus-CTFE comparison is:

```text
cross-execution characterization
```

not:

```text
independent mathematical reference
```

Status:

```text
CROSS_EXECUTION
```

---

# 6. Independence levels

R0.13-A proposes the following provenance labels.

## NORMATIVE

A standard/specification directly defines the property or equation.

Example:

```text
WCAG 2.2 relative luminance
```

## PRIMARY

The defining publication/source of a color model or algorithm.

Example:

```text
Ottosson Oklab publication
```

## INDEPENDENT_IMPLEMENTATION

A separately implemented route computes the same mathematical quantity.

Examples:

```text
direct linear-sRGB → Oklab comparator
R0.10 real-precision deltaEOK route
```

## STANDARDS_SAMPLE

Example or sample implementation accompanying a standard.

Example:

```text
CSS Color conversion sample code
```

Useful, but not automatically the normative definition of underlying
colorimetry.

## INTERNAL_REGRESSION

A value already validated in earlier color-d research.

Useful for regression continuity.

Not independent evidence by itself.

## CROSS_EXECUTION

The same implementation evaluated through:

```text
runtime
CTFE
different compiler
different build mode
```

Useful for portability characterization.

Not an independent mathematical reference.

---

# 7. Exact-property candidates for R0.13

The inventory supports retaining exact comparison for at least the following
classes, subject to phase-specific confirmation:

```text
type/representation invariants
cardinality
copied components
stored raw components
preserved endpoints
explicit raw anchors
status booleans
iteration counts
strict finite/domain classifications
strict gamut classification
clip idempotence
exact-achromatic c == 0
selected algebraic identities
deltaEOK(x, x) == 0
same-color contrast identity where arithmetic guarantees it
```

Important:

This list identifies candidate exact semantic properties.

R0.13 must still verify whether the actual production formulation preserves
each exact property.

---

# 8. Approximate-comparison candidates

The inventory identifies these broad numerical classes:

```text
transcendental transfer functions
matrix transform reference values
matrix round trips
cube-root Oklab transforms
trigonometric polar transforms
premultiply/unpremultiply round trips
source-over general reference vectors
floating-point associativity observations
interior interpolation arithmetic
gamut-mapped color coordinates
deltaEOK general reference comparison
runtime/CTFE post-transformation values
compiler-cross post-transformation values
```

No common threshold is inferred.

---

# 9. Explicit-policy candidates

These are not ordinary implementation-error tolerances:

```text
near-achromatic threshold
epsilon-aware gamut boundary query
consumer-defined numerical proximity
```

The threshold changes the question being asked.

Therefore:

```text
strict predicate
!=
policy predicate
```

---

# 10. Algorithmic-threshold candidates

These affect algorithm behavior rather than test acceptance:

```text
Local MINDE search epsilon
Ray Trace epsilon
gamut-mapping iteration/convergence conditions
JND-related mapping threshold
```

R0.13 must document them separately from test comparison policy.

A value may legitimately appear in both an algorithm and a test only when the
relationship is explicit and justified.

---

# 11. Historical tolerance status

The following historical forms are all provisional:

```text
R0.2–R0.6:
    operation-local abs/relative constants

R0.7:
    representative absolute 1e-12 checks

R0.8:
    research-local comparison tolerances
    plus distinct algorithmic thresholds

R0.9:
    standards-reference comparisons through abs/relative helper

R0.10:
    double property tolerance 1e-12
    float property tolerance 2e-5
    reference tolerance 8*T.epsilon*max(1, abs(reference))

R0.12:
    no tolerance selected for runtime/CTFE mapped/encoded drift
```

R0.13 must not promote any of these merely because they were previously
sufficient.

---

# 12. Immediate unresolved questions

## Q1 — exact versus approximate transfer endpoints

Should values such as:

```text
sRGB 0 → linear 0
sRGB 1 → linear 1
```

be required exactly by the production implementation, or merely numerically
close because of the chosen generic formulation?

This must be answered semantically and empirically.

## Q2 — matrix-reference authority

Resolved in R0.13-A.

IEC 61966-2-1 anchors the underlying sRGB colorimetry. The exact rational
sRGB <-> XYZ D65 matrices in the pinned CSS Color 4 snapshot anchor the
reproducible high-precision numerical matrix reference used by R0.13-B.

This deliberately separates normative color-space authority from the numerical
reference representation. CSS sample code does not become the normative
definition of sRGB.

## Q3 — Oklab dual references

How should the difference between:

```text
XYZ-based path
direct Ottosson linear-sRGB path
```

be treated when both represent the intended color transform but use different
coefficient routes?

## Q4 — angle comparison

Ordinary scalar difference is not sufficient for all hue comparisons.

R0.13-C must decide whether test infrastructure needs an explicit angular
distance/equivalence helper.

## Q5 — relative error near zero

Relative error is ill-conditioned when the reference is zero or very small.

The absolute floor, if any, must be operation-specific.

## Q6 — ULP usefulness

No previous R0 block establishes ULP guarantees.

R0.13 must determine empirically whether ULP distance is useful as:

```text
diagnostic measurement
regression criterion
portable contract
```

These are distinct decisions.

## Q7 — compiler/runtime drift

R0.12 demonstrates that runtime and CTFE can differ while preserving the tested
semantic result.

R0.13-E must determine whether those differences are:

```text
normal rounding variation
operation-specific implementation differences
compiler-specific behavior
```

before defining acceptance rules.

## Q8 — algorithm tolerance versus test tolerance

R0.8 proves that the same word "epsilon" can describe fundamentally different
things.

R0.13 terminology must prevent accidental reuse of an algorithmic stopping
threshold as a generic test tolerance.

---

# 13. Phase-A provisional conclusions

The existing evidence already supports:

1. There is no evidence for one universal epsilon.
2. Floating-point storage does not imply approximate comparison.
3. Exact semantic properties should remain exact.
4. Strict classification and approximate policy classification are different
   APIs/questions.
5. Historical tests use multiple comparison forms and multiple threshold
   scales.
6. The shared `approxEqual` syntax does not prove a shared numerical contract.
7. Absolute-only comparison is useful for some historical tests but is not a
   universal model.
8. Relative comparison requires explicit near-zero handling.
9. R0.10 already demonstrates the value of separating property tolerance from
   reference-implementation tolerance.
10. Runtime/CTFE equality is property-specific.
11. Reference provenance and reference independence must be recorded explicitly.
12. Algorithm-internal epsilon/convergence values form a separate category from
    numerical comparison tolerance.
13. ULP distance remains unvalidated as a contract.
14. `float` and `double` require separate characterization.
15. No production comparison helper is yet justified.

---

# 14. R0.13-A closure

R0.13-A is validated.

The phase now has:

```text
a comparison taxonomy separating seven distinct comparison concepts
a consolidated and classified source registry
a pinned CSS Color 4 snapshot
resolved sRGB/D65 matrix provenance
explicit alpha/compositing provenance
an operation × property × comparison-class matrix
a reviewed R0.13-B–E probe plan covering the inventoried operation families
```

The unresolved numerical questions assigned to R0.13-B–E remain intentionally
open for those phases; they do not block R0.13-A closure.

No numerical threshold is frozen by this inventory.
