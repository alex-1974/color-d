# ADR 0005 — Use property-specific numerical validation

**Status:** Accepted

## Context

One global epsilon cannot correctly describe exact identities, strict gamut
classification, reference-vector accuracy, round trips, portability
differences, policy thresholds, and algorithm convergence.

## Decision

Use property-specific comparison classes: EXACT, CLASSIFY, REFERENCE, DERIVED,
CROSS, POLICY, and ALGORITHM. Validate `float` and `double` separately.
Do not expose a generic library-wide `approxEqual`.

## Consequences

Tests state what kind of numerical promise they are protecting. Internal
algorithm thresholds and application policy cannot silently become public
accuracy tolerances.

The maintained user- and release-facing numerical policy is documented in
[`../accuracy-and-validation.md`](../accuracy-and-validation.md). Detailed
historical experiments and raw evidence remain research material and are not
required to apply this ADR.
