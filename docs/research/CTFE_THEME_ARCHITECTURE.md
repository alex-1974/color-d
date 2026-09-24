# Compile-Time Color and Theme Architecture

**Status:** DESIGN INPUT / CONSUMER RESEARCH
**Research baseline:** R0.12 validated; R0.13 in progress
**Document revision:** 0.1
**Date:** 2026-09-24
**Repository:** `color-d`
**Git provenance:** `git log -1 -- docs/research/CTFE_THEME_ARCHITECTURE.md`
**Primary target:** R4 OSM editor theme/style integration


## 1. Purpose

`color-d` shall treat compile-time evaluation as a normal execution mode of its color mathematics rather than as a separate subsystem.

Where the inputs of a color operation are known at compile time, the same semantic API used at runtime should normally be evaluable by D's Compile-Time Function Evaluation (CTFE).

This applies in particular to:

- color-space conversion;
- transfer functions;
- luminance and contrast calculations;
- perceptual color differences;
- interpolation;
- gamut checks and mapping;
- tone-scale generation;
- palette derivation;
- support for consumer-side semantic theme generation;
- validation of statically defined themes.

The intended model is:

```text
                    one semantic implementation
                              │
                    ┌─────────┴─────────┐
                    │                   │
                  CTFE               runtime
                    │                   │
            generated constants    dynamic colors
            static validation      user/runtime input
            fixed themes           adaptive rendering
```

A separate family of `fooCtfe()` APIs shall not be introduced merely because an operation is used at compile time.

---

## 2. Architectural boundary

`color-d` remains a color-mathematics library.

It shall not become a GUI framework, widget-theme engine, OSM styling system or renderer.

The architectural layering is:

```text
color-d
    │
    ├── color spaces
    ├── conversions
    ├── compositing
    ├── contrast
    ├── interpolation
    ├── gamut operations
    ├── perceptual operations
    └── palette / tone primitives
             │
             ▼
       theme/style layer
             │
      ┌──────┴──────┐
      │             │
   GUI theme     map styles
      │             │
      └──────┬──────┘
             ▼
          renderer
```

The theme/style layer may use `color-d` entirely at compile time when all source parameters are static.

GUI toolkit adapters belong above `color-d`.

OSM-specific concepts such as:

```text
highway.primary
building.residential
relation.boundary
editing.snapping
validation.error
```

also belong above `color-d`.

`color-d` supplies the mathematics from which those colors can be derived.

---

## 3. CTFE contract

An operation should be CTFE-capable when all of the following hold:

1. its semantics do not inherently depend on runtime state;
2. its implementation can reasonably execute under the supported D frontend;
3. CTFE support does not materially damage the runtime implementation;
4. supporting CTFE does not require a second semantic implementation.

Example:

```d
enum source = SRgb!double(0.2, 0.4, 0.8);
enum perceptual = source.toOklab();

static assert(perceptual.l > 0.0);
```

The corresponding runtime expression remains:

```d
auto perceptual = source.toOklab();
```

Both forms shall use the same implementation.

CTFE is therefore a capability of the API, not a separate API.

---

## 4. Compile-time theme generation

A completely static GUI theme can in principle be resolved during compilation
by a consumer theme/style layer built on `color-d`.

The examples in this section use illustrative consumer-layer names; they do not
define `color-d` core types or functions.

Conceptually:

```d
enum darkSpec = ThemeSpec(/* ... */);
enum darkTheme = buildTheme(darkSpec);
```

`darkTheme` is then a fully resolved value.

Theme construction may include:

```text
seed colors
    ↓
perceptual color-space conversion
    ↓
tone/chroma manipulation
    ↓
gamut mapping
    ↓
semantic color derivation
    ↓
interaction-state derivation
    ↓
contrast validation
    ↓
resolved theme
```

No corresponding theme-generation work is required when the application starts.

The resulting values can be emitted as ordinary static program data.

---

## 5. Theme specification versus resolved theme

A consumer theme/style architecture should distinguish **author intent** from
**resolved colors**.

The following names are illustrative consumer-layer pseudocode, not proposed
`color-d` core API.

Conceptually:

```d
struct ThemeSpec
{
    // source colors and policies
}

struct Theme
{
    // completely resolved colors
}
```

