# R0.11-A — Primitive decomposition

This experiment is the first executable phase of R0.11.

It does not attempt to generate a complete design palette.

The purpose is to determine the smallest useful mathematical primitive for
raw OKLCH tone generation before adding:

- nonlinear schedules;
- chroma shaping;
- gamut mapping;
- target-space conversion;
- semantic palette roles;
- theme generation.

No public API is established by this experiment.

## Candidates

R0.11-A compares four increasingly policy-heavy forms.

### A — one raw tone

Conceptually:

```d
rawTone(lightness, chroma, hue)
```

This may turn out to be no more useful than constructing:

```d
Oklch!T(lightness, chroma, hue)
```

directly.

The experiment therefore treats A as a decomposition probe, not as an assumed
future API.

### B — explicit lightness schedule

Conceptually:

```d
tonesAtLightnesses(chroma, hue, lightnesses)
```

This constructs a raw OKLCH family with:

```text
L[i] = lightnesses[i]
C[i] = requested chroma
H[i] = requested hue
```

No clipping or gamut mapping occurs.

This is the main low-level candidate in phase A.

### C — seed convenience

Conceptually:

```d
tonesFromSeed(seed, lightnesses)
```

This uses:

```text
seed.c
seed.h
```

for the generated family.

The experiment deliberately checks whether `seed.l` has any semantic effect.

If two seeds with different lightness but identical chroma/hue generate the
same result, then the word "seed" hides the fact that only part of the input is
being consumed.

### D — exact anchor

Conceptually:

```d
anchoredTones(seed, anchorIndex, lightnesses)
```

An exact anchor requires:

```text
result[anchorIndex] == seed
```

This creates a semantic conflict when:

```text
lightnesses[anchorIndex] != seed.l
```

because exact anchor preservation and exact schedule preservation cannot both
hold.

R0.11-A makes that conflict observable rather than silently choosing one
policy.

## Composition probe — scalar `withLightness`

R0.11-A also tests whether a dedicated raw tone-scale primitive is necessary
at all.

The existing technical-spec direction already includes a scalar perceptual
manipulation primitive conceptually equivalent to:

```d
color.withLightness(lightness)
```

For OKLCH this operation has an unambiguous mathematical meaning:

```text
L = requested lightness
C = original chroma
H = original hue
```

A scale can then be formed mechanically by applying that scalar operation to
each caller-supplied lightness position.

Conceptually:

```d
tonesByLightness(color, lightnesses)
```

may be no more than:

```text
for each requested L:
    result = color.withLightness(L)
```

This probe asks whether candidate B and candidate C contain additional
mathematical semantics, or whether they are merely batch/convenience forms of
an already useful scalar primitive.

If so, R0.11 should distinguish:

```text
scalar color mathematics
```

from:

```text
container / scale-generation convenience
```

rather than inventing a larger primitive unnecessarily.

## Questions

The experiment asks:

1. Is candidate A merely an alternate spelling of direct construction?
2. Is B sufficient as the smallest reusable raw scale primitive?
3. Does C hide the fact that `seed.l` is ignored?
4. Does D necessarily introduce an anchor-vs-schedule policy?
5. Can the simple candidates remain:
   - `@safe`;
   - `pure`;
   - `nothrow`;
   - `@nogc`;
   - CTFE-capable?
6. Are all component-preservation properties exact because phase A performs no
   nonlinear arithmetic?
7. Can candidate C be expressed exactly as repeated scalar `withLightness`?
8. Can candidate B likewise be expressed as that scalar operation applied to
   any OKLCH exemplar carrying the requested chroma and hue?
9. If both are true, does the scale layer add mathematics or only batching?

## Deliberate exclusions

This phase does not yet decide:

- zero-step behavior;
- one-step behavior;
- runtime-sized output;
- lazy ranges;
- nonlinear/eased schedules;
- chroma curves;
- achromatic hue policy beyond preserving the represented value;
- gamut mapping;
- sRGB conversion;
- `deltaEOK` spacing;
- non-finite policy;
- performance beyond obvious implementation shape.

Those belong to later R0.11 phases.

## Expected interpretation

Candidate B is the strongest initial hypothesis for the lowest useful
scale-level operation.

However, the scalar-composition probe may show that the actual mathematical
primitive is `withLightness`, with B and C being only allocation-free batch or
convenience forms.

Candidate A may not justify any API at all.

Candidate C is expected to be convenient but semantically weaker if described
as a generic "seed" operation. If it is retained, semantics equivalent to
repeated `withLightness` may describe it more precisely.

Candidate D is expected to demonstrate that anchoring is separate policy and
must not be smuggled into ordinary raw scale generation.

`RESULTS.md` will be created only after observed compiler runs.

---

# R0.11-B — Schedule semantics

R0.11-A established that the scalar mathematical operation is conceptually:

```d
withLightness(color, L)
```

and that a raw tone collection can be obtained mechanically by applying that
operation over a sequence of requested lightness values.

R0.11-B therefore studies the sequence itself.

It does not revisit the R0.11-A primitive decomposition.

## B1 — Explicit positions

Caller-supplied lightness positions have no implicit spacing algorithm.

Examples:

```text
[]
[0.5]
[0.2, 0.8]
[0.95, 0.80, 0.60, 0.35, 0.10]
```

The experiment tests whether:

