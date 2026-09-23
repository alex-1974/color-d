# R0.11 results — OKLCH tone-scale research

**Status:** R0.11-A/B VALIDATED — R0.11 IN PROGRESS
**Research block:** R0.11 — OKLCH tone-scale generation
**Validated phases:** R0.11-A — primitive decomposition; R0.11-B — schedule semantics

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

---

## R0.11-B results — schedule semantics

**Status:** VALIDATED
**Phase:** R0.11-B — schedule semantics

R0.11-B studied the lightness schedule itself after R0.11-A established that
raw tone construction decomposes into:

```text
withLightness(color, L)
```

applied over a sequence of requested lightness values.

No public API is established by these results.

### B.1 Observed compiler matrix

The final R0.11-B candidate was executed under:

```text
DMD 2.111.0  Debug
DMD 2.111.0  Release
LDC 1.41.0   Debug
LDC 1.41.0   Release
```

Each configuration executed the complete R0.11-A and R0.11-B runtime suite:

```text
82 PASS
0 FAIL
```

Therefore the observed final matrix totals:

```text
4 configurations
82 runtime checks per configuration

328 PASS
0 FAIL
```

The compile-time probes also compiled successfully in all four configurations.

Observed matrix:

| Compiler | Build | Result |
|---|---|---:|
| DMD 2.111.0 | Debug | 82/82 PASS |
| DMD 2.111.0 | Release | 82/82 PASS |
| LDC 1.41.0 | Debug | 82/82 PASS |
| LDC 1.41.0 | Release | 82/82 PASS |

No final hybrid-property disagreement was observed between compiler families or
build modes.

### B.2 Explicit schedules

Caller-supplied positions were tested independently from generated intervals.

Observed:

```text
N == 0
```

is naturally representable as an empty explicit position sequence and produces
an empty tone collection.

Observed:

```text
N == 1
```

is also unambiguous when the caller supplies the position explicitly.

For example:

```text
[0.42]
```

means exactly one requested tone at:

```text
L = 0.42
```

No endpoint or midpoint policy is involved.

### B.3 Generated inclusive intervals

A generated inclusive endpoint schedule has different semantics.

For:

```text
N == 2
```

the observed and intended result is exactly:

```text
[start, end]
```

The experiment explicitly constrains the generated inclusive schedule
candidates to:

```text
N >= 2
```

Compile-time probes confirm that the weighted generated candidate:

```text
N == 0  -> does not compile
N == 1  -> does not compile
N == 2  -> compiles
```

This is deliberate experiment semantics rather than a D language limitation.

### B.4 Singleton ambiguity

R0.11-B compared three explicit interpretations for a generated interval with:

```text
N == 1
```

namely:

```text
[start]
[midpoint]
[end]
```

For the probe interval:

```text
start = 0.20
end   = 0.80
```

the three policies produce distinct values.

Therefore the phrase:

```text
inclusive linear schedule from start to end with one sample
```

does not identify one unique mathematical result.

R0.11-B consequently supports keeping generic generated inclusive endpoint
schedules constrained to:

```text
N >= 2
```

rather than silently selecting a singleton policy.

Explicit caller-supplied schedules remain free to contain one value.

### B.5 Ascending and descending schedules

Generated schedules were tested in both directions.

Observed:

```text
0.10 -> 0.90
```

is nondecreasing and preserves both endpoints exactly.

Observed:

```text
0.90 -> 0.10
```

is nonincreasing and preserves both endpoints exactly.

No separate ascending and descending generation algorithms are required.

### B.6 Finite extended lightness

The raw schedule layer was tested with:

```text
start = -0.50
end   =  1.50
```

The generated values remained ordinary finite mathematical values and preserved
the expected order and endpoints.

R0.11-B therefore found no mathematical reason for the raw schedule generator
itself to clamp lightness to:

```text
[0, 1]
```

This does not establish the final public non-finite or domain contract.

NaN and infinity remain later R0.11 questions.

### B.7 Direct-difference interpolation candidate

The straightforward interior formula was:

```text
start + (end - start) * t
```

