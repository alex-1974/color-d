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
