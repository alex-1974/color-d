# R0.4 — XYZ D65 <-> Oklab

Architecture/research spike for `color-d`.

## Questions

1. Is `Oklab!T` practical as a public computational type?
2. Can XYZ D65 <-> Oklab be implemented as allocation-free scalar arithmetic?
3. Does the cube-root nonlinear step work with `float` and `double`?
4. Does the complete conversion work during CTFE?
5. Does the sign-preserving cube root handle extended/negative LMS values?
6. What round-trip tolerances are appropriate?
7. Do DMD and LDC agree on the tested vectors?
8. How closely does the XYZ-based path agree with Björn Ottosson's direct
   linear-sRGB <-> Oklab reference implementation?
9. Should the production conversion graph primarily route through XYZ D65,
   while retaining direct optimized paths only where justified?

## Primary reference

CSS Color Module Level 4 sample conversion code:

    XYZ D65 <-> Oklab

The matrices used there were recalculated for a consistent D65 white point
and 64-bit precision.

## Independent comparison

Björn Ottosson's direct:

    Linear sRGB <-> Oklab

reference implementation is used as an independent comparison path.

Small numerical differences are expected because the two paths use slightly
different matrix coefficients and precision.

## Scope

This experiment tests:

    XyzD65!T <-> Oklab!T

and compares against:

    LinearSRgb!T -> Oklab!T

It does not yet establish the final production conversion graph.

No code in this experiment is stable public API.