- an empty explicit schedule is representable;
- a single explicit position is unambiguous;
- arbitrary ascending and descending explicit schedules remain ordinary data.

For explicit positions:

```text
N == 0
```

means no requested tones.

For:

```text
N == 1
```

the one supplied lightness already specifies the result.

No midpoint/start/end policy is required.

## B2 — Generated inclusive linear schedule

A generated interval is different.

Conceptually:

```text
linearSchedule(start, end, N)
```

normally implies that both endpoints participate.

For:

```text
N >= 2
```

the inclusive interpretation is unambiguous:

```text
result[0]     = start
result[N - 1] = end
```

with interior samples between them.

For:

```text
N == 1
```

several plausible results exist:

```text
[start]
[midpoint]
[end]
```

None follows uniquely from the phrase "inclusive linear schedule".

R0.11-B therefore compares explicit singleton policies rather than silently
choosing one.

The principal hypothesis is that a generic inclusive endpoint schedule should
require:

```text
N >= 2
```

while explicit caller-supplied positions naturally handle zero and one item.

## B3 — Direct-difference formula

The straightforward formula is:

```text
start + (end - start) * t
```

This is algebraically correct over real numbers.

For floating-point values, however:

```text
end - start
```

may overflow even when:

- `start` is finite;
- `end` is finite;
- the mathematically interpolated value is finite.

R0.11-B tests this with large finite endpoints of opposite sign.

## B4 — Weighted-endpoint formula

A second candidate is:

```text
(1 - t) * start + t * end
```

For the large opposite-sign probe this avoids forming the potentially
overflowing full endpoint difference.

The experiment does not assume that this formula solves every floating-point
interpolation problem.

It tests whether it is a better candidate for the concrete lightness-schedule
requirements observed here.

## B5 — Endpoint preservation

Regardless of the interior formula, an inclusive schedule should preserve
requested endpoints exactly where possible:

```text
result[0]     == start
result[N - 1] == end
```

The research implementation therefore writes the endpoints explicitly and
uses interpolation only for interior elements.

This avoids making exact endpoint preservation depend on arithmetic rounding.

## B6 — Direction

A linear schedule must support both:

```text
start < end
```

and:

```text
start > end
```

without a separate algorithm.

The experiment validates:

- nondecreasing ascending schedules;
- nonincreasing descending schedules.

## B7 — Extended finite endpoints

The raw mathematical schedule is not initially restricted to:

```text
0 <= L <= 1
```

R0.11-B tests finite extended endpoints separately from later display/gamut
policy.

This does not yet establish the final public-domain contract.

## B8 — Composition with R0.11-A

A generated lightness schedule remains separate from color generation:

```text
linear L schedule
       ↓
tonesByLightness(color, schedule)
```

R0.11-B tests this composition explicitly.

No chroma shaping or gamut mapping is introduced.

## B9 — Questions

R0.11-B asks:

1. Can explicit schedules represent zero positions?
2. Is one explicit caller-supplied position already unambiguous?
3. Should an inclusive generated endpoint schedule require `N >= 2`?
4. Do start/midpoint/end singleton policies produce observably different
   answers?
5. Does the direct-difference interpolation formula lose finite-range
   robustness?
6. Does the weighted-endpoint form avoid that concrete failure?
7. Can exact endpoints be guaranteed independently from the interior formula?
8. Are ascending and descending schedules both monotonic?
9. Can finite extended endpoints remain mathematical inputs?
10. Does the resulting schedule compose mechanically with the validated
    R0.11-A `withLightness` model?

Observed R0.11-B results are recorded in `RESULTS.md` only after the compiler matrix was executed.

---

# R0.11-C — Chroma and hue policy

R0.11-A established scalar lightness replacement as the lowest useful raw
tone operation.

R0.11-B separated explicit positions from generated scalar schedules.

R0.11-C now asks whether chroma and hue introduce additional tone-scale
mathematics or whether they remain explicit scalar/component policy.

## C1 — Scalar component operations

The first candidates are conceptually:

```d
withChroma(color, chroma)
withHue(color, hue)
```

Their intended raw semantics are deliberately narrow:

```text
withChroma:
    replace C
    preserve L
    preserve stored H

withHue:
    replace stored H
    preserve L
    preserve C
```

No:

- gamut mapping;
- clipping;
- canonicalization;
- hue normalization;
- achromatic hue erasure

is implied by these raw operations.

## C2 — Explicit chroma schedules

Given:

```text
L[0 .. N]
C[0 .. N]
```

a raw scale may be formed mechanically as:

```text
result[i] =
    withChroma(
        withLightness(seed, L[i]),
        C[i]
    )
```

The experiment asks whether this introduces any additional color mathematics.

The principal hypothesis is that it does not.

## C3 — Constant chroma

A constant-chroma tone family is then merely the special case:

```text
C[i] = constant
```

for every requested position.

If so, constant chroma should not require a separate mathematical primitive.

## C4 — Generated chroma schedules

R0.11-B's finite scalar schedule machinery can also produce a sequence of
chroma values.

R0.11-C tests whether such a generated scalar sequence can be consumed
mechanically as chroma data.

This does not imply that a generic scalar schedule helper belongs in the final
public color API.

## C5 — Powerless hue

At:

```text
C == 0
```

hue is perceptually powerless.

