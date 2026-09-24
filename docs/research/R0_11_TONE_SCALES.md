# R0.11 — OKLCH tone-scale generation

**Status:** R0.11 COMPLETE — A/B/C/D/E/F VALIDATED
**Issue:** https://github.com/alex-1974/color-d/issues/7
**Branch:** `research/r0_11-tone-scales`
**Base HEAD:** `35b3f6f8183e43a20f89ad7955c16409f8245e46`

This document is the durable repository-side research contract for R0.11.

The GitHub issue is the coordination surface. This document governs the
experiment carried out on this branch.

No public API is frozen by R0.11.

---

## 1. Goal

Validate the mathematical semantics, API boundary, output representation,
numerical behavior and CTFE suitability of low-level OKLCH tone-scale
generation.

R0.11 must determine which parts of tone-scale generation are reusable color
mathematics and which parts are aesthetic or application-level policy.

It does not design a complete theme system.

---

## 2. Inherited color-d architecture

R0.11 inherits the validated R0.1 through R0.10 decisions.

Relevant constraints include:

- color spaces are encoded in types;
- encoded and linear RGB remain distinct;
- color-space conversion is explicit;
- OKLCH is the primary polar perceptual space;
- finite extended computational values may exist;
- ordinary operations do not silently clip;
- gamut mapping is explicit;
- alpha and color coordinates are orthogonal concerns;
- NaN and infinity are not silently repaired;
- `float` and `double` are supported scalar types;
- CTFE is a first-class requirement where technically practical;
- scalar mathematical operations should remain allocation-free;
- semantic theme roles belong outside `color-d`;
- consumer requirements drive later API stabilization.

R0.11 must preserve these rules.

---

## 3. Existing technical-spec direction

The current technical specification identifies OKLCH as the preferred working
space for:

- tone scales;
- shades;
- hue-preserving transformations;
- semantic palette construction;
- gamut mapping.

It currently sketches possible interfaces such as:

```d
toneScale(base, parameters)
```

or:

```d
perceptualScale(base, range, steps)
```

but does not define their semantics.

R0.11 exists specifically to avoid freezing those sketches prematurely.

---

## 4. Reference context

There is no single normative OKLCH tone-scale algorithm.

R0.11 therefore uses external systems as comparison evidence rather than API
templates.

### 4.1 CSS Color 4

CSS Color 4 defines Oklab and OKLCH component semantics.

Relevant concepts include:

- Oklab lightness;
- OKLCH chroma;
- OKLCH hue;
- powerless / missing hue behavior;
- explicit color-space interpolation rules.

CSS Color 4 does not define a general-purpose tone-scale or design-palette
generation algorithm.

Reference:

https://www.w3.org/TR/css-color-4/

### 4.2 Color.js

Color.js exposes discrete color steps separately from interpolation policy.

Its interpolation facilities demonstrate that concepts such as:

- interpolation space;
- output space;
- number of steps;
- color-difference-limited subdivision;

can be independent choices.

This is useful architecture evidence, but R0.11 must not simply copy the
Color.js API.

Reference:

https://colorjs.io/docs/interpolation

### 4.3 Material Color Utilities

Material Color Utilities uses HCT rather than OKLCH.

Its tonal palettes vary tone while operating around hue/chroma intent and are
later consumed by higher-level semantic color roles.

Material's current dynamic-color documentation describes tonal palettes with
13 tones spanning tone 0 through tone 100.

This is useful evidence for separating:

```text
tonal palette mathematics
```

from:

```text
semantic role assignment
```

but HCT behavior is not an OKLCH specification.

Reference:

https://github.com/material-foundation/material-color-utilities/blob/main/concepts/dynamic_color_scheme.md

### 4.4 Tailwind CSS

Current Tailwind default color families expose practical 11-step palettes:

```text
50
100
200
300
400
500
600
700
800
900
950
```

and publish them using OKLCH coordinates.

These palettes demonstrate practical design-system use of OKLCH, but they are
curated palette data rather than a normative universal generation algorithm.

Reference:

