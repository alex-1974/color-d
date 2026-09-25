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
