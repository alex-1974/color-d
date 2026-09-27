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

## Extreme finite conversion closure

The public computational types accept extended floating-point values; that does
not imply that every finite IEEE input can pass through every matrix transform
without an intermediate overflow.

The pre-v0.1 extreme-finite audit evaluated deterministic grids with a wider
reference route on DMD 2.113.0 and LDC 1.43.0:

- linear-sRGB → XYZ D65: no avoidable non-finite result was observed in the
  tested grid;
- XYZ D65 → Oklab: the former direct LMS path produced 58 avoidable non-finite
  results among 729 reference-representable cases for each scalar width; the
  production result-gated scaled fallback reduces the observed count to zero;
- Oklab → XYZ D65: no avoidable non-finite result was observed in the tested
  grid;
- XYZ D65 → linear-sRGB: 42 of 111 reference-representable extreme cases
  currently become non-finite because individual inverse-matrix terms can
  overflow before cancellation.

The last case is a documented exceptional-domain limitation, not clipping or
gamut mapping. A scaled candidate removes the observed failures but currently
adds roughly 22–43% to the ordinary conversion hot path, so it has not been
adopted. The lower-overhead production follow-up is tracked separately.

These counts describe the retained deterministic audit corpus. They do not
claim exhaustive proof over all finite IEEE values.

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
