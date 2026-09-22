# R0.2 Results — sRGB Transfer Function and CTFE

## Status

PASS

Tested on x86_64 with:

- DMD, debug build
- LDC, release build

Both compilers successfully compiled and executed the experiment and passed
all compile-time assertions.

## Validated

The experiment confirmed:

1. encoded sRGB and linear-light sRGB can remain distinct D types;
2. the sRGB transfer functions work generically with `float` and `double`;
3. the implementation is usable during CTFE;
4. `std.math.pow` is usable in the tested CTFE paths;
5. no clamping is required by the conversion;
6. negative extended-sRGB values are preserved;
7. values greater than 1 are preserved;
8. forward and inverse transfer functions round-trip the tested values;
9. the same implementation works under DMD and LDC.

## Observed reference values

    0.5
        -> 0.214041...
        -> 0.5

    -0.5
        -> -0.214041...
        -> -0.5

    1.2
        -> 1.516837...
        -> 1.2

The standard encoded threshold was also exercised:

    0.04045
        -> 0.0031308...
        -> 0.04045

## Extended-range result

The following compile-time color was tested:

    SRgb!double(-0.5, 1.2, 0.5)

and converted to approximately:

    LinearSRgb!double(
        -0.214041,
         1.51684,
         0.214041
    )

The round trip returned:

    SRgb!double(-0.5, 1.2, 0.5)

within the experiment tolerances.

## Architectural conclusion

The computational RGB representation must remain capable of carrying
out-of-gamut values.

Therefore:

- `SRgb!T` is not inherently limited to `[0, 1]`;
- `LinearSRgb!T` is not inherently limited to `[0, 1]`;
- conversion does not imply clipping;
- gamut testing is a separate operation;
- clipping is a separate explicit operation;
- perceptual gamut mapping is a separate explicit operation.

This model is compatible with CTFE and with both tested D compilers.

## Tolerance note

R0.2 used operation-specific tolerances rather than one global epsilon.

This policy should continue.

Numerical tolerances still need systematic characterization over larger test
sets before becoming part of the public library contract.

## Not established by R0.2

This experiment does not yet establish:

- final public function names;
- final UFCS API;
- exhaustive numerical error bounds;
- exact cross-compiler bit identity;
- behavior for NaN and infinity;
- conversion to XYZ or perceptual spaces;
- gamut classification;
- optimized generated code.

## Next experiment

R0.3 should investigate:

    LinearSRgb!T <-> XyzD65!T

Goals:

- validate the D65 matrices;
- preserve extended-range values;
- test `float` and `double`;
- test CTFE;
- test reference vectors;
- establish matrix/round-trip tolerances;
- compare DMD and LDC;
- inspect whether the implementation remains simple allocation-free scalar
  arithmetic.
