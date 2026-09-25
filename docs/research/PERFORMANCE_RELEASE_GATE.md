# Performance release gate — R0 closeout

Status: validated research evidence for issue #5.

## Purpose

This note records the release-performance evidence that closes the R0
performance-baseline work. It does not define public API.

The release target is not "D must beat every C++ implementation". The fair
comparison is the same algorithm, mathematical semantics, scalar type,
deterministic input set, machine and release-oriented optimization settings.

`-ffast-math` is excluded because color-d intentionally preserves numerical
and invalid-state semantics that fast-math may weaken.

## Reference toolchains

Measured reference toolchains:

- DMD 2.113.0;
- LDC 1.43.0 / LLVM 22.1.8;
- Clang 21.1.8;
- GCC 15.2.0.

Runs were pinned to logical CPU 2 on the same Intel Core i7-9750H machine.

## Phobos pow bottleneck

The equivalent native C++ R0.9 benchmark showed that simple linear D/LDC
kernels were already broadly at C++ level, while every path containing the sRGB
floating-point power transfer was about four times slower.

Generated-code and Phobos-source inspection isolated the cause:

- LDC 1.43 exposes `llvm_pow(T,T)`;
- Phobos explicitly disables that branch for general `std.math.pow` and falls
  back to `_powImpl(real, real)`;
- DMD 2.113 floating/floating `std.math.pow` also calls that general
  `_powImpl` implementation.

On x86-64 the measured LDC fallback uses extended-precision/x87 operations.

## Native runtime probe

Replacing only the floating-point power call with direct native
`pow`/`powf` reduced LDC encoded-sRGB operations from roughly 220 ns/op to
roughly 52--54 ns/op and contrast operations from roughly 450--490 ns/op to
roughly 110--115 ns/op.

A five-run interleaved LDC/direct-libm/Clang/GCC comparison placed the D runtime
path essentially at native C++ level.

## CTFE-preserving LDC path

A compiler-selected internal wrapper was validated:

```d
T colorPow24(T)(T base)
@safe pure nothrow @nogc
{
    if (__ctfe)
        return cast(T)pow(base, cast(T)2.4);

    version (LDC)
    {
        import ldc.intrinsics : llvm_pow;
        return llvm_pow!T(base, cast(T)2.4);
    }
    else
    {
        return cast(T)pow(base, cast(T)2.4);
    }
}
```

The wrapper:

- compiles with both DMD 2.113 and LDC 1.43;
- retains `@safe pure nothrow @nogc`;
- retains CTFE on both compilers;
- lowers the LDC runtime path to native `pow`/`powf`;
- leaves DMD on the correct Phobos fallback.

## Numerical evidence

For the actual sRGB decode structure — positive power base, exponent 2.4, sign
reapplied outside the power operation — deterministic extended-range testing
used 1,000,000 `double` and 1,000,000 `float` inputs.

Results:

- LDC `llvm_pow` vs direct libm: 100% bit-identical for both scalar types;
- current Phobos vs LDC native path: maximum observed finite difference 1 ULP;
- NaN/Inf classification mismatches: zero;
- explicit tests preserved the tested transfer-boundary values, signed zero,
  infinities and NaN bit pattern.

This validates the narrow color-d use case. It does not claim that
`llvm_pow` is a drop-in semantic replacement for every general-purpose
`std.math.pow` input; Phobos itself documents a disabled intrinsic branch due
to a unit-test failure.

## Best-known compiler comparison

Five interleaved release runs gave these representative `double` medians:

```text
metric                 DMD+libm   LDC+llvm   Clang21
linear unchecked         7.696      1.095      1.070
linear checked          20.287      3.326      2.603
linear try              12.665      2.431      2.605
linear compact          20.544      2.672      2.820
encoded unchecked       67.789     52.928     52.999
encoded checked         79.833     51.437     52.907
encoded try             78.223     51.355     51.653
encoded compact         80.784     51.679     52.793
contrast checked       174.727    110.944    113.020
contrast compact       169.540    112.320    111.849
```

DMD remained approximately 1.28x--1.56x slower on encoded operations,
1.51x--1.58x slower on contrast, and roughly 5x--8x slower on the pow-free
linear micro-paths.

## v0.1 decision

For v0.1:

1. LDC is the release-performance reference compiler.
2. Release-critical hot paths shall be checked against equivalent optimized C++
   baselines where a fair comparison is meaningful.
3. A material unexplained LDC-vs-C++ gap is a release concern.
4. DMD remains a supported correctness/portability compiler.
5. DMD is not required to satisfy the same performance gate when reproduced
   evidence isolates the remaining gap to compiler/code-generation behavior.
6. Compiler-specific internal optimization paths are permitted only when the
   public API remains common and numerical, CTFE, attribute and generated-code
   behavior are separately validated.
7. Compiler retests are targeted at plausible code-generation changes rather
   than mechanically performed for every release.
