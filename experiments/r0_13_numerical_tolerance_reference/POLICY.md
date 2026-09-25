# R0.13-F — Production test and API numerical policy

**Status:** VALIDATED
**Parent:** R0.13
**Document revision:** 1.0
**Date:** 2026-09-25

This document is the durable R0.13 handoff for R1 production work.

The core decision is:

```text
color-d does not have one floating-point tolerance.

Each tested property selects its comparison contract from the semantics of
that property, the reference provenance and the scalar type.
```

Observed maxima from research are evidence. They are not automatically test
thresholds.

## 1. Final comparison classes

Production tests use seven distinct concepts:

```text
EXACT
    bit/value equality where the semantic contract itself is exact

CLASSIFY
    strict domain or set membership with no hidden numerical widening

REFERENCE
    comparison against a normative, analytical or independently implemented
    numerical reference

DERIVED
    round-trip, composition, interpolation, associativity or other derived
    floating-point property

CROSS
    portability observation across runtime/CTFE, build modes and compilers

POLICY
    explicit threshold that changes the semantic question being asked

ALGORITHM
    convergence, search or execution threshold internal to an algorithm
```

`POLICY` and `ALGORITHM` values must never be reused as generic comparison
epsilons merely because they are numerical thresholds.

## 2. Exact properties

Use direct equality only where exactness is part of the intended implementation
contract.

Current promoted exact-property classes include:

```text
structurally copied components such as alpha
raw palette/tone components and cardinality
explicitly implemented interpolation endpoints
exact hue-path and 180-degree tie decisions
exact C == 0 achromatic semantics and hue borrowing rules
selected canonical alpha/compositing identity branches
sRGB zero endpoint where structurally preserved
linear-RGB/XYZ/Oklab black-to-zero identities where structurally preserved
deltaEOK(x, x) == 0
selected exactly representable analytical deltaEOK cases
selected same-color contrast identity == 1
clip boundary/idempotence where clamp semantics make it exact
fixed algorithm work limits where the limit itself is the contract
```

Do not promote an identity to `EXACT` solely because current compilers happened
to produce exact bits. The implementation structure and semantic requirement
must justify it.

Signed zero is not globally bit-significant. A test may require its sign only
when the specific operation contract says so.

## 3. Strict classifications

Strict predicates remain strict.

Examples:

```text
finite-domain validation
alpha in [0, 1]
sRGB / linear-sRGB measurement domain
strict sRGB gamut membership
exact achromaticity C == 0
```

These predicates do not absorb a comparison epsilon.

If a caller needs proximity to a boundary, that is a separate `POLICY`
question and must be explicit in the API.

Therefore:

```text
inGamut(value)
    !=
inGamut(value, callerSelectedBoundaryEpsilon)
```

The exact spelling remains an API-design decision, but the semantic separation
is frozen.

## 4. Reference comparisons

`REFERENCE` tests prefer references in this order:

```text
1. normative standard / defining primary source
2. independently derived analytical value
3. independent higher-precision or independently implemented route
4. standards sample with pinned version
5. validated internal regression fixture
```

Cross-execution output and self-round trips are not independent references.

For reference comparisons:

- use an absolute term near zero or where the quantity has a natural bounded
  scale;
- use a relative term only where scaling by magnitude is meaningful;
- a combined absolute/relative rule is permitted when both parts have an
  operation-specific justification;
- do not infer either term from the largest observed sample error alone;
- record the source, version/formula, input, precision and provenance class.

Reference-route discrepancies are not implementation rounding error. In
particular, the direct Ottosson linear-sRGB -> Oklab route and the production
XYZ-based coefficient route remain distinct evidence paths.

## 5. Derived numerical comparisons

`DERIVED` properties use operation-local acceptance rules distinct from direct
reference tests.

Examples:

```text
encode/decode round trips
matrix round trips
Oklab/OKLCH Cartesian-polar round trips
premultiply/unpremultiply round trips
source-over associativity observations
interior interpolation
mapped-color idempotence after conversion
```

