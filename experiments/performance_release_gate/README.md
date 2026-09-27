# Performance release gate — C++ baseline

This directory contains external native baseline experiments for color-d #5.

The C++ code is not production code and does not define color-d API.

## R0.9 equivalent WCAG benchmark

`r0_9_cpp_baseline.cpp` mirrors the existing D benchmark in:

`experiments/r0_9_luminance_contrast/benchmark/source/app.d`

Controlled properties:

- same mathematical formulas;
- same `float` / `double` scalar split;
- same `{T,bool}`, compact-NaN and try/out result shapes;
- same deterministic LCG;
- same 8192-sample data set;
- same 1000 repetitions;
- anti-DCE checksum;
- checked aggregate functions carry an always-inline request to mirror the D
  harness's `pragma(inline, true)`.

Fair release comparison must not use `-ffast-math`, because color-d relies on
NaN/invalid-state and IEEE behavior.

Initial comparison flags:

```text
LDC:
    -O3 -release -boundscheck=off -mcpu=native

Clang/GCC:
    -O3 -DNDEBUG -march=native -std=c++20
```

Absolute timings are machine-local evidence. The important release question is
whether an equivalent optimized C++ implementation exposes a material,
unexplained gap in a color-d hot path.


## R0.9 release-gate conclusion

The release-gate investigation produced the following measured conclusions on
the reference x86-64 system:

- current Phobos floating/floating `std.math.pow` routes through
  `_powImpl(real, real)` and is a material sRGB-transfer hot-path bottleneck;
- direct native `pow`/`powf` removes that gap;
- LDC's `llvm_pow(T,T)` runtime path lowers to native `pow`/`powf` and
  preserves a `@safe pure nothrow @nogc` wrapper when paired with a
  `__ctfe` fallback to `std.math.pow`;
- the LDC `llvm_pow` and direct-libm sRGB decode results were bit-identical
  across 1,000,000 deterministic `double` and 1,000,000 `float` inputs;
- the current Phobos result differed by at most 1 ULP in those samples, with no
  NaN/Inf classification mismatches;
- the measured LDC hot paths are C++-competitive without fast-math;
- DMD 2.113 remains materially slower even with `-mcpu=native` and therefore
  remains the correctness/portability compiler rather than the v0.1
  performance-reference compiler.

The benchmark-only probes in this directory do not themselves define production
API. Production implementation must preserve the public API, CTFE behavior and
the numerical contracts established by the relevant research/specification.


## R4 audit — sRGB encode reciprocal-power path

The R4 D-code audit revisited the inverse sRGB transfer because production
`linearToSrgbComponent` still used the generic floating/floating
`std.math.pow(base, 1/2.4)` route while the decode path already had a
validated LDC-native power backend.

Executable evidence is retained in:

`rgb_encode_pow_probe.d`

The focused probe compares identical linear-to-encoded component formulas and
changes only the power backend:

```text
current/reference runtime     std.math.pow
candidate LDC runtime         ldc.intrinsics.llvm_pow
candidate CTFE                std.math.pow
higher-precision reference    powl with the same T-rounded base/exponent
```

The numerical corpus contains 1,000,000 deterministic extended finite inputs
for each public scalar type, plus signed zero, the transfer boundary, ±1,
infinities, and NaN.

Final GitHub-hosted audit run:

```text
LDC:       1.43.0
CPU:       AMD EPYC 7763
real:      64 mantissa bits

double:
    Phobos vs LLVM max difference:      4 ULP
    samples above 1 ULP:                73 / 1,000,000
    Phobos vs powl max difference:      4 ULP
    LLVM vs powl max difference:        4 ULP
    special-value mismatches:           0

float:
    Phobos vs LLVM max difference:      2 ULP
    samples above 1 ULP:                56 / 1,000,000
    Phobos vs powl max difference:      4 ULP
    LLVM vs powl max difference:        4 ULP
    special-value mismatches:           0
```

The higher-precision reference does not show a material accuracy advantage for
the current Phobos path. The two implementations have the same observed
maximum ULP distance to that reference and nearly identical >1-ULP counts.

Five balanced-order same-process release rounds gave representative medians:

| Scalar | Phobos | LDC llvm_pow | Approx. ratio |
| --- | ---: | ---: | ---: |
| `double` | 126.5 ns/component | 15.0 ns/component | 8.5× |
| `float` | 127.2 ns/component | 7.7 ns/component | 16.6× |

These absolute values are GitHub-hosted-runner observations, not portable
throughput guarantees. The large same-process relative gap is nevertheless
consistent with the already established TC-0006 Phobos floating/floating
`pow` bottleneck.

**Audit decision:** the encode-side LDC intrinsic route qualifies for a
separate production implementation trial. Adoption still requires the normal
DMD/LDC unit, CTFE, reference, special-value and external-consumer gates. The
experiment itself does not change production semantics.


### Production integration verification

The follow-up production trial routed only the LDC runtime implementation of
`LinearSRgb!T.toSRgb` through the validated reciprocal-power intrinsic while
leaving DMD runtime and CTFE on Phobos.

The same focused harness was then compiled together with the real
`source/color/rgb.d` and compared the public `toSRgb` call against an
otherwise identical local Phobos implementation.

On the same class of AMD EPYC 7763 hosted runner:

```text
100,000 deterministic RGB colors

double:
    public-production vs local-Phobos max difference: 2 ULP
    components above 1 ULP:                           18
    local Phobos median:                              ~377.8 ns/color
    public toSRgb median:                             ~45.5 ns/color
    relative ratio:                                  ~8.3x

float:
    public-production vs local-Phobos max difference: 2 ULP
    components above 1 ULP:                           11
    local Phobos median:                              ~465.1 ns/color
    public toSRgb median:                             ~23.5 ns/color
    relative ratio:                                  ~19.8x
```

This verifies that the optimization survives integration through the supported
public API rather than existing only in an isolated helper benchmark.

**Production decision:** retain the narrow LDC runtime
`srgbEncodePowInv24` path, with Phobos preserved for CTFE and non-LDC
compilers. The optimization remains internal and does not change the public
transfer equation, API, or numerical tolerance contract.
