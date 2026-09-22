# R0.3 Results — Linear sRGB <-> XYZ D65

## Status

PASS

Tested on x86_64 with:

- DMD, debug build
- LDC, release build

Both compilers successfully compiled and executed the experiment and passed
all compile-time assertions.

## Validated

R0.3 confirmed that:

1. `XyzD65!T` is practical as a distinct computational color-space type;
2. linear-light sRGB and XYZ D65 remain statically distinct types;
3. the conversion can be expressed as small allocation-free scalar arithmetic;
4. both transforms work with `float` and `double`;
5. the complete forward and inverse matrix calculations work during CTFE;
6. extended-range values are preserved without clipping;
7. the tested forward and inverse transforms round-trip successfully;
8. the tested DMD and LDC builds produce the same displayed results;
9. the rational sRGB/D65 matrix coefficients are practical to use directly
   in D source.

## Layout

Observed on both tested builds:

| Type | sizeof | alignof |
|---|---:|---:|
| `LinearSRgb!float` | 12 | 4 |
| `XyzD65!float` | 12 | 4 |
| `LinearSRgb!double` | 24 | 8 |
| `XyzD65!double` | 24 | 8 |

No additional storage overhead was observed for `XyzD65!T` compared with
the equivalent three-component RGB type.

## Unit primaries

The unit linear-sRGB primaries produced:

    red:
        XYZ = (0.412391, 0.212639, 0.0193308)

    green:
        XYZ = (0.357584, 0.715169, 0.119195)

    blue:
        XYZ = (0.180481, 0.0721923, 0.950532)

The compile-time assertions use higher-precision expected values.

These tests also act as regression checks for matrix orientation and component
ordering.

## D65 white

Unit linear-sRGB white:

    LinearSRgb!double(1, 1, 1)

mapped to:

    XyzD65!double(0.950456, 1, 1.08906)

and round-tripped to:

    LinearSRgb!double(1, 1, 1)

within the experiment's double-precision tolerances.

This is consistent with normalized XYZ D65 where Y = 1.

## Ordinary reference color

Input:

    LinearSRgb!double(
        0.4352785666728059,
        0.017175850397231969,
        0.054553830782703643
    )

Observed XYZ:

    XyzD65!double(
        0.195493...,
        0.108779...,
        0.0623167...
    )

The inverse transform returned the original RGB values within the tested
double-precision tolerances.

The corresponding `float` test also round-tripped successfully.

## Extended range

The experiment deliberately tested:

    LinearSRgb!double(-0.2, 1.3, 0.5)

This mapped to approximately:

    XyzD65!double(
        0.472622,
        0.923288,
        0.626353
    )

and round-tripped to:

    LinearSRgb!double(-0.2, 1.3, 0.5)

No clipping or normalization occurred.

## CTFE

The following were evaluated during compilation:

- black conversion;
- unit-primary conversion;
- D65 white conversion;
- forward matrix multiplication;
- inverse matrix multiplication;
- ordinary RGB round trip;
- extended-range round trip;
- `float` round trip.

All associated `static assert`s passed under both tested compilers.

R0.3 therefore extends the previous CTFE evidence from nonlinear transfer
functions to full three-by-three color-space transformations.

## Architectural conclusion

The following conversion chain is now experimentally viable:

    SRgb!T
        ⇅
    LinearSRgb!T
        ⇅
    XyzD65!T

`XyzD65!T` remains a strong candidate for a public core type rather than only
an internal implementation detail.

Reasons include:

- compact representation;
- static type safety;
- natural D65 interoperability;
- no observed allocation requirement;
- CTFE compatibility;
- future use as a connection point for additional RGB spaces;
- usefulness for independent standards/reference testing.

## Range policy

R0.3 reinforces the existing range policy:

- computational color values are not implicitly clamped;
- conversion and gamut handling are distinct operations;
- XYZ values may legitimately lie outside ranges associated with a particular
  display gamut;
- extended RGB values survive conversion through XYZ.

## Numerical policy

The experiment continues to use operation-specific absolute and relative
tolerances.

Current experimental tolerances are not yet a frozen library contract.

Before stabilization, numerical behavior should be characterized across a
larger input set and against independent reference implementations.

## Not established by R0.3

R0.3 does not establish:

- the final public type names;
- the final conversion API;
- ABI guarantees;
- exact bit-identical results across compilers;
- SIMD or batch-conversion APIs;
- final production coefficient representation;
- NaN or infinity policy;
- Oklab conversion;
- chromatic adaptation;
- D50 support;
- gamut mapping.

Generated-code quality has also not yet been adopted as a public performance
contract. Detailed code-generation analysis belongs in a dedicated
performance investigation once the conversion architecture is further
established.

## Next experiment

R0.4 should investigate:

    XyzD65!T <-> Oklab!T

and, where useful for validating the implementation, the equivalent direct
linear-sRGB/Oklab reference path.

Goals:

- verify the current Oklab reference matrices;
- determine the most appropriate conversion graph;
- support `float` and `double`;
- preserve extended values where mathematically meaningful;
- validate cube-root behavior at CTFE;
- test reference vectors;
- establish round-trip tolerances;
- compare DMD and LDC;
- prepare for subsequent `Oklab!T <-> Oklch!T`.
