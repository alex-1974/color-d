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
