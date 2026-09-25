# R0.13 — Reference source registry

**Status:** VALIDATED
**Parent:** R0.13
**Document revision:** 0.3
**Date:** 2026-09-25
**GitHub:** #9

This document records the external and independent sources used to establish
numerical-reference provenance for R0.13. R0.13-A established the source
registry; R0.13-B adds validated evidence about how selected sources may and
may not be used as numerical comparators.

A reference source does not automatically establish a comparison tolerance.

---

# 1. Source classes

R0.13 uses:

```text
NORMATIVE
PRIMARY
INDEPENDENT_IMPLEMENTATION
STANDARDS_SAMPLE
INTERNAL_REGRESSION
CROSS_EXECUTION
```

as defined by `INVENTORY.md`.

A dated standards snapshot is preferred where specification evolution could
change regression semantics.

---

# 2. sRGB

## Normative definition

```text
IEC 61966-2-1:1999
Multimedia systems and equipment —
Colour measurement and management —
Part 2-1: Colour management —
Default RGB colour space — sRGB
```

Official IEC publication:

```text
https://webstore.iec.ch/en/publication/6169
```

The IEC publication page states that the currently supplied base publication
includes the January 2014 corrigendum.

Related publication:

```text
IEC 61966-2-1:1999/AMD1:2003
https://webstore.iec.ch/en/publication/6168
```

Classification:

```text
NORMATIVE
```

## Public technical registry

International Color Consortium:

```text
https://registry.color.org/rgb-registry/srgb
```

The ICC registry identifies the definition as:

```text
IEC 61966-2-1:1999
```

and publicly records the sRGB primaries, D65 white point and component transfer
function.

Role:

```text
SUPPORTING REGISTRY MATERIAL
NOT A R0.13 PROVENANCE CLASS
```

For R0.13 it is useful supporting material, but the IEC publication remains the
underlying normative source.

## Numerical sRGB/D65 matrix reference

R0.13-A separates the authority for the color space from the representation used
for reproducible numerical tests.

The pinned CSS Color 4 snapshot publishes the linear-sRGB <-> XYZ D65 matrices
as exact rational coefficients. Those rational matrices are the R0.13 numerical
reference for the production coefficient set and for R0.13-B probes.

Provenance chain:

```text
IEC 61966-2-1
    -> normative sRGB colorimetry

ICC sRGB registry
    -> public supporting registry for IEC-defined primaries, D65 and transfer

pinned CSS Color 4 snapshot
    -> STANDARDS_SAMPLE numerical matrix reference using exact rational values
```

This does not make CSS the normative definition of sRGB. It gives R0.13 a
pinned, inspectable and reproducible numerical representation of the transform
while IEC remains the underlying colorimetric authority.

### R0.13-B matrix-provenance result

R0.13-B independently derived the linear-sRGB → XYZ D65 matrix from the IEC/ICC
primaries and D65 white point, then compared that derivation with the pinned CSS
rational matrix.

On the tested x86_64 Linux setup, the local wider-`real` diagnostic route agreed
with the pinned rational coefficients at roughly `1e-20` to `1e-19`.

This is evidence that the two provenance routes are numerically consistent. It
does not make D `real` portable ground truth, and it does not turn the observed
difference into an acceptance tolerance.

---

# 3. CSS Color Module Level 4

Pinned R0.13 snapshot:

```text
CSS Color Module Level 4
W3C Candidate Recommendation Draft
13 September 2026

https://www.w3.org/TR/2026/CRD-css-color-4-20260913/
```

Do not use the moving:

```text
https://www.w3.org/TR/css-color-4/
```

as the sole identity of final regression evidence.

Relevant R0.13 subjects include:

```text
sRGB and linear-sRGB definitions
conversion sample code
XYZ conversion
Oklab / OkLCh
hue interpolation
powerless components
color equivalence
gamut mapping
deltaEOK sample code
```

Classification depends on the particular material:

```text
normative CSS behavior          -> NORMATIVE for CSS semantics
sample conversion code         -> STANDARDS_SAMPLE
underlying sRGB colorimetry     -> defer to IEC 61966-2-1
underlying Oklab mathematics    -> defer to Oklab primary source
```

---

# 4. CSS numerical-policy examples

The pinned CSS Color 4 snapshot provides direct evidence that numerical
thresholds may have different semantics even within one specification.

## Same-color-space CSS equivalence

For two colors already in the same CSS color space, numeric components are
considered equal using:

```text
small implementation-defined epsilon
```

This is a CSS equivalence rule.

It is not a portable color-d floating-point error bound.

## Cross-color-space CSS equivalence

For colors in different color spaces without missing components, CSS converts
both to Oklab and compares components using:

```text
standardized Oklab epsilon = 0.00001
```

This value belongs specifically to:

```text
CSS <color> equivalence semantics
```

It must not be promoted into a generic color-d approximate-equality constant.

## OkLCh powerless hue

For OkLCh conversion semantics CSS defines hue as powerless when:

```text
C <= 0.000004
```

This threshold answers:

```text
when conversion noise should make hue powerless
```

not:

```text
whether two arbitrary Oklab/OkLCh values are numerically equal
```

Therefore it belongs to:

