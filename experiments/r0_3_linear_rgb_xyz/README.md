# R0.3 — Linear sRGB <-> XYZ D65

Architecture/research spike for `color-d`.

## Questions

1. Is `XyzD65!T` a practical public computational type?
2. Can linear-light sRGB <-> XYZ D65 be implemented as small,
   allocation-free scalar arithmetic?
3. Do the transformations support both `float` and `double`?
4. Do they work during CTFE?
5. Are extended-range RGB and XYZ values preserved without clipping?
6. What round-trip tolerances are appropriate?
7. Do DMD and LDC agree on the tested vectors?
8. Are the current high-precision sRGB/D65 matrices suitable for the
   color-d conversion chain?

## Reference

The initial matrix coefficients are taken from the current CSS Color 4
sample conversion code.

The coefficients are represented as rational fractions where the reference
provides them that way, avoiding an unnecessary rounded-decimal source.

The CSS sample code is a reference implementation, not by itself the
normative definition of sRGB colorimetry. Independent reference validation
remains part of later research.

## Scope

This experiment tests only:

    LinearSRgb!T <-> XyzD65!T

It does not yet add:

- encoded sRGB transfer functions;
- Oklab;
- OKLCH;
- chromatic adaptation;
- D50;
- gamut mapping;
- public library API.

No code in this experiment is stable public API.