A direct-reference envelope must not be reused automatically for a round trip,
and a round-trip envelope must not be reused for a different composition.

Range failure is not tolerance error. Overflow, underflow with information
loss, NaN from an avoidable intermediate overflow, or failure to preserve an
explicit endpoint must be handled as range/algorithm behavior rather than by
widening a numerical comparator.

## 6. Angular comparisons

Hue is circular.

Non-exact hue values are compared using wrapped angular distance rather than
ordinary scalar subtraction:

```text
d = abs(normalizeToSigned180(actual - expected))
```

Equivalent angles across the 0/360 seam must therefore compare by their short
angular separation.

Exact hue-policy decisions and exact tie rules remain `EXACT`; this angular
metric applies only to derived/reference angle values.

## 7. ULP policy

ULP distance is retained as a diagnostic and regression-analysis tool.

It is not a general portable correctness contract.

R0.13 observed cases where:

- near-zero values make ULP/relative interpretation misleading;
- different reference routes create discrepancies much larger than ordinary
  rounding;
- DMD/LDC or Debug/Release can differ by low ULP counts while satisfying the
  same semantic contract;
- equal ULP maxima can coexist with different maximum absolute errors.

Therefore no production operation receives a generic `N ULP` acceptance rule
from R0.13.

A future operation may adopt a ULP regression bound only with direct evidence
that target-type rounding itself is the intended contract.

## 8. Scalar policy

`float` and `double` are tested separately.

Do not derive one threshold by mechanically scaling the other.

For each operation-specific approximate test, record or derive separately:

```text
scalar type
reference magnitude/domain
absolute behavior
relative behavior where meaningful
ULP diagnostics where useful
special-value behavior
cross-execution observations
```

`real` may be used as local wider-precision diagnostic evidence where it is
wider than `double`; it is not portable ground truth.

## 9. Special values

NaN, infinity and signed zero are semantic cases, not ordinary approximate
numbers.

Tests must state the intended behavior explicitly.

Examples established by R0.13 include:

```text
deltaEOK:
    NaN delta -> NaN
    otherwise infinite delta -> +Inf
    NaN takes precedence over infinity

strict gamut/domain predicates:
    non-finite input is outside the valid domain

clipping:
    does not silently repair non-finite input
```

A generic approximate comparator must not silently define special-value
equivalence.

## 10. Cross-execution policy

Runtime/CTFE, Debug/Release, compiler-family and compiler-version comparisons
reuse the same property-specific contracts above.

Cross-execution is not a new tolerance class.

Derived coordinates need not be bit-identical. Exact semantic properties still
must remain exact. Strict classifications remain strict.

Path-dependent algorithm metadata is portable only if independently promoted
as part of the semantic contract. The Ray Trace `success` flag is specifically
not such a portable color-result contract under the current research evidence.

No DMD-, LDC-, CTFE-, Debug-, Release- or compiler-version-specific epsilon is
introduced.

## 11. Operation-family production test strategy