R0.11-C does not reinterpret that as:

```text
hue is absent
```

or:

```text
hue must become zero
```

The experiment tests whether the stored hue can remain intact while chroma is
zero and become meaningful again if chroma is restored.

This follows the raw OKLCH representation direction already established in
R0.5.

## C6 — Raw hue

Raw hue storage is not normalized implicitly.

For example:

```text
725 degrees
```

may remain stored as:

```text
725 degrees
```

until an explicitly requested normalization operation is applied.

Tone-scale generation must not silently change that representation.

## C7 — Negative chroma

R0.5 already separated raw representation from canonicalization.

R0.11-C therefore tests that raw component replacement does not silently
canonicalize a negative chroma value.

Canonicalization remains a separate explicit operation.

This phase does not reopen R0.5's canonicalization semantics.

## C8 — What is deliberately not tested here

R0.11-C does not yet choose:

- an aesthetic chroma curve;
- automatic chroma reduction near light/dark extremes;
- maximum in-gamut chroma;
- a gamut-dependent chroma cap;
- a default gamut mapper;
- hue rotation for palette aesthetics;
- perceptually equal chroma spacing.

Those are either higher-level palette policy or belong to explicit gamut
composition.

## C9 — Questions

R0.11-C asks:

1. Is `withChroma` an independent scalar component operation?
2. Is `withHue` an independent scalar component operation?
3. Can explicit lightness and chroma schedules be zipped mechanically?
4. Does that zip preserve the requested L and C values exactly?
5. Does it preserve the seed hue exactly?
6. Is the zipped operation exactly equivalent to repeated scalar composition?
7. Is constant chroma merely an explicit constant C schedule?
8. Can a generated scalar schedule be consumed as chroma without new color
   mathematics?
9. Does setting chroma to zero preserve stored powerless hue?
10. Can chroma later be restored without losing that stored hue?
11. Does raw hue remain unnormalized?
12. Does raw negative chroma remain uncanonicalized?

Observed R0.11-C results are recorded in `RESULTS.md` only after the compiler matrix was executed.

---

# R0.11-D — explicit gamut composition

R0.11-A through R0.11-C established a raw tone-family layer:

```text
component operations
        ↓
explicit/generated scalar schedules
        ↓
raw OKLCH tone family
```

R0.11-D investigates how that raw family composes with the already validated
R0.8 target-gamut layer.

R0.11-D does not redesign gamut mapping.

The validated R0.8 semantics remain authoritative:

```text
inGamut
    diagnostic target-gamut membership

clip
    explicit target-coordinate saturation

gamutMap
    explicit perceptual transformation

ordinary conversion
    neither clipping nor mapping
```

The initial target remains sRGB.

## D1 — Raw family precedes gamut policy

Tone construction must remain possible without any target-gamut operation.

Conceptually:

```text
rawToneFamily(...)
```

may contain colors that are outside sRGB.

This is not an error.

The caller may subsequently choose:

```text
ordinary conversion
explicit clipping
Local MINDE mapping
Ray Trace mapping
```

according to its own target/output policy.

R0.11-D tests gamut mapping specifically.

It does not make clipping and perceptual mapping interchangeable.

## D2 — Mapping is explicit and downstream

The intended composition is:

```text
raw OKLCH tones
        ↓
explicit target + mapping method
        ↓
mapped target-space colors
```

not:

```text
tone generation
        ↓
hidden automatic gamut mapping
```

and not:

```text
generate a new chroma schedule implicitly because some tones are out of gamut
```

The raw tone family remains independently observable.

## D3 — Element-wise composition

For a raw family:

```text
raw[0 .. N]
```

mapping is conceptually point-wise:

```text
mapped[i] = mapper(raw[i])
```

R0.11-D asks whether this requires any additional palette mathematics.

Expected structural invariants are:

```text
same number of elements
same index correspondence
same ordering of elements
```

This does not mean that the mapped colors preserve every raw OKLCH component.

## D4 — Output space is the target space

The validated R0.8 perceptual mapping candidates produce target-space
`LinearSRgb` output.

Therefore R0.11-D treats:

```text
OKLCH raw family
```

and:

```text
mapped LinearSRgb family
```

as semantically distinct representations.

A mapped result is not silently converted back into a new authoritative raw
OKLCH schedule.

Round-tripping mapped output back to OKLCH may be useful for diagnostics, but
it does not redefine the original schedule.

## D5 — In-gamut identity

R0.8 established an in-gamut fast path.

For an already in-sRGB-gamut raw tone, R0.11-D expects:

```text
success == true
iterations == 0
mapped target color == ordinary target conversion
```

subject to the exact semantics of the validated R0.8 implementation.

This is an important composition property because an explicit mapping stage
must not unnecessarily alter already valid target colors.

## D6 — Out-of-gamut mapping

For representative finite out-of-gamut raw tones, both validated mapping
candidates should:

```text
report success
produce an in-sRGB-gamut target color
```

The two algorithms are not required to produce identical target colors.

R0.11-D must preserve the R0.8 distinction between:

```text
Local MINDE
Ray Trace
```

and must not infer a universal default mapper.

## D7 — Raw component schedules stop at the mapping boundary

Before mapping, R0.11-A through R0.11-C may establish exact properties such as:

```text
requested L preserved exactly
requested C preserved exactly
stored H preserved exactly
```