https://tailwindcss.com/docs/colors

---

## 5. Core boundary

R0.11 studies low-level tone-scale generation.

It does not assign semantic roles such as:

```text
accent
warning
success
selected
hovered
road.primary
building.residential
```

Those belong to a higher-level design-token/theme layer.

R0.11 also does not yet define:

- complete light/dark themes;
- semantic palette relationships;
- typography/accessibility policy;
- GUI component roles;
- OSM feature styling;
- renderer adaptation.

Those are later consumers of the mathematical primitives.

---

## 6. Terminology

For R0.11:

### Tone position

A requested position along the lightness dimension.

This may be represented directly as OKLCH `L` or derived from a normalized
parameter.

### Tone

One generated color in the scale.

### Tone scale

An ordered collection of generated colors associated with ordered tone
positions.

### Seed / base color

A supplied color whose components may provide some combination of:

- hue;
- chroma;
- lightness;
- anchor identity.

R0.11 must determine which meaning belongs in each primitive.

### Anchor

A requirement that one generated tone reproduce a supplied base color exactly.

### Chroma policy

A rule controlling requested chroma across the scale.

### Gamut policy

A separate rule controlling how, or whether, generated colors are mapped into a
target gamut.

These terms must not be silently conflated.

---

## 7. Research question — primitive decomposition

The first architectural question is whether one large:

```d
toneScale(...)
```

operation is too policy-heavy.

Candidate decomposition:

```text
tone positions
      ↓
raw OKLCH tone generation
      ↓
optional chroma shaping
      ↓
explicit gamut mapping
      ↓
explicit target-space conversion
```

R0.11 should determine whether these layers need separate primitives.

A short convenience API must not hide:

- spacing policy;
- anchor policy;
- chroma policy;
- gamut policy.

---

## 8. Research question — primitive input

Compare at least these conceptual models.

### Model A — seed color

```d
toneScale(seed, positions)
```

Questions:

- Does `seed.l` matter?
- Is `seed` an exact anchor?
- Or does only `seed.c` / `seed.h` define the family?

### Model B — explicit hue/chroma

```d
toneScale(chroma, hue, positions)
```

Advantages:

- avoids pretending that one particular base lightness is important;
- clearly describes a constant-hue/chroma family.

Disadvantages:

- less convenient for consumers beginning from one color.

### Model C — explicit anchor

Conceptually:

```d
toneScale(seed, anchorIndex, positions)
```

or an equivalent representation.

This makes exact preservation visible.

### Model D — endpoint interpolation

```d
toneScale(dark, light, steps)
```

This is structurally closer to interpolation than tone generation and may
belong to R0.7-style interpolation rather than R0.11 tone semantics.

R0.11 must determine whether endpoint interpolation is actually the same
abstraction.

---

## 9. Research question — lightness schedule

Do not assume one universal lightness curve.

Compare at least:

### Linear OKLCH lightness

For `N` tones:

```text
L0 ... LN-1
```

equally spaced between requested endpoints.

This is mathematically simple and should serve as a baseline.

### Caller-supplied lightness positions

Example:

```text
0.97
0.93
0.88
0.80
0.70
0.60
0.50
0.40
0.30
0.22
0.15
```

The exact values above are illustrative only.

A caller-supplied schedule may be the most policy-transparent primitive.

### Parametric/eased schedule

Possible normalized curve:

```text
t -> L(t)
```

R0.11 should investigate whether color-d should provide such curves or merely
consume positions generated elsewhere.

### Perceptual-distance-oriented schedule

R0.10 `deltaEOK` may be used diagnostically to inspect adjacent distances.

Do not assume:

```text
equal deltaEOK
```

is necessarily the correct definition of a useful UI tone scale.

---

## 10. Monotonicity

For a monotonically ordered requested lightness schedule, raw generated tones
should preserve the same ordering unless an explicitly named policy says
otherwise.

This gives a useful property:

```text
L[i] <= L[i + 1]
```

or the corresponding descending relation.

Gamut mapping may affect the final target-space appearance and must be studied
separately from the raw tone-generation property.

