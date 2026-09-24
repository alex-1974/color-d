# R0.12 — Compile-time palette construction and validation

**GitHub:** #8 — R0.12 — Validate compile-time palette construction and validation

R0.12 is an integration research block.

R0.1–R0.11 have already established the relevant low-level mathematical
semantics independently.

R0.12 asks whether those primitives compose into useful compile-time palette
construction and validation without introducing an unnecessary palette engine,
theme model or hidden policy into `color-d`.

No public API is established by this experiment.

`RESULTS.md` must not be created until executable evidence has been observed.

---

# 1. Research boundary

The experiment distinguishes three layers.

```text
color-d mathematical primitives
        ↓
generic palette composition
        ↓
application theme / design-token semantics
```

R0.12 studies the first boundary:

```text
mathematical primitives
        ↓
generic palette composition
```

It does not move application semantics into `color-d`.

Concepts such as:

```text
accent
warning
success
selected
hovered
road.primary
building.residential
ThemeMode.light
ThemeMode.dark
ThemeMode.highContrast
```

are deliberately excluded from the library-side experiment.

A consumer may assign such meaning to the generated colors later.

---

# 2. Existing validated foundation

R0.12 does not reopen the algorithms already researched by earlier blocks.

The relevant foundation is:

```text
R0.1   typed color values and CTFE
R0.2   encoded / linear sRGB transfer
R0.3   linear sRGB / XYZ D65
R0.4   XYZ D65 / Oklab
R0.5   Oklab / OKLCH and hue semantics
R0.8   gamut detection, clipping and explicit perceptual mapping
R0.9   WCAG-2 relative luminance and contrast measurement
R0.10  deltaEOK measurement
R0.11  raw OKLCH tone composition and finite schedules
```

R0.12 may reuse or adapt those validated research implementations.

Any local integration fixture remains research-only.

Copying a research fixture into R0.12 does not promote it into production API.

---

# 3. Central hypothesis

The primary hypothesis is:

> A useful compile-time palette can be constructed by ordinary composition of
> already validated color-d primitives, without a new policy-heavy palette
> generator or a color-d-specific palette container.

Conceptually:

```text
compile-time seed colors
        ↓
explicit OKLCH schedules
        ↓
explicit chroma / hue policy
        ↓
raw OKLCH families
        ↓
explicit target-gamut mapping
        ↓
explicit target-space conversion
        ↓
measurements / structural predicates
        ↓
caller-defined acceptance policy
        ↓
compile-time result
```

The experiment must make every policy boundary visible.

---

# 4. What "palette" means in R0.12

For this research block, a palette is only a finite collection of color
families.

It does not imply semantic application roles.

Examples of acceptable research terminology are:

```text
family 0
family 1
family 2

tone 0
tone 1
...
tone N
```

The experiment may use a consumer-local aggregate to hold several families.

That aggregate is not presumed to belong in `color-d`.

One of the research questions is whether ordinary D representation is already
sufficient.

---

# 5. Policies that must remain explicit

R0.12 must not hide any of the following behind a universal palette builder:

```text
lightness schedule
chroma schedule
hue adjustment
gamut mapper
target color space
contrast threshold
contrast comparison pairs
deltaEOK threshold
deltaEOK comparison pairs
monotonicity requirement
finite-value requirement
application semantic role
```

A candidate abstraction that implicitly chooses one of these is evidence of a
policy boundary, not automatically evidence for a public API.

---

# 6. Validation boundary

R0.12 distinguishes:

```text
measurement
```

from:

```text
acceptance policy
```

For example:

```text
contrastRatio(a, b)
```

is mathematical measurement.

The statement:

```text
contrastRatio(a, b) >= requestedThreshold
```

contains caller policy.

Likewise:

```text
deltaEOK(a, b)
```

is measurement.

The statement:

```text
deltaEOK(a, b) >= requestedMinimum
```

contains caller policy.

R0.12 must therefore not assume one universal:

```d
validatePalette(...)
```

contract unless executable evidence demonstrates a genuinely generic semantic
operation that cannot be expressed cleanly through existing primitives.

---

