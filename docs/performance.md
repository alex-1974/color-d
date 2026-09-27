# Performance

## Contract

Performance work may change implementation strategy but must not weaken the
public color semantics, numerical contract, CTFE behavior, or safety
attributes.

LDC is the current release-performance reference compiler. DMD remains a
correctness/portability target.

## Allocation

Current public mathematical operations are `@nogc` and do not perform hidden
allocation. Runtime-sized tone families write into caller-owned output slices.

## Representative hot paths

The repository maintains evidence for performance-relevant operation families,
including:

- sRGB transfer / encoded paths;
- WCAG measurement;
- perceptual gamut mapping;
- low-level tone construction;
- XYZ D65 → linear-sRGB extreme-finite hardening, including scalar-specific
  ordinary-path cost and reference-accuracy evidence.

The main performance evidence is summarized in
[`research/PERFORMANCE_RELEASE_GATE.md`](research/PERFORMANCE_RELEASE_GATE.md)
with executable probes under `../experiments/performance_release_gate/`.

## Comparison policy

Where comparison with optimized C++ is meaningful, the comparison must align
algorithm, scalar type, validation, mathematical semantics, inputs, and build
intent closely enough to be fair. Bounds-check-disabled measurements are
additional evidence rather than the sole consumer-performance claim.

Compiler-specific fast paths are acceptable only when the common public
semantics remain intact and correctness, numerical behavior, CTFE, attributes,
and generated code are separately validated.
