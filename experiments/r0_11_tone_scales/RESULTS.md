# R0.11-A results — primitive decomposition

**Status:** VALIDATED
**Research block:** R0.11 — OKLCH tone-scale generation
**Phase:** R0.11-A — primitive decomposition

This file records observed results.

It was created only after the experiment had been executed with the historical
color-d compiler baseline.

No public API is established by these results.

---

## 1. Question

R0.11-A asked what the smallest useful mathematical primitive for raw OKLCH
tone generation actually is.

The initial candidates were:

```text
A  rawTone(lightness, chroma, hue)

B  tonesAtLightnesses(
       chroma,
       hue,
       explicitLightnesses
   )

C  tonesFromSeed(
       seed,
       explicitLightnesses
   )

D  anchoredTones(
       seed,
       anchorIndex,
       explicitLightnesses
   )
```

A later composition probe added:

```text
withLightness(color, lightness)

tonesByLightness(
    color,
    explicitLightnesses
)
```

The purpose of that probe was to determine whether B or C contain actual
tone-scale mathematics beyond repeated application of an already meaningful
scalar color operation.

---

## 2. Toolchains

Observed compiler baseline:

```text
DMD64 D Compiler v2.111.0
```

and:

```text
LDC 1.41.0
based on DMD v2.111.0
LLVM 19.1.7
target: x86_64-pc-linux-gnu
host CPU: skylake
```

The experiment reports:

```text
D language version: 2111
```

under both compiler families.

---

## 3. Build matrix

The final R0.11-A candidate was executed under:

```text
DMD 2.111.0  Debug
DMD 2.111.0  Release
LDC 1.41.0   Debug
LDC 1.41.0   Release
```

For each configuration:

```text
float  -> 14 runtime checks PASS
double -> 14 runtime checks PASS
```

Therefore:

```text
28 runtime checks per configuration
4 configurations

112 observed runtime PASS results
0 observed runtime failures
```

The program also contains compile-time `static assert` probes.

Those CTFE probes compiled successfully in all four configurations.

---

## 4. Observed matrix

| Compiler | Build | Runtime result | CTFE |
|---|---|---:|---|
| DMD 2.111.0 | Debug | 28/28 PASS | PASS |
| DMD 2.111.0 | Release | 28/28 PASS | PASS |
| LDC 1.41.0 | Debug | 28/28 PASS | PASS |
| LDC 1.41.0 | Release | 28/28 PASS | PASS |

No compiler/build disagreement was observed in R0.11-A.

---

## 5. Candidate A — `rawTone`

Candidate A is:

```d
rawTone(lightness, chroma, hue)
```

Observed property:

```text
rawTone(L, C, H) == Oklch(L, C, H)
```

for both supported scalar types.

The operation performs no transformation.

It merely constructs the same value that direct `Oklch` construction already
represents.

### R0.11-A conclusion

Candidate A does not currently justify a separate mathematical API.

It is useful as an experiment decomposition probe, but no additional semantics
were discovered.

---

## 6. Candidate B — explicit lightness schedule

Candidate B is conceptually:

```d
tonesAtLightnesses(
    chroma,
    hue,
    lightnesses
)
```

Observed properties for both `float` and `double`:

```text
result[i].l == lightnesses[i]
result[i].c == requested chroma
result[i].h == requested hue
```

All checks passed in all compiler/build configurations.

No:

- clipping;
- gamut mapping;
- hue rotation;
- target-space conversion;
- nonlinear arithmetic

occurs in this phase.

---

## 7. Candidate C — complete seed color

Candidate C is conceptually:

```d
tonesFromSeed(
    seed,
    lightnesses
)
```

Observed:

```text
C(seed) == B(seed.c, seed.h)
```

for the same explicit lightness schedule.

More importantly, two seeds with:

```text
different L
same C
same H
```

produce exactly the same Candidate-C scale.

Observed property:

```text
seed1.l != seed2.l

seed1.c == seed2.c
seed1.h == seed2.h

=>

tonesFromSeed(seed1, positions)
==
tonesFromSeed(seed2, positions)
```

This passed for both scalar types in all tested compiler/build configurations.

### R0.11-A conclusion

Candidate C does not use the complete semantic content of its `Oklch` input.

Calling that input a generic "seed color" therefore risks hiding the fact that
its original lightness is irrelevant to the generated raw scale.

---

## 8. Scalar `withLightness` probe

The composition probe introduced:

```d
withLightness(color, lightness)
```