Those are raw-family properties.

After perceptual gamut mapping, R0.11-D must not require exact preservation of:

```text
L
C
H
```

when the original tone was out of gamut.

The purpose of gamut mapping is precisely to replace an unrepresentable target
color with a representable one.

## D8 — Raw anchoring versus mapped anchoring

If a seed or scheduled tone is already inside the target gamut, mapping may
preserve it through the R0.8 identity path.

If an exact raw anchor is outside the target gamut, these two requirements
cannot both hold:

```text
preserve the exact raw color
produce an in-target-gamut result
```

Therefore anchor preservation belongs primarily to the raw tone family.

A mapped output may preserve an anchor exactly only when target-gamut
constraints permit it.

## D9 — Lightness extremes

R0.8 established explicit target behavior:

```text
L <= 0
    -> destination black

L >= 1
    -> destination white
```

Consequently multiple distinct raw tones may collapse to the same mapped
target color.

R0.11-D therefore must not assume that mapping preserves:

```text
uniqueness
perceptual spacing
exact scalar spacing
```

across the mapped family.

Those are separate palette-quality questions.

## D10 — No feedback into raw chroma generation

R0.11-C separated explicit chroma scheduling from gamut policy.

R0.11-D must retain that separation.

This phase does not define an algorithm such as:

```text
generate C
test gamut
reduce C
regenerate scale
repeat
```

as the primitive tone-scale operation.

A future higher-level palette policy may deliberately use gamut information to
construct a chroma schedule.

That would be an explicit policy layer above the raw primitives.

## D11 — Mapping-method policy

R0.8 retained:

```text
Local MINDE
```

as a standards-oriented / perceptual reference candidate and:

```text
Ray Trace
```

as a bounded-cost / hot-path candidate.

R0.11-D consumes both as explicit alternatives.

It does not:

```text
rank them universally
choose a public default
hide method selection
```

## D12 — What R0.11-D should test

The executable experiment should test:

1. A raw tone family may contain both in-gamut and out-of-gamut tones.
2. No gamut operation occurs during raw family generation.
3. Mapping preserves family cardinality.
4. Mapping preserves index correspondence.
5. Mapping an in-gamut tone uses the identity/zero-iteration path.
6. Mapping an out-of-gamut finite tone produces an in-gamut result.
7. Both Local MINDE and Ray Trace compose with the same raw family.
8. Mapper outputs may differ without violating the contract.
9. Mapping is exactly equivalent to applying the chosen mapper independently
   to every raw tone.
10. Exact raw L/C/H schedule properties remain properties of the raw family,
    not mandatory properties of mapped target colors.
11. An out-of-gamut raw anchor cannot simultaneously remain exact and become
    an in-gamut target color.
12. Lightness-extreme tones may collapse to black or white.
13. No mapper is selected implicitly by the raw tone-family operation.
14. Mapping does not feed back into the raw chroma schedule.

## D13 — Deliberately out of scope

R0.11-D does not re-evaluate:

- Local MINDE algorithm quality;
- Ray Trace algorithm quality;
- EdgeSeeker;
- gamut-detection mathematics;
- clipping mathematics;
- deltaEOK;
- mapping performance;
- mapping iteration budgets;
- Display-P3;
- Rec.2020;
- HDR;
- image-wide rendering intent;
- a default public mapper.

Those questions are either already answered by R0.8 or require separate
consumer-driven research.

Observed R0.11-D results are recorded in `RESULTS.md` after the complete DMD/LDC Debug/Release matrix was executed.

---

# R0.11-E — representation and CTFE

R0.11-A through R0.11-D established the mathematical and compositional
semantics of raw OKLCH tone families.

R0.11-E investigates representation and execution form.

It does not introduce new tone mathematics.

The central question is whether the same element-wise tone semantics can be
expressed cleanly for:

```text
compile-time-known cardinality
runtime-known cardinality
```

without requiring allocation in the low-level primitive.

## E1 — Fixed-size static-array form

For a compile-time-known element count `N`, the natural D representation is:

```d
Oklch!T[N]
```

Candidate operations may return a static array by value.

R0.11-E should determine whether this form:

```text
supports ordinary runtime execution
supports CTFE
preserves exact element-wise semantics
remains @safe pure nothrow @nogc
requires no heap allocation
```

for representative scale sizes.

This phase does not assume that returning a static array is the only production
API.

## E2 — Caller-provided output form

For runtime-sized tone families, a natural allocation-free representation is a
caller-provided mutable slice:

```d
Oklch!T[] output
```

Conceptually:

```d
void tones(
    Oklch!T seed,
    const(T)[] lightnesses,
    const(T)[] chromas,
    Oklch!T[] output);
```

The low-level operation writes into storage owned by the caller.

The primitive itself therefore need not allocate.

R0.11-E should test the D semantics of this form rather than merely assuming
them.

## E3 — Shared element semantics

The static-array and caller-output forms must not become two independent tone
algorithms.

For every valid element index:

```text
staticResult[i]
==
callerOutput[i]
==
scalar composition for element i
```

The representation layer must not change the color semantics validated in
R0.11-A through R0.11-D.

## E4 — No allocation requirement

The low-level representation candidates should remain compatible with:

```d
@nogc
```

R0.11-E does not require that every future high-level convenience API be
allocation-free.

