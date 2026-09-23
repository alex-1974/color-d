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