with the exact semantics:

```text
result.l = requested lightness
result.c = color.c
result.h = color.h
```

Observed property:

```text
withLightness replaces only L
```

passed for:

```text
float
double
DMD Debug
DMD Release
LDC Debug
LDC Release
CTFE
```

This operation has useful scalar color semantics independent of tone-scale
generation.

It also matches the existing Technical Specification direction for explicit
perceptual manipulation.

---

## 9. Candidate C decomposes exactly into `withLightness`

The experiment compared:

```text
tonesFromSeed(seed, lightnesses)
```

against:

```text
for every L in lightnesses:
    withLightness(seed, L)
```

Observed:

```text
Candidate C
==
repeated withLightness(seed, L[i])
```

exactly.

This result held for:

```text
float
double
runtime
CTFE
DMD
LDC
Debug
Release
```

No tolerance was required because the operation consists only of component
assignment/copying.

---

## 10. Candidate B also decomposes exactly into `withLightness`

The experiment created an arbitrary OKLCH exemplar whose initial lightness was
deliberately unrelated to the requested tone schedule but whose chroma and hue
matched Candidate B.

Conceptually:

```text
exemplar = Oklch(
    arbitrary L,
    requested C,
    requested H
)
```

Then:

```text
tonesByLightness(exemplar, positions)
```

was compared with:

```text
tonesAtLightnesses(
    requested C,
    requested H,
    positions
)
```

Observed:

```text
B == repeated withLightness on same-C/H exemplar
```

exactly in every tested configuration.

### R0.11-A conclusion

Candidate B does not introduce additional color mathematics beyond:

```text
withLightness(color, L)
```

plus mechanical application over multiple requested lightness values.

---

## 11. Scale construction versus scalar color mathematics

The strongest R0.11-A finding is therefore not simply:

```text
Candidate B wins
```

Instead, the decomposition is:

```text
Oklch value
    ↓
withLightness(color, L)
    ↓
repeat over explicit L schedule
    ↓
raw tone collection
```

The first step is scalar color mathematics.

The second step is collection/batch composition.

R0.11-A found no new mathematical color semantics in the batch operation
itself.

This distinction matters for later API design.

A public scale helper may still be justified by:

- ergonomics;
- CTFE convenience;
- fixed-size generation;
- caller-provided buffers;
- consumer usage;

but not because raw scale generation requires a different underlying color
operation.

---

## 12. Candidate D — explicit anchoring

Candidate D is:

```d
anchoredTones(
    seed,
    anchorIndex,
    lightnesses
)
```

Two cases were tested.

### Matching anchor

When:

```text
lightnesses[anchorIndex] == seed.l
```

the experiment observed both:

```text
result[anchorIndex] == seed
```

and:

```text
result lightness schedule == requested schedule
```

There is no conflict.

### Mismatching anchor

When:

```text
lightnesses[anchorIndex] != seed.l
```

the experiment observed:

```text
result[anchorIndex] == seed
```

but therefore necessarily:

```text
result[anchorIndex].l != lightnesses[anchorIndex]
```

and:

```text
schedulePreserved(result, lightnesses) == false
```

This result is structural rather than numerical.

Exact seed anchoring and exact preservation of a contradictory requested
lightness cannot both hold.

---

## 13. Anchor-policy conclusion

Anchoring is not an implicit property of raw tone generation.

It introduces a policy question:

```text
when anchor lightness and requested schedule disagree,
which contract wins?
```

R0.11-A therefore rejects hidden anchoring in the lowest-level raw
tone-generation operation.

If anchoring is useful to a later palette consumer, it should be represented by
an explicitly named operation or policy.

---

## 14. Exactness and numerical tolerance

R0.11-A performs:

- value construction;
- component replacement;
- component copying;
- static-array iteration;
- equality comparison.

It performs no:

- transfer function;
- matrix multiplication;
- square root;
- trigonometry;
- interpolation arithmetic;
- gamut mapping;
- distance calculation.

Therefore exact equality is the appropriate test for the phase-A invariants.

No floating-point approximation tolerance was required.

R0.11-A does not establish any library-wide tolerance policy.

---

## 15. Extended values observed in the decomposition probe

The composition probe deliberately used an exemplar with:

```text
L = -0.25
```

while generating a scale from unrelated requested lightness values.

Its initial lightness had no effect on the resulting B-equivalent scale.

This provides limited phase-A evidence that the simple scalar/batch
decomposition does not inherently require a nominal `[0,1]` input lightness
for the exemplar.

