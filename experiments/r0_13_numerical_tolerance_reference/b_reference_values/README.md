# R0.13-B — Reference-value characterization

**Status:** EXPERIMENT
**Parent:** R0.13 — Numerical tolerance and reference policy
**Document revision:** 0.3
**Date:** 2026-09-25
**GitHub:** #9

## Purpose

R0.13-B characterizes numerical error for the reference-value rows identified by the validated R0.13-A matrix. It measures behavior before any production tolerance is selected.

The experiment keeps candidate arithmetic, reference arithmetic, and reporting separate. Historical `approxEqual` helpers from R0.2–R0.4 are not reused.

## Completed scope

B1 covers the sRGB transfer functions, including exact-zero candidates, branch-boundary probes, ordinary and extended finite values, and encode/decode round trips. B2 covers both directions of linear sRGB and XYZ D65, including black, primaries, white, ordinary and extended finite values, RGB -> XYZ -> RGB round trips, and independent derivation of the matrices from IEC/ICC chromaticities. B3 covers XYZ D65 to and from Oklab, ordinary and extended finite values, XYZ and Oklab round trips, and an RGB-origin route comparison against the direct 2021 Ottosson coefficients.

`real` is a diagnostic higher-precision path only when it is wider than `double`; it is not treated as portable ground truth. The harness records scalar precision so results remain interpretable across compiler and platform runs.

## Evidence classes used

The harness deliberately keeps different kinds of evidence separate.

- `EXACT` checks algebraic or representational candidates that should not need tolerance. B3 black -> Oklab zero is exact for both tested scalar types.
- `REFERENCE` compares production-style arithmetic with a higher-precision or independently derived reference path.
- `DERIVED` characterizes round trips. A round-trip envelope is not an independent-reference envelope.
- The direct Ottosson linear-sRGB -> Oklab path is a provenance and route-consistency comparator. It is not a precision oracle for the production RGB -> XYZ -> Oklab route.

## Observed results

### B1 — sRGB transfer

Ordinary encode/decode probes behave at the expected scalar precision. The exceptional case is the transfer-boundary round trip: the published rounded thresholds `0.04045` and `0.0031308` are not exact inverse images. The observed boundary discrepancy is therefore structural rather than ordinary floating-point drift. In the captured run it is about `2.24e-8` for `float` and `2.96e-8` for `double`; the latter corresponds to billions of ULPs despite the small absolute difference.

This boundary case must not inflate a generic transfer tolerance.

### B2 — linear sRGB <-> XYZ D65

The independently derived IEC/ICC matrix and the pinned CSS rational matrix agree at roughly `1e-20` to `1e-19` in the local wider `real` diagnostic path.

For ordinary non-zero components, production-style `double` matrix evaluations stay within a few ULPs of the higher-precision reference. `float` is similarly close for direct reference comparisons, while composed round trips can accumulate more error; the ordinary float RGB round trip reaches 10 ULPs in the captured probes.

Components whose mathematical reference is zero demonstrate why ULP and relative error cannot be universal acceptance metrics: tiny residuals near zero can have enormous ULP distances while remaining small in absolute terms.

### B3 — XYZ D65 <-> Oklab

Black -> Oklab zero is exact for both `float` and `double` in the tested implementation.

Against the same published CSS coefficient route evaluated through the wider `real` diagnostic path, ordinary and extended `float` probes show errors at float scale. The observed round-trip and inverse cases reach up to 13 ULPs and absolute error of roughly `3.6e-7`. For `double`, composed inverse and round-trip probes reach up to 27 ULPs while absolute error remains approximately `1e-15` or smaller.

D65 white is an important near-zero example. Finite published coefficients do not force the computed Oklab `a` and `b` components to be exactly zero in every scalar evaluation. Relative and ULP diagnostics therefore become misleading for these near-zero components; exact white neutrality is not established as an equality contract by this experiment.

The direct Ottosson RGB route exposes a separate coefficient-route discrepancy. In `double`, differences remain on the order of `3e-9` to `3.7e-8`, producing tens of millions to billions of ULPs. These differences are far above ordinary double rounding error and arise from comparing different published coefficient routes. The direct route must therefore not be used to choose the acceptance tolerance for the production XYZ-based implementation. At `float` precision the same route discrepancy is largely masked by scalar rounding, but its semantic classification does not change.

Extended probes with negative XYZ or Oklab components remain finite and exercise the sign-preserving cube-root path without exposing a domain failure.

## Cross-compiler observation

The captured DMD and LDC runs on the tested x86_64 Linux environment produced the same reported B1, B2, and B3 values. This is evidence for the current setup only; it is not a portable compiler-equivalence guarantee.

## Comparison-policy consequences

R0.13-B supports the R0.13-A hypothesis that color-d needs property-specific comparison contracts rather than one universal epsilon or one universal ULP budget.

- Exact candidates remain exact unless separate evidence disproves them.
- Independent reference comparisons, derived round trips, near-zero properties, branch-boundary behavior, and cross-route comparisons require distinct treatment.
- Near zero, absolute error or a property-specific zero policy is primary; relative error and ULP distance are diagnostic only.
- Round-trip tolerances must be derived independently from direct reference tolerances.
- Structural specification discontinuities and coefficient-route discrepancies must be documented instead of absorbed into a looser generic tolerance.
- A tolerance chosen for one scalar type or operation must not be copied automatically to another.

## Status of thresholds

No production numerical threshold is frozen by this experiment. The measured envelopes are characterization evidence for the next R0.13 step, where candidate per-property acceptance rules can be proposed and then validated without turning the largest observed outlier into a universal tolerance.