# 7. Numerical-policy boundary

R0.13 / GitHub #9 separately studies library-wide numerical tolerance and
reference policy.

R0.12 must not pre-empt that work by inventing a universal epsilon.

Where R0.12 requires approximate numerical comparison, it may reuse
operation-local research tolerances already established by the corresponding
earlier experiment.

Such tolerances remain research-local and provisional until R0.13.

Structural properties should remain exact where possible.

Examples:

```text
cardinality
component preservation
array dimensions
policy separation
unchanged raw family after mapping
finite classification
gamut classification
monotonic ordering where exact inputs make that property exact
```

---

# 8. Non-finite boundary

R0.11 established raw component preservation for NaN and infinity but did not
establish non-finite gamut-mapping semantics.

R0.12 therefore must not accidentally create such a contract.

Non-finite values may be used where the tested operation already has an
established raw-value contract.

They must not be sent through gamut mapping merely to expand R0.12 coverage.

---

# 9. Candidate architecture under test

The default candidate is ordinary explicit composition.

Conceptually:

```d
auto rawFamily = ...;       // explicit schedules
auto mapped    = ...;       // explicitly selected mapper
auto target    = ...;       // explicit target-space representation

auto contrast = ...;        // measurements
auto distance = ...;

bool accepted =
    callerChosenConditions(...);
```

For multiple families, ordinary D representation is the baseline candidate.

Examples include:

```text
static arrays
nested static arrays
consumer-defined structs containing static arrays
```

R0.12 does not begin by assuming a library-owned:

```text
Palette
PaletteBuilder
Theme
ThemeBuilder
PaletteValidator
```

type.

Any such abstraction must earn its existence through observed evidence.

---

# 10. Research phases

## R0.12-A — Vertical composition and ownership boundary

Question:

> Can representative multi-family palette construction be expressed cleanly
> by ordinary composition of the validated primitives?

Exercise at least:

- more than one independent seed/family;
- explicit lightness schedules;
- explicit chroma policy;
- at least one out-of-gamut case requiring explicit mapping;
- target-space conversion;
- no semantic application roles.

Compare:

```text
ordinary explicit composition
```

against any convenience helper that appears useful during implementation.

Determine whether the helper adds mathematical semantics or merely batching.

### A exit criteria

- multiple families compose successfully;
- raw families remain distinct from mapped output;
- gamut policy is explicit;
- target-space conversion is explicit;
- no Theme/application semantics are required;
- any proposed helper has a precise semantic justification.

---

## R0.12-B — Validation composition

Question:

> Can palette validation be composed from measurements and explicit
> caller-owned acceptance rules?

Exercise:

- finite-value predicates where applicable;
- target-gamut checks;
- WCAG-2 contrast measurements;
- `deltaEOK` measurements;
- explicit lightness-order checks;
- caller-selected comparison pairs;
- caller-selected thresholds.

Compare at least:

```text
one opaque aggregate bool validator
```

with:

```text
explicit measurement + explicit acceptance composition
```

The experiment should expose whether a generic library-side validation
primitive adds real semantics or hides policy/diagnostics.

### B exit criteria

- measurement and acceptance policy remain distinguishable;
- thresholds remain caller-visible;
- comparison pairs remain caller-visible;
- no universal accessibility/perceptual threshold is introduced;
- any reusable predicate is justified independently.

---

## R0.12-C — Representation and CTFE

Question:

> Are ordinary D value representations sufficient for compile-time palettes?

Exercise representative compile-time-known dimensions using:

```text
static arrays
nested static arrays and/or
a consumer-local struct containing static arrays
```

Test:

- CTFE construction;
- storage as `static immutable`;
- compile-time validation;
- runtime construction through the same ordinary functions;
- runtime/CTFE agreement where the tested property has an established
  comparison rule.

No separate CTFE API family is permitted merely because the operation runs at
compile time.

### C exit criteria

- the same ordinary operations work at runtime and CTFE;
- compile-time-known palette cardinality needs no custom dynamic container;
- `static immutable` can hold the finished compile-time result;
- no hidden allocation is required by the low-level construction path;
- any custom palette type is justified by semantics, not storage convenience.