For ordinary ranges it behaves as expected.

However, R0.11-B deliberately tested finite opposite-sign endpoints:

```text
start =  0.75 * T.max
end   = -0.75 * T.max
```

Both endpoints are finite.

Their full difference is not representable in the same scalar type.

For:

```text
t = 0.5
```

the mathematically expected result is:

```text
0
```

Observed in every tested compiler/build/scalar combination:

```text
direct-difference formula loses finite midpoint
```

The direct-difference expression therefore does not satisfy the desired
finite-range property for the complete finite endpoint domain.

### B.8 Weighted-endpoint interpolation candidate

The second candidate was:

```text
(1 - t) * start + t * end
```

For the large opposite-sign probe it avoided formation of the overflowing full
difference.

Observed in every tested configuration:

```text
weighted midpoint is finite
weighted symmetric midpoint == 0
exact externally assigned endpoints are preserved
```

This resolves the concrete opposite-sign range failure of the direct formula.

However, R0.11-B also tested equal large endpoints.

For:

```text
start == end
```

a mathematically constant schedule should contain exactly that value at every
position.

The weighted candidate was observed as:

```text
weighted equal-endpoint exact: NO
```

for every tested combination:

```text
DMD Debug    float   NO
DMD Debug    double  NO

DMD Release  float   NO
DMD Release  double  NO

LDC Debug    float   NO
LDC Debug    double  NO

LDC Release  float   NO
LDC Release  double  NO
```

Therefore the pure weighted formula is not accepted as the general
R0.11-B schedule-interpolation candidate.

Its weakness was repeatable across the complete historical compiler matrix.

### B.9 Hybrid candidate

The final phase-B candidate chooses the arithmetic form according to endpoint
signs.

Conceptually:

```text
strictly opposite signs
    -> weighted-endpoint expression

otherwise
    -> direct-difference expression
```

The experimental scalar operation is equivalent to:

```text
if start and end have strictly opposite signs:
    (1 - t) * start + t * end
else:
    start + (end - start) * t
```

The generated schedule writes:

```text
result[0]     = start
result[N - 1] = end
```

explicitly and applies the interpolation expression only to interior samples.

This separates exact endpoint preservation from interior floating-point
arithmetic.

### B.10 Equal-endpoint property

For equal large endpoints, the direct and hybrid candidates were tested over an
11-element generated schedule.

Observed in all tested configurations:

```text
direct formula preserves equal-endpoint constant schedule
hybrid formula preserves equal-endpoint constant schedule
```

while the pure weighted candidate produced the separate observation:

```text
weighted equal-endpoint exact: NO
```

The hybrid candidate therefore retains the useful exact constant-schedule
property of the direct form.

### B.11 Same-sign large endpoints

The hybrid candidate was tested with large same-sign finite endpoints:

```text
start = 0.75 * T.max
end   = 0.50 * T.max
```

Observed:

```text
all tested interior values remain finite
schedule remains nonincreasing
```

Because the endpoints have the same sign, the direct-difference branch does not
form the large opposite-sign span that caused the earlier overflow failure.

### B.12 Opposite-sign large endpoints

The hybrid candidate was also retested with:

```text
start =  0.75 * T.max
end   = -0.75 * T.max
```

Observed in every configuration and scalar type:

```text
midpoint remains finite
symmetric midpoint == 0 exactly
endpoints remain exact
```

Thus the hybrid candidate retains the finite-range advantage of the weighted
expression where that advantage is required.

### B.13 Representative finite-domain property sweep

The final experiment used this deterministic endpoint set for each scalar type:

```text
-0.75 * T.max
-2
-1
-T.min_normal
-0.0
 0
 T.min_normal
 0.25
 1
 2
 0.75 * T.max
```

This produces:

```text
11 * 11 = 121
```

ordered endpoint pairs.

For every pair, the hybrid candidate generated:

```text
17
```

samples.

Therefore the representative sweep generated:

```text
121 * 17 = 2057
```

schedule values per scalar type and compiler/build configuration.

Across:

```text
2 scalar types
4 compiler/build configurations
```

the final matrix exercised:

