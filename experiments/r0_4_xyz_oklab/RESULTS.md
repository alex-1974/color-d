# R0.4 Results — XYZ D65 <-> Oklab

## Status

PASS

Tested on x86_64 with:

- DMD 2.111.0, debug build
- LDC 1.41.0, release build
  - based on DMD 2.111.0
  - LLVM 19.1.7

Both compilers successfully compiled and executed the experiment and passed
all compile-time assertions.

## Validated

R0.4 confirmed that:

1. `Oklab!T` is practical as a distinct computational color-space type;
2. XYZ D65 and Oklab remain statically distinct types;
3. XYZ D65 <-> Oklab can be implemented as small allocation-free scalar
   arithmetic;
4. the transformations work with both `float` and `double`;
5. the complete transformation works during CTFE;
6. negative intermediate LMS values can be handled with a sign-preserving
   cube-root formulation;
7. extended-range input values survive the conversion and round trip;
8. the tested XYZ -> Oklab -> XYZ transforms round-trip within the selected
   tolerances;
9. the XYZ-based Oklab path agrees very closely with Björn Ottosson's direct
   linear-sRGB -> Oklab reference path;
10. DMD and LDC produced the same displayed results for all tested values.

## Layout

Observed on both tested builds:

| Type | sizeof | alignof |
|---|---:|---:|
| `XyzD65!float` | 12 | 4 |
| `Oklab!float` | 12 | 4 |
| `XyzD65!double` | 24 | 8 |
| `Oklab!double` | 24 | 8 |

No additional storage overhead was observed for `Oklab!T`.

## D65 white

Input:

    XyzD65!double(0.950456..., 1, 1.08906...)

produced:

    Oklab!double(
        1,
        -5.69125e-16,
         1.76725e-17
    )

and converted back to the original XYZ value within the tested tolerances.

The very small non-zero `a` and `b` components are numerical residue.

The experiment deliberately does not clamp or canonicalize these values to
zero.

## Unit primaries

The tested linear-sRGB unit primaries, routed through XYZ D65, produced:

    red:
        Oklab(0.627955,  0.224863,  0.125846)

    green:
        Oklab(0.866440, -0.233888,  0.179498)

    blue:
        Oklab(0.452014, -0.032457, -0.311528)

All higher-precision compile-time reference assertions passed.

## Ordinary reference color

Input linear sRGB:

    LinearSRgb!double(
        0.4352785666728059,
        0.017175850397231969,
        0.054553830782703643
    )

produced approximately:

    XyzD65!double(
        0.195493,
        0.108779,
        0.0623167
    )

then:

    Oklab!double(
        0.499568,
        0.169354,
        0.0447558
    )

and round-tripped through Oklab back to the original XYZ value within the
selected tolerances.

The corresponding `float` path also passed.

## Extended range

The experiment deliberately used:

    LinearSRgb!double(
        -0.2,
         1.3,
         0.5
    )

which produced:

    XyzD65!double(
        0.472622,
        0.923288,
        0.626353
    )

and then:

    Oklab!double(
         0.943018,
        -0.243440,
         0.0716841
    )

The inverse Oklab -> XYZ transformation returned the original XYZ value within
the tested tolerances.

No clipping or gamut normalization occurred.

## Cube-root finding

The first implementation attempted to use:

    std.math.cbrt

inside the intended:

    @safe pure nothrow @nogc

conversion chain.

On the tested DMD 2.111.0 toolchain this failed because the available
`std.math.cbrt` declaration could not be called from a `pure` function.

This exposed an important portability issue before public API stabilization.

R0.4 therefore switched to an explicitly sign-preserving cube-root baseline:

    cubeRoot(x) =
        x                         if x == ±0
        -pow(-x, 1/3)             if x < 0
         pow( x, 1/3)             if x > 0

This formulation:

- preserves negative inputs;
- preserves signed zero in the tested implementation;
- works in the intended `@safe pure nothrow @nogc` chain;
- works during CTFE;
- passed under both DMD and LDC.

This does not yet establish the final optimized runtime cube-root
implementation.

A specialized runtime path may be investigated later if benchmarks justify it.

## CTFE

The following were successfully evaluated at compile time:

- positive cube root;
- negative cube root;
- positive zero;
- negative zero;
- D65 white conversion;
- unit-primary conversion;
- ordinary XYZ -> Oklab -> XYZ round trip;
- extended-range round trip;
- `float` round trip;
- comparison with the direct linear-sRGB -> Oklab reference path.

R0.4 therefore confirms that the nonlinear Oklab conversion can participate
in the same CTFE-oriented architecture already validated by R0.1 through R0.3.

## Direct linear-sRGB comparison

The experiment also implemented Björn Ottosson's direct:

    LinearSRgb!T -> Oklab!T

reference transformation.

The XYZ-based and direct paths produced extremely close results.

Example extended-range output:

    via XYZ:
        Oklab(0.943018, -0.243440, 0.0716841)

    direct:
        Oklab(0.943018, -0.243440, 0.0716842)

The two paths were intentionally not required to be bit-identical.

They use independently sourced matrix coefficients with slightly different
precision and derivation.

## Conversion-graph conclusion

R0.4 supports the following canonical conversion graph as a strong current
candidate:

    SRgb!T
        ⇅
    LinearSRgb!T
        ⇅
    XyzD65!T
        ⇅
    Oklab!T

Advantages:

- each transformation has clear colorimetric semantics;
- XYZ D65 remains a useful interoperability hub;
- each layer can be independently tested;
- future RGB spaces can connect naturally through XYZ;
- reference data from standards can be tested directly;
- CTFE remains viable through the full chain.

The direct:

    LinearSRgb!T <-> Oklab!T

path should currently be treated as:

- an independent validation path;
- a possible future optimization.

It should not yet become a second semantic conversion graph without a measured
consumer benefit.

## Numerical policy

R0.4 reinforces several numerical-policy decisions:

- tiny floating-point residue is not automatically canonicalized;
- conversions do not clamp;
- extended values remain valid computational values;
- operation-specific tolerances are preferable to one global epsilon;
- independent conversion paths may agree numerically without being
  bit-identical.

## Not established by R0.4

R0.4 does not yet establish:

- final public type names;
- final conversion function names;
- final cube-root implementation;
- a performance advantage for direct linear-sRGB/Oklab conversion;
- exhaustive numerical error bounds;
- NaN policy;
- infinity policy;
- ABI guarantees;
- SIMD or batch conversion;
- Oklab <-> OKLCH;
- gamut mapping.

## Next experiment

R0.5 should investigate:

    Oklab!T <-> Oklch!T

Primary questions:

- hue representation;
- radians versus degrees at the API boundary;
- hue normalization;
- zero-chroma behavior;
- undefined hue semantics;
- negative chroma policy;
- CTFE behavior of `sqrt` and `atan2`;
- float/double round-trip behavior;
- whether a dedicated hue type is justified.

R0.5 is expected to be the first experiment where API semantics are more
significant than the underlying matrix mathematics.