---

## R0.12-D — Coarse CTFE cost

Question:

> Does representative palette construction show any pathological compile-time
> scaling that changes the architecture?

This is not a compiler benchmark campaign.

Measure only enough representative palette sizes to detect obvious pathological
behavior.

Keep separate:

```text
runtime performance
compile-time cost
```

Record:

- exact compiler/version;
- build configuration;
- palette dimensions;
- whether mapping is included;
- wall/user time where practical.

Do not claim portable timing guarantees.

Do not optimize from one noisy timing result.

### D exit criteria

- no obvious pathological CTFE behavior is ignored;
- any material anomaly is reproducible before influencing architecture;
- no performance-specific API is introduced without evidence.

---

## R0.12-E — Integration and edge properties

Final integration phase.

Exercise representative combinations such as:

- several palette cardinalities;
- multiple independent hues;
- achromatic/zero-chroma raw values;
- extended finite raw values where supported;
- naturally in-gamut families;
- families requiring explicit gamut mapping;
- raw-versus-mapped separation;
- runtime/CTFE agreement;
- compile-time validation success;
- deliberately failing caller validation.

This phase must not reopen the underlying color algorithms.

### E exit criteria

- representative multi-family palettes work through the composed architecture;
- raw and mapped representations remain distinct;
- policies remain explicit;
- runtime and CTFE paths agree under established comparison rules;
- failed validation is observable at compile time;
- no application semantic roles enter `color-d`;
- no new abstraction survives unless evidence demonstrates a real semantic
  need.

---

# 11. Candidate outcomes

R0.12 is allowed to conclude that no new public palette abstraction is needed.

Possible outcomes include:

## Outcome A — composition is sufficient

```text
existing scalar/color primitives
+
ordinary arrays
+
caller-owned policy
```

are enough.

This is a successful research result.

## Outcome B — one or more generic primitives are justified

A new primitive may be proposed only if it:

- has semantics independent of application roles;
- does not hide gamut/threshold/theme policy;
- materially reduces duplicated mechanical work;
- remains type-safe;
- works through ordinary runtime and CTFE use;
- has a clear ownership reason to live in `color-d`.

## Outcome C — palette abstraction belongs above color-d

If useful construction necessarily requires semantic roles, theme modes,
design-token relationships or application policy, that abstraction belongs in
a higher-level consumer/theme library rather than `color-d`.

---

# 12. Explicit non-goals

R0.12 does not establish:

- application theme roles;
- GUI widget states;
- OSM style semantics;
- Light/Dark/High-Contrast theme policy;
- a universal tone curve;
- a universal chroma curve;
- a default gamut mapper;
- a universal contrast threshold;
- a universal perceptual-distance threshold;
- a universal numerical epsilon;
- CSS color parsing;
- renderer/GPU representation policy;
- runtime adaptive styling;
- final production API names;
- a stable public API.

---

# 13. Compiler matrix

Correctness validation begins with the established baseline matrix:

```text
DMD 2.111.0  Debug
DMD 2.111.0  Release
LDC 1.41.0   Debug
LDC 1.41.0   Release
```

R0.12-E exposed a specific compiler-dependent runtime problem, so the
correctness matrix was expanded for diagnosis and final compatibility
validation to:

```text
DMD 2.111.0  Debug / Release
DMD 2.112.0  Debug / Release
DMD 2.112.1  Debug / Release
DMD 2.113.0  Debug / Release

LDC 1.41.0   Debug / Release
LDC 1.42.0   Debug / Release
LDC 1.43.0   Debug / Release
```

The implementation goal remains:

```text
correct from the established baseline upward
```

A common implementation path is preferred where it is correct across the
matrix.

Compiler-specific switches remain permitted when a reproduced correctness
problem or measured material performance difference justifies them.

General newer-compiler performance optimization remains subject to the
targeted compiler/performance work in GitHub #5.

---

# 14. Promotion rule

Research code must not become production API through implementation momentum.

R0.12 concludes only after the observed evidence has been recorded and the
resulting architectural implications are written durably.

No public palette API is frozen by this experiment.
