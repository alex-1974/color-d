# Accuracy and validation

## Scalar contract

The current public computational scalar types are `float` and `double`.
They are validated separately. D `real` is not part of the initial public
contract because its representation and precision are platform-dependent.

## No universal epsilon

color-d does not define one floating-point tolerance. Each tested property uses
the comparison contract appropriate to that property.

The accepted classes are:

- **EXACT** — equality where exactness is the semantic contract;
- **CLASSIFY** — strict set/domain classification without hidden widening;
- **REFERENCE** — comparison to a normative, analytical, or independently
  implemented reference;
- **DERIVED** — round-trip or composition properties;
- **CROSS** — observations across CTFE/runtime, compilers, or build modes;
- **POLICY** — explicit thresholds that change the semantic question;
- **ALGORITHM** — internal convergence/search thresholds.

A POLICY or ALGORITHM threshold is never reused as a general comparison
epsilon.

## Reference hierarchy

Reference tests prefer:

1. normative standard or defining primary source;
2. independently derived analytical value;
3. independent higher-precision or implementation route;
4. pinned standards sample;
5. validated internal regression fixture.

Self-round-trips are useful derived tests but are not independent references.

## CTFE versus runtime

CTFE support is an execution-mode contract where claimed, but bit identity is
not assumed for every floating-point path. Tests apply the property-specific
numerical contract and explicitly protect cases where exact equality is part of
the API.

## Important standards and provenance

- sRGB transfer and RGB/XYZ behavior are validated against the accepted
  sRGB/CSS reference model used by the R0.2/R0.3 research.
- Oklab/OKLCH conversion follows the published Oklab model validated in R0.4
  and R0.5.
- OKLCH hue paths follow the CSS Color 4 shorter/longer/increasing/decreasing
  angular policies validated in R0.7.
- Local MINDE and Ray Trace are explicit CSS Color 4 gamut-mapping strategies
  validated in R0.8.
- WCAG functions implement the WCAG 2.2 sRGB measurement model validated in
  R0.9; WCAG relative luminance is deliberately distinct from XYZ D65 Y.
- `deltaEOK` is Euclidean Oklab distance as described by CSS Color 4 and
  independently validated in R0.10.

## Evidence

The durable numerical policy is
[`../experiments/r0_13_numerical_tolerance_reference/POLICY.md`](../experiments/r0_13_numerical_tolerance_reference/POLICY.md).
Research inputs and measured results remain under `docs/research/` and
`experiments/`.