```text
16,456
```

representative generated schedule values in this sweep.

This number describes generated values, not independent test assertions.

### B.14 Sweep properties

For every representative endpoint pair, the experiment checked:

```text
finite output
monotonicity in the endpoint direction
boundedness within the closed endpoint interval
exact first endpoint
exact last endpoint
exact constant schedule when start == end
```

Observed for both `float` and `double`, under all four configurations:

```text
PASS  hybrid representative sweep remains finite
PASS  hybrid representative sweep remains monotonic
PASS  hybrid representative sweep remains within endpoints
PASS  hybrid representative sweep preserves exact endpoints
PASS  hybrid representative equal endpoints remain exact
```

No counterexample was found in the representative sweep.

This is strong empirical evidence for the tested domain.

It is not a formal proof over every finite IEEE-754 value.

### B.15 Composition with R0.11-A

R0.11-B keeps schedule generation separate from color manipulation.

The experiment composes:

```text
generated lightness schedule
            ↓
tonesByLightness(seed, schedule)
            ↓
repeated withLightness(seed, L)
```

Observed:

```text
generated schedule composes mechanically with phase A
```

while preserving:

```text
the generated L schedule
seed chroma
seed hue
```

No extra color mathematics is introduced by the schedule layer.

### B.16 Current architectural decomposition

After R0.11-A and R0.11-B, the current research decomposition is:

```text
scalar OKLCH operation
    withLightness(color, L)

        ↓

lightness positions

    caller-supplied:
        N = 0, 1, 2, ...

    or generated inclusive interval:
        N >= 2

        ↓

robust finite interior schedule arithmetic

    same-sign / equal:
        direct-difference form

    strictly opposite-sign:
        weighted-endpoint form

        ↓

raw tone collection
```

This is a decomposition result, not a frozen public API.

### B.17 Phase-B decisions

R0.11-B supports the following research decisions.

Accepted:

1. Caller-supplied explicit positions naturally support `N == 0`.
2. Caller-supplied explicit positions naturally support `N == 1`.
3. A generic generated inclusive endpoint schedule should require `N >= 2`
   unless a separate singleton policy is explicitly requested.
4. Ascending and descending schedules use the same abstraction.
5. Exact generated endpoints should be assigned explicitly.
6. Raw finite lightness schedules need not be restricted to `[0,1]`.
7. The pure direct-difference expression is insufficient over the tested full
   finite endpoint range because opposite-sign endpoint subtraction can
   overflow.
8. The pure weighted-endpoint expression fixes that concrete range problem but
   loses exact constant-schedule behavior in the tested compiler matrix.
9. The tested hybrid candidate combines the useful properties of both forms for
   the investigated finite schedule domain.
10. Schedule generation remains separate from `withLightness` and raw tone
    construction.
11. No separate ascending/descending API is justified.
12. No implicit seed anchoring is introduced by schedule generation.

### B.18 Not established by R0.11-B

R0.11-B does not establish:

- a general-purpose public `lerp` API;
- final public names for schedule helpers;
- runtime-sized output representation;
- caller-buffer APIs;
- nonlinear/eased schedule policy;
- chroma shaping;
- hue policy;
- NaN semantics;
- infinity semantics;
- gamut mapping policy;
- target-space conversion policy;
- perceptual-distance-equalized schedules;
- a universal floating-point interpolation theorem.

The hybrid helper remains research vocabulary until later R0.11 phases and
consumer validation justify a production boundary.

### B.19 Phase-B conclusion

R0.11-B validates a clean distinction between:

```text
explicit positions
```

and:

```text
generated inclusive endpoint schedules
```

Explicit positions require no special zero- or one-element policy.

Generated inclusive endpoint schedules are semantically clean from:

```text
N >= 2
```

onward.

For finite endpoints, the tested hybrid arithmetic avoids the observed
opposite-sign overflow failure of the direct formula while preserving the exact
constant-schedule property that the pure weighted formula lost.

The complete historical DMD/LDC matrix passed with no hybrid-property
disagreement.

R0.11-B is therefore complete.

R0.11 remains in progress.
