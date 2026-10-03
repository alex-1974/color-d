# Accuracy and validation

## Scalar contract

The current public computational scalar types are `float` and `double`.
They are validated separately. D `real` is not part of the initial public
contract because its representation and precision are platform-dependent.

## 8-bit storage conversion

`SRgb8` and `SRgba8` use the full unsigned-byte range as normalized
encoded-sRGB/straight-alpha storage.

Storage-to-computation maps a byte `c` to `c / 255` in the requested
`float` or `double` scalar type.

Checked computation-to-storage accepts only finite components in inclusive
`[0, 1]`. Accepted components are multiplied by 255 and rounded to the
nearest byte with exact half steps choosing the larger byte. Invalid input
fails without modifying caller-owned destination storage.

Every possible byte value is exhaustively tested to survive
storage -> float/double -> storage round trips.

No implicit clipping, gamut mapping, alpha premultiplication, or special-value
repair is part of the storage conversion contract. See ADR 0006.

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
- XYZ D65 → linear-sRGB: the former direct implementation produced 42
  avoidable non-finite results among 111 reference-representable retained
  extreme-grid cases for each scalar width. The promoted hybrid implementation
  reduces the observed count to zero.

The inverse XYZ transform deliberately uses different numerically equivalent
evaluation strategies for the two public scalar widths:

- `float` preserves the original direct-matrix evaluation for ordinary finite
  results. Only a non-finite direct result from finite XYZ input enters a
  normalized scaled fallback. Two million ordinary audit samples were
  bit-identical to the former production result.
- `double` uses an exact rational dominant-factor refactorization. On two
  million ordinary audit samples it changed the final rounding of many values,
  but reduced both measured mean absolute error and maximum absolute error
  against the wider `real` reference. The retained subnormal corpus can differ
  by a few ULPs; signed-zero and non-finite classification remained unchanged.

The hybrid was selected over a bit-identical result-gated `double` fallback
because the latter retained roughly 15% ordinary-path overhead on the LDC
release-performance compiler, while the dominant-factor `double` route was
slightly faster than the former direct implementation in the isolated audit.

These counts and error comparisons describe the retained deterministic audit
corpora. They do not claim exhaustive proof over all finite IEEE values.

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
- CIE 1976 L*a*b* and Delta E 1976 follow ISO/CIE 11664-4. The production
  `CieLabD50` type makes the D50 reference white explicit; XYZ D65 ↔ CIELAB
  conversion includes the explicit linear Bradford adaptation.
- CIEDE2000 follows ISO/CIE 11664-6 and is validated against the Sharma/Wu/Dalal
  supplementary reference data.

## Evidence

This page states the maintained numerical policy that package users may rely
on. Detailed experiment drivers, raw measurements, compiler probes, and
historical research notes are maintainer evidence and are intentionally not
shipped in the consumer package.