| Operation family | Production test strategy |
|---|---|
| sRGB transfer | exact structural endpoints where guaranteed; targeted branch-boundary probes; normative/reference comparison for ordinary values; separate derived round trip |
| linear sRGB <-> XYZ D65 | exact black-to-zero; pinned rational/reference vectors for ordinary and extended values; separate round-trip tests |
| XYZ D65 <-> Oklab | exact black-to-zero; same-route reference comparison; keep direct Ottosson route as provenance/route comparator, not drop-in oracle |
| Oklab <-> OKLCH | exact achromatic semantics; wrapped angular reference comparison for non-achromatic hue; separate Cartesian/polar round trip |
| alpha/premultiplication | exact canonical identity branches; explicit alpha domain classification; wider/reference arithmetic for general vectors; tiny-alpha loss as range behavior |
| source-over | exact canonical identity cases; W3C formula/reference vectors for general cases; associativity only as derived observation |
| interpolation | exact endpoints and hue-policy decisions; reference/derived comparison for interior values; overflow behavior tested separately from tolerance |
| gamut classification | strict finite [0,1] target-space predicate; explicit caller-policy helper only for proximity queries |
| clipping | exact clamp semantics for finite values; non-finite behavior explicit; idempotence exact where structurally guaranteed |
| Local MINDE | algorithm thresholds tested as algorithm semantics; mapped result must satisfy strict target gamut; coordinates compared only within algorithm-specific regression/reference tests |
| Ray Trace | fixed work budget tested as algorithm contract; `success` treated as diagnostic/path metadata unless future API semantics promote it; mapped result strict in gamut |
| WCAG | strict measurement domain; exact black/white luminance and same-color identity where guaranteed; normative reference comparison for general luminance/contrast; 21:1 is REFERENCE, not universal EXACT |
| deltaEOK | exact identity and representable analytical cases; explicit NaN/Inf policy; wider independent reference for general finite values; ULP diagnostic only |
| palette/CTFE | raw structural values exact; mapped/encoded values judged by their underlying operation contracts; no CTFE-specific epsilon |

## 12. Test-helper ownership

R0.13 selects **Outcome A** for generic comparison machinery:

```text
generic approximate comparison helpers remain test/research infrastructure
```

There is no evidence for a public `color-d` function such as a universal
`approxEqual`, global epsilon constant, generic color tolerance object, or
compiler-specific numerical policy.

Test infrastructure may provide narrowly named helpers such as:

```text
absoluteDifference
relativeDifference
ulpDistance
wrappedAngularDifference
operation-local abs/rel acceptance
```

but their presence in test code does not create a shared numerical contract.

Internal production numerical mechanisms required to implement mathematics
robustly, such as a baseline-specific `hypot` compatibility path, are separate
from public comparison API.

## 13. Runtime policy APIs

R0.13 does preserve the possibility of explicit public policy-bearing APIs
when the threshold is itself part of the user's question.

Current examples are:

```text
near-achromatic classification
numerical proximity to a gamut boundary
```

Such APIs must:

- take the policy/threshold explicitly;
- document its units and semantic meaning;
- not change the strict predicate;
- not reuse a generic global epsilon by default.

R0.13 does not freeze their final names.

## 14. CI / portability rule

Correctness CI should cover the baseline compilers and representative later
versions in both Debug and Release where numerical optimization can matter.

The baseline remains:

```text
DMD 2.111.0
LDC 1.41.0
```

The R0.13 evidence matrix additionally covered:

```text
DMD 2.112.0
DMD 2.112.1
DMD 2.113.0
LDC 1.42.0
LDC 1.43.0
```

Compiler/version drift is diagnosed against property-specific tests rather than
against a golden byte dump of all derived floating-point outputs.

## 15. R1 / R0.14 handoff

R1 production tests should be organized by property class, not by one shared
epsilon helper.

Every approximate production test must answer:

```text
What property is being tested?
What is the reference source?
Why is exact equality inappropriate?
Why is this comparison form appropriate?
How are near-zero values handled?
How are NaN/Inf/signed zero handled?
Is the rule scalar-specific?
Is the threshold semantic, algorithmic, or merely test acceptance?
```

R0.14 should reject a v0.1 promotion if any production numerical test relies on
an unexplained magic epsilon, treats a policy threshold as generic precision,
or weakens an exact semantic property to make a test pass.

## 16. Final decision

R0.13-F validates the original central hypothesis:

> color-d requires a taxonomy of comparison contracts rather than one global
> floating-point epsilon.

No universal epsilon is adopted.

No generic approximate comparator is promoted into the public API.

ULP remains diagnostic unless future operation-specific evidence justifies a
narrow contract.

Explicit policy thresholds remain explicit user/specification semantics.

Production correctness is defined by property-specific contracts with recorded
reference provenance and separate `float`/`double` characterization.