In this illustrative consumer model, `ThemeSpec` describes how a theme should
be generated, while `Theme` contains the resolved colors used by the
application.

The central transformation is conceptually:

```d
Theme buildTheme(ThemeSpec spec);
```

Whether a real consumer should expose these names or structures remains
subject to R4 consumer validation. No corresponding public `color-d`
abstraction is implied.

The important consumer-layer architectural property is:

```text
ThemeSpec
    │
    │ buildTheme()
    ▼
Theme
```

The transformation must be usable both at runtime and under CTFE.

---

## 6. Semantic tokens

A generic consumer theme should describe colors by semantic role rather than
by widget implementation. These semantic roles belong to the consumer
theme/style layer unless later evidence demonstrates a reusable color-domain
abstraction.

Possible groups include:

```text
surfaces
    background
    panel
    elevated
    overlay

content
    primary
    secondary
    disabled
    inverse

borders
    normal
    subtle
    strong

interaction
    accent
    hover
    pressed
    selected
    focus
    disabled

status
    information
    success
    warning
    error
```

This list is illustrative rather than a frozen public API.

Toolkit-specific concepts should not enter the generic model unless they represent a genuinely reusable semantic concept.

For example, a Qt-specific palette role is not by itself a reason to add that role to `color-d`.

---

## 7. Derived states

Interaction colors should not normally have to be manually authored one by one.

A theme specification may provide source colors and derivation policies from which states such as:

```text
normal
hover
pressed
selected
disabled
focus
```

are generated.

Derivation should use perceptual color operations where appropriate rather than arbitrary RGB arithmetic.

For example, a state transformation may constrain changes in:

```text
OKLCH lightness
OKLCH chroma
alpha
minimum contrast
target gamut
```

The exact derivation algorithms require prototype and visual validation before
a consumer theme/style API is stabilized.

---

## 8. Compile-time validation

Static consumer themes provide an opportunity to move errors from runtime
into compilation.

A resolved consumer theme should be verifiable against explicit policies using
`color-d` measurements and transformations where appropriate.

Potential invariants include:

- required semantic tokens are present;
- all required output colors are finite;
- output colors expected to be displayable are inside the target gamut;
- defined foreground/background pairs satisfy their required contrast policy;
- tone scales obey required ordering;
- alpha values lie in their valid domain;
- state derivations satisfy declared constraints.

Conceptually:

```d
enum theme = buildTheme(spec);
enum result = validateTheme(theme, policy);

static assert(result.valid);
```

Validation policy must remain distinct from color mathematics.

`color-d` should not silently impose one universal accessibility threshold on every consumer.

---

## 9. Compile-time tone and palette generation

Tone scales are particularly suitable for CTFE.

For example:

```text
accent seed
    ↓
OKLCH
    ↓
tone generation
    ↓
gamut mapping
    ↓
static palette
```

A generated palette might conceptually contain:

```text
tone 0
tone 10
tone 20
...
tone 90
tone 100
```

or another caller-defined scale.

The representation should favor value-level CTFE:

```d
enum tones = generateTones(seed, policy);
```

rather than generating declarations through string mixins.

Templates should be used where type-level behavior is genuinely required, not merely because the computation occurs during compilation.

---

## 10. Precomputation strategy

Fixed application colors should normally be resolved before the rendering hot path.

Preferred architecture:

```text
ThemeSpec
     │
     │ CTFE
     ▼
resolved semantic colors
     │
     ▼
cached style tables
     │
     ▼
renderer
```

This means operations such as:

- sRGB ↔ linear RGB conversion;
- Oklab/OKLCH conversion;
- tone generation;
- gamut mapping;
- interaction-state generation;

need not be repeatedly executed for static application colors.

This is useful independently of raw CPU speed because it also makes runtime behavior simpler and more deterministic.

---

## 11. Runtime themes

Compile-time support must not imply that consumer themes can only be static.

The same underlying `color-d` operations should also support consumer-side
runtime construction:

```d
auto theme = buildTheme(userSpec);
```

at runtime.

Runtime construction is required for cases such as:

- user-selected accent colors;
- imported themes;
- configuration files;
- operating-system supplied colors;
- dynamically selected accessibility settings;
- theme editors.

Compile-time and runtime construction should therefore share the same
consumer-side semantic model while reusing the same underlying `color-d`
operations.

---

