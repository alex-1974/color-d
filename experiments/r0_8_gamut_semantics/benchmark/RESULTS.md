# R0.8 Gamut Semantics — Benchmark Results

Date: 2026-09-23

## Purpose

This benchmark supplements the R0.8 correctness experiment with focused
performance and generated-code evidence for:

- strict sRGB gamut detection;
- target-space clipping;
- OKLCH / linear-sRGB conversion;
- Local MINDE gamut mapping;
- Ray Trace gamut mapping;
- `float` versus `double`;
- in-gamut fast paths;
- selected implementation-level optimizations.

The benchmark is research evidence. It does not freeze a public API.

## Environment

Repository:

- project: `color-d`
- branch: `research/r0_8-gamut-semantics`
- research base commit:
  `bad46d7e37a6fc63d81b43d1bd92dea3fa51f62e`

Compilers observed during R0.8:

- DMD 2.111.0
- LDC 1.41.0
- LDC based on DMD 2.111.0
- LLVM 19.1.7

Machine:

- Intel Core i7-9750H
- 6 physical cores / 12 logical CPUs
- reported LDC host CPU: `skylake`
- maximum reported clock: 4.5 GHz
- benchmark CPU: logical CPU 2
- SMT sibling of CPU 2: CPU 8

Native LDC measurement build:

```text
ldc2
    -O3
    -release
    -boundscheck=off
    -mcpu=native
```

Hardware counters were collected with `perf stat -r 7`.
Unprivileged hardware counters were unavailable because the machine had
`kernel.perf_event_paranoid = 4`; the measurement itself therefore used
privileged `perf stat` without changing the sysctl value.

## Datasets

The benchmark uses deterministic generated datasets.

Primary dataset size:

```text
4096 colors
```

For scalar-type comparison, `float` and `double` datasets contain the same
conceptual input colors. Out-of-gamut candidates are accepted only when both
representations classify the color as outside the sRGB gamut.

The performance-only mode suppresses correctness validation and increases
iteration counts so hardware-counter measurements are dominated by the kernel
under test.

## Optimization correctness

4096 out-of-gamut samples were used to compare the optimized mapping variants
against their respective reference implementations.

Observed:

```text
Local max deltaEOK:   0
Local failures:       0

Ray max deltaEOK:     0
Ray failures:         0
```

For the tested samples:

- cached-hue Local MINDE was numerically identical to its reference;
- Ray Trace without repeated `atan2` was numerically identical to its
  reference.

## In-gamut fast path

4096 in-gamut colors were passed through all four mapping variants.

Observed:

```text
failures:             0
non-zero iterations:  0
max deltaEOK:         1.13764e-15
```

The small non-zero delta is attributable to the conversion round trip used by
the validator. No gamut-mapping iteration was entered.

This confirms the intended architecture:

```text
input
  |
  +-- already in target gamut --> return through fast path
  |
  +-- outside target gamut -----> execute mapping algorithm
```

## Paired float / double results

LDC release measurements using paired conceptual datasets:

| Operation | double ns/color | float ns/color | Observation |
| --- | ---: | ---: | --- |
| OKLCH -> Linear sRGB | 32.5616 | 24.0859 | float faster |
| Linear sRGB -> OKLCH | 341.894 | 285.604 | float faster |
| Local MINDE cached hue | 3069.16 | 3094.10 | effectively no float benefit |
| Ray Trace no-atan2 | 1100.30 | 978.428 | moderate float benefit |

The results do not justify choosing one scalar type globally.

`color-d` should remain scalar-generic for `float` and `double`.

## Hardware counters before intersection inlining

`--perf-only` iteration counts:

```text
Local MINDE: 4096 * 300 = 1,228,800 mappings
Ray Trace:   4096 * 500 = 2,048,000 mappings
```

### Local MINDE

| Metric | double | float |
| --- | ---: | ---: |
| cycles/color | 11837.0 | 11810.4 |
| instructions/color | 10328.7 | 10274.3 |
| branches/color | 1223.3 | 1213.9 |
| branch-miss rate | 0.851% | 0.777% |
| IPC | 0.873 | 0.870 |