---

## 11. Base-color anchoring

R0.11 must explicitly decide whether a seed color is:

1. an exact member of the output;
2. only a hue/chroma source;
3. an approximate perceptual reference;
4. meaningful only when its lightness appears in the supplied schedule.

Candidate invariant for an explicit anchored form:

```text
result[anchor] == seed
```

subject only to exact scalar representation.

An unanchored primitive must not imply this property.

---

## 12. Hue policy

For a chromatic tone family, the simplest baseline is constant hue:

```text
H[i] = Hseed
```

where hue is meaningful.

R0.11 must test:

- ordinary chromatic values;
- zero chroma;
- near-zero chroma;
- wrapped hue;
- large/unbounded hue representations if supported by the inherited model;
- NaN hue where inherited semantics allow observation.

The R0.5 powerless/achromatic hue conclusions remain authoritative.

Tone generation must not invent hidden hue rotation.

Optional aesthetic hue drift, if useful later, should be a separate explicit
policy.

---

## 13. Chroma policy

Chroma is a major policy boundary.

Compare at least:

### Constant requested chroma

```text
C[i] = Cseed
```

This is the clean mathematical baseline.

### Caller-supplied chroma schedule

```text
C[i] = schedule[i]
```

This permits explicit shaping without hiding an aesthetic curve in the
library.

### Parametric chroma curve

Potentially useful for reducing chroma toward black and white.

R0.11 must determine whether this belongs in low-level color math or in a
higher palette policy layer.

### Gamut-constrained chroma

A target-gamut operation may need to reduce chroma.

This must remain conceptually distinct from the requested raw scale.

A raw tone generator must not silently reduce chroma merely because a target
display gamut cannot represent the result.

---

## 14. Gamut boundary

R0.8 established:

```text
inGamut
clip
gamutMap
```

as separate operations.

R0.11 must preserve that architecture.

Candidate preferred layering:

```text
raw OKLCH tone scale
        ↓
explicit gamutMap(...)
        ↓
target-space conversion
```

Questions:

- Should a low-level scale contain out-of-gamut values? Likely yes.
- Should a convenience function accept an explicit mapping method?
- Should mapped and unmapped scale generation use different names?
- Should target gamut be represented independently from scale semantics?

No default mapping method should be frozen merely because tone scales often
need displayable output.

---

## 15. Output representation

The core primitive should not require GC allocation.

Compare at least:

### Compile-time static array

Conceptually:

```d
Oklch!T[N]
```

Advantages:

- size encoded in the type;
- stack/value semantics;
- CTFE-friendly;
- suitable for built-in palettes.

Questions:

- semantics for `N == 0`;
- compile-time cost for larger `N`;
- ergonomics for caller-supplied positions.

### Caller-provided output

Conceptually:

```d
generateToneScale(seed, positions, output)
```

Advantages:

- runtime-size flexibility;
- no allocation required by color-d.

Questions:

- aliasing;
- range length mismatch;
- attribute preservation;
- CTFE ergonomics.

### Lazy range

Potentially flexible, but may add template/API complexity without a concrete
consumer benefit.

Do not introduce a lazy public abstraction without evidence.

---

## 16. Step-count semantics

Explicitly test:

```text
0
1
2
5
9
10
11
13
large N
```

Questions:

### Zero

Is an empty scale meaningful and representable?

Do not assume D's type/CTFE behavior without testing.

### One

Possible interpretations include:

- seed;
- midpoint;
- first endpoint;
- sole supplied position.

The primitive must not guess.

### Two

This may collapse into endpoints/interpolation semantics.

### Ordinary palette counts

5, 9, 10, 11 and 13 are useful practical cases, but none should become a
hard-coded architectural assumption.

---

## 17. Extended-value semantics

Color-d computational types permit finite extended values.

R0.11 must distinguish:

```text
mathematically computable raw OKLCH scale
```

from:

```text
nominal display-oriented tone schedule
```

Research at least:

- `L < 0`;
- `L > 1`;
- negative chroma if the inherited type permits representation;
- high chroma;
- very large finite hue;
- out-of-sRGB but finite colors.

Do not silently clamp an extended raw input.

If a particular primitive requires nominal positions such as:

```text
0 <= L <= 1
```

that requirement must be explicit and justified.

---

## 18. Non-finite semantics

Test:

```text
NaN
+Inf
-Inf
```

in:

- lightness;
- chroma;
- hue;
- schedule values.

The core must not silently turn non-finite input into plausible finite palette
colors.

Determine whether ordinary propagation is sufficient or whether a checked
diagnostic has a concrete consumer requirement.

Do not copy the R0.9 checked-result model automatically.

---

## 19. Alpha boundary

Tone-scale generation operates on color coordinates.

Primary hypothesis:

```text
Alpha!(Oklch!T)
```

is not required by the lowest-level primitive.

Possible higher-level behavior:

- preserve one fixed alpha orthogonally;
- provide independent alpha scheduling;
- resolve alpha only at a later theme/rendering layer.

R0.11 must not:

- composite alpha;
- infer a background;
- use alpha to alter tone mathematics.

---

## 20. Mathematical properties

Test useful properties for both `float` and `double`.

Candidate properties:

### Determinism

Identical inputs produce identical outputs.

### Schedule preservation

For direct raw generation:

```text
result[i].l == requestedL[i]
```

where the primitive promises direct positions.

### Monotonicity

Monotonic input lightness schedule implies monotonic output lightness.

### Hue preservation

For meaningful chromatic hue and a constant-hue primitive:

```text
result[i].h == requestedHue
```

subject to the inherited canonicalization policy.

### Chroma preservation

For a constant-chroma raw primitive:

```text
result[i].c == requestedChroma
```

unless a separately selected chroma policy says otherwise.

### Anchor preservation

Where explicitly promised:

```text
result[anchor] == seed
```

### Finite closure

For finite raw inputs and arithmetic that does not overflow:

```text
finite input -> finite raw output
```

### CTFE/runtime equivalence

The same normal API should produce equivalent results at compile time and
runtime.

---

## 21. deltaEOK diagnostics

R0.10 provides the validated Oklab Euclidean distance primitive.

R0.11 may use `deltaEOK` to report:

- adjacent tone distances;
- distance variance across a scale;
- effect of chroma shaping;
- effect of gamut mapping.

This is diagnostic evidence.

Do not make equal `deltaEOK` spacing an implicit contract unless the experiment
shows a concrete reason to expose such a primitive.

---

## 22. Comparison scales

R0.11 should inspect several families rather than optimize for one hue.

Include representative seeds or hue/chroma families around:

```text
red
orange
yellow
green
cyan
blue
purple
magenta
near-neutral
high-chroma
```

The purpose is to detect:

- hue-dependent sRGB gamut limits;
- endpoint chroma behavior;
- nonuniform effects from mapping;
- accidental assumptions tied to one test color.

These are experiment families, not semantic palette roles.

---

## 23. Reference strategy

Because there is no normative tone-scale algorithm, reference validation must
be layered.

### Exact mathematical references

Use analytically constructed raw OKLCH scales where expected components are
known directly.

Examples:

```text
constant hue
constant chroma
explicit lightness schedule
exact anchor
```

### External comparison data

Use selected published palette values from systems such as Tailwind or Material
only as comparative evidence.

Do not treat them as exact expected output for a different algorithm.

### Cross-block evidence

Reuse validated:

- R0.5 OKLCH/hue semantics;
- R0.8 gamut operations;
- R0.10 `deltaEOK`;

where useful.

The candidate under test must not be its own only oracle.

---

## 24. CTFE

CTFE is a primary R0.11 requirement.

Candidate tests should include:

```d
enum scale = ...;
static assert(...);
```

for:

- small fixed-size scales;
- caller-supplied compile-time positions;
- float;
- double;
- anchor invariants;
- monotonicity;
- constant hue/chroma invariants.

No separate `toneScaleCtfe` API should exist.