## 12. Hybrid compile-time/runtime rendering

Some editor styling cannot be completely determined at compile time.

The most important example is map geometry rendered over arbitrary imagery.

The background beneath a road, node, polygon or selection marker is only known at runtime.

The intended architecture is therefore:

```text
        compile time
             │
             ▼
semantic base color
candidate variants
contrast policies
             │
             │
             ▼
        runtime input
      map / imagery sample
             │
             ▼
       adaptive selection
             │
             ▼
       rendered style
```

One promising strategy is to generate a small candidate family at compile time.

For example:

```text
selection.base
selection.light
selection.dark
selection.highContrastLight
selection.highContrastDark
```

At runtime the renderer can select the best candidate using local background information.

This may avoid performing full perceptual gamut manipulation for every rendered primitive.

Whether this strategy is preferable to continuous runtime adjustment is a performance and visual-quality question and must be benchmarked rather than assumed.

---

## 13. Separation of color adaptation and rendering adaptation

`color-d` may provide operations such as:

```text
relative luminance
contrast
perceptual distance
gamut mapping
color adjustment
compositing
```

It should not decide whether an editor should use:

```text
a halo
a casing
a wider stroke
a dashed line
a pattern
an outline
a shadow
```

Those are rendering decisions.

This distinction is particularly important for map editing.

Color alone cannot guarantee visibility over every possible background.

The renderer may therefore combine color adaptation with geometric techniques.

---

## 14. Compile-time versus runtime cost

CTFE shall not be treated as free computation.

For theme generation the project should measure at least:

```text
compiler wall time
compiler memory consumption
binary size
generated static-data size
runtime initialization cost
runtime lookup cost
```

A transformation being possible under CTFE does not automatically mean that performing it there is desirable.

Likewise, a runtime optimization must not be accepted merely because it is faster at runtime if it makes compile-time evaluation pathologically expensive for normal theme construction.

Runtime and CTFE performance are separate engineering dimensions.

---

## 15. Avoiding template bloat

Theme construction should preferably operate on ordinary values.

Prefer:

```d
enum theme = buildTheme(spec);
```

over architectures that instantiate a new type hierarchy for every color or token.

Templates remain appropriate for matters such as:

- scalar type;
- strongly typed color-space representation;
- genuine compile-time capabilities.

They should not be used merely to turn every theme value into a type.

The expected result of theme generation is primarily **data**, not generated code.

---

## 16. CTFE compatibility matrix

Before a consumer theme/style API is stabilized, its use of `color-d` shall
be verified across the supported compiler/frontend range.

The prototype should exercise at least:

```text
sRGB transfer functions
matrix conversion
cube/cube-root operations required by Oklab
atan2 / trigonometric hue operations
Oklab ↔ OKLCH
interpolation
gamut checks
gamut mapping
contrast
tone generation
complete theme generation
theme validation
```

Particular attention is required for mathematical functions whose CTFE behavior may differ by compiler/frontend version.

A mathematical implementation should not be replaced with a less appropriate algorithm solely to satisfy CTFE unless the trade-off is understood and documented.

---

## 17. CTFE/runtime equivalence

Every core operation promised to work under CTFE should have equivalent runtime tests.

The comparison rule is property-specific.

Where exact equality is part of the semantic contract, exact equality should be
tested.

Where floating-point transformation results are not required to be bit-for-bit
identical, comparison must follow the numerical policy established for the
underlying operation and property.

In particular, cross-execution comparison between CTFE and runtime is distinct
from reference-value comparison, round-trip or derived-property comparison,
classification predicates, caller policy, and algorithm-internal numerical
thresholds.

Observed runtime/CTFE differences are measurements, not automatically suitable
tolerance constants.

R0.13 owns the numerical reference and tolerance policy. This document does not
define a generic approximate-equality contract or a universal epsilon.

Consumer theme tests should inherit the comparison policy of the underlying
`color-d` operations rather than introduce a separate theme-wide tolerance.

---

## 18. Theme validation tests

The consumer integration prototype should contain deliberately valid and
invalid theme fixtures.

Examples:

```text
valid light theme
valid dark theme
valid high-contrast theme

insufficient text/background contrast
non-monotonic tone scale
non-finite source color
invalid alpha
unresolved semantic token
out-of-gamut final display token
```