It asks only whether the reusable low-level primitive can be allocation-free.

A later convenience API may allocate explicitly if consumer evidence justifies
it.

## E5 — CTFE is a property of ordinary functions

R0.11 has consistently treated CTFE as use of the normal API at compile time,
not as a separate API family.

R0.11-E must retain that rule.

The static-array form should be exercised directly through `enum` or
`static assert`.

The caller-output form should also be tested at CTFE where D permits it.

R0.11-E must not assume in advance that mutable slices imply runtime-only use.

## E6 — Runtime-sized schedules

A runtime-sized schedule cannot produce a return type whose static-array length
depends on a runtime value.

Therefore runtime cardinality requires another storage strategy.

The initial candidate is:

```text
caller-owned output slice
```

rather than:

```text
hidden heap allocation
dynamic-array return owned by the primitive
```

R0.11-E should establish whether the caller-output form is sufficient for the
low-level layer.

## E7 — Length contract

Caller-provided schedules and output storage introduce a representational
precondition.

For a component-based scale:

```text
lightness count
chroma count
output count
```

must agree.

R0.11-E should investigate the mechanical contract for mismatched lengths.

This phase should not silently truncate with `zip`-style shortest-range
semantics unless evidence supports that policy.

Likewise, the low-level primitive should not silently allocate replacement
storage.

The experiment should make the mismatch behavior explicit.

## E8 — Empty output

A zero-length runtime schedule should be representable naturally:

```text
input length  = 0
output length = 0
```

and should perform no writes.

This should agree with the explicit zero-length static-array behavior already
observed in R0.11-B.

## E9 — Aliasing

Caller-provided output raises an issue absent from return-by-value static
arrays: aliasing.

R0.11-E should test whether meaningful input/output aliasing can occur and
whether the primitive needs an aliasing contract.

For the current tone primitives, schedules contain scalar values and output
contains `Oklch!T`, so direct element-type aliasing is structurally limited.

The experiment should record the actual D behavior rather than invent a broad
aliasing abstraction prematurely.

## E10 — Representation should not encode policy

Neither representation form should imply:

```text
gamut mapping
clipping
chroma shaping
hue normalization
anchoring policy
semantic theme roles
```

Representation is orthogonal to the tone semantics already validated.

## E11 — Candidate static API shape

A research candidate may be equivalent to:

```d
Oklch!T[N] tonesAtLightnessAndChroma(T, size_t N)(
    Oklch!T seed,
    const T[N] lightnesses,
    const T[N] chromas);
```

This is already close to the R0.11 research implementation.

R0.11-E evaluates its representation properties rather than treating its name
or signature as frozen public API.

## E12 — Candidate caller-output shape

A corresponding research candidate may be equivalent to:

```d
void tonesAtLightnessAndChromaInto(T)(
    Oklch!T seed,
    const(T)[] lightnesses,
    const(T)[] chromas,
    Oklch!T[] output);
```

The experiment should establish whether this can retain:

```d
@safe
pure
nothrow
@nogc
```

and produce the exact same elements as the fixed-size form.

Names remain provisional.

## E13 — Return value for caller-output form

R0.11-E should compare only simple possibilities justified by actual use:

```text
void
bool success
written-count
```

A richer result object should not be introduced unless the experiment exposes
a concrete need.

If equal lengths are a caller precondition that can be expressed cleanly, a
`void` low-level primitive may be sufficient.

If runtime mismatch requires explicit non-throwing handling, a small status
form may be justified.

This is a D/API question to be measured in the experiment.

## E14 — Runtime/CTFE equivalence

For representative schedules, R0.11-E should compare:

```text
compile-time static-array result
runtime static-array result
runtime caller-output result
compile-time caller-output result, if supported
```

All applicable forms must yield identical raw `Oklch` elements.

The comparison should cover both:

```text
float
double
```

## E15 — Size range

The experiment should cover more than one cardinality.

At minimum:

```text
N = 0
N = 1
small representative palette
larger representative palette
```

The purpose is not benchmarking arbitrary giant arrays.

It is to expose representation or compiler behavior that depends on size.

## E16 — Performance scope

R0.11-E is primarily a representation and compiler-semantics phase.

It should record gross anomalies if they appear, but it does not automatically
become a microbenchmark project.

Targeted generated-code or benchmark work is justified only if the candidate
representations show a meaningful ambiguity or regression.

## E17 — Compiler matrix

Use the established historical baseline:

```text
DMD 2.111.0
LDC 1.41.0
```

with:

```text
Debug
Release
float
double
CTFE
```

Do not broaden compiler coverage unless R0.11-E reveals a compiler-specific
problem.

## E18 — What R0.11-E should test

The executable experiment should determine:

1. Static-array return works for `N = 0`.
2. Static-array return works for `N = 1`.
3. Static-array return works for representative larger `N`.
4. Static-array output equals repeated scalar composition.
5. Static-array form works at CTFE.
6. Caller-provided output works for runtime-sized schedules.
7. Caller-output form performs no hidden allocation in the primitive.
8. Caller-output form can retain `@safe pure nothrow @nogc`.
9. Caller-output elements equal static-array elements.
10. Caller-output elements equal repeated scalar composition.
11. Empty caller-output schedules perform no writes.
12. Length mismatch behavior is explicit and deterministic.
13. Caller-output form can be exercised at CTFE if supported by D.
14. Runtime and CTFE results agree.
15. `float` and `double` expose the same representation semantics.
16. No additional container abstraction is required unless these candidates
    fail.