---

## 25. Attributes

Where the operation shape permits, validate:

```d
@safe
pure
nothrow
@nogc
```

Do not mechanically force attributes onto an abstraction that cannot honestly
support them.

The experiment should record any D-language or Phobos limitation encountered.

---

## 26. Allocation policy

The mathematical tone-scale primitive should not require heap allocation.

Candidate allocation-free approaches include:

```text
static arrays
caller-provided output
compile-time generated immutable data
```

A higher-level ergonomic API may later allocate if a concrete consumer wants
that behavior, but allocation must not be mandatory in the mathematical core.

---

## 27. Performance scope

Tone-scale generation is expected primarily during:

- theme construction;
- style initialization;
- CTFE;
- user-driven theme editing.

It is not currently a demonstrated per-pixel hot path.

Therefore R0.11 should prioritize:

1. correctness;
2. semantic clarity;
3. CTFE behavior;
4. compile-time cost sanity;
5. ordinary runtime sanity.

Do not perform extensive nanosecond optimization without evidence.

Issue #5 remains the project-wide performance and compiler-retest tracker.

---

## 28. Compile-time cost

Unlike previous scalar operations, a tone scale creates multiple values.

R0.11 should record compile-time behavior for representative sizes such as:

```text
5
11
13
32
64
```

This does not require a full compiler benchmark suite.

The goal is to detect:

- pathological template instantiation;
- excessive CTFE work;
- accidental allocation;
- poor scaling with output length.

---

## 29. API layering

R0.11 should keep these layers conceptually separate:

```text
tone schedule
    ↓
raw OKLCH generation
    ↓
chroma policy
    ↓
explicit gamut mapping
    ↓
target-space conversion
    ↓
palette construction
    ↓
semantic role assignment
    ↓
theme validation
```

Not every layer necessarily needs a public function.

The experiment must determine the smallest useful reusable mathematical
surface.

---

## 30. Relationship to R0.12

The intended next research block is compile-time palette/theme generation and
validation.

R0.11 should hand R0.12 validated low-level building blocks, not theme
semantics.

R0.12 may need concepts such as:

- semantic palette roles;
- multiple related scales;
- light/dark scheme construction;
- contrast constraints;
- state differentiation;
- compile-time validation.

Those are deliberately outside R0.11.

---

## 31. Candidate experiment structure

```text
docs/research/R0_11_TONE_SCALES.md

experiments/r0_11_tone_scales/
    README.md
    dub.sdl
    source/app.d
    RESULTS.md
```

`RESULTS.md` must not be created until observed compiler runs exist.

---

## 32. Candidate experiment phases

### R0.11-A — primitive decomposition

Prototype the smallest raw OKLCH operations.

Compare:

```text
seed color
explicit hue/chroma
explicit schedule
anchor-aware form
```

### R0.11-B — schedule semantics

Compare:

```text
linear
explicit positions
simple nonlinear schedule
deltaEOK diagnostics
```

### R0.11-C — chroma and hue

Test:

```text
constant hue
achromatic cases
constant chroma
explicit chroma shaping
```

### R0.11-D — gamut composition

Compare raw scale output with explicitly mapped output using validated R0.8
operations.

No implicit mapper.

### R0.11-E — representation and CTFE

Compare:

```text
static array
caller output
other allocation-free forms only if justified
```

Validate DMD and LDC behavior.

### R0.11-F — properties and edge cases

Exercise:

```text
step counts
extended values
NaN/Inf
monotonicity
anchors
CTFE/runtime agreement
```

---

## 33. Compiler matrix

Use the established historical baseline:

```text
DMD 2.111.0
LDC 1.41.0
```

Validate at minimum:

```text
float
double
debug
release
CTFE
```

Do not broaden to newer compiler versions merely because they exist.

Targeted newer-compiler work belongs under issue #5 unless R0.11 exposes a
new compiler-specific problem.

---

## 34. Initial hypotheses

R0.11 begins with these hypotheses.