Where practical, invalid compile-time specifications should produce compile-time failures that clearly identify the violated invariant.

Diagnostic quality is part of the prototype evaluation.

---

## 19. GUI integration

A GUI toolkit adapter may translate a resolved consumer theme into
toolkit-native structures.

For example:

```text
consumer theme data
      ↓
Qt adapter
      ↓
QPalette / application stylesheet
```

or:

```text
consumer theme data
      ↓
other GUI adapter
      ↓
toolkit-native theme
```

The dependency direction must remain:

```text
GUI adapter → color-d
```

never:

```text
color-d → GUI toolkit
```

This allows the editor to replace its GUI technology without redesigning
`color-d` mathematics. Consumer-owned semantic theme definitions can remain
framework-neutral as well.

---

## 20. Expected editor usage

A future editor consumer may therefore contain something conceptually
equivalent to:

```d
enum lightTheme = buildTheme(lightThemeSpec);
enum darkTheme  = buildTheme(darkThemeSpec);

static assert(validateTheme(lightTheme, guiPolicy).valid);
static assert(validateTheme(darkTheme, guiPolicy).valid);
```

At runtime:

```text
user / OS chooses light or dark
             ↓
select already generated Theme
             ↓
GUI adapter
             ↓
renderer
```

There is no requirement to calculate the complete fixed theme during application startup.

---

## 21. What CTFE does not solve

Compile-time generation does not replace runtime behavior when inputs are inherently dynamic.

Examples include:

- user-defined colors;
- imported theme files;
- current OS accent color;
- current monitor/color-management state;
- imagery underneath an edited object;
- transient rendering conditions.

The design goal is therefore not:

> move all color processing to compile time.

It is:

> make every naturally static color computation statically evaluable without creating a separate programming model.

---

## 22. Consumer integration prototype

The theme architecture should be validated through a real consumer rather than
by promoting a synthetic theme abstraction into the `color-d` core.

The primary validation target is the R4 OSM editor theme/style integration.
Build one representative end-to-end consumer prototype.

It should contain:

```text
one light ThemeSpec
one dark ThemeSpec
one high-contrast ThemeSpec

one accent seed
one neutral seed

generated tonal scales

surface tokens
text tokens
interaction tokens
status tokens

hover / pressed / disabled derivation

contrast validation

CTFE generation

runtime generation of the same specifications

CTFE/runtime equivalence tests
```

The prototype should record:

```text
DMD compile time
LDC compile time
binary-size impact
runtime construction cost
generated theme data size
diagnostic quality on invalid themes
```

Only real consumer experience should determine the exact `ThemeSpec`, `Theme`,
token hierarchy and derivation-policy API. These remain consumer-layer concepts
unless later evidence establishes a genuinely reusable `color-d` abstraction.

---

## 23. Architectural decision

The current direction is therefore:

**Established by existing `color-d` research**

- CTFE as a first-class capability of normal `color-d` operations;
- no separate CTFE-only color API;
- compile-time palette and tone construction through composition of lower-level
  primitives;
- fixed-size arrays for compile-time-known palette cardinality;
- separation of construction, gamut mapping, target conversion and validation;
- no semantic `Palette`, `Theme`, `PaletteBuilder` or `ThemeBuilder`
  abstraction is currently justified in the `color-d` core.

**Consumer architecture to validate in R4**

- compile-time construction and validation of fixed themes;
- runtime construction when theme inputs are dynamic;
- framework-neutral semantic theme data in the consumer theme/style layer;
- precomputation of frequently used colors;
- hybrid compile-time/runtime styling where environmental information is
  dynamic.

**Consumer details not yet stabilized**

- exact consumer-side `ThemeSpec` representation;
- exact semantic-token hierarchy;
- state-derivation algorithms;
- candidate-ladder strategy for adaptive map rendering;
- compile-time diagnostic mechanism;
- gamut-mapping algorithm used during theme generation.

**Reject as architectural direction**

- separate CTFE-only color APIs;
- GUI-toolkit dependencies inside `color-d`;
- OSM-specific semantic tokens inside `color-d`;
- string-mixin-based theme generation as the default mechanism;
- type-level representation of every theme value;
- mandatory runtime reconstruction of completely static themes;
- a universal numerical epsilon;
- the assumption that color adaptation alone can solve arbitrary map-background visibility.