## E19 — Deliberately out of scope

R0.11-E does not decide:

- final public function names;
- dynamic-array convenience allocation;
- ranges or lazy tone generation;
- arbitrary output-range abstractions;
- SIMD/batch APIs;
- GPU representations;
- palette/theme objects;
- semantic color tokens;
- gamut mapping;
- color-quality heuristics;
- library-wide numerical tolerances.

Those require separate evidence.

## E20 — Strong hypotheses entering the experiment

R0.11-E begins with these hypotheses:

1. `Oklch!T[N]` is the simplest form when cardinality is known statically.
2. Caller-provided `Oklch!T[]` is sufficient for runtime-sized low-level
   generation.
3. Both forms can use exactly the same scalar tone semantics.
4. The low-level primitive need not allocate.
5. Both forms can remain `@safe pure nothrow @nogc`.
6. Static-array generation works naturally at CTFE.
7. Caller-output generation may also work at CTFE and should be tested.
8. Silent shortest-input truncation is undesirable for mismatched schedules.
9. No custom tone-scale container is justified initially.
10. No range abstraction is justified initially.
11. Representation must remain independent of gamut and palette policy.
12. Public API choice remains provisional until R0.12 and consumer review.

Observed R0.11-E results are recorded in `RESULTS.md` after the complete DMD/LDC Debug/Release matrix was executed.

---

# R0.11-F — properties and edge cases

R0.11-A through R0.11-E established:

```text
primitive decomposition
schedule semantics
chroma and hue semantics
explicit gamut composition
representation and CTFE behavior
```

R0.11-F is the final integration and edge-case phase.

It introduces no new tone-generation algorithm and no new public API
candidate.

Its purpose is to determine whether the already validated model remains
internally consistent across boundary values, unusual raw values and combined
use of the previously validated operations.

## F1 — Property phase, not another design phase

R0.11-F should primarily test invariants.

It should not redesign:

```text
withLightness
withChroma
withHue
generated schedule interpolation
static-array representation
caller-output representation
gamut mapping
```

unless an actual contradiction is discovered.

A failing property may reopen an earlier conclusion.

A passing property should not create a new abstraction merely because another
wrapper could be written.

## F2 — Cardinalities

Exercise representative tone-family cardinalities including:

```text
N = 0
N = 1
N = 2
N = 3
N = 5
N = 17
N = 32
```

The purpose is to cover:

```text
empty
singleton
minimal generated interval
odd/even small families
representative palette size
larger fixed-size family
```

R0.11-F does not need arbitrary huge arrays unless a compiler anomaly appears.

For explicit caller-supplied schedules:

```text
N = 0
N = 1
```

remain naturally valid.

For generated inclusive intervals, the R0.11-B rule remains:

```text
N >= 2
```

No new generated-`N=0` or generated-`N=1` policy is introduced.

## F3 — Cardinality invariants

For every valid tested family:

```text
result.length == requested schedule length
```

and, where both representations apply:

```text
staticResult.length == callerOutput.length
```

Cardinality must not depend on:

```text
component values
gamut status
hue magnitude
negative chroma
extended lightness
```

Raw generation performs no element insertion, deletion or deduplication.

## F4 — Extended finite raw values

The low-level raw tone model supports finite values outside ordinary UI or
display ranges.

R0.11-F should include representative finite values such as:

```text
L < 0
L = 0
0 < L < 1
L = 1
L > 1

C < 0
C = 0
C > typical sRGB chroma

H < 0 degrees
H = 0 degrees
H = 360 degrees
H > 360 degrees
multiple-turn hue values
```

Representative examples may include:

```text
L: -2, -0.25, 0, 0.5, 1, 1.25, 2
C: -1, -0.1, 0, 0.1, 0.5, 1
H: -720, -45, -0, 0, 360, 725, 1080
```

These are raw mathematical values.

The experiment must not implicitly reinterpret them as UI constraints.

## F5 — Extended finite exactness

For explicit component schedules, raw generation should preserve requested
finite component values exactly where the validated primitives are exact
component replacement.

For each index:

```text
raw[i].l == requestedL[i]
raw[i].c == requestedC[i]
raw[i].h == requestedH[i]
```

when those components were explicitly supplied.

This property is about raw component assignment.

It is not a claim that the resulting color lies in any display gamut.

## F6 — No implicit clamping

R0.11-F should explicitly verify that raw construction does not silently
transform:

```text
L < 0  -> 0
L > 1  -> 1
C < 0  -> 0
```

Likewise, it must not silently force hue into a canonical turn.

Raw operations remain raw.

Clipping and gamut mapping remain separate explicit operations.

## F7 — No implicit hue normalization

Previously validated examples such as:

```text
725 degrees
```

should be extended with additional raw hue values including negative and
multi-turn values.

The property is:

```text
stored hue == requested hue
```

for raw replacement/construction.

R0.11-F does not introduce a canonical hue interval.

## F8 — Powerless hue remains stored data

For:

```text
C = 0
```

stored hue remains representationally present.

R0.11-F should combine this with unusual hue values.

Examples:

