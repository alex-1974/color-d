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


## R4 follow-up — inverse sRGB transfer

The later D-code audit applied the same TC-0006 question to the inverse
linear-sRGB -> encoded-sRGB transfer, which still used generic
floating/floating Phobos `pow(base, 1/2.4)`.

The retained focused probe is
`experiments/performance_release_gate/rgb_encode_pow_probe.d`.

On an AMD EPYC 7763 GitHub runner with LDC 1.43.0, five balanced same-process
rounds measured about 8.5x lower component cost for `double` and 16.6x for
`float` with the LDC `llvm_pow` route.

The numerical audit used 1,000,000 deterministic extended finite values per
scalar width plus explicit special values. Phobos and LLVM differed by at most
4 ULP for `double` and 2 ULP for `float`. Against a `powl` reference using
the same scalar-rounded base and exponent, both implementations had the same
observed 4-ULP maximum and nearly identical >1-ULP counts. No tested
special-value classification/sign mismatch occurred.

This evidence justifies a production implementation trial; it does not by
itself weaken or replace the existing public sRGB transfer tolerances or CTFE
contract.


### Production integration result

The subsequent production trial applied the validated reciprocal-power route
only inside the private LDC runtime implementation of
`LinearSRgb!T.toSRgb`.

A public-API benchmark compiled the real `source/color/rgb.d` into the probe.
Across 100,000 deterministic RGB colors, production `toSRgb` differed from
the otherwise identical local Phobos implementation by at most 2 ULP in both
scalar widths. Only 18 double components and 11 float components out of
300,000 were above 1 ULP.

Five balanced same-process rounds retained the expected performance effect:
approximately 8.3x for double and 19.8x for float on the observed AMD EPYC 7763
hosted runner.

The result supports retaining the narrow LDC runtime optimization. DMD and CTFE
continue to use Phobos, and the existing reference/special-value/round-trip
contracts remain the correctness authority.


## R4 follow-up — Ray Trace inline hint

The D-code audit also re-evaluated the explicit `pragma(inline, true)` on the
ordinary Ray Trace unit-RGB-cube intersection helper.

The retained probe is
`experiments/performance_release_gate/gamut_inline_probe.d`.

It duplicates the validated helper exactly and compares a forced-inline form
against an otherwise identical optimizer-controlled form. On the observed
LDC 1.43.0 release runner:

- 1,000,000 deterministic `double` cases: 0 exact result mismatches;
- 1,000,000 deterministic `float` cases: 0 exact result mismatches;
- `double`: the default optimizer-controlled form was slightly faster in the
  measured rounds, so forced inlining is not justified by `double` alone;
- `float`: forced inlining was consistently about 2.2x faster than the
  default form across all seven balanced rounds.

Because `float` is a supported public scalar type and the difference is large
and stable in the measured release configuration, the explicit inline hint is
retained. This is compiler/code-generation evidence, not a semantic contract;
it should be re-audited when the release-performance compiler changes
materially.



## R4 follow-up — XYZ D65 to linear-sRGB extreme finite hardening

The extreme-conversion audit found a correctness/performance tension in the
inverse XYZ D65 -> linear-sRGB matrix. The former direct evaluation produced
42 avoidable non-finite results among 111 reference-representable cases in the
retained extreme grid for both public scalar widths.

Evidence PR #85 compared result-gated, pre-gated, bit-classification,
row-scaled, dominant-factor, wider-working and FMA candidates. The selected
production strategy is scalar-specific because the best measured trade-off was
different for `float` and `double`.

For `double`, the production path uses an exact rational dominant-factor
refactorization of each matrix row. On the retained two-million-sample ordinary
corpus:

- many last-bit results change because evaluation order changes;
- mean absolute error versus a wider `real` reference decreased from about
  7.68e-17 to 7.06e-17;
- maximum absolute error decreased from about 1.38e-15 to 9.65e-16;
- the retained subnormal corpus can differ by a few ULPs;
- signed-zero and non-finite classification matched the former path;
- isolated LDC 1.43 production median was about 0.964x the former direct path,
  i.e. roughly 3.6% faster.

For `float`, the ordinary direct matrix is retained. Only a non-finite direct
result from finite XYZ input enters a common-scale normalized fallback. On the
retained production audit:

- 2,000,000 ordinary samples were bit-identical to the former direct result;
- signed-zero and non-finite classification were unchanged;
- the extreme-grid avoidable non-finite count decreased from 42 to 0;
- isolated LDC 1.43 production median was about 1.026x the former direct path,
  i.e. roughly 2.6% slower.

The promoted implementation therefore restores the retained extreme finite
closure cases while keeping the `float` ordinary numerical path unchanged and
improving both ordinary `double` reference accuracy and measured LDC runtime.

The retained production probe is
`experiments/performance_release_gate/xyz_linear_rgb_production_probe.d`.


## R4 follow-up — float gamut mapping after XYZ hardening

The public extreme-finite hardening of XYZ D65 -> linear-sRGB exposed a larger
than expected code-generation effect inside the float gamut mappers. Although
the isolated public float conversion cost increased by only about 2.6%, a
public-API mapper comparison against the pre-hardening develop state measured
larger regressions:

- ordinary out-of-gamut Local MINDE: about +6.9%;
- ordinary out-of-gamut Ray Trace: about +6.5%;
- in-gamut Local MINDE fast path: about +42%;
- in-gamut Ray Trace fast path: about +94%;
- huge-chroma Local MINDE: about +12.7%;
- huge-chroma Ray Trace: about +10.5%.

Two source-layout experiments were rejected. Moving the exceptional float
fallback to a non-inlined helper made the critical paths slower, and combining
that split with `pragma(inline, true)` on the public conversion also regressed
the mapper benchmark.

The retained solution keeps the robust public
`XyzD65!float.toLinearSRgb` behavior unchanged and exposes the former direct
inverse matrix only at `package(color)` protection. `color.gamut` uses that
direct route internally for float Oklab/OKLCH mapping. This is appropriate
because the promoted R0.8 mapper semantics were validated with the direct
matrix and Ray Trace already owns a dedicated huge-chroma overflow fallback.
Double mapping continues to use the promoted dominant-factor public route.

A same-runner comparison against the robust public-path develop baseline
measured the retained package-internal float route as:

- ordinary out-of-gamut Local MINDE: about 3684 -> 3445 ns/color;
- ordinary out-of-gamut Ray Trace: about 1096 -> 1029 ns/color;
- in-gamut Local MINDE: about 47.2 -> 32.9 ns/color;
- in-gamut Ray Trace: about 65.0 -> 33.5 ns/color;
- huge-chroma Local MINDE: about 27634 -> 24447 ns/color;
- huge-chroma Ray Trace: about 1188 -> 1074 ns/color.

The benchmark also hashes every mapped RGB component. Baseline and candidate
hashes were identical for all six retained dataset/algorithm combinations,
including finite huge-chroma inputs. All mapping validation failures remained
zero.

The retained probe is
`experiments/performance_release_gate/gamut_production_probe.d`. It is run
against current production by the advisory performance workflow; the historical
baseline comparison remains in PR #90 evidence rather than as a permanent
hard-coded CI dependency.