```text
policy / domain semantic threshold
```

rather than a generic test tolerance.

This distinction is directly relevant to R0.5/R0.7, where color-d deliberately
keeps exact achromaticity separate from caller-defined near-achromatic policy.

---

# 5. CSS gamut mapping

The pinned CSS Color 4 snapshot permits three gamut-mapping algorithms:

```text
Binary Search Gamut Mapping with Local MINDE
EdgeSeeker Gamut Mapping
Ray Trace Gamut Mapping
```

These implement relative-colorimetric behavior for the CSS use case.

The specification also contains algorithm-internal quantities such as JND and
convergence/search thresholds.

Those remain distinct from:

```text
test comparison tolerance
strict gamut membership
caller-requested boundary proximity
```

Classification:

```text
NORMATIVE for CSS gamut-mapping semantics where normative prose applies
STANDARDS_SAMPLE where sample/pseudocode is used as implementation reference
```

---

# 6. Oklab

Primary reference:

```text
Björn Ottosson
A perceptual color space for image processing

https://bottosson.github.io/posts/oklab/
```

The publication records that the matrices were updated:

```text
2021-01-25
```

using a higher-precision sRGB matrix and matching D65 values.

Classification:

```text
PRIMARY
```

R0.13-B pins two coefficient routes for different purposes.

The production-style XYZ D65 ↔ Oklab characterization uses the pinned CSS
coefficient route and evaluates the same published coefficients through the
local wider-`real` diagnostic path.

The direct 2021 Ottosson linear-sRGB → Oklab coefficients are retained as a
PRIMARY-source provenance and route-consistency comparator. They are not an
independent high-precision oracle for the CSS/XYZ production route.

In the B characterization, the direct Ottosson route and the production
linear-sRGB → XYZ → Oklab route differed by roughly `3e-9` to `3.7e-8` in
`double`. That discrepancy is far above ordinary double rounding error and
reflects the different published coefficient routes. It must not be absorbed
into the same tolerance used for same-route XYZ ↔ Oklab reference comparisons.

CSS conversion code therefore remains a useful standards-facing numerical route
while the Ottosson publication remains the defining primary source for Oklab.
The two sources have different comparison roles rather than one serving as a
drop-in numerical oracle for the other.

---

# 7. Alpha compositing

Pinned source:

```text
Compositing and Blending Level 1
W3C Candidate Recommendation Draft
21 March 2024

https://www.w3.org/TR/2024/CRD-compositing-1-20240321/
```

The simple-alpha/source-over model defines, among other equivalent forms:

```text
premultiplied:
    co = cs + cb * (1 - alpha_s)

alpha:
    alpha_o = alpha_s + alpha_b * (1 - alpha_s)
```

Classification:

```text
NORMATIVE
```

For R0.13-C, source-over regression vectors should cite this exact source/formula
rather than only describing them as "W3C-style".

---

# 8. WCAG relative luminance

Pinned source:

```text
Web Content Accessibility Guidelines (WCAG) 2.2
W3C Recommendation
5 October 2023

https://www.w3.org/TR/WCAG22/
```

For sRGB relative luminance the established operation uses:

```text
encoded threshold = 0.04045

L =
    0.2126 * R +
    0.7152 * G +
    0.0722 * B
```

with the WCAG-defined linearization rule.

Classification:

```text
NORMATIVE
```

The older:

```text
0.03928
```

threshold is historical and must not be reintroduced into current WCAG-2.2
reference vectors.

---

# 9. deltaEOK

No external independent numerical authority is currently required merely to
define the Euclidean Oklab distance formula.

R0.10 already contains:

```text
analytical cases
+
separately implemented wider-precision D real route
```

The wider-precision route is:

```text
INDEPENDENT_IMPLEMENTATION
```

not:

```text
NORMATIVE
```

R0.13-C must determine whether it remains sufficient as the numerical reference
for implementation-error characterization.

---

# 10. Runtime / CTFE

Runtime and CTFE evaluate the same implementation in different execution
environments.

Classification:

```text
CROSS_EXECUTION
```

Runtime is not the mathematical reference for CTFE.

CTFE is not the mathematical reference for runtime.

Their comparison characterizes portability and evaluation differences.


---

# 10A. R0.13-B internal evidence

The committed B harness is a research artifact:

```text
fc25044
experiments/r0_13_numerical_tolerance_reference/b_reference_values/
```

Its captured output and result corpus are classified as:

```text
INTERNAL_REGRESSION
```

for reproducibility and continuity. The reference paths implemented inside the
harness retain the provenance classes of the sources they evaluate; classifying
the captured output as `INTERNAL_REGRESSION` does not replace those source-specific
classes.

Its captured observations do not outrank the normative or primary sources above.
The harness records how the current candidate arithmetic behaves against those
sources and against deliberately distinct derivation routes.

---

# 11. Source-selection conclusion

R0.13-A establishes this hierarchy for the next phases:

```text
normative/primary definition
        preferred for semantic meaning

independent implementation
        preferred for numerical implementation checks

standards sample
        useful for standards-facing regression

internal regression
        useful for continuity

cross execution
        useful for portability characterization
```

No source class by itself determines an acceptance tolerance.