```text
C = 0, H = -720
C = 0, H = 725
C = 0, H = +Inf
C = 0, H = NaN
```

where meaningful for the raw representation test.

Restoring nonzero chroma should not cause the raw layer to invent a different
stored hue.

NaN requires classification tests rather than equality.

## F9 — NaN and infinity scope

R0.11-F should test non-finite values only where the raw component operations
have meaningful representation semantics.

Representative cases:

```text
L = NaN
L = +Inf
L = -Inf

C = NaN
C = +Inf
C = -Inf

H = NaN
H = +Inf
H = -Inf
```

The question is not whether these are useful colors.

The question is whether the low-level raw primitives silently:

```text
clamp
normalize
replace
repair
canonicalize
```

them.

They should not.

## F10 — Non-finite property checks

Because:

```text
NaN != NaN
```

R0.11-F must not use ordinary equality as the NaN invariant.

Instead test classification:

```text
isNaN
isInfinity
sign where relevant
```

and verify that untouched components remain untouched.

For infinities, exact sign should remain observable:

```text
+Inf remains +Inf
-Inf remains -Inf
```

No universal "invalid color" wrapper is introduced by this phase.

## F11 — Generated schedules and non-finite endpoints

R0.11-F does not define new interpolation semantics for generated schedules
whose endpoints are NaN or infinite.

R0.11-B validated the generated schedule arithmetic for finite endpoints.

Therefore F should not infer a stable mathematical contract from expressions
such as:

```text
Inf - Inf
0 * Inf
NaN arithmetic
```

Non-finite testing is primarily for explicit/raw component composition.

If generated non-finite endpoints are probed, observations must be recorded as
observations rather than promoted into new API guarantees.

## F12 — Monotone lightness property

For a finite explicit lightness schedule that is nondecreasing:

```text
L[0] <= L[1] <= ... <= L[N-1]
```

raw tone construction must preserve the same ordering because it stores the
requested lightness values.

Likewise for nonincreasing schedules.

Changing chroma and hue schedules must not alter stored raw lightness.

This is a raw component invariant, not a perceptual-lightness guarantee after
gamut mapping.

## F13 — Generated finite lightness monotonicity

For generated finite inclusive schedules already covered by R0.11-B:

```text
start < end -> nondecreasing
start > end -> nonincreasing
start == end -> constant
```

R0.11-F may verify that composing those generated scalar positions into raw
tones preserves the same ordering.

It must not re-run the full R0.11-B arithmetic search unless a contradiction is
found.

## F14 — Chroma and hue independence

For raw tones constructed by component composition:

```text
changing C must not change L or H
changing H must not change L or C
changing L must not change C or H
```

This should be exercised across:

```text
ordinary values
extended finite values
selected non-finite replacement values
```

using classification tests where exact equality is not meaningful.

## F15 — Raw anchor invariants

R0.11-A/B established that an exact seed anchor and a mismatching requested
schedule cannot both be preserved automatically.

R0.11-F should preserve this distinction.

For a schedule containing exactly the seed components at index `k`:

```text
raw[k] == seed
```

where ordinary equality is meaningful.

For a schedule whose requested component differs from the seed:

```text
schedule value wins in an ordinary unanchored raw scale
```

unless the explicitly selected anchoring policy says otherwise.

No implicit nearest-anchor or seed-repair policy is introduced.

## F16 — Anchor versus gamut boundary

R0.11-D established that an out-of-gamut exact raw anchor cannot both remain
exact and become an in-target-gamut replacement.

R0.11-F should not reopen gamut-mapper selection.

At most it should verify the cross-phase structural property:

```text
raw anchor remains raw and observable
mapped result is a separate target-space result
```

for representative finite input.

No non-finite gamut-mapping experiment is required.

## F17 — Representation equivalence on edge values

For edge cases that are representable in both phase-E forms:

```text
static-array result
caller-output result
```

must preserve the same raw properties.

For ordinary and extended finite values, exact equality may be used.

For NaN-containing values, compare component classifications and unaffected
components rather than whole-struct equality.

Representation must not change semantics.

## F18 — Runtime and CTFE agreement

Representative property probes should execute through ordinary functions both:

```text
at runtime
at CTFE
```

The goal is semantic agreement, not compiler-generated-code identity.

At minimum include:

```text
finite extended values
negative chroma
multi-turn hue
monotone schedule
selected non-finite raw component cases
```

where D CTFE supports the ordinary operations.

No CTFE-specific tone API should be introduced.

## F19 — Float and double

Run the property suite for:

```text
float
double
```

The required invariant is semantic agreement.

R0.11-F does not require:

```text
float result bit pattern == double result bit pattern
```

or numerically identical rounding across scalar types.

Exact component replacement remains exact within each scalar type.

## F20 — Exact properties versus numerical tolerances

R0.11-F must keep two concepts separate.

### Exact structural properties

Examples:

```text
component copied unchanged
cardinality preserved
output not written on mismatch
stored hue not normalized
negative chroma not clamped
static and caller-output use the same operation
```

These may be tested exactly.

### Numerical approximation policy

Examples would include deciding a universal epsilon for:

```text
conversion round trips
perceptual equality
near-gamut comparisons
floating-point algorithm tolerances
```

R0.11-F must not define that policy.

A library-wide numerical tolerance policy is a separate R0 research block.