### Ray Trace

| Metric | double | float |
| --- | ---: | ---: |
| cycles/color | 4255.5 | 3824.7 |
| instructions/color | 3738.7 | 3557.5 |
| branches/color | 405.5 | 400.1 |
| branch-miss rate | 1.095% | 0.761% |
| IPC | 0.879 | 0.930 |

The main Ray Trace advantage is reduced dynamic work rather than unusually
high IPC.

Compared with Local MINDE, Ray Trace executes roughly:

- 2.8x fewer cycles per `double` mapping;
- 2.8x fewer instructions per `double` mapping;
- about one third as many dynamic branches.

Branch misses are low for both algorithms and are not the primary explanation
for the performance difference.

## Generated-code inspection

LDC native assembly was inspected for the optimized mapping kernels.

### Hue handling

The optimized Ray Trace kernel contains no `atan2` call.

Two static `sincos` call sites are present, but they belong to alternative
control-flow paths associated with input canonicalization. They do not imply
two `sincos` executions per ordinary invocation.

### Ray iteration structure

LLVM emits:

- the first Ray Trace intersection separately;
- a small loop for the remaining bounded iterations.

This is effectively a peeled first iteration followed by the remaining
bounded loop.

No evidence was found that manual loop unrolling would be justified.

### Intersection helper

Before forced inlining, `intersectUnitRgbCube` remained a separate function.

The helper:

- contains no external calls;
- is relatively compact;
- is called repeatedly by Ray Trace;
- causes visible argument/result stack traffic around the call sites.

This motivated an isolated explicit-inlining experiment.

## `intersectUnitRgbCube` inlining experiment

The benchmark-only helper was annotated:

```d
pragma(inline, true)
```

Assembly inspection then found no remaining:

```text
callq ... intersectUnitRgbCube
```

inside the generated benchmark assembly.

Correctness remained unchanged:

```text
Ray max deltaEOK: 0
Ray failures:     0
```

### Hardware counters after inlining

| Metric | double | float |
| --- | ---: | ---: |
| cycles/color | 3790.1 | 3667.9 |
| instructions/color | 3557.8 | 3479.0 |
| branches/color | 402.1 | 403.9 |
| branch-miss rate | 0.975% | 0.732% |
| IPC | 0.939 | 0.948 |

Relative to the non-inlined Ray kernel:

### double

```text
cycles:       about -10.9%
instructions: about -4.8%
elapsed perf: about -13.1%
IPC:          0.879 -> 0.939
```

### float

```text
cycles:       about -4.1%
instructions: about -2.2%
elapsed perf: about -6.6%
IPC:          0.930 -> 0.948
```

The improvement is sufficiently large and consistent to retain
`intersectUnitRgbCube` as a justified explicit-inline candidate for a future
production implementation.

## Performance conclusions

The R0.8 measurements support the following implementation guidance.

1. Gamut detection and clipping are cheap operations and suitable for direct
   use in ordinary color workflows.

2. Mapping should retain an explicit in-gamut fast path.

3. Local MINDE benefits materially from caching fixed hue information, but its
   iterative structure remains substantially more expensive than Ray Trace.

4. Ray Trace benefits from avoiding repeated `atan2`.

5. Ray Trace has bounded iteration cost and performs substantially less
   dynamic work than Local MINDE on the tested out-of-gamut dataset.

6. `float` is not universally faster. Scalar choice must remain explicit and
   generic.

7. Explicitly inlining `intersectUnitRgbCube` is supported by timing,
   hardware-counter, and assembly evidence.

8. Manual loop unrolling is not currently justified.

9. A direct Linear-sRGB <-> Oklab hot path is not required by R0.8 evidence.
   It should be investigated separately only if a concrete consumer or later
   benchmark justifies it.

## Scope of the result

These measurements establish relative implementation behavior on one
x86-64/LDC system. They are not universal performance guarantees.

In particular they do not establish:

- universal cross-architecture throughput;
- SIMD/batch behavior;
- image-wide rendering performance;
- GPU behavior;
- perceptual superiority of one mapping algorithm.

Those questions belong to later consumer-driven work.