This is not yet the complete R0.11 extended-value decision.

Full extended-value semantics remain assigned to later R0.11 work.

---

## 16. CTFE

Compile-time probes validated:

- direct `rawTone`;
- explicit lightness schedule generation;
- seed form;
- matching anchored form;
- scalar `withLightness`;
- repeated `withLightness`;
- equivalence of Candidate C and repeated `withLightness`;
- equivalence of Candidate B and repeated `withLightness` on a same-C/H
  exemplar.

The same ordinary experiment functions are used at compile time and runtime.

No separate CTFE-specific API exists.

---

## 17. Attributes and allocation shape

The tested scalar and fixed-size operations compile with the intended
research attributes:

```d
@safe
pure
nothrow
@nogc
```

The fixed-size candidates return static arrays:

```d
Oklch!T[N]
```

and require no explicit heap or GC allocation in the experiment.

R0.11-A does not yet decide whether a static-array batch helper belongs in the
future public API.

Runtime-sized output and caller-provided buffers remain later R0.11 questions.

---

## 18. Performance

No runtime microbenchmark was performed.

R0.11-A contains no demonstrated performance-sensitive numerical kernel.

The relevant operations are component assignment and fixed-size iteration.

A nanosecond benchmark would not answer the phase-A architecture question and
would be speculative.

Project-wide performance/compiler retesting remains tracked separately.

---

## 19. R0.11-A decisions

R0.11-A supports the following research decisions.

### Accepted

1. `withLightness(Oklch, L)` is a meaningful independent scalar primitive.
2. Raw explicit-position scale generation can be expressed mechanically by
   repeated `withLightness`.
3. Candidate C is exactly repeated `withLightness(seed, L[i])`.
4. Candidate B is likewise reducible to repeated `withLightness` on any OKLCH
   value carrying the requested chroma and hue.
5. Exact anchoring is separate policy.
6. Hidden anchor override does not belong in the lowest-level raw primitive.
7. No tolerance is required for these exact component-preservation properties.
8. The tested operations are viable for CTFE and the intended core attributes
   on the historical DMD/LDC baseline.

### Not justified by phase A

R0.11-A does not justify a separate public:

```text
rawTone(...)
```

operation.

It also does not yet justify freezing public:

```text
tonesAtLightnesses(...)
tonesFromSeed(...)
tonesByLightness(...)
anchoredTones(...)
toneScale(...)
```

names or signatures.

These remain experiment vocabulary.

---

## 20. Architectural result

The current preferred decomposition after R0.11-A is:

```text
Oklch construction
        ↓
withLightness(color, L)
        ↓
application over an explicit L schedule
        ↓
optional chroma policy
        ↓
explicit gamut mapping
        ↓
explicit target-space conversion
```

Only the first two layers have been examined sufficiently in phase A.

Whether the application-over-schedule layer deserves a reusable public helper
depends on later:

- schedule semantics;
- output representation;
- CTFE ergonomics;
- runtime-sized generation;
- consumer evidence.

---

## 21. Questions handed to later R0.11 phases

R0.11-A leaves these questions open:

- Should color-d provide a linear lightness-schedule generator?
- Should arbitrary caller-supplied positions be the primary scale interface?
- Does a static-array batch helper materially improve CTFE ergonomics?
- Is a caller-provided runtime output buffer useful?
- What are the correct zero-step and one-step semantics?
- Should nonlinear schedules live in color-d or in palette policy?
- What chroma policies are useful and which are aesthetic?
- How should powerless/achromatic hue interact with generated scales?
- What finite extended input contract should scale helpers use?
- What should happen for NaN and infinity?
- How should explicit R0.8 gamut mapping compose with raw scales?
- Is `deltaEOK` useful only diagnostically or does any spacing primitive merit
  exposure?

These questions belong to R0.11-B through R0.11-F.

---

## 22. Phase-A conclusion

R0.11-A validates a smaller architecture than the original `toneScale(...)`
sketch suggested.

The fundamental raw mathematical operation is currently:

```text
replace OKLCH lightness while preserving chroma and hue
```

represented experimentally by:

```d
withLightness(color, L)
```

A raw tone scale is then mechanically obtained by applying this operation over
explicit lightness positions.

The batch operation may still deserve an API for ergonomics or CTFE, but R0.11-A
found no additional color mathematics in that layer.

Exact base anchoring is a separate, potentially conflicting policy and must
remain explicit.

R0.11 remains in progress.