## F21 — No universal epsilon

Do not introduce an epsilon merely to make a property test pass.

If a property is inherently approximate, either:

```text
use an already validated operation-specific criterion
```

or:

```text
record that the property belongs to later tolerance research
```

Tone-scale raw component semantics should mostly permit structural or exact
tests.

## F22 — Gamut scope

R0.11-F consumes the R0.11-D result.

It does not re-evaluate:

```text
Local MINDE quality
Ray Trace quality
iteration budgets
mapper performance
default mapper selection
```

For finite representative raw colors, it may verify only already-established
composition properties.

No new mapper is introduced.

## F23 — Representation scope

R0.11-F consumes the R0.11-E result.

It does not reopen the already observed distinction:

```text
static array for statically known cardinality
caller-owned slice for runtime cardinality
```

unless an edge case exposes a genuine contradiction.

The bare written-count candidate remains rejected as the sole runtime status
channel because valid `N=0` and mismatch both produce zero.

## F24 — Allocation and attributes

Any new phase-F property helper representing low-level color operations should
remain compatible with:

```d
@safe
pure
nothrow
@nogc
```

Test-harness reporting itself need not be pure or `@nogc`.

The property phase must not accidentally require heap allocation in the
validated primitive path.

## F25 — Compiler matrix

Use the established baseline:

```text
DMD 2.111.0
LDC 1.41.0
```

with:

```text
Debug
Release
float
double
CTFE
```

Only broaden compiler coverage if F exposes a compiler-specific anomaly.

## F26 — Initial executable property set

The phase-F experiment should at minimum test:

1. Explicit `N=0` family remains empty.
2. Explicit `N=1` family preserves its sole requested components.
3. Representative cardinalities preserve requested length.
4. Extended finite lightness is preserved raw.
5. Negative chroma is preserved raw.
6. Large positive chroma is preserved raw.
7. Negative hue is preserved raw.
8. Multi-turn hue is preserved raw.
9. Zero chroma preserves stored powerless hue.
10. Restoring chroma preserves the stored hue.
11. No raw lightness clamp occurs.
12. No raw chroma clamp occurs.
13. No raw hue normalization occurs.
14. NaN lightness remains NaN.
15. Positive-infinite lightness remains positive infinity.
16. Negative-infinite lightness remains negative infinity.
17. NaN chroma remains NaN.
18. Positive/negative infinite chroma retains classification and sign.
19. NaN hue remains NaN.
20. Positive/negative infinite hue retains classification and sign.
21. Replacing one component leaves the other raw components unchanged.
22. Ascending explicit lightness remains nondecreasing.
23. Descending explicit lightness remains nonincreasing.
24. Constant explicit lightness remains constant.
25. Chroma/hue schedules do not alter stored lightness.
26. Generated finite ascending schedule remains monotone after tone
    composition.
27. Generated finite descending schedule remains monotone after tone
    composition.
28. Matching raw seed anchor remains exact.
29. Mismatching ordinary raw schedule remains visibly distinct from seed.
30. Static-array and caller-output forms agree on extended finite values.
31. Static-array and caller-output forms preserve equivalent classifications
    for selected NaN/Inf values.
32. Runtime and CTFE agree on representative finite edge cases.
33. Runtime and CTFE agree on selected non-finite raw classifications.
34. `float` and `double` expose the same property semantics.
35. Representative finite raw/mapped composition keeps raw and target result
    distinct.
36. No new container, mapper or tolerance abstraction is required if these
    properties hold.

The exact runtime check count may differ if multiple closely related
properties are combined into one check.

## F27 — Deliberately out of scope

R0.11-F does not establish:

- a library-wide floating-point epsilon;
- generic approximate equality;
- new conversion tolerances;
- a default gamut mapper;
- new gamut-mapping algorithms;
- non-finite gamut-mapping guarantees;
- a canonical hue interval;
- automatic chroma canonicalization;
- automatic clipping;
- palette aesthetic quality;
- contrast guarantees;
- semantic theme roles;
- final public names;
- consumer-specific palette ergonomics;
- performance micro-optimization unless an anomaly appears.

## F28 — Strong hypotheses entering the experiment

R0.11-F begins with these hypotheses:

1. Raw tone generation remains structurally exact for explicitly supplied
   finite components.
2. Extended finite values remain raw and are not silently clamped.
3. Negative chroma remains raw.
4. Hue remains stored without implicit normalization.
5. Powerless hue remains stored at zero chroma.
6. Raw component replacement does not silently repair NaN or infinity.
7. Non-finite classification can be tested without defining a generic
   "invalid color" abstraction.
8. Monotone finite lightness schedules remain monotone after raw tone
   composition.
9. Chroma and hue composition do not alter stored lightness.
10. Matching raw anchors remain exact.
11. Mismatching raw anchors remain an explicit policy conflict.
12. Static-array and caller-output representations preserve the same edge-case
    semantics.
13. Runtime and CTFE preserve the same raw properties.
14. `float` and `double` expose the same structural semantics.
15. R0.11-F will not require a universal epsilon.
16. R0.11-F will not require a new tone-scale container.
17. R0.11-F will not require a new gamut abstraction.
18. Passing F should allow R0.11 to close without another tone-generation
    research phase.

No R0.11-F result is recorded until observed compiler runs exist.