1. OKLCH is the correct initial working space for tone-scale primitives.
2. A raw tone scale should not silently imply target-gamut displayability.
3. Explicit caller-supplied lightness positions are the safest low-level
   schedule primitive.
4. Equal numeric OKLCH-lightness spacing is useful as a baseline, not as a
   universal design rule.
5. A seed color and an exact anchor are different concepts and should not be
   conflated.
6. Constant hue is the correct baseline where hue is meaningful.
7. Achromatic/powerless hue must follow R0.5 semantics rather than new
   tone-specific rules.
8. Constant requested chroma is the correct raw baseline.
9. Aesthetic chroma shaping should be explicit.
10. Gamut mapping remains a separate explicit operation.
11. Fixed-size static arrays are likely useful for CTFE-built scales.
12. Caller-provided output is likely useful for runtime-sized scales.
13. The core primitive need not allocate.
14. `deltaEOK` is useful as a diagnostic but should not automatically define
    the schedule.
15. Alpha is outside the raw tone-coordinate primitive.
16. Palette and semantic-theme generation remain later layers.
17. No public tone-scale API should be frozen before R0.12 and consumer review.

---

## 35. Decisions R0.11 must make

The experiment must end with explicit answers to:

1. What is the smallest reusable tone-scale primitive?
2. Does it consume a seed color or explicit hue/chroma?
3. What does a supplied base color mean?
4. Is exact anchoring part of the primitive?
5. How are tone/lightness positions supplied?
6. Is linear lightness scheduling provided by color-d?
7. Are nonlinear schedules part of color-d or caller policy?
8. What is the default/raw hue behavior?
9. What is the default/raw chroma behavior?
10. Where does chroma shaping live?
11. Does the raw primitive permit out-of-gamut results?
12. How is explicit gamut mapping composed?
13. What output representation is preferred?
14. What happens for zero and one step?
15. What finite extended inputs are accepted?
16. What happens for NaN and infinity?
17. Is alpha rejected or preserved only by a separate layer?
18. Which properties are durable tests?
19. Which CTFE form is viable?
20. Which pieces become R1/R3 candidates?
21. Which palette/theme concerns are explicitly deferred to R0.12?

---

## 36. Explicit non-goals

R0.11 does not finalize:

- semantic theme roles;
- complete Material-style schemes;
- Tailwind-compatible palette reproduction;
- automatic AA/AAA role assignment;
- application-specific contrast policy;
- OSM map-style semantics;
- adaptive map-background rendering;
- color-vision-deficiency palettes;
- categorical/scientific palettes;
- image palette extraction;
- Display-P3 tone policies;
- Rec.2020 tone policies;
- HDR tone mapping;
- ICC/profile behavior;
- CSS parsing/serialization;
- animation between themes;
- a universal aesthetic definition of a "good" palette.

---

## 37. Exit criteria

R0.11 is complete when:

- the low-level tone-scale boundary is explicit;
- primitive input semantics are decided;
- tone-position semantics are validated;
- base/anchor semantics are explicit;
- hue behavior is explicit;
- chroma behavior is explicit;
- gamut behavior is explicit;
- zero/one/two-step behavior is recorded;
- finite extended input behavior is recorded;
- non-finite behavior is recorded;
- output representation is justified;
- allocation behavior is recorded;
- float/double behavior is validated;
- CTFE is validated;
- relevant attributes are validated;
- useful mathematical properties are tested;
- comparison/reference evidence is recorded;
- R0.12 handoff is explicit;
- ROADMAP and TECHNICAL_SPEC conclusions are updated;
- results are merged to `main`;
- no public API is frozen before consumer validation.

---

## 38. Research rule

R0.11 must prefer explicit composition over a convenient but policy-heavy
single operation.

In particular, the experiment must not make any of the following implicit
without evidence:

```text
lightness curve
base anchor
hue drift
chroma curve
gamut mapper
target color space
semantic role
contrast threshold
```

The purpose of R0.11 is not to generate attractive screenshots.

The purpose is to determine the smallest correct, composable and
consumer-usable mathematical foundation for future tone scales and palettes.
